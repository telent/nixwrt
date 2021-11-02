lib: users:
let us = lib.mapAttrsToList (name: u: "${name}:!!:${builtins.toString u.uid}:${builtins.toString u.gid}:${u.gecos}:${u.dir}:${u.shell}\n" )
  users;
in lib.concatStrings us
