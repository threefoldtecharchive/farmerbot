module manager

import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.client
import freeflowuniverse.baobab.jobs
import threefoldtech.farmerbot.system { ITfChain, IZos }
import log
import time

const (
	data_manager_prefix       = '[DATAMANAGER]'
	timeout_powerstate_change = time.minute * 30
)

[heap]
pub struct DataManager {
	name string = 'farmerbot.datamanager'
mut:
	client  client.Client
	db      &system.DB
	logger  &log.Logger
	tfchain &ITfChain
	zos     &IZos
	timeout_rmb_response u64 = 120 // nodes have 2 minutes to respond to the requests
}

pub fn (mut d DataManager) on_started() {
	mut node_twin_ids := d.db.nodes.values().map(it.twin_id)
	d.batch_ping_nodes(node_twin_ids)
	d.handle_responses(mut node_twin_ids)
}

pub fn (mut d DataManager) on_stop() {
	
}

pub fn (mut d DataManager) init(mut action actions.Action) ! {
	d.logger.warn('${manager.data_manager_prefix} Unknown action ${action.name}')
}

pub fn (mut d DataManager) execute(mut job jobs.ActionJob) ! {
}

pub fn (mut d DataManager) update() {
	mut node_twin_ids := d.db.nodes.values().map(it.twin_id)
	// update resources for nodes that have no claimed resources
	update_resources_node_ids := d.db.nodes.values().filter(it.timeout_claimed_resources <= time.now()).map(it.id)
	update_resources_twin_ids := d.db.nodes.values().filter(it.timeout_claimed_resources <= time.now()).map(it.twin_id)
	// we ping all nodes (even the ones with claimed resources)
	d.batch_ping_nodes(node_twin_ids)
	// we do not update the resources for the nodes that have claimed resources because those resources should not be overwritten until the timeout
	d.batch_get_statistics(update_resources_twin_ids)
	d.batch_get_storage_pools(update_resources_twin_ids)
	d.batch_has_public_config(update_resources_twin_ids)
	d.batch_update_has_rent_contract(update_resources_node_ids)
	// handle all responses and modify state of the nodes
	d.handle_responses(mut node_twin_ids)
}

fn (mut d DataManager) batch_ping_nodes(node_twin_ids []u32) {
	d.zos.get_system_version(node_twin_ids, d.timeout_rmb_response) or {
		d.logger.error('${manager.data_manager_prefix} Failed send get_system_version message: ${err}')
		return
	}
}

fn (mut d DataManager) batch_get_statistics(node_twin_ids []u32) {
	d.zos.get_statistics(node_twin_ids, d.timeout_rmb_response) or {
		d.logger.error('${manager.data_manager_prefix} Failed send get_zos_statistics message: ${err}')
		return
	}
}

fn (mut d DataManager) batch_get_storage_pools(node_twin_ids []u32) {
	d.zos.get_storage_pools(node_twin_ids, d.timeout_rmb_response) or {
		d.logger.error('${manager.data_manager_prefix} Failed send get_storage_pools message: ${err}')
		return
	}
}

fn (mut d DataManager) batch_has_public_config(node_twin_ids []u32) {
	d.zos.has_public_config(node_twin_ids, d.timeout_rmb_response) or {
		d.logger.error('${manager.data_manager_prefix} Failed send has_public_config message: ${err}')
		return
	}
}

// update if they have rent contract (done through tfchain)
fn (mut d DataManager) batch_update_has_rent_contract(node_ids []u32) {
	for node_id in node_ids {
		mut node := d.db.nodes[node_id] or {
			d.logger.error('${manager.data_manager_prefix} Unknown node_id ${node_id}')
			continue
		}
		rent_contract := d.tfchain.active_rent_contract_for_node(node_id) or {
			d.logger.error('${manager.data_manager_prefix} Failed to update active rent contract ${node_id}: ${err}')
			return
		}
		node.has_active_rent_contract = rent_contract != 0
	}
}

