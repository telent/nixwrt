{ myKeys
, loghost
, sshHostKey
, lib
, nixwrt
, ...
}:
let
  baseConfiguration = lib.recursiveUpdate
    nixwrt.emptyConfig {
      hostname = "emu";
      webadmin = { allow = ["localhost" "192.168.8.0/24"]; };
      interfaces = {
        "eth0" = { } ;
        lo = { ipv4Address = "127.0.0.1/8"; };
      };
      users = [
        {name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
         shell="/bin/sh"; authorizedKeys = (lib.splitString "\n" myKeys);}
      ];
      packages = [ nixwrt.nixpkgs.iproute ];
      busybox = { applets = [ "poweroff" "halt" "reboot" ]; };
    };

  m = with nixwrt.modules;
  [(_ : _ : _ : baseConfiguration)
   (import <nixwrt/modules/lib.nix> {})
   (import <nixwrt/devices/qemu.nix> {})
   (sshd { hostkey = sshHostKey ; })
   busybox
   kernelMtd
   (dhcpClient {
     resolvConfFile = "/run/resolv.conf";
     interface = "eth0";
   })
  ];
in m
