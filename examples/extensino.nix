{ psk
, ssid
, loghost
, myKeys
, sshHostKey }:
let nixwrt = (import <nixwrt>) { endian = "little";  }; in
with nixwrt.nixpkgs;
let
  baseConfiguration = lib.recursiveUpdate
    nixwrt.emptyConfig {
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
            ssid = ssid;
            country_code = "UK";
            channel = 1;
            hw_mode = "g";
            ieee80211n = 1;
            wmm_enabled = 1;
            wpa = 2;
            wpa_key_mgmt = "WPA-PSK";
            wpa_psk = psk;
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
      users = [
        {name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
         shell="/bin/sh"; authorizedKeys = (lib.splitString "\n" myKeys);}
      ];
      packages = [ pkgs.iproute ];
    };

    wantedModules = with nixwrt.modules;
      [(_ : _ : _ : baseConfiguration)
       (import <nixwrt/modules/lib.nix> {})
       (import <nixwrt/devices/gl-mt300a.nix> {})
       (sshd { hostkey = sshHostKey ; })
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
       (syslog { inherit loghost ; })
       (ntpd { host = "pool.ntp.org"; })
    ];

    in {
      firmware = nixwrt.firmware (nixwrt.mergeModules wantedModules);
      kernel = nixwrt.kernel (nixwrt.mergeModules wantedModules);
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
