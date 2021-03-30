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
  firmwareBlobs = nixpkgs.fetchFromGitHub {
    owner = "kvalo";
    repo = "ath10k-firmware";
    rev = "5d63529ffc6e24974bc7c45b28fd1c34573126eb";
    sha256 = "1bwpifrwl5mvsmbmc81k8l22hmkwk05v7xs8dxag7fgv2kd6lv2r";
  };
  listFiles = dir: builtins.attrNames (builtins.readDir dir);
  extraConfig = {
    "BLK_DEV_INITRD" = "n";
    "CMDLINE_PARTITION" = "y";
    "DEBUG_INFO" = "y";
    "DEVTMPFS" = "y";
    "EARLY_PRINTK" = "y";
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

    "ASN1" = "y";
    "ASYMMETRIC_KEY_TYPE" = "y";
    "ASYMMETRIC_PUBLIC_KEY_SUBTYPE" = "y";
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
    "ENCRYPTED_KEYS" = "y";
    "KEYS" = "y";
  };
  checkConfig = { };
  tree = kb.patchSourceTree {
    inherit upstream openwrt;
    inherit (nixpkgs) buildPackages patchutils stdenv lib;
    version = kernelVersion;
    patches = lists.flatten
      [ "${openwrtKernelFiles}/ath79/patches-5.4/"
        "${openwrtKernelFiles}/generic/backport-5.4/"
        "${openwrtKernelFiles}/generic/pending-5.4/"
        (map (n: "${openwrtKernelFiles}/generic/hack-5.4/${n}")
          (builtins.filter
            (n: ! (strings.hasPrefix "230-" n))
            (listFiles "${openwrtKernelFiles}/generic/hack-5.4/")))
        ../kernel/552-ahb_of.patch
      ];
    files = [ "${openwrtKernelFiles}/generic/files/"
              "${openwrtKernelFiles}/ath79/files/"
            ];
  };
  vmlinux = kb.makeVmlinux {
    inherit tree ;
    inherit (self.kernel) config;
    checkedConfig = checkConfig // extraConfig;
    inherit (nixpkgs) stdenv buildPackages writeText runCommand;
  };

  modules = (import ../kernel/make-backport-modules.nix) {
    inherit (nixpkgs) stdenv lib buildPackages runCommand writeText;
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
      "ATH9K_AHB" = "y";
      "ATH9K_DEBUGFS" = "m";
      "ATH_DEBUG" = "y";
      "ATH10K" = "m";
      "ATH10K_AHB" = "m";
      "ATH10K_PCI" = "m";
      "ATH10K_DEBUG" = "y";
      "CFG80211"="m";
      # can't get signed regdb to work rn, it just gives me
      # "loaded regulatory.db is malformed or signature is
      # missing/invalid"
      "CFG80211_REQUIRE_SIGNED_REGDB" = "n";
      # I am reluctant to have to enable this but can't transmit on
      # 5GHz bands without it (they are all marked NO-IR)
      "CFG80211_CERTIFICATION_ONUS" = "y";
      "CFG80211_DEBUGFS" = "y";
      "CFG80211_WEXT"="n";
      "CFG80211_CRDA_SUPPORT" = "n";

      "CRYPTO_ARC4" = "y";
      "MAC80211"="m";
      "MAC80211_LEDS"="y";
      "MAC80211_MESH"="y";
      "REQUIRE_SIGNED_REGDB" = "n";
      "WLAN"="y";
      "WLAN_VENDOR_ATH"="y";
    };
  };
  firmware = nixpkgs.stdenv.mkDerivation {
    name = "regdb";
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out/firmware/ath10k/QCA9887/hw1.0/
      cp ${nixpkgs.wireless-regdb}/lib/firmware/regulatory.db* $out/firmware
      blobdir=${firmwareBlobs}/QCA9887/hw1.0
      cp $blobdir/10.2.4-1.0/firmware-5.bin_10.2.4-1.0-00047 $out/firmware/ath10k/QCA9887/hw1.0/firmware-5.bin
      cp ${./ar750-ath10k-cal.bin} $out/firmware/ath10k/cal-pci-0000:00:00.0.bin
      cp $blobdir/board.bin  $out/firmware/ath10k/QCA9887/hw1.0/
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
      insmod drivers/net/wireless/ath/ath.ko
      insmod drivers/net/wireless/ath/ath10k/ath10k_core.ko
      insmod drivers/net/wireless/ath/ath10k/ath10k_pci.ko
      insmod drivers/net/wireless/ath/ath9k/ath9k_hw.ko
      insmod drivers/net/wireless/ath/ath9k/ath9k_common.ko
      insmod drivers/net/wireless/ath/ath9k/ath9k.ko debug=0xffffffff
    ''; in "${s}/bin/load-modules.sh";
  };
in nixpkgs.lib.attrsets.recursiveUpdate super {
  packages = ( if super ? packages then super.packages else [] )
             ++ [modules];
  services.modloader = modloaderservice;
  busybox.applets = super.busybox.applets ++ [ "insmod" "lsmod" "modinfo" ];
  kernel = rec {
    inherit vmlinux tree firmware;
    config =
      (kb.readDefconfig "${openwrtKernelFiles}/generic/config-5.4") //
      (kb.readDefconfig "${openwrtKernelFiles}/ath79/config-5.4") //
      extraConfig;
    package =
      let fdt = kb.makeFdt {
            dts = options.dts {inherit openwrt;};
            inherit (nixpkgs) stdenv;
            inherit (nixpkgs.buildPackages) dtc;
            inherit (self.boot) commandLine;
            includes = [
              "${openwrtKernelFiles}/ath79/dts"
              "${tree}/arch/mips/boot/dts"
              "${tree}/arch/mips/boot/dts/include"
              "${tree}/include/"];
          };
      in kb.makeUimage {
        inherit vmlinux fdt;
        inherit (self.boot) entryPoint loadAddress commandLine;
        extraName = "ath79";
        inherit (nixpkgs) patchImage stdenv;
        inherit (nixpkgs.buildPackages) lzma ubootTools;
      };
  };
  boot = {
    loadAddress = "0x80060000";
    entryPoint  = "0x80060000";
    commandLine = "earlyprintk=serial,ttyATH0 console=ttyS0,115200 panic=10 oops=panic init=/bin/init loglevel=8 rootfstype=squashfs";
  };
}
