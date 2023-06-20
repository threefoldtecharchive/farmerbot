module main

import utils { 
	ensure_no_error, ensure_result_contains_string, equals_statistics, rmb_response_system_version, rmb_response_statistics, rmb_response_storage_pools, rmb_response_public_config, run_test, TestEnvironment
}
import freeflowuniverse.baobab.client { Client }
import freeflowuniverse.crystallib.params { Params }
import threefoldtech.farmerbot.factory { Farmerbot }
import threefoldtech.farmerbot.system { RmbResponse, ZosResources }

import time

fn test_no_node_responds() {
	run_test("test_no_node_responds",
		fn (mut t TestEnvironment) ! {
			// prepare

			//act
			t.datamanager_update()!

			// assert
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .off).len == t.farmerbot.db.nodes.len
		}
	)!
}

fn test_all_nodes_respond() {
	run_test("test_all_nodes_respond",
		fn (mut t TestEnvironment) ! {
			// prepare
			for node in t.farmerbot.db.nodes.values() {
				t.zos_mock.messages <- rmb_response_system_version(node.twin_id)
			}

			//act
			t.datamanager_update()!

			// assert
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .on).len == t.farmerbot.db.nodes.len
		}
	)!
}

fn test_some_nodes_respond() {
	run_test("test_some_nodes_respond",
		fn (mut t TestEnvironment) ! {
			// prepare
			for node in t.farmerbot.db.nodes.values()[..2] {
				t.zos_mock.messages <- rmb_response_system_version(node.twin_id)
			}

			//act
			t.datamanager_update()!

			// assert
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .off).len == t.farmerbot.db.nodes.len - 2
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .on).len == 2

		}
	)!
}

fn test_node_resources_update() {
	run_test("test_node_resources_update",
		fn (mut t TestEnvironment) ! {
			// prepare
			used := ZosResources{
				cru: 2
				sru: 10 * 1024 * 1024 * 1024
				hru: 50 * 1024 * 1024 * 1024
				mru: 2 * 1024 * 1024 * 1024
				ipv4u: 1
			}
			sys := ZosResources {
				cru: 1
				sru: 100 * 1024 * 1024 * 1024
				hru: 0
				mru: 0
				ipv4u: 0
			}
			total := ZosResources {
				cru: 16
				sru: 200 * 1024 * 1024 * 1024
				hru: 1000 * 1024 * 1024 * 1024
				mru: 32 * 1024 * 1024 * 1024
				ipv4u: 0
			}
			for node in t.farmerbot.db.nodes.values() {
				t.zos_mock.messages <- rmb_response_system_version(node.twin_id)
				t.zos_mock.messages <- rmb_response_public_config(node.twin_id)
				t.zos_mock.messages <- rmb_response_statistics(node.twin_id, used, sys, total)
				t.zos_mock.messages <- rmb_response_storage_pools(node.twin_id)
			}

			//act
			t.datamanager_update()!

			// assert
			assert t.farmerbot.db.nodes.values().filter(it.powerstate == .on).len == t.farmerbot.db.nodes.len
			for node in t.farmerbot.db.nodes.values() {
				assert equals_statistics(node.resources.total, total)
				assert equals_statistics(node.resources.used, used)
				assert equals_statistics(node.resources.system, sys)
				assert node.public_ips_used == 1
			}
		}
	)!
}

// We simulate a successful wakeup: the node has answered our ping so the state should be changed to on. 
fn test_state_wakeup() {
	run_test("test_state_wakeup",
		fn (mut t TestEnvironment) ! {
			// prepare
			mut node_5 := t.farmerbot.db.get_node(5)!
			node_5.powerstate = .wakingup
			t.zos_mock.messages <- rmb_response_system_version(node_5.twin_id)

			//act
			t.datamanager_update()!

			// assert
			node_5 = t.farmerbot.db.get_node(5)!
			assert node_5.powerstate == .on
		}
	)!
}

// We simulate a wakeup that is still in progress: the node does not answer yet but the timeout is not yet exceeded. The state should still be wakingup. 
fn test_state_wakeup_still_in_progress() {
	run_test("test_state_wakeup_still_in_progress",
		fn (mut t TestEnvironment) ! {
			// prepare
			mut node_5 := t.farmerbot.db.get_node(5)!
			node_5.powerstate = .wakingup
			node_5.last_time_powerstate_changed = time.now()

			//act
			t.datamanager_update()!

			// assert
			node_5 = t.farmerbot.db.get_node(5)!
			assert node_5.powerstate == .wakingup
		}
	)!
}

// No message received after 30 minutes means the wakeup failed so the powerstate should be set to off.
fn test_state_wakeup_failed() {
	run_test("test_state_wakeup_failed",
		fn (mut t TestEnvironment) ! {
			// prepare
			mut node_5 := t.farmerbot.db.get_node(5)!
			node_5.powerstate = .wakingup
			node_5.last_time_powerstate_changed = time.now().add(-time.minute * 30)

			//act
			t.datamanager_update()!

			// assert
			node_5 = t.farmerbot.db.get_node(5)!
			assert node_5.powerstate == .off
		}
	)!
}

// The node does no longer answer the calls so the shutdown was a success. The state should be off
fn test_state_shutdown() {
	run_test("test_state_shutdown",
		fn (mut t TestEnvironment) ! {
			// prepare
			mut node_5 := t.farmerbot.db.get_node(5)!
			node_5.powerstate = .shuttingdown

			//act
			t.datamanager_update()!

			// assert
			node_5 = t.farmerbot.db.get_node(5)!
			assert node_5.powerstate == .off
		}
	)!
}

// We simulate a shutdown in progress: the timeout of 30 minutes is not yet exceeded and the node is still responding to our calls.
// The state should stay intact
fn test_state_shutdown_still_in_progress() {
	run_test("test_state_shutdown_still_in_progress",
		fn (mut t TestEnvironment) ! {
			// prepare
			mut node_5 := t.farmerbot.db.get_node(5)!
			node_5.powerstate = .shuttingdown
			node_5.last_time_powerstate_changed = time.now()
			// still receiving the message but 
			t.zos_mock.messages <- rmb_response_system_version(node_5.twin_id)

			//act
			t.datamanager_update()!

			// assert
			node_5 = t.farmerbot.db.get_node(5)!
			assert node_5.powerstate == .shuttingdown
		}
	)!
}

// The node is still answering our calls after 30 minutes: failure of shutdown so the state be back to on
fn test_state_shutdown_failed() {
	run_test("test_state_wakeup_failed",
		fn (mut t TestEnvironment) ! {
			// prepare
			mut node_5 := t.farmerbot.db.get_node(5)!
			node_5.powerstate = .shuttingdown
			node_5.last_time_powerstate_changed = time.now().add(-time.minute * 30)
			t.zos_mock.messages <- rmb_response_system_version(node_5.twin_id)

			//act
			t.datamanager_update()!

			// assert
			node_5 = t.farmerbot.db.get_node(5)!
			assert node_5.powerstate == .on
		}
	)!
}