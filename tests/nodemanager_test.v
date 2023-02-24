module main

import utils { 
	add_required_resources, capacity_from_args, ensure_error_message, ensure_no_error, ensure_node_has_claimed_resources, 
	ensure_result_contains_u32, run_test 
}
import freeflowuniverse.baobab.client { Client }
import freeflowuniverse.crystallib.params { Params }
import threefoldtech.farmerbot.factory { Farmerbot }
import threefoldtech.farmerbot.system 

// Test finding a node with minimal required resources
fn test_find_node_required_resources() {
	run_test("test_find_node_required_resources", 
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare 
			mut args := Params {}
			add_required_resources(mut args, "500GB", "100GB", "4GB", "2")

			// act
			mut job := client.job_new_wait(
				twinid: client.twinid
				action: system.job_node_find
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job)!
			ensure_result_contains_u32(&job, "nodeid", 3)!
			ensure_node_has_claimed_resources(farmerbot.db.get_node(3)!, capacity_from_args(args)!)!
		}
	)!
}

//   Test finding a node with minimal required resources
//   The required resources is more then what the first node can handle
 fn test_find_node_required_resources_selecting_second_node() {
	run_test("test_find_node_required_resources_selecting_second_node", 
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			node_id_5_capacity := farmerbot.db.get_node(5)!.resources.total
			mut args := Params {}
			add_required_resources(mut args,
				node_id_5_capacity.hru.str(),
				node_id_5_capacity.sru.str(), 
				node_id_5_capacity.mru.str(),
				node_id_5_capacity.cru.str())

			// act
			mut job := client.job_new_wait(
				twinid: client.twinid
				action: system.job_node_find
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job)!
			ensure_result_contains_u32(&job, "nodeid", 5)!
			ensure_node_has_claimed_resources(farmerbot.db.get_node(5)!, capacity_from_args(args)!)!
		}
	)!
}

// Test finding a node that has a public_config
fn test_find_node_with_public_config() {
	run_test("test_find_node_with_public_config", 
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			mut args := Params {}
			add_required_resources(mut args, "500GB", "100GB", "4GB", "2")
			args.kwarg_add("public_config", "1")

			// act
			mut job := client.job_new_wait(
				twinid: client.twinid
				action: system.job_node_find
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job)!
			ensure_result_contains_u32(&job, "nodeid", 8)!
		}
	)!
}

// Test finding a node with minimum amount of resources and renting the full node (it should not be used)
fn test_find_node_dedicated() {
	run_test("test_find_node_dedicated", 
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			mut args := Params {}
			add_required_resources(mut args, "500GB", "100GB", "4GB", "2")
			args.kwarg_add("dedicated", "1")

			// act
			mut job := client.job_new_wait(
				twinid: client.twinid
				action: system.job_node_find
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job)!
			ensure_result_contains_u32(&job, "nodeid", 20)!
		}
	)!
}

// Test finding a node with minimum amount of resources and excluding specific nodes
// The required resources will fit on any node but we exclude node 3 and 5
fn test_find_node_excluding_nodes() {
	run_test("test_find_node_excluding_nodes",
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			mut args := Params {}
			add_required_resources(mut args, "500GB", "100GB", "4GB", "2")
			args.kwarg_add("node_exclude", "3, 5")

			// act
			mut job := client.job_new_wait(
				twinid: client.twinid
				action: system.job_node_find
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job)!
			ensure_result_contains_u32(&job, "nodeid", 8)!
		}
	)!
}

// Test finding a certified node with minimal required resources
// Node with id 20 is also certified but is dedicated and we are
// not asking for dedicated node nor asking for al resources
 fn test_find_node_certified() {
	run_test("test_find_node_certified",
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			mut args := Params {}
			add_required_resources(mut args, "500GB", "100GB", "4GB", "2")
			args.kwarg_add("certified", "true")

			// act
			mut job := client.job_new_wait(
				twinid: client.twinid
				action: system.job_node_find
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job)!
			ensure_result_contains_u32(&job, "nodeid", 25)!
		}
	)!
}

