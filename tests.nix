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
      test -f ${foo.ready} || fail "${foo.ready} not found"
    '')
  (t.example "it does not start when blocked by dependency" ''
      ${bar.package} start &
      ! test -f ${bar.ready} || fail "${bar.ready} found unexpectedly"
      test-wait 9 -f ${bar.blocked}
      test -f ${bar.blocked} || fail "${bar.blocked} not found"
    '')
  (t.example "it starts when dependency already satisfied" ''
      ${foo.package} start
      ${bar.package} start
      test -f ${bar.ready} || fail "${bar.ready} not found"
    '')
  (t.example "it unblocks if dependency becomes ready while blocking" ''
      ${bar.package} start &
      ${foo.package} start
      test-wait 10  -f ${bar.ready} || fail "${bar.ready} not found"
      ! test -f ${bar.blocked} || fail "${bar.blocked} found unexpectedly"
    '')
]
