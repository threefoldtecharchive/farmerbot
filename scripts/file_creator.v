import os
import regex
import x.json2
import net.http

fn main() {

    // Regex functions
    is_int := regex.regex_opt("^[0-9]*$") or {panic(err)}
    is_12h_format := regex.regex_opt("^(1[0-2])|[0-9]:[0-5][0-9](AM)|(PM)$") or {panic(err)}

    // Section 0: Creating and going into the directory

    // Name of config directory
    config_name := "config"

    // Path to current directory
    parent_dir := os.getwd()

    // Path to config directory
    config_dir := parent_dir + "/" + config_name

    // Create the directory 
    os.mkdir(config_dir) or {}

    // Remove .env and config.md if they exist
    path_env := parent_dir + "/" + ".env"
    path_config := config_dir + "/" + "config.md"

    os.rm(path_env) or {}
    os.rm(path_config) or {}

    // Change to parent directory
    os.chdir(parent_dir) or {}

    // SECTION 1: Creating the .env file
    // Setting the seed phrase

    mut this_file := os.create(".env")!

    mut answer := os.input('\nWhat is the mnemonic or HEX secret of your farm? \n')

	mut grid_url_node := ""

    mut network_farm := ""

    this_file.writeln('SECRET=\"'+answer+'\"')!
    println("")

    // Setting the network

    for {

        answer = os.input('What is the network? (main, test, qa, dev)? \n')
        println("")

        if answer == "main" {

            this_file.writeln('NETWORK='+answer)!
            this_file.writeln('RELAY=wss://relay.grid.tf:443')!
            this_file.writeln('SUBSTRATE=wss://tfchain.grid.tf:443')!
			grid_url_node = 'https://gridproxy.grid.tf/nodes/'
            network_farm = answer
            break

        } else if answer == "test" || answer == "qa" || answer == "dev" {

            this_file.writeln('NETWORK='+answer)!
            this_file.writeln('RELAY=wss://relay.'+answer+'.grid.tf:443')!
            this_file.writeln('SUBSTRATE=wss://tfchain.'+answer+'.grid.tf:443')! 
			grid_url_node = 'https://gridproxy.' + answer + '.grid.tf/nodes/'
            network_farm = answer  
            break    

        } else {

            println('ERROR: The network must be either main, dev, qa or test.\n')

        }

    }

    this_file.close()

    // SECTION 2: Creating the config.md file

    // Change to config directory
    os.chdir(config_dir) or {}

    // Create the file config.md
    this_file = os.create("config.md")!

    println("**** WARNING: Make sure all 3nodes are within the same farm. ****\n")

    for {

        nodes := os.input('How many nodes do you have? \n')
        println("")

        if is_int.matches_string(nodes) && nodes.u32() >= 1 && nodes.u32() <= 1000 {

            mut i := 0
            for i <= (nodes.u32() - 1) {

                for {
                    nbi := i + 1
                    nb := nbi.str()

                    answer = os.input('What is your node ID? (node number ' + nb+ ')\n')
                    println("")

                    if is_int.matches_string(answer) && answer.u32() >= 1 {

                        // Get info from node ID to fill up other parameters of the node section
						result_get_proxy := http.get_text(grid_url_node + answer)
						decoded := json2.raw_decode(result_get_proxy)!
						m := decoded.as_map()

                        mut farm_id := m['farmId'] or {eprintln('Failed to decode json')
						return}

                        // SECTION 2.1: Farm Manager section
                        // For the first node, retrieve and print in config.md information the farm
                        if nb == "1" {
                        this_file.writeln('Farm configuration')!
                        this_file.writeln('!!farmerbot.farmmanager.define')!
                        this_file.writeln('\tid:' + farm_id.str())!

                        // Retrieve number of IP addresses for the given farm
                        mut grid_url_farm := ""

                        if network_farm == "main" {
                            grid_url_farm = "https://gridproxy.grid.tf/farms?farm_id=" + farm_id.str()

                        } else if network_farm != "main" {

                            grid_url_farm = "https://gridproxy." + network_farm + ".grid.tf/farms?farm_id=" + farm_id.str()

                        }
                    
                        result_get_proxy_farm := http.get_text(grid_url_farm)
						decoded_farm := json2.raw_decode(result_get_proxy_farm)!
                        string_farm := decoded_farm.str()
                    
                        ip_str := "\"ip\""

                        iter_ip := string_farm.count(ip_str)

                        this_file.writeln('\tpublic_ips:' + iter_ip.str())!

                        this_file.writeln("")!

                        }

                        // SECTION 2.2: Node Manager section
                        this_file.writeln('Nodes Configuration')!
                        this_file.writeln('!!farmerbot.nodemanager.define')!
                        this_file.writeln('\tid:' + answer)!

                        // Get twinID status
						twinid := m['twinId'] or {eprintln('Failed to decode json')
							return}
						this_file.writeln('\ttwinid:' + twinid.str())!

                        // Get dedicated status
						dedicated := m['dedicated'] or {eprintln('Failed to decode json')
							return}
						this_file.writeln('\tdedicated:'+dedicated.str())!

                        // Get certification status
						certified := m['certificationType'] or {eprintln('Failed to decode json')
							return}
						    if certified.str() == "Certified" {
							    this_file.writeln('\tcertified:true')!
						    } else {

                                this_file.writeln('\tcertified:false')!
                            }

                        // Check if there are public configurations
                        public_config := m['publicConfig']or {eprintln('Failed to decode json')
							return}
                        p_str := public_config.str()
                        gw4 := "\"gw4\":\"\""
                        gw6 := "\"gw4\":\"\""
                        ipv4 := "\"ipv4\":\"\""
                        ipv6 := "\"ipv6\":\"\""

                        if p_str.contains(gw4) && p_str.contains(gw6) && p_str.contains(ipv4) && p_str.contains(ipv6) {
                            this_file.writeln('\tpublic_config:false')!
                        } else {
                            this_file.writeln('\tpublic_config:true')!
                        }

                        // Get farm ID
						farm_id_json := m['farmId'] or {eprintln('Failed to decode json')
							return}
						farm_id = farm_id_json.str()

                        break

                    } else {
                        println('ERROR: The number must be a nonzero integer.\n')   
                    }
                }

                for {

                    answer = os.input('Should this node never be shut down? (yes/no) \nOPTIONAL: Press ENTER to skip.\n')
                    println("")

                    if answer == "yes" {

                        this_file.writeln('\tnever_shutdown:1')!
                        break
                        
                    } else if answer == "no" || answer == "" {
   
                        break    

                    } else {

                        println('ERROR: Either answer yes, no or press ENTER.\n')

                    }

                }

                for {

                    answer = os.input('How much the cpu can be overprovisioned? (between 1 and 4) (i.e. 2 means double the amount of cpus)\nOPTIONAL: Press ENTER to skip.\n')
                    println("")

                    if is_int.matches_string(answer) && answer.u32() >= 1 && answer.u32() <= 4 {

                        this_file.writeln('\tcpuoverprovision:' + answer)!
                        break

                        } else if answer == "" {
    
                            break    

                        } else {

                            println('ERROR: The number must be an integer and between 1 and 4 inclusively.\n')

                        }

                }

                this_file.writeln("")!
                i++
            }

            break

        } else {
            println('ERROR: The number must be an nonzero integer.')
            println("")
        }

    }

    // SECTION 2.3: Power Manager section

    this_file.writeln('Power configuration')!
    this_file.writeln('!!farmerbot.powermanager.define')!

    for {

        answer = os.input('What is your wake up threshold? (between 50 and 80)\n')
        println("")

        if is_int.matches_string(answer) && answer.u32() >=50 && answer.u32() <=80 {

            this_file.writeln('\twake_up_threshold:' + answer)!
            break

        } else {
            println('ERROR: The number must be an integer and between 50 and 80 inclusively.\n')   
        }
    }

    for {

        answer = os.input('What is the periodic wake up limit? (i.e. how many nodes can wake up at the same time) (minimum value = 1)\nOPTIONAL: If you press ENTER, the default value will be taken, which is 1.\n')
        println("")

        if is_int.matches_string(answer) && answer.u32() >=1 && answer.u32() <=100 {

            this_file.writeln('\tperiodic_wakeup_limit:' + answer)!
            break

        } else if answer == "" {
    
            break    

        } else {
            println('ERROR: The number must be an integer and between 1 and 100 inclusively.\n')   
        }
    }

    for {

        answer = os.input('What is the periodic wake up? (e.g. 8:30AM or 10:30PM) (Always in UTC)\n')
        println("")

        if is_12h_format.matches_string(answer) {

            this_file.writeln('\tperiodic_wakeup:' + answer)!
            break

        } else {
                println('The input should be in 12-hour format (e.g. 1:30AM or 12:30PM).\n')   
        }
    }

    this_file.close()

}