module actor_powermanager
import freeflowuniverse.crystallib.actionrunner
import freeflowuniverse.crystallib.taskletmanager {TaskletManager}


fn (mut tm TaskletManager) action_reboot(mut job &actionrunner.ActionJob)!bool{
	nodeid := job.params.get_u32("nodeid")!	
	mut job1:=tm.schedule(action:"!!farmerbot.powermanager.poweroff nodeid:${nodeid}",timeout:"1min")!
	tm.schedule(action:"!!farmerbot.powermanager.poweron nodeid:${nodeid}",deps:[job1.guid],timeout:"5min")!
	return true
}



