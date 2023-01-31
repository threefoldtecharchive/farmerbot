module main

import threefoldtech.farmerbot.factory

import os

const testpath = os.dir(@FILE) + '/example_data'

fn main() {
	// TODO add arguments
	factory.run_farmerbot(testpath) or { 
		exit(1)
	}
}
