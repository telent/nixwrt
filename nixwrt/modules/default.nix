{
  hostapd = import ./hostapd.nix;
  rsyncd = options: nixpkgs: self: super:
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

    };
  sshd = nixpkgs: self: super:
    with nixpkgs;
    lib.attrsets.recursiveUpdate super  {
      pkgs = super.packages ++ [pkgs.dropbear];
      services = with nixpkgs; {
        dropbear = {
          start = "${pkgs.dropbear}/bin/dropbear -s -P /run/dropbear.pid";
          hostKey = ../../ssh_host_key; # FIXME
        };
      };
    };
  dhcpClient = options: nixpkgs: self: super:
    with nixpkgs;
    let dhcpscript = nixpkgs.writeScriptBin "dhcpscript" ''
      #!/bin/sh
      dev=${options.interface}
      deconfig(){
        ip addr flush dev $dev
      }
      bound(){
        ip addr replace $ip/$mask dev $dev ;
        ip route add 0.0.0.0/0 via $router;
      }
      case $1 in
        deconfig)
          deconfig
          ;;
        bound|renew)
          bound
          ;;
        *)
          echo unrecognised command $1
          ;;
      esac
      '';
    in nixpkgs.lib.attrsets.recursiveUpdate super  {
      services.udhcpc = {
        start = "${options.busybox}/bin/udhcpc -H ${self.hostname} -i ${options.interface} -p /run/udhcpc.pid -s '${dhcpscript}/bin/dhcpscript'";
        depends = [ options.interface ];
      };
    };
  syslogd = options: nixpkgs: self: super:
    with nixpkgs;
    lib.attrsets.recursiveUpdate super {
      services.syslogd = {
        start = "/bin/syslogd -R ${options.loghost}";
      };
    };
  ntpd = options: nixpkgs: self: super:
    with nixpkgs;
    lib.attrsets.recursiveUpdate super {
      services.ntpd = {
        start = "/bin/ntpd -p ${options.host}";
      };
    };
}
