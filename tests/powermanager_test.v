module main

import utils { 
	ensure_error_message, ensure_no_error,
	put_usage_to_x_procent, run_test, TestEnvironment
}
import freeflowuniverse.baobab.client { Client }
import freeflowuniverse.crystallib.params { Params }
import threefoldtech.farmerbot.factory { Farmerbot }
import threefoldtech.farmerbot.system { PowerState }

import time

// Test power off a node that is ON
fn test_poweroff_node() {
	run_test("test_poweroff_node", 
		fn (mut t TestEnvironment) ! {
			// prepare
			t.farmerbot.db.get_node(3)!.powerstate = .on
			mut args := Params {}
			args.kwarg_add("nodeid", "3")

			// act
			mut job := t.client.job_new_wait(
				twinid: t.client.twinid
				action: system.job_power_off
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job)!
			assert t.farmerbot.db.get_node(3)!.powerstate == .shuttingdown
		}
	)!
}

// Test power off a node that is in shutdown state
fn test_poweroff_node_that_is_shutting_down() {
	run_test("test_poweroff_node_that_is_shutting_down",
		fn (mut t TestEnvironment) ! {
			// prepare
			t.farmerbot.db.get_node(3)!.powerstate = .shuttingdown
			mut args := Params {}
			args.kwarg_add("nodeid", "3")

			// act
			mut job := t.client.job_new_wait(
				twinid: t.client.twinid
				action: system.job_power_off
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job)!
			assert t.farmerbot.db.get_node(3)!.powerstate == .shuttingdown
		}
	)!
}

// Test power off a node that is already off
fn test_poweroff_node_that_is_off() {
	run_test("test_poweroff_node_that_is_off",
		fn (mut t TestEnvironment) ! {
			// prepare
			t.farmerbot.db.get_node(3)!.powerstate = .off
			mut args := Params {}
			args.kwarg_add("nodeid", "3")

			// act
			mut job := t.client.job_new_wait(
				twinid: t.client.twinid
				action: system.job_power_off
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job)!
			assert t.farmerbot.db.get_node(3)!.powerstate == .off
		}
	)!
}

// Test power off a node that is waking up
fn test_poweroff_node_that_is_wakingup() {
	run_test("test_poweroff_node_that_is_wakingup_fails",
		fn (mut t TestEnvironment) ! {
			// prepare
			t.farmerbot.db.get_node(3)!.powerstate = .wakingup
			mut args := Params {}
			args.kwarg_add("nodeid", "3")

			// act
			mut job := t.client.job_new_wait(
				twinid: t.client.twinid
				action: system.job_power_off
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job)!
			assert t.farmerbot.db.get_node(3)!.powerstate == .shuttingdown
		}
	)!
}

