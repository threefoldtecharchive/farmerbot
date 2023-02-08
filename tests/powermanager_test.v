module main

import utils { 
	ensure_error_message, ensure_no_error, TestEnvironment 
}
import freeflowuniverse.baobab.client { Client }
import freeflowuniverse.crystallib.params { Params }
import threefoldtech.farmerbot.factory { Farmerbot }
import threefoldtech.farmerbot.system


// TODO
fn test_poweroff_node() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run(fn (mut farmerbot Farmerbot, mut client Client) ! {
		// prepare
		farmerbot.db.nodes[3].powerstate = .on
		mut args := Params {}
		args.kwarg_add("nodeid", "3")

		// act
		mut job := client.job_new_wait(
			twinid: client.twinid
			action: system.job_power_off
			args: args
			actionsource: ""
		) or {
			return error("failed to create and wait for job")
		}

		// assert
		ensure_no_error(&job)!
		assert farmerbot.db.nodes[3].powerstate == .shuttingdown
	})!
}

// TODO
fn test_poweroff_node_that_is_shutting_down() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run(fn (mut farmerbot Farmerbot, mut client Client) ! {
		// prepare
		farmerbot.db.nodes[3].powerstate = .shuttingdown
		mut args := Params {}
		args.kwarg_add("nodeid", "3")

		// act
		mut job := client.job_new_wait(
			twinid: client.twinid
			action: system.job_power_off
			args: args
			actionsource: ""
		) or {
			return error("failed to create and wait for job")
		}

		// assert
		ensure_no_error(&job)!
		assert farmerbot.db.nodes[3].powerstate == .shuttingdown
	})!
}

// TODO
fn test_poweroff_node_that_is_off() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run(fn (mut farmerbot Farmerbot, mut client Client) ! {
		// prepare
		farmerbot.db.nodes[3].powerstate = .off
		mut args := Params {}
		args.kwarg_add("nodeid", "3")

		// act
		mut job := client.job_new_wait(
			twinid: client.twinid
			action: system.job_power_off
			args: args
			actionsource: ""
		) or {
			return error("failed to create and wait for job")
		}

		// assert
		ensure_no_error(&job)!
		assert farmerbot.db.nodes[3].powerstate == .off
	})!
}

// TODO
fn test_poweroff_node_that_is_wakingup_fails() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run(fn (mut farmerbot Farmerbot, mut client Client) ! {
		// prepare
		farmerbot.db.nodes[3].powerstate = .wakingup
		mut args := Params {}
		args.kwarg_add("nodeid", "3")

		// act
		mut job := client.job_new_wait(
			twinid: client.twinid
			action: system.job_power_off
			args: args
			actionsource: ""
		) or {
			return error("failed to create and wait for job")
		}

		// assert
		ensure_error_message(&job, "Node is waking up")!
		assert farmerbot.db.nodes[3].powerstate == .wakingup
	})!
}

// TODO 
fn test_poweroff_node_one_should_stay_on_fails() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run(fn (mut farmerbot Farmerbot, mut client Client) ! {
		// prepare
		for mut node in farmerbot.db.nodes.values() {
			node.powerstate = .off
		}
		farmerbot.db.nodes[3].powerstate = .on
		mut args := Params {}
		args.kwarg_add("nodeid", "3")

		// act
		mut job := client.job_new_wait(
			twinid: client.twinid
			action: system.job_power_off
			args: args
			actionsource: ""
		) or {
			return error("failed to create and wait for job")
		}

		// assert
		ensure_error_message(&job, "Cannot power off node, at least one node should be on in the farm.")!
		assert farmerbot.db.nodes[3].powerstate == .on
	})!
}

// TODO
fn test_poweron_node() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run(fn (mut farmerbot Farmerbot, mut client Client) ! {
		// prepare
		farmerbot.db.nodes[3].powerstate = .off
		mut args := Params {}
		args.kwarg_add("nodeid", "3")

		// act
		mut job := client.job_new_wait(
			twinid: client.twinid
			action: system.job_power_on
			args: args
			actionsource: ""
		) or {
			return error("failed to create and wait for job")
		}

		// assert
		ensure_no_error(&job)!
		assert farmerbot.db.nodes[3].powerstate == .wakingup
	})!
}

// TODO
fn test_poweron_node_that_is_shutting_down_fails() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run(fn (mut farmerbot Farmerbot, mut client Client) ! {
		// prepare
		farmerbot.db.nodes[3].powerstate = .shuttingdown
		mut args := Params {}
		args.kwarg_add("nodeid", "3")

		// act
		mut job := client.job_new_wait(
			twinid: client.twinid
			action: system.job_power_on
			args: args
			actionsource: ""
		) or {
			return error("failed to create and wait for job")
		}

		// assert
		ensure_error_message(&job, "Node is shutting down")!
		assert farmerbot.db.nodes[3].powerstate == .shuttingdown
	})!
}

// TODO
fn test_poweron_node_that_is_waking_up() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run(fn (mut farmerbot Farmerbot, mut client Client) ! {
		// prepare
		farmerbot.db.nodes[3].powerstate = .wakingup
		mut args := Params {}
		args.kwarg_add("nodeid", "3")

		// act
		mut job := client.job_new_wait(
			twinid: client.twinid
			action: system.job_power_on
			args: args
			actionsource: ""
		) or {
			return error("failed to create and wait for job")
		}

		// assert
		ensure_no_error(&job)!
		assert farmerbot.db.nodes[3].powerstate == .wakingup
	})!
}

// TODO
fn test_poweron_node_that_is_on() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run(fn (mut farmerbot Farmerbot, mut client Client) ! {
		// prepare
		farmerbot.db.nodes[3].powerstate = .on
		mut args := Params {}
		args.kwarg_add("nodeid", "3")

		// act
		mut job := client.job_new_wait(
			twinid: client.twinid
			action: system.job_power_on
			args: args
			actionsource: ""
		) or {
			return error("failed to create and wait for job")
		}

		// assert
		ensure_no_error(&job)!
		assert farmerbot.db.nodes[3].powerstate == .on
	})!
}

