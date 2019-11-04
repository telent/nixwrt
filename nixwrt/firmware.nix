{ stdenv
, kernelImage
, rootImage } :
stdenv.mkDerivation rec {
  name = "firmware.bin";
  phases = [ "installPhase" ];
  inherit kernelImage;
  installPhase = ''
    mkdir -p $out
    dd if=${kernelImage} of=$out/firmware.bin bs=128k conv=sync
    dd if=${rootImage}/image.squashfs of=$out/firmware.bin bs=128k conv=sync,nocreat,notrunc oflag=append
  '';
}
