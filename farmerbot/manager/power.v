module manager

import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.client
import freeflowuniverse.baobab.jobs
import freeflowuniverse.crystallib.params { Params }
import threefoldtech.farmerbot.system { Capacity, ITfChain, IZos, Node }

import log
import time

const (
	power_manager_prefix = "[POWERMANAGER]"
	periodic_wakeup_interval = time.hour * 23
)

[heap]
pub struct PowerManager {
	name string = "farmerbot.powermanager"
mut:
	client client.Client
	db &system.DB
	logger &log.Logger
	tfchain &ITfChain
	zos &IZos
}

pub fn (mut p PowerManager) init(mut action actions.Action) ! {
	if action.name == system.action_power_configure {
		p.configure(mut action)!
	}
}

pub fn (mut p PowerManager) execute(mut job jobs.ActionJob) ! {
	if job.action == system.job_power_on {
		p.poweron(mut job)!
	}
	if job.action == system.job_power_off {
		p.poweroff(mut job)!
	}
}

pub fn (mut p PowerManager) update() {
	p.periodic_wakeup()
	p.power_management()
}

fn (mut p PowerManager) periodic_wakeup() {
	now := time.now()
	today := time.new_time(year: now.year, month: now.month, day: now.day)
	periodic_wakeup_start := today.add(p.db.periodic_wakeup_start)
	if periodic_wakeup_start <= now {
		for mut node in p.db.nodes.values().filter(it.powerstate == .off) {
			if node.last_time_awake < periodic_wakeup_start {
				p.schedule_power_job(node.id, .on) or {
					p.logger.error("${power_manager_prefix} Job to power on node ${node.id} failed.")
					continue
				}
				// reboot one at a time others will be rebooted 5 min later
				break
			}
		}
	}
}

fn (mut p PowerManager) power_management() {
	if p.db.nodes.values().filter(it.powerstate == .wakingup || it.powerstate == .shuttingdown).len > 0 {
		// in case one of the nodes is waking up or shutting down do nothing until the timeouts occur or the nodes are up or down.
		return 
	}
	used_resources, total_resources := p.calculate_resource_usage()
	if total_resources == 0 {
		return
	}
	resource_usage := 100 * used_resources / total_resources
	if resource_usage >= p.db.wake_up_threshold {
		sleeping_nodes := p.db.nodes.values().filter(it.powerstate == .off)
		if sleeping_nodes.len > 0 {
			node := sleeping_nodes.first()
			p.logger.info("${power_manager_prefix} Too much resource usage: ${resource_usage}. Turning on node ${node.id}")
			p.schedule_power_job(node.id, .on) or {
				p.logger.error("${power_manager_prefix} Job to power on node ${node.id} failed.")
			}
		}
	} else {
		nodes_able_to_shutdown := p.db.nodes.values().filter(it.powerstate == .on && it.is_unused())
		if nodes_able_to_shutdown.len > 1 {
			// shutdown a node if there is more then 1 unused node (aka keep at least one node online)
			node := nodes_able_to_shutdown.last()
			new_used_resources := (used_resources - node.resources.used.hru - node.resources.used.sru - node.resources.used.mru - node.resources.used.cru)
			new_total_resources := (total_resources - node.resources.total.hru - node.resources.total.sru - node.resources.total.mru - node.resources.total.cru)
			if 100 * new_used_resources / new_total_resources < p.db.wake_up_threshold {
				// we need to keep the resource percentage lower then the threshold
				p.logger.info("${power_manager_prefix} Resource usage too low: ${resource_usage}. Turning of unused node ${node.id}")
				p.schedule_power_job(node.id, .off) or {
					p.logger.error("${power_manager_prefix} Job to power off node ${node.id} failed.")
				}
			}
		}
	}
}

