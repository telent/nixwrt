options: nixpkgs: self: super:
with nixpkgs.lib;
let
  ralink = (import ./ralink.nix { inherit nixpkgs; inherit (self) nixwrt; });
  kb = self.nixwrt.kernel;
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
  vmlinux = kb.makeVmlinux {
    inherit (ralink) tree ;
    inherit (self.kernel) config;
    checkedConfig = checkConfig // extraConfig;
    inherit (nixpkgs) stdenv buildPackages writeText runCommand;
  };
  modules = (import ../kernel/make-backport-modules.nix) {
    inherit (nixpkgs) stdenv buildPackages runCommand writeText;
    openwrtSrc = ralink.openwrt;
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
      "CFG80211"="m";
      "CFG80211_WEXT"="n";
      "CRYPTO_ARC4" = "y";
      "MAC80211"="m";
      "MAC80211_LEDS"="y";
      "MAC80211_MESH"="y";
      "MT7603E" = "y";
      "REQUIRE_SIGNED_REGDB" = "n";
      "WLAN"="y";
      "WLAN_VENDOR_RALINK"="y";
      "WLAN_VENDOR_MEDIATEK"="y";
    };
  };
  firmware = nixpkgs.fetchurl {
    url = "https://github.com/openwrt/mt76/raw/8167074dab20b4f434f882b3ceb737bc953c2f61/firmware/mt7628_e2.bin";
    sha256 = "1dkhfznmdz6s50kwc841x3wj0h6zg6icg5g2bim9pvg66as2vmh9";
  };
  regulatory = nixpkgs.stdenv.mkDerivation {
    name = "regdb";
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out/firmware
      cp ${nixpkgs.wireless-regdb}/lib/firmware/regulatory.db* $out/firmware
      cp ${firmware} $out/firmware/mt7628_e2.bin
      ( cd $out/firmware && find .)
    '';
  };
  modloaderservice = {
    type = "oneshot";
    start = let s= nixpkgs.writeScriptBin "load-modules.sh" ''
      #!${nixpkgs.busybox}/bin/sh
      cd ${modules}
      insmod ./compat/compat.ko
      insmod ./net/wireless/cfg80211.ko
      insmod ./net/mac80211/mac80211.ko
      insmod ./drivers/net/wireless/mediatek/mt76/mt76.ko
      insmod ./drivers/net/wireless/mediatek/mt76/mt7603/mt7603e.ko
   ''; in "${s}/bin/load-modules.sh";
  };

in nixpkgs.lib.attrsets.recursiveUpdate super {
  packages = ( if super ? packages then super.packages else [] )
             ++ [modules regulatory];
  services.modloader = modloaderservice;
  busybox.applets = super.busybox.applets ++ [ "insmod" "lsmod" "modinfo" ];
  kernel = rec {
    firmware = regulatory;
    inherit (ralink) tree;
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
