module system

import log
import os

pub fn logger() &log.Logger {
	level := match os.environ()["FARMERBOT_LOG_LEVEL"].to_upper() {
		"DEBUG" {
			log.Level.debug
		}
		else {
			log.Level.info
		}
	}
	output_file := os.environ()["FARMERBOT_LOG_OUTPUT"]
	mut l := &log.Log{ level: level }
	if output_file != "" {
		l.set_full_logpath(output_file)
	}
	return &log.Logger(l)
}