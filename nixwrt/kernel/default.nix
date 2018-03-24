{ stdenv, lzma, onTheBuild, targetPlatform, kconfig ? [] } :
let wantModules = false;
    ledeSrc = onTheBuild.fetchFromGitHub {
      owner = "lede-project";
      repo = "source";
      rev = "57157618d4c25b3f08adf28bad5b24d26b3a368a";
      sha256 = "0jbkzrvalwxq7sjj58r23q3868nvs7rrhf8bd2zi399vhdkz7sfw";
    };
    lib = stdenv.lib; in
stdenv.mkDerivation rec {
    name = "nixwrt_kernel";
    defaultKconfig = [
      "CLKSRC_MMIO"
      "DEBUG_INFO"
      "DEVTMPFS"
      "EARLY_PRINTK"
      "GENERIC_IRQ_IPI"
      "IP_PNP"
      "MIPS_CMDLINE_DTB_EXTEND"
      "MTD_CMDLINE_PART"
      "MTD_PHRAM"
      "NET_MEDIATEK_GSW_MT7620"
      "NET_MEDIATEK_MT7620"
      "PRINTK_TIME"
      "SOC_MT7620"
      "SQUASHFS"
      "SQUASHFS_XZ"
      "TMPFS"
      ];
    src = let
     url = {
       url = "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.9.76.tar.xz";
       sha256 = "1pl7x1fnyhvwbdxgh0w5fka9dyysi74n8lj9fkgfmapz5hrr8axq";
     }; in onTheBuild.fetchurl url;

    prePatch =  ''
      q_apply() {
        find $1 -type f | sort | xargs  -n1 patch -N -p1 -i
      }
      cp -dRv ${ledeSrc}/target/linux/generic/files/* .   # */
      cp -dRv ${ledeSrc}/target/linux/ramips/files-4.9/* .  # */
      q_apply ${ledeSrc}/target/linux/generic/backport-4.9/
      q_apply ${ledeSrc}/target/linux/generic/pending-4.9/
      q_apply ${ledeSrc}/target/linux/generic/hack-4.9/
      q_apply ${ledeSrc}/target/linux/ramips/patches-4.9/
      chmod -R +w .
    '';

    patches = [ ./kernel-ath79-wdt-at-boot.patch
                ./kernel-lzma-command.patch
                ./kernel-memmap-param.patch
                ];

    patchFlags = [ "-p1" ];

    hardeningDisable = ["all"];
    nativeBuildInputs = [onTheBuild.pkgs.bc
     lzma onTheBuild.stdenv.cc
     onTheBuild.pkgs.ubootTools];
    CC = "${stdenv.cc.bintools.targetPrefix}gcc";
    HOSTCC = "gcc";
    CROSS_COMPILE = stdenv.cc.bintools.targetPrefix;
    ARCH = "mips";
    dontStrip = true;
    dontPatchELF = true;
    enableKconfig = builtins.concatStringsSep
                     "\n"
                     (map (n : "CONFIG_${n}=y") (kconfig ++ defaultKconfig));

    configurePhase = ''
      cat ${ledeSrc}/target/linux/generic/config-4.9  ${ledeSrc}/target/linux/ramips/mt7620/config-4.9 > arch/mips/configs/mt7620_defconfig
      substituteInPlace scripts/ld-version.sh --replace /usr/bin/awk ${onTheBuild.pkgs.gawk}/bin/awk
      make V=1 mrproper
      ( grep -v CONFIG_BLK_DEV_INITRD arch/mips/configs/${targetPlatform.kernelHeadersBaseConfig} && echo "CONFIG_CPU_${lib.strings.toUpper targetPlatform.endian}_ENDIAN=y" && echo "$enableKconfig" ) > .config
      make V=1 olddefconfig
    '';

    buildPhase = ''
      make vmlinux
      objcopy -O binary -R .reginfo -R .notes -R .note -R .comment -R .mdebug -R .note.gnu.build-id -S vmlinux vmlinux.stripped
      objdump -h vmlinux |grep '.text'
      objdump -f vmlinux |grep start
      cc -o scripts/patch-dtb ${ledeSrc}/tools/patch-image/src/patch-dtb.c
      cpp -nostdinc -x assembler-with-cpp -Iarch/mips/boot/dts -Iarch/mips/boot/dts/include -Iinclude/ -undef -D__DTS__  -o dtb.tmp ${ledeSrc}/target/linux/ramips/dts/GL-MT300A.dts
      scripts/dtc/dtc -O dtb -i${ledeSrc}/target/linux/ramips/dts/  -o vmlinux.dtb dtb.tmp
      scripts/patch-dtb vmlinux.stripped vmlinux.dtb
      rm -f vmlinux.lzma
      ${lzma}/bin/lzma -k -z  vmlinux.stripped
      mkimage -A mips -O linux -T kernel -C lzma -a 0x80000000 -e 0x80000000 -n 'MIPS NixWrt Linux' -d vmlinux.stripped.lzma kernel.image
    '';

    installPhase = ''
      mkdir -p $out
      cp vmlinux kernel.image $out/
      ${if wantModules then "make modules_install INSTALL_MOD_PATH=$out" else ""}
    '';

    shellHook = ''
      export ledeSrc=${ledeSrc}
    '';
  }
