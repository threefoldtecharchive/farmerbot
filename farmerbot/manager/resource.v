module manager

import freeflowuniverse.baobab.actions
import threefoldtech.farmerbot.system

import log

[heap]
pub struct ResourceManager {
mut: 
	logger &log.Logger
}


pub fn (mut a ResourceManager) execute(mut db &system.DB, mut action &actions.Action) ! {
	if !(a.is_relevant(mut db, mut action)!) {
		return
	}
	if action.name == system.action_find_node {
		
	}
}

pub fn (mut m ResourceManager) update(mut db &system.DB) ! {
	
}

fn (mut a ResourceManager) is_relevant(mut db &system.DB, mut action &actions.Action) !bool {
	if action.name.starts_with("farmerbot.resourcemanager") { 
		// TODO make sure all params are good
		return true
	}
	return false
}

