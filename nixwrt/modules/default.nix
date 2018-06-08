{
  rsyncd = options: nixpkgs: configuration:
    with nixpkgs;
    nixpkgs.lib.attrsets.recursiveUpdate configuration  {
      services = {
        rsyncd = {
          start = "${pkgs.rsync}/bin/rsync --daemon";
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
        "rsyncd.secrets" = { mode= "0400"; content = "backup:${options.password}\n" ; };
      };

    };
  sshd = nixpkgs: configuration:
    nixpkgs.lib.attrsets.recursiveUpdate configuration  {
      services = with nixpkgs; {
        dropbear = {
          start = "${pkgs.dropbear}/bin/dropbear -s -P /run/dropbear.pid";
          hostKey = ../../ssh_host_key; # FIXME
        };
      };
    };
  dhcpClient = options: nixpkgs: configuration:
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
    in nixpkgs.lib.attrsets.recursiveUpdate configuration  {
      services.udhcpc = {
        start = "${options.busybox}/bin/udhcpc -H ${configuration.hostname} -p /run/udhcpc.pid -s '${dhcpscript}/bin/dhcpscript'";
        depends = [ options.interface ];
      };
    };
  syslogd = options: nixpkgs: configuration:
    with nixpkgs;
    lib.attrsets.recursiveUpdate configuration {
      services.syslogd = {
        start = "/bin/syslogd -R ${options.loghost}";
      };
    };
  ntpd = options: nixpkgs: configuration:
    with nixpkgs;
    lib.attrsets.recursiveUpdate configuration {
      services.ntpd = {
        start = "/bin/ntpd -p ${options.host}";
      };
    };
}
