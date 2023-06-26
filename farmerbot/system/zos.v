module system

import freeflowuniverse.crystallib.redisclient

import encoding.base64
import json
import log
import rand
import time

const (
	capacity_zos_message_channel = 1000
)

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
	shm string = 'application/json'
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
	src string
	now u64
	shm string
	err RmbError
}

pub fn (r &RmbResponse) parse_system_version() !string {
	if r.err.message != '' {
		return error('${r.err.message}')
	}
	return base64.decode_str(r.dat)
}

pub fn (r &RmbResponse) parse_statistics() !ZosResourcesStatistics {
	if r.err.message != '' {
		return error('${r.err.message}')
	}
	return json.decode(ZosResourcesStatistics, base64.decode_str(r.dat))!
}

pub fn (r &RmbResponse) parse_storage_pools() ![]ZosPool {
	if r.err.message != '' {
		return error('${r.err.message}')
	}
	return json.decode([]ZosPool, base64.decode_str(r.dat))
}

pub fn (r &RmbResponse) parse_has_public_config() !bool {
	if r.err.message != '' {
		return false
	}
	return true
}

pub fn (r &RmbResponse) parse_wg_ports() ![]u16 {
	if r.err.message != '' {
		return error('${r.err.message}')
	}
	return json.decode([]u16, base64.decode_str(r.dat))
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
	running bool 
	messages chan RmbResponse
	run()
	has_public_config(dsts []u32, exp u64) !
	get_statistics(dsts []u32, exp u64) !
	get_system_version(dsts []u32, exp u64) !
	get_wg_ports(dsts []u32, exp u64) !
	get_storage_pools(dsts []u32, exp u64) !
}

pub fn new_zosrmbpeer(redis_address string, logger &log.Logger) !ZosRMBPeer {
	return ZosRMBPeer{
		message_queue: rand.uuid_v4()
		redis_request: redisclient.get(redis_address)!
		redis_response: redisclient.get(redis_address)!
		logger: unsafe { logger }
		messages: chan RmbResponse { cap: capacity_zos_message_channel }
	}
}

pub struct ZosRMBPeer {
pub mut:
	logger  &log.Logger
	message_queue string
	running bool
	messages chan RmbResponse
	// we need two redis connections here because redis is not threadsafe so we use one to send requests and the other to get responses
	redis_response redisclient.Redis
	redis_request redisclient.Redis
}

pub fn (mut z ZosRMBPeer) run() {
	z.running = true
	for z.running {
		response_json := z.redis_response.brpop([z.message_queue], 5) or {
			continue
		}
		if response_json.len != 2 || response_json[1] == '' {
			// no message in queue 
			continue
		}
		z.logger.debug("Received message: ${response_json[1]}")
		rmb_response := json.decode(RmbResponse, response_json[1]) or {
			z.logger.error("Failed decoding RmbResponse: ${response_json[1]}")
			continue
		}
		z.messages <- rmb_response
	}
}

pub fn (mut z ZosRMBPeer) rmb_client_request(cmd string, dsts []u32, data string, exp u64) ! {
	start := time.now()  
	msg := RmbMessage{
		ver: 1
		cmd: cmd
		ref: cmd
		exp: exp
		dat: base64.encode_str(data)
		dst: dsts
		ret: z.message_queue
		now: u64(start.unix_time())
	}
	request := json.encode(msg)
	z.redis_request.lpush('msgbus.system.local', request)!
}

pub fn (mut z ZosRMBPeer) has_public_config(dsts []u32, exp u64) ! {
	z.rmb_client_request('zos.network.public_config_get', dsts, "", exp)!
}

pub fn (mut z ZosRMBPeer) get_statistics(dsts []u32, exp u64) ! {
	z.rmb_client_request('zos.statistics.get', dsts, "", exp)!
}

pub fn (mut z ZosRMBPeer) get_system_version(dsts []u32, exp u64) ! {
	z.rmb_client_request('zos.system.version', dsts, "", exp)!
}

pub fn (mut z ZosRMBPeer) get_wg_ports(dsts []u32, exp u64) ! {
	z.rmb_client_request('zos.network.list_wg_ports', dsts, "", exp)!
}

pub fn (mut z ZosRMBPeer) get_storage_pools(dsts []u32, exp u64) ! {
	z.rmb_client_request('zos.storage.pools', dsts, "", exp)!
}
