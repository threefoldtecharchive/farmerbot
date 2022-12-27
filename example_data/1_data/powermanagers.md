
# example how to initialize an environment for farmer


example node definition, description is optional

!!powermanager.define
    name:'wol'
    devicetype:'wol'
    description:'is the default wake on lan implementation'

!!powermanager.define
    name:'pwr1'
    devicetype:'racktivity'
    description:'is power manager as racktivity'
    nrports:16
    ipaddr:'192.168.10.33'
    secret:'asecret'
    color:'red'
