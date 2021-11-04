{
  busybox = import ./busybox.nix;
  dhcpClient = import ./dhcp_client.nix;
  haveged = import ./haveged.nix;
  hostapd = import ./hostapd.nix;
  kernelMtd =  import ./kernel-mtd.nix;
  kexec = import ./kexec.nix;
  l2tp = import ./l2tp.nix;
  ntpd = import ./ntpd.nix;
  phram = import ./phram.nix;
  pppoe = import ./pppoe.nix;
  rsyncd = import ./rsyncd.nix;
  sshd = import ./sshd.nix;
  switchconfig = import ./switchconfig.nix;
  syslog = import ./syslog.nix;
  usbdisk = import ./usbdisk.nix;
  user = import ./user.nix;
  virtio9p = import ./virtio9p.nix;
}
