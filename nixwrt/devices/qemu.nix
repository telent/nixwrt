options: nixpkgs: self: super:
with nixpkgs.lib;
let
  dts = v :"${v}/arch/mips/boot/dts/mti/malta.dts";
  kb = self.nixwrt.kernel;
  openwrt =  nixpkgs.fetchFromGitHub {
    owner = "openwrt";
    repo = "openwrt";
    name = "openwrt-src" ;
    rev = "252197f014932c03cea7c080d8ab90e0a963a281";
    sha256 = "1n30rhg7vwa4zq4sw1c27634wv6vdbssxa5wcplzzsbz10z8cwj9";
  };
  openwrtKernelFiles = "${openwrt}/target/linux";
  kernelVersion = [5 4 64];
  upstream = kb.fetchUpstreamKernel {
    version = kernelVersion;
    sha256 = "1vymhl6p7i06gfgpw9iv75bvga5sj5kgv46i1ykqiwv6hj9w5lxr";
  };
  listFiles = dir: builtins.attrNames (builtins.readDir dir);
  extraConfig = {
    "BLK_DEV_INITRD" = "n";
    "CMDLINE_PARTITION" = "y";
    "DEBUG_INFO" = "y";
    "DEVTMPFS" = "y";
#    "EARLY_PRINTK" = "y";
    "FW_LOADER" = "y";
    # we don't have a user helper, so we get multiple 60s pauses
    # at boot time unless we disable trying to call it
    "FW_LOADER_USER_HELPER" = "n";
    "IMAGE_CMDLINE_HACK" = "n";
    "IP_PNP" = "y";
    "JFFS2_FS" = "n";
    "MIPS_RAW_APPENDED_DTB" = "y";
    "MODULE_SIG" = "y";
    "MTD_CMDLINE_PARTS" = "y";
    "MTD_SPLIT_FIRMWARE" = "y";
    "PARTITION_ADVANCED" = "y";
    "PRINTK_TIME" = "y";
    "SQUASHFS" = "y";
    "SQUASHFS_XZ" = "y";
    "VIRTIO" = "y";
    "VIRTIO_BLK" = "y";
    "VIRTIO_NET" = "y";
    "VIRTIO_PCI" = "y"; # only because VIRTIO can't be enabled without it
  };
  checkConfig = { };
  tree = kb.patchSourceTree {
    inherit upstream openwrt;
    inherit (nixpkgs) buildPackages patchutils stdenv;
    version = kernelVersion;
    patches = lists.flatten
      [ "${openwrtKernelFiles}/generic/backport-5.4/"
        "${openwrtKernelFiles}/generic/pending-5.4/"
        (map (n: "${openwrtKernelFiles}/generic/hack-5.4/${n}")
          (builtins.filter
            (n: ! (strings.hasPrefix "230-" n))
            (listFiles "${openwrtKernelFiles}/generic/hack-5.4/")))
        ../kernel/552-ahb_of.patch
      ];
    files = [ "${openwrtKernelFiles}/generic/files/"
            ];
  };
  vmlinux = kb.makeVmlinux {
    inherit tree ;
    inherit (self.kernel) config;
    checkedConfig = checkConfig // extraConfig;
    inherit (nixpkgs) stdenv buildPackages writeText runCommand;
  };
in nixpkgs.lib.attrsets.recursiveUpdate super {
  packages = ( if super ? packages then super.packages else [] );
  kernel = rec {
    inherit vmlinux tree;
    config =
      (kb.readDefconfig "${openwrtKernelFiles}/generic/config-5.4") //
      (kb.readDefconfig "${openwrtKernelFiles}/malta/config-5.4") //
      extraConfig;
    package =
      let fdt = kb.makeFdt {
            dts = "${tree}/arch/mips/boot/dts/mti/malta.dts";
            inherit (nixpkgs) stdenv;
            inherit (nixpkgs.buildPackages) dtc;
            inherit (self.boot) commandLine;
            includes = [
              "${tree}/arch/mips/boot/dts"
              "${tree}/arch/mips/boot/dts/include"
              "${tree}/include/"];
          };
      in nixpkgs.stdenv.mkDerivation {
        name = "kernel-and-dtb";
        phases = ["installPhase"];
        installPhase = ''
          mkdir -p $out
          cp ${fdt} $out/kernel.dtb
          cp ${vmlinux} $out/vmlinux
        '';
      };
  };
  boot = {
    loadAddress = "0x80060000";
    entryPoint  = "0x80060000";
    commandLine = "earlyprintk=serial,ttyS0 console=ttyS0,38400n8 panic=10 oops=panic init=/bin/init loglevel=8 root=/dev/vda";
  };
}
