module system

import log
import os

pub fn logger() &log.Logger {
	environment_variables := os.environ()
	level := match environment_variables['FARMERBOT_LOG_LEVEL'].to_upper() {
		'DEBUG' {
			log.Level.debug
		}
		else {
			log.Level.info
		}
	}
	output_file := environment_variables['FARMERBOT_LOG_OUTPUT']
	log_to_console := environment_variables['FARMERBOT_LOG_CONSOLE'].to_upper()
	mut l := &log.Log{
		level: level
	}
	if output_file != '' {
		l.set_full_logpath(output_file)
		if log_to_console == "" || log_to_console == "1" || log_to_console == "TRUE" {
			l.log_to_console_too()
		}
	}
	return &log.Logger(l)
}
