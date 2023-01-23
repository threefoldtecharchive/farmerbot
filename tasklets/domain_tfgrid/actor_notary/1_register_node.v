module actor_notary
import freeflowuniverse.crystallib.actionrunner
import freeflowuniverse.crystallib.taskletmanager {TaskletManager}


fn (mut tm TaskletManager) action_register_node(mut job &actionrunner.ActionJob)!bool{
	// tm.node_set(job.params)!
	return true
}
