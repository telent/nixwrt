let
  readDefconfig = import ./util/read_defconfig.nix;
  kernelSrcLocn = {
    url = "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.9.76.tar.xz";
    sha256 = "1pl7x1fnyhvwbdxgh0w5fka9dyysi74n8lj9fkgfmapz5hrr8axq";
  };
  ledeSrcLocn = {
    owner = "lede-project";
    repo = "source";
    rev = "57157618d4c25b3f08adf28bad5b24d26b3a368a";
    sha256 = "0jbkzrvalwxq7sjj58r23q3868nvs7rrhf8bd2zi399vhdkz7sfw";
  };
in {
  mt300a = {
    name = "gl-mt300a"; endian= "little";
    kernel = lib: let adds = [
                        "CLKSRC_MMIO"
                        "CMDLINE_OVERRIDE"
                        "CMDLINE_PARTITION"
                        "DEBUG_INFO"
                        "EARLY_PRINTK"
                        "GENERIC_IRQ_IPI"
                        "IP_PNP"
                        "MIPS_CMDLINE_BUILTIN_EXTEND"
                        "MTD_CMDLINE_PART"
                        "MTD_PHRAM"
                        "NET_MEDIATEK_GSW_MT7620"
                        "NET_MEDIATEK_MT7620"
                        "PARTITION_ADVANCED"
                        "PRINTK_TIME"
                        "SOC_MT7620"
                        "SQUASHFS"
                        "SQUASHFS_XZ"
                        "SQUASHFS_ZLIB"
                        "SWCONFIG"
                      ] ;
                 removes = ["MTD_ROOTFS_ROOT_DEV" "IMAGE_CMDLINE_HACK"
                            "BLK_DEV_INITRD"];
                 others = {
                            "CPU_LITTLE_ENDIAN" = "y";
                            "CMDLINE" = builtins.toJSON "earlyprintk=serial,ttyS0 console=ttyS0,115200 panic=10 oops=panic init=/bin/init phram.phram=nixrootfs,0x2000000,11Mi root=/dev/mtdblock0 memmap=12M\$0x2000000 loglevel=8 rootfstype=squashfs";
                        }; in
    {
      defaultConfig = "ramips/mt7620/config-4.9";
      socFamily = "ramips";
      extraConfig = (lib.genAttrs adds (name: "y")) //
                    (lib.genAttrs removes (name: "n")) //
                    others;
      dts = nixpkgs: nixpkgs.stdenv.mkDerivation rec {
        name = "gl-mt300a.dts";
        version = "1";
        src = nixpkgs.buildPackages.fetchurl {
          url = "https://raw.githubusercontent.com/lede-project/source/70b192f57358f753842cbe1f8f82e26e8c6f9e1e/target/linux/ramips/dts/GL-MT300A.dts";
          sha256 = "17nc31hii74hz10gfsg2v4vz5y8k91n9znyydvbnfsax7swrzlnw";
        };
        patchFile = ./kernel/kernel-dts-enable-eth0.patch;
        phases = [ "installPhase" ];
        installPhase = ''
          cp $src ./board.dts
          echo patching from ${patchFile}
          ${nixpkgs.buildPackages.patch}/bin/patch -p1 < ${patchFile}
          cp ./board.dts $out
        '';
      };
    };
  };
  yun = rec {
    name = "arduino-yun"; endian = "big";
    socFamily = "ar71xx";
    hwModule = nixpkgs: self: super:
      with nixpkgs;
      let kernelSrc = pkgs.fetchurl kernelSrcLocn;
          ledeSrc = pkgs.fetchFromGitHub ledeSrcLocn;
          readconf = readDefconfig nixpkgs;
          p = "${ledeSrc}/target/linux/";
          stripOpts = prefix: c: lib.filterAttrs (n: v: !(lib.hasPrefix prefix n)) c;
          kconfig = stripOpts "ATH79_MACH"
                      (stripOpts "XZ_DEC_"
                       (stripOpts "WLAN_VENDOR_"
                        ((readconf "${p}/generic/config-4.9") //
                         (readconf "${p}/${socFamily}/config-4.9")))) // {
                           "ATH79_MACH_ARDUINO_YUN" = "y";
                           "ATH79_MACH_TEW_712BR" = "y";
                           "ATH9K" = "y";
                           "ATH9K_AHB" = "y";
                           "CFG80211" = "y";
                           "CRASHLOG" = "n";
                           "DEBUGFS" = "n";
                           "DEVTMPFS" = "y";
                           "INPUT_MOUSE" = "n";
                           "INPUT_MOUSEDEV" = "n";
                           "JFFS2_FS" = "n";
                           "KALLSYMS" = "n";
                           "MAC80211" = "y";
                           "MOUSE_PS2" = "n";
                           "OVERLAYFS" = "n";
                           "SLOB" = "y";
                           "SLUB" = "n";
                           "SQUASHFS_ZLIB" = "n";
                           "SUSPEND" = "n";
                           "SWAP" = "n";
                           "TMPFS" = "y";
                           "VT" = "n";
                           "WLAN_80211" = "y";
                           "WLAN_VENDOR_ATH" = "y";
                         };
      in lib.attrsets.recursiveUpdate super {
        kernel.config = kconfig;
        kernel.package = (callPackage ./kernel/default.nix) {
          config = self.kernel.config;
          loadAddress = "0x80060000";
          entryPoint = "0x80060000";
          inherit kernelSrc ledeSrc socFamily;
        };
      };
    };
  malta = { name = "qemu-malta"; endian = "big";
            kernel = lib: {
              defaultConfig = "malta/config-4.9";
              extraConfig = { "BLK_DEV_SR" = "y"; "E1000" = "y"; "PCI" = "y"; "NET_VENDOR_INTEL" = "y";};
            };
          };
}
