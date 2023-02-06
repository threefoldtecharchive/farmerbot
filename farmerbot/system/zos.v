module system

import freeflowuniverse.crystallib.redisclient

import encoding.base64
import json
import rand
import time

pub struct RmbMessage {
pub mut:
	ver int = 1
	cmd string
	exp u64
	dat string
	dst []u32
    ret string
	now i64
}

pub struct RmbError {
    code u32
	message string
}

pub struct RmbResponse {
pub mut:
	ver int = 1
	ref string
	dat string
	dst string
	now u64
	err RmbError
}

pub struct RmbClient {
pub mut:
	msg RmbMessage
	client redisclient.Redis
}

pub fn zos_has_public_config(dst []u32, exp u64) !bool {
	mut rmb := RmbClient{}
	rmb.client = redisclient.get('localhost:6379')!
	rmb.msg = RmbMessage {
		ver: 1
		cmd: "zos.network.public_config_get"
		exp: exp
		dat: base64.encode_str("")
		dst: dst
		ret: rand.uuid_v4()
		now: time.now().unix_time()
	}
	request := json.encode_pretty(rmb.msg)
	rmb.client.lpush('msgbus.system.local', request)!
	response_json := rmb.client.blpop(rmb.msg.ret, int(exp))!
	response := json.decode(RmbResponse, response_json)!
	if response.err.message != "" {
		return false
	}
	return true 
}

pub fn get_zos_statistics(dst []u32, exp u64) !ZosResourcesStatistics {
	mut rmb := RmbClient{}
	rmb.client = redisclient.get('localhost:6379')!
	rmb.msg = RmbMessage {
		ver: 1
		cmd: "zos.statistics.get"
		exp: exp
		dat: base64.encode_str("")
		dst: dst
		ret: rand.uuid_v4()
		now: time.now().unix_time()
	}
	request := json.encode_pretty(rmb.msg)
	rmb.client.lpush('msgbus.system.local', request)!
	response_json := rmb.client.blpop(rmb.msg.ret, int(exp))!
	response := json.decode(RmbResponse, response_json)!
	if response.err.message != "" {
		return error("${response.err.message}")
	}
	return json.decode(ZosResourcesStatistics, base64.decode_str(response.dat))!
}


pub struct ZosResources {
pub mut:
	cru u64
	sru u64
	hru u64
	mru u64
	ipv4u u64
}

pub struct ZosResourcesStatistics {
pub mut:
	total ZosResources
	used ZosResources
}