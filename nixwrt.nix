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
   sshHostKey = ./ssh_host_key;
   sshAuthorizedKeys = stdenv.lib.strings.splitString "\n" ( builtins.readFile "/etc/ssh/authorized_keys.d/dan" );
   
in with onTheHost; rec {
  dropbearHostKey = runCommand "makeHostKey" { preferLocalBuild = true; } ''
   ${onTheBuild.pkgs.dropbear}/bin/dropbearconvert openssh dropbear ${sshHostKey} $out
  '';
    
  kernel = import ./kernel.nix {
    stdenv = stdenv;
    lzma = lzmaLegacy;
    onTheBuild = onTheBuild;
    targetPlatform = targetPlatform;
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
  
  busybox = import ./busybox.nix {
    stdenv = stdenv; pkgs = pkgs;
    applets = [
      "cat"
      "dmesg"
      "find"
      "grep"
      "gzip"
      "ifconfig"
      "init"
      "kill"
      "ls"
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
    
  squashfs = import ./nixos/lib/make-squashfs.nix {  
    inherit (onTheBuild.pkgs) perl pathsFromGraph squashfsTools;
    stdenv = onTheHost.stdenv;
    storeContents = [ 
    busybox
    monit
    dropbear
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
           "/etc/${name} f ${s.mode} ${s.owner} ${s.group} echo -n \"${c}\" |qprint -d")
      { 
        monitrc = {
          mode = "0400";
          content = import ./monitrc.nix {
            lib = lib;
            interfaces.wired = {
              device = "eth1";
              address = "192.168.0.251";
              defaultRoute = "192.168.0.254";
            };
            services = {
              dropbear = {
                start = "${pkgs.dropbear}/bin/dropbear -s -P /run/dropbear.pid";
                depends = [ "wired"];
              };
              syslogd = { start = "/bin/syslogd -R 192.168.0.2"; 
                          depends = ["wired"]; };
              ntpd =  { start = "/bin/ntpd -p pool.ntp.org" ;
                        depends = ["wired"]; };
            };
          };
        };
        hosts = {content = "127.0.0.1 localhost\n"; };
        fstab = {content = ''
          proc /proc proc defaults 0 0
          tmpfs /tmp tmpfs rw 0 0
          tmpfs /run tmpfs rw 0 0
          sysfs /sys sysfs defaults 0 0
          devtmpfs /dev devtmpfs defaults 0 0
          #devpts /dev/pts devpts noauto 0 0          
        '';};
        "resolv.conf" = { content = ( lib.readFile "/etc/resolv.conf" );};
        passwd = {content = ''
          root:x:0:0:System administrator:/root:/bin/sh
        '';};
        inittab = {content = ''
          ::askfirst:-/bin/sh
          ::sysinit:/etc/rc
          ::respawn:${monit}/bin/monit -I -c /etc/monitrc
        '';};
        rc = {mode="0755"; content = ''
          #!${busybox}/bin/sh
          stty sane < /dev/console
          mount -a
          mkdir /dev/pts
          mount -t devpts none /dev/pts
        '';};

      }; in
      writeText "pseudo-etc.txt" ( "/etc d 0755 root root\n" + (builtins.concatStringsSep "\n" lines));

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
      /etc/dropbear d 0700 root root
      /etc/dropbear/dropbear_rsa_host_key f 0600 root root cat ${dropbearHostKey} 
      /root/.ssh/authorized_keys f 0600 root root echo -e "${builtins.concatStringsSep newline sshAuthorizedKeys}"
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
