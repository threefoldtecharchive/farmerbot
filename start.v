module main

import threefoldtech.farmerbot.factory

import flag
import log
import os

const default_data_dir = os.dir(@FILE) + '/example_data'
const default_grid3_http_address = "http://localhost:3000"
const default_redis_address = "localhost:6379"

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('Welcome to the farmerbot. The farmerbot is a service that a farmer can run allowing him to automatically manage the nodes of his farm.')
	fp.limit_free_args(0, 0)!
	fp.description('')
	fp.skip_executable()
	grid3_http_address := fp.string('grid3', `g`, '${default_grid3_http_address}', 'The address of the grid3_client_ts http server to connect to.')
	redis := fp.string('redis', `r`, '${default_redis_address}', 'The address of the redis db.')
	directory := fp.string('config_dir', `c`, '${default_data_dir}', 'The directory containing the markup definition files with the configuration of the nodes.')
	output_file := fp.string('output', `o`, '', 'The file to save the logs of the farmerbot in.')
	debug_log := fp.bool('debug', 0, false, 'By setting this flag the farmerbot will print debug logs too.')

	_ := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}
	if debug_log {
		os.setenv("FARMERBOT_LOG_LEVEL", "DEBUG", true)
	}
	if output_file != "" {
		os.mkdir_all(os.dir(output_file), os.MkdirParams{})!
		os.setenv("FARMERBOT_LOG_OUTPUT", output_file, true)
	}

	// TODO add arguments
	mut f := factory.new(directory, grid3_http_address, redis) or {
		exit(1)
	}
	
	f.run() or { 
		exit(1)
	}
}
