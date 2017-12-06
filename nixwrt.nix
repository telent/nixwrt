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
    onTheHost = import ./default.nix {
  crossSystem = rec {
    system = "mipsel-linux-gnu";
    openssl.system = "linux-generic32";
    withTLS = true;
    inherit (platform) gcc;
    # libc = "uclibc";
    # float = "soft" ;
    platform = {
      uboot = null;
      name = "malta";
      kernelArch = "mips";
      kernelBaseConfig = "malta_defconfig";
      kernelHeadersBaseConfig = "malta_defconfig";
      kernelTarget = "uImage";
      gcc = { abi = "32"; } ;
      kernelAutoModules = false;
      kernelModules = false;      
      kernelPreferBuiltin = true;
    };
  };
};
   stdenv = onTheHost.stdenv;
in with onTheHost; rec {
  kernel = onTheBuild.stdenv.mkDerivation rec {
    name = "nixwrt_kernel";
    src = onTheBuild.fetchurl {
      url = "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.14.1.tar.xz";
      sha256 = "1rsdrdapjw8lhm8dyckwxfihykirbkincm5k0lwwx1pr09qgdfbg";
    };
    hardeningDisable = ["all"];
    nativeBuildInputs = [onTheBuild.pkgs.bc buildPackages.binutils];
    CROSS_COMPILE = "${buildPackages.gcc}/bin/mipsel-unknown-linux-gnu-";
    NM = "${buildPackages.binutils}/bin/mipsel-unknown-linux-gnu-nm";
    AR = "${buildPackages.binutils}/bin/mipsel-unknown-linux-gnu-ar";
    OBJCOPY = "${buildPackages.binutils}/bin/mipsel-unknown-linux-gnu-objcopy";
    OBJDUMP = "${buildPackages.binutils}/bin/mipsel-unknown-linux-gnu-objdump";
    ARCH = "mips";
    dontStrip = true;
    dontPatchELF = true;
    preConfigure = ''
      substituteInPlace scripts/ld-version.sh --replace /usr/bin/awk ${onTheBuild.pkgs.gawk}/bin/awk
      make V=1 mrproper
      ( cat arch/mips/configs/malta_defconfig && echo CONFIG_MODULES=y && echo CONFIG_SQUASHFS=y ) > .config
      make V=1 olddefconfig 
    '';
    buildPhase = ''
      make vmlinux modules V=1 NM=${NM} AR=${AR} OBJCOPY=${OBJCOPY} OBDUMP=${OBJDUMP}
    '';
    installPhase = ''
      mkdir -p $out
      cp vmlinux $out/
      make modules_install INSTALL_MOD_PATH=$out
    '';

    
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
    inherit (buildPackages) perl pathsFromGraph squashfsTools;
    stdenv = onTheHost.stdenv;
    storeContents = [ kernel busybox rsync hello ] ;
    compression = "gzip";       # probably should use lz4 or lzo, but need 
    compressionFlags = "";      # to rebuild kernel & squashfs-tools for that
  };
  image = stdenv.mkDerivation rec {
    name = "nixwrt-root";
    deviceNodes = writeText "devicenodes.txt" ''
      /dev d 0755 root root
      /dev/console c 0600 root root 5 1
      /dev/ttyS0 c 0777 root root 4 64
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
    mkdir -p $out/sbin $out/bin $out/nix/store $out/var
    cp ${busybox}/bin/busybox $out/bin/busybox
    cp ${busybox}/bin/busybox $out/bin/sh
    cp ${busybox}/bin/busybox $out/bin/ls
    # mksquashfs has the unhelpful (for us) property that it will
    # copy /nix/store/$xyz as /$xyz in the image
    cp ${squashfs} $out/image.squashfs
    chmod +w  $out/image.squashfs
    # so we need to graft all the directories in the image back onto /nix/store
    mksquashfs $out/var $out/image.squashfs -pf ${deviceNodes} -root-becomes /store/
    mksquashfs $out/sbin $out/bin $out/image.squashfs  \
     -root-becomes /nix
    chmod a+r $out/image.squashfs
    '';
  };
}

