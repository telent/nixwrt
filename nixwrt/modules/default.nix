{
  rsyncd = nixpkgs: configuration:
    with nixpkgs; nixpkgs.lib.attrsets.recursiveUpdate configuration  {
      services = {
        rsyncd = {
          start = "${pkgs.rsync}/bin/rsync --daemon";
          depends = [ "eth0.2"];
        };
      };
      packages = configuration.packages ++ [ pkgs.rsync ];
    };
  sshd = nixpkgs: configuration:
    nixpkgs.lib.attrsets.recursiveUpdate configuration  {
      services = with nixpkgs; {
        dropbear = {
          start = "${pkgs.dropbear}/bin/dropbear -s -P /run/dropbear.pid";
          depends = [ "eth0.2"];
          hostKey = ../../ssh_host_key; # FIXME
        };
      };
  };
}
