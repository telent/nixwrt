{ lib
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
   # some "services" are one-off scripts that run to completion and
   # don't want to be restarted.  we implement these in monit as 'check file'
   oneshots =
     lib.attrsets.filterAttrs (k : v: (v.type or "watch") == "oneshot") services;
   watchables =
     lib.attrsets.filterAttrs (k : v: (v.type or "watch") != "oneshot") services;
   stanzaForOneshot = (name: spec : let spec_ = {
     file = "/run/${name}.stamp";
     uid = 0;
     gid = 0;
     depends = [];
   } // spec;
     dep = d: if d == [] then ""  else "depends on " + (lib.strings.concatStringsSep ", " d);
   touchFile = "/bin/touch ${spec_.file}";
   in ''
    check file ${name} with path ${spec_.file}
      if not exist then exec "${lib.strings.escape ["\""] spec_.start}"
        as uid ${toString spec_.uid} gid ${toString spec_.gid}
      if not exist then exec "${lib.strings.escape ["\""] touchFile}"
        as uid ${toString spec_.uid} gid ${toString spec_.gid}
      ${dep spec_.depends}
    '');
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
    catLines = lib.strings.concatStringsSep "\n" ;
in writeText "monitrc" ''
  set init
  set daemon 30
  set httpd port 80
    allow localhost
    allow 192.168.0.0/24
  set idfile /run/monit.id
  set pidfile /run/monit.pid
  set statefile /run/monit.state
  check directory booted path /

  ${catLines (lib.attrsets.mapAttrsToList stanzaForInterface interfaces)}
  ${catLines (lib.attrsets.mapAttrsToList stanzaForService watchables)}
  ${catLines (lib.attrsets.mapAttrsToList stanzaForOneshot oneshots)}
  ${catLines (lib.attrsets.mapAttrsToList stanzaForFs filesystems)}
  ''
