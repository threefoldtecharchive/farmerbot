module main

import threefoldtech.farmerbot.system

import log
import flag
import os
import time

fn do(redis_address string, cmd string, src u32, dst u32) ! {
	mut logger := &log.Log{ level:.debug}
	mut zos_rmbpeer := system.new_zosrmbpeer(redis_address, logger)!
	t := spawn (&zos_rmbpeer).run()
	zos_rmbpeer.rmb_client_request(cmd, [dst], "", 300)!
	select {
		message := <-zos_rmbpeer.messages {
			match message.ref {
				'zos.system.version' {
					version := message.parse_system_version()!
					println(version)
				}
				'zos.network.public_config_get' {
					public_config := message.parse_has_public_config()!
					println(public_config)
				}
				'zos.statistics.get' {
					stats := message.parse_statistics()!
					println(stats)
				}
				'zos.storage.pools' {
					storage_pools := message.parse_storage_pools()!
					println(storage_pools)
				}
				'zos.gpu.list' {
					gpus := message.parse_gpus()!
					println(gpus)
				}
				else {
					return error('Unknown msg ${message}')
				}
			}
		}
		60 * time.second {}
	}
	zos_rmbpeer.running = false
	t.wait()
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

	do(redis_address, cmd, u32(twinid), u32(twinidnode)) or {
		eprintln(err)
	}
}