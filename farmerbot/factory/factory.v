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

pub fn (mut f Farmerbot) init_db() ! {
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

fn (mut f Farmerbot) init_managers() ! {
	f.logger.info('Initializing managers')
	f.managers = map[string]&manager.Manager{}
	mut data_manager := &manager.DataManager{
		client: client.new(f.redis_address)!
		db: f.db
		logger: f.logger
		tfchain: f.tfchain
		zos: f.zos
	}
	mut farm_manager := &manager.FarmManager{
		client: client.new(f.redis_address)!
		db: f.db
		logger: f.logger
		tfchain: f.tfchain
		zos: f.zos
	}
	mut node_manager := &manager.NodeManager{
		client: client.new(f.redis_address)!
		db: f.db
		logger: f.logger
		tfchain: f.tfchain
		zos: f.zos
	}
	mut power_manager := &manager.PowerManager{
		client: client.new(f.redis_address)!
		db: f.db
		logger: f.logger
		tfchain: f.tfchain
		zos: f.zos
	}

	// ADD NEW MANAGERS HERE
	f.managers['datamanager'] = data_manager
	f.managers['farmmanager'] = farm_manager
	f.managers['nodemanager'] = node_manager
	f.managers['powermanager'] = power_manager

	f.actionrunner = actionrunner.new(client.new(f.redis_address)!, [farm_manager, node_manager,
		power_manager])
}

pub fn (mut f Farmerbot) init() ! {
	f.init_managers()!
	f.init_db() or { return error('Failed initializing the database: ${err}') }
}

pub fn (mut f Farmerbot) run() ! {
	f.running = true
	spawn (&f).update()
	spawn (&f.actionrunner).run()
	t := spawn (&f.processor).run()
	f.logger.info('Farmerbot up and running (version: ${system.version})')
	t.wait()
	f.logger.info('Shutdown successful')
}

pub fn (mut f Farmerbot) shutdown() {
	f.logger.info('Shutting down')
	f.actionrunner.running = false
	f.processor.running = false
	f.running = false
}

pub fn (mut f Farmerbot) on_sigint(signal Signal) {
	f.shutdown()
}

pub fn new(path string, grid3_http_address string, redis_address string) !&Farmerbot {
	mut logger := system.logger()
	mut f := &Farmerbot{
		redis_address: redis_address
		path: path
		db: &system.DB{
			farm: &system.Farm{}
		}
		tfchain: &system.TfChain{
			address: grid3_http_address
		}
		zos: &system.IZos(system.new_zosrmbpeer(redis_address)!)
		logger: logger
		processor: processor.new(redis_address, logger)!
		actionrunner: actionrunner.ActionRunner{
			client: &client.Client{}
		}
	}
	f.init() or {
		f.logger.error('${err}')
		return err
	}
	return f
}
