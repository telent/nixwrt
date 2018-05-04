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
    inherit (k) defaultConfig;
    extraConfig = k.extraConfig // {
      "9P_FS" = "y";
      "9P_FS_POSIX_ACL" = "y";
      "9P_FS_SECURITY" = "y";
      "BRIDGE_VLAN_FILTERING" = "y";
      "NET_9P" = "y";
      "NET_9P_DEBUG" = "y";
      "VIRTIO" = "y";
      "VIRTIO_PCI" = "y";
      "VIRTIO_NET" = "y";
      "NET_9P_VIRTIO" = "y";
    };
  };

  kernel = nixwrt.kernel testKernelAttrs;

  swconfig = nixwrt.swconfig { inherit kernel; };
  iproute_ = pkgs.iproute.override {
    # db cxxSupport causes closure size explosion because it drags in
    # gcc as runtime dependency.  I don't think it needs it, it's some
    # kind of rpath problem or similar
    db = pkgs.db.override { cxxSupport = false;};
  };
  rootfs = nixwrt.rootfsImage {
    inherit (nixwrt) monit busybox;
    iproute = iproute_;
    configuration = {
      interfaces = {
        "eth0.1" = { type = "vlan" ;  id = 1; dev = "eth0"; depends = ["switchconfig"];};
        "eth0" = { } ;
        lo = { ipv4Address = "127.0.0.1/8"; };
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
                 in [ rsyncSansAcls swconfig iproute_ ];
      filesystems = {
        "/srv" = { label = "backup-disk";
                   fstype = "ext4";
                   options = "rw";
                 };
      };
      services = {
        switchconfig =
          let vlans = {"2" = "1t 2t 3t 6";
                       "3" = "0t 6"; };
               cmd = vlan : ports :
                 "${swconfig}/bin/swconfig dev switch0 vlan ${vlan} ports '${ports}'";
               script = lib.strings.concatStringsSep "\n" ((lib.attrsets.mapAttrsToList cmd vlans)  ++ ["${swconfig}/bin/swconfig dev switch0 set apply"]);
               file = writeScriptBin "switchconfig.sh" script;
          in {
            start = "${nixwrt.busybox}/bin/sh ${file}";
            type = "oneshot";
        };
        dropbear = {
          start = "${pkgs.dropbear}/bin/dropbear -s -P /run/dropbear.pid";
          depends = [ "eth0.1"];
          hostKey = ./ssh_host_key;
        };
        syslogd = { start = "/bin/syslogd -R 192.168.0.2";
                    depends = ["eth0.1"]; };
        ntpd =  { start = "/bin/ntpd -p pool.ntp.org" ;
                  depends = ["eth0.1"]; };
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
