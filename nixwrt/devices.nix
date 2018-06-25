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
    # GL-Inet GL-MT300A

    # The GL-Inet pocket router range makes nice cheap hardware for
    # playing with NixWRT or similar projects. The manufacturers seem
    # open to the DIY market, and the devices have a reasonable amount
    # of RAM and are much easier to get serial connections than many
    # COTS routers. GL-MT300A is my current platform for NixWRT
    # development.

    # Wire up the serial connection: this probably involves opening
    # the box, locating the serial header pins (TX, RX and GND) and
    # connecting a USB TTL converter - e.g. a PL2303 based device - to
    # it. The defunct OpenWRT wiki has a guide with some pictures. (If
    # you don't have a USB TTL converter to hand, other options are
    # available. For example, use the GPIO pins on a Raspberry Pi)

    # Run a terminal emulator such as Minicom on whatever is on the
    # other end of the link. I use 115200 8N1 and find it also helps
    # to set "Character tx delay" to 1ms, "backspace sends DEL" and
    # "lineWrap on".

    # When you turn the router on you should be greeted with some
    # messages from U-Boot and a little bit of ASCII art, followed by
    # the instruction to hit SPACE to stop autoboot. Do this and you
    # will get a gl-mt300a> prompt.

    # For flashing from uboot, the firmware partition is from
    # 0xbc050000 to 0xbcfd0000

    # For more details refer to https://ww.telent.net/2018/4/16/flash_ah_ah

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

  # The Arduino Yun is a handy (although pricey) way to get an AR9331
  # target without any soldering: it's a MIPS SoC glued to an Arduino,
  # so you can use Arduino tools to talk to it.

  # In order to talk to the Atheros over a serial connection, upload
  # https://www.arduino.cc/en/Tutorial/YunSerialTerminal to your
  # Yun using the standard Arduino IDE. Once the sketch is
  # running, rather than using the Arduino serial monitor as it
  # suggests, I run Minicom on /dev/ttyACM0

  # On a serial connection to the Yun, to get into the U-Boot monitor
  # you hit YUN RST button, then press RET a couple of times - or in
  # newer U-Boot versions you need to type ard very quickly.
  # https://www.arduino.cc/en/Tutorial/YunUBootReflash may help

  # The output most probably will change to gibberish partway through
  # bootup. This is because the kernel serial driver is running at a
  # different speed to U-Boot, and you need to change it (if using the
  # YunSerialTerminal sketch, by pressing ~1 or something along those
  # lines).

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
                           "BLK_DEV_INITRD" = "n";
                           "CFG80211" = "y";
                           "CMDLINE_OVERRIDE" = "y";
                           "CMDLINE_PARTITION" = "y";
                           "CRASHLOG" = "n";
                           "DEBUG_FS" = "n";
                           "DEBUG_KERNEL" = "n";
                           "DEVTMPFS" = "y";
                           "INPUT_MOUSE" = "n";
                           "INPUT_MOUSEDEV" = "n";
                           "JFFS2_FS" = "n";
                           "KALLSYMS" = "n";
                           "MAC80211" = "y";
                           "MIPS_CMDLINE_BUILTIN_EXTEND" = "y";
                           "MSDOS_PARTITION" = "n";
                           "MTD_CMDLINE_PART" = "y";
                           "MOUSE_PS2" = "n";
                           "OVERLAY_FS" = "n";
                           "PARTITION_ADVANCED" = "y";
                           "SCHED_DEBUG" = "n";
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
        # ACHTUNG! XXX! we're temporarily abusing this configuration
        # for a TrendNET TEW712BR.  The only change you'd have to make
        # to go back to a Yun is the `board` and `machtype` below.
        kernel.commandLine = "earlyprintk=serial,ttyATH0 console=ttyATH0,115200 panic=10 oops=panic init=/bin/init  rootfstype=squashfs board=TEW-712BR machtype=TEW-712BR";
        kernel.package = (callPackage ./kernel/default.nix) {
          config = self.kernel.config;
          commandLine = self.kernel.commandLine;
          loadAddress = "0x80060000";
          entryPoint = "0x80060000";
          inherit kernelSrc ledeSrc socFamily;
        };
      };
    };
  # see QEMU.md
  malta = { name = "qemu-malta"; endian = "big";
            kernel = lib: {
              defaultConfig = "malta/config-4.9";
              extraConfig = { "BLK_DEV_SR" = "y"; "E1000" = "y"; "PCI" = "y"; "NET_VENDOR_INTEL" = "y";};
            };
          };
}
