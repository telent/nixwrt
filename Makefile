EXAMPLES=arhcive defalutroute emu extensino upstaisr

SECRETS=./secrets

default:
	@echo "No default target, choose from $(EXAMPLES)"

all: $(EXAMPLES)

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

## Per-target config

arhcive: ATTRS=--argstr endian little

emu: image=emulator
emu: ATTRS= --argstr endian big

defalutroute: ATTRS=--argstr endian big

extensino: ATTRS=--argstr endian little

upstaisr: ATTRS=--argstr endian little

## Variables & Functions

INCLUDE=-I nixwrt=./nixwrt

ifdef DRY_RUN
DRY_RUN_FLAG=--dry-run
endif

NIX_BUILD=nix-build -j1
NIX_BUILD_ARGS=$(NIX_BUILD) --show-trace $(INCLUDE) $(DRY_RUN_FLAG)  -A $(image)

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

export SSH_AUTHORIZED_KEYS=$(file <  $(ssh_public_key_file))
export SSH_HOST_KEY=$(file < emu-host-key)

%:examples/%/config.nix
	test -f $(SECRETS)
	env $(shell cat $(SECRETS)) $(NIX_BUILD_ARGS) \
	 $(ATTRS) \
	 -I nixwrt-config=`pwd`/$^ \
	 default.nix -o out/$@

repl:
	nix repl $(INCLUDE)
