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
    gcc = { abi = "32"; arch = "mips32"; } ;
    linuxArch = "mips";
    bfdEmulation = ends.${endian}.bfd;
    # platform = {
    #   inherit endian;
    # };
  };
}