fn (mut p PowerManager) calculate_resource_usage() (u64, u64) {
	mut used_resources := Capacity {}
	mut total_resources := Capacity {}

	for node in p.db.nodes.values().filter(it.powerstate == .on) {
		used_resources.add(node.resources.used)
		total_resources.add(node.resources.total)
	}
	
	return (used_resources.cru + used_resources.hru + used_resources.mru + used_resources.sru), 
			(total_resources.cru + total_resources.hru + total_resources.mru + total_resources.sru)

}

fn (mut p PowerManager) nodeid_from_args(job &jobs.ActionJob) !u32 {
	nodeid := job.args.get_u32("nodeid") or {
		return error("The argument nodeid is required in order to power off a node")
	}
	if !(nodeid in p.db.nodes) {
		return error("The farmerbot is not managing the node with id ${nodeid}")
	}
	return nodeid
}

fn (mut p PowerManager) poweron(mut job jobs.ActionJob) ! {
	//make sure the node is powered on
	p.logger.info("${power_manager_prefix} Executing job: POWERON")

	nodeid := p.nodeid_from_args(&job)!

	if p.db.nodes[nodeid].powerstate == .wakingup ||
		p.db.nodes[nodeid].powerstate == .on {
		// nothing to do
		return
	}
	p.ensure_node_is_on_or_off(nodeid)!

	p.tfchain.set_node_power(nodeid, .on)!

	p.db.nodes[nodeid].powerstate = .wakingup
	p.db.nodes[nodeid].last_time_powerstate_changed = time.now()
}

fn (mut p PowerManager) poweroff(mut job jobs.ActionJob) ! {
	//make sure the node is powered off
	p.logger.info("${power_manager_prefix} Executing job: POWEROFF: ${p.tfchain}")

	nodeid := p.nodeid_from_args(&job)!

	if p.db.nodes[nodeid].powerstate == .shuttingdown ||
		p.db.nodes[nodeid].powerstate == .off {
		// nothing to do
		return
	}
	p.ensure_node_is_on_or_off(nodeid)!
	if p.db.nodes.values().filter(it.powerstate == .on).len < 2 {
		return error("Cannot power off node, at least one node should be on in the farm.")
	}

	p.tfchain.set_node_power(nodeid, .off)!

	p.db.nodes[nodeid].powerstate = .shuttingdown
	p.db.nodes[nodeid].last_time_powerstate_changed = time.now()
}

fn (p &PowerManager) ensure_node_is_on_or_off(nodeid u32) ! {
	if p.db.nodes[nodeid].powerstate == .wakingup {
		return error("Node is waking up")
	}
	if p.db.nodes[nodeid].powerstate == .shuttingdown {
		return error("Node is shutting down")
	}
}

fn (mut p PowerManager) schedule_power_job(nodeid u32, powerstate system.PowerState) ! {
	mut args := Params {}
	args.kwarg_add("nodeid", "${nodeid}")
	_ := p.client.job_new_wait(
		twinid: p.client.twinid,
		action: if powerstate == .on { system.job_power_on } else { system.job_power_off },
		args: args,
		actionsource: "")!
}

fn (mut p PowerManager) configure(mut action actions.Action) ! {
	mut wake_up_threshold := action.params.get_u8_default("wake_up_threshold", system.default_wake_up_threshold)!
	if wake_up_threshold < system.min_wake_up_threshold || wake_up_threshold > system.max_wake_up_threshold {
		wake_up_threshold = if wake_up_threshold < system.min_wake_up_threshold { u8(system.min_wake_up_threshold) } else { u8(system.max_wake_up_threshold) }
		p.logger.warn("${power_manager_prefix} The setting wake_up_threshold should be in the range [${system.min_wake_up_threshold}, ${system.max_wake_up_threshold}]")
	}

	periodic_wakeup_start := action.params.get_time_default("periodic_wakeup", time.hour * time.now().hour)!
	
	p.db.wake_up_threshold = wake_up_threshold
	p.db.periodic_wakeup_start = periodic_wakeup_start
}
