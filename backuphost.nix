with import <nixpkgs> {};  
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
  myKeys = (stdenv.lib.splitString "\n" ( builtins.readFile "/etc/ssh/authorized_keys.d/dan" ) );
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
    };
    users = [
      {name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
       shell="/bin/sh"; authorizedKeys = myKeys;}
      {name="store"; uid=500; gid=500; gecos="Storage owner"; dir="/srv";
       shell="/dev/null"; authorizedKeys = [];}
      {name="dan"; uid=1000; gid=1000; gecos="Daniel"; dir="/home/dan";
       shell="/bin/sh"; authorizedKeys = myKeys;}
    ];
    services = {
      dropbear = {
        start = "${pkgs.dropbear}/bin/dropbear -s -P /run/dropbear.pid";
        depends = [ "wired"];
        hostKey = ./ssh_host_key;
      };
      syslogd = { start = "/bin/syslogd -R 192.168.0.2"; 
                  depends = ["wired"]; };
      ntpd =  { start = "/bin/ntpd -p pool.ntp.org" ;
                depends = ["wired"]; };
    };

  };
in ((import ./nixwrt) platform config).tftproot
#in { foo = myKeys ;}
