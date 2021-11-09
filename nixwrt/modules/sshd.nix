{hostkey, authkeys ? {}}: nixpkgs: self: super:
with nixpkgs;
lib.attrsets.recursiveUpdate super  {
  pkgs = super.packages ++ [pkgs.dropbearSmall];
  users = lib.mapAttrs (user: keys: { authorizedKeys = keys ;}) authkeys;
  svcs.ssh = svc {
    name = "ssh";
    start = "${pkgs.dropbearSmall}/bin/dropbear -P /run/dropbear.pid";
    outputs = ["ready"];
  };
  sshHostKey = hostkey;
}
