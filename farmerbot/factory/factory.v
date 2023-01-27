module factory

import freeflowuniverse.baobab.actions
import freeflowuniverse.crystallib.pathlib
import threefoldtech.farmerbot.system
import threefoldtech.farmerbot.manager

import log
import regex

pub fn run(path0 string) !system.DB {
	// TODO change level base on environment variable
	mut logger := log.Logger(&log.Log{ level: .info })
	mut db := system.DB{}

	mut path := pathlib.get_dir(path0, false)!	

	//ADD THE KNOWN MANAGERS
	mut managers := map[string]manager.Manager{}
	managers["power"] = manager.PowerManager{ logger: &logger }
	managers["resource"] = manager.ResourceManager{ logger: &logger }
	managers["node"] = manager.NodeManager{ logger: &logger }

	mut re := regex.regex_opt(".*") or { panic(err) }
	ar := path.list(regex:re, recursive:true)!
	for p in ar{
		if p.path.ends_with(".md") {
			mut parser := actions.file_parse(p.path)!
			for mut action in parser.actions {
				logger.debug("$action")
				name := action.name.split(".")[0]
				if name in managers {
					managers[name].execute(mut &db, mut &action)!
				}		
			}					
		}
	}
	return db
}
