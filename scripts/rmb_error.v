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

fn unauthorized(twinid u32, mut cl client.Client) ! {
	a_wrong_source_twin_id := twinid + 5
	mut wrong_payload := '{"guid":"0eb2d6d6-73ef-4273-a80c-ab1289d2d0d6","twinid":${twinid},"action":"farmerbot.farmmanager.version","args":{"params":[],"args":[]},"result":{"params":[],"args":[]},"state":"init","start":1677842854,"end":0,"grace_period":0,"error":"","timeout":0,"src_twinid":${a_wrong_source_twin_id},"src_action":"","dependencies":[]}'

	mut redis := redisclient.get("localhost:6379")!	
	mut msg := system.RmbMessage {
			ver: 1
			cmd: "msgbus.execute_job"
			src: "$twinid"
			ref: rand.uuid_v4()
			exp: 60
			dat: base64.encode_str(wrong_payload)
			dst: [twinid]
			ret: rand.uuid_v4()
			now: u64(time.now().unix_time())
	}
	request := json.encode_pretty(msg)
	redis.lpush('msgbus.execute_job', request)!
	response_json := redis.blpop(msg.ret, int(msg.exp))!
	response := json.decode(system.RmbResponse, response_json)!
	println("Response: ${response}")
	assert response.err.code == int(RMBErrorCode.unauthorized)
	assert response.err.message == error_code_to_message(RMBErrorCode.unauthorized)
}

fn wrong_json_job(twinid u32, mut cl client.Client) ! {
	mut wrong_payload := '"guid":"0eb2d6d6-73ef-4273-a80c-ab1289d2d0d6","twinid":0,"action":"farmerbot.farmmanager.version","args":{"params":[],"args":[]},"result":{"params":[],"args":[]},"state":"init","start":1677842854,"end":0,"grace_period":0,"error":"","timeout":0,"src_twinid":0,"src_action":"","dependencies":[]}'

	mut redis := redisclient.get("localhost:6379")!	
	mut msg := system.RmbMessage {
			ver: 1
			cmd: "msgbus.execute_job"
			src: "$twinid"
			ref: rand.uuid_v4()
			exp: 60
			dat: base64.encode_str(wrong_payload)
			dst: [twinid]
			ret: rand.uuid_v4()
			now: u64(time.now().unix_time())
	}
	request := json.encode_pretty(msg)
	redis.lpush('msgbus.execute_job', request)!
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
	twinid := fp.int('twinid', 0, 0, 'your twinid')
	_ := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}
	mut cl := client.new() or { panic("$err") }
	wrong_json_job(u32(twinid), mut cl) or {
		eprintln(err)
	}
	unauthorized(u32(twinid), mut cl) or {
		eprintln(err)
	}
}