{ overlays ? []
, endian }:
let
  overlay = import ./overlay.nix;
  modules = import ./modules/default.nix;
  system = (import ./mksystem.nix) { inherit endian; };

  pinnedNixpkgs = builtins.fetchTarball {
    name = "nixos-unstable";
    url = "https://github.com/nixos/nixpkgs/archive/2deb07f3ac4eeb5de1c12c4ba2911a2eb1f6ed61.tar.gz";
    # Hash obtained using `nix-prefetch-url --unpack <url>`
    sha256 = "0036sv1sc4ddf8mv8f8j9ifqzl3fhvsbri4z1kppn0f1zk6jv9yi";
  };
  fromEnvNixpkgs = builtins.getEnv "NIXPKGS";
  nixpkgsSource = if (fromEnvNixpkgs != "") then fromEnvNixpkgs else pinnedNixpkgs;
  nixpkgs = import nixpkgsSource (system // { overlays = [overlay] ++ overlays;} );
in
with nixpkgs; rec {
  inherit  modules system nixpkgs;

  mergeModules = ms:
    let extend = lhs: rhs: lhs // rhs lhs;
    in lib.fix (self: lib.foldl extend {}
                  (map (x: x self) (map (f: f nixpkgs) ms)));

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
    monitrc = ((pkgs.callPackage ./monitrc.nix) configuration);
    inherit configuration;
  };

  firmware = configuration:
    pkgs.callPackage ./firmware.nix {
      kernelImage = configuration.kernel.package;
      rootImage = rootfs configuration;
    };

  emulator = configuration : writeScript "emulator" ''
    #!${stdenv.shell}
    rootfs=${rootfs configuration}/image.squashfs
    vmlinux=${configuration.kernel.package}/vmlinux
    dtb=${configuration.kernel.package}/kernel.dtb
    set +x
    ${nixpkgs.pkgsBuildBuild.qemu}/bin/qemu-system-mips  -M malta -m 128 -nographic  -kernel ''$vmlinux \
      -append ${builtins.toJSON configuration.boot.commandLine} \
      -netdev user,id=mynet0,net=10.8.6.0/24,dhcpstart=10.8.6.4 \
      -device virtio-net-pci,netdev=mynet0 \
      -drive if=virtio,readonly=on,file=''$rootfs \
        -nographic
  '';

  secret = name: let a = builtins.getEnv name;
                 in assert (a != "") ||
                           throw "no environent variable ${builtins.toJSON name}"; a;
}
