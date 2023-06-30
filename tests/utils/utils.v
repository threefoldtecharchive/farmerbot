module utils

import freeflowuniverse.baobab.actionrunner
import freeflowuniverse.baobab.client { Client }
import freeflowuniverse.baobab.jobs { ActionJob, ActionJobState }
import freeflowuniverse.baobab.processor
import freeflowuniverse.crystallib.params { Params }

import threefoldtech.farmerbot.factory { Farmerbot }
import threefoldtech.farmerbot.manager { PowerManager }
import threefoldtech.farmerbot.system { Capacity, Node, PowerState, RmbResponse, ZosPool, ZosResources, ZosResourcesStatistics }

import encoding.base64
import json
import math
import os

const (
	testpath = os.dir(@FILE) + '/../../example_data'
)

pub type MockSetNodePower = fn(node_id u32, state PowerState)!

// TODO add some mock code
pub struct TfChainMock {
pub mut:
	mock_set_node_power MockSetNodePower = fn(node_id u32, state PowerState) ! {}
}
pub fn (mut t TfChainMock) set_node_power(node_id u32, state PowerState) ! {
	t.mock_set_node_power(node_id, state)!
}
pub fn (mut t TfChainMock) 	active_rent_contract_for_node(nodeid u32) !u64 {
	return 0
}

// TODO add some mock code 
pub struct ZosMock {
pub mut:
	running bool
	messages chan RmbResponse
}
pub fn (mut z ZosMock) run() {
}
pub fn (mut z ZosMock) has_public_config(dsts []u32, exp u64) ! {
}
pub fn (mut z ZosMock) get_statistics(dsts []u32, exp u64) ! {
}
pub fn (mut z ZosMock) get_system_version(dsts []u32, exp u64) ! {
}
pub fn (mut z ZosMock) get_wg_ports(dsts []u32, exp u64) ! {
}
pub fn (mut z ZosMock) get_storage_pools(dsts []u32, exp u64) ! {
}
pub fn (mut z ZosMock) get_gpus(dsts []u32, exp u64) ! {
}

pub type Test = fn (mut TestEnvironment) !

[heap]
[noinit]
pub struct TestEnvironment {
pub mut:
	client &Client = &Client{}
	farmerbot &Farmerbot
	tfchain_mock &TfChainMock = &TfChainMock {}
	zos_mock &ZosMock = &ZosMock {}
}

pub fn run_test(name string, test Test) ! {
	mut redis_address := os.getenv("FARMERBOT_REDIS_ADDRESS")
	if redis_address == "" {
		redis_address = "localhost:6379"
	}
	mut c := client.new(redis_address) or { 
		return error("Failed creating client: $err")
	}
	os.mkdir_all("/tmp/farmerbot", os.MkdirParams{})!

	os.setenv("FARMERBOT_LOG_OUTPUT", "/tmp/farmerbot/${name}.log", true)
	os.setenv("FARMERBOT_LOG_LEVEL", "DEBUG", true)
	os.setenv("FARMERBOT_LOG_CONSOLE", "FALSE", true)
	
	mut tfchain_mock := &TfChainMock {}
	mut zos_mock := &ZosMock {
		messages: chan RmbResponse {cap: 1000}
	}
	mut logger := system.logger()
	mut managers := map[string]&manager.Manager{}
	mut db := &system.DB {
		farm: &system.Farm {}
	}
	mut data_manager := &manager.DataManager{
		client: client.new(redis_address)!
		db: db
		logger: logger
		tfchain: tfchain_mock
		zos: zos_mock
		timeout_rmb_response: 1
	}
	mut farm_manager := &manager.FarmManager{
		client: client.new(redis_address)!
		db: db
		logger: logger
		tfchain: tfchain_mock
		zos: zos_mock
	}
	mut node_manager := &manager.NodeManager{
		client: client.new(redis_address)!
		db: db
		logger: logger
		tfchain: tfchain_mock
		zos: zos_mock
	}
	mut power_manager := &manager.PowerManager{
		client: client.new(redis_address)!
		db: db
		logger: logger
		tfchain: tfchain_mock
		zos: zos_mock
		random_wakeups_a_month: 0
	}

	// ADD NEW MANAGERS HERE
	managers['datamanager'] = data_manager
	managers['farmmanager'] = farm_manager
	managers['nodemanager'] = node_manager
	managers['powermanager'] = power_manager

	mut f := &Farmerbot {
		redis_address: redis_address
		path: testpath
		db: db
		logger: logger
		tfchain: tfchain_mock
		zos: zos_mock
		processor: processor.new(redis_address, logger)!
		actionrunner: actionrunner.new(client.new(redis_address)!, [farm_manager, node_manager,
		power_manager])
		managers: managers
	}
	// to proceed the shutting down of the server (more computation though)
	f.actionrunner.timeout_waiting_actors = 0.01
	f.processor.timeout_waiting_queues = 0.01
	f.init() or {
		return error("Failed creating farmerbot: $err")
	}

	for mut node in f.db.nodes.values() {
		// Simulate resources being used by ZOS
		node.resources.system = system.Capacity {
			cru: 0
            sru: 100 * 1024 * 1024 *1024
            mru: 2 * 1024 * 1024 * 1024
            hru: 0
		}
	}
	
	f.processor.reset() or {
		return error("Failed resetting processor: $err")
	}

	t_ar := spawn (&f.actionrunner).run()
	t_pr := spawn (&f.processor).run()

	c.reset() or {
		return error("Failed resetting client: $err")
	}

	mut t := TestEnvironment{
		client: &c
		farmerbot: f
		tfchain_mock: tfchain_mock
		zos_mock: zos_mock
	}
	test(mut t) or {
		f.processor.running = false
		f.actionrunner.running = false
		t_ar.wait()
		t_pr.wait()
		return error("$err")
	}

	f.processor.running = false
	f.actionrunner.running = false
	t_ar.wait()
	t_pr.wait()
}

