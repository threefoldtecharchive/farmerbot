module main
import time
// import os
// import threefoldtech.farmerbot.factory
import os

const testpath = os.dir(@FILE) + '/example_data'


fn do() ! {
	mut db:=factory.run(testpath)!
	println(db)
}	

fn main() {
	do() or { panic(err) }
}
