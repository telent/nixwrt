{svc, iproute, writeScriptBin} :
{ interface
, hostname
, addDefaultRoute ? false
} :
let
  ifname = interface.name;
  serviceName = "dhcpc-${interface.name}";
  dhcpscript = ''
    #!/bin/sh
    dev=${ifname}
    . ${interface.statefns} ${serviceName}
    ip() { ${iproute}/bin/ip  $* ; }
    deconfig(){
      ip addr flush dev $dev
      rmstate address
    }
    bound(){
      ip addr replace $ip/$mask dev $dev ;
      setstate ready true
      setstate address $ip
      prefix=$(busybox ipcalc -p $subnet)
      setstate prefix ''${prefix#PREFIX=}
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
        echo $0: unrecognised subcommand $1
        ;;
    esac
    '';
in svc rec {
  name = serviceName;
  config = {
    busybox = {
      applets = [ "udhcpc" "ipcalc" ];
      config.FEATURE_IPCALC_FANCY = "y";
    };
  };
  pid = "/run/${name}.pid";
  start = "/bin/udhcpc -f -F ${hostname} -x hostname:${hostname} -i ${ifname} -p ${pid}  -s '${writeScriptBin "dhcpscript" dhcpscript}/bin/dhcpscript'";
  foreground = true;
  depends = [ interface.ready ];
  outputs = [ "ready" "address" "prefix"];
}
