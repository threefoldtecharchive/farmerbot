module manager

import freeflowuniverse.baobab.actions
import threefoldtech.farmerbot.system

import log

[heap]
pub struct NodeManager{
mut:
	logger &log.Logger
}

pub fn (mut n NodeManager) execute(mut db &system.DB, mut action &actions.Action) ! {
	if action.name == "farmerbot.node.define" {
		n.data_set(mut db, mut action)!
	}
}

fn (mut n NodeManager) data_set(mut db &system.DB, mut action &actions.Action) ! {
	n.logger.debug("${action.names()[1]}")
	mut node := system.Node {
		id: action.params.get_u32("id")!
		description: action.params.get_default("description", "")!
		farmid: action.params.get_u32("farmid")!
		capacity_available: system.Capacity {
			cru: action.params.get_u64("cru")!
			sru: action.params.get_kilobytes("sru")!
			mru: action.params.get_kilobytes("mru")!
			hru: action.params.get_kilobytes("hru")!
		}
		params: action.params
		powerstate: .on
	}

	db.nodes[node.id] = &node
}