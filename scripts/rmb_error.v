module main

import freeflowuniverse.baobab.client
import freeflowuniverse.crystallib.redisclient
import freeflowuniverse.baobab.processor { error_code_to_message, RMBErrorCode}

import threefoldtech.farmerbot.system


import encoding.base64
import flag
import json
import os
import rand
import time

fn unauthorized(mut redis redisclient.Redis, twinid u32, twinidfarm u32, mut cl client.Client) ! {
	a_wrong_source_twin_id := twinid + 5
	mut wrong_payload := '{"guid":"0eb2d6d6-73ef-4273-a80c-ab1289d2d0d6","twinid":${twinidfarm},"action":"farmerbot.farmmanager.version","args":{"params":[],"args":[]},"result":{"params":[],"args":[]},"state":"init","start":1677842854,"end":0,"grace_period":0,"error":"","timeout":0,"src_twinid":${a_wrong_source_twin_id},"src_action":"","dependencies":[]}'
	mut msg := system.RmbMessage {
			ver: 1
			cmd: "execute_job"
			src: "$twinid"
			ref: rand.uuid_v4()
			exp: 60
			dat: base64.encode_str(wrong_payload)
			dst: [twinidfarm]
			ret: rand.uuid_v4()
			now: u64(time.now().unix_time())
	}
	request := json.encode_pretty(msg)
	redis.lpush('msgbus.system.local', request)!
	response_json := redis.blpop(msg.ret, int(msg.exp))!
	response := json.decode(system.RmbResponse, response_json)!
	println("Response: ${response}")
	assert response.err.code == int(RMBErrorCode.unauthorized)
	assert response.err.message == error_code_to_message(RMBErrorCode.unauthorized)
}

fn wrong_json_job(mut redis redisclient.Redis, twinid u32, twinidfarm u32, mut cl client.Client) ! {
	mut wrong_payload := '"guid":"0eb2d6d6-73ef-4273-a80c-ab1289d2d0d6","twinid":0,"action":"farmerbot.farmmanager.version","args":{"params":[],"args":[]},"result":{"params":[],"args":[]},"state":"init","start":1677842854,"end":0,"grace_period":0,"error":"","timeout":0,"src_twinid":0,"src_action":"","dependencies":[]}'
	mut msg := system.RmbMessage {
			ver: 1
			cmd: "execute_job"
			src: "$twinid"
			ref: rand.uuid_v4()
			exp: 60
			dat: base64.encode_str(wrong_payload)
			dst: [twinidfarm]
			ret: rand.uuid_v4()
			shm: "application/json"
			now: u64(time.now().unix_time())
	}
	request := json.encode_pretty(msg)
	redis.lpush('msgbus.system.local', request)!
	response_json := redis.blpop(msg.ret, int(msg.exp))!
	response := json.decode(system.RmbResponse, response_json)!
	println("Response: ${response}")
	assert response.err.code == int(RMBErrorCode.failed_decoding_payload_to_job)
	assert response.err.message == error_code_to_message(RMBErrorCode.failed_decoding_payload_to_job)
}

pub fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('Script allowing you to a RMB message that is not accepted by the farmerbot.')
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
	mut redis := redisclient.get(redis_address) or { panic("$err") }
	mut cl := client.new(redis_address) or { panic("$err") }
	if twinidfarm == 0 {
		twinidfarm = twinid
	}
	wrong_json_job(mut redis, u32(twinid), u32(twinidfarm), mut cl) or {
		eprintln(err)
	}
	unauthorized(mut redis, u32(twinid), u32(twinidfarm), mut cl) or {
		eprintln(err)
	}
	test(mut redis, u32(twinid), u32(twinidfarm), mut cl) or {
		eprintln(err)
	}
}