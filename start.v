module main

//import freeflowuniverse.baobab
//import freeflowuniverse.baobab.actionrunner
//import freeflowuniverse.baobab.processor
import threefoldtech.farmerbot.system
import threefoldtech.farmerbot.factory

import log
import os

const testpath = os.dir(@FILE) + '/example_data'

fn main() {
	mut logger := system.logger()
	mut db := factory.run(testpath) or { 
		logger.error("$err")
		return
	}

	logger.info("$db")

	// TODO: Timur needs to make some changes:

	// mut b := baobab.new()!
	// mut resource_manager := manager.ResourceManager{}
	// mut power_manager := manager.PowerManager{}
	// mut ar := actionrunner.new(b.client, [&resource_manager, &power_manager])!
	// mut processor := processor.Processor{}

	// // concurrently run actionrunner, processor, and external client
	// spawn (&ar).run()
	// spawn (&processor).run()
}
