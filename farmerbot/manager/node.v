module manager

import freeflowuniverse.crystallib.twinclient as tw
import freeflowuniverse.baobab.actions
import threefoldtech.farmerbot.system

import json
import log


[heap]
pub struct NodeManager {
mut:
	logger &log.Logger

}

pub fn (mut n NodeManager) execute(mut db &system.DB, mut action &actions.Action) ! {
	if action.name == "farmerbot.node.define" {
		n.data_set(mut db, mut action)!
	}
}

pub fn (mut n NodeManager) update(mut db &system.DB) ! {
	// TODO Check if this works!
	for _, mut node in db.nodes {
		response := node.twinconnection.send("zos.statistics.get", "")!
		statistics := json.decode(system.ZosStatisticsGetResponse, response.data)!
		node.capacity_capability.update(statistics.total)
		node.capacity_used.update(statistics.used)
	}
}

fn (mut n NodeManager) data_set(mut db &system.DB, mut action &actions.Action) ! {
	n.logger.debug("${action.names()[1]}")
	twinid := action.params.get_u32("twinid")!
	mut twinconnection := tw.RmbTwinClient{}
	twinconnection.init([int(twinid)], 5, 5)!
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

	db.nodes[node.id] = &node
}