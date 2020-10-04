{ stdenv
, git
, python2
, which
, fetchgit
, fetchFromGitHub
, autoreconfHook
, coccinelle
, donorTree } :
let
  backports = stdenv.mkDerivation {
    name = "linux-backports";
    version = "9400d9e7-dirty";
    nativeBuildInputs = [ python2 ];
    src = fetchgit {
      url = "https://git.kernel.org/pub/scm/linux/kernel/git/backports/backports.git";
      name = "backports";
      rev = "79400d9e7c46a37501e309ebba898266c35fadfd";
      sha256 = "1xzwh9y0g1nv76aincw1d04fkz2dbh6vdgnxl7ww028lfdc1v18b";
    };
    buildPhase = ''
        patchShebangs .
    '';
    installPhase = ''
        mkdir -p $out
        cp -a . $out
        # fq.patch is obsoleted by kernel commit 48a54f6bc45 and no longer
        # applies
        rm $out/patches/0091-fq-no-siphash_key_t/fq.patch
        # don't know why this doesn't apply but it's only important for
        # compiling against linux < 4.1
        rm $out/patches/0058-ptp_getsettime64/ptp_getsettime64.cocci
      '';
    patches = [ ./gentree-writable-outputs.patch
                ./update-usb-sg-backport-patch.patch
                ./backport_kfree_sensitive.patch
              ];
  };
  coccinelleNew  = coccinelle.overrideAttrs (o: {
    nativeBuildInputs = [ autoreconfHook ];
    doCheck = false;
    postInstall = "true";
    src =
      fetchFromGitHub {
        owner = "coccinelle";
        name = "coccinelle";
        repo = "coccinelle";
        rev = "c40485138a0d9b5db30ad528b042fb856f28c9b7";
        sha256 = "1qb9nr69xp2hcx5pz1pcc4npb51v961m11b7dir3m0mf53b0smmf";
        };
  });
in stdenv.mkDerivation rec {
  inherit donorTree;
  KERNEL_VERSION = builtins.substring 0 11 donorTree.rev;
  BACKPORTS_VERSION = backports.version;
  name = "backported-kernel-${KERNEL_VERSION}-${BACKPORTS_VERSION}";

  # gentree uses "which" at runtime to test for the presence of git,
  # and I don't have the patience to patch it out. There is no other
  # reason we need either of them as build inputs.
  nativeBuildInputs = [ coccinelleNew which git python2 ];

  phases = [
    "backportFromFuture" "installPhase"
  ];

  backportFromFuture = ''
    echo $KERNEL_VERSION $BACKPORTS_VERSION
    WORK=`pwd`/build
    mkdir -p $WORK
    cat ${backports}/copy-list > copy-list
    echo 'include/linux/key.h' >> copy-list
    python  ${backports}/gentree.py --verbose --clean  --copy-list copy-list ${donorTree} $WORK
  '';
  installPhase = ''
    cp -a ./build/ $out
  '';

}
