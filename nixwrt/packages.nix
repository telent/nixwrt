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

{ pkgs, stdenv, buildPackages, ... }:
rec {
  swconfig = { kernel, ...} : stdenv.mkDerivation {
    src = buildPackages.fetchFromGitHub {
      owner = "jekader";
      repo = "swconfig";
      rev = "66c760893ecdd1d603a7231fea9209daac57b610";
      sha256 = "0hi2rj1a1fbvr5n1090q1zzigjyxmn643jzrwngw4ij0g82za3al";
    };
    name = "swconfig";
    buildInputs = [ buildPackages.pkgconfig ];
    nativeBuildInputs = [ kernel pkgs.libnl ];
    CFLAGS="-O2 -I${kernel}/include -I${pkgs.libnl.dev}/include/libnl3";
    LDFLAGS="-L${pkgs.libnl.lib}/lib";

    buildPhase = ''
      echo ${buildPackages.pkgconfig}
      make swconfig
      $STRIP swconfig
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp swconfig $out/bin
    '';
  };

  kernel = pkgs.callPackage ./kernel/default.nix ;

  # build real lzma instead of using xz, because the lzma decoder in
  # u-boot doesn't understand streaming lzma archives ("Stream with
  # EOS marker is not supported") and xz can't create non-streaming
  # ones.
  # See https://sourceforge.net/p/squashfs/mailman/message/26599379/

  lzmaLegacy = buildPackages.stdenv.mkDerivation {
    name = "lzma";
    version = "4.32.7";
    # workaround for "forbidden reference to /tmp" message which will one
    # day be fixed by a new patchelf release
    # https://github.com/NixOS/nixpkgs/commit/cbdcc20e7778630cd67f6425c70d272055e2fecd
    preFixup = ''rm -rf "$(pwd)" && mkdir "$(pwd)" '';
    srcs = buildPackages.fetchurl {
      url = "https://tukaani.org/lzma/lzma-4.32.7.tar.gz";
      sha256 = "0b03bdvm388kwlcz97aflpr3ir1zpa3m0bq3s6cd3pp5a667lcwz";
    };
  };

  busybox = import ./busybox.nix {
    inherit stdenv pkgs;
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

  rootfsImage = pkgs.callPackage ./rootfs-image.nix ;

}
