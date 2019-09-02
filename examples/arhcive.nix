# Status May 2019: builds, may not boot, has not been tested recently

{ rsyncPassword ? "urbancookie"
, myKeys ? "ssh-rsa AAAAATESTFOOBAR dan@example.org"
, loghost ? "loghost"
, sshHostKey ? "----FAKING RSA PRIVATE KEY----" }:
let nixwrt = (import <nixwrt>) { targetBoard = "mt300nv2"; }; in
with nixwrt.nixpkgs;
let
    baseConfiguration = {
      hostname = "arhcive";
      interfaces = {
        # this is set up for a GL.inet router, you'd have to edit it for another
        # target that has its LAN port somewhere else
        "eth0.2" = {
          type = "vlan"; id = 2; parent = "eth0"; depends = [];
        };
        "eth0" = { } ;
        lo = { ipv4Address = "127.0.0.1/8"; };
      };
      etc = {
#        "resolv.conf" = { content = ( stdenv.lib.readFile "/etc/resolv.conf" );};
      };
      users = [
        {name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
         shell="/bin/sh"; authorizedKeys = (stdenv.lib.splitString "\n" myKeys);}
        {name="store"; uid=500; gid=500; gecos="Storage owner"; dir="/srv";
         shell="/dev/null"; authorizedKeys = [];}
      ];
      packages = [ pkgs.iproute ];
      filesystems = {} ;
    };

    wantedModules = with nixwrt.modules;
      [(_ : _ : _ : baseConfiguration)
       nixwrt.device.hwModule
       (kexec {})
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
       (switchconfig {
         name = "switch0";
         interface = "eth0";
         vlans = {"2" = "1 2 3 6t";  "3" = "0 6t"; };
        })
       (phram { offset = "0xa00000"; sizeMB = "5"; })
       (syslogd { inherit loghost ; })
       (ntpd { host = "pool.ntp.org"; })
       (dhcpClient { interface = "eth0.2"; })
    ];
    in {
      firmware = nixwrt.firmware (nixwrt.mergeModules wantedModules);

      # phramware generates an image which boots from the "fake" phram mtd
      # device - required if you want to boot from u-boot without
      # writing the image to flash first
      phramware = let m = wantedModules ++ [nixwrt.modules.forcePhram];
        in nixwrt.firmware (nixwrt.mergeModules m);

    }
