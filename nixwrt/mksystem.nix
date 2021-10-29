{ endian, ...}:
let ends = {
      "little" = {
        config = "mipsel-unknown-linux-musl";
#        bfd = "elf32ltsmip";
      };
      "big" = {
        config = "mips-unknown-linux-musl";
#        bfd = "elf32btsmip";
      };
    };
in {
  localSystem = builtins.currentSystem;
  crossSystem = {
    config = ends.${endian}.config;
  };
}
