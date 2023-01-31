
# example how to initialize an environment for farmer


example node definition, description is optional

!!farmerbot.nodemanager.define
    description:'this is a description'
    id:3 
    twinid:2
    farmid:3
    certified:yes
    hru:1024GB
    sru:512GB
    cru:8
    mru:16GB

!!farmerbot.nodemanager.define
    id:5
    twinid:50
    farmid:3
    ethernetaddr:'aabbccddeeffgg'
    hru:1024GB
    sru:512GB
    cru:8
    mru:16GB
