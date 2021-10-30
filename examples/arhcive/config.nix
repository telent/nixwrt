# Status Oct 2020: builds, boots, Works On My Network

{ rsyncPassword
, myKeys
, loghost
, sshHostKey
, lib
, nixwrt
, ...
}:
let
    baseConfiguration = {
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
         shell="/bin/sh"; authorizedKeys = (lib.splitString "\n" myKeys);}
        {name="store"; uid=500; gid=500; gecos="Storage owner"; dir="/srv";
         shell="/dev/null"; authorizedKeys = [];}
      ];
      packages = [ ];
      filesystems = {} ;
      busybox = {
        applets = [];
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
   (import <nixwrt/devices/gl-mt300n-v2.nix> {})
   (rsyncd { password = rsyncPassword; })
   (sshd { hostkey = sshHostKey ; })
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
   (syslog { inherit loghost ; })
   (ntpd { host = "pool.ntp.org"; })
   (dhcpClient {
     resolvConfFile = "/run/resolv.conf";
     interface = "eth0.2";
   })
  ])