// Test power off the last node online in the farm, it should fail 
fn test_poweroff_node_one_should_stay_on_fails() {
	run_test("test_poweroff_node_one_should_stay_on_fails",
		fn (mut t TestEnvironment) ! {
			// prepare
			for mut node in t.farmerbot.db.nodes.values() {
				node.powerstate = .off
			}
			t.farmerbot.db.get_node(3)!.powerstate = .on
			mut args := Params {}
			args.kwarg_add("nodeid", "3")

			// act
			mut job := t.client.job_new_wait(
				twinid: t.client.twinid
				action: system.job_power_off
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_error_message(&job, "Cannot power off node, at least one node should be on in the farm.")!
			assert t.farmerbot.db.get_node(3)!.powerstate == .on
		}
	)!
}

// Test power off node: call to tfchain fails
fn test_poweroff_node_call_tfchain_fails() {
	run_test("test_poweroff_node_call_tfchain_fails",
		fn (mut t TestEnvironment) ! {
			// prepare
			t.tfchain_mock.mock_set_node_power = fn(node_id u32, state PowerState) ! {
				return error("something failed on tfchain")
			}
			for mut node in t.farmerbot.db.nodes.values() {
				node.powerstate = .on
			}
			mut args := Params {}
			args.kwarg_add("nodeid", "3")

			// act
			mut job := t.client.job_new_wait(
				twinid: t.client.twinid
				action: system.job_power_off
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_error_message(&job, "something failed on tfchain")!
			assert t.farmerbot.db.get_node(3)!.powerstate == .on
		}
	)!
}

// Test powering off a node that is configured never to be shutdown
fn test_poweroff_node_configured_never_to_shutdown() {
	run_test("test_poweroff_node_configured_never_to_shutdown",
		fn (mut t TestEnvironment) ! {
			// prepare
			t.farmerbot.db.get_node(3)!.never_shutdown = true
			mut args := Params {}
			args.kwarg_add("nodeid", "3")

			// act
			mut job := t.client.job_new_wait(
				twinid: t.client.twinid
				action: system.job_power_off
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_error_message(&job, "Cannot power off node, node is configured to never be shutdown.")!
			assert t.farmerbot.db.get_node(3)!.powerstate == .on
		}
	)!
}

// Test powering off a node that has a public 
fn test_poweroff_node_with_public_config() {
	run_test("test_poweroff_node_with_public_config",
		fn (mut t TestEnvironment) ! {
			// prepare
			t.farmerbot.db.get_node(3)!.public_config = true
			mut args := Params {}
			args.kwarg_add("nodeid", "3")

			// act
			mut job := t.client.job_new_wait(
				twinid: t.client.twinid
				action: system.job_power_off
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_error_message(&job, "Cannot power off node, node has public config.")!
			assert t.farmerbot.db.get_node(3)!.powerstate == .on
		}
	)!
}

// Test powering on a node that is offline
fn test_poweron_node() {
	run_test("test_poweron_node", 
		fn (mut t TestEnvironment) ! {
			// prepare
			t.farmerbot.db.get_node(3)!.powerstate = .off
			mut args := Params {}
			args.kwarg_add("nodeid", "3")

			// act
			mut job := t.client.job_new_wait(
				twinid: t.client.twinid
				action: system.job_power_on
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job)!
			assert t.farmerbot.db.get_node(3)!.powerstate == .wakingup
		}
	)!
}

// Test powering on a node that is in shutdown state
fn test_poweron_node_that_is_shutting_down() {
	run_test("test_poweron_node_that_is_shutting_down_fails", 
		fn (mut t TestEnvironment) ! {
			// prepare
			t.farmerbot.db.get_node(3)!.powerstate = .shuttingdown
			mut args := Params {}
			args.kwarg_add("nodeid", "3")

			// act
			mut job := t.client.job_new_wait(
				twinid: t.client.twinid
				action: system.job_power_on
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job)!
			assert t.farmerbot.db.get_node(3)!.powerstate == .wakingup
		}
	)!
}

// Test powering on a node that is waking up
fn test_poweron_node_that_is_waking_up() {
	run_test("test_poweron_node_that_is_waking_up", 
		fn (mut t TestEnvironment) ! {
			// prepare
			t.farmerbot.db.get_node(3)!.powerstate = .wakingup
			mut args := Params {}
			args.kwarg_add("nodeid", "3")

			// act
			mut job := t.client.job_new_wait(
				twinid: t.client.twinid
				action: system.job_power_on
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job)!
			assert t.farmerbot.db.get_node(3)!.powerstate == .wakingup
		}
	)!
}

// Test powering on a node that is already online
fn test_poweron_node_that_is_on() {
	run_test("test_poweron_node_that_is_on", 
		fn (mut t TestEnvironment) ! {
			// prepare
		t.farmerbot.db.get_node(3)!.powerstate = .on
			mut args := Params {}
			args.kwarg_add("nodeid", "3")

			// act
			mut job := t.client.job_new_wait(
				twinid: t.client.twinid
				action: system.job_power_on
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job)!
			assert t.farmerbot.db.get_node(3)!.powerstate == .on
		}
	)!
}


// Test power on node: call to tfchain fails
fn test_poweron_node_call_tfchain_fails() {
	run_test("test_poweron_node_call_tfchain_fails",
		fn (mut t TestEnvironment) ! {
			// prepare
			t.tfchain_mock.mock_set_node_power = fn(node_id u32, state PowerState) ! {
				return error("something failed on tfchain")
			}
			for mut node in t.farmerbot.db.nodes.values() {
				node.powerstate = .off
			}
			mut args := Params {}
			args.kwarg_add("nodeid", "3")

			// act
			mut job := t.client.job_new_wait(
				twinid: t.client.twinid
				action: system.job_power_on
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_error_message(&job, "something failed on tfchain")!
			assert t.farmerbot.db.get_node(3)!.powerstate == .off
		}
	)!
}

// Test power management: when the resource usage gets too high 
// (> wake_up_threshold). It should power on a new node
fn test_power_management_resource_usage_too_high() {
	run_test("test_power_management_resource_usage_too_high",
		fn (mut t TestEnvironment) ! {
			// prepare
			t.farmerbot.db.wake_up_threshold = 80
			for mut node in t.farmerbot.db.nodes.values() {
				node.powerstate = .off
				node.last_time_awake = time.now()
			}
			mut node_3 := t.farmerbot.db.get_node(3)!
			node_3.powerstate = .on
			put_usage_to_x_procent(mut node_3, 80)
			mut node_5 := t.farmerbot.db.get_node(5)!
			node_5.powerstate = .on
			put_usage_to_x_procent(mut node_5, 81)

			// act
			t.powermanager_update()!

			// assert
			assert t.farmerbot.db.get_node(8)!.powerstate == .wakingup
		}
	)!
}

// Test power management: when the usage is perfect do nothing
fn test_power_management_resource_usage_is_perfect() {
	run_test("test_power_management_resource_usage_is_perfect",
		fn (mut t TestEnvironment) ! {
			// prepare
			t.farmerbot.db.wake_up_threshold = 80
			for mut node in t.farmerbot.db.nodes.values() {
				node.last_time_awake = time.now()
				node.powerstate = .off
			}
			mut node_3 := t.farmerbot.db.get_node(3)!
			node_3.powerstate = .on
			put_usage_to_x_procent(mut node_3, 70)
			mut node_5 := t.farmerbot.db.get_node(5)!
			node_5.powerstate = .on
			put_usage_to_x_procent(mut node_5, 70)

			// act
			t.powermanager_update()!

			// assert
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .on).len == 2
		}
	)!
}

// Test power management when usage is too low and we can power off 
// a node
fn test_power_management_resource_usage_too_low() {
	run_test("test_power_management_resource_usage_too_low",
		fn (mut t TestEnvironment) ! {
			// prepare
			t.farmerbot.db.wake_up_threshold = 80
			for mut node in t.farmerbot.db.nodes.values() {
				node.last_time_awake = time.now()
				node.powerstate = .off
			}
			t.farmerbot.db.get_node(3)!.powerstate = .on
			t.farmerbot.db.get_node(5)!.powerstate = .on
			mut node_8 := t.farmerbot.db.get_node(8)!
			node_8.powerstate = .on
			put_usage_to_x_procent(mut node_8, 100)

			// act
			t.powermanager_update()!

			// assert
			assert t.farmerbot.db.get_node(3)!.powerstate == .shuttingdown
			assert t.farmerbot.db.get_node(5)!.powerstate == .on
		}
	)!
}


// Test power management when usage is too low and we can power off 
// two nodes
fn test_power_management_resource_usage_too_low_shutdown_2_nodes() {
	run_test("test_power_management_resource_usage_too_low_shutdown_2_nodes",
		fn (mut t TestEnvironment) ! {
			// prepare
			t.farmerbot.db.wake_up_threshold = 80
			for mut node in t.farmerbot.db.nodes.values() {
				node.last_time_awake = time.now()
				node.powerstate = .off
			}

			t.farmerbot.db.get_node(3)!.powerstate = .on
			t.farmerbot.db.get_node(5)!.powerstate = .on
			mut node_8 := t.farmerbot.db.get_node(8)!
			node_8.powerstate = .on
			put_usage_to_x_procent(mut node_8, 10)

			// act
			t.powermanager_update()!

			// assert
			assert t.farmerbot.db.get_node(3)!.powerstate == .shuttingdown
			assert t.farmerbot.db.get_node(5)!.powerstate == .shuttingdown
		}
	)!
}


// Test power management when usage is too low but we can't power off
// nodes that are configured to never shutdown
fn test_power_management_resource_usage_too_low_nodes_that_cant_shutdown() {
	run_test("test_power_management_resource_usage_too_low_nodes_that_cant_shutdown",
		fn (mut t TestEnvironment) ! {
			// prepare
			for mut node in t.farmerbot.db.nodes.values() {
				node.powerstate = .on
				node.public_config = false
				node.never_shutdown = false
			}
			t.farmerbot.db.get_node(3)!.never_shutdown = true
			t.farmerbot.db.get_node(5)!.public_config = true
			t.farmerbot.db.get_node(8)!.never_shutdown = true

			// act
			t.powermanager_update()!

			// assert
			assert t.farmerbot.db.get_node(3)!.powerstate == .on
			assert t.farmerbot.db.get_node(5)!.powerstate == .on
			assert t.farmerbot.db.get_node(8)!.powerstate == .on
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .shuttingdown).len == t.farmerbot.db.nodes.len - 3
		}
	)!
}

// Test power management when usage is too low but we have to keep at least one
// node on
fn test_power_management_resource_usage_too_low_keep_at_least_one_node_on() {
	run_test("test_power_management_resource_usage_too_low_keep_at_least_one_node_on",
		fn (mut t TestEnvironment) ! {
			// prepare
			for mut node in t.farmerbot.db.nodes.values() {
				node.last_time_awake = time.now()
				node.powerstate = .off
			}
			t.farmerbot.db.get_node(3)!.powerstate = .on
			t.farmerbot.db.get_node(5)!.powerstate = .on

			// act
			t.powermanager_update()!

			// assert
			assert t.farmerbot.db.get_node(3)!.powerstate == .shuttingdown
			assert t.farmerbot.db.get_node(5)!.powerstate == .on
		}
	)!
}

// Test power management: the capacity usage is lower then the threshold but
// we can't shutdown any nodes as they are all being used.
fn test_power_management_resource_usage_too_low_no_nodes_to_bring_down() {
	run_test("test_power_management_resource_usage_too_low_no_nodes_to_bring_down",
		fn (mut t TestEnvironment) ! {
			// prepare
			t.farmerbot.db.wake_up_threshold = 80
			for mut node in t.farmerbot.db.nodes.values() {
				node.last_time_awake = time.now()
				node.powerstate = .off
			}
			mut node_3 := t.farmerbot.db.get_node(3)!
			node_3.powerstate = .on
			put_usage_to_x_procent(mut node_3, 25)
			mut node_5 := t.farmerbot.db.get_node(5)!
			node_5.powerstate = .on
			put_usage_to_x_procent(mut node_5, 34)
			mut node_8 := t.farmerbot.db.get_node(8)!
			node_8.powerstate = .on
			put_usage_to_x_procent(mut node_8, 55)

			// act
			t.powermanager_update()!

			// assert
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .on).len == 3
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .shuttingdown).len == 0
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .wakingup).len == 0
		}
	)!
}

