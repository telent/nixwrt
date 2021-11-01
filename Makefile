EXAMPLES=arhcive defalutroute emu extensino upstaisr

default:
	@echo "No default target, choose from $(EXAMPLES)"

# WARNING: This Makefile is my personal attempt to make building
# my personal NixWRT images more personally convenient for me (personally).
# It does not attempt to address the general questions of
# "where should we keep secrets and how do we get them into nix-build attributes"
# and should not be considered good practice, except perhaps[*] by accident

# [*] even that's unlikely

## Config

#image?=phramware  # build runnable-from-ram image
image?=firmware  # build flashable image
ssh_public_key_file?=/etc/ssh/authorized_keys.d/$(USER)

-include $(SECRETS)

## Per-target config

e=$(or $(value $(1)),$(error "$(1) undefined (add it to your SECRETS file?)"))

arhcive: ATTRS=\
 --argstr endian little \
 --argstr loghost $(call e,LOGHOST)\
 --argstr rsyncPassword $(call e,ARHCIVE_RSYNC_PASSWORD)

emu: image=emulator
emu: ATTRS=\
 --argstr endian big \
 --argstr loghost $(call e,LOGHOST)

defalutroute: ATTRS=\
 --argstr endian big \
 --argstr ssid $(call e,SSID) \
 --argstr psk $(call e,PSK) \
 --argstr loghost $(call e,LOGHOST) \
 --argstr l2tpUsername $(call e,L2TP_USERNAME) \
 --argstr l2tpPassword $(call e,L2TP_PASSWORD) \
 --argstr l2tpPeer $(call e,L2TP_PEER)

extensino: ATTRS=\
 --argstr endian little \
 --argstr ssid $(call e,SSID) \
 --argstr psk $(call e,PSK) \
 --argstr loghost $(call e,LOGHOST)

upstaisr: ATTRS=\
 --argstr endian little \
 --argstr ssid $(call e,SSID) \
 --argstr psk $(call e,PSK) \
 --argstr loghost $(call e,LOGHOST)

## Variables & Functions

INCLUDE=-I nixwrt=./nixwrt

NIX_BUILD=nix-build -j1
NIX_BUILD_ARGS=$(NIX_BUILD) --show-trace $(INCLUDE)  -A $(image)

# nixpkgs doesn't recognise mips-linux as a supported system
export NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1

## Implementation

# ssh host keys are generated on the build system and then copied to
# the target.  Unless you want to be confronted with "Host key
# verification failed" messages from ssh every time you reflash, you
# probably shouldn't be deleting them

# From a security POV this is suboptimal as it means the device's secret
# keys are all compromised as soon as the build machine is, and we
# would be better to try and generate a host key on first boot then somehow
# notify that OOB to the connecting user, but as we don't in general
# know of any provision/channel for doing that, this is not a problem
# I have yet confronted.

.PRECIOUS: %-host-key

%-host-key:
	ssh-keygen -m PEM -P '' -t rsa -f $@ -b 2048

%:examples/%/config.nix
	$(NIX_BUILD_ARGS) \
	 $(ATTRS) \
	 -I nixwrt-config=`pwd`/$^ \
	 --argstr myKeys "`cat $(ssh_public_key_file) `" \
	 --argstr sshHostKey "`cat emu-host-key`" \
	 default.nix -o out/$@

repl:
	nix repl $(INCLUDE)
