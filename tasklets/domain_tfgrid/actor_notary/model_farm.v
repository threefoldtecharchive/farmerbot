module actor_notary
import freeflowuniverse.crystallib.params
import freeflowuniverse.crystallib.taskletmanager {TaskletManager}

pub struct Farm{
pub mut:
	id u32
	name string
	description string
	params params.Params
}

fn farm_new(params params.Params)!Farm{
	mut obj := Farm{}
	obj.description = params.get_default("description","")!
	obj.name = params.get_default("name","")!
	obj.id = params.get_u32("id")!
	obj.params = params
	return obj
}

pub fn (mut tm TaskletManager) farm_set(params params.Params)!{
	mut obj:=farm_new(params)! //make sure object works
	tm.db.set(domain,obj.id,params)!
	tm.db.key_set(domain,"farm.${obj.name}",obj.id.str())!
}

pub fn (mut tm TaskletManager) farm_get(id u32)!Farm{
	mut params:=tm.db.get(domain,obj.id)!
	mut obj:=farm_new(params)!
	return obj
}

pub fn (mut tm TaskletManager) farm_get_from_name(name string)!Farm{
	id:=tm.db.key_get_u32(domain,"farm.${obj.name}")!
	return tm.farm_get(id)
}

