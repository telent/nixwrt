options@{lac, ifname, username, password, endpoint, ...}: nixpkgs: self: super:
with nixpkgs;
# FIXME this only works for a single tunnel/session, generalising this
# for multiple-anything is left for another time
let
  ppp_options = writeText "ppp.options" ''
    +ipv6
    debug
    ipv6cp-use-ipaddr
    ifname ${ifname}
    name ${username}
    password ${password}
    noauth
  '';
  configFile = writeText "xl2tpd.conf" ''
    [global]
    max retries = 1
    [lac ${lac}]
    autodial = no
    ppp debug = no
    redial = no
    lns = ${endpoint}
    require authentication = no
    pppoptfile = ${ppp_options}
  '';

  watcherFile = writeScript "${ifname}.lua" ''
    #!${swarm}/bin/lua-swarm
    package.path = "${swarm}/lib/?.lua;${swarm}/share/swarm/scripts/?.lua;;"
    xl2tpd = require("xl2tpd")
    xl2tpd({
      name = "${lac}",
      transit_iface = "eth0",
      lac = "${lac}",
      config = "${configFile}",
      secrets = "/etc/xl2tpd.secrets",
      iface = "${ifname}",
      paths = {
        xl2tpd = "${xl2tpd}/bin/xl2tpd"
      }
    })
  '';

  # only here temporarily
  eth0WatcherFile = writeScript "eth0.lua" ''
    #!${swarm}/bin/lua-swarm
    package.path = "${swarm}/lib/?.lua;${swarm}/share/swarm/scripts/?.lua;;"
    (require("ethernet"))({
      name = "eth0",
      iface = "eth0",
      paths = {
        ip = "${iproute}/bin/ip",
        xl2tpd = "${xl2tpd}/bin/xl2tpd"
      }
    })
  '';


  # only here temporarily
  odhcp6cWatcherFile =
    let odhcp6UpdateScript = writeScript "odhcp6c-update" ''
      #!/bin/sh
      mkdir -p /run/swarm/services/odhcp6c-script/
      exec /bin/cp /proc/self/environ /run/swarm/services/odhcp6c-script/environ
    '';
    in
      writeScript "odhcp6c.lua" ''
        #!${swarm}/bin/lua-swarm
        package.path = "${swarm}/lib/?.lua;${swarm}/share/swarm/scripts/?.lua;;"
        (require("odhcp6c"))({
          name = "odhcp6c",
          updatescript = "${odhcp6UpdateScript}",
          iface = "${ifname}",
          paths = {
            odhcp6c = "${odhcp6c}/bin/odhcp6c",
          }
        })
  '';
in lib.attrsets.recursiveUpdate super {
  packages = super.packages ++ [
    pkgs.ppp watcherFile eth0WatcherFile
    odhcp6cWatcherFile
  ];
  busybox = { applets = super.busybox.applets ++ ["echo"];}; # unneeded?

  kernel.config."L2TP" = "y";
  kernel.config."PPP" = "y";
  kernel.config."PPPOL2TP" = "y";
  kernel.config."PPP_ASYNC" = "y";
  kernel.config."PPP_BSDCOMP" = "y";
  kernel.config."PPP_DEFLATE" = "y";
  kernel.config."PPP_SYNC_TTY" = "y";

  etc."xl2tpd.secrets" = {
    mode = "0400";
    content = "# empty apart from this comment\n";
  };

  inittab."${lac}" = {
    action = "respawn";
    process = watcherFile;
  };

  # only here temporarily
  inittab.eth0 = {
    action = "respawn";
    process = eth0WatcherFile;
  };

  inittab.odhcp6c = {
    action = "respawn";
    process = odhcp6cWatcherFile;
  };

}
