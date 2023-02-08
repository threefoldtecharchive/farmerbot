module utils

import freeflowuniverse.baobab.client { Client }
import freeflowuniverse.baobab.jobs { ActionJob, ActionJobState }
import freeflowuniverse.crystallib.params { Params }

import threefoldtech.farmerbot.factory { Farmerbot }
import threefoldtech.farmerbot.system { Capacity, Node}

import os

const (
	testpath = os.dir(@FILE) + '/../../example_data'
)

pub type Test = fn (mut farmerbot Farmerbot, mut client Client) !

pub struct TestEnvironment {
}

pub fn (mut t TestEnvironment) run(test Test) ! {
	mut client := client.new() or { 
		return error("Failed creating client: $err")
	}

	// TODO: output log to file
	mut f := factory.new(testpath, .disabled) or {
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


pub fn capacity_from_args(args &Params) !Capacity {
	return Capacity {
		hru: args.get_kilobytes("required_hru")!
		sru: args.get_kilobytes("required_sru")!
		mru: args.get_kilobytes("required_mru")!
		cru: args.get_kilobytes("required_cru")!
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