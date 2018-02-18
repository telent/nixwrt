{ stdenv, lzma, onTheBuild, targetPlatform, kconfig ? [] } :
let wantModules = false;
    lib = stdenv.lib; in
stdenv.mkDerivation rec {
    name = "nixwrt_kernel";
    defaultKconfig = [
      "AG71XX"
      "ATH79_DEV_ETH"
      "ATH79_MACH_ARDUINO_YUN"
      "ATH79_WDT"
      "DEVTMPFS"
      "IP_PNP"
      "MODULES"
      "MTD_AR7_PARTS"
      "MTD_CMDLINE_PART"
      "MTD_PHRAM"
      "SQUASHFS"
      "SQUASHFS_XZ"
      "SWCONFIG" # switch config, AG71XX needs register_switch to build
      "TMPFS"
      ];
    src = let
     url = {
       url = "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.9.76.tar.xz";
       sha256 = "1pl7x1fnyhvwbdxgh0w5fka9dyysi74n8lj9fkgfmapz5hrr8axq";
     }; in onTheBuild.fetchurl url;

    prePatch = let ledeSrc = onTheBuild.fetchFromGitHub {
      owner = "lede-project";
      repo = "source";
      rev = "57157618d4c25b3f08adf28bad5b24d26b3a368a";
      sha256 = "0jbkzrvalwxq7sjj58r23q3868nvs7rrhf8bd2zi399vhdkz7sfw";
    }; in ''
      q_apply() {
        find $1 -type f | sort | xargs  -n1 patch -N -p1 -i
      }
      cp -dRv ${ledeSrc}/target/linux/generic/files/* .   # */
      q_apply ${ledeSrc}/target/linux/generic/backport-4.9/
      q_apply ${ledeSrc}/target/linux/generic/pending-4.9/
      q_apply ${ledeSrc}/target/linux/generic/hack-4.9/
      cp -dRv ${ledeSrc}/target/linux/ar71xx/files/* .  # */
      q_apply ${ledeSrc}/target/linux/ar71xx/patches-4.9/
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
      substituteInPlace scripts/ld-version.sh --replace /usr/bin/awk ${onTheBuild.pkgs.gawk}/bin/awk
      make V=1 mrproper
      ( grep -v CONFIG_BLK_DEV_INITRD arch/mips/configs/${targetPlatform.kernelHeadersBaseConfig} && echo "CONFIG_CPU_${lib.strings.toUpper targetPlatform.endian}_ENDIAN=y" && echo "$enableKconfig" ) > .config
      make V=1 olddefconfig 
    '';
    buildPhase = ''
      make uImage.lzma ${if wantModules then "modules" else ""} V=1 LZMA_COMMAND=${lzma}/bin/lzma 
    '';
    installPhase = ''
      mkdir -p $out
      cp vmlinux arch/mips/boot/uImage.lzma $out/
      ${if wantModules then "make modules_install INSTALL_MOD_PATH=$out" else ""}
    '';
  }
