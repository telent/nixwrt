t?=mt300n_v2
d?=backuphost
RSYNC_PASSWORD?=secret
default: firmware
export RSYNC_PASSWORD
TFTPROOT?=/tftp/
ssh_public_key_file?=/etc/ssh/authorized_keys.d/$(USER)

firmware:
	nix-build  -I nixpkgs=../nixpkgs $(d).nix -A $@ \
	 --argstr rsyncPassword $(RSYNC_PASSWORD) \
	 --argstr myKeys "$(shell cat $(ssh_public_key_file))" \
	 --argstr targetBoard $(t) \
	 --arg sshHostKey ./ssh_host_key \
	 -o $(t)_$(d) --show-trace
	rsync -caAiL  $(t)_$(d) $(TFTPROOT)

# this is for the backuphost target
password:
	$(eval RSYNC_PASSWORD := $(shell sudo cat /var/lib/backupwrt/rsync))


# this has not been used in a few months (as of June 2018), and may be
# better considered as a starting point than as a working qemu
# invocation
qemu: tftproot
	nix-shell  -p qemu --run "qemu-system-mips  -M malta -m 128 -virtfs local,path=`pwd`,mount_tag=host0,security_model=passthrough,id=host0 -nographic -kernel malta/kernel.image  -append 'root=/dev/sr0 console=ttyS0 init=/bin/init' -blockdev driver=file,node-name=squashed,read-only=on,filename=malta/rootfs.image -blockdev driver=raw,node-name=rootfs,file=squashed,read-only=on -device ide-cd,drive=rootfs -nographic -netdev user,id=u0 -device e1000,netdev=u0"
