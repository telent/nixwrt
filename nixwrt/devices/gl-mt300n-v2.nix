# GL-Inet GL-MT300N-V2

# This is very similar to the MT300A, but has a slightly different
# chipset and comes in a yellow case not a blue one.  It's different
# again to the v1, which has only half the RAM.  At the time I bought
# it it was a tenner cheaper than the A variant.

options: nixpkgs: self: super:
let
  soc = import ./mt7628.nix;    # XXX doesn't quite work
  dts = {openwrt}: "${openwrt}/target/linux/ramips/dts/mt7628an_glinet_gl-mt300n-v2.dts";
in soc (options // { inherit dts ;}) nixpkgs self super
