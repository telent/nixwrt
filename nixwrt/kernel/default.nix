{  stdenv
 , buildPackages
 , runCommand
 , writeText
 , config ? {}
 , commandLine ? ""
 , sourceTree
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
    nativeBuildInputs = [buildPackages.pkgs.bc buildPackages.stdenv.cc ];
    CC = "${stdenv.cc.bintools.targetPrefix}gcc";
    HOSTCC = "gcc";
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
      ( cd ${sourceTree} && make V=1 olddefconfig )
    '';

    KBUILD_BUILD_HOST = "nixwrt.builder";
    buildPhase = ''
      make -C ${sourceTree} vmlinux
    '';

    installPhase = ''
      cp vmlinux $out
    '';

  }
