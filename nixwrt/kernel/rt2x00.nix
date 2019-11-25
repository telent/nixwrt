{ ledeSrc, stdenv, callPackage, patchutils } :
stdenv.mkDerivation {
  name = "rt2x00-patch";
  nativeBuildInputs = [ patchutils ];
  inherit ledeSrc;
  builder = ./make-rt2x00-monster-patch.sh;
}
