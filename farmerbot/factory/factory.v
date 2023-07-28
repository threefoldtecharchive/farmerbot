module factory

import freeflowuniverse.baobab.actionrunner
import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.client
import freeflowuniverse.baobab.processor
import freeflowuniverse.crystallib.pathlib
import threefoldtech.farmerbot.system
import threefoldtech.farmerbot.manager
import log
import os { Signal }
import regex
import time

[heap]
pub struct Farmerbot {
pub:
	redis_address string
pub mut:
	running      bool
	path         string
	db           &system.DB
	logger       &log.Logger
	tfchain      &system.ITfChain
	zos          &system.IZos
	managers     map[string]&manager.Manager
	processor    processor.Processor
	actionrunner actionrunner.ActionRunner
}

pub fn (f &Farmerbot) get_manager(name string) !&manager.Manager {
	return f.managers[name] or { return error('Unknown manager ${name}') }
}

fn (mut f Farmerbot) on_started() {
	for _, mut manager in f.managers {
		manager.on_started()
	}
}

fn (mut f Farmerbot) on_stop() {
	for _, mut manager in f.managers {
		manager.on_stop()
	}
}

fn (mut f Farmerbot) update() {
	for f.running {
		time_start := time.now()
		for _, mut manager in f.managers {
			manager.update()
		}
		delta := time.now() - time_start
		f.logger.info('Elapsed time for update: ${delta.minutes()}')
		time_to_sleep := if delta.minutes() >= 5 { 0 } else { 5 - delta.minutes() }
		time.sleep(time.minute * time_to_sleep)
	}
}

pub fn (mut f Farmerbot) init() ! {
	f.logger.info('Initializing database')
	f.db.nodes = map[u32]&system.Node{}
	f.db.farm = &system.Farm{}
	mut path := pathlib.get_dir(f.path, false)!
	mut re := regex.regex_opt('.*') or { panic(err) }
	ar := path.list(regex: re, recursive: true)!
	for p in ar {
		if p.path.ends_with('.md') {
			mut parser := actions.file_parse(p.path)!
			for mut action in parser.actions {
				name := action.name.split('.')[1]
				mut m := f.managers[name] or {
					f.logger.error('Unknown manager ${name}. Skipping this action')
					continue
				}
				m.init(mut &action)!
			}
		}
	}
	f.logger.debug('${f.db.nodes}')
}

pub fn (mut f Farmerbot) run() ! {
	f.running = true
	spawn (&f).update()
	spawn (*f.zos).run()
	spawn (&f.actionrunner).run()
	t := spawn (&f.processor).run()
	f.logger.info('Farmerbot up and running (version: ${system.version})')
	f.on_started()
	t.wait()
	f.logger.info('Shutdown successful')
}

pub fn (mut f Farmerbot) shutdown() {
	f.logger.info('Shutting down')
	f.on_stop()
	f.actionrunner.running = false
	f.zos.running = false
	f.processor.running = false
	f.running = false
}

pub fn (mut f Farmerbot) on_sigint(signal Signal) {
	f.shutdown()
}

pub fn new(path string, grid3_http_address string, redis_address string) !&Farmerbot {
	mut logger := system.logger()
	mut zos_rmbpeer := system.new_zosrmbpeer(redis_address, logger)!
	mut db := &system.DB{
		farm: &system.Farm{}
	}
	mut zos := &system.IZos(zos_rmbpeer)
	mut tfchain := &system.TfChain{
		address: grid3_http_address
	}
	tfchain.should_have_enough_balance()!
	mut managers := map[string]&manager.Manager{}
	mut data_manager := &manager.DataManager{
		client: client.new(redis_address)!
		db: db
		logger: logger
		tfchain: tfchain
		zos: zos
	}
	mut farm_manager := &manager.FarmManager{
		client: client.new(redis_address)!
		db: db
		logger: logger
		tfchain: tfchain
		zos: zos
	}
	mut node_manager := &manager.NodeManager{
		client: client.new(redis_address)!
		db: db
		logger: logger
		tfchain: tfchain
		zos: zos
	}
	mut power_manager := &manager.PowerManager{
		client: client.new(redis_address)!
		db: db
		logger: logger
		tfchain: tfchain
		zos: zos
	}

	// ADD NEW MANAGERS HERE
	managers['datamanager'] = data_manager
	managers['farmmanager'] = farm_manager
	managers['nodemanager'] = node_manager
	managers['powermanager'] = power_manager

	mut f := &Farmerbot{
		redis_address: redis_address
		path: path
		db: db
		tfchain: tfchain
		zos: zos
		logger: logger
		processor: processor.new(redis_address, logger)!
		actionrunner: actionrunner.new(client.new(redis_address)!, [farm_manager, node_manager,
		power_manager])
		managers: managers
	}

	f.init() or {
		f.logger.error('${err}')
		return err
	}
	return f
}
