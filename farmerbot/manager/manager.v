module manager

import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.client
import freeflowuniverse.baobab.jobs
import threefoldtech.farmerbot.system

import log

// A manager is also an Actor in baobab
pub interface Manager {
	name string
mut:
	client &client.Client
	db &system.DB
	logger &log.Logger

	// is executed at initialization time
	init(mut action &actions.Action) !
	// execute a job
	execute(mut action &jobs.ActionJob) !
	// this will be run every 5 minutes
	update() !
}