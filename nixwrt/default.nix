{ overlays ? [] , targetBoard }:
let overlay = import ./overlay.nix;
  device = (import ./devices.nix).${targetBoard};
  modules = import ./modules/default.nix;
  system = (import ./mksystem.nix) device;
  nixpkgs = import <nixpkgs> (system // { overlays = [overlay] ++ overlays;} );
in
with nixpkgs; rec {
  inherit device modules system nixpkgs;

  mergeModules = ms:
    let extend = lhs: rhs: lhs // rhs lhs;
    in lib.fix (self: lib.foldl extend {}
                  (map (x: x self) (map (f: f nixpkgs) ms)));

  rootfs = configuration: pkgs.callPackage ./rootfs-image.nix {
    busybox = configuration.busybox.package;
    inherit configuration;
  };

  firmware = configuration:
    let kernelImage = configuration.kernel.package;
    in stdenv.mkDerivation rec {
      name = "firmware.bin";
      phases = [ "installPhase" ];
      inherit kernelImage;
      installPhase = ''
        mkdir -p $out
        dd if=${kernelImage} of=$out/firmware.bin bs=128k conv=sync
        dd if=${rootfs configuration}/image.squashfs of=$out/firmware.bin bs=128k conv=sync,nocreat,notrunc oflag=append
      '';
  };
}
