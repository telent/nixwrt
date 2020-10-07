options@{lac, ifname, username, password, endpoint, ...}: nixpkgs: self: super:
with nixpkgs;
# FIXME this only works for a single tunnel/session, generalising this
# for multiple-anything is left for another time
let
  ppp_options = writeText "ppp.options" ''
    +ipv6
    debug
    ipv6cp-use-ipaddr
    ifname ${ifname}
    name ${username}
    password ${password}
    noauth
  '';
  configFile = writeText "xl2tpd.conf" ''
    [global]
    max retries = 1
    [lac ${lac}]
    autodial = no
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

  interfaces."${ifname}" = {
    type = "l2tp";
    depends = ["xl2tpd"];
    ifup = [
      "/bin/echo c ${lac} > /run/xl2tpd.control"
    ];
    ifdown = [
      "/bin/echo d ${lac} > /run/xl2tpd.control"
    ];
  };

  etc."xl2tpd.secrets" = {
    mode = "0400";
    content = "# empty apart from this comment\n";
  };

  services.xl2tpd = {
    start = "${pkgs.xl2tpd}/bin/xl2tpd -c ${configFile} -s /etc/xl2tpd.secrets -p /run/xl2tpd.pid -C /run/xl2tpd.control";
  };
}
