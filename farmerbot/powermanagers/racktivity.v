module powermanagers
import freeflowuniverse.crystallib.actionparser
import threefoldtech.farmerbot.system

[heap]
pub struct PowerManagerRacktivity{
}


pub fn (mut a PowerManagerRacktivity) execute(mut bot &system.DB, mut action &actionparser.Action) ! {
	if action.names()[1] == "define" {
		data_set(mut db, mut action)!
		action.params.get("powermanager")!
		action.params.get_u8("powermanager_port")!		
	}
}


//checks if the logic is relevant for this device
fn (mut a PowerManagerWakeOnLan) is_relevant(mut bot &system.DB, mut action &actionparser.Action) !bool {
	//logic for wakeonlan
	devicetype := action.params.get("devicetype")!
	if devicetype == "wol" {
		return true
	}
	return false
}

fn (mut a PowerManagerWakeOnLan) poweron(mut bot &system.DB, mut action &actionparser.Action) ! {
	powermanager := action.params.get("powermanager")!
	powermanager_port := action.params.get_u8("powermanager_port")!
}

fn (mut a PowerManagerWakeOnLan) poweroff(mut bot &system.DB, mut action &actionparser.Action) ! {
	//logic for wakeonlan
}

