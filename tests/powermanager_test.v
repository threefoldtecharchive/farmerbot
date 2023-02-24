module main

import utils { 
	ensure_error_message, ensure_no_error, powermanager_update,
	put_usage_to_x_procent, run_test
}
import freeflowuniverse.baobab.client { Client }
import freeflowuniverse.crystallib.params { Params }
import threefoldtech.farmerbot.factory { Farmerbot }
import threefoldtech.farmerbot.system

import time

// Test power off a node that is ON
fn test_poweroff_node() {
	run_test("test_poweroff_node", 
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			farmerbot.db.get_node(3)!.powerstate = .on
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
			assert farmerbot.db.get_node(3)!.powerstate == .shuttingdown
		}
	)!
}

// Test power off a node that is in shutdown state
fn test_poweroff_node_that_is_shutting_down() {
	run_test("test_poweroff_node_that_is_shutting_down",
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			farmerbot.db.get_node(3)!.powerstate = .shuttingdown
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
			assert farmerbot.db.get_node(3)!.powerstate == .shuttingdown
		}
	)!
}

// Test power off a node that is already off
fn test_poweroff_node_that_is_off() {
	run_test("test_poweroff_node_that_is_off",
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			farmerbot.db.get_node(3)!.powerstate = .off
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
			assert farmerbot.db.get_node(3)!.powerstate == .off
		}
	)!
}

// Test power off a node that is waking up
fn test_poweroff_node_that_is_wakingup() {
	run_test("test_poweroff_node_that_is_wakingup_fails",
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			farmerbot.db.get_node(3)!.powerstate = .wakingup
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
			assert farmerbot.db.get_node(3)!.powerstate == .shuttingdown
		}
	)!
}

// Test power off the last node online in the farm, it should fail 
fn test_poweroff_node_one_should_stay_on_fails() {
	run_test("test_poweroff_node_one_should_stay_on_fails",
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			for mut node in farmerbot.db.nodes.values() {
				node.powerstate = .off
			}
			farmerbot.db.get_node(3)!.powerstate = .on
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
			assert farmerbot.db.get_node(3)!.powerstate == .on
		}
	)!
}

// Test powering on a node that is offline
fn test_poweron_node() {
	run_test("test_poweron_node", 
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			farmerbot.db.get_node(3)!.powerstate = .off
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
			assert farmerbot.db.get_node(3)!.powerstate == .wakingup
		}
	)!
}

// Test powering on a node that is in shutdown state
fn test_poweron_node_that_is_shutting_down() {
	run_test("test_poweron_node_that_is_shutting_down_fails", 
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			farmerbot.db.get_node(3)!.powerstate = .shuttingdown
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
			assert farmerbot.db.get_node(3)!.powerstate == .wakingup
		}
	)!
}

// Test powering on a node that is waking up
fn test_poweron_node_that_is_waking_up() {
	run_test("test_poweron_node_that_is_waking_up", 
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			farmerbot.db.get_node(3)!.powerstate = .wakingup
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
			assert farmerbot.db.get_node(3)!.powerstate == .wakingup
		}
	)!
}

// Test powering on a node that is already online
fn test_poweron_node_that_is_on() {
	run_test("test_poweron_node_that_is_on", 
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
		farmerbot.db.get_node(3)!.powerstate = .on
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
			assert farmerbot.db.get_node(3)!.powerstate == .on
		}
	)!
}

// Test power management: when the resource usage gets too high 
// (> wake_up_threshold). It should power on a new node
fn test_power_management_resource_usage_too_high() {
	run_test("test_power_management_resource_usage_too_high",
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			farmerbot.db.wake_up_threshold = 80
			for mut node in farmerbot.db.nodes.values() {
				node.powerstate = .off
				node.last_time_awake = time.now()
			}
			mut node_3 := farmerbot.db.get_node(3)!
			node_3.powerstate = .on
			put_usage_to_x_procent(mut node_3, 80)
			mut node_5 := farmerbot.db.get_node(5)!
			node_5.powerstate = .on
			put_usage_to_x_procent(mut node_5, 81)

			// act
			powermanager_update(mut farmerbot)!

			// assert
			assert farmerbot.db.get_node(8)!.powerstate == .wakingup
		}
	)!
}

// Test power management: when the usage is perfect do nothing
fn test_power_management_resource_usage_is_perfect() {
	run_test("test_power_management_resource_usage_is_perfect",
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			farmerbot.db.wake_up_threshold = 80
			for mut node in farmerbot.db.nodes.values() {
				node.last_time_awake = time.now()
				node.powerstate = .off
			}
			mut node_3 := farmerbot.db.get_node(3)!
			node_3.powerstate = .on
			put_usage_to_x_procent(mut node_3, 70)
			mut node_5 := farmerbot.db.get_node(5)!
			node_5.powerstate = .on
			put_usage_to_x_procent(mut node_5, 70)

			// act
			powermanager_update(mut farmerbot)!

			// assert
			assert farmerbot.db.nodes.values().filter(it.powerstate == .on).len == 2
		}
	)!
}

