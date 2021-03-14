{  ...}:
{
  crossSystem = rec {
    #libc = "musl";
    #config = "armv7l-unknown-linux-musl";
    config = "armv7l-unknown-linux-musleabi";
    openssl.system = "linux-generic32";
    withTLS = true;
    platform = {
      kernelArch = "arm";
    };
  };
}
