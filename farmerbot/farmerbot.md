# Farmerbot developer guide


## Actors

The farmerbot has been implemented using the actor model principles. It contains three actors that are able to execute jobs (functions that need to be executed by a specific actor). The first actor is the farmmanager and is in charge of answering get_version jobs. The name says what the job does: it returns the current version of the farmerbot which might be useful if you want to know if there is a farmerbot running for a specific farm. The second actor is the nodemanager which is in charge of executing jobs related to nodes (e.g. finding a suitable node). The last actor is the powermanager which allows us to power on and off nodes in the farm.

Actors can schedule the execution of jobs for other actors which might or might not be running on the same system. For example, the nodemanager might schedule the execution of a job to power on a node (which is meant for the powermanager). The repository [baobab](https://github.com/freeflowuniverse/baobab) contains the logic for scheduling jobs.

Jobs don't have to originate from the system running the farmerbot. It may as well be scheduled from another system (with another twin id). The job to find a suitable node for example will come from the TSClient (which is located on another system). These jobs will be send from the TSClient to the farmerbot via [RMB](https://github.com/threefoldtech/rmb-rs).

## Manager

For each actor we have a manager that handles the jobs it receives. You will find the code for it in the [manager folder](./manager/). You'll notice that we have more managers than actors. That is because to be an actor a manager has to have jobs. Managers on the other hand have a bit more capabilities:

- they are able to execute code every X minutes (5 in our case)
- they are able to execute actions at startup time
- they are able to execute jobs on behalf of others
- they are able to request the execution of a job for another manager

## Adding a new manager

Adding a new manager is very simple. Follow these steps:

1) add a new file in the [manager folder](./manager/)
2) implement the interface defined in [here](./manager/manager.v)
3) add your actions in that class and open them up through the init function
4) add your jobs in that class and open them up through the execute function
5) add the manager to the factory method _new_ from [factory.v](./factory/factory.v)
6) add the manager as an actor in the factory method if it contains one or more jobs
7) make sure to add new tests for that manager in [tests](../tests/)


### Update function

Each manager has an update function which is called every 5 minutes. The update function is called on each manager one after the other in the order that the managers were added to. It is not allowed to throw any errors, all errors should be handled and/or logged. 

### Jobs

Jobs are executed from the execute function of the manager that should execute the job. The jobs thus run on a separate thread as the update function.

### State

The state is kept in the db property that is part of each manager. As the update function of each manager is called in sequence there is no need to fear for race conditions. The jobs on the other hand could be executed at the same time so keep that in mind when implementing new code. Jobs are also called in sequence so there is no need to fear for race conditions between jobs either. It is important to keep it that way when calling jobs from jobs.

## Data manager

The data manager is in charge of updating the state of the nodes by talking to the nodes through RMB. Every time the update function is called it goes through the following steps:

1) It sends batch ping messages to all the configured nodes: this is a message to get the version of the zos nodes
2) It sends batch messages to all the nodes that do not have claimed resources (resources that are locked because of a find_node request):
    1) One message per node to get the statistics (cru, mru, etc)
    2) One message per node to get the storage pools
    3) One message per node to get the public config (if it has one)
3) It asks tfchain for whether or not there is a rent contract on the node (via the tfgrid http server that is running along side the farmerbot)
4) After that the farmerbot waits 2 minutes for answers from the ZOS nodes. It will modify the state (on, wakingup, off, shuttingdown) based on the following rules:
    1) If the state is on and it didn't get any answer from the ZOS node it will print an error message saying there is a node offline while expecting it to be online. The state will be put to off after this
    2) If the state is wakingup and the node answered our message(s) we put the state to on because this shows a succesful wakeup
    3) If the state is wakingup and we didn't get any answer we leave the state as is if the timeout (30 minutes) has not exceeded yet. If it did exceed we print an error message and put the state back to off as it indicates a failed wakeup
    4) If the state is shuttingdown and the node no longer answers our calls we put the state to off (indicating a successful shutdown)
    5) If the state is shuttingdown and the node is still answering our calls we keep the state as is unless the timeout exceeded (30 minutes). In that case we put the state back to on (indicating a failed attempt to shutdown the node) and log an error.
    6) If the state is off and we suddenly get an answer we put the state to on and log an error as we didn't expect the node to be on

## Farm manager

The farm manager contains one job which allows you to get the version of the farmerbot. It is a useful feature to be able to know if the farmerbot is running for a specific farm. You can just send the get_version job to the twin id of that farm. If an answer is send back you know the farmerbot is running for that farm. 


## Node manager

The node manager is in charge of adding nodes the state (through actions) at startup and handles the incoming jobs from the outside. There is only one job for now: find_node.

The job find_node will iterate over the nodes and find the best suitable nodes for your request. It will take into account the following:

- nodes that are up will have precedence over nodes that are down
- only the nodes that have enough resources left will be returned
- the requested resources will be reserved the next 30 minutes on the chosen node: this means the 30 minutes after that the farmerbot will not be updating the statistics of the node
- if the returned node is off it will be powered on (can happen in rare cases)

## Power manager

The power manager is in charge of the power management and of the power-related jobs (power on and power off). The power management consists of two things: periodic wakeup and usage management. 

The periodic wakeup will wake up the nodes once a day so that they can send their uptime to the chain. It starts at the time defined by the farmer in the configuration file. How many nodes are woken up at the same time is also defined by the parameter in the configuration file. This means that we cannot ensure that all nodes will be waken up at the periodic wakeup start but it should be some moment after it. The nodes that are woken up are kept up for 30 minutes to give time to the zos node to send the uptime report.

The usage management powers on nodes and shuts them down based on the resource usage. If the nodes that are not used enough it will powe down the nodes that can be powered down. If on the other hand the resource usage is exceeding the threshold defined in the configuration it will power on a new node (if there are nodes left to power on). 

Nodes are only allowed to be powered off if:
- it is not being used (no rent contracts, no resources being used)
- it is has no public config
- it is not marked as never_shutdown in the configuration file
- it was just powered on less then 30 minutes ago



