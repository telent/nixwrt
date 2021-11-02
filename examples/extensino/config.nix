{ nixwrt, device }:
let
  lib = nixwrt.nixpkgs.lib;
  secrets = {
    psk = nixwrt.secret "PSK";
    ssid = nixwrt.secret "SSID";
    loghost = nixwrt.secret "LOGHOST";
    myKeys = nixwrt.secret "SSH_AUTHORIZED_KEYS";
    sshHostKey = nixwrt.secret "SSH_HOST_KEY";
  };
  pkgs = nixwrt.nixpkgs;
  baseConfiguration = {
    hostname = "extensino";
    webadmin = { allow = ["localhost" "192.168.8.0/24"]; };
    interfaces = {
      "eth0" = {
      	depends = [];
      };
      "eth0.1" = {
        type = "vlan"; id = 1; parent = "eth0"; depends = [];
        memberOf = "br0";
      };
      "wlan0" = {
        type = "hostap";
        params = {
          ssid = secrets.ssid;
          country_code = "UK";
          channel = 1;
          hw_mode = "g";
          ieee80211n = 1;
          wmm_enabled = 1;
          wpa = 2;
          wpa_key_mgmt = "WPA-PSK";
          wpa_psk = secrets.psk;
          wpa_pairwise = "CCMP";

          # to get 40MHz channels, we would need to set something
          # like
          #  ht_capab = "[HT40-][HT40+][LDPC][SHORT-GI-20][SHORT-GI-40][TX-STBC][RX-STBC1][DSSS_CCK-40]";
          # or
          # ht_capab = "[SHORT-GI-40][HT40+][HT40-][DSSS_CCK-40]";
          # but (maybe some regulatory misconfiguration) my hardware
          # doesn't like that and refuses to start hostapd
        };
        memberOf = "br0";
      };
      "br0" = {
        type = "bridge";
        enableStp = true;
        timeout = 90;
      };
      lo = { ipv4Address = "127.0.0.1/8"; };
    };
    packages = [ pkgs.iproute ];
  };

in (with nixwrt.modules;
  [(_ : _ : super : lib.recursiveUpdate super baseConfiguration)
   (import <nixwrt/modules/lib.nix> {})
   (sshd {
     hostkey = secrets.sshHostKey;
     authkeys = { root = lib.splitString "\n" secrets.myKeys; };
   })
   (_ : _ : super : { packages = super.packages ++ [ pkgs.iperf3 ] ; })
   busybox
   kernelMtd
   haveged
   (switchconfig {
     name = "switch0";
     interface = "eth0";
     vlans = {
       "1" = "0 1 6t";           # all the ports
     };
   })
   (dhcpClient { interface = "br0"; resolvConfFile = "/run/resolv.conf"; })
   (syslog { inherit (secrets) loghost ; })
   (ntpd { host = "pool.ntp.org"; })
  ])
