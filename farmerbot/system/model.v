module system

import freeflowuniverse.crystallib.params

pub struct Farm{
pub mut:
	id u32
	description string
	params params.Params
}

pub enum PowerState{
	on 
	off
}

pub struct Node{
pub mut:
	id u32
	farmid u32
	description string
	capacity_capability Capacity	   //capacity capability total on the node
	capacity_available Capacity  	   //capacity available free on the node
	cpu_load u8  					   //0..100 is percent in int about how heavy is CPU loaded
	params params.Params
	powerstate PowerState
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

[heap]
pub struct DB{
pub mut:
	nodes map[u32]&Node
	farms map[u32]&Farm
}


