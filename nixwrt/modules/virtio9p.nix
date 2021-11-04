options: nixpkgs: self: super:
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
}