// Test finding a node, testing the power state functionality
// Required resources can fit on node with id 3 but it is offline so it should be 5
fn test_find_node_that_is_on_first() {
	run_test("test_find_node_that_is_on_first",
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			farmerbot.db.get_node(3)!.powerstate = .off
			mut args := Params {}
			add_required_resources(mut args, "500GB", "100GB", "4GB", "2")

			// act
			mut job := client.job_new_wait(
				twinid: client.twinid
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
	)!
}

// Test finding a node: testing a bit of everything together
fn test_find_node_with_everything() {
	run_test("test_find_node_with_everything",
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			mut args := Params {}
			add_required_resources(mut args, "500GB", "100GB", "4GB", "2")
			args.kwarg_add("certified", "true")
			args.kwarg_add("dedicated", "1")
			args.kwarg_add("public_config", "1")
			args.kwarg_add("node_exclude", "3, 5")

			// act
			mut job := client.job_new_wait(
				twinid: client.twinid
				action: system.job_node_find
				args: args
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job)!
			ensure_result_contains_u32(&job, "nodeid", 20)!
		}
	)!
}

// Test finding a node with overprovisioning 
// node 3 has overprovisioning set to 2 (8 cores * 2 => 16 cores available)
// first two jobs should be able to fit onto node 3 (with overprovisioning)
fn test_overprovisioning_cpu() {
	run_test("test_overprovisioning_cpu", 
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			mut args_a := Params {}
			add_required_resources(mut args_a, "100GB", "100GB", "4GB", "8")
			mut args_b := Params {}
			add_required_resources(mut args_b, "100GB", "100GB", "4GB", "6")
			mut args_c := Params {}
			add_required_resources(mut args_c, "100GB", "100GB", "4GB", "4")

			// act
			mut job_a := client.job_new_wait(
				twinid: client.twinid
				action: system.job_node_find
				args: args_a
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}
			mut job_b := client.job_new_wait(
				twinid: client.twinid
				action: system.job_node_find
				args: args_b
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}
			mut job_c := client.job_new_wait(
				twinid: client.twinid
				action: system.job_node_find
				args: args_c
				actionsource: ""
			) or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job_a)!
			ensure_no_error(&job_b)!
			ensure_no_error(&job_c)!
			ensure_result_contains_u32(&job_a, "nodeid", 3)!
			ensure_result_contains_u32(&job_b, "nodeid", 3)!
			ensure_result_contains_u32(&job_c, "nodeid", 5)!
		}
	)!
}

// Test finding a node with 2 public ips
// Farm has 2 public ips available so this job should succeed
fn test_find_node_with_public_ips() {
	run_test("test_find_node_with_public_ips",
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			mut args := Params {}
			add_required_resources(mut args, "500GB", "100GB", "4GB", "2")
			args.kwarg_add("public_ips", "2")

			// act
			mut job := client.job_new_wait(
				twinid: client.twinid
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
	)!
}

// Test finding a node with 3 public ips
// Farm has 2 public ips available so this job should fail
fn test_find_node_with_public_ips_fails() {
	run_test("test_find_node_with_public_ips_fails", 
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			mut args := Params {}
			add_required_resources(mut args, "500GB", "100GB", "4GB", "2")
			args.kwarg_add("public_ips", "3")

			// act
			mut job := client.job_new_wait(
				twinid: client.twinid
				action: system.job_node_find
				args: args
				actionsource: ""
			)or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_error_message(&job, "No more public ips available")!
		}
	)!
}

fn test_find_node_testing_rent_contract() {
	run_test("test_find_node_testing_rent_contract", 
		fn (mut farmerbot Farmerbot, mut client Client) ! {
			// prepare
			mut args := Params {}
			farmerbot.db.get_node(3)!.has_active_rent_contract = true
			add_required_resources(mut args, "500GB", "100GB", "4GB", "2")

			// act
			mut job := client.job_new_wait(
				twinid: client.twinid
				action: system.job_node_find
				args: args
				actionsource: ""
			)or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job)!
			ensure_result_contains_u32(&job, "nodeid", 5)!
		}
	)!
}