import os
import regex
import json
import net.http
import freeflowuniverse.crystallib.markdowndocs { Action, Doc }
import freeflowuniverse.crystallib.params { Params }
import freeflowuniverse.crystallib.pathlib { get_file }

const (
	// Messages

	mess_opening_internet   = '\n*** NOTE: You need an Internet connection to run this program properly. ***'
	mess_3node_one_farm     = '*** NOTE: Make sure that all 3Nodes are within the same farm. ***\n'
	mess_end_program        = '*** NOTE: The files config/config.md and .env have now been created.\nYou can now run the Farmerbot with docker.***\n'

	// Questions

	q_mnemonic              = '\nWhat is the mnemonic or HEX secret of your farm? \n'
	q_network               = 'What is the network? (main, test, qa, dev)? \n'
	q_nodes                 = 'How many nodes do you have? \n'
	q_node_id               = 'What is your node ID? (node number '
	q_shutdown              = 'Should this node never be shut down? (yes/no) \nOPTIONAL: Press ENTER to skip.\n'
	q_cpu                   = 'How much the cpu can be overprovisioned? (between 1 and 4) (i.e. 2 means double the amount of cpus)\nOPTIONAL: Press ENTER to skip.\n'
	q_wakeup_limit          = 'What is the periodic wake up limit? (i.e. how many nodes can wake up at the same time) (minimum value = 1)\nOPTIONAL: If you press ENTER, the default value will be taken, which is 1.\n'
	q_threshold             = 'What is your wake up threshold? (between 50 and 80)\n'
	q_periodic_wakeup       = 'What is the periodic wake up? (e.g. 8:30AM or 10:30PM) (Always in UTC)\n'

	// Errors

	err_input               = 'Failed to read the input.'
	err_create              = 'Failed to create the file.'
	err_write               = 'Failed to write in the file.'
	err_json                = 'Failed to decode json.'
	err_internet            = '\nCheck your Internet connection.'
	err_node_network        = '\nMake sure the node exists on the selected network.'
	err_choice_network      = 'ERROR: The network must be either main, dev, qa or test.\n'
	err_non_zero_int        = 'ERROR: The number must be a nonzero integer.\n'
	err_int_gt_one          = 'ERROR: The number must be an integer between 2 and 1000 inclusively.\n'
	err_yes_no              = 'ERROR: Either answer yes, no or press ENTER.\n'
	err_int_1_4             = 'ERROR: The number must be an integer and between 1 and 4 inclusively.\n'
	err_int_50_80           = 'ERROR: The number must be an integer and between 50 and 80 inclusively.\n'
	err_int_1_100           = 'ERROR: The number must be an integer and between 1 and 100 inclusively.\n'
	err_12h_format          = 'The input should be in 12-hour format (e.g. 1:30AM or 12:30PM).\n'
	err_save_wiki           = 'The markdown file couldn not save properly.'
	err_path                = 'Failed to create file in path.'

	// Regex

	reg_int                 = '^[0-9]*$'
	reg_12h_format          = '^(1[0-2])|[0-9]:[0-5][0-9](AM)|(PM)$'

	// File names

	file_env                = '.env'
	file_config             = 'config/config.md'

	// Network names

	s_main                  = 'main'
	s_test                  = 'test'
	s_qa                    = 'qa'
	s_dev                   = 'dev'

	// .env string outputs

	s_secret                = 'SECRET="'
	s_network               = 'NETWORK='
	s_relay                 = 'RELAY=wss://relay.grid.tf:443'
	s_substrate             = 'SUBSTRATE=wss://tfchain.grid.tf:443'

	// config.md string outputs

	s_farm_manager          = 'farmerbot.farmmanager.define'
	s_power_manager         = 'farmerbot.powermanager.define'
	s_node_manager          = 'farmerbot.nodemanager.define'
	s_farm_id               = 'farmId'
	s_id                    = 'id'
	s_twin_id               = 'twinId'
	s_twin_id_input         = 'twinid'

	s_periodic_wakeup       = 'periodic_wakeup'
	s_periodic_wakeup_limit = 'periodic_wakeup_limit'
	s_threshold             = 'wake_up_threshold'
	s_no_entry              = ''
	s_cpu                   = 'cpuoverprovision'
	s_yes                   = 'yes'
	s_no                    = 'no'
	s_shutdown              = 'never_shutdown'
	s_pub_config            = 'public_config'
	s_cert                  = 'certified'
	s_certified             = 'Certified'
	s_dedicated             = 'dedicated'

	s_ip                    = '"ip"'
	s_pub_ip_input          = 'public_ips'

	s_true                  = 'true'
	s_false                 = 'false'
)

