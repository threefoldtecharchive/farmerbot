module main

import utils { 
	ensure_no_error, ensure_result_contains_string, equals_statistics, rmb_response_system_version, rmb_response_statistics, rmb_response_storage_pools, rmb_response_public_config, run_test, TestEnvironment
}
import freeflowuniverse.baobab.client { Client }
import freeflowuniverse.crystallib.params { Params }
import threefoldtech.farmerbot.factory { Farmerbot }
import threefoldtech.farmerbot.system { RmbResponse, ZosResources }




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
