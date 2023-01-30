module main

import threefoldtech.farmerbot.factory
import threefoldtech.farmerbot.system

import os

const testpath = os.dir(@FILE) + '/example_data'

fn main() {
	mut logger := system.logger()

	factory.run(testpath) or { 
		logger.error("$err")
		return
	}
}
