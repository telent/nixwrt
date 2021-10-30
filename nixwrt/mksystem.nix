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
  crossSystem = {
    config = ends.${endian}.config;
    gcc = {
      abi = "32";
      arch = "mips32";          # maybe mips_24kc-
    };
  };
}
