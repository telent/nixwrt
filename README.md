![status: works on my machine](https://img.shields.io/badge/status-works%20on%20my%20machine-green.svg)

# What is it?

An experiment, currently, to see if Nixpkgs is a good way to build an
OS for a domestic wifi router of the kind that OpenWRT or DD-WRT or
Tomato run on.

## What does it (will it) do?

* Milestone 0 ("what I came in for"): backup server on GL-MT300A
"travel router" (based on Mediatek MT7620A) with attached USB disk.
This works now.

* Milestone 1: replace the OS on the wireless access point in the
  study - Trendnet TEW-731BR, based on  Atheros AR9341.  This works now.
  
* Milestone 2: replace the OS running on the 
  [GL-MT300N router](https://www.gl-inet.com/mt300n/) attached to my DSL modem

  ** all the stuff in M0, M1 plus PPPoE

* Milestone 3: IP camera with motion detection on Raspberry Pi (note
  this is ARM not MIPS)
  
  ** anybody's guess what is needed here

* Milestone 4: put a lot of GPIOs in my cheap robot vacuum and turn
  it into a smart robot vacuum cleaner.  Probably never get to this.


# How it works

This is not NixOS.  This is using the Nix language and the Nix package
collection to create an immutable "turnkey" image that can be flashed
onto a router (or other IoT device) and never modified thereafter.
The ingredients are

## Nixpkgs

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

## Setting up (you will need ...)

First, set up a TFTP server.

Then, allocate yourself (or request from your IT support) a static IP
address on your local network.  It need not be globally reachable, it
just has to be something that will let your device see its TFTP
server.  If your router boot monitor has DHCP support you won't even
need one, but I haven't yet seen a device that does this.  In the
examples that follow, we will use 192.168.0.251 for the device and
192.168.0.2 for the TFTP server.

Then, find out how to get into your router's boot monitor.  This will
very often involve opening it up and attaching a USB serial convertor
to some header pins: sometimes it involves soldering those pins into
holes.  On other machines it's not nearly as complicated as you can
access u-boot across the network.  The OpenWRT wiki is often very helpful here.

Next, clone the nixwrt repo, and also the nixpkgs fork on which it depends

    $ git clone git@github.com:telent/nixwrt
    $ git clone git@github.com:telent/nixpkgs.git nixpkgs-for-nixwrt
    $ cd nixwrt

The best way to get started is to read `wap.nix`, which consists of
(a) boilerplate, (b) a base `configuration`, (c) an array of
`wantedModules`, and (d) two targets `tftproot` and `firmware`.  The
former is for experimentation and the latter is for when you are ready
to write to the router's permanent flash storage.


## Build the tftproot target

This variant of NixWRT runs from RAM and doesn't need the router to be
flashed.  This is great when you're testing things and don't want to
keep erasing the flash (because it takes a long time and because it
has limited write cycles).  It's not great when you want to do a
permanent installation because the router RAM contents don't survive a
reset.  It uses
the
[phram driver](https://github.com/torvalds/linux/blob/3a00be19238ca330ce43abd33caac8eff343800c/drivers/mtd/devices/Kconfig#L140) to
emulate flash using system RAM.

So, build the `tftproot` derivation and copy the result into your tftp
server data directory: there is a Makefile which Works For Me but you
may need to adjust pathnames and stuff.

    $ wpa_passphrase 'my wifi ssid' 'my wifi password'
    network={
        ssid="my wifi ssid"
        #psk="my wifi password"
        psk=17e3c534ff0f0fbde1a158f6980f8955cf85a496e65a0b6b97d9e6e41d7de6d9
    }
    $ make t=yun d=wap tftproot PSK=17e3c534ff0f0fbde1a158f6980f8955cf85a496e65a0b6b97d9e6e41d7de6d9

This should leave you with two files in `result/`: `kernel.image` and `rootfs.image`

## Run it

This will vary depending on your device, but on my TrendNET TEW712BR I
reset the router, hit RETURN when it says

    Hit any key to stop autoboot: 2
    
and then type the following commands at the `ar7240>` prompt:

    setenv serverip 192.168.0.2 
    setenv ipaddr 192.168.0.251 
    setenv kernaddr 0x81000000
    setenv rootaddr 1200000
    setenv rootaddr_useg 0x$rootaddr
    setenv rootaddr_ks0 0x8$rootaddr
    setenv bootargs  console=ttyATH0,115200 panic=10 oops=panic init=/bin/init phram.phram=nixrootfs,$rootaddr_ks0,4Mi root=/dev/mtdblock0 memmap=4M\$$rootaddr_useg ath79-wdt.from_boot=n ath79-wdt.timeout=20  loglevel=8 rootfstype=squashfs ethaddr=90:A2:DA:F9:07:5A machtype=TEW-712BR
    setenv bootn " tftp $rootaddr_ks0 /tftp/rootfs.image; tftp $kernaddr /tftp/kernel.image ; bootm  $kernaddr"
    run bootn

The constraints on memory addresses are as follows

* the kernel and root images must not  overlap, nor should anything encroach
  on the area starting at 0x8006000 where the kernel will be
  uncompressed to
* the memmap parameter in bootargs should cover the whole rootfs image



## Make it permanent (flashable image)

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
know you can probably make a reasonable guess: my suggestion is to
look at the boot log for a line of the form `Booting image at
9f070000` and then double check by lookin at the output of `cat
/proc/mtd` in OpenWRT and see if there's a partition starting at
`0x70000`.  If you get this wrong you may brick your device, of course.

### Build the image

    $ make t=yun d=wap firmware PSK=17e3c534ff0f0fbde1a158f6980f8955cf85a496e65a0b6b97d9e6e41d7de6d9

### Flash it

Get into u-boot, then do something like this

    setenv serverip 192.168.0.2 
    setenv ipaddr 192.168.0.251 
    erase 0x9f070000 0x9f400000
    tftp 0x80060000 /tftp/firmware_yun.bin
    cp.b 0x80060000 0x9f070000 ${filesize}

The magic numbers here are 

- 0x80060000 : somewhere in RAM, not critical
- 0x9f070000 : flash memory address for "firmware" partition (kernel plus root fs)
- 0x9f400000 : end of flash firmware partition image

If that looked like it worked, type `reset` to find out if you were right.



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

