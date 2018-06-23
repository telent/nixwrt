{
  hostapd = import ./hostapd.nix;

  busybox = import ./busybox.nix;

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
  sshd = options: nixpkgs: self: super:
    with nixpkgs;
    lib.attrsets.recursiveUpdate super  {
      pkgs = super.packages ++ [pkgs.dropbearSmall];
      services = with nixpkgs; {
        dropbear = {
          start = "${pkgs.dropbearSmall}/bin/dropbear -P /run/dropbear.pid";
          hostKey = options.hostkey;
        };
      };
    };
  dhcpClient = import ./dhcp_client.nix;

  syslogd = options: nixpkgs: self: super:
    with nixpkgs;
    lib.attrsets.recursiveUpdate super {
      busybox.applets = super.busybox.applets ++ [ "syslogd" ];
      busybox.config."FEATURE_SYSLOGD_READ_BUFFER_SIZE" = 256;
      busybox.config."FEATURE_REMOTE_LOG" = "y";
      services.syslogd = {
        start = "/bin/syslogd -R ${options.loghost}";
      };
    };
  ntpd = options: nixpkgs: self: super:
    with nixpkgs;
    lib.attrsets.recursiveUpdate super {
      busybox.applets = super.busybox.applets ++ [ "ntpd" ];
      services.ntpd = {
        start = "/bin/ntpd -p ${options.host}";
      };
    };

  # Add this module when you want separate tftp-bootable images that
  # run from RAM instead of a single flashable firmware image.  Resulting images
  # may be bigger, but hopefully your device has more RAM than flash
  tftpboot = nixpkgs: self: super:
    nixpkgs.lib.recursiveUpdate super { kernel.config."MTD_PHRAM" = "y"; };

}
