module main

import freeflowuniverse.baobab.client
import freeflowuniverse.baobab.jobs
import freeflowuniverse.crystallib.params
import freeflowuniverse.crystallib.redisclient

import threefoldtech.farmerbot.system


import encoding.base64
import flag
import json
import os
import rand
import time

fn find_job(mut redis redisclient.Redis, twinid u32, twinidfarm u32, mut cl client.Client) ! {
	mut args := params.Params{}
	args.kwarg_add("required_hru", "500GB")
	args.kwarg_add("required_sru", "10GB")
	args.kwarg_add("required_mru", "2GB")
	args.kwarg_add("required_cru", "2")
	//args.kwarg_add("node_exclude", "[77]")
	//args.kwarg_add("dedicated", "false")
	mut j := jobs.new(
			twinid: twinidfarm,
			action: "farmerbot.nodemanager.findnode", 
			args: args,
			actionsource: ""
			src_twinid: twinid)!

	mut msg := system.RmbMessage {
			ver: 1
			cmd: "execute_job"
			src: "$twinid"
			ref: rand.uuid_v4()
			exp: 60
			dat: base64.encode_str(j.json_dump())
			dst: [twinidfarm]
			ret: rand.uuid_v4()
			shm: "application/json"
			now: u64(time.now().unix_time())
	}
	request := json.encode_pretty(msg)
	redis.lpush('msgbus.system.local', request)!
	response_json := redis.blpop(msg.ret, int(msg.exp))!
	response := json.decode(system.RmbResponse, response_json)!
	job_response := jobs.json_load(base64.decode_str(response.dat))!
	println("Status: ${job_response.state}")
	println("Err: ${job_response.error}")
	println("Response: ${job_response.result}")
}

pub fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('Script allowing you to send a find_node job.')
	fp.limit_free_args(0, 0)!
	fp.description('')
	fp.skip_executable()
	redis_address := fp.string('redis', 0, "localhost:6379", "the address of the redis database")
	twinid := fp.int('twinid', 0, 0, 'your twinid')
	mut twinidfarm := fp.int('twinidfarm', 0, 0, 'the twinid of your farm')
	_ := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}
	if twinidfarm == 0 {
		twinidfarm = twinid
	}
	mut cl := client.new(redis_address) or { panic("$err") }
	mut redis := redisclient.get(redis_address) or {
	 	panic("$err")
	}
	find_job(mut redis, u32(twinid), u32(twinidfarm), mut cl) or {
		eprintln(err)
	}
}