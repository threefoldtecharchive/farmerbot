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
	src string
	ref string
	exp u64
	dat string
	dst []u32
	ret string
	now u64
	shm string
}

pub struct RmbError {
pub mut:
	code    int
	message string
}

pub struct RmbResponse {
pub mut:
	ver int = 1
	ref string
	dat string
	dst string
	now u64
	shm string
	err RmbError
}

pub struct ZosResources {
pub mut:
	cru   u64
	sru   u64
	hru   u64
	mru   u64
	ipv4u u64
}

pub struct ZosResourcesStatistics {
pub mut:
	total  ZosResources
	used   ZosResources
	system ZosResources
}

pub struct ZosPool {
pub mut:
	name      string
	pool_type string [json: 'type']
	size      int
	used      int
}

pub interface IZos {
mut:
	zos_has_public_config(dst u32) !bool
	get_zos_statistics(dst u32) !ZosResourcesStatistics
	get_zos_system_version(dst u32) !string
	get_zos_wg_ports(dst u32) ![]u16
	get_storage_pools(dst u32) ![]ZosPool
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
	msg := RmbMessage{
		ver: 1
		cmd: cmd
		exp: 5
		dat: base64.encode_str('')
		dst: [dst]
		ret: rand.uuid_v4()
		now: u64(time.now().unix_time())
	}
	request := json.encode_pretty(msg)
	z.redis.lpush('msgbus.system.local', request)!
	response_json := z.redis.blpop(msg.ret, 5)!
	response := json.decode(RmbResponse, response_json)!
	return response
}

pub fn (mut z ZosRMBPeer) zos_has_public_config(dst u32) !bool {
	response := z.rmb_client_request('zos.network.public_config_get', dst)!
	if response.err.message != '' {
		return false
	}
	return true
}

pub fn (mut z ZosRMBPeer) get_zos_statistics(dst u32) !ZosResourcesStatistics {
	response := z.rmb_client_request('zos.statistics.get', dst)!
	if response.err.message != '' {
		return error('${response.err.message}')
	}
	return json.decode(ZosResourcesStatistics, base64.decode_str(response.dat))!
}

pub fn (mut z ZosRMBPeer) get_zos_system_version(dst u32) !string {
	response := z.rmb_client_request('zos.system.version', dst)!
	if response.err.message != '' {
		return error('${response.err.message}')
	}
	return base64.decode_str(response.dat)
}

pub fn (mut z ZosRMBPeer) get_zos_wg_ports(dst u32) ![]u16 {
	response := z.rmb_client_request('zos.network.list_wg_ports', dst)!
	if response.err.message != '' {
		return error('${response.err.message}')
	}
	return json.decode([]u16, base64.decode_str(response.dat))
}

pub fn (mut z ZosRMBPeer) get_storage_pools(dst u32) ![]ZosPool {
	response := z.rmb_client_request('zos.storage.pools', dst)!

	if response.err.message != '' {
		return error('${response.err.message}')
	}
	return json.decode([]ZosPool, base64.decode_str(response.dat))
}
