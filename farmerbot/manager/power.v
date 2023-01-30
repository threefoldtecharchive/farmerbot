module manager

import freeflowuniverse.baobab.actions
import threefoldtech.farmerbot.system

import log

[heap]
pub struct PowerManager {
mut:
	logger &log.Logger
}

pub fn (mut m PowerManager) execute(mut db &system.DB, mut action &actions.Action) ! {
	if !(m.is_relevant(mut db, mut action)!) {
		return
	}
}

pub fn (mut m PowerManager) update(mut db &system.DB) ! {
	// TODO: shutdown nodes if need be
}

fn (mut m PowerManager) is_relevant(mut db &system.DB, mut action &actions.Action) !bool {
	// TODO: parse arguments and check if everything you need is available
	return false
}

fn (mut m PowerManager) poweron(mut db &system.DB, mut action &actions.Action) ! {
	//make sure the node is powered on
}

fn (mut m PowerManager) poweroff(mut db &system.DB, mut action &actions.Action) ! {
	//make sure the node is powered off
}
