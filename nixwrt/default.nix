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

  tftproot = configuration:
    let rootfs = pkgs.callPackage ./rootfs-image.nix {
                   busybox = configuration.busybox.package;
                   inherit configuration;
                 };
        kernel = configuration.kernel.package;
    in stdenv.mkDerivation rec {
      name = "tftproot";
      phases = [ "installPhase" ];
      kernelImage = (if targetBoard == "malta" then kernel.vmlinux else "${kernel.out}/kernel.image");
      installPhase = ''
        mkdir -p $out
        cp ${kernelImage} $out/kernel.image
        cp ${rootfs}/image.squashfs  $out/rootfs.image
      '';
   };

  firmware = configuration:
    let rootfs = pkgs.callPackage ./rootfs-image.nix {
                   busybox = configuration.busybox.package;
                   inherit configuration;
                 };
        kernel = configuration.kernel.package;
    in stdenv.mkDerivation rec {
      name = "firmware.bin";
      phases = [ "installPhase" ];
      installPhase = ''
        dd if=${kernel.out}/kernel.image of=$out bs=128k conv=sync
        dd if=${rootfs}/image.squashfs of=$out bs=128k conv=sync,nocreat,notrunc oflag=append
      '';
  };
}
