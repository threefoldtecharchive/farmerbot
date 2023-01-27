module system

import log

pub fn logger() &log.Logger {
	return &log.Logger(&log.Log{ level: .info })
}