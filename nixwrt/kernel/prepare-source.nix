{  stdenv
 , buildPackages
 , socFamily ? null
 , ledeSrc
 , kernelSrc
 , patchutils
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
    nativeBuildInputs = [ patchutils ]; 

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
      for i in `seq -w 001 004`; do cat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/''${i}*.patch | patch -p1 -N --batch ; done
      # this misses a potentially useful patch 
      cat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/005-*.patch  | filterdiff -x '*/rt2x00mac.c' | patch -l -p1 -N 
      for i in `seq -w 006 013`; do cat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/''${i}*.patch | patch -p1 -N --batch ; done
      # not vital that we apply all the hunks here, it's only taking out some
      # superfluous error checks
      cat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/014-rt2x00-no-need-to-check-return-value-of-debugfs_crea.patch  | sed -e 's/0400/S_IRUSR/g' -e 's/0600/S_IRUSR | S_IWUSR/g' | filterdiff --hunks=1,4-5 | patch -l -p1 -N 
      for i in `seq -w 015 031`; do cat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/''${i}*.patch | patch -p1 -N --batch ; done
#      cat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/032-*.patch  | filterdiff -x '*/rt2x00mac.c' | patch -l -p1 -N 
      cat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/050*.patch | patch -p1 -N --batch 
      cat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/601-*.patch | filterdiff -x '*/local-symbols' -x '*/rt2x00_platform.h'  | patch -p1 -N 
      cat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/602-*.patch | sed 's/CPTCFG_/CONFIG_/g' | filterdiff -x '*/local-symbols' | patch  -p1 -N 
      cat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/603-*.patch | patch -p1 -N
      cat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/604-*.patch | patch -p1 -N
      cat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/606-*.patch | filterdiff -x '*/local-symbols' -x '*/rt2x00_platform.h'  | patch -p1 -N 
      cat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/607-*.patch | filterdiff -x '*/local-symbols' -x '*/rt2x00_platform.h'  | patch -p1 -N 
      cat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/60[89]-*.patch | patch -p1 -N 
      cat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/9*.patch | patch -p1 -N
      ${lib.optionalString (! isNull socFamily)
                           "q_apply ${ledeSrc}/target/linux/${socFamily}/patches-${majmin}/"}
      chmod -R +w .       # */

    '';

    patches = [ ./kernel-ath79-wdt-at-boot.patch
                ./kernel-lzma-command.patch
                ./kexec_copy_from_user_return.patch
              ] ++ lib.optional (! versionExceeds version [4 10 0]) ./kernel-memmap-param.patch
#                ++ lib.optional (versionExceeds version [4 10 0]) ./kexec-fdt.patch;
                 ;

    patchFlags = [ "-p1" ];
    buildPhase = ''
      substituteInPlace scripts/ld-version.sh --replace /usr/bin/awk ${buildPackages.pkgs.gawk}/bin/awk
      substituteInPlace Makefile --replace /bin/pwd ${buildPackages.pkgs.coreutils}/bin/pwd
    '';

    installPhase = ''
      cp -a . $out
    '';

  }
