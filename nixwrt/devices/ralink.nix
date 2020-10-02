{ nixpkgs
, nixwrt } :
let kb = nixwrt.kernel;
in rec {
  listFiles = dir: builtins.attrNames (builtins.readDir dir);
  openwrt =  nixpkgs.fetchFromGitHub {
    owner = "openwrt";
    repo = "openwrt";
    name = "openwrt-src" ;
    rev = "252197f014932c03cea7c080d8ab90e0a963a281";
    sha256 = "1n30rhg7vwa4zq4sw1c27634wv6vdbssxa5wcplzzsbz10z8cwj9";
  };
  openwrtKernelFiles = "${openwrt}/target/linux";
  kernelVersion = [5 4 64];
  upstream = kb.fetchUpstreamKernel {
    version = kernelVersion;
    sha256 = "1vymhl6p7i06gfgpw9iv75bvga5sj5kgv46i1ykqiwv6hj9w5lxr";
  };
  tree =  kb.patchSourceTree {
      inherit upstream openwrt;
      inherit (nixpkgs) buildPackages patchutils stdenv;
      version = kernelVersion;
      patches = nixpkgs.lib.lists.flatten
        [ "${openwrtKernelFiles}/ramips/patches-5.4/"
          "${openwrtKernelFiles}/generic/backport-5.4/"
          "${openwrtKernelFiles}/generic/pending-5.4/"
          (map (n: "${openwrtKernelFiles}/generic/hack-5.4/${n}")
            (builtins.filter
              (n: ! (nixpkgs.lib.strings.hasPrefix "230-" n))
              (listFiles "${openwrtKernelFiles}/generic/hack-5.4/")))
        ];
      files = [ "${openwrtKernelFiles}/generic/files/"
                "${openwrtKernelFiles}/ramips/files/"
                "${openwrtKernelFiles}/ramips/files-5.4/"
              ];
  };
}
