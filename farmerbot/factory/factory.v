module factory

import freeflowuniverse.baobab
import freeflowuniverse.baobab.actionrunner
import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.processor
import freeflowuniverse.crystallib.pathlib
import threefoldtech.farmerbot.system
import threefoldtech.farmerbot.manager

import log
import regex
import time

fn update(mut managers &map[string]&manager.Manager) ! {
	for {
		for _, mut manager in managers {
			manager.update()!
			time.sleep(time.minute * 5)
		}
	}
}

fn init(path0 string, mut managers map[string]&manager.Manager) ! {
	mut path := pathlib.get_dir(path0, false)!
	mut re := regex.regex_opt(".*") or { panic(err) }
	ar := path.list(regex:re, recursive:true)!
	for p in ar {
		if p.path.ends_with(".md") {
			mut parser := actions.file_parse(p.path)!
			for mut action in parser.actions {
				name := action.name.split(".")[1]
				if name in managers {
					managers[name].init(mut &action)!
				}		
			}					
		}
	}
}

pub fn run_farmerbot(path string) ! {
	mut logger := system.logger()
	mut db := system.DB {}
	mut b := baobab.new()!
	mut node_manager := manager.NodeManager {
		client: &b.client
		db: &db 
		logger: logger 
	}
	mut power_manager := manager.PowerManager {
		client: &b.client
		db: &db
		logger: logger 
	}
	mut managers := map[string]&manager.Manager{}
	managers["nodemanager"] = &node_manager
	managers["powermanager"] = &power_manager

	init(path, mut managers)!
	logger.debug("${db}")

	// The action runner will call execute whenever it finds a job in the redis queue
	mut ar := actionrunner.new(b.client, [node_manager, power_manager])!
	// TODO: use processor to assign jobs (received through RMB) to our actor
	mut processor := processor.Processor{}

	// concurrently run actionrunner, processor, and external client
	t := spawn update(mut &managers)
	spawn (&ar).run()
	spawn (&processor).run()
	t.wait() !
}