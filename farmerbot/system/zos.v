module system

import freeflowuniverse.crystallib.redisclient
import freeflowuniverse.crystallib.twinclient as tw

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

pub interface IZos {
mut:
	zos_has_public_config(dst u32) !bool
	get_zos_statistics(dst u32) !ZosResourcesStatistics
	get_zos_system_version(dst u32) !string
}

pub fn new_zosrmbpeer(redis_address string) !ZosRMBPeer {
	return ZosRMBPeer{
		redis: redisclient.get(redis_address)!
	}
}

pub struct ZosRMBPeer {
mut:
	redis redisclient.Redis
}

fn (mut z ZosRMBPeer) rmb_client_request(cmd string, dst u32) !RmbResponse {
	mut msg:= RmbMessage {
			ver: 1
			cmd: cmd
			exp: 5
			dat: base64.encode_str("")
			dst: [dst]
			ret: rand.uuid_v4()
			now: time.now().unix_time()
	}
	request := json.encode_pretty(msg)
	z.redis.lpush('msgbus.system.local', request)!
	response_json := z.redis.blpop(msg.ret, 5)!
	response := json.decode(RmbResponse, response_json)!
	return response
}

pub fn (mut z ZosRMBPeer) zos_has_public_config(dst u32) !bool {
	response := z.rmb_client_request("zos.network.public_config_get", dst)!
	if response.err.message != "" {
		return false
	}
	return true 
}

pub fn (mut z ZosRMBPeer) get_zos_statistics(dst u32) !ZosResourcesStatistics {
	response := z.rmb_client_request("zos.statistics.get", dst)!
	if response.err.message != "" {
		return error("${response.err.message}")
	}
	return json.decode(ZosResourcesStatistics, base64.decode_str(response.dat))!
}

pub fn (mut z ZosRMBPeer) get_zos_system_version(dst u32) !string {
	response := z.rmb_client_request("zos.system.version", dst)!
	if response.err.message != "" {
		return error("${response.err.message}")
	}
	return base64.decode_str(response.dat)
}


pub fn new_zosrmbgo(redis_address string) !ZosRMBGo {
	return ZosRMBGo{
		redis: redisclient.get(redis_address)!
	}
}

pub struct ZosRMBGo {
mut:
	redis redisclient.Redis
}

fn (mut z ZosRMBGo) rmb_client_request(cmd string, data string, dst u32) !tw.Message {
	msg := tw.Message{
		id: rand.uuid_v4()
		version: 1
		command: cmd
		expiration: 10
		retry: 5
		twin_src: 0
		twin_dst: [int(dst)]
		data: base64.encode_str(data)
		retqueue: rand.uuid_v4()
		epoch: time.now().unix_time()
	}
	request := json.encode_pretty(msg)
	z.redis.lpush('msgbus.system.local', request)!
	response_json := z.redis.blpop(msg.retqueue, 5)!
	mut response := json.decode(tw.Message, response_json)!
	response.data = base64.decode_str(response.data)
	return response
}

pub fn (mut z ZosRMBGo) zos_has_public_config(dst u32) !bool {
	response := z.rmb_client_request("zos.network.public_config_get", "", dst)!
	if response.err != "" {
		return false
	}
	return true 
}

pub fn (mut z ZosRMBGo) get_zos_statistics(dst u32) !ZosResourcesStatistics {
	response := z.rmb_client_request("zos.statistics.get", "", dst)!
	if response.err != "" {
		return error("${response.err}")
	}
	return json.decode(ZosResourcesStatistics, base64.decode_str(response.data))!
}

pub fn (mut z ZosRMBGo) get_zos_system_version(dst u32) !string {
	response := z.rmb_client_request("zos.system.version", "", dst)!
	if response.err != "" {
		return error("${response.err}")
	}
	return base64.decode_str(response.data)
}


