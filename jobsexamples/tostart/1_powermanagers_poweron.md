
# example how to initialize an environment for farmer


example node definition, description is optional

!!farmer.powermanager.poweron
    name:'wol'
    devicetype:'wol'
    description:'is the default wake on lan implementation'

!!farmer.powermanager.model.powermanager
    name:'pwr1'
    devicetype:'racktivity'
    description:'is power manager as racktivity'
    nrports:16
    ipaddr:'192.168.10.33'
    secret:'asecret'
    color:'red'
