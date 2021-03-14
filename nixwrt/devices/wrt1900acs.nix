# WRT1900ACS

options: nixpkgs: self: super:
let
  soc = import ./mvebu.nix;
  dts = {openwrt}:
    let owrtDtsPath = "${openwrt}/target/linux/mvebu/files/arch/arm/boot/dts/armada-385-linksys-venom.dts";
    in nixpkgs.stdenv.mkDerivation {
      name = "dts";
      phases = [ "buildPhase" ];
      buildPhase = ''
cat ${owrtDtsPath} > tmp.dts
cp tmp.dts $out
               '';
    };
in soc (options // { inherit dts ;}) nixpkgs self super
