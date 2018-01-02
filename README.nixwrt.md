# What is it?

An experiment, currently, to see if Nixpkgs is a good way to build an
OS for a domestic wifi router of the kind that OpenWRT or DD-WRT or
Tomato run on.

* nixwrt.nix contains the derivation which will eventually produce a
  firmware router image
  
* everything else is a lightly forked (I hope and expect that I can
  upstream it) nixpkgs with a few changes I've had to make for
  cross-compiling some packages

# Status/TODO

## Using QEMU

- [x] builds a kernel
- [x] builds a root filesystem
- [x] mounts the root filesystem
- [x] statically linked init (busybox) runs
- [x] make shared libraries work
- [ ] convert to musl or uclibc
- [ ] reasonable user environment

## On real hardware

- [x] builds a kernel
- [x] builds a root filesystem
- [ ] mounts the root filesystem
- [ ] ethernet driver

Currently: it can see the root fs is there and contains a squashfs
image, but it does not want to boot it: instead it hangs and/or resets
after printing

```
ar933x-uart: ttyATH0 at MMIO 0x18020000 (irq = 11, base_baud = 1562500) is a ART
console [ttyATH0] enabled
console [ttyATH0] enabled
bootconsole [early0] disabled
bootconsole [early0] disabled
phram: rootfs device: 0x900000 at 0x81178000
ehci_hcd: USB 2.0 'Enhanced' Host Controller (EHCI) Driver
ehci-pci: EHCI PCI platform driver
ehci-platform: EHCI generic platform driver
ohci_hcd: USB 1.1 'Open' Host Controller (OHCI) Driver
ohci-pci: OHCI PCI platform driver
ohci-platform: OHCI generic platform driver
NET: Registered protocol family 17
```

I suspect the tty is in some way part of the problem, because if I
give it an incorrect `console=` entry it gets further


```
ohci-platform: OHCI generic platform driver
NET: Registered protocol family 17
Warning: unable to open an initial console.
VFS: Mounted root (squashfs filesystem) readonly on device 31:0.
Freeing unused kernel memory: 208K
This architecture does not have kernel memory protection.
Kernel panic - not syncing: Attempted to kill init! exitcode=0x00000000
```


# How to run it

## With QEMU

    nix-build ./nixwrt.nix -A tftproot -o malta --argstr target malta
    nix-shell  -p qemu --run "qemu-system-mipsel  -M malta -m 64 -nographic -kernel malta/vmlinux   -append 'root=/dev/sr0 console=ttyS0 init=/bin/sh' -blockdev driver=file,node-name=squashed,read-only=on,filename=malta/rootfs.image -blockdev driver=raw,node-name=rootfs,file=squashed,read-only=on -device ide-cd,drive=rootfs -nographic" 


## On real hardware

This is a little more complicated ...

_[ Note that As of Tue Jan  2 23:11:48 2018 this doesn't entirely work ]_

### Preparation

* Get an Arduino Yun: this is the initial target for no better reason
than that I have one and the USB device interface on the Atmega side
makes it easy to test with.  The Yun is logically a traditional
Arduino bolted onto an Atheros 9331 by means of a two-wire serial
connection: we target the Atheros SoC and use the Arduino MCU as a
USB/serial converter.  The downside of this SoC, however, is that _it
currently appears_ that mainstream Linux has no support for its
Ethernet device.

* In order to talk to the Atheros over a serial connection, upload
https://www.arduino.cc/en/Tutorial/YunSerialTerminal to your Yun using
the standard Arduino IDE.  Once the sketch is running, rather than
using the Arduino serial monitor as it suggests, I run minicom on
`/dev/ttyACM0`

* install a TFTP server (most convenient if this is on your build
machine itself)

* acquire a static IP address for your Yun, and find otu the address of
your TFTP server.  In my case these are 192.168.0.251 and 192.168.0.2

### Installation

Build the derivation and copy the result into your tftp server data
directory:

    nix-build nixwrt.nix -A tftproot -o yun --argstr target yun
    rsync -a yun/ /tftp/ # or wherever

On a serial connection to the Yun, get into the U-Boot monitor
(hit YUN RST button, then press RET a couple of times - or in newer
U-Boot versions you need to type `ard` very quickly -
https://www.arduino.cc/en/Tutorial/YunUBootReflash may help)
Once you have the `ar7240>` prompt, run

    setenv serverip 192.168.0.2 
    setenv ipaddr 192.168.0.251 
    setenv kernaddr 0x81000000
    setenv rootaddr 1178000
    setenv rootaddr_useg 0x$rootaddr
    setenv rootaddr_ks0 0x8$rootaddr
    setenv bootargs keep_bootcon console=ttyATH0,250000 panic=10 oops=panic init=/bin/sh phram.phram=rootfs,$rootaddr_ks0,9Mi root=/dev/mtdblock0 memmap=10M\$$rootaddr_useg
    setenv bootn "tftp $kernaddr /tftp/kernel.image ; tftp $rootaddr_ks0 /tftp/rootfs.image; bootm  $kernaddr"
    run bootn
    
substituting your own IP addresses where appropriate.  The constraints
on memory addresses are as follows

* the kernel and root images don't overlap, nor does anything encroach
  on the area starting at 0x8006000 where the kernel will be
  uncompressed to
* the memmap parameter in bootargs should cover the whole rootfs image




