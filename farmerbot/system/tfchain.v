module system

import freeflowuniverse.crystallib.twinclient as tw

import json

pub struct SetNodePowerArgs {
pub mut:
	node_id u32 [json: 'nodeId']
	power bool
}

pub struct ActiveRentContractForNodeArgs {
pub mut:
	nodeid u32 [json: 'nodeId']
}

[heap]
pub interface ITfChain {
mut:
	set_node_power(node_id u32, state PowerState) !
	active_rent_contract_for_node(nodeid u32) !u64
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
	response := http_client.send("nodes.setNodePower", json.encode(args)) or {
		return error("Failed to send ")
	}
	if response.err != "" {
		return error("${response.err}")
	}
}

pub fn (mut t TfChain) active_rent_contract_for_node(nodeid u32) !u64 {
	mut http_client := tw.HttpTwinClient{}
	http_client.init(t.address)!
	
	args := ActiveRentContractForNodeArgs {
		nodeid: nodeid
	}
	response := http_client.send("contracts.activeRentContractForNode", json.encode(args)) or {
		return error("Failed to send ")
	}
	if response.err != "" {
		return error("${response.err}")
	}
	if response.data == "" {
		return 0
	}
	return response.data.u64()
}
