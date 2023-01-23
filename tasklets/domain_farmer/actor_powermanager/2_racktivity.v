module actor_powermanager
import freeflowuniverse.crystallib.actionrunner
import freeflowuniverse.crystallib.taskletmanager {TaskletManager}


//return true if we need to do the job
fn match_racktivity(mut job &actionrunner.ActionJob){
	devicetype := job.params.get("devicetype")!
	if devicetype=="racktivity"{return true}
	return false
}

fn (mut tm TaskletManager) action_poweron__racktivity(mut job &actionrunner.ActionJob)!bool{
	if !match_racktivity(mut job){return false}
	powermanager := job.params.get("powermanager")!
	powermanager_port := job.params.get_u8("powermanager_port")!	
	//TODO: implement poweron
	mut job:=tm.schedule(action:"!!tfgrid.nodemanager.ensure_up nodeid:${nodeid}",timeout:"5min")!
	job.checks<<job.guid 
	return true
}

fn (mut tm TaskletManager) action_poweroff__racktivity(mut job &actionrunner.ActionJob)!bool{
	if !match_racktivity(mut job){return false}

	nodeid := job.params.get_u32("nodeid")!

	mut node := tm.db..... 
	powermanager := node.params.get("powermanager")!
	powermanager_port := node.params.get_u8("powermanager_port")!	
	//TODO: implement poweroff

	//TODO: do some test that the node is on
	mut job:=tm.schedule(action:"!!tfgrid.nodemanager.ensure_down nodeid:${nodeid}",timeout:"5min")!
	job.checks<<job.guid 
	//TODO: need to check the guid is remembered
	return true
}

