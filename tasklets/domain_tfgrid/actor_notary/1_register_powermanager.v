module actor_notary
import freeflowuniverse.crystallib.actionrunner
import freeflowuniverse.crystallib.taskletmanager {TaskletManager}


fn (mut tm TaskletManager) action_register_powermanager(mut job &actionrunner.ActionJob)!bool{
	// tm.powermanager_set(job.params)!
	return true
}
