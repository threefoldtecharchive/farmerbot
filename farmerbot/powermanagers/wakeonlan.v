module powermanagers
import freeflowuniverse.crystallib.actionparser
import threefoldtech.farmerbot.system


[heap]
pub struct PowerManagerWakeOnLan{
}

pub fn (mut a PowerManagerWakeOnLan) execute(mut db &system.DB, mut action &actionparser.Action) !{
	if ! (a.is_relevant(mut db,mut action)){
		return
	}
	if action.names()[1]=="define"{
		data_set(mut db,mut action)!
	}
	if action.names()[1]=="poweron"{
		a.poweron(mut db,mut action)!
	}	
	if action.names()[1]=="poweroff"{
		a.poweroff(mut db,mut action)!
	}		
}


//checks if the logic is relevant for this device
fn (mut a PowerManagerWakeOnLan) is_relevant(mut bot &system.DB, mut action &actionparser.Action) !bool{
	//logic for wakeonlan
	devicetype := action.params.get("devicetype")!
	if devicetype=="wol"{
		return true
	}
	return false
}

fn (mut a PowerManagerWakeOnLan) poweron(mut bot &system.DB, mut action &actionparser.Action) !{
	//logic for wakeonlan
}

fn (mut a PowerManagerWakeOnLan) poweroff(mut bot &system.DB, mut action &actionparser.Action) !{
	//logic for wakeonlan
}
