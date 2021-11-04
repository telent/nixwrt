nixpkgs: self: super:
nixpkgs.lib.recursiveUpdate super {
  kernel.config."MTD_SPLIT" = "y";
  kernel.config."MTD_SPLIT_UIMAGE_FW" = "y";
  kernel.config."MTD_CMDLINE_PARTS" = "y";
  # partition layout comes from device tree, doesn't need to be specified here
}
