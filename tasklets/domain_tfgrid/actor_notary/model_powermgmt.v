module actor_notary
import freeflowuniverse.crystallib.params



pub struct PowerManager{
pub mut:
	id string
	farmid u32
	description string
	params params.Params
}


// pub fn node_get(id u32){
// 	mut node := FarmerBotNode{}
// 	node.description = job.params.get_default("description","")!
// 	node.farmid = job.params.get_u32("farmid")!
// 	node.params = job.params
// 	params.get("powermanager")!
// 	params.get_u8("powermanager_port")!	
// }



// mut node := FarmerBotNode{}
// node.name = job.params.get_string("name")!
// node.description = job.params.get_default("description","")!
// node.farmid = job.params.get_u32("farmid") or {u32(0)}
// node.nrports = job.params.get_u8("nrports") or {u8(0)}
// node.farmname = job.params.get_default("farmname","")!
// node.secret = job.params.get_default("secret","")!
// node.params = job.params
// // job.params.get("powermanager")!
// // job.params.get_u8("powermanager_port")!	
// node.save()!
