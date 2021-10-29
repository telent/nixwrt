{ overlays ? []
, endian }:
let
  overlay = import ./overlay.nix;
  modules = import ./modules/default.nix;
  system = (import ./mksystem.nix) { inherit endian; };

  nixpkgsTarball = builtins.fetchTarball {
    name = "nixos-unstable";
    url = "https://github.com/nixos/nixpkgs/archive/2deb07f3ac4eeb5de1c12c4ba2911a2eb1f6ed61.tar.gz";
    # Hash obtained using `nix-prefetch-url --unpack <url>`
    sha256 = "0036sv1sc4ddf8mv8f8j9ifqzl3fhvsbri4z1kppn0f1zk6jv9yi";
  };
  nixpkgs = import nixpkgsTarball (system // { overlays = [overlay] ++ overlays;} );
in
with nixpkgs; rec {
  inherit  modules system nixpkgs;

  mergeModules = ms:
    let extend = lhs: rhs: lhs // rhs lhs;
    in lib.fix (self: lib.foldl extend {}
                  (map (x: x self) (map (f: f nixpkgs) ms)));

  monitrc = pkgs.callPackage ./monitrc.nix;

  emptyConfig = {
    interfaces = {};
    etc = {};
    users = [ ];

    # Packages in this list will have symlinks in /bin added to their
    # binaries in the store path. Packages which are dependencies of
    # packages listed here will be available in the store but will not
    # have symlinks
    packages = [ ];

    # default busybox config is quite minimal but you can add applets here
    busybox = { applets = []; };

    filesystems = {} ;
  };

  rootfs = configuration: pkgs.callPackage ./rootfs-image.nix {
    busybox = configuration.busybox.package;
    monitrc = (monitrc configuration);
    inherit configuration;
  };

  firmware = configuration:
    pkgs.callPackage ./firmware.nix {
      kernelImage = configuration.kernel.package;
      rootImage = rootfs configuration;
    };
}
