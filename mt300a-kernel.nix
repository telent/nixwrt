lib :
let adds = [
  "CLKSRC_MMIO"
  "CMDLINE_OVERRIDE"
  "DEBUG_INFO"
  "DEVTMPFS"
  "EARLY_PRINTK"
  "GENERIC_IRQ_IPI"
  "IP_PNP"
  "MIPS_CMDLINE_BUILTIN_EXTEND"
  "MTD_CMDLINE_PART"
  "MTD_PHRAM"
  "NET_MEDIATEK_GSW_MT7620"
  "NET_MEDIATEK_MT7620"
  "PRINTK_TIME"
  "SOC_MT7620"
  "SQUASHFS"
  "SQUASHFS_XZ"
  "SQUASHFS_ZLIB"
  "SWCONFIG"
  "TMPFS"

  "PARTITION_ADVANCED"
  "CMDLINE_PARTITION"
] ;
removes = ["MTD_ROOTFS_ROOT_DEV" "IMAGE_CMDLINE_HACK" "BLK_DEV_INITRD"];
others = {
  "CPU_LITTLE_ENDIAN" = "y";
  "CMDLINE" = builtins.toJSON "earlyprintk=serial,ttyS0 console=ttyS0,115200 panic=10 oops=panic init=/bin/init phram.phram=nixrootfs,0x2000000,11Mi root=/dev/mtdblock0 memmap=12M\$0x2000000 loglevel=8 rootfstype=squashfs";
};
in {
  defaultConfig = "ramips/mt7620/config-4.9";
  overrideConfig = cfg : cfg // (lib.genAttrs adds (name: "y")) //
                         (lib.genAttrs removes (name: "n")) //
                         others;
}
