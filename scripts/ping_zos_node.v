module main

import threefoldtech.farmerbot.system

import flag
import os


fn do(redis_address string, cmd string, src u32, dst u32) ! {
	mut zos_rmbpeer := system.new_zosrmbpeer(redis_address)!
	response_json := zos_rmbpeer.rmb_client_request(cmd, dst)!
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

	do(redis_address, cmd, u32(twinid), u32(twinidnode)) or {
		eprintln(err)
	}
}