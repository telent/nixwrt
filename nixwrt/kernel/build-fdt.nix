{ stdenv
, dts
, commandLine
, dtc
, includes } :
let
  cppDtSearchFlags = builtins.concatStringsSep " " (map (f: "-I${f}") includes);
  dtcSearchFlags = builtins.concatStringsSep " " (map (f: "-i${f}") includes);
in stdenv.mkDerivation {
  name = "fdt";
  nativeBuildInputs = [ dtc ];
  phases = ["buildPhase"];
  buildPhase = ''
    echo ${cppDtSearchFlags}
    ${stdenv.cc.targetPrefix}cpp -nostdinc -x assembler-with-cpp ${cppDtSearchFlags} -undef -D__DTS__  -o dtb.tmp ${dts}
    echo '/{ chosen { bootargs = ${builtins.toJSON commandLine}; }; };'  >> dtb.tmp
    dtc -O dtb ${dtcSearchFlags} -o $out dtb.tmp
'';
}
