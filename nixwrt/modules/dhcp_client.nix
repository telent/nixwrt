{
  resolvConfFile ? null
, interface
, name
} : nixpkgs: self: super:
with nixpkgs;
let
  resolving = resolvConfFile != null;
  writeResolvConf = ''
    conf=${resolvConfFile}
    echo domain $domain > $conf
    for i in $dns; do echo nameserver $i >> $conf ; done
  '';
  pseudofileAttr = if resolving then {
    etc."resolv.conf" = { type = "s"; target = resolvConfFile; };
  } else {};

  if-service = svc {
    name = "${interface}-if";
    start = "${pkgs.iproute}/bin/ip link set dev ${interface} up; setstate up true; setstate name ${interface}";
    # a more robust service would watch for link status and
    # die if cable unplugged
    stop = "${pkgs.iproute}/bin/ip link set dev ${interface} down";
    outputs = ["up" "name"];
    };

  # dhcp to get address (don't create default route)
  dhcpc-service =
    let
      ip = "${pkgs.iproute}/bin/ip";
      script = pkgs.writeScript "dhcp.script" ''
        #! ${pkgs.runtimeShell}
        . ${if-service.statefns} eth0-address
        case $1 in
        deconfig)
          ${ip} link set dev $interface up
          rmstate address
          ;;
        bound)
          ${ip} address flush dev $interface
          ${ip} address add $ip/$subnet dev $interface
          setstate ready true
          setstate address $ip
          prefix=$(busybox ipcalc -p $subnet)
          setstate prefix ''${prefix#PREFIX=}
          ;;
        *)
          echo Missing switch clause for $1;
          ;;
        esac
      '';  in svc rec {
      name = "eth0-address";
      pid = "/run/udhcpc-${name}.pid";
      start = "/bin/busybox udhcpc -f -x hostname:emu -i eth0 -p ${pid}  -s ${script} ";
      foreground = true;
      depends = [ if-service.name if-service.up ];
      outputs = [ "address" "ready" "prefix"];
    };


in
  nixpkgs.lib.attrsets.recursiveUpdate super (pseudofileAttr // {
   busybox.applets = super.busybox.applets ++ [ "udhcpc" ];
   svcs.${name} = dhcpc-service;
  })
