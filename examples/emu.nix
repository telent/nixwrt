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
           shell="/bin/sh"; authorizedKeys = (stdenv.lib.splitString "\n" myKeys);}
        ];
        packages = [ pkgs.iproute ];
      };

    wantedModules = with nixwrt.modules;
      [(_ : _ : _ : baseConfiguration)
       (import <nixwrt/modules/lib.nix> {})
       (import <nixwrt/devices/qemu.nix> {})
       (sshd { hostkey = sshHostKey ; })
       busybox
       kernelMtd
       (syslog { inherit loghost ; })
       (ntpd { host = "pool.ntp.org"; })
       (dhcpClient {
         resolvConfFile = "/run/resolv.conf";
         interface = "eth0";
        })
      ];
    allConfig =  nixwrt.mergeModules wantedModules;
in rec {
  emulator = writeScriptBin "emulator" ''
rootfs=${nixwrt.rootfs allConfig}/image.squashfs
vmlinux=${allConfig.kernel.package}/vmlinux
dtb=${allConfig.kernel.package}/kernel.dtb
set +x
qemu-system-mips  -M malta -m 128 -nographic  -kernel ''$vmlinux \
  -append ${builtins.toJSON allConfig.boot.commandLine} \
    -drive if=virtio,readonly=on,file=''$rootfs \
    -nographic
# qemu-system-mips  -M malta -m 128 -nographic  -kernel ''$vmlinux \
#  -append ${builtins.toJSON allConfig.boot.commandLine} \
#    -blockdev driver=file,node-name=squashed,read-only=on,filename=''$rootfs \
#      -blockdev driver=raw,node-name=rootfs,file=squashed,read-only=on \
#        -device ide-cd,drive=rootfs -nographic
'';
}
