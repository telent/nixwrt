# NixWRT Frequently Asked Questions

## What triggered all this?

A long time ago (last October) in a <del>galaxy</del> spare bedroom
far away, I built a new desktop/home server/media storage machine, and
wanted more robust/less easily trashable backups than simply mirroring
stuff onto an external USB drive then forgetting to unmount it.  But I
wasn't about to build yet another PC just to back up the first one, so
what could I do with stuff I had lying around?  Well, I have this
router with a USB port that's not doing much, maybe I could
use that somehow?

Since that first thought, the eventual scope has grown a bit and the
next steps in NixWRT are to replace the OpenWRT on all the other
embedded MIPS systems in the house - one router, one wifi extender,
and maybe try it on some ARM devices as well.

## What can I use it for?

Right now, if you have

* a GL.Inet GL-MT300A which you are prepared to open up and attach cables to
* a PL-2303 or similar to translate three wire 3.3v serial signal into USB or something else that's useful to you
* a USB2 disk drive with an ext[234]fs filesystem on it labelled `backup-disk`
* a NixOS build system on which your username is `dan`

then you should be able to use my NixWRT configuration unchanged to
build a firmware image on the first of those that runs an rsync daemon to
make the second accessible, such that you can back up the third using
duplicity.  Or use the rsync daemon for anything else you choose.

To the extent that your hardware or your use case or your name is
different, then your scope of work will differ proportionately. Or if
you are unfortunate, disproportionately.  Some attempt has been made
towards a sensible separation of concerns but it's going to take one
or two more use cases (next two projects planned: a wireless extender
and a domestic PPPoE router) to get it right.

## Why not "just" use OpenWRT?

I have an [uneasy relationship with OpenWRT](https://ww.telent.net/2011/6/22/openwrt_backfire_first_impressions) - anything I want to achieve with it tends to involve a lot of "maybe
I'll flash a newer version" and "what if I edit that file" and "I'll
just change that thing in the web thing", with the result that
generally by the time I have the system performing the specified task
I
[no longer know which change was the required one](https://ww.telent.net/2016/11/12/huawei_e3372_with_openwrt),
and sometimes can't even remember all the changes I made. This is
not
[infrastructure as code](https://martinfowler.com/bliki/InfrastructureAsCode.html) ,
kids

## Do you realise that comes across as very mean/ungrateful?

Yes, I worry that it may do.  OpenWRT (and the related projects
DD-WRT, Tomato etc etc) are a bunch of - from my observation -
fantastically knowledgable, talented and hard-working people without
whom NixWRT would not exist (I'm using their kernel patches as-is, for
example, and that represents a lot of work).  NixWRT is an argumentum
ad "show me the code" that Nix is useful in this problem space, but
it's very definitely meant as a contribution to the community and not
an attack on it.


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

Some of the packages are from Nixpkgs (some others are custom).
There's a "service" abstraction a bit like NixOS but not the same (we
use Monit not systemd as service manager).  We build our own kernels,
because we need to do complicated things with merging huge swathes of
OpenWRT patches into them and it was easier to do this starting from
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

Not yet but I plan to add it next.


## Wired ethernet at least?

Yes, certainly.  DHCP or static addresses, and some support for
configuring the switch too.


