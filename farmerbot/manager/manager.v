module manager

import freeflowuniverse.baobab.actions
import threefoldtech.farmerbot.system

import log

pub interface Manager {
mut:
	logger &log.Logger

	//
	execute(mut db &system.DB, mut action &actions.Action) !
	// this will be ran every 5 minutes
	update(mut db &system.DB) !
}
