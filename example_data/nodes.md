
# example how to initialize an environment for farmer


example node definition, description is optional

!!farmerbot.nodemanager.define
    description:'this is a description'
    id:3 
    twinid:2
    hru:1024GB
    sru:524288MB
    cru:8
    mru:17179869184
    cpuoverprovision:2

!!farmerbot.nodemanager.define
    id:5
    twinid:50
    hru:2048GB
    sru:1024GB
    cru:16
    mru:33554432KB

!!farmerbot.nodemanager.define
    id:8
    twinid:54
    public_config:true
    hru:2048GB
    sru:1024GB
    cru:16
    mru:32GB
    certified:no

!!farmerbot.nodemanager.define
    id:20
    twinid:105
    public_config:true
    dedicated:1
    certified:yes
    hru:2048GB
    sru:1024GB
    cru:16
    mru:32GB

!!farmerbot.nodemanager.define
    id:25
    twinid:112
    certified:yes
    hru:2048GB
    sru:1024GB
    cru:16
    mru:32GB
    never_shutdown:1

!!farmerbot.powermanager.configure
    wake_up_threshold:80
    periodic_wakeup:8:30AM


!!farmerbot.farmmanager.define
    id:3
    public_ips:2