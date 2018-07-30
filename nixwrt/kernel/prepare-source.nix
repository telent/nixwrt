{  stdenv
 , buildPackages
 , socFamily ? null
 , ledeSrc
 , kernelSrc
 , version
} :
let versionScalar = v :
      let nth = n : builtins.elemAt v n;
      in (nth 2) + ((nth 1) * 1000) + ((nth 0) * 1000000);
    versionExceeds = a : b : (versionScalar a) > (versionScalar b) ;
    lib = stdenv.lib; in
stdenv.mkDerivation rec {
    name = "kernel-source";
    phases = [ "unpackPhase" "patchFromLede" "patchPhase" "buildPhase" "installPhase" ];
    src = kernelSrc;

    patchFromLede = let
      majmin = "${toString (builtins.elemAt version 0)}.${toString (builtins.elemAt version 1)}";
    in ''
      q_apply() {
        if test -d $1 ; then find $1 -type f | sort | xargs  -n1 patch -N -p1 -i  ;fi
      }
      cp -dRv ${ledeSrc}/target/linux/generic/files/* .
      cp -dRv ${ledeSrc}/target/linux/ramips/files-${majmin}/* .
      cp -dRv ${ledeSrc}/target/linux/ar71xx/files/* .
      q_apply ${ledeSrc}/target/linux/generic/backport-${majmin}/
      q_apply ${ledeSrc}/target/linux/generic/pending-${majmin}/
      q_apply ${ledeSrc}/target/linux/generic/hack-${majmin}/
      ${lib.optionalString (! isNull socFamily)
                           "q_apply ${ledeSrc}/target/linux/${socFamily}/patches-${majmin}/"}
      chmod -R +w .       # */

    '';

    patches = [ ./kernel-ath79-wdt-at-boot.patch
                ./kernel-lzma-command.patch
                ./kexec_copy_from_user_return.patch
              ] ++ lib.optional (! versionExceeds version [4 10 0]) ./kernel-memmap-param.patch
                ++ lib.optional (versionExceeds version [4 10 0]) ./kexec-fdt.patch;

    patchFlags = [ "-p1" ];
    buildPhase = ''
      substituteInPlace scripts/ld-version.sh --replace /usr/bin/awk ${buildPackages.pkgs.gawk}/bin/awk
      substituteInPlace Makefile --replace /bin/pwd ${buildPackages.pkgs.coreutils}/bin/pwd
    '';

    installPhase = ''
      cp -a . $out
    '';

  }
