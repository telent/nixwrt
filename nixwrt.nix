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
   nocheck = d : onTheHost.lib.overrideDerivation d (a: {
    doCheck = stdenv.buildPlatform == stdenv.hostPlatform;
    })  ;
in with onTheHost; rec {
  hello = (nocheck pkgs.hello);

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
      make vmlinux V=1 NM=${NM} AR=${AR} OBJCOPY=${OBJCOPY} OBDUMP=${OBJDUMP}
      make modules V=1 NM=${NM} AR=${AR} OBJCOPY=${OBJCOPY}
    '';
    installPhase = ''
      mkdir -p $out
      cp vmlinux $out/
      make modules_install INSTALL_MOD_PATH=$out
    '';

    
  };
  zlib_ = lib.overrideDerivation pkgs.zlib (attrs: {
    CC = "${targetPlatform.config}-cc";
    AR = "${targetPlatform.config}-ar";    
    hardeningDisable = [ "all" ];
  });
  rsync = pkgs.rsync.override {
    zlib = zlib_;
    enableACLs = false;
  };
  image = let inputs = [ kernel pkgs.busybox rsync ] ;
                  
   in stdenv.mkDerivation {
    name = "nixwrt-root";
    phases = [ "buildPhase" ];
    nativeBuildInputs = [ buildPackages.squashfsTools ];
    buildPhase = '' 
    mkdir -p $out
    date >> $out/CREATED
    # mksquashfs is unhelpful here; this copies /nix/store/xyz to /xyz
    ${lib.concatMapStrings (n: "mksquashfs  ${n} $out/image.squashfs -all-root -keep-as-directory\n") inputs}
    # so we need to graft it back to /nix/store/xyz
    mkdir $out/sbin
    ln -s ${pkgs.busybox}/bin/busybox $out/sbin/init
    mksquashfs $out/sbin $out/CREATED /$out/image.squashfs  -root-becomes nix/store
    chmod a+r $out/image.squashfs
    '';
  };
  acl = pkgs.acl;
}

