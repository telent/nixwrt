{
  vmlinux
, commandLine
, dtc
, dtcSearchPaths
, dtsPath ? null
, entryPoint ? "0x80000000"
, extraName ? ""                # e.g. socFamily
, loadAddress ? "0x80000000"
, lzma
, patchImage
, stdenv
, ubootTools
} :
let
  cppDtSearchFlags = builtins.concatStringsSep " " (map (f: "-I${f}") dtcSearchPaths);
  dtcSearchFlags = builtins.concatStringsSep " " (map (f: "-i${f}") dtcSearchPaths);
  objcopy = "${stdenv.cc.bintools.targetPrefix}objcopy";
  patchDtbCommand = if (dtsPath != null) then ''
    ${stdenv.cc.targetPrefix}cpp -nostdinc -x assembler-with-cpp ${cppDtSearchFlags} -undef -D__DTS__  -o dtb.tmp ${dtsPath}
    echo '/{ chosen { bootargs = ${builtins.toJSON commandLine}; }; };'  >> dtb.tmp
    dtc -O dtb ${dtcSearchFlags} -o vmlinux.dtb dtb.tmp
    patch-dtb vmlinux.stripped vmlinux.dtb
  '' else ''
    echo patch-cmdline vmlinux.stripped '${commandLine}'
    patch-cmdline vmlinux.stripped '${commandLine}'
    echo
  '';
in
stdenv.mkDerivation {
  name = "kernel.image";
  phases = [ "buildPhase" "installPhase" ];
  nativeBuildInputs = [ patchImage dtc lzma stdenv.cc ubootTools ];
  buildPhase = ''
    ${objcopy} -O binary -R .reginfo -R .notes -R .note -R .comment -R .mdebug -R .note.gnu.build-id -S ${vmlinux} vmlinux.stripped
    ${patchDtbCommand}
    rm -f vmlinux.stripped.lzma
    lzma -k -z  vmlinux.stripped
    mkimage -A mips -O linux -T kernel -C lzma -a ${loadAddress} -e ${entryPoint} -n 'MIPS NixWrt Linux ${extraName}' -d vmlinux.stripped.lzma kernel.image
  '';
  installPhase = ''
    cp kernel.image $out
  '';
}
