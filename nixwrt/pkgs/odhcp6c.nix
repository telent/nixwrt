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
    rev = "49305e6847efa43e008d0bebdc176e1833120947";
    sha256 = "08n939b190sq92ixvghw2sllmp6kbxz0dxv8av7x68c4gbwpgh4g";
  };
  name = "odhcp6c";

  nativeBuildInputs = [ cmake ];
}
