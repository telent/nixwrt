let device = import <nixwrt-device>;
    nixwrt = (import <nixwrt>) { inherit (device) endian; }; in
with nixwrt.nixpkgs;
let
  modules = import <nixwrt-config> { inherit device lib nixwrt; };
  configuration = nixwrt.mergeModules modules;
in rec {
  emulator = nixwrt.emulator configuration;

  firmware = nixwrt.firmware configuration;

  # phramware generates an image which boots from the "fake" phram mtd
  # device - required if you want to boot from u-boot without
  # writing the image to flash first
  phramware =
    let phram_ = (nixwrt.modules.phram {
          offset = "0xa00000"; sizeMB = "7";
        });
    in nixwrt.firmware (nixwrt.mergeModules [configuration phram_]);
}
