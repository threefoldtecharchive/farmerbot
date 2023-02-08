module manager

import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.client
import freeflowuniverse.baobab.jobs
import threefoldtech.farmerbot.system

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
	client client.Client
	db &system.DB
	logger &log.Logger
}

pub fn (mut n NodeManager) init(mut action actions.Action) ! {
	if action.name == system.action_node_define {
		n.data_set(mut action)!
	}
}

pub fn (mut n NodeManager) execute(mut job jobs.ActionJob) ! {
	if job.action == system.job_node_find {
		n.find_node(mut job)!
	}
}

pub fn (mut n NodeManager) update() ! {
	// Update the resources by asking ZOS
	for _, mut node in n.db.nodes {
		stats := system.get_zos_statistics([node.twinid], timeout_zos_rmb_requests) or {
			n.logger.error("${node_manager_prefix} Failed getting resources from ZOS node: ${err}")
			continue
		}
		node.update_resources(stats)
		node.public_config = system.zos_has_public_config([node.twinid], timeout_zos_rmb_requests) or {
			n.logger.error("${node_manager_prefix} Failed getting publicip from ZOS node: ${err}")
			continue
		}

		n.logger.debug("${node_manager_prefix} capacity updated for node:\n$node")
	}
}

fn (mut n NodeManager) data_set(mut action actions.Action) ! {
	n.logger.info("${node_manager_prefix} Executing action: DATA_SET")
	n.logger.debug("${node_manager_prefix} $action")

	twinid := action.params.get_u32("twinid")!
	cpu_overprovision := action.params.get_u8_default("cpuoverprovision", 1)!
	if cpu_overprovision < 1 || cpu_overprovision > 4 {
		return error("cpuoverprovision should be a value between 1 and 4")
	}
	mut node := system.Node {
		id: action.params.get_u32("id")!
		twinid: twinid
		description: action.params.get_default("description", "")!
		resources: system.ConsumableResources{
			overprovision_cpu: cpu_overprovision
			total: system.Capacity {
				cru: action.params.get_u64_default("cru", 0)!
				sru: action.params.get_kilobytes_default("sru", 0)!
				mru: action.params.get_kilobytes_default("mru", 0)!
				hru: action.params.get_kilobytes_default("hru", 0)!
			}
		}
		public_config: action.params.get_default_false("public_config")
		dedicated: action.params.get_default_false("dedicated")
		certified: action.params.get_default_false("certified")
		powerstate: .on
	}

	n.db.nodes[node.id] = &node
}

fn (mut n NodeManager) find_node(mut job jobs.ActionJob) ! {
	n.logger.info("${node_manager_prefix} Executing job: FIND_NODE")
	n.logger.debug("${node_manager_prefix} $job")

	// Parse args
	certified := job.args.get_default_false("certified")
	public_config := job.args.get_default_false("public_config")
	public_ips := job.args.get_u32_default("public_ips", 0)!
	dedicated := job.args.get_default_false("dedicated")
	node_exclude := job.args.get_list_u32("node_exclude")!
	required_capacity := system.Capacity {
		hru: job.args.get_kilobytes_default("required_hru", 0)!
		sru: job.args.get_kilobytes_default("required_sru", 0)!
		mru: job.args.get_kilobytes_default("required_mru", 0)!
		cru: job.args.get_u64_default("required_cru", 0)!
	}
	
	// Lets find a node
	mut possible_nodes := n.db.nodes.values()
	if public_ips > 0 {
		mut public_ips_used_by_nodes := u64(0)
		for node in n.db.nodes.values() {
			public_ips_used_by_nodes += node.public_ips_used
		}
		if public_ips_used_by_nodes + public_ips > n.db.farm.public_ips {
			return error("No more public ips available")
		}
	}
	if certified {
		// Keep certified nodes
		possible_nodes = possible_nodes.filter(it.certified)
	}
	if public_config {
		// Keep nodes with public ip
		possible_nodes = possible_nodes.filter(it.public_config)
	}
	if dedicated {
		// Keep dedicated nodes only AKA rent the full node
		possible_nodes = possible_nodes.filter(it.dedicated && it.is_unused())
	} else {
		// Don't care if it is dedicated. Though if the node is dedicated we have to rent the full node!
		possible_nodes = possible_nodes.filter(!it.dedicated || required_capacity == it.resources.total)
	}
	if node_exclude.len > 0 {
		// Exclude the nodes that the user doesn't want
		possible_nodes = possible_nodes.filter(!(it.id in node_exclude))
	}
	// Keep nodes with enough resources
	possible_nodes = possible_nodes.filter(
		it.can_claim_resources(required_capacity)
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

	n.logger.debug("Found a node: ${possible_nodes[0]}")
	// claim the resources until next update of the data
	if dedicated {
		// claim all capacity
		possible_nodes[0].claim_resources(possible_nodes[0].resources.total)
	} else {
		possible_nodes[0].claim_resources(required_capacity)
	}
	// claim public ips until next update of the data
	if public_ips > 0 {
		possible_nodes[0].public_ips_used += public_ips
	}
	// Result
	job.result.kwarg_add("nodeid", "${possible_nodes[0].id}")

	if possible_nodes[0].powerstate == system.PowerState.off {
		_ := n.client.job_new_schedule(
			twinid: job.twinid,
			action: system.job_power_on,
			args: job.result,
			actionsource: system.job_node_find)!
	}
}