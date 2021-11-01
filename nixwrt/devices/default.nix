{
  gl-mt300a = {
    endian = "little";
    module = import ./gl-mt300a.nix;
  };
  gl-ar750 = {
    endian = "big";
    module = import ./gl-ar750.nix;
  };
  gl-mt300n-v2 = {
    endian = "little";
    module = import ./gl-mt300n-v2.nix;
  };
  qemu = {
    endian = "big";
    module = import ./qemu.nix;
  };
}