fn (mut d DataManager) handle_responses(mut node_twin_ids []u32) {
	// check for incoming message from RMB
	start := time.now()
	for time.now()-start <= time.second * int(d.timeout_rmb_response) {
		select {
			message := <-d.zos.messages {
				mut node := d.db.get_node_by_twin_id(message.src.u32()) or {
					d.logger.error('${manager.data_manager_prefix} ${err}')
					continue
				}
				match message.cmd {
					'zos.system.version' {
						message.parse_system_version() or {
							continue
						}
					}
					'zos.network.public_config_get' {
						node.public_config = message.parse_has_public_config() or {
							d.logger.error('${manager.data_manager_prefix} Failed to update public config of node ${node.id}: ${err}')
							continue
						}
					}
					'zos.statistics.get' {
						stats := message.parse_statistics() or {
							d.logger.error('${manager.data_manager_prefix} Failed to update statistics of node ${node.id}: ${err}')
							continue
						}
						node.update_resources(stats)
					}
					'zos.storage.pools' {
						storage_pools := message.parse_storage_pools() or {
							d.logger.error('${manager.data_manager_prefix} Failed to update storage pools ${node.id}: ${err}')
							continue
						}
						node.pools = storage_pools
					}
					else {
						d.logger.warn('${manager.data_manager_prefix} Unknown command ${message.cmd}')
					}
				}
				// remove from list so that we know which nodes we were able to contact
				node_twin_ids = node_twin_ids.filter(it != node.twin_id)
			}
			1 * time.second {
			}
		}
	}

	// update state: if we didn't get any response => node is offline
	for node in d.db.nodes.values() {
		if node.twin_id in node_twin_ids {
			// got no messages from that node
			d.update_powerstate(node.id, false)
		} else {
			// got at least one message from that node
			d.update_powerstate(node.id, true)
		}
	}
}

fn (mut d DataManager) update_powerstate(node_id u32, got_response bool) {
	mut node := d.db.nodes[node_id] or {
		d.logger.error('${manager.data_manager_prefix} Unknown node_id ${node_id}')
		return
	}
	if !got_response {
		// No response from ZOS node: if the state is waking up we wait for either the node to come up or the
		// timeout to hit. If the time out hits we change the state to off (AKA unsuccessful wakeup)
		// If the state was not waking up the node is considered off
		match node.powerstate {
			.wakingup {
				if time.since(node.last_time_powerstate_changed) < manager.timeout_powerstate_change {
					d.logger.info('${manager.data_manager_prefix} Node ${node.id} is waking up.')
					return
				}
				d.logger.error('${manager.data_manager_prefix} Node ${node.id} wakeup was unsuccessful. Putting its state back to off.')
			}
			.shuttingdown {
				d.logger.info('${manager.data_manager_prefix} Node ${node.id} shutdown was successful.')
			}
			.on {
				d.logger.error('${manager.data_manager_prefix} Node ${node.id} is not responding while we expect it to.')
			}
			else {
				d.logger.info('${manager.data_manager_prefix} Node ${node.id} is OFF.')
			}
		}
		if node.powerstate != .off {
			node.last_time_powerstate_changed = time.now()
		}
		node.powerstate = .off
		return
	}
	// We got a response from ZOS: it is still online. If the powerstate is shutting down
	// we check if the timeout has not exceeded yet. If it has we consider the attempt to shutting
	// down the down a failure and set teh powerstate back to on
	if node.powerstate == .shuttingdown {
		if time.since(node.last_time_powerstate_changed) < manager.timeout_powerstate_change {
			d.logger.info('${manager.data_manager_prefix} Node ${node.id} is shutting down.')
			return
		}
		d.logger.error('${manager.data_manager_prefix} Node ${node.id} shutdown was unsuccessful. Putting its state back to on.')
	} else {
		d.logger.info('${manager.data_manager_prefix} Node ${node.id} is ON.')
	}
	d.logger.debug('${manager.data_manager_prefix} Capacity updated for node ${node.id}:\n${node.resources}\n${node.pools}\nhas_active_rent_contract: ${node.has_active_rent_contract}')
	if node.powerstate != .on {
		node.last_time_powerstate_changed = time.now()
	}
	node.powerstate = .on
	node.last_time_awake = time.now()
}