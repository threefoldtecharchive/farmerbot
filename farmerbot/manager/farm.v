module manager

import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.client
import freeflowuniverse.baobab.jobs
import threefoldtech.farmerbot.system

import log

const (
	farm_manager_prefix = "[FARMMANAGER]"
)

[heap]
pub struct FarmManager {
	name string = "farmerbot.farmmanager"

mut:
	client client.Client
	db &system.DB
	logger &log.Logger
	tfchain &system.ITfChain
	zos &system.IZos
}

pub fn (mut f FarmManager) init(mut action actions.Action) ! {
	if action.name == system.action_farm_define {
		f.data_set(mut action)!
	}
}

pub fn (mut f FarmManager) execute(mut job jobs.ActionJob) ! {
	if job.action == system.job_farm_version {
		f.get_version(mut job)!
	}
}

pub fn (mut f FarmManager) update() {
}

fn (mut f FarmManager) data_set(mut action actions.Action) ! {
	f.logger.info("${farm_manager_prefix} Executing action: DATA_SET")
	f.logger.debug("${farm_manager_prefix} $action")

	mut farm := &system.Farm {
	 	id: action.params.get_u32("id")!
	 	description: action.params.get_default("description", "")!
	 	public_ips: action.params.get_u32_default("public_ips", 0)!
	}

	f.db.farm = farm
}

fn (mut f FarmManager) get_version(mut job jobs.ActionJob) ! {
	f.logger.info("${farm_manager_prefix} Executing job: GET_VERSION}")
	f.logger.debug("${farm_manager_prefix} $job")
	job.result.kwarg_add("version", system.version)
}