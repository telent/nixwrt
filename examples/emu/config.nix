{ nixwrt, device}:
let
  lib = nixwrt.nixpkgs.lib;
  secrets = {
    myKeys = builtins.getEnv "SSH_AUTHORIZED_KEYS";
    sshHostKey = builtins.getEnv "SSH_HOST_KEY";
  };
  baseConfiguration = {
    hostname = "emu";
    webadmin = { allow = ["localhost" "192.168.8.0/24"]; };
    interfaces = {
      "eth0" = { } ;
      lo = { ipv4Address = "127.0.0.1/8"; };
    };
    packages = [ nixwrt.nixpkgs.iproute ];
    busybox = { applets = [ "poweroff" "halt" "reboot" ]; };
  };

in (with nixwrt.modules;
  [(_ : _ : super : lib.recursiveUpdate super baseConfiguration)
   (import <nixwrt/modules/lib.nix> {})
   (user {
     name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
     shell="/bin/sh";
     authorizedKeys = (lib.splitString "\n" secrets.myKeys);
   })
   (sshd { hostkey = secrets.sshHostKey ; })
   busybox
   kernelMtd
   (dhcpClient {
     resolvConfFile = "/run/resolv.conf";
     interface = "eth0";
   })
  ])