// Test power management when usage is too low and we can power off 
// a node (at least two empty)
fn test_power_management_resource_usage_too_low() {
	run_test("test_power_management_resource_usage_too_low",
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			farmerbot.db.wake_up_threshold = 80
			for mut node in farmerbot.db.nodes.values() {
				node.last_time_awake = time.now()
				node.powerstate = .off
			}
			mut node_3 := farmerbot.db.get_node(3)!
			node_3.powerstate = .on
			put_usage_to_x_procent(mut node_3, 100)
			farmerbot.db.get_node(5)!.powerstate = .on
			farmerbot.db.get_node(8)!.powerstate = .on

			// act
			powermanager_update(mut farmerbot)!

			// assert
			assert farmerbot.db.get_node(5)!.powerstate == .shuttingdown
			assert farmerbot.db.get_node(8)!.powerstate == .on
		}
	)!
}

// Test power management when usage is too low but we have to keep at least one
// empty node on
fn test_power_management_resource_usage_too_low_keep_at_least_one_empty_node_on() {
	run_test("test_power_management_resource_usage_too_low_keep_at_least_one_empty_node_on",
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			farmerbot.db.wake_up_threshold = 80
			for mut node in farmerbot.db.nodes.values() {
				node.last_time_awake = time.now()
				node.powerstate = .off
			}
			mut node_3 := farmerbot.db.get_node(3)!
			node_3.powerstate = .on
			put_usage_to_x_procent(mut node_3, 60)
			farmerbot.db.get_node(5)!.powerstate = .on

			// act
			powermanager_update(mut farmerbot)!

			// assert
			assert farmerbot.db.get_node(5)!.powerstate == .on
		}
	)!
}

// Test power management: the capacity usage is lower then the threshold but
// we can't shutdown any nodes as they are all being used.
fn test_power_management_resource_usage_too_low_no_nodes_to_bring_down() {
	run_test("test_power_management_resource_usage_too_low_no_nodes_to_bring_down",
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			farmerbot.db.wake_up_threshold = 80
			for mut node in farmerbot.db.nodes.values() {
				node.last_time_awake = time.now()
				node.powerstate = .off
			}
			mut node_3 := farmerbot.db.get_node(3)!
			node_3.powerstate = .on
			put_usage_to_x_procent(mut node_3, 25)
			mut node_5 := farmerbot.db.get_node(5)!
			node_5.powerstate = .on
			put_usage_to_x_procent(mut node_5, 34)
			mut node_8 := farmerbot.db.get_node(8)!
			node_8.powerstate = .on
			put_usage_to_x_procent(mut node_8, 55)

			// act
			powermanager_update(mut farmerbot)!

			// assert
			assert farmerbot.db.nodes.values().filter(it.powerstate == .on).len == 3
			assert farmerbot.db.nodes.values().filter(it.powerstate == .shuttingdown).len == 0
			assert farmerbot.db.nodes.values().filter(it.powerstate == .wakingup).len == 0
		}
	)!
}

// Test power management: periodic wakeup
fn test_power_management_periodic_wakeup() {
	run_test("test_power_management_periodic_wakeup",
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			now := time.now()
			farmerbot.db.periodic_wakeup_start = time.hour * now.hour
			twenty_three_hours_ago := now.add_days(-1)
			one_hour_ago := now.add(-time.hour)

			for mut node in farmerbot.db.nodes.values() {
				node.powerstate = .on
			}
			farmerbot.db.get_node(3)!.powerstate = .off
			farmerbot.db.get_node(3)!.last_time_awake = one_hour_ago
			farmerbot.db.get_node(5)!.powerstate = .off
			farmerbot.db.get_node(5)!.last_time_awake = twenty_three_hours_ago

			// act
			// we wake up only one node at a time
			powermanager_update(mut farmerbot)!
			powermanager_update(mut farmerbot)!

			// assert
			assert farmerbot.db.get_node(3)!.powerstate == .wakingup
			assert farmerbot.db.get_node(5)!.powerstate == .wakingup
			// make sure no other nodes were shutdown
			assert farmerbot.db.nodes.values().filter(it.powerstate == .shuttingdown).len == 0
			assert farmerbot.db.nodes.values().filter(it.powerstate == .off).len == 0
		}
	)!
}