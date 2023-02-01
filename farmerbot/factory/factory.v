module factory

import freeflowuniverse.baobab
import freeflowuniverse.baobab.actionrunner
import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.actor
import freeflowuniverse.baobab.client
import freeflowuniverse.baobab.processor
import freeflowuniverse.crystallib.pathlib
import threefoldtech.farmerbot.system
import threefoldtech.farmerbot.manager

import log
import regex
import time

[heap]
pub struct Farmerbot {
pub mut:
	path string 
	db system.DB = system.DB {}
	logger &log.Logger = system.logger()
	managers map[string]manager.Manager
	jobclient client.Client = client.Client {}
	processor processor.Processor = processor.Processor {}
	actionrunner actionrunner.ActionRunner = actionrunner.ActionRunner {}
}

fn (mut f Farmerbot) update() ! {
	for {
		for _, mut manager in f.managers {
			manager.update()!
			time.sleep(time.minute * 5)
		}
	}
}

pub fn (mut f Farmerbot) init_db() ! {
	f.logger.info("Initializing database")
	f.db = system.DB {}
	mut path := pathlib.get_dir(f.path, false)!
	mut re := regex.regex_opt(".*") or { panic(err) }
	ar := path.list(regex:re, recursive:true)!
	for p in ar {
		if p.path.ends_with(".md") {
			mut parser := actions.file_parse(p.path)!
			for mut action in parser.actions {
				name := action.name.split(".")[1]
				if name in f.managers {
					f.managers[name].init(mut &action)!
				}		
			}					
		}
	}
	f.logger.debug("${f.db}")
}

fn (mut f Farmerbot) init_managers() {
	f.logger.info("Initializing managers")
	mut node_manager := &manager.NodeManager {
		client: &f.jobclient
		db: &f.db 
		logger: f.logger 
	}
	mut power_manager := manager.PowerManager {
		client: &f.jobclient
		db: &f.db
		logger: f.logger 
	}

	// ADD NEW MANAGERS HERE
	f.managers["nodemanager"] = node_manager
	f.managers["powermanager"] = power_manager

	f.actionrunner = actionrunner.new(f.jobclient, [node_manager, power_manager])
}

pub fn (mut f Farmerbot) init() ! {
	f.jobclient = client.new()!
	f.init_managers()
	f.init_db()!
}

pub fn (mut f Farmerbot) run() ! {
	// concurrently run actionrunner, processor, and external client
	t := spawn (&f).update()
	spawn (&f.actionrunner).run()
	spawn (&f.processor).run()
	t.wait() !
}

pub fn new(path string) !&Farmerbot {
	mut f := &Farmerbot {
		path: path
	}
	f.init()!
	return f
}