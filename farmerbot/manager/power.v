module manager

import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.client
import freeflowuniverse.baobab.jobs
import threefoldtech.farmerbot.system

import log

const (
	power_manager_prefix = "[POWERMANAGER]"
)

[heap]
pub struct PowerManager {
	name string = "farmerbot.powermanager"
mut:
	client client.Client
	db &system.DB
	logger &log.Logger
}

pub fn (mut p PowerManager) init(mut action actions.Action) ! {
	if action.name == system.action_power_configure {
		p.configure(mut action)!
	}
}

pub fn (mut p PowerManager) execute(mut job jobs.ActionJob) ! {
	// PowerManager is not executing jobs from outside yet
	if job.action == system.job_power_on {
		p.poweron(mut job)!
	}
}

pub fn (mut p PowerManager) update() ! {
	// TODO: shutdown nodes if they don't have used resources

	mut used_resources := system.Capacity {}
	mut total_resources := system.Capacity {}
	for node in p.db.nodes.values().filter(it.powerstate == .on) {
		used_resources.add(node.resources.used)
		total_resources.add(node.resources.total)
	}
	if (used_resources.cru + used_resources.hru + used_resources.mru + used_resources.sru) /
		(total_resources.cru + total_resources.hru + total_resources.mru + total_resources.sru) >= p.db.wake_up_threshold {
		// TODO wake up a sleeping node
	} else {
		// maybe we can shut down a node here
	}
}

fn (mut p PowerManager) poweron(mut job jobs.ActionJob) ! {
	//make sure the node is powered on
	p.logger.info("${power_manager_prefix} Executing job: POWERON")

}

fn (mut p PowerManager) poweroff(mut job jobs.ActionJob) ! {
	//make sure the node is powered off
}

fn (mut p PowerManager) configure(mut action actions.Action) ! {
	mut wake_up_threshold := action.params.get_u8_default("wake_up_threshold", 80)!
	if wake_up_threshold < 50 || wake_up_threshold > 100 {
		wake_up_threshold = if wake_up_threshold < 50 { u8(50) } else { u8(100) }
		p.logger.warn("${power_manager_prefix} The setting wake_up_threshold should be in the range [50, 100]")
	}

	p.db.wake_up_threshold = wake_up_threshold
}