// Test power management: periodic wakeup
fn test_power_management_periodic_wakeup() {
	run_test("test_power_management_periodic_wakeup",
		fn (mut t TestEnvironment) ! {
			// prepare
			now := time.now()
			t.farmerbot.db.periodic_wakeup_start = time.hour * now.hour
			twenty_three_hours_ago := now.add_days(-1)
			one_hour_ago := now.add(-time.hour)
			for mut node in t.farmerbot.db.nodes.values() {
				node.powerstate = .on
			}
			t.farmerbot.db.get_node(3)!.powerstate = .off
			t.farmerbot.db.get_node(3)!.last_time_awake = one_hour_ago
			t.farmerbot.db.get_node(5)!.powerstate = .off
			t.farmerbot.db.get_node(5)!.last_time_awake = twenty_three_hours_ago

			// act
			// we wake up only one node at a time
			t.powermanager_update()!
			t.powermanager_update()!

			// assert
			assert t.farmerbot.db.get_node(3)!.powerstate == .wakingup
			assert t.farmerbot.db.get_node(5)!.powerstate == .wakingup
			// make sure no other nodes were shutdown
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .shuttingdown).len == 0
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .off).len == 0
		}
	)!
}

// Test power management: periodic wakeup with different periodic_wakeup_limit
fn test_power_management_periodic_wakeup_limit() {
	run_test("test_power_management_periodic_wakeup_limit",
		fn (mut t TestEnvironment) ! {
			// prepare
			now := time.now()
			t.farmerbot.db.periodic_wakeup_start = time.hour * now.hour
			t.farmerbot.db.periodic_wakeup_limit = 2
			twenty_three_hours_ago := now.add_days(-1)
			for mut node in t.farmerbot.db.nodes.values() {
				node.powerstate = .on
			}
			t.farmerbot.db.get_node(3)!.powerstate = .off
			t.farmerbot.db.get_node(3)!.last_time_awake = twenty_three_hours_ago
			t.farmerbot.db.get_node(5)!.powerstate = .off
			t.farmerbot.db.get_node(5)!.last_time_awake = twenty_three_hours_ago

			// act
			// we wake up two at a time
			t.powermanager_update()!

			// assert
			assert t.farmerbot.db.get_node(3)!.powerstate == .wakingup
			assert t.farmerbot.db.get_node(5)!.powerstate == .wakingup
			// make sure no other nodes were shutdown
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .shuttingdown).len == 0
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .off).len == 0
		}
	)!
}

