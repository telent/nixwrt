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
    "ASN1" = "y";
    "ASYMMETRIC_KEY_TYPE" = "y";
    "ASYMMETRIC_PUBLIC_KEY_SUBTYPE" = "y";
    "BLK_DEV_INITRD" = "n";
    "BLK_DEV_RAM" = "n";
    "CMDLINE_PARTITION" = "y";
    "CRC_CCITT" = "y";
    "CRYPTO" = "y";
    "CRYPTO_ARC4" = "y";
    "CRYPTO_CBC" = "y";
    "CRYPTO_CCM" = "y";
    "CRYPTO_CMAC" = "y";
    "CRYPTO_GCM" = "y";
    "CRYPTO_HASH_INFO" = "y";
    "CRYPTO_LIB_ARC4" = "y";
    "CRYPTO_RSA" = "y";
    "CRYPTO_SHA1" = "y";
    "DEVTMPFS" = "y";
    "ENCRYPTED_KEYS" = "y";
    "JFFS2_FS" = "n";
    "KEYS" = "y";
    "MODULES" = "y";
    "MODULE_SIG" = "y"; # enable "SYSTEM_DATA_VERIFICATION"
    "MODULE_SIG_ALL" = "y"; # enable "SYSTEM_DATA_VERIFICATION"
    "MODULE_SIG_FORMAT" = "y"; # enable "SYSTEM_DATA_VERIFICATION"
    "MODULE_SIG_SHA1" = "y"; # enable "SYSTEM_DATA_VERIFICATION"
    "PKCS7_MESSAGE_PARSER" = "y";
    "SYSTEM_DATA_VERIFICATION" = "y";
    "SYSTEM_TRUSTED_KEYRING" = "y";
    "WLAN" = "n";
    "X509_CERTIFICATE_PARSER" = "y";
  };
  checkConfig = { };
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
  vmlinux = kb.makeVmlinux {
    inherit tree ;
    inherit (self.kernel) config;
    checkedConfig = checkConfig // extraConfig;
    inherit (nixpkgs) stdenv buildPackages writeText runCommand;
  };
  modules = (import ../kernel/make-backport-modules.nix) {
    inherit (nixpkgs) stdenv buildPackages runCommand writeText;
    openwrtSrc = openwrt;
    backportedSrc =
      nixpkgs.buildPackages.callPackage ../kernel/backport.nix {
        donorTree = nixpkgs.fetchgit {
          url =
            "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git";
          rev = "bcf876870b95592b52519ed4aafcf9d95999bc9c";
          sha256 = "1jffq83jzcvkvpf6afhwkaj0zlb293vlndp1r66xzx41mbnnra0x";
        };
      };
    klibBuild = vmlinux.modulesupport;
    kconfig = {
      "ATH9K"="m";
      "CFG80211"="m";
      "CFG80211_WEXT"="n";
      "CRYPTO_ARC4" = "y";
      "MAC80211"="m";
      "MAC80211_LEDS"="y";
      "MAC80211_MESH"="y";
      "REQUIRE_SIGNED_REGDB" = "n";
      "RT2800SOC" = "m";
      "RT2X00" = "m";
      "WLAN"="y";
      "WLAN_VENDOR_ATH"="y";
      "WLAN_VENDOR_RALINK"="y";
    };
  };
  regulatory = nixpkgs.stdenv.mkDerivation {
    name = "regdb";
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out/firmware
      cp ${nixpkgs.wireless-regdb}/lib/firmware/regulatory.db* $out/firmware
    '';
  };
  modloaderservice = {
    type = "oneshot";
    start = let s= nixpkgs.writeScriptBin "load-modules.sh" ''
      #!${nixpkgs.busybox}/bin/sh
      echo ${regulatory}/firmware/ > /sys/module/firmware_class/parameters/path
      cd ${modules}
      insmod ./compat/compat.ko
      insmod ./net/wireless/cfg80211.ko
      insmod ./net/mac80211/mac80211.ko
      insmod ./drivers/net/wireless/ralink/rt2x00/rt2x00lib.ko
      insmod ./drivers/net/wireless/ralink/rt2x00/rt2x00mmio.ko
      insmod ./drivers/net/wireless/ralink/rt2x00/rt2x00soc.ko
      insmod ./drivers/net/wireless/ralink/rt2x00/rt2800lib.ko
      insmod ./drivers/net/wireless/ralink/rt2x00/rt2800mmio.ko
      insmod ./drivers/net/wireless/ralink/rt2x00/rt2800soc.ko
    ''; in "${s}/bin/load-modules.sh";
  };
in nixpkgs.lib.attrsets.recursiveUpdate super {
  packages = ( if super ? packages then super.packages else [] )
             ++ [modules regulatory];
  services.modloader = modloaderservice;
  busybox.applets = super.busybox.applets ++ [ "insmod" "lsmod" "modinfo" ];
  kernel = rec {
    inherit vmlinux tree;
    config =
      (kb.readDefconfig "${openwrtKernelFiles}/generic/config-5.4") //
      (kb.readDefconfig "${openwrtKernelFiles}/ramips/mt7620/config-5.4") //
      extraConfig;
    package =
      let fdt = kb.makeFdt {
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
        extraName = "mt7620";
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
