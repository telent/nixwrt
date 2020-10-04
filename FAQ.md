# NixWRT Frequently Asked Questions

## What triggered all this?

A long time ago (October 2018) in a <del>galaxy</del> spare bedroom
far away, I built a new desktop/home server/media storage machine, and
wanted more robust/less easily trashable backups than simply mirroring
stuff onto an external USB drive then forgetting to unmount it.  But I
wasn't about to build yet another PC just to back up the first one, so
what could I do with stuff I had lying around?  Well, I have this
router with a USB port that's not doing much, maybe I could
use that somehow?

Since that first thought, the eventual scope has grown a bit and the
next steps in NixWRT are to replace the OpenWrt on all the other
embedded MIPS systems in the house - one router, two wifi extenders,
and maybe try it on some ARM devices as well.

## How do you pronounce the name?

As in "NICK'S Whut", because I'm the kind of person who likes to
pronounce acronyms instead of spelling them out. You don't have to, though.


## What can I use it for?

See [Applications and use cases](https://github.com/telent/nixwrt/blob/master/README.md#applications-and-use-cases-former-current-and-prospective)


## Why not "just" use OpenWrt?

The developers of OpenWrt (and the related projects DD-WRT, Tomato etc
etc) are a bunch of - from my observation - fantastically
knowledgable, talented and hard-working people without whom NixWRT
would not exist. 

That said, configuration management - in the sense of being able to
see what you changed on a device, why you changed it, and repeat the
configuration on another device or using a newer version of the base
system - is not (IMO) one of its strong points. Anything I want to
achieve with it tends to involve a lot of "maybe I'll flash a newer
version" and "what if I edit that file" and "I'll just change that
thing in the web thing", with the result that generally by the time I
have the system performing the specified task I [no longer know which
change was the required one](https://ww.telent.net/2016/11/12/huawei_e3372_with_openwrt), and sometimes can't even remember all the changes I made. This is not
[infrastructure as
code](https://martinfowler.com/bliki/InfrastructureAsCode.html) , kids


## What about Puppet? (Or Chef or Ansible or ...)

I have previously wondered about running Puppet to produce router
configs, but it's a bit heavyweight for systems that count their
memory in MB.  Even if the hardware did support it I'm not a fan of the
way that changes can fall through the cracks when the CM system is
grafted onto an existing OS with its own package system.  Absence of a
resource from the catalog doesn't mean absence of the corresponding
file/package/service from the host, it just means that Puppet doesn't
know about it.

As far as I know Chef (which I've never used) solves much the same
kind of problem in much the same kind of way

## So is this NixOS running on your router?

No.  I have NixOS running on my desktop to build a firmware
bimary image that I can flash to a router.  I can ssh into the router
and look around, and it will look quite Nixy (it has `/nix/store` and
stuff like that) but it's a read-only "appliance" where to change
anything I build a new image.

Most of the packages are from Nixpkgs (some others are custom).
There's a "service" abstraction a bit like NixOS but not the same (we
use Monit not systemd as service manager).  We build our own kernels,
because we need to do complicated things with merging huge swathes of
OpenWrt patches into them and it was easier to do this starting from
the upstream kernel build than to understand the Nix special kernel
sauce.

(I am thinking about supporting persisted mutable state in some small
way, if only because things like key rotation are going to be tedious
otherwise.  But not yet)

## LUCI? Some other Web GUI?  

No. Well, definitely no to the first question, and 93% no to the
second.  There's no interface for changing things on the device,
because there's (intentionally) nothing you can change on the device.
But the Monit web interface is enabled so you can see what services
are up and how many Mb/second the network is moving.

## Do you have wireless?

There is "Access Point" support (using hostapd) for the wireless
hardware on the devices it supports (ath9k, ath10k, mt7620, mt7628)
using drivers taken from the linux-backports project. If your device
is supported there it should be relatively[*] trouble free to get it
running here.

[*] relative to what exactly, I'm not saying

## And wired ethernet?

Yes, certainly.  DHCP or static addresses, and some support for
configuring the switch too.