// Test power management: we only power off a node after 30 minutes after a periodic wake up to allow the node to 
// report its uptime. Don't shutdown nodes where the powerstate was changed within 30 minutes ago.
fn test_power_management_after_periodic_wakeup_too_early_to_shutdown() {
	run_test("test_power_management_after_periodic_wakeup_too_early_to_shutdown",
		fn (mut t TestEnvironment) ! {
			// prepare
			now := time.now()
			t.farmerbot.db.periodic_wakeup_start = time.hour * now.hour
			for mut node in t.farmerbot.db.nodes.values() {
				node.powerstate = .off
				node.last_time_awake = now
			}
			t.farmerbot.db.get_node(3)!.powerstate = .on
			t.farmerbot.db.get_node(3)!.last_time_powerstate_changed = now
			t.farmerbot.db.get_node(5)!.powerstate = .on
			t.farmerbot.db.get_node(5)!.last_time_powerstate_changed = now

			// act
			t.powermanager_update()!

			// assert
			assert t.farmerbot.db.get_node(3)!.powerstate == .on
			assert t.farmerbot.db.get_node(5)!.powerstate == .on
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .off).len == t.farmerbot.db.nodes.len - 2
		}
	)!
}

// Test power management: second node shutdown fails on tfchain side so we ignore that case in our calculation.  
fn test_power_management_second_shutdown_fails() {
	run_test("test_power_management_second_shutdown_fails",
		fn (mut t TestEnvironment) ! {
			// prepare
			for mut node in t.farmerbot.db.nodes.values() {
				node.powerstate = .on
				node.never_shutdown = false
				node.public_config = false
			}
			t.tfchain_mock.mock_set_node_power = fn(node_id u32, state PowerState) ! {
				if node_id == 5 {
					return error("something failed on tfchain for node 3")
				}
			}

			// act
			t.powermanager_update()!

			// assert
			assert t.farmerbot.db.get_node(5)!.powerstate == .on
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .shuttingdown).len == t.farmerbot.db.nodes.len - 1
		}
	)!
}

