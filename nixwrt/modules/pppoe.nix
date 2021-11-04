params @ {options ? {}, auth} : nixpkgs: self: super:
let ppp_config = nixpkgs.writeText "pppd.options"
  (builtins.concatStringsSep
    "\n"
    (nixpkgs.lib.mapAttrsToList
      (name: value: "${name} ${value}")
	    ({plugin = "rp-pppoe.so";
  	    # nodetach
        "eth0" = "";
	      usepeerdns = "";
	      defaultroute ="";
	      persist = "";} // options)));
in nixpkgs.lib.recursiveUpdate super {
	kernel.config."PPP" = "y";
	kernel.config."PPP_BSDCOMP" = "y";
	kernel.config."PPP_DEFLATE" = "y";
	kernel.config."PPP_ASYNC" = "y";
	kernel.config."PPP_SYNC_TTY" = "y";
	packages = super.packages ++ [ nixpkgs.ppp ppp_config ];
	etc."ppp" = { type="d"; mode = "0500"; };
	etc."ppp/chap-secrets" = { content = auth; mode = "0400"; };
	etc."ppp/pap-secrets" = { content = auth; mode = "0400"; };
}
