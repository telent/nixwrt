{ iproute, svc, lib }:
{ ifname
, addresses ? []
, depends ? []
} : let addressCommands =
          lib.concatStringsSep
          "\n"
            (builtins.map
              (a: "${iproute}/bin/ip address add ${a} dev ${ifname}")
            addresses);
in svc {
  name = "${ifname}";
  outputs = ["ready"];
  config = { packages = [ iproute ]; };
  start = ''
    ${iproute}/bin/ip link set up dev ${ifname}
    ${addressCommands}
    setstate ready true
  '';
  stop = "${iproute}/bin/ip link set down dev ${ifname}";
  inherit depends;
}
