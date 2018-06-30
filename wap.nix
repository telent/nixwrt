# Configuration for a wireless access point based on Atheros 9331
# (testing on Arduino Yun, deploying on Trendnet TEW712BR)

{ targetBoard ? "yun" }:
let nixwrt = (import ./nixwrt/default.nix) { inherit targetBoard; }; in
with nixwrt.nixpkgs;
let
    myKeys = stdenv.lib.splitString "\n"
              (builtins.readFile ("/etc/ssh/authorized_keys.d/" + builtins.getEnv( "USER"))) ;
    baseConfiguration = rec {
      hostname = "upstaisr";
      interfaces = {
        "eth0" = { };
        lo = { ipv4Address = "127.0.0.1/8"; };
        "wlan0" = { };
        "br0" = {
          type = "bridge";
          members  = [ "eth0" "wlan0" ];
        };
      };
      etc = {
        # We take these settings from the build machine.  This works for me but
        # you might wnt to do it differently
        "resolv.conf" = { content = ( stdenv.lib.readFile "/etc/resolv.conf" );};
      };
      users = [
        {name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
         shell="/bin/sh"; authorizedKeys = myKeys;}
      ];
      packages = [ ];
      filesystems = { };
      services = { };
    };
    wantedModules = with nixwrt.modules;
      [  (_ : _ : _ : baseConfiguration) ] ++
      nixwrt.device.hwModules ++
      [ (sshd { hostkey = ./ssh_host_key ; })
        busybox
        (syslogd { loghost = "192.168.0.2"; })
        (ntpd { host = "pool.ntp.org"; })
        (hostapd {
          config = { interface = "wlan0"; ssid = "telent"; hw_mode = "g"; channel = 1; };
          # no support for creating PSK from passphrase in nixwrt, so use wpa_passphrase
          psk = builtins.getEnv( "PSK") ;
        })
        (dhcpClient { interface = "br0"; })] ;
    kernelExtra = nixpkgs: self: super:
      nixpkgs.lib.recursiveUpdate super {
        kernel.config."MTD_SPLIT" = "y";
        kernel.config."MTD_SPLIT_UIMAGE_FW" = "y";
        kernel.commandLine = "${super.kernel.commandLine} mtdparts=spi0.0:64k(u-boot),64k(ART),64k(mac),64k(nvram),192k(language),3648k(firmware)";
      };

in {
  tftproot =
    let configuration = nixwrt.mergeModules (wantedModules ++ [
     (nixwrt.modules.tftpboot {rootOffset="0x1200000"; rootSizeMB="4"; })
     ]);
    in nixwrt.tftproot configuration;
  firmware = let
    configuration = nixwrt.mergeModules (wantedModules ++ [kernelExtra]);
    in nixwrt.firmware configuration;
}
