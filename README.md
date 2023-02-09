# Farmerbot
Welcome to the farmerbot. The farmerbot is a service that a farmer can run allowing him to automatically manage the nodes of his farm. 

The key feature of the farmerbot is powermanagement. The farmerbot will automatically shutdown nodes from its farm whenever possible and bring them back on when they are needed using Wake-on-Lan (WOL). It will try to maximize downtime as much as possible by recommending which nodes to use, this is one of the requests that the farmerbot can handle (asking for a node to deploy on).

The behavior of the farmerbot is customizable through markup definition files. You can find an example [here](example_data/1_data/nodes.md). 

## Under the hood
The farmerbot has been implemented using the actor model principles. It contains two actors that are able to execute jobs (actions that need to be executed by a specific actor).

The first actor is the nodemanager which is in charge of executing jobs related to nodes (e.g. finding a suitable node). The second actor is the powermanager which allows us to power on and off nodes in the farm.

Actors can schedule the execution of jobs for other actors which might or might not be running on the same system. For example, the nodemanager might schedule the execution of a job to power on a node (which is meant for the powermanager). The repository [baobab](https://github.com/freeflowuniverse/baobab) contains the logic for scheduling jobs.

Jobs don't have to originate from the system running the farmerbot. It may as well be scheduled from another system (with another twin id). The job to find a suitable node for example will come from the TSClient (which is located on another system). These jobs will be send from the TSClient to the farmerbot via [RMB](https://github.com/threefoldtech/rmb-rs).

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

## Running the farmerbot
Make sure you have all the dependencies installed before running the command below. You also have to configure some things in markup definition files:

- the nodes have to be configured (see example_data/1_data/nodes.md)

Now you can run the following command:
> v run start.v

## Running tests
Make sure to go through the documentation under [tests](tests/README.md). 

