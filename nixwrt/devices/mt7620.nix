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
    inherit (nixpkgs) stdenv lib buildPackages writeText runCommand;
  };
  modloaderservice = ralink.module_loader {
    inherit vmlinux;
    kconfig = {
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
      "WLAN_VENDOR_RALINK"="y";
    };
    module_paths = [
      "net/wireless/cfg80211.ko"
      "net/mac80211/mac80211.ko"
      "drivers/net/wireless/ralink/rt2x00/rt2x00lib.ko"
      "drivers/net/wireless/ralink/rt2x00/rt2x00mmio.ko"
      "drivers/net/wireless/ralink/rt2x00/rt2x00soc.ko"
      "drivers/net/wireless/ralink/rt2x00/rt2800lib.ko"
      "drivers/net/wireless/ralink/rt2x00/rt2800mmio.ko"
      "drivers/net/wireless/ralink/rt2x00/rt2800soc.ko"
    ];
  };
  firmware = nixpkgs.stdenv.mkDerivation {
    name = "regdb";
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out/firmware
      cp ${nixpkgs.wireless-regdb}/lib/firmware/regulatory.db* $out/firmware
    '';
  };
in nixpkgs.lib.attrsets.recursiveUpdate super {
  services.modloader = modloaderservice;
  busybox.applets = super.busybox.applets ++ [ "insmod" "lsmod" "modinfo" ];
  kernel = rec {
    inherit vmlinux;
    inherit (ralink) tree;
    config =
      (kb.readDefconfig "${ralink.openwrtKernelFiles}/generic/config-5.4") //
      (kb.readDefconfig "${ralink.openwrtKernelFiles}/ramips/mt7620/config-5.4") //
      extraConfig;
    inherit firmware;
    package =
      let fdt = kb.makeFdt {
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
        extraName = "mt7620";
        inherit (nixpkgs) patchImage stdenv;
        inherit (nixpkgs.buildPackages) lzma ubootTools;
      };
  };
  boot = {
    loadAddress = "0x80000000";
    entryPoint = "0x80000000";
    phramBaseAddress = "0xa00000";
    commandLine = "earlyprintk=serial,ttyS0 console=ttyS0,115200 panic=10 oops=panic init=/bin/init loglevel=8 rootfstype=squashfs";
  };
}
