nixpkgs: self: super:
with nixpkgs;
nixpkgs.lib.attrsets.recursiveUpdate super {
  packages = super.packages ++ [ pkgs.haveged ];
  services.haveged = {
    start = "${pkgs.haveged}/bin/haveged --pid /run/haveged.pid --run 0";
  };
}

