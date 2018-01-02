# reminder: counterintuitive system naming
#  the Build is the machine we are building a program on
#  the Host is the machine that will run the program
#  if the program generates code, the Target is the machine that the program
#    will generate code for
#
# For example, 
#
# * we require an `ar` that runs on x86-64 linux and generates mips
#    code, build=x86-64, host=x86-64, target=mips
#
# * we need a busybox that runs on the end-user device, 
#    build=x86-64, host=mips, target is not relevant

let onTheBuild = import ./default.nix {} ;
    mkPlatform = name : baseConfig : {
      uboot = null;
      name = name;
      kernelArch = "mips";
      kernelBaseConfig = baseConfig;
      kernelHeadersBaseConfig = baseConfig;
      kernelTarget = "uImage";
      gcc = { abi = "32"; } ;
      kernelAutoModules = false;
      kernelModules = false;      
      kernelPreferBuiltin = true;
      bfdEmulation = "elf32btsmip";
    };
    onTheHost = import ./default.nix {
      crossSystem = rec {
        system = "mips-linux-gnu";
        openssl.system = "linux-generic32";
        withTLS = true;
        inherit (platform) gcc;
        # libc = "uclibc";
        # float = "soft" ;
        platform = # (mkPlatform "malta" "malta_defconfig");
          (mkPlatform "ath79" "ath79_defconfig");
      };
   };
   stdenv = onTheHost.stdenv;
