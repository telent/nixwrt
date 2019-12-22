{lib, ip, hostapd, writeText, writeScriptBin}:
let defaults = { up= true; routes = []; type = "hw"; depends = []; timeout = 30;};
    setAddress = name : attrs:
      (lib.optionalString (attrs ? ipv4Address)
        "${ip} addr add ${attrs.ipv4Address} dev ${name}");
    addToMaster = name : attrs@{memberOf ? null, ...} :
      lib.optionalString (memberOf != null)
        "${ip} link set ${name} master ${memberOf}";
    setUp = name : {up, ...}:
      "${ip} link set dev ${name} ${if up then "up" else "down"}";
    commands = {
      # the intention is that we should be able to extend this with
      # more types of interface as we need them: tunnels,
      # wireless stations, ppp links etc
      vlan = name : attrs@{parent, type, id,  ...} :
        ["${ip} link add link ${parent} name ${name} type ${type} id ${toString id}"
         (setAddress name attrs)
         (addToMaster name attrs)
         (setUp name attrs)];
      bridge = name : attrs@{type, enableStp ? false, ...} : lib.flatten
        ["${ip} link add name ${name} type ${type}"
         (setAddress name attrs)
         "echo \"${if enableStp then ''1'' else ''0'' }\" > /sys/class/net/${name}/bridge/stp_state"
         (setUp name attrs)
         ];
      hostap = name : attrs :
        let attrs' = { logger_stdout = -1; logger_stdout_level = 99; } // attrs;
            cfg = { inherit (attrs') channel country_code hw_mode logger_stdout logger_stdout_level ssid wpa_psk; };
            conf = writeText "hostap-${name}.conf" (import ./hostapd-conf.nix lib cfg);
            debug = (if attrs ? debug then "-d" else "" );
        in lib.flatten
          ["${hostapd}/bin/hostapd ${debug} -B -P /run/hostapd.pid -i ${name} -S ${conf}"
           (addToMaster name attrs)
          ];
      hw = name : attrs :
        [(setAddress name attrs)
         (addToMaster name attrs)
         (setUp name attrs)];
    };
    stanza = name: a@{ routes, type, depends, timeout, ... } :
      let c = ["#!/bin/sh"] ++ (commands.${type} name a) ++ ["# FIN\n"];
          depends' = lib.unique (depends ++ (lib.optionals (a ? members) a.members)
                                         ++ (lib.optional (a ? parent) a.parent));
          start = writeScriptBin "ifup-${name}" (lib.strings.concatStringsSep "\n" c); in
      ''
         check network ${name} interface ${name}
         start program = "${start}/bin/ifup-${name}" with timeout ${toString timeout} seconds
           stop program = "${ip} link set dev ${name} down"
           if failed link then restart
           depends on ${lib.strings.concatStringsSep ", " (depends' ++ ["booted"])}
      '';
  in name : attrs : stanza name (defaults // attrs)
