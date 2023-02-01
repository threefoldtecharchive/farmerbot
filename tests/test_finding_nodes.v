module main

import threefoldtech.farmerbot.factory {Farmerbot}

import log
import os

const testpath = os.dir(@FILE) + '/../example_data'

type Test = fn (farmerbot &Farmerbot) !

pub struct TestEnvironment {
pub mut:
	tests []Test
}

pub fn (mut t TestEnvironment) run() {
	mut logger := log.Logger(&log.Log{ level: .info })


	for test in t.tests {
		mut f := factory.new(testpath) or {
			logger.error("failed creating farmerbot: $err")
			return
		}
		f.jobclient.reset() or {
			logger.error("Failed resetting client")
			return
		}
		//f.logger.set_level(log.Level.disabled)
		t_farmerbot := spawn f.run()
		test(f) or {
			logger.error("Test ${test} failed: $err")
			continue
		}
		logger.info("Test ${test} passed.")
	}
}

fn test_find_node(farmerbot &Farmerbot) ! {
	println("Yup")
}

fn main() {
	mut testenvironment := TestEnvironment {
		tests: [
			test_find_node
		]
	}

	testenvironment.run()
}
