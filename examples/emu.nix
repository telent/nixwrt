{ myKeys
, loghost
, sshHostKey }:
let nixwrt = (import <nixwrt>) { endian = "big";  }; in
with nixwrt.nixpkgs;
let
    baseConfiguration = lib.recursiveUpdate
      nixwrt.emptyConfig {
        hostname = "emu";
        webadmin = { allow = ["localhost" "192.168.8.0/24"]; };
        interfaces = {
          "eth0" = { } ;
          lo = { ipv4Address = "127.0.0.1/8"; };
        };
        users = [
          {name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
           shell="/bin/sh"; authorizedKeys = (lib.splitString "\n" myKeys);}
        ];
        packages = [ pkgs.iproute ];
        busybox = { applets = [ "poweroff" "halt" "reboot" ]; };
      };

    wantedModules = with nixwrt.modules;
      [(_ : _ : _ : baseConfiguration)
       (import <nixwrt/modules/lib.nix> {})
       (import <nixwrt/devices/qemu.nix> {})
       (sshd { hostkey = sshHostKey ; })
       busybox
       kernelMtd
#       (syslog { inherit loghost ; })
#       (ntpd { host = "pool.ntp.org"; })
       (dhcpClient {
         resolvConfFile = "/run/resolv.conf";
         interface = "eth0";
        })
      ];
    allConfig =  nixwrt.mergeModules wantedModules;
    qemu = nixwrt.nixpkgs.buildPackages.qemu.override {
      sdlSupport = false;
    };
in rec {
  emulator = writeScript "emulator" ''
#!${stdenv.shell}
rootfs=${nixwrt.rootfs allConfig}/image.squashfs
vmlinux=${allConfig.kernel.package}/vmlinux
dtb=${allConfig.kernel.package}/kernel.dtb
set +x
${qemu}/bin/qemu-system-mips  -M malta -m 128 -nographic  -kernel ''$vmlinux \
  -append ${builtins.toJSON allConfig.boot.commandLine} \
  -netdev user,id=mynet0,net=10.8.6.0/24,dhcpstart=10.8.6.4 \
  -device virtio-net-pci,netdev=mynet0 \
  -drive if=virtio,readonly=on,file=''$rootfs \
    -nographic
'';
}