// main
// This program ask the farmers information on the farm and its 3nodes to create the .env and config/config.md files needed to run the farmerbot
fn main() {
	// Print the opening message to the user
	println(mess_opening_internet)

	// WRITE .ENV FILE
	// create_env_file Create .env file and return strings network_farm and grid_url_node
	network_farm, grid_url_node := create_env_file()

	path_config := get_file(file_config, true) or {
		println(err_path)
		exit(1)
	}

	// Create Doc object doc that stores the .md file information
	mut doc := Doc{
		path: path_config
	}

	// Print the message specifying all nodes should be from the same farm
	println(mess_3node_one_farm)

	// get the node manager parameters for each node
	param_array, farm_id_string := config_nodes(grid_url_node)

	// Create the section farm manager in config.md
	doc_config_farm(farm_id_string, network_farm, mut doc)

	// Create the section power manager in config.md
	doc_config_power(mut doc)

	// Create the section node manager in config.md
	doc_config_node(param_array, mut doc)

	// Save the markdown file config/config.md
	doc.save_wiki() or { println(err_save_wiki) }

	println(mess_end_program)
}

// Struct for gridproxy json query

struct Node_json {
	nodeid            int          [json: 'nodeId']
	farmid            int          [json: 'farmId']
	twinid            int          [json: 'twinId']
	certificationtype string       [json: 'certificationType']
	dedicated         bool
	publicconfig      PublicConfig [json: 'publicConfig']
}

// Struct for publicconfig element of Node_json struct
struct PublicConfig {
	domain string
	gw4    string
	gw6    string
	ipv4   string
	ipv6   string
}

// doc_config_farm
// Create the section farm manager in config.md
fn doc_config_farm(farm_id_string string, network_farm string, mut doc Doc) {
	// WRITE CONFIG.MD FILE
	// Write farm manager section in config/config.md
	doc.items << Action{
		name: s_farm_manager
		params: config_farm(farm_id_string, network_farm)
	}
}

// doc_config_power
// Create the section power manager in config.md
fn doc_config_power(mut doc Doc) {
	// Write power manager section in config/config.md
	doc.items << Action{
		name: s_power_manager
		params: config_power()
	}
}

// doc_config_node
// Create the section node manager in config.md
fn doc_config_node(param_array []Params, mut doc Doc) {
	// Write node manager section in config/config.md
	mut i := 0
	for i < param_array.len {
		doc.items << Action{
			name: s_node_manager
			params: param_array[i]
		}
		i++
	}
}

fn config_farm(farm_id_string string, network_farm string) Params {
	// SECTION 2.1: Farm Manager section
	// For the first node, retrieve and print in config.md information for the farm manager
	// FARM MANAGER
	// Add the farm ID in farm params
	mut params_farm := Params{}
	params_farm.kwarg_add(s_id, farm_id_string)

	// Retrieve number of IP addresses for the given farm
	mut grid_url_farm := ''

	// Query the proper network (main, test, dev, qa)
	if network_farm == s_main {
		grid_url_farm = 'https://gridproxy.grid.tf/farms?farm_id=' + farm_id_string
	} else if network_farm != s_main {
		grid_url_farm = 'https://gridproxy.' + network_farm + '.grid.tf/farms?farm_id=' +
			farm_id_string
	}

	// Count the number of "ip" iteration in the json (string)
	iter_ip := http.get_text(grid_url_farm).count(s_ip)

	// Add the number of IP addresses in the farm params
	params_farm.kwarg_add(s_pub_ip_input, iter_ip.str())

	return params_farm
}

