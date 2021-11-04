options: nixpkgs: self: super:
with nixpkgs;
nixpkgs.lib.attrsets.recursiveUpdate super  {
  services = {
    rsyncd = {
      start = "${pkgs.rsync}/bin/rsync --daemon";
    };
  };
  packages = super.packages ++ [ pkgs.rsync ];
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
    "rsyncd.secrets" = { mode= "0400"; content = "backup:${options.password}\n" ; };
  };

}
