with import <nixpkgs> {};
let t = callPackage ./testfns.nix {};
    svcnix = callPackage ./svcnix.nix { baseDir = "/tmp"; };
in t.examples [
  (let foo = svcnix.build {
         name = "foo";
         start = "setstate ready true";
         outputs = ["ready"];
       };
   in t.example "it creates a state file foo/ready when started" ''
      ${foo.package} start
      test -f ${foo.ready} || fail "${foo.ready} not found"
    ''
       )
]
#   when

# given a service definition
# foo =
# when I start the service
# then it creates a state file foo/ready

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
