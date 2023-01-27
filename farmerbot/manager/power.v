module manager

import freeflowuniverse.baobab.actions
import threefoldtech.farmerbot.system

import log

[heap]
pub struct PowerManager{
mut:
	logger &log.Logger
}

pub fn (mut a PowerManager) execute(mut db &system.DB, mut action &actions.Action) ! {
	if !(a.is_relevant(mut db, mut action)!) {
		return
	}
	if action.names()[1] == "define" {
		data_set(mut db, mut action)!
	}
	if action.names()[1] == "poweron" {
		a.poweron(mut db, mut action)!
	}	
	if action.names()[1] == "poweroff" {
		a.poweroff(mut db, mut action)!
	}		
}


//checks if the logic is relevant for this device
fn (mut a PowerManager) is_relevant(mut db &system.DB, mut action &actions.Action) !bool {
	//logic for wakeonlan
	devicetype := action.params.get("devicetype")!
	if devicetype == "wol" {
		return true
	}
	return false
}

fn (mut a PowerManager) poweron(mut db &system.DB, mut action &actions.Action) ! {
	//logic for wakeonlan
}

fn (mut a PowerManager) poweroff(mut db &system.DB, mut action &actions.Action) ! {
	//logic for wakeonlan
}
