{svc, iproute, writeScript, writeText, xl2tpd, ppp } :
{ link
, ifname
, peer
, username
, password
} :
let
  serviceName = "l2tp-${link.name}";
  ip-up-script = writeScript "ip-up" ''
    #!/bin/sh
    # params are ifname tty speed local-addr remote-addr ipparam
    . ${link.statefns} l2tp
    setstate local-v4-address $4
    setstate peer-v4-address $5
    setstate ready true
  '';
  ipv6-up-script = writeScript "ipv6-up" ''
    #!/bin/sh
    # params are ifname tty speed local-addr remote-addr ipparam

    # this is a workaround for a bug I haven't diagnosed yet.
    # the ipv6 link address that pppd adds seems not to work
    # (can't be pinged, doesn't see traffic), unless I delete
    # and add it again. Don't know why. From the pppd source code
    # it uses an ioctl to create the route whereas iproute is
    # using netlink, maybe that's a place to start investigating
    ip=${iproute}/bin/ip
    $ip address del $4 dev $1 scope link
    $ip address add $4 peer $5 dev $1 scope link
    setstate local-v6-address $4
    setstate peer-v6-address $5
  '';
  ppp_options = writeText "ppp.options" ''
    +ipv6
    ipv6cp-use-ipaddr
    ipv6cp-accept-local
    ifname ${ifname}
    name ${username}
    ip-up-script ${ip-up-script}
    ipv6-up-script ${ipv6-up-script}
    password ${password}
    logfile /dev/console
    noauth
  '';
  configFile = writeText "xl2tpd.conf" ''
    [global]
    max retries = 1
    [lac lac]
    autodial = yes
    ppp debug = no
    redial = no
    lns = ${peer}
    require authentication = no
    pppoptfile = ${ppp_options}
  ''
    ;
in svc rec {
  name = serviceName;
  pid = "/run/${serviceName}.pid";
  foreground = true;
  depends = [ link.ready  ];
  start = ''
    ${xl2tpd}/bin/xl2tpd -D -c ${configFile} -s /etc/xl2tpd.secrets -p ${pid} -C /run/${serviceName}.control
  ''  ;
  outputs = ["ready"];
  config = {
    packages = [ xl2tpd ppp ];
    kernel.config = {
      "L2TP" = "y";
      "PPP" = "y";
      "PPPOL2TP" = "y";
      "PPP_ASYNC" = "y";
      "PPP_BSDCOMP" = "y";
      "PPP_DEFLATE" = "y";
      "PPP_SYNC_TTY" = "y";
    };
    etc."xl2tpd.secrets" = {
      mode = "0400";
      content = "# empty apart from this comment\n";
    };
  };
}
