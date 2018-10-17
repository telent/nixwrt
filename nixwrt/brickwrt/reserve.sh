#! @sh@
die(){ echo $* >&2; exit 1; }
if test "$#" -ne 1  ; then
    die "Usage: $0 /dev/mtdnnn # where nnn is the current firmware device"
fi
firmwaredevice=$1
. /etc/phram.vars
echo Press Return to reboot
read
kexec -f $firmwaredevice --command-line="memmap=${phram_sizeMB}M\$${phram_offset} $(cat /proc/cmdline)"
