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
         forwarding = nixpkgs.pkgs.svc {
           depends = [ eth1.ready wan0.prefixes l2tp.peer-v6-address ];
           outputs = [ "ready"];
           name = "forwarding";
           config = {
             kernel.config = {
               "BRIDGE_NETFILTER" = "y";
               "NETFILTER" = "y";
               "NETFILTER_ADVANCED" = "y";
               "NETFILTER_INGRESS" = "y";
               "NETFILTER_NETLINK" = "y";
               "NETFILTER_NETLINK_LOG" = "y";
               "NFT_CHAIN_NAT_IPV4" = "y";
               "NFT_CHAIN_NAT_IPV6" = "y";
               "NFT_CHAIN_ROUTE_IPV4" = "y";
               "NFT_CHAIN_ROUTE_IPV6" = "y";
               "NFT_CT" = "y";
               "NFT_MASQ" = "y";
               "NFT_NAT" = "y";
               "NFT_REJECT_IPV4" = "y";
               "NF_CONNTRACK" = "y";
               "NF_CONNTRACK_AMANDA" = "y";
               "NF_CONNTRACK_FTP" = "y";
               "NF_CONNTRACK_H323" = "y";
               "NF_CONNTRACK_IRC" = "y";
               "NF_CONNTRACK_LABELS" = "y";
               "NF_CONNTRACK_NETBIOS_NS" = "y";
               "NF_CONNTRACK_PPTP" = "y";
               "NF_CONNTRACK_SNMP" = "y";
               "NF_CT_PROTO_DCCP" = "y";
               "NF_CT_PROTO_GRE" = "y";
               "NF_CT_PROTO_SCTP" = "y";
               "NF_CT_PROTO_UDPLITE" = "y";
               "NF_TABLES" = "y";
               "NF_TABLES_BRIDGE" = "y";
               "NF_TABLES_IPV4" = "y";
               "NF_TABLES_IPV6" = "y";
             };
           };
           start = ''
             # XXX most likely we should be using only the first
             # of the prefixes advertised, any others are probably
             # for a VPN or some other use
             for prefix in $(cat ${wan0.prefixes}) ; do
               prefix=''${prefix%%,*}
               network=''${prefix%%/*}
               bits=''${prefix#*/}
               peeraddr=''$(cat ${l2tp.peer-v6-address})
               ${nixpkgs.pkgs.iproute}/bin/ip address add ''${network}1/$bits dev eth1
             done
             echo "1" > /proc/sys/net/ipv6/conf/all/forwarding
             echo "1" > /proc/sys/net/ipv4/ip_forward
             nft(){ ${nixpkgs.pkgs.nftables}/bin/nft $* ;}
             nft 'add table nat'
             nft 'add chain nat postrouting { type nat hook postrouting priority 100 ; }'
             nft 'add rule nat postrouting oif wan0 masquerade'
             ip route add default dev wan0
             ip -6 route add default via $peeraddr dev wan0
             setstate ready true
           '';
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
