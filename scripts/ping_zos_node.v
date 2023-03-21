module main

import freeflowuniverse.crystallib.redisclient

import threefoldtech.farmerbot.system {RmbMessage}

import encoding.base64
import flag
import json 
import os
import rand
import time


fn do(mut redis redisclient.Redis, cmd string, src u32, dst u32) ! { 
	msg := RmbMessage {
			ver: 1
			cmd: cmd
			exp: 10
			src: "$src"
			dat: base64.encode_str("")
			dst: [dst]
			ret: rand.uuid_v4()
			shm: "application/json"
			now: u64(time.now().unix_time())
	}
	request := json.encode_pretty(msg)
	redis.lpush('msgbus.system.local', request)!
	response_json := redis.blpop([msg.ret], 10)!
	println(response_json)
}

pub fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('Script allowing you to send a find_node job.')
	fp.limit_free_args(0, 0)!
	fp.description('')
	fp.skip_executable()
	redis_address := fp.string('redis', 0, "localhost:6379", "the address of the redis database")
	twinid := fp.int('twinid', 0, 0, 'your twinid')
	twinidnode := fp.int('dst', 0, 0, 'the twinid of the zos node')
	cmd := fp.string('cmd', 0, 'zos.system.version', 'the command to send to zos node')
	_ := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}
	mut redis := redisclient.get(redis_address) or {
		panic("$err")
	}
	do(mut redis, cmd, u32(twinid), u32(twinidnode)) or {
		eprintln(err)
	}
}