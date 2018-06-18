nixpkgs: file:
with nixpkgs;
let f = pkgs.runCommand "defconfig.json"  { } ''
      echo -e "{\n" > $out
      (source ${file} ; for v in ''${!CONFIG@} ; do printf "  \"%s\": \"%s\",\n" "$v" "''${!v}" ;done ) >> $out
      echo -e "  \042SWALLOW_COMMA\042: \042n\042 \n}" >> $out
    '';
    attrset = builtins.fromJSON ( builtins.readFile f ); in
  lib.mapAttrs'
    (n: v: (lib.nameValuePair (lib.removePrefix "CONFIG_" n) v))
    attrset
