{
  rsyncd = nixpkgs: configuration:
    nixpkgs.lib.attrsets.recursiveUpdate configuration  {
      services = with nixpkgs; {
        rsyncd = {
          start = "${pkgs.rsync}/bin/rsync --daemon";
          depends = [ "eth0.2"];
        };
      };
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
