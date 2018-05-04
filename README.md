# What is it?

An experiment, currently, to see if Nixpkgs is a good way to build an
OS for a domestic wifi router of the kind that OpenWRT or DD-WRT or
Tomato run on.

# Milestones/initial use cases

* Milestone 0 ("what I came in for"): backup server on GL-MT300A
"travel router" (based on Mediatek MT7620A) with attached USB disk.

* Milestone 1: replace the OS on the wireless access point in the
  study - Trendnet TEW-731BR, based on  Atheros AR9341 

* Milestone 2: IP camera with motion detection on Raspberry Pi (note this is ARM not MIPS)

* Milestone 3: replace the 
  [GL-MT300N router](https://www.gl-inet.com/mt300n/)  attached to my DSL modem

# How to build it

Please note: for ease of development/testing, the NixWRT build
presently produces separate kernel image and root fileystem images,
which you are expected to load into your device's RAM using TFTP.
All-in-one flashable images for "production" use are still a TODO
item.

Clone the nixwrt repo, and also the nixpkgs fork on which it depends

    $ git clone git@github.com:telent/nixwrt
    $ git clone --branch everything git@github.com:telent/nixpkgs.git nixpkgs-for-nixwrt
    $ cd nixwrt

The best way to get started is to read `backuphost.nix`, which is a
souple of magic imports followed by an attrset of things that need
building (kernel, root fs image, anything else you want in your
image). Most of the work in supporting a new device is probably in the
`kernel` derivation, and most of the work in supporting new userland
stuff is in `rootfs`, which generates a squashfs image based on a big
attrset called `configuration` with keys such as `interfaces`,
`users`, `packages`, `services` etc that describe what you want to go
into the image.

So, build the derivation and copy the result into your tftp server data
directory:

    $ nix-build -I nixpkgs=../nixpkgs-for-nixwrt/ backuphost.nix -A tftproot --argstr targetBoard $BOARD -o $BOARD
    $ rsync -cIa $BOARD $TFTP_SERVER_ROOT # -I to ignore timestamps when comparing

`$BOARD` is currently one of `mt300a` (works), `yun` (doesn't build) or
`malta` (works, but no networking)

This should leave you with two files in `result/`: `kernel.image` and `rootfs.image`


# How to run it

## General tips

To avoid having to reflash the device every time we make a change, we
use
the
[phram driver](https://github.com/torvalds/linux/blob/3a00be19238ca330ce43abd33caac8eff343800c/drivers/mtd/devices/Kconfig#L140) to
emulate flash using system RAM, and read the kernel/root file system
into memory over TFTP.  This means you will need

* a TFTP server
* a way to get into the bootloader (which is probably some variety of
  U-Boot) on your device 
* enough RAM on the device that it's still functional even after 4MB
  or so is eaten by the filesystem and kernel image
* static IP addresses (on your local network - not necessarily
  globally reachable).  In the examples that follow, we will use 
  192.168.0.251 for the device and 192.168.0.2 for the TFTP server

## On a GL-Inet GL-MT300A

The GL-Inet pocket router range makes nice cheap hardware for playing
with NixWRT or similar projects.  The manufacturers seem open to the
DIY market, and the devices have a reasonable amount of RAM and are
much easier to get serial connections than many COTS routers.
GL-MT300A is my current platform for NixWRT development.

Wire up the serial connection: this probably involves opening the box, locating
the serial header pins (TX, RX and GND) and connecting a USB TTL
converter - e.g. a PL2303 based device - to it.  The
[defunct OpenWRT wiki](https://wiki.openwrt.org/toh/gl-inet/gl-mt300a#opening_the_case) has
a guide with some pictures.  (If you don't have a USB TTL converter to
hand, other options are available.  For example, use the GPIO pins on
a Raspberry Pi)
  
Run a terminal emulator such as Minicom on whatever is on the other
end of the link. I use 115200 8N1 and find it also helps to set
"Character tx delay" to 1ms, "backspace sends DEL" and "lineWrap on".

When you turn the router on you should be greeted with some messages
from U-Boot and a little bit of ASCII art, followed by the instruction
to hit SPACE to stop autoboot.  Do this and you will get a
`gl-mt300a>` prompt.

Run these commands :

    gl-mt300a> setenv serverip 192.168.0.2
    gl-mt300a> setenv ipaddr 192.168.0.251
    gl-mt300a> setenv kernaddr 0x81000000
    gl-mt300a> setenv rootaddr 0x2000000
    gl-mt300a> tftp ${rootaddr} /tftp/rootfs.image ; tftp ${kernaddr} /tftp/kernel.image ; bootm  ${kernaddr}

and you should see the kernel and rootfs download and boot.

### Writing to flash

If you're sure you want to toast a perfectly good OpenWRT installation
... read on.  I accept no responsibility for anything bad that might
happen as a result of following these instructions.

This procedure is new and experimental and works on my machine.  There
are a number of magic numbers which are most likely correct if you
have the same hardware as I have and almost certainly incorrect if you don't.

#### Build a flashable image

```
$ nix-build -I nixpkgs=../nixpkgs-for-nixwrt/ backuphost.nix \
 -A firmwareImage --argstr targetBoard mt300a -o mt300a.bin
$ cp mt300a.bin /tftp
```

#### Flash it

```
setenv serverip 192.168.0.2 
setenv ipaddr 192.168.0.251 
tftp 0x80060000 /tftp/mt300a.bin
erase 0xbc050000 0xbcfd0000
cp.b 0x80060000 0xbc050000 ${filesize};
```

Next time you reset the device it *should* come up in NixWRT.  For
more details refer to https://ww.telent.net/2018/4/16/flash_ah_ah

## On an Arduino Yun

[ This is slightly broken right now but will return ]

Arduino Yun was the initial target for no better reason than that I
had one to hand, and the USB device interface on the Atmega side makes
it easy to test with.  The Yun is logically a traditional Arduino
bolted onto an Atheros 9331 by means of a two-wire serial connection:
we target the Atheros SoC and use the Arduino MCU as a USB/serial
converter.

* In order to talk to the Atheros over a serial connection, upload
https://www.arduino.cc/en/Tutorial/YunSerialTerminal to your Yun using
the standard Arduino IDE.  Once the sketch is running, rather than
using the Arduino serial monitor as it suggests, I run Minicom on
`/dev/ttyACM0`

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
    setenv bootargs  console=ttyATH0,115200 panic=10 oops=panic init=/bin/init phram.phram=rootfs,$rootaddr_ks0,10Mi root=/dev/mtdblock0 memmap=11M\$$rootaddr_useg ath79-wdt.from_boot=n ath79-wdt.timeout=30 ethaddr=90:A2:DA:F9:07:5A machtype=AP121
    setenv bootn " tftp $rootaddr_ks0 /tftp/rootfs.image; tftp $kernaddr /tftp/kernel.image ; bootm  $kernaddr"
    run bootn
    
substituting your own IP addresses where appropriate.  (This is a bit
more text than on the GL-MT300A, because that device has a broken
U-boot install which means we have to bake the command line into the
image.  The Yun has no such restriction)

The constraints on memory addresses are as follows

* the kernel and root images don't overlap, nor does anything encroach
  on the area starting at 0x8006000 where the kernel will be
  uncompressed to
* the memmap parameter in bootargs should cover the whole rootfs image

The output most probably will change to gibberish partway through
bootup.  This is because the kernel serial driver is running at a
different speed to U-Boot, and you need to change it (if using the
YunSerialTerminal sketch, by pressing `~1` or something along those
lines).

## On QEMU ("malta")

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




# Troubleshooting

If it doesn't work, you could try

* changing `init=/bin/init` to `init=/bin/sh`.  Sometimes the ersatz
  edifice of string glommeration that creates the contents of `/etc`
  goes wrong and generates broken files or empty files or no files.
  This will give you a root shell on the console with which you can
  poke around
* On Atheros-based devices (the Yun) changing `ath79-wdt.from_boot=n` to `ath79-wdt.from_boot=y`: this
  will cause the board to reboot after 21 seconds, which is handy if
  it's wedging during the boot process - especially if you're not
  physically colocated with it.
  
# Feedback

Is very welcome.  Please open an issue on Github for anything that 
involves more than a line of text, or find me in the
"Fediverse" [@telent@maston.social](https://mastodon.social/@telent) 
or on Twitter [@telent_net](https://twitter.com/telent_net) if not

I do occasionally hang out on #nixos IRC as `dan_b` or as `telent` but
not often enough to make it a good way of getting in touch.
