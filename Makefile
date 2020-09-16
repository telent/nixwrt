EXAMPLES=$(notdir $(basename $(wildcard examples/*.nix)))

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
SSID?=NixWRT
ssh_public_key_file?=/etc/ssh/authorized_keys.d/$(USER)

-include secrets

## Per-target config

extensino/firmware.bin: ATTRS=--argstr ssid $(SSID) --argstr psk $(PSK) --argstr loghost $(LOGHOST)

defalutroute/firmware.bin: ATTRS=--argstr ssid $(SSID) --argstr psk $(PSK) --argstr loghost $(LOGHOST)

arhcive/firmware.bin: ATTRS=--argstr loghost $(LOGHOST) --argstr rsyncPassword $(ARHCIVE_RSYNC_PASSWORD)


## Variables & Functions

INCLUDE=-I nixpkgs=../nixpkgs -I nixwrt=./nixwrt

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

define shortcut_to_example
$(1): $(1)/firmware.bin
endef

$(foreach x,$(EXAMPLES),$(eval $(call shortcut_to_example,$(x))))


%/firmware.bin: examples/%.nix %-host-key
	$(NIX_BUILD_ARGS) \
	 $(ATTRS) \
	 --argstr myKeys "`cat $(ssh_public_key_file) `" \
	 --argstr sshHostKey "`cat $(@D)-host-key`" \
	 $< -o $(@D)

repl:
	nix repl $(INCLUDE)
