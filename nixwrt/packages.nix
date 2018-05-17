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
  busybox = import ./busybox.nix {
    inherit stdenv pkgs;
    applets = [
      "blkid"
      "cat"
      "chmod"
      "chown"
      "cp"
      "dd"
      "df"
      "dmesg"
      "du"
      "find"
      "grep"
      "gzip"
      "init"
      "kill"
      "ls"
      "mdev"
      "mkdir"
      "mount"
      "mv"
      "nc"
      "ntpd"
      "ping"
      "ps"
      "reboot"
      "route"
      "rm"
      "rmdir"
      "stty"
      "syslogd"
      "tar"
      "udhcpc"
      "umount"
      "zcat"
    ];
  };

  rootfsImage = pkgs.callPackage ./rootfs-image.nix ;

}
