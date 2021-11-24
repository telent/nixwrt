# Some day this will be the config for my PPPoE router that connects
# to my ISP.  There's a little way to go yet to make that happen.

# status nov 2021: WIP
#   [x] builds
#   [x] boots
#   [x] wifi works
#   [x] wifi wide channel on 5GHz
#   [ ] wifi configured correctly inc. country code
#   [x] l2tp tunnel https://github.com/xelerance/xl2tpd/blob/cd86560b3eb9abc090d9fb717b6f4cedeaae5688/l2tp.h#L44
#   [x] odhcp6c: get ipv6 prefix address & network from upstream
#   [x] dnsmasq: enable-ra, delegate (some or all) of the address space to lan
#   [x] dnsmasq: dhcp for ipv4
#   [x] dnsmasq: dns and any other services
#   [ ] ipv6 firewall
#   [ ] ipv4 nat + firewall
#   [ ] ntp
#   [ ] pppoe


{nixwrt, device} :
let
  lib = nixwrt.nixpkgs.lib;
  services = nixwrt.services;
  secrets = {
    psk = nixwrt.secret "PSK";
    ssid = nixwrt.secret "SSID";
    loghost = nixwrt.secret "LOGHOST";
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
    hostname = "defalutroute";
    busybox  = { applets = ["stty"] ; };
    webadmin = { allow = ["localhost" "192.168.1.0/24"]; };
    ignoredInterfaces = {
      "eth0" = { } ;
      "eth0.1" = {
        type = "vlan"; id = 2; parent = "eth0"; depends = []; # lan
        memberOf = "br0";
      };
      "eth1" = { ipv4Address = "10.0.0.5/24"; };
      "wlan0" = {
        type = "hostap";
        memberOf = "br0";
        debug = true;
        params = rec   {
          inherit (secrets) ssid;
          ht_capab = "[HT40+]";
          vht_oper_chwidth = 1;
          vht_oper_centr_freq_seg0_idx = channel + 6;
          country_code = "US";
          channel = 36;
          ieee80211ac = 1;
          wmm_enabled = 1;
          hw_mode = "a";
        };
      };
      "wlan1" = {
        type = "hostap";
        memberOf = "br0";
        debug = true;
        params = {
          inherit (secrets) ssid;
          country_code = "US";
          channel = 9;
          wmm_enabled = 1;
          ieee80211n = 1;
          hw_mode = "g";
        };
      };
      "br0" = {
        type = "bridge";
        ipv4Address = "192.168.1.4/24";
      };
      lo = { ipv4Address = "127.0.0.1/8"; };
    };
    packages = [ nixwrt.nixpkgs.iproute ];
  };

in (with nixwrt.modules;
  [(_ : _ : super : lib.merge2Configs super baseConfiguration)
   (sshd {
     hostkey = secrets.sshHostKey;
     authkeys = { root = lib.splitString "\n" secrets.myKeys; };
   })
   busybox
   kernelMtd
   (_: _: super: { boot = super.boot // { phramSizeMB = "22"; }; })
   (nixpkgs: self: super:
     let lo = services.netdevice {ifname = "lo"; };
         wanLink =
           let link = services.netdevice {ifname = "eth1"; };
           in services.dhcpc { interface = link ; hostname = "emu"; };

         l2tp = services.l2tp {
           link = wanLink;
           ifname = "wan0";
           inherit (secrets.l2tp) peer username password;
         };
         wan0 = services.dhcp6c {
           link = l2tp;
           ifname = "wan0";
           hostname = "emu";
         };

         # XXX lan interface is a bridge whose members are
         # hw ethernet, wlan0, wlan1
         eth0 = services.netdevice {
           ifname = "eth0";
           addresses = ["192.168.19.1/24" ];
         };

         wlan1 = services.netdevice { ifname = "wlan1"; };

         hostap-wlan1 = services.hostapd {
           name = "hostap-wlan1";
           debug = true;
           wlan = wlan1;
           modloader = super.svcs.modloader;
           params = {
             inherit (secrets) ssid;
             country_code = "US";
             channel = 1;
             wmm_enabled = 1;
             ieee80211n = 1;
             hw_mode = "g";
           };
           psk = secrets.psk;
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
           lan = eth0;
           resolvFile = "/run/resolv.conf";
           domain = "example.com";
           ranges = [
             "192.168.1.5,192.168.1.240"
             "::4,::ffff,constructor:eth1,slaac"
           ];
         };
         forwarding = services.forwarding {
           ipv6-peer-address = l2tp.peer-v6-address;
           wan = wan0;
           wanifname = "wan0";
           lan = eth0;
         };
     in
       lib.recursiveUpdate super {
         svcs = {
           inherit
             dnsmasq
             eth0
             wanLink
             forwarding
             lo
             nswatcher
             wan0
             hostap-wlan1
             # XXX ntp
           ; };
       }
   )
   # (switchconfig {
   #   name = "switch0";
   #   interface = "eth1";
   #   vlans = {
	 #     "1" = "0t 1 2 3 4";           # lan (0 is cpu)
	 #   };
   # })

#   (syslog { inherit (secrets) loghost; })

  ])
