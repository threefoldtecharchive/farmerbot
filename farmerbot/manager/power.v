module manager

import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.client
import freeflowuniverse.baobab.jobs
import threefoldtech.farmerbot.system

import log

[heap]
pub struct PowerManager {
	name string = "powermanager"
mut:
	client &client.Client
	db &system.DB
	logger &log.Logger
}

pub fn (mut p PowerManager) init(mut action &actions.Action) ! {

}

pub fn (mut p PowerManager) execute(mut job &jobs.ActionJob) ! {
	// PowerManager is not executing jobs from outside yet
}

pub fn (mut p PowerManager) update() ! {
	// TODO: shutdown nodes if they don't have used resources
}

fn (mut p PowerManager) poweron(mut job &jobs.ActionJob) ! {
	//make sure the node is powered on
}

fn (mut p PowerManager) poweroff(mut job &jobs.ActionJob) ! {
	//make sure the node is powered off
}
