module manager

import freeflowuniverse.baobab.actions
import threefoldtech.farmerbot.system

import log

pub interface Manager {
mut:
	logger &log.Logger

	execute(mut db &system.DB, mut action &actions.Action) !
}
