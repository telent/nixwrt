{ hostapd, svc, lib, writeText }:
{ name
, wlan
, psk
, params
, modloader
, debug ? false
} :
let ifname = wlan.name;
    cfg = {
      logger_stdout = -1; logger_stdout_level = 99;
      logger_syslog_level = 1;
      ctrl_interface = "/run/hostapd-${ifname}";
      ctrl_interface_group = 0;
    } // params;
    conf = writeText "hostap-${ifname}.conf"
      (lib.concatStringsSep "\n"
        (lib.attrsets.mapAttrsToList
          (k : v: "${k}=${builtins.toString v}" )
          cfg));
    pid = "/run/${name}.pid";
in svc {
  foreground = true;
  inherit name pid;
  depends = [ wlan.ready modloader.ready ];
   start = ''
    setstate ready true
    ${hostapd}/bin/hostapd ${if debug then "-d" else ""} -P ${pid} -i ${ifname} -S ${conf}
  '';
  outputs = ["ready"];
  config = {
    etc."hostapd.psk" = {
      mode= "0400"; content = "00:00:00:00:00:00 ${psk}\n" ;
    };
  };
}
