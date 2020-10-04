# GL-Inet GL-AR750

options: nixpkgs: self: super:
let
  soc = import ./ath79.nix;
  dts = {openwrt}:
    let owrtDtsPath = "${openwrt}/target/linux/ath79/dts/qca9531_glinet_gl-ar750.dts";
        cal = ./ar750-ath10k-cal.bin;
    in nixpkgs.stdenv.mkDerivation {
      name = "dts";
      phases = [ "buildPhase" ];
      buildPhase = ''
cat ${owrtDtsPath} > tmp.dts
echo "&pcie0 { wifi@0,0 { qcom,ath10k-calibration-data = [ " >> tmp.dts
od -A n -v -t x1 ${cal}   >> tmp.dts
echo "] ; };};" >> tmp.dts
cp tmp.dts $out
               '';
    };
in soc (options // { inherit dts ;}) nixpkgs self super
