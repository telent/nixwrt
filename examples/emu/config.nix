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
   (nixpkgs: self: super:
     let lo = services.netdevice {ifname = "lo"; };
         eth0 =
           let link = services.netdevice {ifname = "eth0"; };
           in services.dhcpc { interface = link ; hostname = "emu"; };

         l2tp = services.l2tp {
           link = eth0;
                 ifname = "wan0";
                 inherit (secrets.l2tp) peer username password;
         };
         wan0 = services.dhcp6c {
           link = l2tp;
           ifname = "wan0";
           hostname = "emu";
         };

         eth1 = services.netdevice {
           ifname = "eth1";
           addresses = ["192.168.19.1/24" ];
         };

         nswatcher = nixpkgs.pkgs.svc {
           name = "nswatcher";
           depends = [ wan0.nameservers ];
           outputs = ["ready"];
           start = ''
             echo "nameserver $(cat ${wan0.nameservers})" > /run/resolv.conf
             setstate ready true
           '';
         };

         dnsmasq = services.dnsmasq {
           name = "dnsmasq-eth1";
           lan = eth1;
           resolvFile = "/run/resolv.conf";
           domain = "example.com";
           ranges = [
             "192.168.19.5,192.168.19.240"
             "::4,::ffff,constructor:eth1,slaac"
           ];
         };
         forwarding = services.forwarding {
           ipv6-peer-address = l2tp.peer-v6-address;
           wan = wan0;
           wanifname = "wan0";
           lan = eth1;
         };
     in
       lib.recursiveUpdate super {
         svcs = {
           inherit
             dnsmasq
             eth0
             eth1
             forwarding
             lo
             nswatcher
             wan0
           ; };
       }
   )
  ])
