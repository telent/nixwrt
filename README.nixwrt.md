# NixWRT

An experiment, currently, to see if Nixpkgs is a good way to build an
OS for a domestic wifi router of the kind that OpenWRT or DD-WRT or
Tomato run on.

* nixwrt.nix contains the derivation which will eventually produce a
  firmware router image
  
* everything else is a lightly forked (I hope and expect that I can
  upstream it) nixpkgs with a few changes I've had to make for
  cross-compiling some packages

## Status/TODO

- [x] builds a kernel
- [x] builds a root filesystem
- [x] statically linked init (busybox) runs
- [ ] make shared libraries work

Currently: There is a problem with squashfs or the way we are using it
which means that `/nix/store` is empty when the squashfs image is
mounted (the `-root-becomes` option doesn't appear to work).  This is
an obvious cause of shared libraries not working - because they're not
there.


## How to build it

    nix-build nixwrt.nix -A image -o image
    nix-build nixwrt.nix -A kernel -o kernel
    
## How to run it

    nix-shell '<nixpkgs>' -p qemu --run "qemu-system-mipsel  -M malta -m 512 -kernel kernel/vmlinux  -append 'root=/dev/sr0 console=ttyS0 init=/bin/sh' -blockdev driver=file,node-name=squashed,read-only=on,filename=image/image.squashfs -blockdev driver=raw,node-name=rootfs,file=squashed,read-only=on -device ide-cd,drive=rootfs -nographic"

# Real hardware

Initial target is the Arduino Yun because I have one and because the
USB gadget interface on the Atmega side makes it easy to test with.
The Yun is logically a traditional Arduino bolted onto an Atheros 9331
by means of a two-wire serial connection: we're going to target the
Atheros SoC and use the Arduino MCU as a USB/serial converter 

## Invoking the kernel

* You need a tftp server, and you need to choose a static IP address
  for your Yun.  In my case these are 192.168.0.2 and 192.168.0.251

* When developing remotely there is no easy way to hard-reset the Linux
half of the Yun.  To mitigate, be sure to start the kernel with 
panic=10 oops=panic

* To talk to the Atheros over a serial connection, upload
  https://www.arduino.cc/en/Tutorial/YunSerialTerminal to your Yun
  using the standard Arduino IDE.  Once the sketch is running, rather
  than using the Arduino serial monitor as it suggests, I run minicom
  on `/dev/ttyACM0`

On your build machine, copy the files to somewhere the tftp server
can see them
  
    cp kernel/uImage.lzma image/image.squashfs /tftp

On a serial connection to the Yun, get into the U-Boot monitor
(hit YUN RST button, then press RET a couple of times - or in newer
U-Boot versions you need to type `ard` very quickly -
https://www.arduino.cc/en/Tutorial/YunUBootReflash may help)
Once you have the `ar7240>` prompt, run

    setenv serverip 192.168.0.2 ; setenv ipaddr 192.168.0.251 ; setenv bootargs console=ttyS0 panic=10 oops=panic init=/bin/sh ; tftp 0x81060000 /tftp/uImage.lzma ; bootm   0x81060000

substituting your own IP addresses where appropriate.  0x81060000 is
an address I chose at random which (I hope) exists and is sufficiently
greater than 0x80060000 that the uncompressed kernel doesn't overwrite
the compressed kernel.

# Testing with nfs root

On the build system (or anywhere with access to the artifacts), create
the nfs root by unpacking the squashfs image

    sudo nix-shell '<nixpkgs>'  -p squashfsTools --run "mkdir -p /tmp/yun-root && cd /tmp/yun-root &&  unsquashfs `pwd`/result/image.squashfs" 

and start an nfs server

    nix-shell '<nixpkgs>' -p  unfs3 --run "unfsd -d -u -e `pwd`/exports.nfs -p -s "

Now at the arduino `ar7240>` u-boot  prompt, run 

    setenv serverip 192.168.0.2 ; setenv ipaddr 192.168.0.251 ; setenv bootargs console=ttyS0 panic=10 oops=panic init=/bin/sh root=/dev/nfs rw nfsroot=192.168.0.2:/tmp/yun-root/squashfs-root,port= ip=192.168.0.251:192.168.0.2 ; tftp 0x81060000 /tftp/uImage.lzma ; bootm   0x81060000

(tip if you're using Minicom: I found that pasted long lines like
that one tended to get scrambled until I pressed `C-a t f` and
changed the "Character tx delay" to about 2ms)