// config_power
// Query the power parameters
fn config_power() Params {
	// POWER MANAGER
	// Set the power manager configs in config/config.md
	mut params_power := Params{}
	params_power.kwarg_add(s_threshold, wake_up_treshold_ask())
	params_power.kwarg_add(s_periodic_wakeup_limit, wake_up_limit_ask())
	params_power.kwarg_add(s_periodic_wakeup, periodic_wakeup_ask())

	return params_power
}

// is_int
// Return true if string is only composed of integers
fn is_int(s string) bool {
	is_int_regex := regex.regex_opt(reg_int) or {
		eprintln(err_input)
		return false
	}

	bool_var := is_int_regex.matches_string(s)
	return bool_var
}

// is_int
// Return true if string is in 12h format
fn is_12h_format(s string) bool {
	is_12h_format_regex := regex.regex_opt(reg_12h_format) or {
		eprintln(err_input)
		return false
	}

	bool_var := is_12h_format_regex.matches_string(s)
	return bool_var
}

// wake_up_treshold_ask
// Ask the wakeup threshold limit (from 50 to 80)
fn wake_up_treshold_ask() string {
	mut answer_return := ''

	for {
		answer := os.input(q_threshold)
		println(s_no_entry)

		answer_int := answer.u32()

		if is_int(answer) && answer_int >= 50 && answer_int <= 80 {
			answer_return = answer
			break
		} else {
			println(err_int_50_80)
		}
	}

	return answer_return
}

// wake_up_limit_ask
// Ask the wake up limit
fn wake_up_limit_ask() string {
	mut answer_return := ''

	for {
		answer := os.input(q_wakeup_limit)
		println(s_no_entry)

		answer_int := answer.u32()

		if is_int(answer) && answer_int >= 1 && answer_int <= 100 {
			answer_return = answer
			break
		} else if answer == '' {
			answer_return = '1'
			break
		} else {
			println(err_int_1_100)
		}
	}

	return answer_return
}

// periodic_wakeup_ask
// Ask the periodic wakeup time
fn periodic_wakeup_ask() string {
	mut answer_return := ''

	for {
		answer := os.input(q_periodic_wakeup)
		println(s_no_entry)

		if is_12h_format(answer) {
			answer_return = answer
			break
		} else {
			println(err_12h_format)
		}
	}

	return answer_return
}

// create_env_file
// Create the .env file with all necessary information.
// Return an array with network_farm and grid_url_node
fn create_env_file() (string, string) {
	// SECTION 1: Creating the .env file
	// Setting the seed phrase

	// Mutable strings
	mut grid_url_node := ''
	mut network_farm := ''

	os.rm(os.getwd() + file_env) or {}

	mut this_file := os.create(file_env) or {
		eprintln(err_create)
		return network_farm, grid_url_node
	}
	mut answer := os.input(q_mnemonic)

	this_file.writeln(s_secret + answer + '"') or {
		eprintln(err_write)
		return network_farm, grid_url_node
	}
	println(s_no_entry)

	// Setting the network

	for {
		answer = os.input(q_network)
		println(s_no_entry)

		if answer == s_main {
			this_file.writeln(s_network + answer) or {
				eprintln(err_write)
				return network_farm, grid_url_node
			}
			this_file.writeln(s_relay) or {
				eprintln(err_write)
				return network_farm, grid_url_node
			}
			this_file.writeln(s_substrate) or {
				eprintln(err_write)
				return network_farm, grid_url_node
			}
			grid_url_node = 'https://gridproxy.grid.tf/nodes/'
			network_farm = answer
			break
		} else if answer == s_test || answer == s_qa || answer == s_dev {
			this_file.writeln(s_network + answer) or {
				eprintln(err_write)
				return network_farm, grid_url_node
			}
			this_file.writeln('RELAY=wss://relay.' + answer + '.grid.tf:443') or {
				eprintln(err_write)
				return network_farm, grid_url_node
			}
			this_file.writeln('SUBSTRATE=wss://tfchain.' + answer + '.grid.tf:443') or {
				eprintln(err_write)
				return network_farm, grid_url_node
			}
			grid_url_node = 'https://gridproxy.' + answer + '.grid.tf/nodes/'
			network_farm = answer
			break
		} else {
			println(err_choice_network)
		}
	}

	this_file.close()

	return network_farm, grid_url_node
}

