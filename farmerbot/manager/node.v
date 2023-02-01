module manager

import freeflowuniverse.crystallib.twinclient as tw
import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.client
import freeflowuniverse.baobab.jobs
import threefoldtech.farmerbot.system

import json
import log

const (
	node_manager_prefix = "[NODEMANAGER]"
	timeout_zos_rmb_requests = 5
	retries_zos_rmb_requests = 5
)

[heap]
pub struct NodeManager {
	name string = "farmerbot.nodemanager"
	
mut:
	client &client.Client
	db &system.DB
	logger &log.Logger
}

pub fn (mut n NodeManager) init(mut action &actions.Action) ! {
	if action.name == system.action_node_define {
		n.data_set(mut action)!
	}
}

pub fn (mut n NodeManager) execute(mut job &jobs.ActionJob) ! {
	if job.action == system.job_node_find {
		n.find_node(mut job)!
	}
}

pub fn (mut n NodeManager) update() ! {
	// Update the resources by asking ZOS
	// TODO experiment with multiple threads
	for _, mut node in n.db.nodes {
		response := node.twinconnection.send("zos.statistics.get", "") or {
			n.logger.error("${node_manager_prefix} Failed getting resources from ZOS node: ${err}")
			continue
		}
		statistics := json.decode(system.ZosStatisticsGetResponse, response.data)!
		node.capacity_capability.update(statistics.total)
		node.capacity_used.update(statistics.used)
	}
}

fn (mut n NodeManager) data_set(mut action &actions.Action) ! {
	n.logger.info("${node_manager_prefix} Executing action: DATA_SET")
	n.logger.debug("${node_manager_prefix} $action")
	twinid := action.params.get_u32("twinid")!
	mut twinconnection := tw.RmbTwinClient{}
	twinconnection.init([int(twinid)], timeout_zos_rmb_requests, retries_zos_rmb_requests)!
	mut node := system.Node {
		id: action.params.get_u32("id")!
		twinid: twinid
		description: action.params.get_default("description", "")!
		farmid: action.params.get_u32("farmid")!
		capacity_capability: system.Capacity {
			cru: action.params.get_u64("cru")!
			sru: action.params.get_kilobytes("sru")!
			mru: action.params.get_kilobytes("mru")!
			hru: action.params.get_kilobytes("hru")!
		}
		params: action.params
		powerstate: .on
		twinconnection: twinconnection
	}

	n.db.nodes[node.id] = &node
}

fn (mut n NodeManager) find_node(mut job &jobs.ActionJob) ! {
	n.logger.info("${node_manager_prefix} Executing job: FIND_NODE")
	n.logger.debug("${node_manager_prefix} $job")

	// Parse args
	certified := job.args.get_default_false("certified")
	publicip := job.args.get_default_false("publicip")
	dedicated := job.args.get_default_false("dedicated")
	node_exclude := job.args.get_list_u32("node_exclude")!
	required_hru := job.args.get_kilobytes_default("required_hru", 0)!
	required_sru := job.args.get_kilobytes_default("required_sru", 0)!
	required_mru := job.args.get_kilobytes_default("required_mru", 0)!
	required_cru := job.args.get_u64_default("required_cru", 0)!
	
	// Lets find a node
	mut possible_nodes := n.db.nodes.values()
	if certified {
		// Keep certified nodes
		possible_nodes = possible_nodes.filter(it.certified)
	}
	if publicip {
		// Keep nodes with public ip
		possible_nodes = possible_nodes.filter(it.publicip)
	}
	if node_exclude.len > 0 {
		// Exclude the nodes that the user doesn't want
		possible_nodes = possible_nodes.filter(!(it.id in node_exclude))
	}
	// Keep nodes with enough resources
	possible_nodes = possible_nodes.filter(
		it.can_claim_resources(system.Capacity{ 
				hru: required_hru, 
				mru: required_mru, 
				cru: required_cru, 
				sru: required_sru 
		})
	)
	// Sort the nodes on power state (the ones that are ON first)
	possible_nodes.sort_with_compare(fn (a &&system.Node, b &&system.Node) int {
         if a.powerstate == b.powerstate {
             return 0
         } else if u8(a.powerstate) < u8(b.powerstate) {
             return -1
         } else {
             return 1
        }
    })

	if possible_nodes.len == 0 {
		return error("Could not find a suitable node")
	}

	// Return the node 
	n.logger.debug("Found a node: ${possible_nodes[0]}")
	job.result.kwarg_add("nodeid", "${possible_nodes[0].id}")

	if possible_nodes[0].powerstate == system.PowerState.off {
		_ := n.client.job_new_schedule(
			twinid: job.twinid,
			action: system.job_power_on,
			args: job.result,
			actionsource: system.job_node_find)!
	}
}