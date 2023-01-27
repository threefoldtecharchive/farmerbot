module manager

import freeflowuniverse.baobab.actions
import threefoldtech.farmerbot.system

import log

[heap]
pub struct NodeManager{
mut:
	logger &log.Logger
}


//init the data from the node and put in Database
// !!node.define
//     description:''
//     id:3
//     farmid:3
//     powermanager:'pwr1'
//     powermanager_port:0
pub fn (mut n NodeManager) execute(mut db &system.DB, mut action &actions.Action) ! {
	if action.names()[1] == "define" {
		n.data_set(mut db, mut action)!
	}
}

fn (mut n NodeManager) data_set(mut db &system.DB, mut action &actions.Action) ! {
	n.logger.debug("${action.names()[1]}")
	if action.names()[1] == "define" {
		mut node := system.Node{}
		node.id = action.params.get_u32("id")!
		node.description = action.params.get_default("description", "")!
		node.farmid = action.params.get_u32("farmid")!
		node.params = action.params
		db.nodes[node.id] = &node
	}
}