module system

import freeflowuniverse.crystallib.twinclient as tw

import json

pub struct SetNodePowerArgs {
pub mut:
	node_id u32 [json: 'nodeId']
	power bool
}

pub struct ListContractsByTwinIdArgs {
pub mut:
	twinid u32 [json: 'twinId']
}

pub struct TfChainNodeContract {
pub mut:
	id u64 [json: 'contractID']
	//deployment_data TfChainDeploymentData [json: 'deploymentData']
	//state string
	//created_at string [json: 'createdAt']
	//nodeid u32 [json: 'nodeID']
}

pub struct TfChainRentContract {
pub mut:
	id u64 [json: 'contractID']
	// TODO use extra things
}

pub struct TfChainNameContract {
pub mut:
	id u64 [json: 'contractID']
	// TODO use extra things
}

pub struct TfChainContracts {
pub mut:
	name_contracts []TfChainNameContract [json: 'nameContracts']
	node_contracts []TfChainNodeContract [json: 'nodeContracts']
	rent_contracts []TfChainRentContract [json: 'rentContracts']
}

[heap]
pub interface ITfChain {
mut:
	set_node_power(node_id u32, state PowerState) !
	get_contracts_for_twinid(twinid u32) !TfChainContracts
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

pub fn (mut t TfChain) get_contracts_for_twinid(twinid u32) !TfChainContracts {
	mut http_client := tw.HttpTwinClient{}
	http_client.init(t.address)!
	
	args := ListContractsByTwinIdArgs {
		twinid: twinid
	}
	response := http_client.send("contracts.listContractsByTwinId", json.encode(args)) or {
		return error("Failed to send ")
	}
	if response.err != "" {
		return error("${response.err}")
	}
	println(response.data)
	return json.decode(TfChainContracts, response.data)!
}
