module system

import freeflowuniverse.crystallib.params
import freeflowuniverse.crystallib.twinclient as tw

pub enum FarmerbotState as u8 {
	stop
	start
}

pub struct Farm{
pub mut:
	id u32
	description string
	params params.Params
}

pub enum PowerState as u8 {
	on 
	off
}

pub struct Node{
pub mut:
	id u32
	twinid u32
	farmid u32
	description string
	certified bool
	dedicated bool
	publicip bool
	capacity_capability Capacity	   //capacity capability total on the node
	capacity_used Capacity
	cpu_load u8  					   //0..100 is percent in int about how heavy is CPU loaded
	powerstate PowerState
	//twinconnection tw.RmbTwinClient
}

pub fn (n &Node) can_claim_resources(cap &Capacity) bool {
	free := n.capacity_free()
	return free.cru >= cap.cru && free.mru >= cap.mru && free.hru >= cap.hru && free.sru >= cap.sru
}
pub fn (mut n Node) claim_resources(cap &Capacity) {
	n.capacity_used.add(cap)
}

pub fn (n &Node) capacity_free() Capacity {
	return n.capacity_capability - n.capacity_used
}

// for the capacity planning
// cru: virtual core
// mru: memory mbyte
// hru: memory gbyte
// sru: memory gbyte
pub struct Capacity{
pub mut:
	cru	 u64 
	sru  u64
	mru  u64
	hru  u64
}

pub fn (mut c Capacity) update(z &ZosStatistics) {
	c.cru = z.cru
	c.sru = z.sru
	c.mru = z.mru
	c.hru = z.mru
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
	return Capacity {
		cru: if a.cru >= b.cru { a.cru - b.cru } else { 0 }
		sru: if a.sru >= b.sru { a.sru - b.sru } else { 0 }
		mru: if a.mru >= b.mru { a.mru - b.mru } else { 0 }
		hru: if a.hru >= b.hru { a.hru - b.hru } else { 0 }
	}
}

[heap]
pub struct DB{
pub mut:
	nodes map[u32]&Node
	farms map[u32]&Farm
}