module main

import utils { 
	ensure_error_message, ensure_no_error, put_usage_to_x_procent, TestEnvironment, wait_till_jobs_are_finished
}
import freeflowuniverse.baobab.client { Client }
import freeflowuniverse.crystallib.params { Params }
import threefoldtech.farmerbot.factory { Farmerbot }
import threefoldtech.farmerbot.system

import time

// Test power off a node that is ON
fn test_poweroff_node() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run("test_poweroff_node", 
	fn (mut farmerbot Farmerbot, mut client Client) ! {
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

// Test power off a node that is in shutdown state
fn test_poweroff_node_that_is_shutting_down() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run("test_poweroff_node_that_is_shutting_down",
	fn (mut farmerbot Farmerbot, mut client Client) ! {
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

// Test power off a node that is already off
fn test_poweroff_node_that_is_off() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run("test_poweroff_node_that_is_off",
	fn (mut farmerbot Farmerbot, mut client Client) ! {
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

// Test power off a node that is waking up, it should fail
fn test_poweroff_node_that_is_wakingup_fails() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run("test_poweroff_node_that_is_wakingup_fails",
	fn (mut farmerbot Farmerbot, mut client Client) ! {
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

// Test power off the last node online in the farm, it should fail 
fn test_poweroff_node_one_should_stay_on_fails() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run("test_poweroff_node_one_should_stay_on_fails",
	fn (mut farmerbot Farmerbot, mut client Client) ! {
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

// Test powering on a node that is offline
fn test_poweron_node() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run("test_poweron_node", 
	fn (mut farmerbot Farmerbot, mut client Client) ! {
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

// Test powering on a node that is in shutdown state, it should fail
fn test_poweron_node_that_is_shutting_down_fails() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run("test_poweron_node_that_is_shutting_down_fails", 
	fn (mut farmerbot Farmerbot, mut client Client) ! {
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

// Test powering on a node that is waking up
fn test_poweron_node_that_is_waking_up() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run("test_poweron_node_that_is_waking_up", 
	fn (mut farmerbot Farmerbot, mut client Client) ! {
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

// Test powering on a node that is already online
fn test_poweron_node_that_is_on() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run("test_poweron_node_that_is_on", 
	fn (mut farmerbot Farmerbot, mut client Client) ! {
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

// Test power management: when the resource usage gets too high 
// (> wake_up_threshold). It should power on a new node
fn test_power_management_resource_usage_too_high() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run("test_power_management_resource_usage_too_high",
	fn (mut farmerbot Farmerbot, mut client Client) ! {
		// prepare
		farmerbot.db.wake_up_threshold = 80
		for mut node in farmerbot.db.nodes.values() {
			node.powerstate = .off
		}
		farmerbot.db.nodes[3].powerstate = .on
		put_usage_to_x_procent(mut farmerbot.db.nodes[3], 80)
		farmerbot.db.nodes[5].powerstate = .on
		put_usage_to_x_procent(mut farmerbot.db.nodes[5], 81)

		// act
		farmerbot.managers["powermanager"].update()

		// assert
		assert farmerbot.db.nodes[8].powerstate == .wakingup
	})!
}

// Test power management: when the usage is perfect do nothing
fn test_power_management_resource_usage_is_perfect() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run("test_power_management_resource_usage_is_perfect",
	fn (mut farmerbot Farmerbot, mut client Client) ! {
		// prepare
		farmerbot.db.wake_up_threshold = 80
		for mut node in farmerbot.db.nodes.values() {
			node.powerstate = .off
		}
		farmerbot.db.nodes[3].powerstate = .on
		put_usage_to_x_procent(mut farmerbot.db.nodes[3], 70)
		farmerbot.db.nodes[5].powerstate = .on
		put_usage_to_x_procent(mut farmerbot.db.nodes[5], 70)

		// act
		farmerbot.managers["powermanager"].update()

		// assert
		assert farmerbot.db.nodes.values().filter(it.powerstate == .on).len == 2
	})!
}

// Test power management when usage is too low and we can power off 
// a node (at least two empty)
fn test_power_management_resource_usage_too_low() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run("test_power_management_resource_usage_too_low",
	fn (mut farmerbot Farmerbot, mut client Client) ! {
		// prepare
		farmerbot.db.wake_up_threshold = 80
		for mut node in farmerbot.db.nodes.values() {
			node.powerstate = .off
		}
		farmerbot.db.nodes[3].powerstate = .on
		put_usage_to_x_procent(mut farmerbot.db.nodes[3], 100)
		farmerbot.db.nodes[5].powerstate = .on
		farmerbot.db.nodes[8].powerstate = .on

		// act
		farmerbot.managers["powermanager"].update()

		// assert
		assert farmerbot.db.nodes[8].powerstate == .shuttingdown
	})!
}

// Test power management when usage is too low but we have to keep at least one
// empty node on
fn test_power_management_resource_usage_too_low_keep_at_least_one_empty_node_on() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run("test_power_management_resource_usage_too_low_keep_at_least_one_empty_node_on",
	fn (mut farmerbot Farmerbot, mut client Client) ! {
		// prepare
		farmerbot.db.wake_up_threshold = 80
		for mut node in farmerbot.db.nodes.values() {
			node.powerstate = .off
		}
		farmerbot.db.nodes[3].powerstate = .on
		put_usage_to_x_procent(mut farmerbot.db.nodes[3], 60)
		farmerbot.db.nodes[5].powerstate = .on

		// act
		farmerbot.managers["powermanager"].update()

		// assert
		assert farmerbot.db.nodes[5].powerstate == .on
	})!
}