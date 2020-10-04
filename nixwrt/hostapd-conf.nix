lib : cfg :
let lines = lib.attrsets.mapAttrsToList
  (k : v: "${k}=${builtins.toString v}" ) cfg;
in lib.concatStringsSep "\n" lines
