module main

import freeflowuniverse.baobab.client
import freeflowuniverse.crystallib.params

import flag
import os

pub fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('Script allowing you to power on or off a node')
	fp.limit_free_args(0, 0)!
	fp.description('')
	fp.skip_executable()
	twinid := fp.int('twinid', 0, 0, 'Your twinid')
	nodeid := fp.int('nodeid', 0, 0, 'The node id to power on or off')
	on := fp.bool('on', 0, true, 'If set it will power on the node')
	off := fp.bool('off', 0, false, 'If set it will power off the node')
	_ := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}
	if on && off {
		eprintln("You should choose on or off not both!")
		return
	}
	mut cl := client.new("localhost:6379") or { panic("$err") }
	mut args := params.Params{}
	args.kwarg_add("nodeid", "${nodeid}")
	action := if on {
		"farmerbot.powermanager.poweron"
	} else {
		"farmerbot.powermanager.poweroff"
	}
	mut job := cl.job_new_wait(
		twinid:u32(twinid),
		action: action, 
		args: args, 
		actionsource: "",
		src_twinid: twinid) or { 
		eprintln(err)
		return 
	}
	println("Success!")
}