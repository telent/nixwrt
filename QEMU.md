# On QEMU ("malta")

There is limited and probably bitrotten support for running on emulated MIPS using Qemu

Once you've built the nix `tftproot` derivation, start Qemu:

```
nix-shell  -p qemu --run "qemu-system-mips  -M malta -m 128 -nographic -kernel malta/kernel.image -virtfs local,path=`pwd`,mount_tag=host0,security_model=passthrough,id=host0   -append 'root=/dev/sr0 console=ttyS0 init=/bin/init' -blockdev driver=file,node-name=squashed,read-only=on,filename=malta/rootfs.image -blockdev driver=raw,node-name=rootfs,file=squashed,read-only=on -device ide-cd,drive=rootfs -nographic"
```

This shares the current directory with the virtual MIPS system via 9p,
so once booted you can run

    mkdir /run/mnt
    mount -t 9p -o trans=virtio,version=9p2000.L host0 /run/mnt

which is very handy if you want to rebuild binaries with debug printfs
inserted.


