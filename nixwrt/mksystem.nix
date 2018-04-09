{ name, endian, ...}:
let ends = {
      "little" = {triples = "mipsel-linux-musl"; bfd = "elf32ltsmip"; };
      "big" = {triples = "mips-linux-musl"; bfd = "elf32btsmip"; };
    };
in {
  crossSystem = rec {
    libc = "musl";
    system = ends.${endian}.triples;
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
