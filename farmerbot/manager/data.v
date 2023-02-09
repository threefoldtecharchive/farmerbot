module manager

import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.client
import freeflowuniverse.baobab.jobs
import threefoldtech.farmerbot.system { ITfChain, Node }

import log

const (
	data_manager_prefix = "[DATAMANAGER]"
)

[heap]
pub struct DataManager {
	name string = "farmerbot.datamanager"

mut:
	client client.Client
	db &system.DB
	logger &log.Logger
	tfchain &ITfChain
}

pub fn (mut d DataManager) init(mut action actions.Action) ! {
}

pub fn (mut d DataManager) execute(mut job jobs.ActionJob) ! {
}

pub fn (mut d DataManager) update() {
	for nodeid in d.db.nodes.keys() {
		if !d.ping_node(nodeid) {
			continue
		}

		d.update_node_data(nodeid)
	}
}

fn (mut d DataManager) ping_node(nodeid u32) bool {
	mut node := d.db.nodes[nodeid]
	_ := system.get_zos_system_version(node.twinid, 5) or {
		if node.powerstate == .wakingup {
			if node.powerstate_timeout > 1 {
				node.powerstate_timeout -= 1
				return false
			}
			// TODO maybe no longer use the node until it comes back on
			d.logger.error("${data_manager_prefix} Timeout on waking up the node with id ${node.id}. Putting its state back to off")
		}
		node.powerstate = .off
		return false
	}
	if node.powerstate == .shuttingdown {
		if node.powerstate_timeout > 1 {
			node.powerstate_timeout -= 1
			return false
		}
		d.logger.error("${data_manager_prefix} Timeout on shutting down the node with id ${node.id}. Putting its state back to on")
	}
	d.logger.debug("${data_manager_prefix} PING to node ${node.id} was successful.")
	node.powerstate = .on
	return true
}

fn (mut d DataManager) update_node_data(nodeid u32) {
	mut node := d.db.nodes[nodeid]
	stats := system.get_zos_statistics(node.twinid, timeout_zos_rmb_requests) or {
		d.logger.error("${data_manager_prefix} Failed to update statistics of node ${node.id}: $err")
		return
	}
	node.update_resources(stats)
	node.public_config = system.zos_has_public_config(node.twinid, timeout_zos_rmb_requests) or {
		d.logger.error("${data_manager_prefix} Failed to update public config of node ${node.id}: $err")
		return
	}

	d.logger.debug("${data_manager_prefix} capacity updated for node:\n$node")
}