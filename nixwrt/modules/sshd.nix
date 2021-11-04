{hostkey, authkeys ? {}}: nixpkgs: self: super:
with nixpkgs;
lib.attrsets.recursiveUpdate super  {
  pkgs = super.packages ++ [pkgs.dropbearSmall];
  users = lib.mapAttrs (user: keys: { authorizedKeys = keys ;}) authkeys;
  services = with nixpkgs; {
    dropbear = {
      start = "${pkgs.dropbearSmall}/bin/dropbear -P /run/dropbear.pid";
      hostKey = hostkey;
    };
  };
}
