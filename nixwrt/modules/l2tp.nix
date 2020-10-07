options: nixpkgs: self: super:
with nixpkgs;
let
  ppp_options = writeText "ppp.options" ''
    +ipv6
    debug
    ipv6cp-use-ipaddr
    name ${options.username}
    password ${options.password}
    noauth
  '';
  configFile = writeText "xl2tpd.conf" ''
    [global]
    max retries = 1
    [lac aaisp]
    autodial = no
    ppp debug = no
    redial = no
    lns = ${options.endpoint}
    require authentication = no
    pppoptfile = ${ppp_options}
  ''
    ;
in lib.attrsets.recursiveUpdate super {
  packages = super.packages ++ [ pkgs.xl2tpd pkgs.ppp ];

  kernel.config."L2TP" = "y";
  kernel.config."PPP" = "y";
  kernel.config."PPPOL2TP" = "y";
  kernel.config."PPP_ASYNC" = "y";
  kernel.config."PPP_BSDCOMP" = "y";
  kernel.config."PPP_DEFLATE" = "y";
  kernel.config."PPP_SYNC_TTY" = "y";

  etc."xl2tpd.secrets" = {
    mode = "0400";
    content = "# empty\n";
  };

  services.l2tp = {
    start = "echo ${pkgs.xl2tpd}/bin/xl2tpd -c ${configFile} -s /etc/xl2tpd.secrets -p /run/l2tp.pid -C /run/xl2tpd.control";
  };
}
