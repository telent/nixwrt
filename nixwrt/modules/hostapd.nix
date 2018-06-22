options: nixpkgs: self: super:
with nixpkgs;
let config = {
      driver = "nl80211";
      logger_syslog = "-1";
      logger_syslog_level = 1;
      ctrl_interface = "/run/hostapd";
      ctrl_interface_group = 0;
      macaddr_acl = 0;
      max_num_sta = 255;
      auth_algs = 1; # 1=wpa2, 2=wep, 3=both
      wpa = 2;       # 1=wpa, 2=wpa2, 3=both
      wpa_key_mgmt = "WPA-PSK";
      wpa_psk_file = "/etc/hostapd.psk";
      wpa_pairwise = "TKIP CCMP";   # auth for wpa (may not need this?)
      rsn_pairwise = "CCMP";        # auth for wpa2
    } // options.config;
    hostapdConf = writeText "hostapd.conf"
      (builtins.concatStringsSep
        "\n"
        (lib.mapAttrsToList
          (name: value: "${name}=${builtins.toString value}")
          config));

in nixpkgs.lib.attrsets.recursiveUpdate super  {
  services.hostapd = {
    start = "${pkgs.hostapd}/bin/hostapd -B -P /run/hostapd.pid -S ${hostapdConf}";
  };
  packages = super.packages ++ [ pkgs.hostapd ];
  # this is a separate file so that secrets don't end up in the nix store
  etc."hostapd.psk" = { mode= "0400"; content = "00:00:00:00:00:00 ${options.psk}\n" ; };
}
