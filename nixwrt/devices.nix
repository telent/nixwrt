let
  readDefconfig = import ./util/read_defconfig.nix;
  kernelSrcUrl = v : "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-${v}.tar.xz";
  majmin = version :
    let el = n : builtins.toString (builtins.elemAt version n);
    in (el 0) + "." + (el 1);
  mmp = version :
    let el = n : builtins.toString (builtins.elemAt version n);
    in (el 0) + "." + (el 1) + "." + (el 2);
in rec {

  # generic config for boards/products based on the mt7620, which uses the "ramips"
  # soc family in Linux.  Board-specific config for systems based on this (at least, all the
  # ones I've seen so far) is based on device tree, so they need .dts files
  mt7620 = rec {
    endian= "little";
    socFamily = "ramips";
    hwModule = {dts, soc ? "mt7620" } : nixpkgs: self: super:
      with nixpkgs;
      let version = [4 14 53];
          kernelSrc = pkgs.fetchurl {
            url = (kernelSrcUrl (mmp version));
            sha256 = "1gqbm26j7sayl854mlfjmwjvjh3gis2w1l2rl7s53ibxz5r2apx8";
          };
          readconf = readDefconfig nixpkgs;
          stripOpts = prefix: c: lib.filterAttrs (n: v: !(lib.hasPrefix prefix n)) c;
          kconfig = {
            "BLK_DEV_INITRD" = "n";
            "CLKSRC_MMIO" = "y";
            "CLKSRC_OF" = "y";
            "CMDLINE_PARTITION" = "y";
            "CPU_LITTLE_ENDIAN" = "y";
            "DEBUG_INFO" = "y";
            "DEVTMPFS" = "y";
            "EARLY_PRINTK" = "y";
            "GENERIC_IRQ_IPI" = "y";
            "IMAGE_CMDLINE_HACK" = "n";
            "IP_PNP" = "y";
            "JFFS2_FS" = "n";
            "MIPS_CMDLINE_BUILTIN_EXTEND" = "y";
            "MTD_CMDLINE_PART" = "y";
            "NETFILTER"= "y";   # mtk_eth_soc.c won't build without this
            "NET_MEDIATEK_GSW_MT7620" = "y";
            "NET_MEDIATEK_MT7620" = "y";
            "PARTITION_ADVANCED" = "y";
            "PRINTK_TIME" = "y";
            "SQUASHFS" = "y";
            "SQUASHFS_XZ" = "y";
          };
          p = "${pkgs.ledeSrc}/target/linux/";
      in lib.attrsets.recursiveUpdate super {
        kernel.config = (readconf "${p}/generic/config-${majmin version}") //
                        (readconf "${p}/${socFamily}/${soc}/config-${majmin version}") //
                        kconfig;
        kernel.commandLine = "earlyprintk=serial,ttyS0 console=ttyS0,115200 panic=10 oops=panic init=/bin/init loglevel=8 rootfstype=squashfs";
        kernel.package = (callPackage ./kernel/default.nix) {
          config = self.kernel.config;
          commandLine = self.kernel.commandLine;
          loadAddress = "0x80000000";
          entryPoint = "0x80000000";
          dtsPath = dts;
          inherit (pkgs) ledeSrc;
          inherit version kernelSrc socFamily;
        };
      };
    };

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

  mt300a = mt7620 // rec {
      name = "glinet-mt300a";
      hwModule = nixpkgs: self: super:
        with nixpkgs;
        let dtsPath = stdenv.mkDerivation rec {
          name = "gl-mt300a.dts";
          version = "1";
          src = buildPackages.fetchurl {
            url = "https://raw.githubusercontent.com/lede-project/source/70b192f57358f753842cbe1f8f82e26e8c6f9e1e/target/linux/ramips/dts/GL-MT300A.dts";
            sha256 = "17nc31hii74hz10gfsg2v4vz5y8k91n9znyydvbnfsax7swrzlnw";
          };
          patchFile = ./kernel/kernel-dts-enable-eth0.patch;
          phases = [ "installPhase" ];
          installPhase = ''
            cp $src ./board.dts
            echo patching from ${patchFile}
            ${buildPackages.patch}/bin/patch -p1 < ${patchFile}
            cp ./board.dts $out
          '';
        };
        super' = (mt7620.hwModule {dts = dtsPath;} nixpkgs self super);
        in super';
    };

  # Another GL-Inet product: the MT300N v2 has a slightly different
  # chipset than the 300A, and comes in a yellow case not a blue one.
  # It's different again to the v1, which has only half the RAM.
  # At the time I bought it it was a tenner cheaper than the A
  # variant.

  mt300n_v2 = mt7620 // rec {
      name = "glinet-mt300n_v2";
      hwModule = nixpkgs: self: super:
        with nixpkgs;
        let
          dts = buildPackages.fetchurl {
            url = "https://raw.githubusercontent.com/lede-project/source/70b192f57358f753842cbe1f8f82e26e8c6f9e1e/target/linux/ramips/dts/GL-MT300N-V2.dts";
            sha256 = "1xfqays38pqh1qmzcf6753by9xac2jmyiglpv79p8d60b7qma8n4";
          };
          super' = (mt7620.hwModule {dts = dts; soc="mt76x8"; } nixpkgs self super);
        in super';
    };

  # generic config for boards/products based on Atheros AR7x and AR9x SoCs,
  # which corresponds to the "ath79" soc family in Linux (but the "ar71xx" designator
  # in OpenWRT, just liven things up).  There are some boards that use device tree
  # but all the ones I've built for so far use the older configuration style that
  # requires a board-specific kconfig option.  So: if you're using a dts file in this
  # soc family you're the first in nnixwrt to do so.
  ar71xx = rec {
    socFamily = "ar71xx";
    endian = "big";
    hwModule = nixpkgs: self: super:
      with nixpkgs;
      let version = [4 9 91];
          kernelSrc = pkgs.fetchurl {
            url = (kernelSrcUrl (mmp version));
            sha256 = "0clqndkj24a9752bc8x7cwdrdl38yarpvwx2yqkc98czxi9agjk0";
          };
          readconf = readDefconfig nixpkgs;
          p = "${ledeSrc}/target/linux/";
          stripOpts = prefix: c: lib.filterAttrs (n: v: !(lib.hasPrefix prefix n)) c;
          kconfig = stripOpts "ATH79_MACH"
                      (stripOpts "XZ_DEC_"
                       (stripOpts "WLAN_VENDOR_"
                        ((readconf "${p}/generic/config-${majmin version}") //
                         (readconf "${p}/${socFamily}/config-${majmin version}")))) // {
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
        kernel.package = (callPackage ./kernel/default.nix) {
          config = self.kernel.config;
          commandLine = self.kernel.commandLine;
          loadAddress = "0x80060000";
          entryPoint = "0x80060000";
          inherit (pkgs) ledeSrc;
          inherit kernelSrc socFamily version;
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

  yun =
    ar71xx // rec {
      name = "arduino-yun";
      hwModule = nixpkgs: self: super:
        let super' = (ar71xx.hwModule nixpkgs self super);
        in nixpkgs.lib.recursiveUpdate super' {
          kernel.config."ATH79_MACH_ARDUINO_YUN" = "y";
          kernel.commandLine = "earlyprintk=serial,ttyATH0 console=ttyATH0,115200 panic=10 oops=panic init=/bin/init rootfstype=squashfs board=Yun machtype=Yun";
        };
    };

  # The TrendNET TEW712BR is another Atheros AR9330 device, but has
  # only 4MB of flash.  In 2018 this means it has essentially nothing
  # to recommend it as a NixWRT or OpenWRT target, but I happened to
  # have one lying around and wanted to use it.

  tew712br =
    ar71xx // rec {
      name = "trendnet-tew712br";
      hwModule = nixpkgs: self: super:
        let super' = (ar71xx.hwModule nixpkgs self super);
        in nixpkgs.lib.recursiveUpdate super' {
          kernel.config."ATH79_MACH_TEW_712BR" = "y";
          kernel.commandLine = "earlyprintk=serial,ttyATH0 console=ttyATH0,115200 panic=10 oops=panic init=/bin/init rootfstype=squashfs board=TEW-712BR machtype=TEW-712BR";
        };
    };

  # this is bitrotted code for running on Qemu.  See QEMU.md
  malta = rec {
    name = "qemu-malta"; endian = "little";
    socFamily = "malta";
    hwModule = nixpkgs: self: super:
      with nixpkgs;
      let p = "${ledeSrc}/target/linux/";
          version = [4 14 53];
          kernelSrc = pkgs.fetchurl {
            url = (kernelSrcUrl (mmp version));
            sha256 = "1gqbm26j7sayl854mlfjmwjvjh3gis2w1l2rl7s53ibxz5r2apx8";
          };
          readconf = readDefconfig nixpkgs;
      in
        lib.recursiveUpdate super {
          kernel.config = (readconf "${p}/generic/config-${majmin version}") //
                          (readconf "${p}/${socFamily}/config-${majmin version}") //
                          {
                            "BLK_DEV_SR" = "y";
                            "E1000" = "y";
                            "PCI" = "y";
                            "NET_VENDOR_INTEL" = "y";
                          };
          kernel.commandLine = "root=/dev/sr0 console=ttyS0 init=/bin/init";
          kernel.package = (callPackage ./kernel/default.nix) {
            config = self.kernel.config;
            commandLine = self.kernel.commandLine;
            loadAddress = "0x80000000";
            entryPoint = "0x80000000";
#            dtsPath = dts;
            inherit (pkgs) ledeSrc;
            inherit version kernelSrc socFamily;
          };
        };
  };
}
