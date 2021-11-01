let deviceName = (import <nixwrt-device>).name;
    device = (import <nixwrt/devices>).${deviceName};
    nixwrt = (import <nixwrt>) { inherit (device) endian; };
    modules = import <nixwrt-config> {
      config = nixwrt.emptyConfig;
      inherit device nixwrt;
    };
    configuration = nixwrt.mergeModules modules;
in rec {
  emulator = nixwrt.emulator configuration;

  firmware = nixwrt.firmware configuration;

  # phramware generates an image which boots from the "fake" phram mtd
  # device - required if you want to boot from u-boot without
  # writing the image to flash first
  phramware =
    let phram_ = (nixwrt.modules.phram {
          # XXX the offset should come from device.foo
          # XXX the size depends on the firmware image size
          # so depends on _everything_
          offset = "0xa00000"; sizeMB = "7";
        });
    in nixwrt.firmware (nixwrt.mergeModules (modules ++ [phram_]));
}
