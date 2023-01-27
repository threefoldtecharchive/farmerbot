module main

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
}
