import os
import regex
import x.json2
import net.http

const (

    // Messages

	mess_opening_internet = '\n*** NOTE: You need an Internet connection to run this program properly. ***'
    mess_3node_one_farm = '*** NOTE: Make sure that all 3Nodes are within the same farm. ***\n'

    // Network names

    s_main = 'main'
    s_test = 'test'
    s_qa = 'qa'
    s_dev = 'dev'

    // Questions

    q_mnemonic = '\nWhat is the mnemonic or HEX secret of your farm? \n'
    q_network = 'What is the network? (main, test, qa, dev)? \n'
    q_nodes = 'How many nodes do you have? \n'
    q_node_id = 'What is your node ID? (node number '
    q_shutdown = 'Should this node never be shut down? (yes/no) \nOPTIONAL: Press ENTER to skip.\n'
    q_cpu = 'How much the cpu can be overprovisioned? (between 1 and 4) (i.e. 2 means double the amount of cpus)\nOPTIONAL: Press ENTER to skip.\n'
    q_wakeup_limi = 'What is the periodic wake up limit? (i.e. how many nodes can wake up at the same time) (minimum value = 1)\nOPTIONAL: If you press ENTER, the default value will be taken, which is 1.\n'
    q_threshold = 'What is your wake up threshold? (between 50 and 80)\n'
    q_periodic_wakeup = 'What is the periodic wake up? (e.g. 8:30AM or 10:30PM) (Always in UTC)\n'

    // Errors

    err_input = 'Failed to read the input.'
    err_create = 'Failed to create the file.'
    err_write = 'Failed to write in the file.'
    err_json = 'Failed to decode json.'
    err_internet = '\nCheck your Internet connection.'
    err_node_network = '\nMake sure the node exists on the selected network.'
    err_choice_network = 'ERROR: The network must be either main, dev, qa or test.\n'
    err_non_zero_int = 'ERROR: The number must be a nonzero integer.\n'
    err_yes_no = 'ERROR: Either answer yes, no or press ENTER.\n'
    err_int_1_4 = 'ERROR: The number must be an integer and between 1 and 4 inclusively.\n'
    err_int_50_80 = 'ERROR: The number must be an integer and between 50 and 80 inclusively.\n'
    err_int_1_100 = 'ERROR: The number must be an integer and between 1 and 100 inclusively.\n'
    err_12h_format = 'The input should be in 12-hour format (e.g. 1:30AM or 12:30PM).\n'

    // Regex

    reg_int = '^[0-9]*$'
    reg_12h_format = '^(1[0-2])|[0-9]:[0-5][0-9](AM)|(PM)$'

    // Directory names
    name_config = 'config'

    // File names

    file_env = '.env'
    file_config = 'config.md'

    // .env string outputs

    s_secret = 'SECRET=\"'
    s_network = 'NETWORK='
    s_relay = 'RELAY=wss://relay.grid.tf:443'
    s_substrate = 'SUBSTRATE=wss://tfchain.grid.tf:443'

    // config.md string outputs

    s_farm_id = 'farmId'
    s_farm_config = 'Farm configuration'
    s_power_config = 'Power configuration'
    s_farm_manager = '!!farmerbot.farmmanager.define'
    s_power_manager = '!!farmerbot.powermanager.define'
    s_id = '\tid:'
    s_periodic_wakeup = '\tperiodic_wakeup:'
    s_periodic_wakeup_limit = '\tperiodic_wakeup_limit:'
    s_threshold = '\twake_up_threshold:'
    s_no_entry = ''
    s_cpu = '\tcpuoverprovision:'
    s_yes = 'yes'
    s_no = 'no'
    s_shutdown = '\tnever_shutdown:1'
    s_pub_config_false = '\tpublic_config:false'
    s_pub_config_true = '\tpublic_config:true'
    s_pub_config = 'publicConfig'
    s_cert_no = '\tcertified:no'
    s_cert_yes = '\tcertified:yes'
    s_certified = "Certified"
    s_cert_type = 'certificationType'
    s_dedicated_true = '\tdedicated:1'
    s_dedicated = 'dedicated'
    s_true = 'true'
    s_twin_id = 'twinId'
    s_twin_id_input = '\ttwinid:'
    s_node_config = 'Nodes Configuration'
    s_node_manager = '!!farmerbot.nodemanager.define'
    s_ip = '\"ip\"'
    s_pub_ip_input = '\tpublic_ips:'

    // Public config names

    gw4 = '\"gw4\":\"\"'
    gw6 = '\"gw4\":\"\"'
    ipv4 = '\"ipv4\":\"\"'
    ipv6 = '\"ipv6\":\"\"'

)

