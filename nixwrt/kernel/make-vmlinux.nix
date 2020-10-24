{  stdenv
 , buildPackages
 , runCommand
 , writeText

 , config
 , checkedConfig ? {}
 , tree
} :
let writeConfig = name : config: writeText name
        (builtins.concatStringsSep
          "\n"
          (lib.mapAttrsToList
            (name: value: (if value == "n" then "# CONFIG_${name} is not set" else "CONFIG_${name}=${value}"))
            config
          ));
    kconfigFile = writeConfig "nixwrt_kconfig" config;
    checkedConfigFile = writeConfig "checked_kconfig" checkedConfig ;
    lib = stdenv.lib; in
stdenv.mkDerivation rec {
  name = "vmlinux";

  hardeningDisable = ["all"];
  nativeBuildInputs = [buildPackages.stdenv.cc] ++
                      (with buildPackages.pkgs;
                        [rsync bc bison flex pkgconfig openssl ncurses.all perl]);
  CC = "${stdenv.cc.bintools.targetPrefix}gcc";
  HOSTCC = "gcc -I${buildPackages.pkgs.openssl}/include -I${buildPackages.pkgs.ncurses}/include";
  HOST_EXTRACFLAGS = "-I${buildPackages.pkgs.openssl.dev}/include -L${buildPackages.pkgs.openssl.out}/lib -L${buildPackages.pkgs.ncurses.out}/lib " ;
  PKG_CONFIG_PATH = "./pkgconfig";
  CROSS_COMPILE = stdenv.cc.bintools.targetPrefix;
  ARCH = "mips";  # kernel uses "mips" here for both mips and mipsel
  dontStrip = true;
  dontPatchELF = true;
  outputs = ["out"  "modulesupport"];
  phases = ["butcherPkgconfig"
            "configurePhase"
            "checkConfigurationPhase"
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

  configurePhase = ''
    export KBUILD_OUTPUT=`pwd`
    cp ${kconfigFile} .config
    cp ${kconfigFile} .config.orig
    ( cd ${tree} && make V=1 olddefconfig )
  '';

  checkConfigurationPhase = ''
    echo Checking required config items:
    if comm -2 -3 <(grep 'CONFIG' ${checkedConfigFile} |sort) <(grep 'CONFIG' .config|sort) |grep '.'    ; then
      echo -e "^^^ Some configuration lost :-(\nPerhaps you have mutually incompatible settings, or have disabled options on which these depend.\n"
      exit 0
    fi
    echo "OK"
  '';

  KBUILD_BUILD_HOST = "nixwrt.builder";
  buildPhase = ''
    make -C ${tree} vmlinux
  '';

  installPhase = ''
    ${CROSS_COMPILE}strip -d vmlinux
    cp vmlinux $out
    make clean
    mkdir -p $modulesupport
    cp -a . $modulesupport
  '';

}
