image?=phramware
ssh_public_key_file?=/etc/ssh/authorized_keys.d/$(USER)
NIX_BUILD=nix-build --show-trace \
 -I nixpkgs=../nixpkgs -I nixwrt=./nixwrt -A $(image)

# you need to generate an ssh host key for your device before running
# any of these builds: it will be baked in, so that you know you are
# at the right place the first time you connect to it

backuphost: examples/backuphost.nix
	$(NIX_BUILD) \
	 --argstr myKeys "`cat $(ssh_public_key_file) `" \
	 --argstr sshHostKey backuphost-host-key \
	 $^ -o $@ 

defalutroute: examples/defalutroute.nix
	$(NIX_BUILD) \
	 --argstr myKeys "`cat $(ssh_public_key_file) `" \
	 --arg sshHostKey ./defalutroute-host-key \
	 $^ -o $@ 

