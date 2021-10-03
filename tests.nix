with import <nixpkgs> {};
let t = callPackage ./testfns.nix {};
    svcnix = callPackage ./svcnix.nix { baseDir = "/tmp"; };
    foo = svcnix.build {
      name = "foo";
      start = "setstate ready true";
      outputs = ["ready"];
    };
    bar = svcnix.build {
      name = "bar";
      start = "setstate ready true";
      outputs = ["ready"];
      depends = [ foo.ready ];
    };
in t.examples [
  (t.example "it creates a state file foo/ready when started" ''
      ${foo.package} start
      test-wait 9 -f ${foo.ready} || fail "${foo.ready} not found"
    '')
  (t.example "it starts services on which it depends" ''
      ${bar.package} start &
      test-wait 9  -f ${foo.ready} || fail "${foo.ready} not found"
      test-wait 10   -f ${bar.ready} || fail "${bar.ready} not found"
    '')
  (t.example "it starts when dependency already satisfied" ''
      ${foo.package} start
      ${bar.package} start
      test -f ${bar.ready} || fail "${bar.ready} not found"
    '')
  (let
    delay = "3";
    slow = svcnix.build {
      name = "foo";
      start = "sleep ${delay}; setstate ready true";
      outputs = ["ready"];
    };
    bar = svcnix.build {
      name = "bar";
      start = "setstate ready true";
      outputs = ["ready"];
      depends = [ slow.ready ];
    };
  in t.example "it waits for a slow dependency to start" ''
    ${bar.package} start &
    test-wait 5 -f ${bar.blocked} || fail "${bar.blocked} not found"
    sleep ${delay} 1
    test-wait 50  -f ${slow.ready} || fail "${slow.ready} not found"
    test -f ${bar.blocked} && fail "${bar.blocked} found"
    test -f ${bar.ready} || fail "${bar.ready} not found"
  '')
  (t.example "it unblocks if dependency becomes ready while blocking" ''
      ${bar.package} start &
      ${foo.package} start
      test-wait 10  -f ${bar.ready} || fail "${bar.ready} not found"
      ! test -f ${bar.blocked} || fail "${bar.blocked} found unexpectedly"
    '')
  (let slant = svcnix.build {
         name  = "slant";
         start = "setstate ready true; sleep 3";
         outputs = ["ready"];
         foreground = true;
       }; in t.example "a foreground service stops when the process providing it exits" ''
         ${slant.package} start &
         test-wait 50  -f ${slant.ready} || fail "${slant.ready} not found"
         test-wait 50 \! -f ${slant.ready} || fail "${slant.ready} found unexpectedly"
       '')
  (let foo = svcnix.build {
      name = "foo";
      start = "setstate ready true; setstate pidnum \$$";
      outputs = ["ready" "pidnum"];
       }; in
     t.example "it cannot be started a second time" ''
       ${foo.package} start
       pid1=`cat ${foo.pidnum}`
       test -n $pid1
       ${foo.package} start
       pid2=`cat ${foo.pidnum}`
       test "$pid1" = "$pid2" || fail "pids $pid1, $pid2 differ"
    '')
]
