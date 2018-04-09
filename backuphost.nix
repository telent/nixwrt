let device = (import ./nixwrt/devices.nix).mt300a;
    system = (import ./nixwrt/mksystem.nix) device;
    nixpkgs = import <nixpkgs> system; in
with nixpkgs;
let
    myKeys = (nixpkgs.stdenv.lib.splitString "\n" ( builtins.readFile "/etc/ssh/authorized_keys.d/dan" ) );
    nixwrt = pkgs.callPackages ./nixwrt/packages.nix {};
in rec {
  kernel = let k = (device.kernel lib); in nixwrt.kernel {
    lzma = nixwrt.lzmaLegacy;
    dtsPath = k.dts nixpkgs;
    inherit (k) defaultConfig extraConfig;
  };

  swconfig = nixwrt.swconfig { inherit kernel; };

  rootfs = nixwrt.rootfsImage {
    monit = nixwrt.monit;
    configuration = {
      interfaces = {
        wired = {
          device = "eth0";
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
                 in [ rsyncSansAcls swconfig ];
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
  };
  tftproot = stdenv.mkDerivation rec {
    name = "tftproot";
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out
      cp ${kernel.out}/kernel.image $out/
      cp ${rootfs}/image.squashfs  $out/rootfs.image
    '';
  };
}
