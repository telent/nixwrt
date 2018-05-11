{ targetBoard ? "malta" }:
let device = (import ./nixwrt/devices.nix).${targetBoard};
    system = (import ./nixwrt/mksystem.nix) device;
    nixpkgs = import <nixpkgs> system; in
with nixpkgs;
let
    myKeys = (nixpkgs.stdenv.lib.splitString "\n" ( builtins.readFile "/etc/ssh/authorized_keys.d/dan" ) );
    rsyncPassword = (let p = builtins.getEnv( "RSYNC_PASSWORD"); in assert (p != ""); p);
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
      "USB" = "y";
      "USB_EHCI_HCD" = "y";
      "USB_EHCI_HCD_PLATFORM" = "y";
      "USB_OHCI_HCD" = "y";
      "USB_OHCI_HCD_PLATFORM" = "y";
      "USB_COMMON" = "y";
      "USB_STORAGE" = "y";
      "USB_STORAGE_DEBUG" = "n";
      "USB_UAS" = "y";
      "USB_ANNOUNCE_NEW_DEVICES" = "y";
      "SCSI"  = "y"; "BLK_DEV_SD"  = "y"; "USB_PRINTER" = "y";
      "PARTITION_ADVANCED" = "y";
      "MSDOS_PARTITION" = "y"; "EFI_PARTITION" = "y";
      "EXT4_FS" = "y";
      "EXT4_USE_FOR_EXT2" = "y";
      "EXT4_FS_ENCRYPTION" = "y";
      "EXT4_ENCRYPTION" = "y";
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

  switchconfig =
    let vlans = {"2" = "1 2 3 6t";
                 "3" = "0 6t"; };
         exe = "${swconfig}/bin/swconfig";
         cmd = vlan : ports :
           "${exe} dev switch0 vlan ${vlan} set ports '${ports}'";
         script = lib.strings.concatStringsSep "\n"
          ((lib.attrsets.mapAttrsToList cmd vlans)  ++
           ["${exe} dev switch0 set apply"
           ]); in
         writeScriptBin "switchconfig.sh" script;

  dhcpscript = writeScriptBin "dhcpscript" ''
  #!/bin/sh
  dev=eth0.2
  deconfig(){
    ip addr flush dev $dev
  }
  bound(){
    ip addr replace $ip/$mask dev $dev ;
    ip route add 0.0.0.0/0 via $router;
  }
  case $1 in
    deconfig)
      deconfig
      ;;
    bound|renew)
      bound
      ;;
    *)
      echo unrecognised command $1
      ;;
  esac
  '';

  rootfs = nixwrt.rootfsImage {
    inherit (nixwrt) monit busybox;
    iproute = iproute_;
    configuration = rec {
      hostname = "snapshto";
      interfaces = {
        "eth0.2" = {
#          ipv4Address = "192.168.0.251/24";
          type = "vlan"; id = 2; dev = "eth0"; depends = [];
        };
        "eth0" = { } ;
        lo = { ipv4Address = "127.0.0.1/8"; };
      };
      etc = {
        "resolv.conf" = { content = ( stdenv.lib.readFile "/etc/resolv.conf" );};
        "rsyncd.conf" = { content = ''
          pid file = /run/rsyncd.pid
          uid = store
          [srv]
            path = /srv
            use chroot = yes
            auth users = backup
            read only = false
            secrets file = /etc/rsyncd.secrets
          ''; };
        "rsyncd.secrets" = { mode= "0400"; content = "backup:${rsyncPassword}\n" ; };
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
        switchconfig = {
          start = "${nixwrt.busybox}/bin/sh -c '${switchconfig}/bin/switchconfig.sh &'";
          type = "oneshot";
        };
        dropbear = {
          start = "${pkgs.dropbear}/bin/dropbear -s -P /run/dropbear.pid";
          depends = [ "eth0.2"];
          hostKey = ./ssh_host_key;
        };
        rsyncd = {
          start = "${pkgs.rsync}/bin/rsync --daemon";
          depends = [ "eth0.2"];
        };
        udhcpc = {
          start = "${nixwrt.busybox}/bin/udhcpc -H ${hostname} -p /run/udhcpc.pid -s '${dhcpscript}/bin/dhcpscript'";
          depends = [ "eth0.2"];
        };
        syslogd = { start = "/bin/syslogd -R 192.168.0.2";
                    depends = ["eth0.2"]; };
        ntpd =  { start = "/bin/ntpd -p pool.ntp.org" ;
                  depends = ["eth0.2"]; };
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
