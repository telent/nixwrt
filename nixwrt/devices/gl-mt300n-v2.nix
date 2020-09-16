options: nixpkgs: self: super:
let
  soc = import ./mt7620.nix;    # XXX doesn't quite work
  dts = {openwrt}: "${openwrt}/target/linux/ramips/dts/mt7628an_glinet_gl-mt300n-v2.dts";
in soc (options // { inherit dts ;}) nixpkgs self super
