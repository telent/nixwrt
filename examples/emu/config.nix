{ nixwrt, device}:
let
  pkgs = nixwrt.nixpkgs;
  lib = pkgs.lib;
  svc = pkgs.svc;
  secrets = {
    myKeys = nixwrt.secret "SSH_AUTHORIZED_KEYS";
    sshHostKey = nixwrt.secret "SSH_HOST_KEY";
    l2tp = {
      lac = nixwrt.secret "L2TP_LAC";
      peer = nixwrt.secret "L2TP_PEER";
      username = nixwrt.secret "L2TP_USERNAME";
      password = nixwrt.secret "L2TP_PASSWORD";
    };
  };
  baseConfiguration = {
    hostname = "emu";
    webadmin = { allow = ["localhost" "192.168.8.0/24"]; };
    interfaces = {
      lo = { ipv4Address = "127.0.0.1/8"; };
    };
    packages = [ nixwrt.nixpkgs.iproute  ];
    busybox = {
      applets = [ "udhcpc" "poweroff" "halt" "reboot" "netcat" "ipcalc"];
      config.FEATURE_IPCALC_FANCY = "y";
    };
  };

  # odhcp to get prefix delegation

  # eth1 hw (something we could connect another vm to?)
  # set up routes for delegated prefix on eth1
  # default route through ppp0


in (with nixwrt.modules;
  [(_ : _ : super : lib.recursiveUpdate super baseConfiguration)
   (import <nixwrt/modules/lib.nix> {})
   (sshd {
     hostkey = secrets.sshHostKey;
     authkeys = { root = (lib.splitString "\n" secrets.myKeys); };
   })
   busybox
   kernelMtd
   (dhcpClient { interface = "eth0"; name = "dhcp-eth0"; })
   (l2tp {
     dhcp = "dhcp-eth0";
     ifname = "wan0";
     lac = secrets.l2tp.lac;
     endpoint = secrets.l2tp.peer;
     username = secrets.l2tp.username;
     password = secrets.l2tp.password;
   })
  ])
