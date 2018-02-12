{ lib, pkgs , ...} : filename: prefix: specs: 
let defaults = { mode = "0444"; owner="root"; group="root"; };
lines = lib.attrsets.mapAttrsToList
    (name: spec:
       let s = defaults // spec;
           c = builtins.replaceStrings ["\n" "=" "\""] ["=0A" "=3D" "=22"] s.content; in
           "/etc/${name} f ${s.mode} ${s.owner} ${s.group} echo -n \"${c}\" |qprint -d")
           specs;
in pkgs.writeText filename ( "${prefix} d 0755 root root\n" + (builtins.concatStringsSep "\n" lines))
