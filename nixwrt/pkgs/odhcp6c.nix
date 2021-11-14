{ stdenv
, buildPackages
, cmake
, fetchFromGitHub
, ...} :
let switchDotH = buildPackages.fetchurl {
  url = "https://git.openwrt.org/?p=openwrt/openwrt.git;a=blob_plain;f=target/linux/generic/files/include/uapi/linux/switch.h;hb=99a188828713d6ff9c541590b08d4e63ef52f6d7";
  sha256 = "15kmhhcpd84y4f45rf8zai98c61jyvkc37p90pcxirna01x33wi8";
  name="switch.h";
};
in stdenv.mkDerivation {
  src = fetchFromGitHub {
    owner = "openwrt";
    repo = "odhcp6c";
    rev = "94adc8bbfa5150d4c2ceb4e05ecd1840dfa3df08";
    sha256 = "02jz1i5l5p5nsmpp2lwrw8hbfrg17f2lg70xcgcvb7xh6l5q8jan";
  };
  name = "odhcp6c";
  nativeBuildInputs = [ cmake ];
}
