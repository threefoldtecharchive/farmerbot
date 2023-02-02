module main

import utils { add_required_resources, ensure_no_error, ensure_result_contains_u32 }
import freeflowuniverse.baobab.client
import freeflowuniverse.crystallib.params { Params }
import threefoldtech.farmerbot.factory { Farmerbot }
import threefoldtech.farmerbot.system

import flag
import log
import os

const (
	testpath = os.dir(@FILE) + '/../example_data'
)

type Test = fn (mut farmerbot &Farmerbot, mut client &client.Client) !

pub struct TestEnvironment {
pub mut:
	tests map[string]Test
}

pub fn (mut t TestEnvironment) run(log_level log.Level) {
	mut logger := log.Logger(&log.Log{ level: .info })
	mut client := client.new() or { return }
	logger.info("=======")
	logger.info("|TESTS|")
	logger.info("=======")

	for testname, test in t.tests {
		mut f := factory.new(testpath, log_level) or {
			logger.error("failed creating farmerbot: $err")
			return
		}
		client.reset() or {
			logger.error("Failed resetting client")
		 	return
		}
		_ := spawn f.run()
		test(mut f, mut &client) or {
			logger.error("[FAILED] ${testname}: $err")
			continue
		}
		logger.info("[PASSED] ${testname}")

	}
}

fn test_find_node_required_resources(mut farmerbot &Farmerbot, mut client &client.Client) ! {
	// prepare 
	mut args := Params {}
	add_required_resources(mut args, "500GB", "100GB", "4GB", "2")

	// act
	mut job := client.job_new_wait(
		twinid: 162
		action: system.job_node_find
		args: args
		actionsource: ""
	) or {
		return error("failed to create and wait for job")
	}

	// assert
	ensure_no_error(&job)!
	ensure_result_contains_u32(&job, "nodeid", 3)!
}

fn test_find_node_required_resources_second_node(mut farmerbot &Farmerbot, mut client &client.Client) ! {
	// prepare 
	node_id_5_capacity := farmerbot.db.nodes[5].capacity_capability
	mut args := Params {}
	add_required_resources(mut args,
		node_id_5_capacity.hru.str(),
		node_id_5_capacity.sru.str(), 
		node_id_5_capacity.mru.str(),
		node_id_5_capacity.cru.str())

	// act
	mut job := client.job_new_wait(
		twinid: 162
		action: system.job_node_find
		args: args
		actionsource: ""
	) or {
		return error("failed to create and wait for job")
	}

	// assert
	ensure_no_error(&job)!
	ensure_result_contains_u32(&job, "nodeid", 5)!
}

fn test_find_node_that_is_on_first(mut farmerbot &Farmerbot, mut client &client.Client) ! {
	// prepare
	//farmerbot.db.nodes[3].powerstate = .off
	mut args := Params {}
	// can fit on node with id 3 but it is offline so it should be 5
	add_required_resources(mut args, "500GB", "100GB", "4GB", "2")

	// act
	mut job := client.job_new_wait(
		twinid: 162
		action: system.job_node_find
		args: args
		actionsource: ""
	) or {
		return error("failed to create and wait for job")
	}

	//assert
	ensure_no_error(&job)!
	ensure_result_contains_u32(&job, "nodeid", 5)!
}


fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('Integration tests for the farmerbot')
	fp.limit_free_args(0, 0)!
	fp.description('')
	fp.skip_executable()
	debug_log := fp.bool('debug', 0, false, 'By default the logs of the farmerbot are turned off. With this argument the debug logs will be shown too.')
	_ := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}
	mut tests := map[string]Test{}
	tests["find_node_with_required_resources"] = test_find_node_required_resources
	tests["find_node_with_required_resources_second_node"] = test_find_node_required_resources_second_node
	tests["find_node_that_is_on_first"] = test_find_node_that_is_on_first
	// ADD YOUR TESTS HERE
	mut testenvironment := TestEnvironment {
		tests: tests
	}
	testenvironment.run(if debug_log { .debug } else { .disabled })
}
