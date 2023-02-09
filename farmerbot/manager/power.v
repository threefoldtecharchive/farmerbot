module manager

import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.client
import freeflowuniverse.baobab.jobs
import freeflowuniverse.crystallib.params { Params }
import threefoldtech.farmerbot.system { Capacity, ITfChain, Node }

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
	tfchain &ITfChain
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
	mut used_resources := Capacity {}
	mut total_resources := Capacity {}
	mut nodes_to_shutdown := []&Node {}
	for node in p.db.nodes.values() {
		if node.powerstate == .wakingup || node.powerstate == .shuttingdown {
			// in case on of the nodes is waking up or shutting down do nothing until the timeouts occur or the the nodes are up or down.
			return
		}
		if node.powerstate == .on {
			if node.is_unused() {
				nodes_to_shutdown << node
			}
			used_resources.add(node.resources.used)
			total_resources.add(node.resources.total)
		}
	}
	sum_used_resources := (used_resources.cru + used_resources.hru + used_resources.mru + used_resources.sru)
	sum_total_resources := (total_resources.cru + total_resources.hru + total_resources.mru + total_resources.sru)
	if sum_total_resources == 0 {
		return
	}

	resources_usage := 100 * sum_used_resources / sum_total_resources
	if resources_usage >= p.db.wake_up_threshold {
		sleeping_nodes := p.db.nodes.values().filter(it.powerstate == .off)
		if sleeping_nodes.len > 0 {
			p.logger.info("${power_manager_prefix} Too much resource usage: ${resources_usage}. Turning on node ${sleeping_nodes[0].id}")
			p.schedule_power_job(sleeping_nodes[0].id, .on) or {
				p.logger.error("${power_manager_prefix} Job to power on node ${sleeping_nodes[0].id} failed.")
			}
		}
	} else if nodes_to_shutdown.len > 1 {
		// shutdown a node if there is more then 1 unused node (aka keep at least one node online)
		node := nodes_to_shutdown[nodes_to_shutdown.len-1]
		p.logger.info("${power_manager_prefix} Resource usage too low: ${resources_usage}. Turning of unused node ${node.id}")
		p.schedule_power_job(node.id, .off) or {
			p.logger.error("${power_manager_prefix} Job to power off node ${node.id} failed.")
		}
	}
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
	p.db.nodes[nodeid].powerstate_timeout = 6
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
	p.logger.info("Ok")
	p.tfchain.set_node_power(nodeid, .off)!
	p.logger.info("OK;")

	p.db.nodes[nodeid].powerstate = .shuttingdown
	p.db.nodes[nodeid].powerstate_timeout = 6
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

	p.db.wake_up_threshold = wake_up_threshold
}
