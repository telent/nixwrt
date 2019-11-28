{ stdenv, buildPackages, libnl, ...} :
let switchDotH = buildPackages.fetchurl {
  url = "https://git.openwrt.org/?p=openwrt/openwrt.git;a=blob_plain;f=target/linux/generic/files/include/uapi/linux/switch.h;hb=99a188828713d6ff9c541590b08d4e63ef52f6d7";
  sha256 = "15kmhhcpd84y4f45rf8zai98c61jyvkc37p90pcxirna01x33wi8";
  name="switch.h";
};
in stdenv.mkDerivation {
  src = buildPackages.fetchFromGitHub {
    owner = "jekader";
    repo = "swconfig";
    rev = "66c760893ecdd1d603a7231fea9209daac57b610";
    sha256 = "0hi2rj1a1fbvr5n1090q1zzigjyxmn643jzrwngw4ij0g82za3al";
  };
  name = "swconfig";
  buildInputs = [ buildPackages.pkgconfig ];
  nativeBuildInputs = [ libnl ];
  CFLAGS="-O2 -Ifrom_kernel -I${libnl.dev}/include/libnl3";
  LDFLAGS="-L${libnl.out}/lib";

  patchPhase = ''
    mkdir -p from_kernel/linux
    cp ${switchDotH} from_kernel/linux/switch.h
  '';

  buildPhase = ''
    make swconfig
    $STRIP swconfig
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp swconfig $out/bin
  '';
}