in with onTheHost; rec {
  kernel = stdenv.mkDerivation rec {
    name = "nixwrt_kernel";
    src = onTheBuild.fetchurl {
      url = "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.14.1.tar.xz";
      sha256 = "1rsdrdapjw8lhm8dyckwxfihykirbkincm5k0lwwx1pr09qgdfbg";
    };
    hardeningDisable = ["all"];
    nativeBuildInputs = [onTheBuild.pkgs.bc
     lzmaLegacy onTheBuild.stdenv.cc
     onTheBuild.pkgs.ubootTools];
    CC = "${stdenv.cc.bintools.targetPrefix}gcc";
    HOSTCC = "gcc";
    CROSS_COMPILE = stdenv.cc.bintools.targetPrefix;
    ARCH = "mips";
    dontStrip = true;
    dontPatchELF = true;
    enableKconfig = builtins.concatStringsSep "\n" (map (n : "CONFIG_${n}=y") [
      "NFS_FS"
      "IP_PNP"
      "ROOT_NFS"
      "MODULES"
      "SQUASHFS"
      "SQUASHFS_XZ"      
      "MTD_PHRAM"]);
    configurePhase = ''
      substituteInPlace scripts/ld-version.sh --replace /usr/bin/awk ${onTheBuild.pkgs.gawk}/bin/awk
      make V=1 mrproper
      ( cat arch/mips/configs/ath79_defconfig && echo "$enableKconfig" ) > .config
      make V=1 olddefconfig 
    '';
    # we need to invoke the lzma command with a filename (not stdin),
    # so that we get an archive that's not "streamed".  I know it
    # looks like we're building the whole thing twice: the makefile is
    # smart enough to only rebuild missing targets, but also Too Smart
    # in that it rebuilds vmlinux.bin.lzma (incorrectly, from stdin)
    # if the make command line changed
    buildPhase = ''
      make uImage.lzma modules V=1 
      rm arch/mips/boot/uImage.lzma || true
      ${lzmaLegacy}/bin/lzma -v -v -c -6 arch/mips/boot/vmlinux.bin >  arch/mips/boot/vmlinux.bin.lzma
      ls -lart arch/mips/boot/
      make uImage.lzma modules V=1 
    '';
    installPhase = ''
      mkdir -p $out
      cp arch/mips/boot/uImage.lzma $out/
      make modules_install INSTALL_MOD_PATH=$out
    '';
  };

  # build real lzma instead of using xz, because the lzma decoder in
  # u-boot doesn't understand streaming lzma archives ("Stream with
  # EOS marker is not supported") and xz can't create non-streaming
  # ones.
  # See https://sourceforge.net/p/squashfs/mailman/message/26599379/
  
  lzmaLegacy = onTheBuild.stdenv.mkDerivation {
    name = "lzma";
    version = "4.32.7";
    # workaround for "forbidden reference to /tmp" message which will one
    # day be fixed by a new patchelf release
    # https://github.com/NixOS/nixpkgs/commit/cbdcc20e7778630cd67f6425c70d272055e2fecd
    preFixup = ''rm -rf "$(pwd)" && mkdir "$(pwd)" '';
    srcs = onTheBuild.fetchurl {
      url = "https://tukaani.org/lzma/lzma-4.32.7.tar.gz";
      sha256 = "0b03bdvm388kwlcz97aflpr3ir1zpa3m0bq3s6cd3pp5a667lcwz";
    };
  };

  rsync = pkgs.rsync.override {
    enableACLs = false;
  };
  
  busybox = let bb = pkgs.busybox.override {
    enableStatic = true;
    enableMinimal = true;
    extraConfig = ''
      CONFIG_ASH y
      CONFIG_ASH BUILTIN_ECHO y
      CONFIG_ASH_BUILTIN_TEST y
      CONFIG_ASH_OPTIMIZE_FOR_SIZE y
      CONFIG_LS y
      CONFIG_FIND y
      CONFIG_GREP y
    '';
  }; in lib.overrideDerivation bb (a: {
    LDFLAGS = "-L${stdenv.cc.libc.static}/lib";
  });  
  squashfs = import ./nixos/lib/make-squashfs.nix {  
    inherit (onTheBuild.pkgs) perl pathsFromGraph squashfsTools;
    stdenv = onTheHost.stdenv;
    storeContents = [ # kernel
    busybox
    rsync
     ] ;
    compression = "gzip";       # probably should use lz4 or lzo, but need 
    compressionFlags = "";      # to rebuild kernel & squashfs-tools for that
  };
  image = stdenv.mkDerivation rec {
    name = "nixwrt-root";
    deviceNodes = writeText "devicenodes.txt" ''
      /dev d 0755 root root
      /var d 0755 root root
      /dev/console c 0600 root root 5 1
      /dev/ttyS0 c 0777 root root 4 64
      /dev/ttyATH0 c 0777 root root 252 0
      /dev/tty c 0777 root root 5 0
      /dev/full c 0666 root root 1 7
      /dev/zero c 0666 root root 1 5
      /dev/null c 0666 root root 1 3
      /dev/sda b 0660 root root 8 0
      /dev/sda1 b 0660 root root 8 1
      /dev/sr0 b 0660 root root 11 0
    '';
    phases = [ "buildPhase" ];
    nativeBuildInputs = [ buildPackages.squashfsTools ];
    buildPhase = ''
    mkdir -p $out/sbin $out/bin $out/nix/store
    touch $out/.empty
    cp ${busybox}/bin/busybox $out/bin/busybox
    cp ${busybox}/bin/busybox $out/bin/sh
    cp ${busybox}/bin/busybox $out/bin/ls
    # mksquashfs has the unhelpful (for us) property that it will
    # copy /nix/store/$xyz as /$xyz in the image
    cp ${squashfs} $out/image.squashfs
    chmod +w $out/image.squashfs
    # so we need to graft all the directories in the image back onto /nix/store
    mksquashfs $out/.empty $out/image.squashfs -root-becomes store
    mksquashfs $out/sbin $out/bin $out/image.squashfs  \
     -root-becomes nix -pf ${deviceNodes} 
    chmod a+r $out/image.squashfs
    '';
  };
  tftproot = stdenv.mkDerivation rec {
    name = "uImage";
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out
      cp ${kernel}/uImage.lzma  $out/kernel.image
      cp ${image}/image.squashfs  $out/rootfs.image
    '';
  };
}
