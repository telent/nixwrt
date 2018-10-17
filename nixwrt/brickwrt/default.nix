{ stdenv, lib, busybox, ... } : stdenv.mkDerivation {
  name = "brickwrt";
  version = "1";
  src = lib.sourceFilesBySuffices ./. ["Makefile" ".c" ".h" ".sh"];
  sh = "/bin/sh";
  dontPatchShebangs = 1; # avoid patchShebangs which adds dep on bash
  stripAllList = [ "bin" "sbin" "libexec" ];
  installPhase = ''
    mkdir -p $out/bin $out/libexec
    substituteAll reserve.sh $out/bin/brickwrt-reserve
    substituteAll load.sh $out/bin/brickwrt-load
    substituteAll commit.sh $out/bin/brickwrt-commit
    install writemem $out/libexec/
    (cd $out/bin/ && chmod +x * )
  '';
}
