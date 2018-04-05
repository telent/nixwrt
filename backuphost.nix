let device = import ./devices/mt300a.nix ; in
with import ./nixwrt/default.nix device.platform;
let
  myKeys = (stdenv.lib.splitString "\n" ( builtins.readFile "/etc/ssh/authorized_keys.d/dan" ) );
  deviceKernelConfig = (device.kernel lib);
  extraKernelFlags = (lib.genAttrs [
    "USB_COMMON"
    "USB_STORAGE"
    "USB_UAS"
    "USB_ANNOUNCE_NEW_DEVICES"
    "SCSI" "BLK_DEV_SD" "USB_PRINTER"
    "MSDOS_PARTITION" "EFI_PARTITION"
    "EXT2_FS" "EXT3_FS" "EXT4_FS" "NTFS_FS"
    ] (name: "y"));
  kernelConfig = deviceKernelConfig // {
    overrideConfig = c:
      ((deviceKernelConfig.overrideConfig c) // extraKernelFlags);
  };
in
mkDerivations {
  interfaces = {
    wired = {
      device = "eth0";
      address = "192.168.0.251";
      defaultRoute = "192.168.0.254";
    };
  };
  kernel = kernelConfig;
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
  packages = let rsyncSansAcls = pkgs.rsync.override { enableACLs = false; } ;
             in [ rsyncSansAcls ];
  filesystems = {
    "/srv" = { label = "backup-disk";
               fstype = "ext4";
               options = "rw";
             };
  };
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
}
