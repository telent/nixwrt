{  stdenv
 , buildPackages
 , runCommand
 , writeText

 , openwrtSrc
 , backportedSrc
 , klibBuild
 , kconfig
} :
let writeConfig = name : config: writeText name
        (builtins.concatStringsSep
          "\n"
          (lib.mapAttrsToList
            (name: value: (if value == "n" then "# CPTCFG_${name} is not set" else "CPTCFG_${name}=${value}"))
            config
          ));
    config = kconfig;
    kconfigFile = writeConfig "nixwrt_backports_kconfig" config;
#    checkedConfigFile = writeConfig "checked_kconfig" checkedConfig ;
    lib = stdenv.lib; in
stdenv.mkDerivation rec {
  src = backportedSrc;
  name = "backported-modules";

  hardeningDisable = ["all"];
  nativeBuildInputs = [buildPackages.stdenv.cc] ++
                      (with buildPackages.pkgs;
                        [bc bison flex pkgconfig openssl
                         which kmod cpio
                         ncurses.all ncurses.dev perl]);
  #  CC = "${stdenv.cc.bintools.targetPrefix}gcc";
  CC = "${buildPackages.stdenv.cc}/bin/gcc";
  HOSTCC = "gcc -I${buildPackages.pkgs.openssl}/include -I${buildPackages.pkgs.ncurses.dev}/include";
  HOST_EXTRACFLAGS = "-I${buildPackages.pkgs.openssl.dev}/include -L${buildPackages.pkgs.openssl.out}/lib -L${buildPackages.pkgs.ncurses.out}/lib " ;
  PKG_CONFIG_PATH = "./pkgconfig";
  CROSS_COMPILE = stdenv.cc.bintools.targetPrefix;
  ARCH = "mips";  # kernel uses "mips" here for both mips and mipsel
  dontStrip = true;
  dontPatchELF = true;
  phases = ["unpackPhase"
            "butcherPkgconfig"
            "patchFromOpenwrt"
            "configurePhase"
  #           "checkConfigurationPhase"
            "buildPhase"
            "installPhase"
           ];

  # this is here to work around what I think is a bug in nixpkgs packaging
  # of ncurses: it installs pkg-config data files which don't produce
  # any -L options when queried with "pkg-config --lib ncurses".  For a
  # regular nixwrt compilation you'll never even notice, this only becomes
  # an issue if you do a nix-shell in this derivation and expect "make nconfig"
  # to work.
  butcherPkgconfig = ''
    cp -r ${buildPackages.pkgs.ncurses.dev}/lib/pkgconfig .
    chmod +w pkgconfig pkgconfig/*.pc
    for i in pkgconfig/*.pc; do test -f $i && sed -i 's/^Libs:/Libs: -L''${libdir} /'  $i;done
  '';

  patchFromOpenwrt = ''
     mac80211=${openwrtSrc}/package/kernel/mac80211
     cat $mac80211/patches/build/* |patch -p1 -N
     cat $mac80211/patches/rt2x00/* |patch -p1 -N
  '';


   configurePhase = ''
     cp ${kconfigFile} .config
     cp ${kconfigFile} .config.orig
     chmod +w .config .config.orig
     echo $TMPDIR
     make V=1 CC=${CC} SHELL=`type -p bash` LEX=flex KLIB_BUILD=${klibBuild} olddefconfig
     grep ATH9K .config
   '';

   KBUILD_BUILD_HOST = "nixwrt.builder";

   buildPhase = ''
    patchShebangs scripts/
    make V=1 SHELL=`type -p bash` KLIB_BUILD=${klibBuild} modules
    find . -name \*.ko | xargs ${CROSS_COMPILE}strip --strip-debug
   '';

   installPhase = ''
     mkdir -p $out
#     find . -name \*.ko -o -name \*.mod.o | cpio --make-directories --verbose -p $out
     find . -name \*.ko | cpio --make-directories -p $out
     find $out -ls
   ''   ;

}
