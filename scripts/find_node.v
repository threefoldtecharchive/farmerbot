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

fn via_jobs(twinid u32, mut cl client.Client) ! {
	mut args := params.Params{}
	args.kwarg_add("required_hru", "500GB")
	args.kwarg_add("required_sru", "25GB")
	args.kwarg_add("required_mru", "2GB")
	args.kwarg_add("required_cru", "2")

	mut job := cl.job_new_wait(
			twinid: twinid,
			action: "farmerbot.nodemanager.findnode", 
			args: args,
			actionsource: "",
			src_twinid: twinid)!
	println("Status: ${job.state}")
	println("Err: ${job.error}")
	println("Response: ${job.result}")
}

fn via_rmb(twinid u32, mut cl client.Client) ! {
	mut args := params.Params{}
	args.kwarg_add("required_hru", "500GB")
	args.kwarg_add("required_sru", "25GB")
	args.kwarg_add("required_mru", "2GB")
	args.kwarg_add("required_cru", "2")
	//args.kwarg_add("node_exclude", "[77]")
	args.kwarg_add("dedicated", "false")
	mut j := jobs.new(
			twinid: twinid,
			action: "farmerbot.nodemanager.findnode", 
			args: args,
			actionsource: ""
			src_twinid: twinid)!

	mut redis := redisclient.get("localhost:6379")!	
	mut msg := system.RmbMessage {
			ver: 1
			cmd: "msgbus.execute_job"
			src: "$twinid"
			ref: rand.uuid_v4()
			exp: 60
			dat: base64.encode_str(j.json_dump())
			dst: [twinid]
			ret: rand.uuid_v4()
			now: u64(time.now().unix_time())
	}
	request := json.encode_pretty(msg)
	redis.lpush('msgbus.execute_job', request)!
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
	twinid := fp.int('twinid', 0, 0, 'your twinid')
	viarmb := fp.bool('rmb', 0, true, 'send the job via RMB or immediately to the farmerbots job queue')
	_ := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}
	mut cl := client.new() or { panic("$err") }
	if viarmb {
		via_rmb(u32(twinid), mut cl) or {
			eprintln(err)
		}
	} else {
		via_jobs(u32(twinid), mut cl) or {
			eprintln(err)
		}
	}
}