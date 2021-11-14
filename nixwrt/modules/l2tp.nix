options@{lac, dhcp, ifname, username, password, endpoint, ...}: nixpkgs: self: super:
with nixpkgs;

let
  dhcp-service = super.svcs.${dhcp};
  ip-up-script = pkgs.writeScript "ip-up" ''
    #!/bin/sh
    # params are interface-name tty-device speed local-IP-address
    #  remote-IP-address ipparam
    . ${dhcp-service.statefns} l2tp
    setstate local-address $4
    setstate peer-address $5
    setstate ready true
  '';
  ipv6-up-script = pkgs.writeScript "ipv6-up" ''
    #!/bin/sh -x
    # params are interface-name tty-device speed local-IP-address
    #  remote-IP-address ipparam

    # this is a workaround for a bug I haven't diagnosed yet.
    # the ipv6 link address that pppd adds seems not to work
    # (can't be pinged, doesn't see traffic), unless I delete
    # and add it again. Don't know why. From the pppd source code
    # it uses an ioctl to create the route whereas iproute is
    # using netlink, maybe that's a place to start investigating
    ip=${pkgs.iproute}/bin/ip
    $ip address del $4 dev $1 scope link
    $ip address add $4 peer $5 dev $1 scope link
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
    [lac ${lac}]
    autodial = yes
    ppp debug = no
    redial = no
    lns = ${endpoint}
    require authentication = no
    pppoptfile = ${ppp_options}
  ''
    ;
in lib.attrsets.recursiveUpdate super {
  packages = super.packages ++ [ pkgs.xl2tpd pkgs.ppp ];
  busybox = { applets = super.busybox.applets ++ ["echo"];}; # unneeded?

  kernel.config."L2TP" = "y";
  kernel.config."PPP" = "y";
  kernel.config."PPPOL2TP" = "y";
  kernel.config."PPP_ASYNC" = "y";
  kernel.config."PPP_BSDCOMP" = "y";
  kernel.config."PPP_DEFLATE" = "y";
  kernel.config."PPP_SYNC_TTY" = "y";

  etc."xl2tpd.secrets" = {
    mode = "0400";
    content = "# empty apart from this comment\n";
  };

  # echo "c aaisp" >/run/xl2tpd.control

  svcs.xl2tpd = svc {
    name = "l2tp";
    pid = "/run/xl2tpd.pid";
    foreground = true;
    depends = [ dhcp-service.ready  ];
    start = "${pkgs.xl2tpd}/bin/xl2tpd -D -c ${configFile} -s /etc/xl2tpd.secrets -p /run/xl2tpd.pid -C /run/xl2tpd.control";
    outputs = ["ready"];
  };
}
