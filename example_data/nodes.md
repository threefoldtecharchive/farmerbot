
# example how to initialize an environment for farmer


example node definition, description is optional

!!farmerbot.nodemanager.define
    description:'this is a description'
    id:3 
    twinid:2
    farmid:3
    hru:1024GB
    sru:512GB
    cru:8
    mru:16GB
    cpuoverprovision:2

!!farmerbot.nodemanager.define
    id:5
    twinid:50
    farmid:3
    hru:2048GB
    sru:1024GB
    cru:16
    mru:32GB

!!farmerbot.nodemanager.define
    id:8
    twinid:54
    farmid:3
    publicip:true
    hru:2048GB
    sru:1024GB
    cru:16
    mru:32GB

!!farmerbot.nodemanager.define
    id:20
    twinid:105
    farmid:3
    publicip:true
    dedicated:1
    certified:yes
    hru:2048GB
    sru:1024GB
    cru:16
    mru:32GB

!!farmerbot.nodemanager.define
    id:25
    twinid:112
    farmid:3
    certified:yes
    hru:2048GB
    sru:1024GB
    cru:16
    mru:32GB