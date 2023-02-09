module system

import freeflowuniverse.crystallib.twinclient as tw

import json

pub struct SetNodePowerArgs {
pub mut:
	node_id u32 [json: 'nodeId']
	power bool
}

[heap]
pub interface ITfChain {
mut:
	set_node_power(node_id u32, state PowerState) ! 
}

[heap]
pub struct TfChain {
pub mut:
	address string = "http://localhost:3000"
}

pub fn (mut t TfChain) set_node_power(node_id u32, state PowerState) ! {
	mut http_client := tw.HttpTwinClient{}
	http_client.init(t.address)!
	
	args := SetNodePowerArgs {
		node_id: node_id
		power: match state { 
			.on { true } 
			.off { false } 
			else { return error("The node power can only be set to on or off!") }
		}
	}
	response := http_client.send("farmerbot.setNodePower", json.encode(args))!
	if response.err != "" {
		return error("${response.err}")
	}	
}