// Test power management: we only power off a node after 30 minutes after a periodic wake up to allow the node to 
// report its uptime. Shutdown node where powerstate was changed 30 minutes or longer ago.
fn test_power_management_after_periodic_wakeup_allowed_to_shutdown() {
	run_test("test_power_management_after_periodic_wakeup_allowed_to_shutdown",
		fn (mut t TestEnvironment) ! {
			// prepare
			now := time.now()
			t.farmerbot.db.periodic_wakeup_start = time.hour * now.hour
			for mut node in t.farmerbot.db.nodes.values() {
				node.powerstate = .off
				node.last_time_awake = now
			}
			t.farmerbot.db.get_node(3)!.powerstate = .on
			t.farmerbot.db.get_node(3)!.last_time_powerstate_changed = now
			t.farmerbot.db.get_node(5)!.powerstate = .on
			t.farmerbot.db.get_node(5)!.last_time_powerstate_changed = now.add(time.minute * -30)

			// act
			t.powermanager_update()!

			// assert
			assert t.farmerbot.db.get_node(3)!.powerstate == .on
			assert t.farmerbot.db.get_node(5)!.powerstate == .shuttingdown
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .off).len == t.farmerbot.db.nodes.len - 2
		}
	)!
}

// Test Power management and periodic wakeup together. We execute periodic wakeup for 2 nodes while the resource 
// usage is too low. Result: nodes should wake up while we shutdown the nodes that are up except for one.
fn test_periodic_wakeup_and_power_management_resource_usage_too_low() {
	run_test("test_periodic_wakeup_and_power_management_resource_usage_too_low",
		fn (mut t TestEnvironment) ! {
			// prepare
			now := time.now()
			t.farmerbot.db.periodic_wakeup_start = time.hour * now.hour
			t.farmerbot.db.periodic_wakeup_limit = 2
			for mut node in t.farmerbot.db.nodes.values() {
				node.powerstate = .on
				node.never_shutdown = false
				node.public_config = false
				node.last_time_powerstate_changed = now.add(time.hour * -1)
			}
			t.farmerbot.db.get_node(3)!.powerstate = .off
			t.farmerbot.db.get_node(3)!.last_time_awake = now.add(time.hour * -24)
			t.farmerbot.db.get_node(5)!.powerstate = .off
			t.farmerbot.db.get_node(5)!.last_time_awake = now.add(time.hour * -24)

			// act
			t.powermanager_update()!

			// assert
			assert t.farmerbot.db.get_node(3)!.powerstate == .wakingup
			assert t.farmerbot.db.get_node(5)!.powerstate == .wakingup
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .shuttingdown).len == t.farmerbot.db.nodes.len - 3
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .on).len == 1
		}
	)!
}

