# this exists so that I have an easy way to test the
# linux-next/backports/coccinelle stuff, which was a lot of work
# to figure out. As of Sat Sep 19 2020 it was working, but
# is not executed as part of any automated build, so stands a
# risk of bitrotting

with (import <nixpkgs> {}) ;
callPackage ./backport.nix {
  donorTree = fetchgit {
    url =
      "https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/";
    rev = "99c0b9a5f851a85d631803e1b01a91e31ea99026"; # 	next-20200908
    sha256 = "047rasgkxyf6fklmm14ci9kybyzddkcqwl6mnailv09a43sjnkpp";
  };
}
