{
  stdenv
, lib
}:
{
  example = name : body: stdenv.mkDerivation {
    name = lib.strings.sanitizeDerivationName name;
    phases = ["testPhase"];
    testPhase = ''
      set -e
      fail() {
        echo "FAILED: ${name}: $*";
        exit 1
      };
      test-wait() {
        tenths=$1; shift
        for wait in `seq 0 $tenths`; do
          test $* && break
          sleep 0.1
        done
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

}
