{ psk ? "fishfinger"
, ssid
, loghost ? "loghost"
, myKeys ? "ssh-rsa AAAAATESTFOOBAR dan@example.org"
, sshHostKey ? "----NOT A REAL RSA PRIVATE KEY---" }:
let nixwrt = (import <nixwrt>) { endian = "little";  }; in
with nixwrt.nixpkgs;
let
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
          ssid = ssid;
          country_code = "UK";
          channel = 2;
          hw_mode = "g";
          wpa_psk = psk;
          memberOf = "br0";
        };
        "br0" = {
          type = "bridge";
          enableStp = true;
          timeout = 90;
        };
        lo = { ipv4Address = "127.0.0.1/8"; };
      };
      etc = {
        "monit.ping.rc" = { content = ''
          check host 1.1.1.1 with address 1.1.1.1
	    depends on udhcpc
            if failed ping then exec "/bin/touch /tmp/fog-in-channel"
'';
        };
      };
      users = [
        {name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
         shell="/bin/sh"; authorizedKeys = (stdenv.lib.splitString "\n" myKeys);}
      ];
      packages = [ pkgs.swconfig ];
      busybox = { applets = []; };
      filesystems = {} ;
    };

    wantedModules = with nixwrt.modules;
      [(_ : _ : _ : baseConfiguration)
       (import <nixwrt/modules/lib.nix> {})
       (import <nixwrt/devices/gl-mt300a.nix> {})
       (sshd { hostkey = sshHostKey ; })
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
       (dhcpClient { interface = "br0"; resolvConfFile = "/run/resolv.conf";  })
       (syslog { inherit loghost ; })
       (ntpd { host = "pool.ntp.org"; })
    ];

    in {
      firmware = nixwrt.firmware (nixwrt.mergeModules wantedModules);

      # phramware generates an image which boots from the "fake" phram mtd
      # device - required if you want to boot from u-boot without
      # writing the image to flash first
      phramware =
        let phram_ = (nixwrt.modules.phram {
              offset = "0xa00000"; sizeMB = "6";
            });
            m = wantedModules ++ [phram_];
        in nixwrt.firmware (nixwrt.mergeModules m);
    }
