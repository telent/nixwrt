#! @sh@
die(){ echo $* >&2; exit 1; }

. /etc/phram.vars

test "$1" = "" && die "Usage: $0 firmware.bin"
test -r $1 || die "cannot read firmware image $1"

# XXX should check that the phram memory has been reserved
echo Writing $1 to physical memory at $phram_offset
@out@/writemem $phram_offset < $1
echo Press Return to reboot
read
kexec -f $1 --command-line="memmap=${phram_sizeMB}M\$${phram_offset} $(cat /proc/cmdline) mtdparts=mydev:${phram_sizeMB}M(firmware) phram.phram=mydev,${phram_offset},${phram_sizeMB}Mi"
