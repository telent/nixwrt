stdenv: users:
  let us = builtins.foldl' (a: u: a ++ 
    ["${u.name}:!!:${builtins.toString u.uid}:${builtins.toString u.gid}:${u.gecos}:${u.dir}:${u.shell}\n"]) [] users;
  in stdenv.lib.concatStrings us
  
