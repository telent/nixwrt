# Status Oct 2020: builds, boots, Works On My Network

{ nixwrt, device, config} :
let lib = nixwrt.nixpkgs.lib;
    secrets = {
      rsyncPassword = nixwrt.secret "ARHCIVE_RSYNC_PASSWORD";
      psk = nixwrt.secret "PSK";
      ssid = nixwrt.secret "SSID";
      loghost = nixwrt.secret "LOGHOST";
      myKeys = nixwrt.secret "SSH_AUTHORIZED_KEYS";
      sshHostKey = nixwrt.secret "SSH_HOST_KEY";
    };
    baseConfiguration = lib.recursiveUpdate
      config {
        hostname = "arhcive";
        webadmin = { allow = ["localhost" "192.168.8.0/24"]; };
        interfaces = {
          # this is set up for a GL.inet router, you'd have to edit it for another
          # target that has its LAN port somewhere else
          "eth0.2" = {
            type = "vlan"; id = 2; parent = "eth0"; depends = [];
          };
          "eth0" = { } ;
          lo = { ipv4Address = "127.0.0.1/8"; };
        };
        users = [
          {name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
           shell="/bin/sh"; authorizedKeys = (lib.splitString "\n" secrets.myKeys);}
          {name="store"; uid=500; gid=500; gecos="Storage owner"; dir="/srv";
           shell="/dev/null"; authorizedKeys = [];}
        ];
        busybox = {
          # because I have empirically determined that
	        # being able to see which copy of a file is more recent
	        # is an essential feature of a storage server
          config.feature_ls_timestamps = "y";
          config.feature_ls_sortfiles = "y";
        };
      };


in (with nixwrt.modules;
  [(_ : _ : _ : baseConfiguration)
   (import <nixwrt/modules/lib.nix> {})
   (device.module {})
   (rsyncd { password = secrets.rsyncPassword; })
   (sshd { hostkey = secrets.sshHostKey ; })
   busybox
   (usbdisk {
     label = "backup-disk";
     mountpoint = "/srv";
     fstype = "ext4";
     options = "rw";
   })
   kernelMtd
   haveged
   (switchconfig {
     name = "switch0";
     interface = "eth0";
     vlans = {"2" = "1 2 3 6t";  "3" = "0 6t"; };
   })
   (syslog { inherit (secrets) loghost ; })
   (ntpd { host = "pool.ntp.org"; })
   (dhcpClient {
     resolvConfFile = "/run/resolv.conf";
     interface = "eth0.2";
   })
  ])
