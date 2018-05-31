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

}
