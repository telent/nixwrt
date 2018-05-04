{ lib
 , pkgs
 , iproute
 , writeText
 , writeScriptBin
 , interfaces ? {}, services ? {}, filesystems ? {} } :
let ip = "${iproute}/bin/ip";
   stanzaForInterface =
      import ./monit-for-interface.nix { inherit lib writeScriptBin ip; };
   stanzaForFs = mountpoint: spec : ''
     check filesystem vol_${spec.label} path ${mountpoint}
       start program = "/bin/mount -t ${spec.fstype} LABEL=${spec.label} ${mountpoint}";
       stop program = "/bin/umount ${mountpoint}";
   '';
   stanzaForService = (name: spec : let spec_ = {
     pidfile = "/run/${name}.pid";
     uid = 0;
     gid = 0;
     depends = [];
     stop = "/bin/kill \\\$MONIT_PROCESS_PID";
   } // spec;
     dep = d: if d == [] then ""  else "depends on " + (lib.strings.concatStringsSep ", " d);
    in ''
    check process ${name} with pidfile ${spec_.pidfile}
      start program = "${lib.strings.escape ["\""] spec_.start}"
        as uid ${toString spec_.uid} gid ${toString spec_.gid}
      stop program = "${lib.strings.escape ["\""] spec_.stop}"
      ${dep spec_.depends}
    '');
in writeText "monitrc" ''
  set init
  set daemon 30
  set httpd port 80
    allow localhost
    allow 127.0.0.1/32
    allow 192.168.0.0/24
  set idfile /run/monit.id
  set statefile /run/monit.state
  check directory booted path /

  ${lib.strings.concatStringsSep "\n" (lib.attrsets.mapAttrsToList stanzaForInterface interfaces)}
  ${lib.strings.concatStringsSep "\n" (lib.attrsets.mapAttrsToList stanzaForService services)}
  ${lib.strings.concatStringsSep "\n" (lib.attrsets.mapAttrsToList stanzaForFs filesystems)}
  ''
