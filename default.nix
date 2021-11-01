{endian} : let nixwrt = (import <nixwrt>) { inherit endian; }; in
with nixwrt.nixpkgs;
let
  modules = import <nixwrt-config> { inherit lib nixwrt; };
  allConfig = nixwrt.mergeModules modules;
  qemu = nixwrt.nixpkgs.pkgsBuildBuild.qemu;
in rec {
  emulator = writeScript "emulator" ''
    #!${stdenv.shell}
    rootfs=${nixwrt.rootfs allConfig}/image.squashfs
    vmlinux=${allConfig.kernel.package}/vmlinux
    dtb=${allConfig.kernel.package}/kernel.dtb
    set +x
    ${qemu}/bin/qemu-system-mips  -M malta -m 128 -nographic  -kernel ''$vmlinux \
      -append ${builtins.toJSON allConfig.boot.commandLine} \
      -netdev user,id=mynet0,net=10.8.6.0/24,dhcpstart=10.8.6.4 \
      -device virtio-net-pci,netdev=mynet0 \
      -drive if=virtio,readonly=on,file=''$rootfs \
        -nographic
  '';

  firmware = nixwrt.firmware allConfig;

  # phramware generates an image which boots from the "fake" phram mtd
  # device - required if you want to boot from u-boot without
  # writing the image to flash first
  phramware =
    let phram_ = (nixwrt.modules.phram {
          offset = "0xa00000"; sizeMB = "7";
        });
    in nixwrt.firmware (nixwrt.mergeModules [allConfig phram_]);

}
