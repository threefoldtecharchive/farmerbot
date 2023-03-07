module main

import utils { 
	ensure_no_error, ensure_result_contains_string, run_test 
}
import freeflowuniverse.baobab.client { Client }
import freeflowuniverse.crystallib.params { Params }
import threefoldtech.farmerbot.factory { Farmerbot }
import threefoldtech.farmerbot.system

fn test_get_version() {
	run_test("test_get_version", 
		fn (mut farmerbot Farmerbot, mut c Client) ! {
			// prepare
			// act
			mut job := c.job_new_wait(
				twinid: c.twinid
				action: system.job_farm_version
				args: Params {}
				actionsource: ""
			)or {
				return error("failed to create and wait for job")
			}

			// assert
			ensure_no_error(&job)!
			ensure_result_contains_string(&job, "version", system.version)!
		}
	)!
}