// Test Power management and periodic wakeup together. We execute periodic wakeup for 1 node while the resource 
// usage is too high. Result: periodic wakeup fixes the lack of free resources.
fn test_periodic_wakeup_and_power_management_resource_usage_too_high() {
	run_test("test_periodic_wakeup_and_power_management_resource_usage_too_high",
		fn (mut t TestEnvironment) ! {
			// prepare
			now := time.now()
			t.farmerbot.db.periodic_wakeup_start = time.hour * now.hour
			t.farmerbot.db.periodic_wakeup_limit = 2
			for mut node in t.farmerbot.db.nodes.values() {
				node.powerstate = .on
				put_usage_to_x_procent(mut node, 80)
			}
			t.farmerbot.db.get_node(3)!.powerstate = .off
			t.farmerbot.db.get_node(3)!.last_time_awake = now.add(time.hour * -24)
			t.farmerbot.db.get_node(5)!.powerstate = .off
			t.farmerbot.db.get_node(5)!.last_time_awake = now

			// act
			t.powermanager_update()!

			// assert
			assert t.farmerbot.db.get_node(3)!.powerstate == .wakingup
			assert t.farmerbot.db.get_node(5)!.powerstate == .off
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .on).len == t.farmerbot.db.nodes.len - 2
		}
	)!
}


fn test_on_started() {
	run_test("test_on_started",
		fn (mut t TestEnvironment) ! {
			// prepare
			for mut node in t.farmerbot.db.nodes.values() {
				node.powerstate = .off
			}
			t.farmerbot.db.get_node(3)!.powerstate = .on
			t.farmerbot.db.get_node(5)!.powerstate = .on

			// act
			t.powermanager_on_started()!

			// assert
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .on).len == 2
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .wakingup).len == t.farmerbot.db.nodes.len - 2
		}
	)!
}

fn test_on_stop() {
	run_test("test_on_stop",
		fn (mut t TestEnvironment) ! {
			// prepare
			for mut node in t.farmerbot.db.nodes.values() {
				node.powerstate = .off
			}
			t.farmerbot.db.get_node(3)!.powerstate = .on
			t.farmerbot.db.get_node(5)!.powerstate = .on

			// act
			t.powermanager_on_stop()!

			// assert
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .on).len == 2
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .wakingup).len == t.farmerbot.db.nodes.len - 2
		}
	)!
}