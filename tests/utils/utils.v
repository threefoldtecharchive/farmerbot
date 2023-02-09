module utils

import freeflowuniverse.baobab.actionrunner
import freeflowuniverse.baobab.client { Client }
import freeflowuniverse.baobab.jobs { ActionJob, ActionJobState }
import freeflowuniverse.baobab.processor
import freeflowuniverse.crystallib.params { Params }

import threefoldtech.farmerbot.factory { Farmerbot }
import threefoldtech.farmerbot.manager { PowerManager }
import threefoldtech.farmerbot.system { Capacity, Node, PowerState, ZosResourcesStatistics }

import math
import os

const (
	testpath = os.dir(@FILE) + '/../../example_data'
)

// TODO add some mock code
pub struct TfChainMock {
}
pub fn (mut t TfChainMock) set_node_power(node_id u32, state PowerState) ! {

}

// TODO add some mock code 
pub struct ZosMock {
}
pub fn (mut z ZosMock) zos_has_public_config(dst u32) !bool {
	return true
}
pub fn (mut z ZosMock) get_zos_statistics(dst u32) !ZosResourcesStatistics {
	return ZosResourcesStatistics {}
}
pub fn (mut z ZosMock) get_zos_system_version(dst u32) !string {
	return ""
}

pub type Test = fn (mut farmerbot Farmerbot, mut client Client) !

[heap]
pub struct TestEnvironment {
pub mut:
	tfchain_mock &TfChainMock = &TfChainMock {}
	zos_mock &ZosMock = &ZosMock {}
}

pub fn (mut t TestEnvironment) run(name string, test Test) ! {
	mut client := client.new() or { 
		return error("Failed creating client: $err")
	}

	os.mkdir_all("/tmp/farmerbot", os.MkdirParams{})!

	os.setenv("FARMERBOT_LOG_OUTPUT", "/tmp/farmerbot/${name}.log", true)
	os.setenv("FARMERBOT_LOG_LEVEL", "DEBUG", true)
	
	t.tfchain_mock = &TfChainMock {}
	t.zos_mock = &ZosMock {}
	mut f := &Farmerbot {
		path: testpath
		db: &system.DB {
			farm: &system.Farm {}
		}
		logger: system.logger()
		tfchain: t.tfchain_mock
		zos: t.zos_mock
		processor: processor.Processor {}
		actionrunner: actionrunner.ActionRunner {
			client: &Client {}
		}
	}
	f.init() or {
		return error("Failed creating farmerbot: $err")
	}

	t_ar := spawn (&f.actionrunner).run()
	t_pr := spawn (&f.processor).run()

	client.reset() or {
		return error("Failed resetting client: $err")
	}

	test(mut f, mut client) or {
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

pub fn run_test(name string, test Test) ! {
	mut testenvironment := TestEnvironment{}
	testenvironment.run(name, test)!
}


pub fn wait_till_jobs_are_finished(actor string, mut client Client) ! {
 	for client.check_remaining_jobs(actor)! > 0 {
	}
}

pub fn capacity_from_args(args &Params) !Capacity {
	return Capacity {
		hru: args.get_kilobytes("required_hru")!
		sru: args.get_kilobytes("required_sru")!
		mru: args.get_kilobytes("required_mru")!
		cru: args.get_kilobytes("required_cru")!
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