pub fn (mut t TestEnvironment) datamanager_update() ! {
	mut datamanager := t.farmerbot.get_manager("datamanager")!
	datamanager.update()
}

pub fn (mut t TestEnvironment) powermanager_update() ! {
	mut powermanager := t.farmerbot.get_manager("powermanager")!
	powermanager.update()
}

pub fn (mut t TestEnvironment) powermanager_on_started() ! {
	mut powermanager := t.farmerbot.get_manager("powermanager")!
	powermanager.on_started()
}

pub fn (mut t TestEnvironment) powermanager_on_stop() ! {
	mut powermanager := t.farmerbot.get_manager("powermanager")!
	powermanager.on_stop()
}

pub fn wait_till_jobs_are_finished(actor string, mut c Client) ! {
 	for c.check_remaining_jobs(actor)! > 0 {
	}
}

pub fn capacity_from_args(args &Params) !Capacity {
	return Capacity {
		hru: args.get_storagecapacity_in_bytes("required_hru")!
		sru: args.get_storagecapacity_in_bytes("required_sru")!
		mru: args.get_storagecapacity_in_bytes("required_mru")!
		cru: args.get_storagecapacity_in_bytes("required_cru")!
	}
}

pub fn put_usage_to_x_procent(mut node Node, x u32) {
	node.resources.used = Capacity {
		hru: u64(math.ceil(node.resources.total.hru * x / 100))
		sru: u64(math.ceil(node.resources.total.sru * x / 100))
		mru: u64(math.ceil(node.resources.total.mru * x / 100))
		cru: u64(math.ceil(node.resources.total.cru * x / 100))
	}
}

pub fn add_required_resources(mut args Params, hru string, sru string, mru string, cru string) {
	args.kwarg_add("required_hru", hru)
	args.kwarg_add("required_sru", sru)
	args.kwarg_add("required_mru", mru)
	args.kwarg_add("required_cru", cru)
}

pub fn ensure_node_has_claimed_resources(node &Node, capacity &Capacity) ! {
	if !(node.resources.used == capacity) {
		return error("Expected the used resources to be ${capacity}. It is ${node.resources.used} instead!")
	}
}

pub fn ensure_result_contains_string(job &ActionJob, key string, value string) ! {
	value_in_job := job.result.get(key) or {
		return error("Result doesn't contain ${key}: ${job.result}")
	}
	if value_in_job != value {
		return error("Expected result ${key}=${value}, got ${key}=${value_in_job} instead.")
	}
}

pub fn ensure_result_contains_u32(job &ActionJob, key string, value u32) ! {
	value_in_job := job.result.get_u32(key) or {
		return error("Result doesn't contain ${key}: ${job.result}")
	}
	if value_in_job != value {
		return error("Expected result ${key}=${value}, got ${key}=${value_in_job} instead.")
	}
}

pub fn ensure_no_error(job &ActionJob) ! {
	match job.state {
		.done {}
		.error {
			return error("The job is in error state: ${job.error}")
		}
		else {
			return error("The job is not finished yet, state = ${job.state}")
		}
	}
}

pub fn ensure_error(job &ActionJob) ! {
	ensure_error_message(job, "")!
}

pub fn ensure_error_message(job &ActionJob, expected_error string) ! {
	match job.state {
		.error {
			if expected_error != "" && expected_error != job.error {
				return error("Expected error \"${expected_error}\", got \"${job.error}\" instead.")
			}
		}
		else {
			return error("Expected error \"${expected_error}\", job is not in error state but in state ${job.state}.")
		}
	}	
}

pub fn rmb_response_system_version(twin_id u32) RmbResponse {
	return RmbResponse {
			ref: "zos.system.version"
			dat: "doesn't really matter"
			src: "${twin_id}"
	}
}

pub fn rmb_response_public_config(twin_id u32) RmbResponse {
	return RmbResponse {
			ref: "zos.network.public_config_get"
			dat: "doesn't really matter"
			src: "${twin_id}"
	}
}

pub fn rmb_response_statistics(twin_id u32, used ZosResources, sys ZosResources, total ZosResources) RmbResponse {
	stats := ZosResourcesStatistics{
		used: used
		system: sys
		total: total
	}
	return RmbResponse {
			ref: "zos.statistics.get"
			dat: base64.encode_str(json.encode(stats))
			src: "${twin_id}"
	}
}

pub fn rmb_response_storage_pools(twin_id u32) RmbResponse {
	pools := []ZosPool{	}
	return RmbResponse {
			ref: "zos.storage.pools"
			dat: base64.encode_str(json.encode(pools))
			src: "${twin_id}"
	}
}

pub fn equals_statistics(a Capacity, b ZosResources) bool {
	return a == Capacity {
		cru: b.cru
		sru: b.sru
		mru: b.mru
		hru: b.hru
	}
}