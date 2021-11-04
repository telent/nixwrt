options @ { offset, sizeMB} : nixpkgs: self: super:
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
}
