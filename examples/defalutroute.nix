# Some day this will be the config for my PPPoE router that connects
# to my ISP.  There's a little way to go yet to make that happen.
# Status Oct 2020: WIP
#   [x] builds
#   [x] boots
#   [x] wifi works
#   [x] wifi wide channel on 5GHz
#   [ ] wifi configured correctly inc. country code
#   [.] l2tp tunnel https://github.com/xelerance/xl2tpd/blob/cd86560b3eb9abc090d9fb717b6f4cedeaae5688/l2tp.h#L44
#   [ ] odhcp6c: get ipv6 prefix address & network from upstream
#   [ ] dnsmasq: enable-ra, delegate (some or all) of the address space to lan
#   [ ] dnsmasq: dhcp for ipv4
#   [ ] dnsmasq: dns and any other services
#   [ ] ipv6 firewall
#   [ ] ipv4 nat + firewall
#   [ ] ntp
#   [ ] pppoe

{
  loghost
, l2tpUsername
, l2tpPassword
, l2tpPeer
, myKeys
, psk
, sshHostKey
, ssid
}:
let nixwrt = (import <nixwrt>) { endian = "big"; };
in
with nixwrt.nixpkgs;
let
  odhcp6Update = ../nixwrt/dhcp6c-update.lua;
  baseConfiguration = lib.recursiveUpdate
    nixwrt.emptyConfig {
      hostname = "defalutroute";
      busybox  = { applets = ["stty"] ; };
      webadmin = { allow = ["localhost" "192.168.1.0/24"]; };
      interfaces = {
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
            inherit ssid;
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
            inherit ssid;
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
      users = [
        {name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
         shell="/bin/sh"; authorizedKeys = (lib.splitString "\n" myKeys);}
      ];
      packages = [ pkgs.iproute ];
    };

    wantedModules = with nixwrt.modules;
      [(_ : _ : _ : baseConfiguration)
       (import <nixwrt/modules/lib.nix> {})
       (import <nixwrt/devices/gl-ar750.nix> {})
       (sshd { hostkey = sshHostKey ; })
       busybox
       kernelMtd
       (switchconfig {
         name = "switch0";
         interface = "eth1";
         vlans = {
	         "1" = "0t 1 2 3 4";           # lan (0 is cpu)
	       };
       })
       (l2tp {
         username = l2tpUsername;
         password = l2tpPassword;
         endpoint = l2tpPeer;
         lac = "aaisp";
         ifname = "l2tp-aaisp";
       })
       (pkgs : _ : super : {
         services = super.services // {
           odhcp6c = {
             start =
               "${pkgs.odhcp6c}/bin/odhcp6c -d -P 64 -s ${odhcp6Update} -p /run/odhcp6c.pid -v -v l2tp-aaisp";
             depends = [ "l2tp-aaisp" ];
           };
         };
         packages = super.packages ++ [pkgs.odhcp6c pkgs.lua];
       })

#       haveged
#       (pppoe { options = { debug = ""; }; auth = "* * mysecret\n"; })
       (syslog { inherit loghost; })
#       (ntpd { host = "pool.ntp.org"; })
    ];

    in {
      firmware = nixwrt.firmware (nixwrt.mergeModules wantedModules);

      # phramware generates an image which boots from the "fake" phram mtd
      # device - required if you want to boot from u-boot without
      # writing the image to flash first
      phramware =
        let phram_ = (nixwrt.modules.phram {
              offset = "0xa00000"; sizeMB = "7";
            });
            m = wantedModules ++ [phram_];
        in nixwrt.firmware (nixwrt.mergeModules m);
    }