fn config_nodes(grid_url_node string) ([]Params, string) {
	// for loop for the number of 3nodes in the farm
	mut farm_id_string := ''
	mut param_array := []Params{}
	for {
		// Ask how many 3nodes there are in the farm
		nodes := os.input(q_nodes)
		println(s_no_entry)

		number_of_nodes := nodes.u32()

		// Get into the 3node parameters section if the number of nodes is between 2 and 1000 inclusively
		if is_int(nodes) && number_of_nodes > 1 && number_of_nodes <= 1000 {
			param_array = []Params{len: int(number_of_nodes)}
			mut i := 0

			// Iterate over each node
			for i < number_of_nodes {
				// initialize the node
				mut params_node := Params{}
				for {
					nbi := i + 1
					node_nb := nbi.str()

					// Ask for the node ID
					mut node_id := os.input(q_node_id + node_nb + ')\n')
					println(s_no_entry)

					mut node_id_u32 := node_id.u32()

					// Get into the parameter section if the node ID is valid
					if is_int(node_id) && node_id_u32 >= 1 {
						// Query grid proxy to get the information of the node
						result_get_proxy := http.get_text(grid_url_node + node_id)

						mut decoded := json.decode(Node_json, result_get_proxy) or {
							eprintln(err_json + err_internet)
							return param_array, farm_id_string
						}

						// If it's the first 3node of the series, store the farm ID in a string
						if node_nb == '1' {
							// Get the farm ID associated with the node
							farm_id := decoded.farmid

							farm_id_string = farm_id.str()
						}

						// SECTION 2.2: Node Manager section

						// NODE MANAGER
						// Add the node ID in node params
						params_node.kwarg_add(s_id, node_id)

						// Get twinID status
						twinid := decoded.twinid

						// Add the twin id associated with the node ID in node params
						params_node.kwarg_add(s_twin_id_input, twinid.str())

						// Get dedicated status
						dedicated := decoded.dedicated

						if dedicated.str() == s_true {
							params_node.kwarg_add(s_dedicated, s_true)
						}

						// Get certification status
						certified := decoded.certificationtype

						if certified.str() == s_certified {
							params_node.kwarg_add(s_cert, s_true)
						} else {
							params_node.kwarg_add(s_cert, s_false)
						}

						// Check if there are public configurations
						public_config := decoded.publicconfig

						if public_config.ipv4 != '' || public_config.ipv6 != ''
							|| public_config.gw4 != '' || public_config.gw6 != '' {
							params_node.kwarg_add(s_pub_config, s_true)
						} else {
							params_node.kwarg_add(s_pub_config, s_false)
						}

						break
					} else {
						println(err_non_zero_int)
					}
				}

				// Ask if the node should never be shutdown
				for {
					answer := os.input(q_shutdown)
					println(s_no_entry)

					if answer == s_yes {
						params_node.kwarg_add(s_shutdown, s_true)
						break
					} else if answer == s_no || answer == s_no_entry {
						break
					} else {
						println(err_yes_no)
					}
				}

				// Ask if the cpu should be overprovisioned
				for {
					answer := os.input(q_cpu)
					println(s_no_entry)

					answer_int := answer.u32()

					if is_int(answer) && answer_int >= 1 && answer_int <= 4 {
						params_node.kwarg_add(s_cpu, answer)
						break
					} else if answer == s_no_entry {
						break
					} else {
						println(err_int_1_4)
					}
				}

				param_array[i] = params_node

				i++
			}

			break
		} else {
			println(err_int_gt_one)
			println(s_no_entry)
		}
	}
	return param_array, farm_id_string
}
