{  stdenv
 , lzma
 , buildPackages
 , runCommand
 , writeText
 , socFamily ? null
 , config ? {}
 , commandLine ? ""
 , ledeSrc
 , kernelSrc
 , loadAddress ? "0x80000000"
 , entryPoint ? "0x80000000"
 , dtsPath ? null
} :
let kconfigFile = writeText "nixwrt_kconfig"
        (builtins.concatStringsSep
          "\n"
          (lib.mapAttrsToList
            (name: value: "CONFIG_${name}=${value}")
            (config // { "CMDLINE" = builtins.toJSON commandLine; } )
            ));
    lib = stdenv.lib; in
stdenv.mkDerivation rec {
    name = "kernel";
    src = kernelSrc;

    prePatch =  ''
      q_apply() {
        find $1 -type f | sort | xargs  -n1 patch -N -p1 -i
      }
      cp -dRv ${ledeSrc}/target/linux/generic/files/* .   # */
      cp -dRv ${ledeSrc}/target/linux/ramips/files-4.9/* .  # */
      cp -dRv ${ledeSrc}/target/linux/ar71xx/files/* .  # */
      q_apply ${ledeSrc}/target/linux/generic/backport-4.9/
      q_apply ${ledeSrc}/target/linux/generic/pending-4.9/
      q_apply ${ledeSrc}/target/linux/generic/hack-4.9/
      ${lib.optionalString (! isNull socFamily)
                           "q_apply ${ledeSrc}/target/linux/${socFamily}/patches-4.9/"}
      ${lib.optionalString (! isNull dtsPath)
                       "cp ${dtsPath} board.dts"
                       }
      chmod -R +w .
    '';

    patches = [ ./kernel-ath79-wdt-at-boot.patch
                ./kernel-lzma-command.patch
                ./kernel-memmap-param.patch
#                ./kernel-dts-enable-eth0.patch
                ];

    patchFlags = [ "-p1" ];

    hardeningDisable = ["all"];
    nativeBuildInputs = [buildPackages.pkgs.bc
     lzma buildPackages.stdenv.cc
     buildPackages.pkgs.ubootTools];
    CC = "${stdenv.cc.bintools.targetPrefix}gcc";
    HOSTCC = "gcc";
    CROSS_COMPILE = stdenv.cc.bintools.targetPrefix;
    ARCH = "mips";              # use "mips" here for both mips and mipsel
    dontStrip = true;
    dontPatchELF = true;

    configurePhase = ''
      substituteInPlace scripts/ld-version.sh --replace /usr/bin/awk ${buildPackages.pkgs.gawk}/bin/awk
      make V=1 mrproper
      cp ${kconfigFile} .config
      make V=1 olddefconfig
    '';

    outputs = [ "dev" "out" "vmlinux"];
    buildPhase = ''
      make vmlinux
      objcopy -O binary -R .reginfo -R .notes -R .note -R .comment -R .mdebug -R .note.gnu.build-id -S vmlinux vmlinux.stripped
      if test -f board.dts; then
        cc -o scripts/patch-dtb ${ledeSrc}/tools/patch-image/src/patch-dtb.c
        cpp -nostdinc -x assembler-with-cpp -I${ledeSrc}/target/linux/ramips/dts -Iarch/mips/boot/dts -Iarch/mips/boot/dts/include -Iinclude/ -undef -D__DTS__  -o dtb.tmp board.dts
        scripts/dtc/dtc -O dtb -i${ledeSrc}/target/linux/ramips/dts/  -o vmlinux.dtb dtb.tmp
        scripts/patch-dtb vmlinux.stripped vmlinux.dtb
      fi
      rm -f vmlinux.stripped.lzma
      ${lzma}/bin/lzma -k -z  vmlinux.stripped
      mkimage -A mips -O linux -T kernel -C lzma -a ${loadAddress} -e ${entryPoint} -n 'MIPS NixWrt Linux' -d vmlinux.stripped.lzma kernel.image
    '';

    installPhase = ''
      mkdir -p $out
      cp kernel.image $out/
      make headers_install INSTALL_HDR_PATH=$out
      cp vmlinux $vmlinux
    '';

    shellHook = ''
      export ledeSrc=${ledeSrc}
    '';
  }
