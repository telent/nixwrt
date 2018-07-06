{
  hostapd = import ./hostapd.nix;

  busybox = import ./busybox.nix;

  rsyncd = options: nixpkgs: self: super:
    with nixpkgs;
    nixpkgs.lib.attrsets.recursiveUpdate super  {
      services = {
        rsyncd = {
          start = "${pkgs.rsync}/bin/rsync --daemon";
        };
      };
      packages = super.packages ++ [ pkgs.rsync ];
      etc = {
        "rsyncd.conf" = {
          content = ''
            pid file = /run/rsyncd.pid
            uid = store
            [srv]
              path = /srv
              use chroot = yes
              auth users = backup
              read only = false
              secrets file = /etc/rsyncd.secrets
            '';
        };
        "rsyncd.secrets" = { mode= "0400"; content = "backup:${options.password}\n" ; };
      };

    };
  sshd = options: nixpkgs: self: super:
    with nixpkgs;
    lib.attrsets.recursiveUpdate super  {
      pkgs = super.packages ++ [pkgs.dropbearSmall];
      services = with nixpkgs; {
        dropbear = {
          start = "${pkgs.dropbearSmall}/bin/dropbear -P /run/dropbear.pid";
          hostKey = options.hostkey;
        };
      };
    };
  dhcpClient = import ./dhcp_client.nix;

  syslogd = options: nixpkgs: self: super:
    with nixpkgs;
    lib.attrsets.recursiveUpdate super {
      busybox.applets = super.busybox.applets ++ [ "syslogd" ];
      busybox.config."FEATURE_SYSLOGD_READ_BUFFER_SIZE" = 256;
      busybox.config."FEATURE_REMOTE_LOG" = "y";
      services.syslogd = {
        start = "/bin/syslogd -R ${options.loghost}";
      };
    };
  ntpd = options: nixpkgs: self: super:
    with nixpkgs;
    lib.attrsets.recursiveUpdate super {
      busybox.applets = super.busybox.applets ++ [ "ntpd" ];
      services.ntpd = {
        start = "/bin/ntpd -p ${options.host}";
      };
    };

  virtio9p = options: nixpkgs: self: super:
    with nixpkgs;
    lib.attrsets.recursiveUpdate super {
      kernel.config = super.kernel.config // {
        "9P_FS" = "y";
        "9P_FS_POSIX_ACL" = "y";
        "9P_FS_SECURITY" = "y";
        "NET_9P" = "y";
        "NET_9P_DEBUG" = "y";
        "VIRTIO" = "y";
        "VIRTIO_PCI" = "y";
        "VIRTIO_NET" = "y";
        "NET_9P_VIRTIO" = "y";
      };
    };

  usbdisk =  options: nixpkgs: self: super:
    with nixpkgs;
    lib.attrsets.recursiveUpdate super {
      filesystems = super.filesystems // {
        ${options.mountpoint} = { inherit (options) label fstype options ; };
      };
      busybox.applets = super.busybox.applets ++ [
       "blkid"
       "tar"
      ];

      busybox.config = super.busybox.config // {
        "FEATURE_BLKID_TYPE" = "y";
        "FEATURE_MOUNT_FLAGS" = "y";
        "FEATURE_MOUNT_LABEL" = "y";
        "FEATURE_VOLUMEID_EXT" = "y";
      };

      kernel.config = super.kernel.config // {
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

  switchconfig =  { vlans }: nixpkgs: self: super:
    with nixpkgs;
    let exe = "${pkgs.swconfig}/bin/swconfig";
        pkg =  pkgs.swconfig.override { kernel = pkgs.linuxHeaders; };
        cmd = vlan : ports :
           "${exe} dev switch0 vlan ${vlan} set ports '${ports}'";
        script = lib.strings.concatStringsSep "\n"
          ((lib.attrsets.mapAttrsToList cmd vlans)  ++
           ["${exe} dev switch0 set apply"
           ]);
        scriptFile = writeScriptBin "switchconfig.sh" script;
    in lib.attrsets.recursiveUpdate super {
      packages = super.packages ++ [ pkg ];
      busybox.applets = super.busybox.applets ++ [ "touch" ];
      kernel.config."BRIDGE_VLAN_FILTERING" = "y";
      services.switchconfig = {
        start = "${self.busybox.package}/bin/sh -c '${scriptFile}/bin/switchconfig.sh &'";
        type = "oneshot";
      };
    };

  # Add this module when you want separate tftp-bootable images that
  # run from RAM instead of a single flashable firmware image.  Resulting images
  # may be bigger, but hopefully your device has more RAM than flash
  tftpboot = options @ { rootOffset, rootSizeMB} : nixpkgs: self: super:
    nixpkgs.lib.recursiveUpdate super {
      kernel.config."MTD_PHRAM" = "y";
      kernel.commandLine = "${super.kernel.commandLine}  phram.phram=rootfs,${rootOffset},${rootSizeMB}Mi memmap=${rootSizeMB}M\$${rootOffset}";
    };

}
