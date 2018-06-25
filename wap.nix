# Configuration for a wireless access point based on Atheros 9331
# (testing on Arduino Yun, deploying on Trendnet TEW712BR)

{ targetBoard ? "yun" }:
let device = (import ./nixwrt/devices.nix).${targetBoard};
    modules = (import ./nixwrt/modules/default.nix);
    system = (import ./nixwrt/mksystem.nix) device;
    overlay = (import ./nixwrt/overlay.nix);
    nixpkgs = import <nixpkgs> (system // { overlays = [overlay] ;} ); in
with nixpkgs;
let
    myKeys = (nixpkgs.stdenv.lib.splitString "\n" ( builtins.readFile "/etc/ssh/authorized_keys.d/dan" ) );
    baseConfiguration = rec {
      hostname = "upstaisr";
      interfaces = {
        "eth0" = { };
        lo = { ipv4Address = "127.0.0.1/8"; };
        "wlan0" = { };
        "br0" = {
          type = "bridge";
          members  = [ "eth0" "wlan0" ];
        };
      };
      etc = {
        "resolv.conf" = { content = ( stdenv.lib.readFile "/etc/resolv.conf" );};
      };
      users = [
        {name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
         shell="/bin/sh"; authorizedKeys = myKeys;}
      ];
      packages = [] ;
      filesystems = { };
      services = { };
    };
    wantedModules = with modules; [
      (nixpkgs: self: super: baseConfiguration)
      device.hwModule
      (sshd { hostkey = ./ssh_host_key ; })
      busybox
      (syslogd { loghost = "192.168.0.2"; })
      (ntpd { host = "pool.ntp.org"; })
      (hostapd {
        config = { interface = "wlan0"; ssid = "telent"; hw_mode = "g"; channel = 1; };
        # no support currently for generating these, use wpa_passphrase
        psk = builtins.getEnv( "PSK") ;
      })
      (dhcpClient { interface = "br0"; })
    ];
    mergeModules = ms:
      let extend = lhs: rhs: lhs // rhs lhs;
      in lib.fix (self: lib.foldl extend {}
                    (map (x: x self) (map (f: f nixpkgs) ms)));
    configuration = mergeModules wantedModules;
    kernelExtra = nixpkgs: self: super:
      nixpkgs.lib.recursiveUpdate super {
        kernel.config."MTD_SPLIT" = "y";
        kernel.config."MTD_SPLIT_UIMAGE_FW" = "y";
        kernel.commandLine = "${super.kernel.commandLine} mtdparts=spi0.0:64k(u-boot),64k(ART),64k(mac),64k(nvram),192k(language),3648k(firmware)";
      };

in {
  tftproot =
    let configuration = mergeModules (wantedModules ++ [
     (modules.tftpboot {rootOffset="0x1200000"; rootSizeMB="4"; })
     # kernelExtra
     ]);
       rootfs = pkgs.callPackage ./nixwrt/rootfs-image.nix {
         busybox = configuration.busybox.package;
         inherit configuration;
       };
       kernel = configuration.kernel.package;
     in stdenv.mkDerivation rec {
       name = "tftproot";
       phases = [ "installPhase" ];
       kernelImage = (if targetBoard == "malta" then kernel.vmlinux else "${kernel.out}/kernel.image");
       installPhase = ''
         mkdir -p $out
         cp ${kernelImage} $out/kernel.image
         cp ${rootfs}/image.squashfs  $out/rootfs.image
       '';
    };
  k = (mergeModules (wantedModules ++ [kernelExtra])).kernel.package;
  firmware = let
    configuration = mergeModules (wantedModules ++ [kernelExtra]);
    rootfs = pkgs.callPackage ./nixwrt/rootfs-image.nix {
      busybox = configuration.busybox.package;
      inherit configuration;
    };
    kernel = configuration.kernel.package;
    in stdenv.mkDerivation rec {
      name = "firmware.bin";
      phases = [ "installPhase" ];
      installPhase = ''
        dd if=${kernel.out}/kernel.image of=$out bs=128k conv=sync
        dd if=${rootfs}/image.squashfs of=$out bs=128k conv=sync,nocreat,notrunc oflag=append
      '';
  };
}
