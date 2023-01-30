module actor

import freeflowuniverse.baobab.jobs
import freeflowuniverse.crystallib.twinclient as tw
import threefoldtech.farmerbot.system

import log

[heap]
pub struct FarmerbotActor {
mut:
	db &system.DB
	logger &log.Logger
}

pub fn (mut f FarmerbotActor) execute(mut db &system.DB, mut job &jobs.ActionJob) ! {
	if !(f.is_relevant(mut db, mut job)!) {
		return
	}
	if job.action == system.action_find_node {
		
	}
}

pub fn (mut f FarmerbotActor) run() {

}

fn (mut m FarmerbotActor) is_relevant(mut db &system.DB, mut job &jobs.ActionJob) !bool {
	// TODO: parse arguments and check if everything you need is available
	return true
}


pub fn new_farmerbotactor(mut db &system.DB) !FarmerbotActor {
	return FarmerbotActor {
		db: db
		logger: system.logger()
	}
}

// ZOS command for getting resources: zos.statistics.get
// https://github.com/threefoldtech/zos/blob/main/client/node.go#L167