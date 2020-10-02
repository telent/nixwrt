options: nixpkgs: self: super:
with nixpkgs.lib;
let
  ralink = (import ./ralink.nix { inherit nixpkgs; inherit (self) nixwrt; });
  kb = self.nixwrt.kernel;
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
    tree = ralink.tree;
    config =
      (kb.readDefconfig "${ralink.openwrtKernelFiles}/generic/config-5.4") //
      (kb.readDefconfig "${ralink.openwrtKernelFiles}/ramips/mt76x8/config-5.4") //
      extraConfig;

    package =
      let vmlinux = kb.makeVmlinux {
            inherit tree ;
            inherit (self.kernel) config;
            checkedConfig = checkConfig // extraConfig;
            inherit (nixpkgs) stdenv buildPackages writeText runCommand;
          };
          fdt = kb.makeFdt {
            dts = options.dts {inherit (ralink) openwrt;};
            inherit (nixpkgs) stdenv;
            inherit (nixpkgs.buildPackages) dtc;
            inherit (self.boot) commandLine;
            includes = [
              "${ralink.openwrtKernelFiles}/ramips/dts"
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
