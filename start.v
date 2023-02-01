module main

import threefoldtech.farmerbot.factory

import os

const testpath = os.dir(@FILE) + '/example_data'

fn main() {
	// TODO add arguments
	mut f := factory.new(testpath) or {
		exit(1)
	}
	
	f.run() or { 
		exit(1)
	}
}
