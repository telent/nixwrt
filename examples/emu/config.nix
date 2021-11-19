{ nixwrt, device}:
let
  lib = nixwrt.nixpkgs.lib;
  services = nixwrt.services;
  secrets = {
    myKeys = nixwrt.secret "SSH_AUTHORIZED_KEYS";
    sshHostKey = nixwrt.secret "SSH_HOST_KEY";
    l2tp = {
      lac = nixwrt.secret "L2TP_LAC";
      peer = nixwrt.secret "L2TP_PEER";
      username = nixwrt.secret "L2TP_USERNAME";
      password = nixwrt.secret "L2TP_PASSWORD";
    };
  };
  baseConfiguration = {
    hostname = "emu";
    webadmin = { allow = ["localhost" "192.168.8.0/24"]; };
    interfaces = { };
    packages = [ nixwrt.nixpkgs.iproute ];
    busybox = { applets = [ "poweroff" "halt" "reboot" ]; };
  };

in (with nixwrt.modules;
  [(_ : _ : super : lib.recursiveUpdate super baseConfiguration)
   (sshd {
     hostkey = secrets.sshHostKey;
     authkeys = { root = (lib.splitString "\n" secrets.myKeys); };
   })
   busybox
   kernelMtd
   (_: self: super:
     let lo = services.netdevice {ifname = "lo"; };
         eth0 =
           let link = services.netdevice {ifname = "eth0"; };
           in services.dhcpc { interface = link ; hostname = "emu"; };

         wan0 =
           let l2tp = services.l2tp {
                 link = eth0;
                 ifname = "wan0";
                 inherit (secrets.l2tp) peer username password;
               };
           in services.dhcp6c {
             link = l2tp;
             ifname = "wan0";
             hostname = "emu";
           };

         eth1 = services.netdevice {
           ifname = "eth1";
           # XXX need to configure with the prefix from dhcp6c-wan0
           addresses = ["192.168.19.1/24"];
         };
     in
       lib.recursiveUpdate super {
         svcs = { inherit lo eth0 eth1 wan0; };
       }
   )
  ])
