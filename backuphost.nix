{ targetBoard }:
let nixwrt = (import ./nixwrt/default.nix) { inherit targetBoard; }; in
with nixwrt.nixpkgs;
let
    myKeys = stdenv.lib.splitString "\n"
              (builtins.readFile ("/etc/ssh/authorized_keys.d/" + builtins.getEnv( "USER"))) ;
    rsyncPassword = (let p = builtins.getEnv( "RSYNC_PASSWORD"); in assert (p != ""); p);
    baseConfiguration = {
      hostname = "arhcive";
      interfaces = {
        # this is set up for a GL.inet router, you'd have to edit it for another
        # target that has its LAN port somewhere else
        "eth0.2" = {
          type = "vlan"; id = 2; dev = "eth0"; depends = [];
        };
        "eth0" = { } ;
        lo = { ipv4Address = "127.0.0.1/8"; };
      };
      etc = {
        "resolv.conf" = { content = ( stdenv.lib.readFile "/etc/resolv.conf" );};
      };
      users = [
        {name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
         shell="/bin/sh"; authorizedKeys = myKeys;}
        {name="store"; uid=500; gid=500; gecos="Storage owner"; dir="/srv";
         shell="/dev/null"; authorizedKeys = [];}
      ];
      packages = [ pkgs.iproute ];
      filesystems = {} ;
    };

    wantedModules = with nixwrt.modules;
      [(_ : _ : _ : baseConfiguration)
       nixwrt.device.hwModule
       (rsyncd { password = rsyncPassword; })
       (sshd { hostkey = ./ssh_host_key ; })
       busybox
       (usbdisk {
         label = "backup-disk";
         mountpoint = "/srv";
         fstype = "ext4";
         options = "rw";
       })
       (switchconfig {
         vlans = {"2" = "1 2 3 6t";  "3" = "0 6t"; };
        })
       (syslogd { loghost = "192.168.0.2"; })
       (ntpd { host = "pool.ntp.org"; })
       (dhcpClient { interface = "eth0.2"; })
      ];
    kernelMtdOpts = nixpkgs: self: super:
      nixpkgs.lib.recursiveUpdate super {
        kernel.config."MTD_SPLIT" = "y";
        kernel.config."MTD_SPLIT_UIMAGE_FW" = "y";
        # partition layout comes from device tree, doesn't need to be specified here
      };
in {
  tftproot =  let configuration = nixwrt.mergeModules (wantedModules ++ [
       (nixwrt.modules.tftpboot { rootOffset="0x2000000"; rootSizeMB="12"; })
     ]);
    in nixwrt.tftproot configuration;
  firmware = let configuration = nixwrt.mergeModules (wantedModules ++ [kernelMtdOpts]);
    in nixwrt.firmware configuration;
}
