{ targetBoard ? "malta" }:
let device = (import ./nixwrt/devices.nix).${targetBoard};
    system = (import ./nixwrt/mksystem.nix) device;
    nixpkgs = import <nixpkgs> system; in
with nixpkgs;
let
    myKeys = (nixpkgs.stdenv.lib.splitString "\n" ( builtins.readFile "/etc/ssh/authorized_keys.d/dan" ) );
    nixwrt = pkgs.callPackages ./nixwrt/packages.nix {};
in rec {
  testKernelAttrs = let k = (device.kernel lib); in {
    lzma = nixwrt.lzmaLegacy;
    dtsPath = if (k ? dts) then (k.dts nixpkgs) else null ;
    inherit (k) defaultConfig extraConfig;
  };

  kernel = nixwrt.kernel testKernelAttrs;

  swconfig = nixwrt.swconfig { inherit kernel; };

  rootfs = nixwrt.rootfsImage {
    inherit (nixwrt) monit busybox;
    configuration = {
      interfaces = {
        wired = {
          device = "eth0";
          address = "192.168.0.251";
          defaultRoute = "192.168.0.254";
        };
        loopback = {
          device = "lo";
          address = "127.0.0.1";
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
                 in [ rsyncSansAcls swconfig ];
      filesystems = {
        "/srv" = { label = "backup-disk";
                   fstype = "ext4";
                   options = "rw";
                 };
      };
      services = {
        switch = {
          start = "/bin/sh -c '${swconfig}/bin/swconfig dev switch0 set enable_vlan 0; ${swconfig}/bin/swconfig dev switch0 set apply'";
        };

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
  };

  tftproot = stdenv.mkDerivation rec {
    name = "tftproot";
    phases = [ "installPhase" ];
    kernelImage = (if targetBoard == "malta" then kernel.vmlinux else "${kernel.out}/kernel.image");
    installPhase = ''
      mkdir -p $out
      cp ${kernelImage} $out/kernel.image
      cp ${rootfs}/image.squashfs  $out/rootfs.image
    '';
  };

  firmwareImage = stdenv.mkDerivation rec {
    name = "firmware.bin";
    phases = [ "installPhase" ];
    installPhase =
      let liveKernelAttrs = lib.attrsets.recursiveUpdate testKernelAttrs {
            extraConfig."CMDLINE" =
              builtins.toJSON "earlyprintk=serial,ttyS0 console=ttyS0,115200 panic=10 oops=panic init=/bin/init root=/dev/mtdblock5 rootfstype=squashfs";
          };
          kernel = nixwrt.kernel liveKernelAttrs;
      in ''
        dd if=${kernel.out}/kernel.image of=$out bs=128k conv=sync
        dd if=${rootfs}/image.squashfs of=$out bs=128k conv=sync,nocreat,notrunc oflag=append
      '';
  };
}
