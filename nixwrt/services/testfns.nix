{
  stdenv
, lib
}:
{
  example = name : body: stdenv.mkDerivation {
    name = lib.strings.sanitizeDerivationName name;
    phases = ["testPhase"];
    testPhase = ''
      fail() {
        echo "FAILED: ${name}: $*";
        exit 1
      };
      test-wait() {
        tenths=$1; shift;
        succeeded=
        for wait in `seq 0 $tenths`; do
          if test $*; then succeeded=true; break; fi
          sleep 0.1
        done
        test -n "$succeeded"
      }
      ${body}
      touch $out
    '';
  };
  examples = es :
    stdenv.mkDerivation {
      name ="run-tests";
      phases  = [ "testPhase" ];
      buildInputs = es;
      testPhase = "touch $out";
    };
  trace1 = f: builtins.trace (builtins.deepSeq f f) f;
}
