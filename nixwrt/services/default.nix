{svc, callPackage} : {
  netdevice = callPackage ./netdevice.nix {};
  dhcpc = callPackage ./dhcpc.nix {};
}
