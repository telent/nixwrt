{ psk
, ssid
, loghost
, myKeys
, sshHostKey }:
let nixwrt = (import <nixwrt>) {}; in
with nixwrt.nixpkgs;
let
  baseConfiguration = lib.recursiveUpdate
    nixwrt.emptyConfig {
      hostname = "wrt1900acs";
      webadmin = { allow = ["localhost" "192.168.8.0/24"]; };
      users = [
        {name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
         shell="/bin/sh"; authorizedKeys = (stdenv.lib.splitString "\n" myKeys);}
      ];
      #packages = [ pkgs.iproute ];
    };

    wantedModules = with nixwrt.modules;
      [(_ : _ : _ : baseConfiguration)
       (import <nixwrt/modules/lib.nix> {})
       (import <nixwrt/devices/wrt1900acs.nix> {})
       (sshd { hostkey = sshHostKey ; })
       busybox
       kernelMtd
    ];

    in {
      firmware = nixwrt.firmware (nixwrt.mergeModules wantedModules);
      kernel = nixwrt.kernel (nixwrt.mergeModules wantedModules);
      # phramware generates an image which boots from the "fake" phram mtd
      # device - required if you want to boot from u-boot without
      # writing the image to flash first
      phramware =
        let phram_ = (nixwrt.modules.phram {
              offset = "0xa00000"; sizeMB = "7";
            });
            m = wantedModules ++ [phram_];
        in nixwrt.firmware (nixwrt.mergeModules m);
    }
