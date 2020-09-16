options: nixpkgs: self: super:
with nixpkgs.lib;
let
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
    "JFFS2_FS" = "n";
    "DEVTMPFS" = "y";
    "BLK_DEV_INITRD" = "n";
    "BLK_DEV_RAM" = "n";
    "CMDLINE_PARTITION" = "y";
  };
  checkConfig = { };
in nixpkgs.lib.attrsets.recursiveUpdate super {
  kernel = rec {
    tree = kb.patchSourceTree {
      inherit upstream openwrt;
      inherit (nixpkgs) buildPackages patchutils stdenv;
      version = kernelVersion;
      patches = lists.flatten
        [ "${openwrtKernelFiles}/ramips/patches-5.4/"
          "${openwrtKernelFiles}/generic/backport-5.4/"
          "${openwrtKernelFiles}/generic/pending-5.4/"
          (map (n: "${openwrtKernelFiles}/generic/hack-5.4/${n}")
            (builtins.filter
              (n: ! (strings.hasPrefix "230-" n))
              (listFiles "${openwrtKernelFiles}/generic/hack-5.4/")))
        ];
      files = [ "${openwrtKernelFiles}/generic/files/"
                "${openwrtKernelFiles}/ramips/files/"
                "${openwrtKernelFiles}/ramips/files-5.4/"
              ];
    };
    config =
      (kb.readDefconfig "${openwrtKernelFiles}/generic/config-5.4") //
      (kb.readDefconfig "${openwrtKernelFiles}/ramips/mt76x8/config-5.4") //
      extraConfig;

    package =
      let vmlinux = kb.makeVmlinux {
            inherit tree ;
            inherit (self.kernel) config;
            checkedConfig = checkConfig // extraConfig;
            inherit (nixpkgs) stdenv buildPackages writeText runCommand;
          };
          fdt = kb.makeFdt {
            dts = options.dts {inherit openwrt;};
            inherit (nixpkgs) stdenv;
            inherit (nixpkgs.buildPackages) dtc;
            inherit (self.boot) commandLine;
            includes = [
              "${openwrtKernelFiles}/ramips/dts"
              "${tree}/arch/mips/boot/dts"
              "${tree}/arch/mips/boot/dts/include"
              "${tree}/include/"];
          };
      in kb.makeUimage {
        inherit vmlinux fdt;
        inherit (self.boot) entryPoint loadAddress commandLine;
        extraName = "mt76x8";
        inherit (nixpkgs) patchImage stdenv;
        inherit (nixpkgs.buildPackages) lzma ubootTools;
      };
  };
  boot = {
    loadAddress = "0x80000000";
    entryPoint = "0x80000000";
    commandLine = "earlyprintk=serial,ttyS0 console=ttyS0,115200 panic=10 oops=panic init=/bin/init loglevel=8 rootfstype=squashfs";
  };
}
