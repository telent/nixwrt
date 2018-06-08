{
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
  yun = { name = "arduino-yun"; endian = "big";
          kernel = lib: {
	    loadAddress = "0x80060000";
	    entryPoint = "0x80060000";
            defaultConfig = "ar71xx/config-4.9";
            extraConfig = {
              "ATH79_MACH_ARDUINO_YUN" = "y";
              "PARTITION_ADVANCED" = "y";
              "CMDLINE_PARTITION" = "y";
              "MTD_CMDLINE_PART" = "y";
              "MTD_PHRAM" = "y";
              "SQUASHFS" = "y";
              "SQUASHFS_XZ" = "y";
              "SQUASHFS_ZLIB" = "y";
              "SWCONFIG" = "y";
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
