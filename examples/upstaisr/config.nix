# this is another wireless access point/bridge like extensino,
# but different hardware device
{ psk
, ssid
, loghost
, myKeys
, sshHostKey
, lib
, nixwrt
, ...
}:
let
  baseConfiguration = lib.recursiveUpdate
    nixwrt.emptyConfig {
      hostname = "upstaisr";
      webadmin = { allow = ["localhost" "192.168.8.0/24"]; };
      interfaces = {
        "eth0" = {
      	  depends = [];
        };
        "eth0.1" = {
          type = "vlan"; id = 1; parent = "eth0"; depends = [];
          memberOf = "br0";
        };
        "wlan0" = {
          type = "hostap";
          params = {
            ssid = ssid;
            country_code = "UK";
            channel = 10;
            hw_mode = "g";
            ieee80211n = 1;
            wmm_enabled = 1;
            wpa = 2;
            wpa_key_mgmt = "WPA-PSK";
            wpa_psk = psk;
            wpa_pairwise = "CCMP";
          };
          memberOf = "br0";
       };
        "br0" = {
          type = "bridge";
          enableStp = true;
          timeout = 90;
        };
        lo = { ipv4Address = "127.0.0.1/8"; };
      };
      users = [
        {name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
         shell="/bin/sh"; authorizedKeys = (lib.splitString "\n" myKeys);}
      ];
      packages = [ pkgs.iproute ];
      busybox = { applets = ["ln"]; };
    };

in (with nixwrt.modules;
  [(_ : _ : _ : baseConfiguration)
   (import <nixwrt/modules/lib.nix> {})
   (import <nixwrt/devices/gl-mt300n-v2.nix> {})
   (sshd { hostkey = sshHostKey ; })
   (_ : _ : super : { packages = super.packages ++ [ pkgs.iperf3 ] ; })
   busybox
   kernelMtd
   haveged
   (switchconfig {
     name = "switch0";
     interface = "eth0";
     vlans = {
       "1" = "0 1 6t";           # all the ports
     };
   })
   (dhcpClient { interface = "br0"; resolvConfFile = "/run/resolv.conf"; })
   (syslog { inherit loghost ; })
   (ntpd { host = "pool.ntp.org"; })
  ]
    # phramware offset = "0x900000"; sizeMB = "7";
