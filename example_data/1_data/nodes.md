
# example how to initialize an environment for farmer


example node definition, description is optional

!!farmerbot.nodemanager.model.node.set
    description:'this is a description'
    id:3 
    farmid:3
    powermanager:'pwr1'
    powermanager_port:2
    certified:yes

!!farmerbot.nodemanager.model.node.set
    id:5
    farmid:3
    powermanager:'wol'
    ethernetaddr:'aabbccddeeffgg'
