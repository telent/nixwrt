{ lib, writeText, ...} : filename: prefix: specs:
let defaults = { type = "f"; mode = "0444"; owner="root"; group="root"; };
lines = lib.attrsets.mapAttrsToList
    (name: spec:
       let s = defaults // spec;
           c = builtins.replaceStrings ["\n" "=" "\""] ["=0A" "=3D" "=22"] s.content;
           line = "${prefix}${name} ${s.type} ${s.mode} ${s.owner} ${s.group}";
           in if s.type=="f" then
               "${line} echo -n \"${c}\" |qprint -d"
             else
               line)
    specs;
in writeText filename ( "${prefix} d 0755 root root\n" + (builtins.concatStringsSep "\n" lines))
