_: nixpkgs: self: super:
with nixpkgs;
lib.recursiveUpdate super {
  packages = super.packages ++ [ pkgs.kexectools ];
  kernel.config."KEXEC" = "y";
}
