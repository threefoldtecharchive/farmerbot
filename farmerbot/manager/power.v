module manager

import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.jobs
import threefoldtech.farmerbot.system

import log

[heap]
pub struct PowerManager{
mut:
	logger &log.Logger
}

pub fn (mut a PowerManager) execute(mut db &system.DB, mut job &jobs.ActionJob) ! {
	if !(a.is_relevant(mut db, mut job)!) {
		return
	}	
}


//checks if the logic is relevant for this device
fn (mut a PowerManager) is_relevant(mut db &system.DB, mut job &jobs.ActionJob) !bool {
	return false
}

fn (mut a PowerManager) poweron(mut db &system.DB, mut job &jobs.ActionJob) ! {
	//logic for wakeonlan
}

fn (mut a PowerManager) poweroff(mut db &system.DB, mut job &jobs.ActionJob) ! {
	//logic for wakeonlan
}
