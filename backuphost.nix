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
  };
  myKeys = (stdenv.lib.splitString "\n" ( builtins.readFile "/etc/ssh/authorized_keys.d/dan" ) );
  config = { pkgs, stdenv, ... } : {
    kernel = {
      enableKconfig = [
        "USB_COMMON"
        "USB_STORAGE"
        "USB_STORAGE_DEBUG"
        "USB_UAS"
        "CONFIG_USB_ANNOUNCE_NEW_DEVICES"
        "SCSI" "BLK_DEV_SD" "USB_PRINTER"
        "PARTITION_ADVANCED"
        "MSDOS_PARTITION" "EFI_PARTITION" "CMDLINE_PARTITION"
      ];
    };
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
    packages =
     let rsync = pkgs.rsync.override { enableACLs = false; } ;
     in
     [ rsync
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
in ((import ./nixwrt) platform config)
