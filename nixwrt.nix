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

{ target ? "malta" }: 
let onTheBuild = import ./default.nix {} ;
    targetPlatform = {
      malta = { name = "malta"; endian = "big"; baseConfig = "malta_defconfig"; };
      yun = { name = "yun"; endian = "big";  baseConfig = "ath79_defconfig"; };
    }.${target};
    wantModules = false;
    mkPlatform = { name, endian, baseConfig } : {
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
      bfdEmulation = (if endian=="little" then "elf32ltsmip" else "elf32btsmip");
    };
    onTheHost = import ./default.nix {
      crossSystem = rec {
        system = (if targetPlatform.endian=="little" then "mipsel-linux-gnu" else "mips-linux-gnu" );
        openssl.system = "linux-generic32";
        withTLS = true;
        inherit (platform) gcc;
        # libc = "uclibc";
        # float = "soft" ;
        platform = mkPlatform targetPlatform;
      };
   };
   stdenv = onTheHost.stdenv;
in with onTheHost; rec {
  kernel = stdenv.mkDerivation rec {
    name = "nixwrt_kernel";
    src = let
     url_4_4 = {
       url = "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.4.110.tar.xz";
       sha256 = "0n6v872ahny9j29lh60c7ha5fa1as9pdag7jsb5fcy2nmid1g6fh";
     };
     url_4_9 = {
       url = "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.9.76.tar.xz";
       sha256 = "1pl7x1fnyhvwbdxgh0w5fka9dyysi74n8lj9fkgfmapz5hrr8axq";
     };
     url_4_14 = {
       url ="https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.14.1.tar.xz";
       sha256 = "1rsdrdapjw8lhm8dyckwxfihykirbkincm5k0lwwx1pr09qgdfbg";
     }; in onTheBuild.fetchurl url_4_9;

    prePatch = let ledeSrc = onTheBuild.fetchFromGitHub {
      owner = "lede-project";
      repo = "source";
      rev = "57157618d4c25b3f08adf28bad5b24d26b3a368a";
      sha256 = "0jbkzrvalwxq7sjj58r23q3868nvs7rrhf8bd2zi399vhdkz7sfw";
    }; in ''
      q_apply() {
        find $1 -type f | sort | xargs  -n1 patch -N -p1 -i
      }
      cp -dRv ${ledeSrc}/target/linux/generic/files/* . 
      q_apply ${ledeSrc}/target/linux/generic/backport-4.9/
      q_apply ${ledeSrc}/target/linux/generic/pending-4.9/
      q_apply ${ledeSrc}/target/linux/generic/hack-4.9/
      cp -dRv ${ledeSrc}/target/linux/ar71xx/files/* .
      q_apply ${ledeSrc}/target/linux/ar71xx/patches-4.9/
      chmod -R +w .
    '';   # */ <- this here just to unconfuse emacs nix-mode

    patches = [ ./kernel-ath79-wdt-at-boot.patch
                ./kernel-lzma-command.patch
                ./kernel-memmap-param.patch
                ];
                
    patchFlags = [ "-p1" ];

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
      ]);
    configurePhase = ''
      substituteInPlace scripts/ld-version.sh --replace /usr/bin/awk ${onTheBuild.pkgs.gawk}/bin/awk
      make V=1 mrproper
      ( grep -v CONFIG_BLK_DEV_INITRD arch/mips/configs/${targetPlatform.baseConfig} && echo "CONFIG_CPU_${lib.strings.toUpper targetPlatform.endian}_ENDIAN=y" && echo "$enableKconfig" ) > .config
      make V=1 olddefconfig 
    '';
    buildPhase = ''
      make uImage.lzma ${if wantModules then "modules" else ""} V=1 LZMA_COMMAND=${lzmaLegacy}/bin/lzma 
    '';
    installPhase = ''
      mkdir -p $out
      cp vmlinux arch/mips/boot/uImage.lzma $out/
      ${if wantModules then "make modules_install INSTALL_MOD_PATH=$out" else ""}
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
  
  busyboxApplets = [
    "cat"
    "dmesg"
    "find"
    "grep"
    "gzip"
    "ifconfig"
    "init"
    "ls"
    "mkdir"
    "mount"
    "reboot"
    "stty"
    "udhcpc"
    "umount"
    ];  
  busybox = let bb = pkgs.busybox.override {
    enableStatic = true;
    enableMinimal = true;
    extraConfig = ''
      CONFIG_ASH y
      CONFIG_ASH_ECHO y
      CONFIG_BASH_IS_NONE y
      CONFIG_ASH_BUILTIN_ECHO y
      CONFIG_ASH_BUILTIN_TEST y
      CONFIG_ASH_OPTIMIZE_FOR_SIZE y
      CONFIG_FEATURE_USE_INITTAB y
      '' + builtins.concatStringsSep
              "\n" (map (n : "CONFIG_${lib.strings.toUpper n} y") busyboxApplets);
  }; in lib.overrideDerivation bb (a: {
    LDFLAGS = "-L${stdenv.cc.libc.static}/lib";
  });
  monit = pkgs.monit.override { usePAM = false; openssl = null; };
    
  squashfs = import ./nixos/lib/make-squashfs.nix {  
    inherit (onTheBuild.pkgs) perl pathsFromGraph squashfsTools;
    stdenv = onTheHost.stdenv;
    storeContents = [ 
    busybox
    monit
    rsync
     ] ;
    compression = "gzip";       # probably should use lz4 or lzo, but need 
    compressionFlags = "";      # to rebuild squashfs-tools for that
  };
  image = stdenv.mkDerivation rec {
    name = "nixwrt-root";

    pseudoEtc = let defaults = { mode = "0444"; owner="root"; group="root"; };
                    lines = lib.attrsets.mapAttrsToList
       (name: spec:
         let s = defaults // spec;
             c = builtins.replaceStrings ["\n" "=" "\""] ["=0A" "=3D" "=22"] s.content; in
           "/etc/${name} f ${s.mode} ${s.owner} ${s.group} echo \"${c}\" |qprint -d")
      { 
        monitrc = {mode = "0400"; content = ''
          set init
          set daemon 30
          set httpd port 80
            allow localhost
            allow 192.168.0.0/24
          set idfile /run/monit.id
          set statefile /run/monit.state          
          check host gw address 192.168.0.2
            if failed ping then unmonitor  
          '';};
        hosts = {content = "127.0.0.1 localhost\n"; };
        fstab = {content = ''
          proc /proc proc defaults 0 0
          tmpfs /tmp tmpfs rw 0 0
          tmpfs /run tmpfs rw 0 0
          sysfs /sys sysfs defaults 0 0
          devtmpfs /dev devtmpfs defaults 0 0
        '';};
        passwd = {content = ''
          root:x:0:0:System administrator:/:/bin/sh
        '';};
        inittab = {content = ''
          ::askfirst:-/bin/sh
          ::sysinit:/etc/rc
          ::respawn:${monit}/bin/monit -I -c /etc/monitrc
        '';};
        rc = {mode="0755"; content = ''
          #!${busybox}/bin/sh
          mount -a
        '';};

      }; in
      writeText "pseudo-etc.txt" ( "/etc d 0755 root root\n" + (builtins.concatStringsSep "\n" lines));

    # only need enough in /dev to get us to where we can mount devtmpfs,
    # this can probably be pared down
    pseudoDev = writeText "pseudo-dev.txt" ''
      /dev d 0755 root root
      /dev/console c 0600 root root 5 1
      /dev/null c 0666 root root 1 3
      /dev/tty c 0777 root root 5 0
      /dev/zero c 0666 root root 1 5
      /proc d 0555 root root
      /root d 0700 root root
      /root/.ssh d 0700 root root
      /run d 0755 root root
      /sys d 0555 root root
      /tmp d 1777 root root
      /var d 0755 root root
    '';
    phases = [ "installPhase" ];
    nativeBuildInputs = [ buildPackages.squashfsTools ];
    installPhase =  ''
    mkdir -p $out/sbin $out/bin $out/nix/store 
    touch $out/.empty
    ( cd $out/bin; for i in busybox sh ${builtins.concatStringsSep" "  busyboxApplets} ; do ln -s ${busybox}/bin/busybox $i ; done )
    # mksquashfs has the unhelpful (for us) property that it will
    # copy /nix/store/$xyz as /$xyz in the image
    cp ${squashfs} $out/image.squashfs
    chmod +w $out/image.squashfs
    # so we need to graft all the directories in the image back onto /nix/store
    mksquashfs $out/.empty $out/image.squashfs -root-becomes store
    mksquashfs $out/sbin $out/bin  $out/image.squashfs  \
     -root-becomes nix -pf ${pseudoDev}  -pf ${pseudoEtc} 
    chmod a+r $out/image.squashfs
    '';
  };
  tftproot = stdenv.mkDerivation rec {
    name = "tftproot";
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out
      cp ${kernel}/uImage.lzma  $out/kernel.image
      cp ${kernel}/vmlinux  $out/
      cp ${image}/image.squashfs  $out/rootfs.image
    '';
  };
}
