{svc, iproute} : {
  netdevice = { ifname } : svc {
    name = "${ifname}";
    outputs = ["ready"];
    config = { packages = [ iproute ]; };
    start = "${iproute}/bin/ip link set up dev ${ifname}; setstate ready true";
    stop = "${iproute}/bin/ip link set down dev ${ifname}";
  };
}
