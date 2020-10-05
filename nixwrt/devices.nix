
# This is no longer used and is only being kept for reference until all the
# configs have been migrated into individual device/filename.nix modules


  # generic config for boards/products based on Atheros AR7x and AR9x
  # SoCs, which have _not_ been updated to use DTS but instead use the
  # older configuration style that requires a board-specific kconfig
  # option.  This is the "ar71xx" designator

  ar71xx = rec {
    socFamily = "ar71xx";
    endian = "big";
    openwrtSrc =  {
      owner = "openwrt";
      repo = "openwrt";
      name = "openwrt-source" ;
      rev = "430b66bbe8726a096b5db04dc34915ae9be1eaeb";
      sha256 = "0h7mzq2055548060vmvyl5dkvbbfzyasa79rsn2i15nhsmmgc0ri";
    };
    hwModule = {dtsPath ? null }: nixpkgs: self: super:
      with nixpkgs;
      let version = [4 14 113];
          kernelSrc = pkgs.fetchurl {
            url = (kernelSrcUrl (mmp version));
            sha256 = "1hnsmlpfbcy52dax7g194ksr9179kpigj1y5k44jkwmagziz4kdj";
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
                           "CMDLINE_PARTITION" = "y";
                           "CRASHLOG" = "n";
                           "DEBUG_FS" = "n";
                           "DEBUG_KERNEL" = "n";
                           "DEVTMPFS" = "y";
                           "IMAGE_CMDLINE_HACK" = "y";
                           "INPUT_MOUSE" = "n";
                           "INPUT_MOUSEDEV" = "n";
                           "JFFS2_FS" = "n";
                           "KALLSYMS" = "n";
                           "MAC80211" = "y";
                           "MSDOS_PARTITION" = "n";
                           "MTD_CMDLINE_PARTS" = "y";
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
                           "WLAN_VENDOR_ATH" = "y";
                         };
      in lib.attrsets.recursiveUpdate super {
        kernel.config = kconfig;
        kernel.loadAddress = "0x80060000";
        kernel.entryPoint = "0x80060000";
        kernel.dts = null;
        kernel.source = (callPackage ./kernel/prepare-source.nix) {
          ledeSrc = pkgs.fetchFromGitHub openwrtSrc;
          inherit version kernelSrc socFamily;
        };
        kernel.package = let vmlinux = (callPackage ./kernel/default.nix) {
            inherit (self.kernel) config source;
          };
          in uimage self.callPackage vmlinux self.kernel null;
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
      let super' = (ar71xx.hwModule {} nixpkgs self super);
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
      let super' = (ar71xx.hwModule {} nixpkgs self super);
        in nixpkgs.lib.recursiveUpdate super' {
          kernel.config."ATH79_MACH_TEW_712BR" = "y";
          kernel.commandLine = "earlyprintk=serial,ttyATH0 console=ttyATH0,115200 panic=10 oops=panic init=/bin/init rootfstype=squashfs board=TEW-712BR machtype=TEW-712BR";
        };
    };
