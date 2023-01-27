# init nodes



!!node.find
    cru_min:1
    mru_min:1
    hru_min:1
    sru_min:1   
    node_exclude:3,4
    

!!node.find
    mru_min:20
    dedicated:'yes'
    publicip:1
    certified:1
