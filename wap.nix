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
      hostname = "uostairs";
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
        {name="dan"; uid=1000; gid=1000; gecos="Daniel"; dir="/home/dan";
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
        config = { interface = "wlan0"; ssid = "testlent"; hw_mode = "g"; channel = 1; };
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
in {
  tftproot =
    let configuration = mergeModules (wantedModules ++ [ modules.tftpboot ]);
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

  firmware =
    let kernelExtra = nixpkgs: self: super:
      nixpkgs.lib.recursiveUpdate super {
        kernel.config."CMDLINE" = builtins.toJSON "earlyprintk=serial,ttyS0 console=ttyS0,115200 panic=10 oops=panic init=/bin/init root=/dev/mtdblock6 rootfstype=squashfs";
      };
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
