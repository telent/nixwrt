# Status May 2019: builds, but missing some needed packages

{ targetBoard ? "ar750"
, ssid
, psk
, loghost ? "loghost"
, myKeys ? "ssh-rsa AAAAATESTFOOBAR dan@example.org"
, sshHostKey ? "----NOT A REAL RSA PRIVATE KEY---" }:
let nixwrt = (import <nixwrt>) { inherit targetBoard; }; in
with nixwrt.nixpkgs;
let
    baseConfiguration = {
      hostname = "defalutroute";
      webadmin = { allow = ["localhost" "192.168.8.0/24"]; };
      interfaces = {
        "eth0.2" = {
          type = "vlan"; id = 2; parent = "eth0"; depends = []; # wan
        };
        "eth0.1" = {
          type = "vlan"; id = 1; parent = "eth0"; depends = []; # lan
        };
        "eth0" = { } ;
        "wlan0" = { };
        "br0" = {
          type = "bridge";
          ipv4Address = "192.168.1.4/24";
          members  = [ "eth0.1" "wlan0" ];
        };
        lo = { ipv4Address = "127.0.0.1/8"; };
      };
      etc = { };
      users = [
        {name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
         shell="/bin/sh"; authorizedKeys = (stdenv.lib.splitString "\n" myKeys);}
      ];
      packages = [ ];
      filesystems = {} ;
    };

    wantedModules = with nixwrt.modules;
      [(_ : _ : _ : baseConfiguration)
       nixwrt.device.hwModule
       (sshd { hostkey = sshHostKey ; })
       busybox
       kernelMtd
       (hostapd {
          config = { interface = "wlan0"; ssid = "telent1"; hw_mode = "g"; channel = 4; };
          # no support for creating PSK from passphrase in nixwrt, so use wpa_passphrase
          psk = "fishfinger" ;
        })
       (switchconfig {
         name = "switch0";
         interface = "eth0";
         vlans = {
	   "1" = "1 2 3 4 6t";           # lan (id 1 -> ports 1-4)
	   "2" = "0 6t";                 # wan (id 2 -> port 0)
	 };
        })
#       (pppoe { options = { debug = ""; }; auth = "* * mysecret\n"; })
       (phram { offset = "0xa00000"; sizeMB = "5"; })
       (syslog { inherit loghost; })
       (ntpd { host = "pool.ntp.org"; })
#       (dhcpClient { interface = "eth0.2"; })
    ];

    in {
      firmware = nixwrt.firmware (nixwrt.mergeModules wantedModules);

      # phramware generates an image which boots from the "fake" phram mtd
      # device - required if you want to boot from u-boot without
      # writing the image to flash first
      phramware = let m = wantedModules ++ [nixwrt.modules.forcePhram];
        in nixwrt.firmware (nixwrt.mergeModules m);
    }
