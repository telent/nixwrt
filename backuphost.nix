with import <nixpkgs>; 
let
  platform = {
    uboot = null;
    endian = "big";
    name = "yun";
    kernelArch = "mips";
    gcc = { abi = "32"; } ;
    bfdEmulation = "elf32btsmip";
    kernelHeadersBaseConfig = "ath79_defconfig";
/*    kernelBaseConfig = "ath79_defconfig";
    kernelTarget = "uImage";
    kernelAutoModules = false;
    kernelModules = false;      
    kernelPreferBuiltin = true; 
*/
};
 config = { pkgs, stdenv, ... } : {
    interfaces = {
      wired = {
        device = "eth1";
        address = "192.168.0.251";
        defaultRoute = "192.168.0.254";
      };
    };
    etc = {
      "resolv.conf" = { content = ( stdenv.lib.readFile "/etc/resolv.conf" );};
#      "resolv.conf" = { content = "cxbvS";};
    };
    services = {
      dropbear = {
        start = "${pkgs.dropbear}/bin/dropbear -s -P /run/dropbear.pid";
        depends = [ "wired"];
        hostKey = ./ssh_host_key;
        authorizedKeys = stdenv.lib.strings.splitString "\n" ( builtins.readFile "/etc/ssh/authorized_keys.d/dan" );
      };
      syslogd = { start = "/bin/syslogd -R 192.168.0.2"; 
                  depends = ["wired"]; };
      ntpd =  { start = "/bin/ntpd -p pool.ntp.org" ;
                depends = ["wired"]; };
    };  

    };
in (import ./nixwrt) platform config
