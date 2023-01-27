module manager

import freeflowuniverse.baobab.actions
import threefoldtech.farmerbot.system

import log

[heap]
pub struct ResourceManager{
mut: 
	logger &log.Logger
}


pub fn (mut a ResourceManager) execute(mut db &system.DB, mut action &actions.Action) ! {
	if !(a.is_relevant(mut db, mut action)!) {
		return
	}
	if action.names()[1] == "define" {
		data_set(mut db, mut action)!
		action.params.get("powermanager")!
		action.params.get_u8("powermanager_port")!		
	}
}


//checks if the logic is relevant for this device
fn (mut a ResourceManager) is_relevant(mut db &system.DB, mut action &actions.Action) !bool {
	devicetype := action.params.get("devicetype")!
	if devicetype == "wol" {
		return true
	}
	return false
}