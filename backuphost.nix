with import <nixpkgs> {};
let
  platform = {
    uboot = null;
    endian = "little";
    name = "mt300a";
    kernelArch = "mips";
    gcc = { abi = "32"; } ;
    bfdEmulation = "elf32ltsmip";
  };
  platformYun = {
    uboot = null;
    endian = "big";
    name = "yun";
    kernelArch = "mips";
    gcc = { abi = "32"; } ;
    bfdEmulation = "elf32btsmip";
    kernelHeadersBaseConfig = "ath79_defconfig";
  };
  myKeys = (stdenv.lib.splitString "\n" ( builtins.readFile "/etc/ssh/authorized_keys.d/dan" ) );
  config = { pkgs, stdenv, ... } : {
    kernel = {
      # this pathname is relative to lede target/linux/
      defaultConfig = "ramips/mt7620/config-4.9";
      overrideConfig = cfg : let adds = [
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
        "TMPFS"

        "USB_COMMON"
        "USB_STORAGE"
        "USB_UAS"
        "USB_ANNOUNCE_NEW_DEVICES"
        "SCSI" "BLK_DEV_SD" "USB_PRINTER"
        "PARTITION_ADVANCED"
        "MSDOS_PARTITION" "EFI_PARTITION" "CMDLINE_PARTITION"
        "EXT2_FS" "EXT3_FS" "EXT4_FS" "NTFS_FS"
      ] ;
      removes = ["MTD_ROOTFS_ROOT_DEV" "IMAGE_CMDLINE_HACK" "BLK_DEV_INITRD"];
      others = {
        "CPU_${lib.strings.toUpper platform.endian}_ENDIAN" = "y";
        "CMDLINE" = builtins.toJSON "earlyprintk=serial,ttyS0 console=ttyS0,115200 panic=10 oops=panic init=/bin/init phram.phram=nixrootfs,0x2000000,11Mi root=/dev/mtdblock0 memmap=12M\$0x2000000 loglevel=8 rootfstype=squashfs";
      };
      in cfg // (lib.genAttrs adds (name: "y")) //
                (lib.genAttrs removes (name: "n")) //
                others;
    };
    interfaces = {
      wired = {
        device = "eth1";
        address = "192.168.0.251";
        defaultRoute = "192.168.0.254";
      };
    };
    etc = {
      "resolv.conf" = { content = ( stdenv.lib.readFile "/etc/resolv.conf" );};
    };
    users = [
      {name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
       shell="/bin/sh"; authorizedKeys = myKeys;}
      {name="store"; uid=500; gid=500; gecos="Storage owner"; dir="/srv";
       shell="/dev/null"; authorizedKeys = [];}
      {name="dan"; uid=1000; gid=1000; gecos="Daniel"; dir="/home/dan";
       shell="/bin/sh"; authorizedKeys = myKeys;}
    ];
    packages = let rsyncSansAcls = pkgs.rsync.override { enableACLs = false; } ;
               in [ rsyncSansAcls ];
    filesystems = {
      "/srv" = { label = "backup-disk";
                 fstype = "ext4";
                 options = "rw";
               };
    };
    services = {
      dropbear = {
        start = "${pkgs.dropbear}/bin/dropbear -s -P /run/dropbear.pid";
        depends = [ "wired"];
        hostKey = ./ssh_host_key;
      };
      syslogd = { start = "/bin/syslogd -R 192.168.0.2";
                  depends = ["wired"]; };
      ntpd =  { start = "/bin/ntpd -p pool.ntp.org" ;
                depends = ["wired"]; };
    };

  };
in ((import ./nixwrt) platform config)
