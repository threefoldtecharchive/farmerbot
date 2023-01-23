module actor_notary
import freeflowuniverse.crystallib.params


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

enum PowerState{
	on 
	off
}


// for the capacity planning
// cru: virtual core
// mru: memory mbyte
// hru: memory gbyte
// sru: memory gbyte
pub struct Capacity{
pub mut:
	cru	 u32 
	sru  u32
	mru  u32
	hru  u32
}



// pub fn node_get(id u32){
// 	mut node := FarmerBotNode{}
// 	node.description = job.params.get_default("description","")!
// 	node.farmid = job.params.get_u32("farmid")!
// 	node.params = job.params
// 	params.get("powermanager")!
// 	params.get_u8("powermanager_port")!	
// }


