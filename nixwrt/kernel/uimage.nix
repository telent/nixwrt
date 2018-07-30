{
  vmlinux
, commandLine
, dtc
, dtcSearchPaths
, dtsPath
, entryPoint ? "0x80000000"
, extraName ? ""                # e.g. socFamily
, loadAddress ? "0x80000000"
, lzma
, patchDtb
, stdenv
, ubootTools
} :
let
  cppDtSearchFlags = builtins.concatStringsSep " " (map (f: "-I${f}") dtcSearchPaths);
  dtcSearchFlags = builtins.concatStringsSep " " (map (f: "-i${f}") dtcSearchPaths);
  objcopy = "${stdenv.cc.bintools.targetPrefix}objcopy";
in
stdenv.mkDerivation {
  name = "kernel.image";
  phases = [ "buildPhase" "installPhase" ];
  nativeBuildInputs = [ patchDtb dtc lzma stdenv.cc ubootTools ];
  buildPhase = ''
    ${objcopy} -O binary -R .reginfo -R .notes -R .note -R .comment -R .mdebug -R .note.gnu.build-id -S ${vmlinux} vmlinux.stripped
    ${stdenv.cc.targetPrefix}cpp -nostdinc -x assembler-with-cpp ${cppDtSearchFlags} -undef -D__DTS__  -o dtb.tmp ${dtsPath}
    echo '/{ chosen { bootargs = ${builtins.toJSON commandLine}; }; };'  >> dtb.tmp
    dtc -O dtb ${dtcSearchFlags} -o vmlinux.dtb dtb.tmp
    patch-dtb vmlinux.stripped vmlinux.dtb
    rm -f vmlinux.stripped.lzma
    lzma -k -z  vmlinux.stripped
    mkimage -A mips -O linux -T kernel -C lzma -a ${loadAddress} -e ${entryPoint} -n 'MIPS NixWrt Linux ${extraName}' -d vmlinux.stripped.lzma kernel.image
  '';
  installPhase = ''
    cp kernel.image $out
  '';
}
