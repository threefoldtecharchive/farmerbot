module system

import math { ceil }
import time { Duration, Time }

pub const (
	default_wakeup_threshold      = 80
	default_periodic_wakeup_limit = 1
	min_wakeup_threshold          = 50
	max_wakeup_threshold          = 80
)

pub enum FarmerbotState as u8 {
	stop
	start
}

pub struct Farm {
pub mut:
	id          u32
	description string
	public_ips  u32
}

pub enum PowerState as u8 {
	on
	wakingup
	off
	shuttingdown
}

pub struct Node {
pub mut:
	id                           u32
	twinid                       u32
	farmid                       u32
	description                  string
	certified                    bool
	dedicated                    bool
	public_config                bool
	public_ips_used              u64
	resources                    ConsumableResources
	pools                        []ZosPool
	has_active_rent_contract     bool
	powerstate                   PowerState
	timeout_claimed_resources    Time
	last_time_powerstate_changed Time
	last_time_awake              Time
	never_shutdown               bool
}

pub fn (mut n Node) update_resources(zos_stats &ZosResourcesStatistics) {
	n.resources.total.update(zos_stats.total)
	n.resources.used.update(zos_stats.used)
	n.resources.system.update(zos_stats.system)
	n.public_ips_used = zos_stats.used.ipv4u
}

pub fn (n &Node) is_unused() bool {
	return (n.resources.used - n.resources.system).is_empty() && !n.has_active_rent_contract
}

pub fn (n &Node) can_claim_resources(cap &Capacity) bool {
	free := n.capacity_free()
	return n.resources.total.cru >= cap.cru && free.cru >= cap.cru && free.mru >= cap.mru
		&& free.hru >= cap.hru && free.sru >= cap.sru
}

pub fn (mut n Node) claim_resources(cap &Capacity) {
	n.resources.used.add(cap)
}

pub fn (n &Node) capacity_free() Capacity {
	mut total := n.resources.total
	total.cru = u64(ceil(f64(total.cru) * f64(n.resources.overprovision_cpu)))
	return total - n.resources.used
}

pub struct ConsumableResources {
pub mut:
	overprovision_cpu f32 // how much we allow overprovisioning the CPU range: [1;3]
	total             Capacity
	used              Capacity
	system            Capacity
}

pub struct Capacity {
pub mut:
	cru u64
	sru u64
	mru u64
	hru u64
}

pub fn (mut c Capacity) update(z &ZosResources) {
	c.cru = z.cru
	c.sru = z.sru
	c.mru = z.mru
	c.hru = z.hru
}

pub fn (mut c Capacity) add(other &Capacity) {
	c.cru += other.cru
	c.sru += other.sru
	c.mru += other.mru
	c.hru += other.hru
}

pub fn (c &Capacity) is_empty() bool {
	return c.cru == 0 && c.sru == 0 && c.mru == 0 && c.hru == 0
}

fn (a Capacity) - (b Capacity) Capacity {
	return Capacity{
		cru: if a.cru >= b.cru { a.cru - b.cru } else { 0 }
		sru: if a.sru >= b.sru { a.sru - b.sru } else { 0 }
		mru: if a.mru >= b.mru { a.mru - b.mru } else { 0 }
		hru: if a.hru >= b.hru { a.hru - b.hru } else { 0 }
	}
}

[heap]
pub struct DB {
pub mut:
	wake_up_threshold     u8 = system.default_wakeup_threshold
	periodic_wakeup_start Duration
	periodic_wakeup_end   Duration
	periodic_wakeup_limit u8 = system.default_periodic_wakeup_limit
	nodes                 map[u32]&Node
	farm                  &Farm
}

pub fn (d &DB) get_node(nodeid u32) !&Node {
	return d.nodes[nodeid] or {
		return error('The farmerbot is not managing the node with id ${nodeid}')
	}
}
