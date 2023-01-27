
# example how to initialize an environment for farmer


example node definition, description is optional

!!farmerbot.node.define
    description:'this is a description'
    id:3 
    farmid:3
    certified:yes
    hru:1024GB
    sru:512GB
    cru:8
    mru:16GB

!!farmerbot.node.define
    id:5
    farmid:3
    ethernetaddr:'aabbccddeeffgg'
    hru:1024GB
    sru:512GB
    cru:8
    mru:16GB
