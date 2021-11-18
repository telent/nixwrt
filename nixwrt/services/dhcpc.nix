{svc, iproute, writeScriptBin} :
{ interface
, hostname
, addDefaultRoute ? false
} :
let
  ifname = interface.name;
  dhcpscript = ''
    #!/bin/sh
    dev=${ifname}
    ip() { ${iproute}/bin/ip  $* ; }
    deconfig(){
      ip addr flush dev $dev
    }
    bound(){
      ip addr replace $ip/$mask dev $dev ;
      # ip route add 0.0.0.0/0 via $router;
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
in svc rec {
  name = "dhcpc-${interface.name}";
  config = {
    busybox.applets = [ "udhcpc" ];
  };
  pid = "/run/${name}.pid";
  start = "/bin/udhcpc -x hostname:${hostname} -i ${ifname} -p ${pid}  -s '${writeScriptBin "dhcpscript" dhcpscript}/bin/dhcpscript'";
  depends = [ interface.ready ];
  outputs = [ "ready"];
}
