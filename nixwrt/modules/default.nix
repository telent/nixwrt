{
  hostapd = import ./hostapd.nix;

  busybox = import ./busybox.nix;

  syslog = import ./syslog.nix;

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

  switchconfig =  { name, interface, vlans }: nixpkgs: self: super:
    with nixpkgs;
    let exe = "${pkgs.swconfig}/bin/swconfig";
        cmd = vlan : ports :
           "${exe} dev ${name} vlan ${vlan} set ports '${ports}'";
        script = lib.strings.concatStringsSep "\n"
          (["${exe} dev ${name} set reset 1"
            "${exe} dev ${name} set enable_vlan 1"] ++
           (lib.attrsets.mapAttrsToList cmd vlans)  ++
           ["${exe} dev ${name} set apply 1"]
           );
        scriptFile = writeScriptBin "switchconfig.sh" script;
    in lib.attrsets.recursiveUpdate super {
      busybox.applets = super.busybox.applets ++ [ "touch" ];
      kernel.config."BRIDGE_VLAN_FILTERING" = "y";
      kernel.config."SWCONFIG" = "y";
      interfaces.${interface}.depends =  [ name ];
      services.${name} = {
        start = "${self.busybox.package}/bin/sh -c '${scriptFile}/bin/switchconfig.sh'";
        type = "oneshot";
      };
    };

  kernelMtd =  nixpkgs: self: super:
    nixpkgs.lib.recursiveUpdate super {
      kernel.config."MTD_SPLIT" = "y";
      kernel.config."MTD_SPLIT_UIMAGE_FW" = "y";
      kernel.config."MTD_CMDLINE_PARTS" = "y";
      # partition layout comes from device tree, doesn't need to be specified here
    };

  pppoe = params @ {options ? {}, auth} : nixpkgs: self: super:
    let ppp_config = nixpkgs.writeText "pppd.options"
       (builtins.concatStringsSep
         "\n"
         (nixpkgs.lib.mapAttrsToList
            (name: value: "${name} ${value}")
	  ({plugin = "rp-pppoe.so";
  	    # nodetach
            "eth0" = "";
	    usepeerdns = "";
	    defaultroute ="";
	    persist = "";} // options)));
        in nixpkgs.lib.recursiveUpdate super {
	   kernel.config."PPP" = "y";
	   kernel.config."PPP_BSDCOMP" = "y";
	   kernel.config."PPP_DEFLATE" = "y";
	   kernel.config."PPP_ASYNC" = "y";
	   kernel.config."PPP_SYNC_TTY" = "y";
	   packages = super.packages ++ [ nixpkgs.ppp ppp_config ];
	   etc."ppp" = { type="d"; mode = "0500"; };
	   etc."ppp/chap-secrets" = { content = auth; mode = "0400"; };
	   etc."ppp/pap-secrets" = { content = auth; mode = "0400"; };
	};

  phram = options @ { offset, sizeMB} : nixpkgs: self: super:
    nixpkgs.lib.recursiveUpdate super {
      etc."phram.vars" = {
        content = ''
          phram_sizeMB=${sizeMB}
          phram_offset=${offset}
        '';
        mode = "0555";
      };
      kernel.config."MTD_PHRAM" = "y";
      kernel.config."MTD_SPLIT_FIRMWARE" = "y";
      kernel.config."MTD_SPLIT_FIRMWARE_NAME" = builtins.toJSON "nixwrt";
      boot.commandLine =
        "${super.boot.commandLine} mtdparts=phram0:${sizeMB}M(nixwrt) phram.phram=phram0,${offset},${sizeMB}Mi memmap=${sizeMB}M\$${offset}";
    };
  kexec = _: nixpkgs: self: super:
    with nixpkgs;
    lib.recursiveUpdate super {
      packages = super.packages ++ [ pkgs.kexectools ];
      kernel.config."KEXEC" = "y";
    };

  haveged = import ./haveged.nix;

}
