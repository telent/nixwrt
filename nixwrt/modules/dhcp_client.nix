options: nixpkgs: self: super:
with nixpkgs;
let resolving = (options ? resolvConfFile );
writeResolvConf = ''
    conf=${options.resolvConfFile}
    echo domain $domain > $conf
    for i in $dns; do echo nameserver $i >> $conf ; done
'';
pseudofileAttr = if resolving then {
   etc."resolv.conf" = { type = "s"; target = options.resolvConfFile; };
} else {};
dhcpscript = ''
  #!/bin/sh
  dev=${options.interface}
  ip() { ${pkgs.iproute}/bin/ip  $* ; }
  deconfig(){
    ip addr flush dev $dev
  }
  bound(){
    ip addr replace $ip/$mask dev $dev ;
    ip route add 0.0.0.0/0 via $router;
    ${if resolving then writeResolvConf else ""}
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
in 
  nixpkgs.lib.attrsets.recursiveUpdate super (pseudofileAttr // {
   busybox.applets = super.busybox.applets ++ [ "udhcpc" ];
   services.udhcpc = {
     start = "${self.busybox.package}/bin/udhcpc -x hostname:${self.hostname} -i ${options.interface} -p /run/udhcpc.pid -s '${writeScriptBin "dhcpscript" dhcpscript}/bin/dhcpscript'";
     depends = [ options.interface ];
   };   
   })
