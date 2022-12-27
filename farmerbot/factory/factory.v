module factory

import freeflowuniverse.crystallib.actionparser
import freeflowuniverse.crystallib.pathlib
import freeflowuniverse.crystallib.texttools
import threefoldtech.farmerbot.system
import threefoldtech.farmerbot.powermanagers
import threefoldtech.farmerbot.node
import regex

pub fn run (path0 string)!system.DB{

	mut db:=system.DB{}

	mut path := pathlib.get_dir(path0, false)!	

	//ADD THE KNOWN POWER MANAGERS
	mut pwr1:=powermanagers.PowerManagerWakeOnLan{}
	mut pwr2:=powermanagers.PowerManagerRacktivity{}
	mut node:=node.NodeManager{}

	mut re := regex.regex_opt(".*") or {panic(err)}
	ar:=path.list(regex:re, recursive:true)!
	for p in ar{
		if p.path.ends_with(".md"){
			mut parser := actionparser.file_parse(p.path)!
			for mut action in parser.actions {
				$if debug {
					print(texttools.indent('$action\n ', '  |  '))
				}
				name := action.name.split(".")[0]
				if name == "powermanager" {
					pwr1.execute(mut &db, mut &action)!
					pwr2.execute(mut &db, mut &action)!
				}
				if name == "node"{
					node.execute(mut &db, mut &action)!
				}		
			}					
		}
	}
	return db
}
