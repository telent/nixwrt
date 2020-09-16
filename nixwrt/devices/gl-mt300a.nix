options: nixpkgs: self: super:
let
  soc = import ./mt7620.nix;
  dts = {openwrt}: "${openwrt}/target/linux/ramips/dts/mt7620a_glinet_gl-mt300a.dts";
in soc (options // { inherit dts ;}) nixpkgs self super
