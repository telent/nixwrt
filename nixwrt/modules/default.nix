{
  rsyncd = cfg: nixpkgs: configuration:
    with nixpkgs;
    nixpkgs.lib.attrsets.recursiveUpdate configuration  {
      services = {
        rsyncd = {
          start = "${pkgs.rsync}/bin/rsync --daemon";
          depends = [ "eth0.2"];
        };
      };
      packages = configuration.packages ++ [ pkgs.rsync ];
      etc = {
        "rsyncd.conf" = {
          content = ''
            pid file = /run/rsyncd.pid
            uid = store
            [srv]
              path = /srv
              use chroot = yes
              auth users = backup
              read only = false
              secrets file = /etc/rsyncd.secrets
            '';
        };
        "rsyncd.secrets" = { mode= "0400"; content = "backup:${cfg.password}\n" ; };
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
