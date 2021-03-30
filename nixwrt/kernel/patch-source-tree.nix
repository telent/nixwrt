{ upstream
, openwrt
, version
, patches
, files

, stdenv
, lib
, buildPackages
, patchutils
} :
let versionScalar = v :
      let nth = n : builtins.elemAt v n;
      in (nth 2) + ((nth 1) * 1000) + ((nth 0) * 1000000);
    versionExceeds = a : b : (versionScalar a) > (versionScalar b) ;
    inherit lib; in
stdenv.mkDerivation rec {
    name = "kernel-source-tree";
    phases = [ "unpackPhase" "allThePatchesPhase" "buildPhase" "installPhase" ];
    src = upstream;
    nativeBuildInputs = [ patchutils ];

    allThePatchesPhase = let
      majmin = "${toString (builtins.elemAt version 0)}.${toString (builtins.elemAt version 1)}";
    in ''
      patchv() {
        for i in "$@"; do
          echo $i;
          patch -N -p1 -i $i
        done
      }
      q_apply() {
        echo "Checking $1 for patches:"
        if test -d $1 ; then patchv $(find $1 -type f | sort)  ;fi
        if test -f $1 ; then patchv $1 ; fi
      }
      ${lib.concatMapStringsSep "\n" (x: "test -d ${x} && cp -dRv ${x}/* .")
        files}
      ${lib.concatMapStringsSep "\n" (x: "q_apply ${x}") patches}
      chmod -R +w .
    '';

    buildPhase = ''
      substituteInPlace scripts/ld-version.sh --replace /usr/bin/awk ${buildPackages.pkgs.gawk}/bin/awk
      substituteInPlace Makefile --replace /bin/pwd ${buildPackages.pkgs.coreutils}/bin/pwd
    '';

    installPhase = ''
      cp -a . $out
    '';

  }
