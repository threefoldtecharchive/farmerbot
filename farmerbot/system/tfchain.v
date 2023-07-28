module system

import freeflowuniverse.crystallib.twinclient as tw
import json

const (
	cost_extrinsic = 0.001
)

pub struct SetNodePowerArgs {
pub mut:
	node_id u32  [json: 'nodeId']
	power   bool
}

pub struct ActiveRentContractForNodeArgs {
pub mut:
	nodeid u32 [json: 'nodeId']
}

pub struct Balance {
pub mut:
	free     f64
	reserved f64
	frozen   f64
}

[heap]
pub interface ITfChain {
mut:
	set_node_power(node_id u32, state PowerState) !
	active_rent_contract_for_node(nodeid u32) !u64
	get_balance() !Balance
	should_have_enough_balance() !
}

[heap]
pub struct TfChain {
pub mut:
	address string = 'http://127.0.0.1:3000'
}

pub fn (mut t TfChain) get_balance() !Balance {
	mut http_client := tw.HttpTwinClient{}
	http_client.init(t.address)!

	response := http_client.send('balance.getMyBalance', '') or {
		return error('Failed to send: ${err}')
	}
	if response.err != '' {
		return error('Error while calling get_my_balance: ${response.err}')
	}
	return json.decode(Balance, response.data)
}

pub fn (mut t TfChain) should_have_enough_balance() ! {
	balance := t.get_balance() or { return error('Failed to get balance: ${err}') }
	if balance.free < system.cost_extrinsic {
		return error('Not enough balance. You need TFT to power on or off nodes.')
	}
}

pub fn (mut t TfChain) set_node_power(node_id u32, state PowerState) ! {
	t.should_have_enough_balance()!
	mut http_client := tw.HttpTwinClient{}
	http_client.init(t.address)!

	args := SetNodePowerArgs{
		node_id: node_id
		power: match state {
			.on { true }
			.off { false }
			else { return error('The node power can only be set to on or off!') }
		}
	}
	response := http_client.send('nodes.setNodePower', json.encode(args)) or {
		return error('Failed to send: ${err}')
	}
	if response.err != '' {
		return error('Error while calling set_node_power: ${response.err}')
	}
}

pub fn (mut t TfChain) active_rent_contract_for_node(nodeid u32) !u64 {
	mut http_client := tw.HttpTwinClient{}
	http_client.init(t.address)!

	args := ActiveRentContractForNodeArgs{
		nodeid: nodeid
	}
	response := http_client.send('contracts.activeRentContractForNode', json.encode(args)) or {
		return error('Failed to send: ${err}')
	}
	if response.err != '' {
		return error('Error while calling active_rent_contract_for_node: ${response.err}')
	}
	if response.data == '' {
		return 0
	}
	return response.data.u64()
}
