{svc, callPackage} : {
  netdevice = callPackage ./netdevice.nix {};
  dhcpc = callPackage ./dhcpc.nix {};
  l2tp = callPackage ./l2tp.nix {};
}
