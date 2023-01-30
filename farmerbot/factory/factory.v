module factory

import freeflowuniverse.baobab
import freeflowuniverse.baobab.actions
import freeflowuniverse.baobab.processor
import freeflowuniverse.crystallib.pathlib
import threefoldtech.farmerbot.actor
import threefoldtech.farmerbot.system
import threefoldtech.farmerbot.manager

import log
import regex
import time

[heap]
struct Farmerbot {
pub mut:
	db system.DB
	logger &log.Logger = system.logger()
	managers map[string]manager.Manager

}

pub fn (mut f Farmerbot) update_database() ! {
	for {
		f.logger.debug("Updating database")
		for _, mut manager in f.managers {
			manager.update(mut &f.db)!
			time.sleep(time.minute * 5)
		}
	}
}

pub fn (mut f Farmerbot) init_db(path0 string) ! {
	mut db := system.DB{}
	mut path := pathlib.get_dir(path0, false)!	
	mut re := regex.regex_opt(".*") or { panic(err) }
	ar := path.list(regex:re, recursive:true)!
	for p in ar {
		if p.path.ends_with(".md") {
			mut parser := actions.file_parse(p.path)!
			for mut action in parser.actions {
				f.logger.debug("$action")
				name := action.name.split(".")[1]
				if name in f.managers {
					f.managers[name].execute(mut &db, mut &action)!
				}		
			}					
		}
	}
	f.db = db
	f.logger.debug("${f.db}")
}


pub fn run(path string) ! {
	mut logger := system.logger()
	mut managers := map[string]manager.Manager{}
	managers["node"] = manager.NodeManager{ logger: logger }
	managers["power"] = manager.PowerManager{ logger: logger }
	managers["resource"] = manager.ResourceManager{ logger: logger }

	mut farmerbot := Farmerbot {
		managers: managers
		logger: logger
	}

	farmerbot.init_db(path)!

	mut b := baobab.new()!
	mut farmerbotactor := actor.new_farmerbotactor(mut &farmerbot.db) !
	// The action runner will call execute whenever it finds a job in the redis queue
	//mut ar := actionrunner.new(b.client, &farmerbotactor)!
	mut processor := processor.Processor{}

	// concurrently run actionrunner, processor, and external client
	t := spawn (&farmerbot).update_database()
	//spawn (&ar).run()
	spawn (&processor).run()
	t.wait() !
}