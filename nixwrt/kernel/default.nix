{  stdenv
 , buildPackages
 , runCommand
 , writeText
 , config ? {}
 , commandLine ? ""
 , source
} :
let kconfigFile = writeText "nixwrt_kconfig"
        (builtins.concatStringsSep
          "\n"
          (lib.mapAttrsToList
            (name: value: "CONFIG_${name}=${value}")
            (config // {
              "MIPS_CMDLINE_FROM_DTB" = "y";
            } )
          ));
    lib = stdenv.lib; in
stdenv.mkDerivation rec {
  name = "kernel";

  hardeningDisable = ["all"];
  nativeBuildInputs = [buildPackages.stdenv.cc] ++
                      (with buildPackages.pkgs;
                        [bc bison flex openssl perl]);
  CC = "${stdenv.cc.bintools.targetPrefix}gcc";
  HOSTCC = "gcc -I${buildPackages.pkgs.openssl}/include";
  HOST_EXTRACFLAGS = "-I${buildPackages.pkgs.openssl.dev}/include -L${buildPackages.pkgs.openssl.out}/lib ";
  CROSS_COMPILE = stdenv.cc.bintools.targetPrefix;
  ARCH = "mips";              # use "mips" here for both mips and mipsel
  dontStrip = true;
  dontPatchELF = true;
  phases = ["configurePhase" "buildPhase" "installPhase"
  ];

  configurePhase = ''
    export KBUILD_OUTPUT=`pwd`
    cp ${kconfigFile} .config
    cp ${kconfigFile} .config.orig
    ( cd ${source} && make V=1 olddefconfig )
  '';

  KBUILD_BUILD_HOST = "nixwrt.builder";
  buildPhase = ''
    make -C ${source} vmlinux
  '';

  installPhase = ''
    cp vmlinux $out
  '';

}
