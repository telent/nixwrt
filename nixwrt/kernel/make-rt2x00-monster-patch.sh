source $stdenv/setup
ncat(){ for i in $*; do  echo "########## Patch file $i"; cat $i; done; }
exec > $out
for i in `seq -w 001 004`; do ncat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/''${i}*.patch  ; done

# this misses a potentially useful patch
ncat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/005-*.patch  | filterdiff -x '*/rt2x00mac.c'
for i in `seq -w 006 013`; do ncat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/''${i}*.patch  ; done

# not vital that we apply all the hunks here, it's only taking out some
# superfluous error checks
ncat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/014-rt2x00-no-need-to-check-return-value-of-debugfs_crea.patch  | sed -e 's/0400/S_IRUSR/g' -e 's/0600/S_IRUSR | S_IWUSR/g' >/dev/null # # | filterdiff --hunks=1,4-5

for i in `seq -w 015 031`; do ncat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/''${i}*.patch  ; done
ncat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/032-*.patch  # | filterdiff -x '*/rt2x00mac.c'
ncat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/050*.patch
ncat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/601-*.patch | filterdiff -x '*/local-symbols' -x '*/rt2x00_platform.h'
ncat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/602-*.patch | sed 's/CPTCFG_/CONFIG_/g' | filterdiff -x '*/local-symbols'
ncat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/603-*.patch
ncat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/604-*.patch
ncat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/606-*.patch | filterdiff -x '*/local-symbols' -x '*/rt2x00_platform.h'
ncat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/607-*.patch | filterdiff -x '*/local-symbols' -x '*/rt2x00_platform.h'
ncat ${ledeSrc}/package/kernel/mac80211/patches/rt2x00/60[89]-*.patch
