module manager

import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.client
import freeflowuniverse.baobab.jobs
import threefoldtech.farmerbot.system { ITfChain, IZos, Node }

import log
import time

const (
	data_manager_prefix = "[DATAMANAGER]"
	timeout_powerstate_change = time.minute * 30
)

[heap]
pub struct DataManager {
	name string = "farmerbot.datamanager"

mut:
	client client.Client
	db &system.DB
	logger &log.Logger
	tfchain &ITfChain
	zos &IZos
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
	_ := d.zos.get_zos_system_version(node.twinid) or {
		// No response from ZOS node: if the state is waking up we wait for either the node to come up or the
		// timeout to hit. If the time out hits we change the state to off (AKA unsuccessful wakeup)
		// If the state was not waking up the node is considered off
		match node.powerstate {
			.wakingup {
				if time.since(node.last_time_powerstate_changed) < timeout_powerstate_change {
					d.logger.debug("${data_manager_prefix} Node ${node.id} is waking up.")
					return false
				}
				d.logger.error("${data_manager_prefix} Node ${node.id} wakeup was unsuccessful. Putting its state back to off.")
			}
			.shuttingdown {
				d.logger.debug("${data_manager_prefix} Node ${node.id} shutdown was successful.")
			}
			.on {
				d.logger.error("${data_manager_prefix} Node ${node.id} is not responding while we expect it to!")
			}
			else {
				d.logger.error("${data_manager_prefix} Node ${node.id} is offline.")
			}
		}
		node.powerstate = .off
		node.last_time_powerstate_changed = time.now()
		return false
	}
	// We got a response from ZOS: it is still online. If the powerstate is shutting down
	// we check if the timeout has not exceeded yet. If it has we consider the attempt to shutting
	// down the down a failure and set teh powerstate back to on
	if node.powerstate == .shuttingdown {
		if time.since(node.last_time_powerstate_changed) < timeout_powerstate_change {
			d.logger.debug("${data_manager_prefix} Node ${node.id} is shutting down.")
			return false
		}
		d.logger.error("${data_manager_prefix} Node ${node.id} shutdown was unsuccessful. Putting its state back to on.")
	} else {
		d.logger.debug("${data_manager_prefix} Node ${node.id} is online.")
	}
	node.powerstate = .on
	node.last_time_powerstate_changed = time.now()
	node.last_time_awake = time.now()
	return true
}

fn (mut d DataManager) update_node_data(nodeid u32) {
	mut node := d.db.nodes[nodeid]
	if node.timeout_claimed_resources == 0 {
		stats := d.zos.get_zos_statistics(node.twinid) or {
			d.logger.error("${data_manager_prefix} Failed to update statistics of node ${node.id}: $err")
			return
		}
		node.update_resources(stats)
	} else {
		node.timeout_claimed_resources -= 1
	}
	node.public_config = d.zos.zos_has_public_config(node.twinid) or {
		d.logger.error("${data_manager_prefix} Failed to update public config of node ${node.id}: $err")
		return
	}
	node.wg_ports = d.zos.get_zos_wg_ports(node.twinid) or {
		d.logger.error("${data_manager_prefix} Failed to update the wireguard ports used by node ${node.id}: $err")
		return
	}
	d.logger.debug("${data_manager_prefix} Capacity updated for node ${node.id}:\n${node.resources}")
}