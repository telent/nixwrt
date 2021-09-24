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