fn main() {

    println(mess_opening_internet)

    // Regex functions
    is_int := regex.regex_opt(reg_int) or {eprintln(err_input) return}
    is_12h_format := regex.regex_opt(reg_12h_format) or {eprintln(err_input) return}
    
    // Section 0: Creating and going into the directory

    // Path to current directory
    parent_dir := os.getwd()

    // Path to config directory
    config_dir := parent_dir + "/" + name_config

    // Create the directory 
    os.mkdir(config_dir) or {}

    // Remove .env and config.md if they exist
    path_env := parent_dir + "/" + file_env
    path_config := config_dir + "/" + file_config

    os.rm(path_env) or {}
    os.rm(path_config) or {}

    // SECTION 1: Creating the .env file
    // Setting the seed phrase

    mut this_file := os.create(file_env) or {eprintln(err_create) return}
    mut answer := os.input(q_mnemonic)

    // Mutable strings

    mut grid_url_node := ""
    mut network_farm := ""

    this_file.writeln(s_secret + answer+'\"') or {eprintln(err_write) return}
    println(s_no_entry)

    // Setting the network

    for {

        answer = os.input(q_network)
        println(s_no_entry)

        if answer == s_main {

            this_file.writeln(s_network + answer) or {eprintln(err_write) return}
            this_file.writeln(s_relay) or {eprintln(err_write) return}
            this_file.writeln(s_substrate) or {eprintln(err_write) return}
            grid_url_node = 'https://gridproxy.grid.tf/nodes/'
            network_farm = answer
            break

        } else if answer == s_test || answer == s_qa || answer == s_dev {

            this_file.writeln(s_network + answer) or {eprintln(err_write) return}
            this_file.writeln('RELAY=wss://relay.'+answer+'.grid.tf:443') or {eprintln(err_write) return}
            this_file.writeln('SUBSTRATE=wss://tfchain.'+answer+'.grid.tf:443') or {eprintln(err_write) return}
            grid_url_node = 'https://gridproxy.' + answer + '.grid.tf/nodes/'
            network_farm = answer  
            break    

        } else {

            println(err_choice_network)

        }

    }

    this_file.close()

    // SECTION 2: Creating the config.md file

    // Change to config directory
    os.chdir(config_dir) or {}

    // Create the file config.md
    this_file = os.create(file_config) or {eprintln(err_create) return}

    println(mess_3node_one_farm)

    for {

        nodes := os.input(q_nodes)
        println(s_no_entry)

        if is_int.matches_string(nodes) && nodes.u32() >= 1 && nodes.u32() <= 1000 {

            mut i := 0
            for i <= (nodes.u32() - 1) {

                for {
                    nbi := i + 1
                    nb := nbi.str()

                    answer = os.input(q_node_id + nb + ')\n')
                    println(s_no_entry)

                    if is_int.matches_string(answer) && answer.u32() >= 1 {

                        // Get info from node ID to fill up other parameters of the node section
						result_get_proxy := http.get_text(grid_url_node + answer)
						decoded := json2.raw_decode(result_get_proxy) or {eprintln(err_json + err_internet) return}
						m := decoded.as_map()

                        mut farm_id := m[s_farm_id] or {eprintln(err_json + err_node_network) return}

                        // SECTION 2.1: Farm Manager section
                        // For the first node, retrieve and print in config.md information the farm
                        if nb == "1" {
                        this_file.writeln(s_farm_config) or {eprintln(err_write) return}
                        this_file.writeln(s_farm_manager) or {eprintln(err_write) return}
                        this_file.writeln(s_id + farm_id.str()) or {eprintln(err_write) return}

                        // Retrieve number of IP addresses for the given farm
                        mut grid_url_farm := ""

                        if network_farm == s_main {
                            grid_url_farm = "https://gridproxy.grid.tf/farms?farm_id=" + farm_id.str()

                        } else if network_farm != s_main {

                            grid_url_farm = "https://gridproxy." + network_farm + ".grid.tf/farms?farm_id=" + farm_id.str()

                        }
                    
                        result_get_proxy_farm := http.get_text(grid_url_farm)
						decoded_farm := json2.raw_decode(result_get_proxy_farm) or {eprintln(err_json) return}
                        string_farm := decoded_farm.str()

                        iter_ip := string_farm.count(s_ip)

                        this_file.writeln(s_pub_ip_input + iter_ip.str()) or {eprintln(err_write) return}

                        this_file.writeln("") or {eprintln(err_write) return}

                        }

                        // SECTION 2.2: Node Manager section
                        this_file.writeln(s_node_config) or {eprintln(err_write) return}
                        this_file.writeln(s_node_manager) or {eprintln(err_write) return}
                        this_file.writeln(s_id + answer) or {eprintln(err_write) return}

                        // Get twinID status
						twinid := m[s_twin_id] or {eprintln(err_json) return}
						this_file.writeln(s_twin_id_input + twinid.str()) or {eprintln(err_write) return}

                        // Get dedicated status
						dedicated := m[s_dedicated] or {eprintln(err_json) return}
						    if dedicated.str() == s_true {
							    this_file.writeln(s_dedicated_true) or {eprintln(err_write) return}
						    }

                        // Get certification status
						certified := m[s_cert_type] or {eprintln(err_json) return}
						    if certified.str() == s_certified {
							    this_file.writeln(s_cert_yes) or {eprintln(err_write) return}
						    } else {
                                this_file.writeln(s_cert_no) or {eprintln(err_write) return}
                            }

                        // Check if there are public configurations
                        public_config := m[s_pub_config]or {eprintln(err_json) return}
                        p_str := public_config.str()


                        if p_str.contains(gw4) && p_str.contains(gw6) && p_str.contains(ipv4) && p_str.contains(ipv6) {
                            this_file.writeln(s_pub_config_false) or {eprintln(err_write) return}
                        } else {
                            this_file.writeln(s_pub_config_true) or {eprintln(err_write) return}
                        }

                        // Get farm ID
						farm_id_json := m[s_farm_id] or {eprintln(err_json) return}
						farm_id = farm_id_json.str()

                        break

                    } else {
                        println(err_non_zero_int)   
                    }
                }

                for {

                    answer = os.input(q_shutdown)
                    println(s_no_entry)

                    if answer == s_yes {

                        this_file.writeln(s_shutdown) or {eprintln(err_write) return}
                        break
                        
                    } else if answer == s_no || answer == s_no_entry {
   
                        break    

                    } else {

                        println(err_yes_no)

                    }

                }

                for {

                    answer = os.input(q_cpu)
                    println(s_no_entry)

                    if is_int.matches_string(answer) && answer.u32() >= 1 && answer.u32() <= 4 {

                        this_file.writeln(s_cpu + answer) or {eprintln(err_write) return}
                        break

                        } else if answer == s_no_entry {
    
                            break    

                        } else {

                            println(err_int_1_4)

                        }

                }

                this_file.writeln(s_no_entry) or {eprintln(err_write) return}
                i++
            }

            break

        } else {
            println(err_non_zero_int)
            println(s_no_entry)
        }

    }

    // SECTION 2.3: Power Manager section

    this_file.writeln(s_power_config) or {eprintln(err_write) return}
    this_file.writeln(s_power_manager) or {eprintln(err_write) return}

    for {

        answer = os.input(q_threshold)
        println(s_no_entry)

        if is_int.matches_string(answer) && answer.u32() >=50 && answer.u32() <=80 {

            this_file.writeln(s_threshold + answer) or {eprintln(err_write) return}
            break

        } else {
            println(err_int_50_80)   
        }
    }

    for {

        answer = os.input(q_wakeup_limi)
        println(s_no_entry)

        if is_int.matches_string(answer) && answer.u32() >=1 && answer.u32() <=100 {

            this_file.writeln(s_periodic_wakeup_limit + answer) or {eprintln(err_write) return}
            break

        } else if answer == s_no_entry {
    
            break    

        } else {
            println(err_int_1_100)   
        }
    }

    for {

        answer = os.input(q_periodic_wakeup)
        println(s_no_entry)

        if is_12h_format.matches_string(answer) {

            this_file.writeln(s_periodic_wakeup + answer) or {eprintln(err_write) return}
            break

        } else {
                println(err_12h_format)   
        }
    }

    // Go back to the to parent directory
    os.chdir(parent_dir) or {}

    this_file.close()

}