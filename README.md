![status: works on my machine](https://img.shields.io/badge/status-works%20on%20my%20machine-green.svg)

# What is it?

An experiment, currently, to see if Nixpkgs is a good way to build an
OS for a domestic wifi router or IoT device, of the kind that OpenWRT
or DD-WRT or Tomato run on.

This is not NixOS-on-your-router.  This is an immutable "turnkey"
image that can be flashed onto a router (or other IoT device), built
using the Nix language and the Nix package collection.

## Applications and use cases (current and prospective)

* Milestone 0: backup server on GL-MT300A
"travel router" (based on Mediatek MT7620A) with attached USB disk.
This works now.

* Milestone 1: replace the OS on the wireless access point in the
  study - Trendnet TEW-731BR, based on  Atheros AR9341.  This works now.

* Milestone 2: replace the OS running on the
  [GL-MT300N router](https://www.gl-inet.com/mt300n/) attached to my DSL modem

* Milestone 3: IP camera with motion detection on Raspberry Pi (note
  this is ARM not MIPS)

* Milestone 4: put a lot of GPIOs in my cheap robot vacuum cleaner and
  turn it into a smart robot vacuum cleaner.  Probably never get to
  this.

# What's it made of?

## The Nix Package Collection

As of June 2018 it requires a lightly forked nixpkgs, but I am working
to feed changes back upstream.

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

First, set up a TFTP server.

Then, allocate yourself (or request from your IT support if you're in
the kind of place that has that kind of thing) a static IP address on
your local network.  It need not be globally reachable, it just has to
be something that will let your device see its TFTP server.  If your
router boot monitor has DHCP support you won't even need one, but I
haven't yet seen a device that does this.  In the examples that
follow, we will use 192.168.0.251 for the device and 192.168.0.2 for
the TFTP server.

Then, find out how to get into your router's boot monitor.  This will
very often involve opening it up and attaching a USB serial convertor
to some header pins: sometimes it involves soldering those pins into
holes.  On other machines it's not nearly as complicated as you can
access u-boot across the network.  The OpenWRT wiki is often very helpful here.

Next, clone the nixwrt repo, and also the nixpkgs fork on which it depends

    $ git clone git@github.com:telent/nixwrt
    $ git clone git@github.com:telent/nixpkgs.git nixpkgs-for-nixwrt
    $ cd nixwrt

The best way to get started is to read `backuphost.nix`, which
consists of (a) boilerplate, (b) a base `configuration`, (c) an array
of `wantedModules`, and (d) two targets `firmware` and `phramware`
which build firmware images.


## Build it

Building the `phramware` derivation, and copy the result into your tftp
server data directory: there is a Makefile which Works For Me but you
may need to adjust pathnames and stuff.

    $ make t=mt300n_v2 d=backuphost TFTPROOT=/tftp phramware
             ^         ^
             |         +--- use file "backuphost.nix"        }  change to match
             +------------- use "mt300n_v2" from devices.nix }  your setup

This should create a file `mt300n_v2_backuphost/firmware.bin` and copy it to
`/tftp`

## Running it from RAM

The `phramware` image you just built is configured to run from RAM
without needing to write to the router flash memory.  This is great
when you're testing things and don't want to keep erasing the flash
(because it takes a long time and because it has limited write
cycles).  It's not great when you want to do a permanent installation
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
    setenv dir /tftp/mt300n_v2_backuphost
    tftp ${startaddr_ks0} ${dir}/firmware.bin ; bootm ${startaddr_useg}

The `startaddr` must be some location in ordinary RAM (i.e. not flash)
that doesn't conflict with the area starting at 0x6000 to which the
kernel is uncompressed.  0xa00000 (and 0x8a00000 which is the same
physical RAM but differently mapped) seems to do the job.


## Making it permanent (flashable image)

If you're sure you want to toast a perfectly good OpenWRT installation
... read on.  I accept no responsibility for anything bad that might
happen as a result of following these instructions.

_This procedure is fairly new and experimental, but it works on my
machine.  Do not follow it blindly without making some attempt to
understand if it'll work for you_.  There are a number of magic
numbers which are most likely correct if you have the same hardware as
I have and almost certainly incorrect if you don't.

### Find the flash address

You will need to find the address of your flash chip.  If you don't
know you can probably make a reasonable guess: either use the U-boot
`flinfo` command if your router has it, or otherwise my suggestion is
to look at the boot log for a line of the form `Booting image at
9f070000` and then double check by looking at the output of `cat
/proc/mtd` in OpenWRT and see if there's a partition starting at
`0x70000`.  If you get this wrong you may brick your device, of
course.

### Build the regular (non-phram) firmware

    $ make t=mt300n_v2 d=backuphost TFTPROOT=/tftp firmware


### Flash it

Get into u-boot, then do something like this

    setenv serverip 192.168.0.2
    setenv ipaddr 192.168.0.251
    erase 0xbc050000 0xbcfd0000
    setenv dir /tftp/mt300n_v2_backuphost
    tftp 0x80060000 ${dir}/firmware.bin
    cp.b 0x80060000 0xbc050000 ${filesize}

The magic numbers here are

- 0x80060000 : somewhere in RAM, not critical
- 0xbc050000 : flash memory address for "firmware" partition (as per `nixwrt/devices.nix`)
- 0xbcfd0000 : end of flash firmware partition image

If that looked like it worked, type `reset` to find out if you were right.


## Upgrading without a serial console (sketchy, untested)

If you are running NixWRT, you can upgrade to a newer or different
build from within the NixWRT Linux system - e.g. using an ssh
connection into the router, without needing to access the boot
monitor.  *Note that this doesn't need the `phramware` target at any
point*.  To make this work, the firmware you're running *and* the
firmware you're upgrading to should both have been built using the
regular `firmware` target: `phramware` has boot-from-phram behaviour
hardcoded into it and won't work if flashed.

Here's how:

0. ssh into your device and become root

1. run brickwrt-reserve, passing it the device entry for your
"firmware" device.  It will reboot the router, reserving a block of
physical RAM into which you will then be able to write the new firmware

    # brickwrt-reserve /dev/mtd5

2. once the device has rebooted, get the new image onto it somehow
(e.g. with scp or curl or netcat).  Let's suppose it ends up in
`/tmp/firmware.bin`

3. run `brickwrt-load`, which will copy your new firmware into the
area of RAM you reserved in step 1, then reboot into the new kernel

    # brickwrt-load /tmp/firmware.bin

4. do whatever testing you need.  If anything doesn't behave how you want, simply do a full reboot to revert to the regular NixWRT image in flash

5. when you are ready to switch permanently to the new version, write it
to flash with `brickwrt-commit` (this bit is not implemented yet)


## Troubleshooting

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
* If it can't mount a phram rootfs this is often because you've
  enabled more kernel options causing the image size to increase,
  and the end of the kernel is overlapping the start of the rootfs.
  Check the addresses in your uboot `tftp` commands


# Feedback

Is very welcome.  Please open an issue on Github for anything that
involves more than a line of text, or find me in the
"Fediverse" [@telent@maston.social](https://mastodon.social/@telent)
or on Twitter [@telent_net](https://twitter.com/telent_net) if not.

I do occasionally hang out on #nixos IRC as `dan_b` or as `telent` but
not often enough to make it a good way of getting in touch.
