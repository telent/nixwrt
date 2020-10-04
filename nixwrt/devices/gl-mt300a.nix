# GL-Inet GL-MT300A

# The GL-Inet pocket router range makes nice cheap hardware for
# playing with NixWRT or similar projects. The manufacturers seem
# open to the DIY market, and the devices have a reasonable amount
# of RAM and are much easier to get serial connections than many
# COTS routers. GL-MT300A is my current platform for NixWRT
# development.

# Wire up the serial connection: this probably involves opening
# the box, locating the serial header pins (TX, RX and GND) and
# connecting a USB TTL converter - e.g. a PL2303 based device - to
# it. The defunct OpenWRT wiki has a guide with some pictures. (If
# you don't have a USB TTL converter to hand, other options are
# available. For example, use the GPIO pins on a Raspberry Pi)

# Run a terminal emulator such as Minicom on whatever is on the
# other end of the link. I use 115200 8N1 and find it also helps
# to set "Character tx delay" to 1ms, "backspace sends DEL" and
# "lineWrap on".

# When you turn the router on you should be greeted with some
# messages from U-Boot and a little bit of ASCII art, followed by
# the instruction to hit SPACE to stop autoboot. Do this and you
# will get a gl-mt300a> prompt.

# For flashing from uboot, the firmware partition is from
# 0xbc050000 to 0xbcfd0000

# For more details refer to https://ww.telent.net/2018/4/16/flash_ah_ah

options: nixpkgs: self: super:
let
  soc = import ./mt7620.nix;
  dts = {openwrt}: "${openwrt}/target/linux/ramips/dts/mt7620a_glinet_gl-mt300a.dts";
in soc (options // { inherit dts ;}) nixpkgs self super
