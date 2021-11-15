{ nixwrt, device}:
let
  lib = nixwrt.nixpkgs.lib;
  secrets = {
    myKeys = nixwrt.secret "SSH_AUTHORIZED_KEYS";
    sshHostKey = nixwrt.secret "SSH_HOST_KEY";
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
   (sshd {
     hostkey = secrets.sshHostKey;
     authkeys = { root = (lib.splitString "\n" secrets.myKeys); };
   })
   busybox
   kernelMtd
   (dhcpClient {
     resolvConfFile = "/run/resolv.conf";
     interface = "eth0";
   })
  ])
