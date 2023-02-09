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

pub struct ZosRMB {
	redis_address string = "localhost:6379"
}

fn (mut z ZosRMB) rmb_client_request(cmd string, dst u32) !RmbResponse {
	mut rmb := RmbClient{
		client: redisclient.get(z.redis_address)!
		msg: RmbMessage {
			ver: 1
			cmd: cmd
			exp: 5
			dat: base64.encode_str("")
			dst: [dst]
			ret: rand.uuid_v4()
			now: time.now().unix_time()
		}
	}
	request := json.encode_pretty(rmb.msg)
	rmb.client.lpush('msgbus.system.local', request)!
	response_json := rmb.client.blpop(rmb.msg.ret, 5)!
	response := json.decode(RmbResponse, response_json)!
	return response
}

pub fn (mut z ZosRMB) zos_has_public_config(dst u32) !bool {
	response := z.rmb_client_request("zos.network.public_config_get", dst)!
	if response.err.message != "" {
		return false
	}
	return true 
}

pub fn (mut z ZosRMB) get_zos_statistics(dst u32) !ZosResourcesStatistics {
	response := z.rmb_client_request("zos.statistics.get", dst)!
	if response.err.message != "" {
		return error("${response.err.message}")
	}
	return json.decode(ZosResourcesStatistics, base64.decode_str(response.dat))!
}

pub fn (mut z ZosRMB) get_zos_system_version(dst u32) !string {
	response := z.rmb_client_request("zos.system.version", dst)!
	if response.err.message != "" {
		return error("${response.err.message}")
	}
	return base64.decode_str(response.dat)
}