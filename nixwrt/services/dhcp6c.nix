{svc, iproute, writeScript, odhcp6c} :
{ link
, ifname
, hostname
, prefixLength ? 64
} :
let
  serviceName = "dhcp6c-${ifname}";
  dhcp6script = ''
    #!/bin/sh
    set -x
    echo $0 $1 $2

    dev=$1
    . ${link.statefns} ${serviceName}
    ip() { ${iproute}/bin/ip  $* ; }
    deconfig(){
      :
      #      ip addr flush dev $dev
      #      rmstate address
    }
    bound(){
      for el in $ADDRESSES; do
        # Format: <address>/<length>,preferred,valid
        addr=''${el%%,*}
        ip addr add $addr dev $dev
        setstate address $addr
      done
      setstate ready true
      setstate prefixes $PREFIXES
      setstate nameservers $RDNSS
    }
    echo $0 $1 $2
    case $2 in
      started|stopped|unbound)
        deconfig
        ;;
      bound)
        deconfig
        bound
        ;;
      informed|updated|rebound|ra-updated)
        bound
        ;;
      *)
        echo $0: unrecognised subcommand $2
        ;;
    esac
    '';
in svc rec {
  name = serviceName;
  pid = "/run/${name}.pid";
  start = "${odhcp6c}/bin/odhcp6c -P ${builtins.toJSON prefixLength}  -p ${pid}   -v -e -s '${writeScript "dhcp6script" dhcp6script}'  ${ifname}";
  foreground = true;
  depends = [ link.ready ];
  outputs = [ "ready" "address" "nameservers" "prefixes"];
}
