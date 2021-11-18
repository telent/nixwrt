let deviceName = (import <nixwrt-device>).name;
    device = (import <nixwrt/devices>).${deviceName};
    nixwrt = (import <nixwrt>) { inherit (device) endian; };
    modules =
      [( _ : _ : _ :  nixwrt.emptyConfig)
       (device.module {})] ++
      import <nixwrt-config> {inherit device nixwrt; } ++
      [(nixpkgs: self: super :
        let lib = nixpkgs.lib;
            allServices = lib.mapAttrsToList (n: s: s.ready) super.svcs;
            starter = nixpkgs.pkgs.svc {
              name = "all-systems";
              start = "setstate ready true";
              outputs = ["ready"];
              depends = allServices ;
            };
        in lib.mergeConfigs [
          super
          starter.mergedConfig
          {
            supervisor = starter.package;
            packages = [ starter.package ];
          }])];
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
          offset = configuration.boot.phramBaseAddress;
          sizeMB = "7";
        });
    in nixwrt.firmware (nixwrt.mergeModules (modules ++ [phram_]));
}
