{
  vmlinux
, commandLine
, fdt ? null
, entryPoint
, extraName ? ""                # e.g. socFamily
, loadAddress

, patchImage
, lzma
, stdenv
, ubootTools
} :
let
  objcopy = "${stdenv.cc.bintools.targetPrefix}objcopy";
  patchDtbCommand = if (fdt != null) then ''
    ( cat vmlinux.stripped ${fdt} > vmlinux.tmp ) && mv vmlinux.tmp vmlinux.stripped
  '' else ''
    echo patch-cmdline vmlinux.stripped '${commandLine}'
    patch-cmdline vmlinux.stripped '${commandLine}'
    echo
  '';
in
stdenv.mkDerivation {
  name = "kernel.image";
  phases = [ "buildPhase" "installPhase" ];
  nativeBuildInputs = [ patchImage lzma stdenv.cc ubootTools ];
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
