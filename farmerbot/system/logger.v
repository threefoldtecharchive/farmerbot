module system

import log
import os

pub fn logger() &log.Logger {
	println(os.environ()["FARMERBOT_LOG_LEVEL"].to_upper())
	level := match os.environ()["FARMERBOT_LOG_LEVEL"].to_upper() {
		"DEBUG" {
			log.Level.debug
		}
		else {
			log.Level.info
		}
	}
	return &log.Logger(&log.Log{ level: level })
}