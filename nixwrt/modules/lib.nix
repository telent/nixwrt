options: nixpkgs: self: super:
let
  applyVersion = tokens : fn :
    builtins.foldl' (f: x: f x) fn (map toString tokens);

  fetchUpstreamKernel = { version, sha256 } :
    let
      url = applyVersion version (maj : min : p : "https://cdn.kernel.org/pub/linux/kernel/v${maj}.x/linux-${maj}.${min}.${p}.tar.xz");
    in builtins.fetchurl {
      inherit sha256 url;
    };
  lib = nixpkgs.lib;
  readDefconfig = file:
    let f = nixpkgs.pkgs.runCommand "defconfig.json"  { } ''
      echo -e "{\n" > $out
      (source ${file} ; for v in ''${!CONFIG@} ; do printf "  \"%s\": \"%s\",\n" "$v" "''${!v}" ;done ) >> $out
      echo -e "  \042SWALLOW_COMMA\042: \042n\042 \n}" >> $out
    '';
        attrset = builtins.fromJSON ( builtins.readFile f ); in
      lib.mapAttrs'
        (n: v: (lib.nameValuePair (lib.removePrefix "CONFIG_" n) v))
        attrset;
  patchSourceTree = import <nixwrt/kernel/patch-source-tree.nix>;
  makeVmlinux = import <nixwrt/kernel/make-vmlinux.nix>;
  makeUimage = import <nixwrt/kernel/uimage.nix>;
  makeFdt = import <nixwrt/kernel/build-fdt.nix>;
in {
  nixwrt = {
    kernel = {
      inherit fetchUpstreamKernel readDefconfig patchSourceTree
        makeVmlinux makeUimage makeFdt;
    };
  };
}
