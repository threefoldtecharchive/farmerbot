# Farmerbot
Welcome to the farmerbot. The farmerbot is a service that a farmer can run allowing him to automatically manage the nodes of his farm. 

The key feature of the farmerbot is powermanagement. The farmerbot will automatically shutdown nodes from its farm whenever possible and bring them back on when they are needed using Wake-on-Lan (WOL). It will try to maximize downtime as much as possible by recommending which nodes to use, this is one of the requests that the farmerbot can handle (asking for a node to deploy on).

The behavior of the farmerbot is customizable through markup definition files. You can find an example [here](example_data/nodes.md).

## Dependencies
The farmerbot has the following dependencies
- redis
- [rmb-peer](https://github.com/threefoldtech/rmb-rs/releases)
- [grid3_client_ts http server](https://github.com/threefoldtech/grid3_client_ts/blob/development/docs/http_server.md)

If you are building from scratch you will need these V modules installed:
- [crystallib](https://github.com/freeflowuniverse/crystallib)
- [baobab](https://github.com/freeflowuniverse/baobab)

## Install
You will need to clone the V modules that the farmerbot depends on. Then you can run the bash script $install.sh$:
> run install.sh
The farmerbot has been implemented using the actor model principles. It contains two actors that are able to execute jobs (actions that need to be executed by a specific actor).

## Under the hood
The first actor is the nodemanager which is in charge of executing jobs related to nodes (e.g. finding a suitable node). The second actor is the powermanager which allows us to power on and off nodes in the farm.

Actors can schedule the execution of jobs for other actors which might or might not be running on the same system. For example, the nodemanager might schedule the execution of a job to power on a node (which is meant for the powermanager). The repository [baobab](https://github.com/freeflowuniverse/baobab) contains the logic for scheduling jobs.

Jobs don't have to originate from the system running the farmerbot. It may as well be scheduled from another system (with another twin id). The job to find a suitable node for example will come from the TSClient (which is located on another system). These jobs will be send from the TSClient to the farmerbot via [RMB](https://github.com/threefoldtech/rmb-rs).

### Jobs

Jobs can be send to the farmerbot via RMB. This section describes the arguments that they accept. Please take a look at [baobab](https://github.com/freeflowuniverse/baobab) for more information on how you should construct such a job (**especially how you can add the arguments**).

__farmerbot.nodemanager.findnode__

This job allows you to look for a node with specific requirements (minimum amount of resources, public config, etc). You will get the job id as a result. The farmerbot will power on the node if the node is off. It will also claim the required resources for 30 minutes. After that, if the user has not deployed anything on the node the resources will be freed and the node might go down again if it was put on by that job.

Arguments (all arguments are optional and ):
- _certified_ => whether or not you want a certified node (not adding this argument means you don't care whether you get a certified or non certified node)
- _public_config_ => whether or not you want a node with a public config (not adding this argument means you don't care whether or not the node has a public config)
- _public_ips_ => how much public ips you need
- _dedicated_ => whether you want a dedicated node (rent the full node)
- _node_exclude_ => the node ids you want to exclude in your search
- _required_hru_ => the amount of hru required in kilobytes (add suffix mb or gb to define the required resources in megabyte or gygabite)
- _required_sru_ => the amount of sru required in kilobytes (add suffix mb or gb to define the required resources in megabyte or gygabite)
- _required_mru_ => the amount of mru required in kilobytes (add suffix mb or gb to define the required resources in megabyte or gygabite)
- _required_cru_ => the amount of cru required

Result:
- _nodeid_ => the node id that meets your requirements

__farmerbot.powermanager.poweron__

This job is only allowed to be executed if it comes from the farmer (the twinid should equal the farmer's twinid). It will power on the node specified in the arguments.

Arguments:
- _nodeid_ => the node id of the node that needs to powered on

__farmerbot.powermanager.poweroff__

This job is only allowed to be executed if it comes from the farmer (the twinid should equal the farmer's twinid). It will power off the node specified in the arguments.

Arguments:
- _nodeid_ => the node id of the node that needs to powered off

## Running the farmerbot in production
The farmerbot is shipped inside a [docker image](https://github.com/threefoldtech/farmerbot/pkgs/container/farmerbot) so that it is easy to run in a [docker environment](docker-compose.yaml). It requires some configuration written in a markdown file. This file should be located inside a folder called **config** in the directory of the docker compose file. The possible configuration will be discussed in this section. You should also create a **.env** file next to the docker compose file with the content shown below:
```
SECRET="MNEMONIC_OR_HEX_SECRET_OF_YOUR_FARM"
NETWORK=dev
RELAY=wss://relay.dev.grid.tf:443
SUBSTRATE=wss://tfchain.dev.grid.tf:443
```

Please modify the fields to what is required (network, relay, etc). Now to run the the farmerbot just run the following command (make sure to provide the mnemonic or the hex based secret of your farm):
```
docker compose up
```
The farmerbot should be running after a couple of seconds. It will create a log file inside your config folder called *farmerbot.log*. If you wish to restart a running farmerbot you can run the commands shown below. It can take a couple of seconds before the farmerbot is completely shutdown. But before doing that it might be good to copy or delete the old log file. First stop the farmerbot that is running:
```
docker compose rm -f -s -v
```
Now manually power on the nodes that are off (wait till they are on). Although it is not required to do that it is highly recommended. Finally you can run the new farmerbot:
```
docker compose up -d
```

If the docker-compose file has changed and you wish to run the new version you will have to copy the new docker-compose file. Run the command shown below to do that:
```
wget https://raw.githubusercontent.com/threefoldtech/farmerbot/development/docker-compose.yaml
```
Now follow the steps shown previously to restart the farmerbot.

### Node configuration
The farmerbot will manage the nodes that you define in the configuration.
Required attributes:
- id
- twinid

Optional attributes:
- never_shutdown => true or false telling the farmerbot whether or not the node should never be shutdown
- cpuoverprovision => a value between 1 and 4 defining how much the cpu can be overprovisioned (2 means double the amount of cpus)
- public_config => true or false telling the farmerbot whether or not the node has a public config
- dedicated => true or false telling the farmerbot whether or not the node is dedicated (only allow renting the full node)
- certified => true or false telling the farmerbot whether or not the node is certified

Example:
```
!!farmerbot.nodemanager.define
    id:20
    twinid:105
    public_config:true
    dedicated:1
    certified:yes
    cpuoverprovision:1
    never_shutdown:true
```

### Farm configuration
Two more settings are required regarding the farm:
- id => the id of the farm
- public_ips => the amount of public ips that the farm has (don't forget to set this value)

Example:
```
!!farmerbot.farmmanager.define
    id:3
    public_ips:2
```

### Power configuration
The powermanagement behavior is configurable through the following attributes (they are optional):
- wake_up_threshold => a value between 50 and 80 defining the threshold at which nodes will be powered on or off. If the usage percentage (total used resources devided by the total amount of resources) is greater then the threshold a new node will be powered on. In the other case the farmerbot will try to power off nodes if possible.
- periodic_wakeup => the time at which the periodic wakeups (powering on a node that is off) should happen. The offline nodes will be powered on sequentially with an interval of 5 minutes starting at the time defined in periodic_wakeup.
- periodic_wakeup_limit => by default only one node will be woken up every 5 minutes during a periodic wakeup. You can change that behavior by setting the periodic_wakeup_limit setting. 

Example:
```
!!farmerbot.powermanager.configure
    wake_up_threshold:75
    periodic_wakeup:8:30AM
    periodic_wakeup_limit:2
```

### Example of a configuration file
```
My nodes
!!farmerbot.nodemanager.define
    id:20
    twinid:105
    public_config:true
    dedicated:1
    certified:yes
    cpuoverprovision:1

!!farmerbot.nodemanager.define
    id:21
    twinid:106

!!farmerbot.nodemanager.define
    id:22
    twinid:107

Farm configuration
!!farmerbot.farmmanager.define
    id:3
    public_ips:2

Power configuration
!!farmerbot.powermanager.configure
    wake_up_threshold:75
    periodic_wakeup:8:30AM
```

## Running the farmerbot for development
Make sure you have all the dependencies installed before running the commands below. You also have to configure some things in markup definition files:
- the nodes have to be configured (see example_data/1_data/nodes.md)

Now run the dependencies. Make sure to use the mnemonic of your farm as it is needed for some calls to the chain.
> rmb-peer --mnemonics "$(cat mnemonic.txt)" --relay wss://relay.dev.grid.tf:443 --substrate wss://tfchain.dev.grid.tf:443
> See [this page](https://github.com/threefoldtech/grid3_client_ts/blob/development/docs/http_server.md) on how to run the grid3 client ts

Now you can run the following command:
> v run start.v -c dir_with_configuration

## Running tests
Make sure to go through the documentation under [tests](tests/README.md).

