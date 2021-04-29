# this is a derivation I use to build a qemu vm for testing my home
# internet router against. It runs a (very rudimentary) pppoe server,
# and also tftp so that the device can download its firmware image.


# To set up:
#
# The machine it runs on has a second ethernet card dedicated to the
# test device, so that it doesn't leak bad things onto my regular
# LAN/internet.  This means I need to stop the host from seeing the card
# by doing something like this in its configuration.nix
#
# boot = {
#   kernelParams = [ "intel_iommu=on" ];
#   kernelModules = [ "kvm-intel" "vfio_virqfd" "vfio_pci" "vfio_iommu_type1" "vfio" ];
#   postBootCommands = ''
#     echo vfio-pci > /sys/bus/pci/devices/0000:01:00.0/driver_override
#     modprobe -i vfio-pci
#   '';
# };

# To build:
#
# nix-build '<nixpkgs/nixos>' -A vm --arg configuration ./nol.nix -o nol

# To run:
#
# echo 0 | sudo tee /proc/sys/net/bridge/bridge-nf-call-iptables
# echo 0 | sudo tee /proc/sys/net/bridge/bridge-nf-call-ip6tables
#
# test nol.qcow2 -ot nol.nix && rm nol.qcow2
# sudo SHARED_DIR=`pwd` QEMU_OPTS='-netdev tap,id=net0,ifname=tap0,script=no,downscript=no -device virtio-net-pci,netdev=net0 -nographic -serial mon:stdio -device vfio-pci,host=01:00.0 -m 1024 ' ./nol/bin/run-nol-vm

# inside the vm, run sudo sysctl  net.ipv4.ip_forward=1 to forward traffic
# from the device

{config, pkgs, ...}:n
let startppp = pkgs.writeScriptBin "start-ppp" ''
  #!${pkgs.bash}/bin/bash
  ${pkgs.rpPPPoE}/bin/pppoe-server -F  -I eth2 -O /etc/pppoe-server-options
'';

in
{
  imports = [

    # Provide an initial copy of the NixOS channel so that the user
    # doesn't need to run "nix-channel --update" first.
    <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
  ];
  # Enable SSH in the boot process.
  systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];

  systemd.services.pppserverd = {
    enable=true;
    description = "ppp server";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${startppp}/bin/start-ppp";
      Restart = "always";
    };
    wantedBy = ["multi-user.target"];
  };

  services.dnsmasq = {
    enable = true;
    servers = [ "8.8.8.8" "8.8.4.4" ];
    extraConfig = ''
    dhcp-range=10.0.0.22,10.0.0.200
    interface=ens10
'';
  };

  services.atftpd = {
    enable = true;
    extraOptions = ["--bind-address 10.0.0.1"];
    root = "/tmp/shared/";
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+vxEVY7fZywS88tlgjqCVA9CQxChsN68G/UIEtXBoPI2/ufM4Esn6Mp113Ru7tM2Aarha2qxoibvXD8U8Gr88qU4CfS462rtzj6HrLNy+Uo/K/uVHaohe29qxqZjO2OZ8xwdXpf9QDthXf48mpKYghZWBfLAmDje90vPwZhHSMV6Z/X0Lv1zUQw6zd7kE56MkGwyT7379fmwJodQ+73KAlJsgpu8fxcBAcc3bgGrPMObCfvU21ilkMim10FXCUjfr9Rn/s+3QrKgsX6TuDaztLYEMG7eYmlcK1j8EWtSezLoBkvnmLD3dLKKpwl8lJ5u4HykA53DrAeJSD8z0stiH dan@noetbook"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCjSWxutcdErJKJ1Jslw4q1Xa9YPhUQF9dHQysE5ItAbDLp3fZciEZzQqvjFAs8LQziojCqDpfKqoNrQqEVHtjKYDivMqs7TZEv3W4DjGwh5nT1zPjwkXhrAaFp+vQM2EOICqq/wdJK3OmFG4GsF/UMUMsn5+4Qs8QXpxCwcIKFefRfLWcATF8VGgIsf2+ZvGNPVwY7jqe5oqtG3B/rAaCyRk/PkXDL1rmZyfkNKZvEs/f8pxGsgu4UCdz3TXJPOKEzWtCRcyshIFJ0uF0VAs48F/3NkfVI63sA5q83Jzlwj57FLDNfTPEeGPqHJXcjb1iu8ysJ1asWW0fxyHPH6hKd dan@loaclhost"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDeWdZ3MDWUMwZm25q2kC4xsjUXDypOwKTolrj/BaG8by90rsytLSVuh+xOIrcxKQWezDMTbBjA6LJtXFHzJ+IIBpd+x6QMx0UdLGJ68q8cikg5rveLoqDgMd1TSGfqzEBCRfvLMe38hLNHB1g3hnzdWKgd0cEk7rNCwk/vlHFmH2vKN+XCx2pz9p0wq3z7aKIJnUype2jvwhFv9l3wtGsmBYYq1b3WOlgyD+oFZvWECdrKZ6BxNXb2/STZ8eLQ5izh+KLvUrcs6BrXqzgSDFVqJ40qE5/6Y5MIfxzJQF7ax4bV6G0WQaRQa6592E3G2geWjB6f5Au2WRbXeN0nWaM3 dan@tninkpad"

  ];
  users.mutableUsers = false;
  users.users.root.password = "busmechanic";

  networking = {
    hostName = "nol"; # Define your hostname.
    enableIPv6 = true;

    firewall = {
      allowedUDPPorts = [
        67 # bootps
        68 # bootpc
        69 # tftp
      ];
    };

    # interfaces.ens9 = {
    #   useDHCP = true;
    # };

    interfaces.ens9 = {
      useDHCP = false;
      ipv4.addresses = [ { address = "10.0.0.1"; prefixLength = 24;}];
    };

  };
#     49  echo "1" > /proc/sys/net/ipv4/ip_forward

  environment.systemPackages = with pkgs; [
    wget vim rpPPPoE pciutils tcpdump
  ];
  environment.etc."ppp/pap-secrets" = {
    text = "db399@a.1 * JumpyHitch35 *\n";
    mode = "0400";
  };
  environment.etc."pppoe-server-options" = {
    text = ''
debug
require-pap
lcp-echo-interval 10
lcp-echo-failure 2
+ipv6
'';
  };
  services.openssh.enable = true;
  services.openssh.passwordAuthentication = true;

  system.stateVersion = "17.09"; # Did you read the comment?
}
