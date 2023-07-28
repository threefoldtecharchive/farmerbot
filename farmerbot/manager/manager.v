module manager

import freeflowuniverse.baobab.actions { Action }
import freeflowuniverse.baobab.client
import freeflowuniverse.baobab.jobs
import threefoldtech.farmerbot.system
import log

// A manager is also an Actor in baobab

[heap]
pub interface Manager {
	name string
mut:
	client client.Client
	db &system.DB
	logger &log.Logger
	tfchain &system.ITfChain
	zos &system.IZos // executed once the farmerbot is started
	on_started()
	// executed on shutdown of the farmerbot
	on_stop()
	// is executed at initialization time
	init(mut action Action) !
	// execute a job
	execute(mut action jobs.ActionJob) !
	// this will be run every 5 minutes
	update()
}
