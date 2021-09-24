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
      for wait in `seq 0 9`; do
        test -f ${bar.blocked} && break
        sleep 0.1
      done
      test -f ${bar.blocked} || fail "${bar.blocked} not found"
    '')
]

# given a service definition bar depending on foo.ready
# and foo/ready exists
# when I start the bar service
# then it creates a state file bar/ready

# given a service definition bar depending on foo.ready
# and foo/ready does not exist
# when I start the bar service
# then it creates a state file bar/pending

# given a service definition bar depending on foo.ready
# and foo/ready exists
# when I start the bar service
# then it creates a state file bar/pending
