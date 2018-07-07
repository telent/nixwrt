options: nixpkgs: self: super:
with nixpkgs;
let dhcpscript = nixpkgs.writeScriptBin "dhcpscript" ''
  #!/bin/sh
  dev=${options.interface}
  ip() { ${pkgs.iproute}/bin/ip  $* ; }
  deconfig(){
    ip addr flush dev $dev
  }
  bound(){
    ip addr replace $ip/$mask dev $dev ;
    ip route add 0.0.0.0/0 via $router;
  }
  case $1 in
    deconfig)
      deconfig
      ;;
    bound|renew)
      bound
      ;;
    *)
      echo unrecognised command $1
      ;;
  esac
  '';
in nixpkgs.lib.attrsets.recursiveUpdate super  {
  busybox.applets = super.busybox.applets ++ [ "udhcpc" ];
  services.udhcpc = {
    start = "${self.busybox.package}/bin/udhcpc -x hostname:${self.hostname} -i ${options.interface} -p /run/udhcpc.pid -s '${dhcpscript}/bin/dhcpscript'";
    depends = [ options.interface ];
  };
}
