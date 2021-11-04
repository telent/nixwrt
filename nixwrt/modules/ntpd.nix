options: nixpkgs: self: super:
with nixpkgs;
lib.attrsets.recursiveUpdate super {
  busybox.applets = super.busybox.applets ++ [ "ntpd" ];
  services.ntpd = {
    start = "/bin/ntpd -p ${options.host}";
  };
}
