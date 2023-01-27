module manager

import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.jobs

import threefoldtech.farmerbot.system

import log

[heap]
pub struct ResourceManager{
mut: 
	logger &log.Logger
}


pub fn (mut a ResourceManager) execute(mut db &system.DB, mut job &jobs.ActionJob) ! {
	if !(a.is_relevant(mut db, mut job)!) {
		return
	}
	if job.action == "farmerbot.resourcemanager.findnode" {

	}
}


fn (mut a ResourceManager) is_relevant(mut db &system.DB, mut job &jobs.ActionJob) !bool {
	if job.action.starts_with("farmerbot.resourcemanager") { 
		// TODO make sure all params are good
		return true
	}
	return false
}