# Status Sep 2019: builds, boots, Works On My Network

{ rsyncPassword ? "urbancookie"
, myKeys ? "ssh-rsa AAAAATESTFOOBAR dan@example.org"
, loghost ? "loghost"
, sshHostKey ? "----FAKING RSA PRIVATE KEY----" }:
let nixwrt = (import <nixwrt>) { targetBoard = "mt300n_v2"; }; in
with nixwrt.nixpkgs;
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
         shell="/bin/sh"; authorizedKeys = (stdenv.lib.splitString "\n" myKeys);}
        {name="store"; uid=500; gid=500; gecos="Storage owner"; dir="/srv";
         shell="/dev/null"; authorizedKeys = [];}
      ];
      packages = [ ];
      filesystems = {} ;
      busybox = {
        # because I have empirically determined that
	# being able to see which copy of a file is more recent
	# is an essential feature of a storage server
        config.feature_ls_timestamps = "y";
        config.feature_ls_sortfiles = "y";
      };
    };

    wantedModules = with nixwrt.modules;
      [(_ : _ : _ : baseConfiguration)
       nixwrt.device.hwModule
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
    ];
    in {
      firmware = nixwrt.firmware (nixwrt.mergeModules wantedModules);

      # phramware generates an image which boots from the "fake" phram mtd
      # device - required if you want to boot from u-boot without
      # writing the image to flash first
      phramware =
        let phram_ = (nixwrt.modules.phram {
              offset = "0xa00000"; sizeMB = "5";
            });
            m = wantedModules ++ [phram_];
        in nixwrt.firmware (nixwrt.mergeModules m);

    }
