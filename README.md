
![status: works on my machine](https://img.shields.io/badge/status-works%20on%20my%20machine-green.svg)

# What is this?

An experiment, currently, to see if Nixpkgs is a good way to build an
OS for a domestic wifi router or IoT device, of the kind that OpenWrt
or DD-WRT or Tomato run on.

This is not NixOS-on-your-router.  This is an immutable "turnkey"
image that can be flashed onto a router (or other IoT device), built
using the Nix language and the Nix package collection.

## "Supported" hardware

We use the OpenWrt kernel sources (approximately), so it should be not
impossible to get anything working that they have already ported to. I use

- devices based on Mediatek MT7620 and MT7628 (GL-MT300A and GL-MT300N-v2)
- devices based on Atheros ath79 (as of Oct 2020, GL-AR750)
- Qemu, for quick and easy testing of userland changes without real hardware

Previously we built on some ar71xx devices as well (Trendnet
TEW-731BR/Atheros AR9341 and Arduino Yun/AR9331) but support for those
has not been brought forwards to kernel 5.x as I don't have hardware
(or inclination) to test them. Anything that was previously supported
by ar71xx *should* be buildable with ath79, but may require more or
less faff to port depending on whether someone else has written the
device tree for it already.

## Applications and use cases (former, current and prospective)

* Working: Rsync backup server (see examples/arhcive.nix)

* Working: Wireless extender (see examples/{extensino.nix,upstaisr.nix}

* WIP: PPPoE router/access point (examples/defalutroute.nix)


# What's it made of?

## The Nix Package Collection

As of March 2021 it has been tested with nixpkgs master git rev
ad47284f8b01f, which at the time of writing was the latest commit on
nixos-unstable to have built on Hydra. If you're using a later or
earlier version, your mileage may vary.

## a Nixpkgs overlay

In `nixwrt/overlay.nix` we create a couple of new derivations that
don't exist in nixpkgs, and customize a few others for smaller size or
to fix cross-compilation bugs.  Where possible and when time is
available these changes will be pushed upstream.

## a module-based configuration system

A NixWRT image is created by passing a `configuration` attrset to a
derivation that creates a root filesystem image based on that
configuration, then does further work to build a suitable kernel and
glue it all together into a binary that you can flash onto your
router.

Conventionally, you create that configuration by starting with a
fairly bare bones attrset that defines a few files and network
interface names, then pass it in turn to a number of _modules_ which
augment it with the features your application needs.  There are a
number of pre-written modules to add support for things like ntpd and
ssh server, more will be added over time (that's not a promise, but
somewhere between a prediction and a prophecy), and you can write your
own (details later).  If you write your own and then send pull
requests, you will have helped fulfill the prophecy.

# How to build it

## One-time setup

You will need

* a target device (unless you only want to run it on Qemu). I have
  used various of the cheap "travel routers" from
  [GL.iNet](https://www.gl-inet.com/) because they're cheap and
  hobbyist-friendly and they have adequate RAM.

* some kind of PC or other reasonably well-powered machine to build
  everything on.  This is entirely cross-compiled, there is no
  development on the target.  I do it all under NixOS, but any system
  with Nix installed should work - I tried it successfully in a
  [Docker container](https://github.com/LnL7/nix-docker), for example

* an ethernet connecting your build machine to your target device.
  Perhaps you can put them on a LAN together, perhaps you can connect
  them directly to each other with a patch cable.  (The latter is a
  good idea if you plan to test things like DHCP servers on the
  target, otherwise they may start answering IP address requests for
  other hosts on your LAN).  Ideally you want statically allocated IP
  addresses for the build machine and target, because U-Boot probably
  won't work with DHCP.

  * Provided without warranty is nol.nix, a script I use on my build
    machine to provide better isolation between my real LAN and my
    test network.  It generates a QEMU VM which I run with PCI
    passthru so that it has exclusive access to my second network card.
    It may or may not work for you, but feel free to adapt or use it
    for inspiration

* access to your target devices's boot monitor (usually U-Boot).  This
  will very often involve opening it up and attaching a USB serial
  convertor to some header pins: sometimes it involves soldering those
  pins into holes.  On other devices it's not nearly as complicated as
  you can access U-Boot across the network. The OpenWrt wiki is often
  very helpful here.

Now, clone the nixwrt repo, and also the nixpkgs revision on which it depends

    $ git clone git@github.com:telent/nixwrt
    $  git clone -n  git@github.com:nixos/nixpkgs.git && \
       (cd nixpkgs && git checkout bc675971dae581ec653fa6)
    $ cd nixwrt

The best way to get started is to look at one of the examples in
`examples/` and choose the one which has most similar hardware to the
device you want to use and ideally which has most recently been
updated.  There should be advisory and/or warning comments at the top of each.

Each example has a quite similar structure: (a) boilerplate, (b) a
base `configuration`, (c) an array of `wantedModules`, and (d) two
targets `firmware` and `phramware` which build firmware images.


## Build it

There is a Makefile to help you get started on building any of the examples.
To build the `extensino` example, run 

    $ make extensino SSID=mysid PSK=db6c814b6a96464e1fa02efabb240ce8ceb490ddce54e6dbd4fac2f35e8184ae image=phramware
    
This should create a file `extensino/firmware.bin` which you need
to copy to your TFTP server.

Caveat: the makefile is a convenience thing for hacking/testing and
not intended as the nucleus of any kind of production build pipeline.
If you want something to build on for large-scale deploys, write
something that invokes nix-build directly.


## Running it from RAM

The image you just built is configured to run from RAM
without needing to write to the router flash memory.  This is great
when you're testing things and don't want to keep erasing the flash
(because it takes a long time and because it has limited write
cycles).  It's not great when you want to do a permanent installation,
because the router RAM contents don't survive a reset.  It uses the
[phram driver](https://github.com/torvalds/linux/blob/3a00be19238ca330ce43abd33caac8eff343800c/drivers/mtd/devices/Kconfig#L140)
to emulate flash using system RAM.

Instructions vary depending on your device, but on my GL-Inet MT300N
v2, I reset the router, hit RETURN when it says

    Hit any key to stop autoboot: 2

and then type the following commands at the uboot `gl-mt300an>` prompt:

    setenv serverip 192.168.0.2
    setenv ipaddr 192.168.0.251
    setenv startaddr a00000
    setenv startaddr_useg 0x${startaddr}
    setenv startaddr_ks0 0x8${startaddr}
    setenv dir /tftp/extensino
    tftp ${startaddr_ks0} ${dir}/firmware.bin ; bootm ${startaddr_useg}

Depending on your network and tftp configuration, you probably need to
change IP addresses and paths here.  The `startaddr` must be some
location in ordinary RAM (i.e. not flash) that doesn't conflict with
the area starting at 0x6000 to which the kernel is uncompressed.
0xa00000 (and 0x8a00000 which is the same physical RAM but differently
mapped) seems to do the job.


## Making it permanent (flashable image)

If you're sure you want to toast a perfectly good OpenWrt installation
... read on.  I accept no responsibility for anything bad that might
happen as a result of following these instructions.

### The moderately straightforward way

If you have a working NixWRT with a running ssh daemon (usually by
including the `sshd` module) and the `flashcp` busybox app (currently
this is installed by default) you can install a new image from inside the running system without recourse to any U-Boot/serial connection shenanigans.  This is a win when you've deployed the device and don't wish to pop the top off.

Step 1: Build the regular (non-phram) firmware

    $ make extensino SSID=mysid PSK=db6c814b6a96464e1fa02efabb240ce8ceb490ddce54e6dbd4fac2f35e8184ae image=firmware

Step 2: copy it onto the device

    $ cat extensino/firmware.bin | ssh root@extensino.lan 'cat > /tmp/nixwrt.bin'

Step 3: ssh into the device and write it to the `firmware` mtd partition.  Note: the _real_ firmware partition, not the emulated phram one.

    # cat /proc/mtd
    dev:    size   erasesize  name
    mtd0: 00030000 00001000 "u-boot"
    mtd1: 00010000 00001000 "u-boot-env"
    mtd2: 00010000 00001000 "factory"
    mtd3: 00f80000 00001000 "firmware"
    mtd4: 00220000 00001000 "kernel"
    mtd5: 00d60000 00001000 "rootfs"
    mtd6: 00b57000 00001000 "rootfs_data"
    mtd7: 00010000 00001000 "art"

    # flashcp -v /tmp/nixwrt.bin /dev/mtd3

Step 4: reboot the device

    # reboot

### The complicated way

_This procedure is a good way to brick your router if you get it
wrong. Do not follow it blindly without making some attempt to
understand if it'll work for you_.  There are a number of magic
numbers which are most likely correct if you have the same hardware as
I have and almost certainly incorrect if you don't.

#### Find the flash address

You will need to find the address of your flash chip.  If you don't
know you can probably make a reasonable guess: either use the U-boot
`flinfo` command if your router has it, or otherwise my suggestion is
to look at the boot log for a line of the form `Booting image at
9f070000` and then double check by looking at the output of `cat
/proc/mtd` in OpenWrt and see if there's a partition starting at
`0x70000`.  If you get this wrong you may brick your device, of
course.

#### Build the regular (non-phram) firmware

    $ make extensino SSID=mysid PSK=db6c814b6a96464e1fa02efabb240ce8ceb490ddce54e6dbd4fac2f35e8184ae image=firmware

Now do whatever you need to make it available to the TFTP server.

#### Flash it

Get into u-boot, then do something like this

    setenv serverip 192.168.0.2
    setenv ipaddr 192.168.0.251
    erase 0xbc050000 0xbcfd0000
    setenv dir /tftp/extensino
    tftp 0x80060000 ${dir}/firmware.bin
    cp.b 0x80060000 0xbc050000 ${filesize}

The magic numbers here are

- 0x80060000 : somewhere in RAM, not critical
- 0xbc050000 : flash memory address for "firmware" partition (as per `nixwrt/devices.nix`)
- 0xbcfd0000 : end of flash firmware partition image

If that looked like it worked, type `reset` to find out if you were right.


## Running it in Qemu

The build process for Qemu is subtly different because Qemu wants an
ELF kernel image and a root filesystem instead of a combined firmware
image, and also because Qemu doesn't appear to support device trees. 

    $ make emu LOGHOST=loghost.lan image=emulator
    $ nix run nixpkgs.qemu -c sh emu/bin/emulator 


## Troubleshooting

* if the kernel boots but gets stuck where the userland should be
  starting, you could try changing `init=/bin/init` to `init=/bin/sh`.
  Sometimes the ersatz edifice of string glommeration that creates the
  contents of `/etc` goes wrong and generates broken files or empty
  files or no files.  This will give you a root shell on the console
  with which you can poke around

* or use [Binwalk](https://github.com/ReFirmLabs/binwalk) to unpack
  the image on the host

* There is a `syslog` module: if it seems to work mostly but services
  are failing and you think they may be generating error messages, add
  the syslog module to your config and point it at a syslog server.
  Configuring the syslog server is outside the scope of this README,
  but essentially it needs to be able to receive UDP on port 514.  I
  use [RSYSLOG](https://www.rsyslog.com/): other choices are
  available.

* I find a remote-controlled power switch is invaluable. You might too.
  See [here](https://ww.telent.net/2018/7/20/power_play) or [here](https://ww.telent.net/2019/11/18/got_the_power)

# Feedback

Is very welcome.  Please open an issue on Github for anything that
involves more than a line of text, or find me in the "Fediverse"
[@dan@terse.telent.net](https://terse.telent.net) (preferred) or on
Twitter [@telent_net](https://twitter.com/telent_net) (less preferred)
if not.

I do occasionally hang out on #nixos IRC as `dan_b` or as `telent` but
not often enough to make it a good way of getting in touch.
