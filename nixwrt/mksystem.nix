{ endian, ...}:
let ends = {
      "little" = {
        config = "mipsel-unknown-linux-musl";
        bfd = "elf32ltsmip";
      };
      "big" = {
        config = "mips-unknown-linux-musl";
        bfd = "elf32btsmip";
      };
    };
in {
  crossSystem = rec {
    libc = "musl";
    config = ends.${endian}.config;
    openssl.system = "linux-generic32";
    withTLS = true;
    platform = {
      inherit endian;
      kernelArch = "mips";
      gcc = { abi = "32"; } ;
      bfdEmulation = ends.${endian}.bfd;
    };
  };
}
