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

platform: config:
let onTheBuild = import ../default.nix {} ;
    onTheHost = import ../default.nix {
      crossSystem = rec {
        system = "mips-linux-gnu";
        openssl.system = "linux-generic32";
        withTLS = true;
        inherit (platform) gcc;
        inherit platform;
      };
   };
   stdenv = onTheHost.stdenv;
   mkPseudoFile = import ./pseudofile.nix onTheHost;
   configuration = config onTheHost;
in with onTheHost; rec {
  dropbearHostKey = runCommand "makeHostKey" { preferLocalBuild = true; } ''
   ${onTheBuild.pkgs.dropbear}/bin/dropbearconvert openssh dropbear ${configuration.services.dropbear.hostKey} $out
  '';
    
  kernel = import ./kernel {
    stdenv = stdenv;
    lzma = lzmaLegacy;
    onTheBuild = onTheBuild;
    targetPlatform = platform;
    kconfig = configuration.kernel.enableKconfig;
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

  busybox = import ./busybox.nix {
    stdenv = stdenv; pkgs = pkgs;
    applets = [
      "blkid"
      "cat"
      "dmesg"
      "find"
      "grep"
      "gzip"
      "ifconfig"
      "init"
      "kill"
      "ls"
      "mdev"
      "mkdir"
      "mount"
      "ntpd"
      "ping"
      "ps"
      "reboot"
      "route"
      "stty"
      "syslogd"
      "udhcpc"
      "umount"
    ];
  };
  
  monit = pkgs.monit.override { usePAM = false; openssl = null; };
    
  squashfs = import ../nixos/lib/make-squashfs.nix {  
    inherit (onTheBuild.pkgs) perl pathsFromGraph squashfsTools;
    inherit stdenv;
    storeContents = configuration.packages ++ [ 
      busybox
      monit
      dropbear
    ];
    compression = "gzip";       # probably should use lz4 or lzo, but need 
    compressionFlags = "";      # to rebuild squashfs-tools for that
  };
  image = stdenv.mkDerivation rec {
    name = "nixwrt-root";

    pseudoEtc = mkPseudoFile "pseudo-etc.txt" "/etc/" ({
      monitrc = {
        mode = "0400";
        content = import ./monitrc.nix {
          lib = lib;
          inherit (configuration) interfaces services filesystems;
        };
      };
      group = {content = ''
        root:!!:0:
      '';};
      hosts = {content = "127.0.0.1 localhost\n"; };
      fstab = {
        content = (import ./fstab.nix stdenv) configuration.filesystems;
      };
      passwd = {content = (import ./mkpasswd.nix stdenv) configuration.users; };
      inittab = {content = ''
        ::askfirst:-/bin/sh
        ::sysinit:/etc/rc
        ::respawn:${monit}/bin/monit -I -c /etc/monitrc
      '';};
      "mdev.conf" = { content = ''
        -[sh]d[a-z] 0:0 660 @${monit}/bin/monit start vol_\$MDEV
        [sh]d[a-z] 0:0 660 $/usr/bin/env ${monit}/bin/monit stop vol_\$MDEV
      ''; };
      rc = {mode="0755"; content = ''
        #!${busybox}/bin/sh
        stty sane < /dev/console
        mount -a
        mkdir /dev/pts
        mount -t devpts none /dev/pts
        echo /bin/mdev > /proc/sys/kernel/hotplug
        mdev -s
      '';};

    } // configuration.etc) ;

    # only need enough in /dev to get us to where we can mount devtmpfs,
    # this can probably be pared down
    pseudoDev = let newline = "\\n"; in writeText "pseudo-dev.txt" ''
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
      ${lib.strings.concatStringsSep "\n"
         (lib.attrsets.mapAttrsToList (n: a: "${n} d 0755 root root")
           configuration.filesystems)}
      /etc/dropbear d 0700 root root
      /etc/dropbear/dropbear_rsa_host_key f 0600 root root cat ${dropbearHostKey} 
      /root/.ssh/authorized_keys f 0600 root root echo -e "${builtins.concatStringsSep newline ((builtins.elemAt configuration.users 0).authorizedKeys) }"
    '';
    phases = [ "installPhase" ];
    nativeBuildInputs = [ buildPackages.qprint buildPackages.squashfsTools ];
    installPhase =  ''
    mkdir -p $out/sbin $out/bin $out/nix/store 
    touch $out/.empty
    ( cd $out/bin; for i in ${busybox}/bin/* ; do ln -s $i . ; done )
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
