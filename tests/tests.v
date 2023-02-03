module main

import utils { add_required_resources, capacity_from_args, ensure_no_error, ensure_node_has_claimed_resources, ensure_result_contains_u32, Test, TestEnvironment }
import freeflowuniverse.baobab.client { Client }
import freeflowuniverse.crystallib.params { Params }
import threefoldtech.farmerbot.factory { Farmerbot }
import threefoldtech.farmerbot.system

import flag
import os

fn test_find_node_required_resources(mut farmerbot Farmerbot, mut client Client) ! {
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
	ensure_node_has_claimed_resources(farmerbot.db.nodes[3], capacity_from_args(args)!)!
}

fn test_find_node_required_resources_selecting_second_node(mut farmerbot Farmerbot, mut client Client) ! {
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
	ensure_node_has_claimed_resources(farmerbot.db.nodes[5], capacity_from_args(args)!)!
}

fn test_find_node_with_public_ip(mut farmerbot Farmerbot, mut client Client) ! {
	// prepare
	mut args := Params {}
	add_required_resources(mut args, "500GB", "100GB", "4GB", "2")
	args.kwarg_add("publicip", "1")

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

fn test_find_node_dedicated(mut farmerbot Farmerbot, mut client Client) ! {
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

fn test_find_node_excluding_nodes(mut farmerbot Farmerbot, mut client Client) ! {
	// prepare
	mut args := Params {}
	// will fit on any node
	add_required_resources(mut args, "500GB", "100GB", "4GB", "2")
	// exclude nodes 3 and 5
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

fn test_find_node_certified(mut farmerbot Farmerbot, mut client Client) ! {
	// prepare
	mut args := Params {}
	// will fit on any node
	add_required_resources(mut args, "500GB", "100GB", "4GB", "2")
	// node with id 20 is also certified but is dedicated and we are
	// not asking for dedicated node nor asking for al resources
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

fn test_find_node_that_is_on_first(mut farmerbot Farmerbot, mut client Client) ! {
	// prepare
	farmerbot.db.nodes[3].powerstate = .off
	mut args := Params {}
	// can fit on node with id 3 but it is offline so it should be 5
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

	//assert
	ensure_no_error(&job)!
	ensure_result_contains_u32(&job, "nodeid", 5)!
}

fn test_find_node_with_everything(mut farmerbot Farmerbot, mut client Client) ! {
	// prepare
	mut args := Params {}
	// will fit on any node
	add_required_resources(mut args, "500GB", "100GB", "4GB", "2")
	args.kwarg_add("certified", "true")
	args.kwarg_add("dedicated", "1")
	args.kwarg_add("dedicated", "1")
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
	tests["find_node_with_required_resources_selecting_second_node"] = test_find_node_required_resources_selecting_second_node
	tests["find_node_that_is_on_first"] = test_find_node_that_is_on_first
	tests["find_node_with_public_ip"] = test_find_node_with_public_ip
	tests["find_node_dedicated"] = test_find_node_dedicated
	tests["find_node_excluding_nodes"] = test_find_node_excluding_nodes
	tests["find_node_certified"] = test_find_node_certified
	tests["find_node_with_everything"] = test_find_node_with_everything
	
	// ADD YOUR TESTS HERE
	mut testenvironment := TestEnvironment {
		tests: tests
	}
	testenvironment.run(debug_log)
}
