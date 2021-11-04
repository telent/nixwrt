options: nixpkgs: self: super:
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
}
