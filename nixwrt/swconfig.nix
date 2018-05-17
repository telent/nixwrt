{ stdenv, kernel, buildPackages, libnl, ...} : stdenv.mkDerivation {
  src = buildPackages.fetchFromGitHub {
    owner = "jekader";
    repo = "swconfig";
    rev = "66c760893ecdd1d603a7231fea9209daac57b610";
    sha256 = "0hi2rj1a1fbvr5n1090q1zzigjyxmn643jzrwngw4ij0g82za3al";
  };
  name = "swconfig";
  buildInputs = [ buildPackages.pkgconfig ];
  nativeBuildInputs = [ kernel libnl ];
  CFLAGS="-O2 -I${kernel}/include -I${libnl.dev}/include/libnl3";
  LDFLAGS="-L${libnl.lib}/lib";

  buildPhase = ''
    make swconfig
    $STRIP swconfig
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp swconfig $out/bin
  '';
}
