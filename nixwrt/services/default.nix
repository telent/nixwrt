{svc, callPackage, lib} :
with builtins;
let callPackages =
      dir: lib.mapAttrs' (n: v:
        (lib.attrsets.nameValuePair
          (lib.strings.removeSuffix ".nix" n)
          (if ((v == "regular")  &&
               (n != "default.nix") &&
               (lib.hasSuffix ".nix" n))
           then callPackage (dir + "/${n}") {}
           else (builtins.trace [n v] null))))
        (readDir dir);
in callPackages ./.
