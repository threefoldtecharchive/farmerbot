module manager

import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.client
import freeflowuniverse.baobab.jobs
import freeflowuniverse.crystallib.params { Params }
import threefoldtech.farmerbot.system { Capacity, Node }

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
	if job.action == system.job_power_on {
		p.poweron(mut job)!
	}
	if job.action == system.job_power_off {
		p.poweroff(mut job)!
	}
}

pub fn (mut p PowerManager) update() ! {
	p.handle_timeouts()
	p.do_power_management()!
}

fn (mut p PowerManager) handle_timeouts() {
	for mut node in p.db.nodes.values() {
		// PING the node to see if it is on
		_ := system.get_zos_system_version([node.twinid], 5) or {
			if node.powerstate == .wakingup {
				if node.powerstate_timeout > 1 {
					node.powerstate_timeout -= 1
					continue
				}
				// TODO maybe no longer use the node until it comes back on
				p.logger.error("Timeout on waking up the node with id ${node.id}. Putting its state back to off")
			}
			node.powerstate = .off
			continue
		}
		if node.powerstate == .shuttingdown {
			if node.powerstate_timeout > 1 {
				node.powerstate_timeout -= 1
				continue
			}
			p.logger.error("Timeout on shutting down the node with id ${node.id}. Putting its state back to on")
		}
		node.powerstate = .on
	}
}

fn (mut p PowerManager) do_power_management() ! {
	mut used_resources := Capacity {}
	mut total_resources := Capacity {}
	mut nodes_to_shutdown := []&Node {}
	mut nbr_nodes_on := 0
	for node in p.db.nodes.values() {
		if node.powerstate == .wakingup || node.powerstate == .shuttingdown {
			// in case on of the nodes is waking up or shutting down do nothing until the timeouts occur or the the nodes are up or down.
			return
		}
		if node.powerstate == .on {
			nbr_nodes_on += 1
			if node.is_unused() {
				nodes_to_shutdown << node
			}
			used_resources.add(node.resources.used)
			total_resources.add(node.resources.total)
		}
	}
	resources_usage := (used_resources.cru + used_resources.hru + used_resources.mru + used_resources.sru) / (total_resources.cru + total_resources.hru + total_resources.mru + total_resources.sru)
	if resources_usage >= p.db.wake_up_threshold {
		sleeping_nodes := p.db.nodes.values().filter(it.powerstate == .off)
		if sleeping_nodes.len > 0 {
			p.logger.info("Too much resource usage: ${resources_usage}. Turning on node ${sleeping_nodes[0].id}")
			p.schedule_power_job(sleeping_nodes[0].id, .on)!
		}
	} else if nbr_nodes_on >= 2 {
		// maybe we can shut down a node
		for node in nodes_to_shutdown {
			new_used := used_resources - node.resources.used
			new_total := total_resources - node.resources.total
			if (new_used.cru + new_used.hru + new_used.mru + new_used.sru) /
				(new_total.cru + new_total.hru + new_total.mru + new_total.sru) < p.db.wake_up_threshold {
				p.schedule_power_job(node.id, .off)!
				break				
			}
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

	// TODO: call the chain

	p.db.nodes[nodeid].powerstate = .wakingup
	p.db.nodes[nodeid].powerstate_timeout = 6
}

fn (mut p PowerManager) poweroff(mut job jobs.ActionJob) ! {
	//make sure the node is powered off
	p.logger.info("${power_manager_prefix} Executing job: POWEROFF")

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
	
	// TODO: call the chain
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
	_ := p.client.job_new_schedule(
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
