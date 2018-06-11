# ip link add link eth0 name eth0.1 type vlan id 1
# ip link add link eth0 name eth0.2 type vlan id 2
# ip addr add 192.168.0.251/24 dev eth0.2
# ip link set dev eth0 up

{lib, ip, writeScriptBin}:
let defaults = { up= true; routes = []; type = "hw"; depends = [];};
    setAddress = name : attrs:
      (lib.optionalString (attrs ? ipv4Address)
        "${ip} addr add ${attrs.ipv4Address} dev ${name}");
    setUp = name : {up,...}:
      "${ip} link set dev ${name} ${if up then "up" else "down"}";
    commands = {
      # the intention is that we should be able to extend this with
      # more types of interface as we need them: tunnels,
      # wireless stations, ppp links etc
      vlan = name : attrs@{dev, type, id,  ...} :
        ["${ip} link add link ${dev} name ${name} type ${type} id ${toString id}"
         (setAddress name attrs)
         (setUp name attrs)];
      bridge = name : attrs@{type, members, ...} : lib.flatten
        ["${ip} link add name ${name} type ${type}"
         (setAddress name attrs)
         (setUp name attrs)
         (map (intf : "${ip} link set ${intf} master ${name}") members)];
      hw = name : attrs :
        [(setAddress name attrs)
         (setUp name attrs)];
    };
    stanza = name: a@{ routes , type, depends , ... } :
      let c = ["#!/bin/sh"] ++ (commands.${type} name a) ++ ["# FIN\n"];
          depends' = lib.unique (depends ++ (lib.optionals (a ? members) a.members));
          start = writeScriptBin "ifup-${name}" (lib.strings.concatStringsSep "\n" c); in
      ''
         check network ${name} interface ${name}
           start program = "${start}/bin/ifup-${name}"
           stop program = "${ip} link set dev ${name} down"
           if failed link then restart
           depends on ${lib.strings.concatStringsSep ", " (depends' ++ ["booted"])}
      '';
  in name : attrs : stanza name (defaults // attrs)
