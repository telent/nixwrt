nixpkgs: self: super:
  with nixpkgs;
  let derivationAttrs = { config, applets } :
    let xconfig = builtins.concatStringsSep "\n"
      (lib.mapAttrsToList (n: v: "CONFIG_${pkgs.lib.strings.toUpper n} ${toString v}") config);
        aconfig = builtins.concatStringsSep "\n"
      (map (n: "CONFIG_${pkgs.lib.strings.toUpper n} y") applets);
    in {
      enableMinimal = true;
      extraConfig = ''
        ${xconfig}
        ${aconfig}
      '';
    };
  in lib.attrsets.recursiveUpdate super {
      # we can probably pare this down a bit further if we're really pushed for space
      busybox.applets = [
          "cat"
          "chmod"
          "chown"
          "cp"
          "dd"
          "df"
          "dmesg"
          "du"
          "find"
          "grep"
          "gzip"
          "init"
          "kill"
          "ls"
          "mkdir"
          "mount"
          "mv"
          "ping"
          "ps"
          "reboot"
          "rm"
          "rmdir"
          "stty"
          "tar"
          "umount"
          "zcat"
        ] ++ lib.attrByPath ["busybox" "applets"] [] super;

      busybox.config = {
        "ASH" = "y";
        "ASH_BUILTIN_ECHO" = "y";
        "ASH_BUILTIN_TEST" = "y";
        "ASH_ECHO" = "y";
        "ASH_OPTIMIZE_FOR_SIZE" = "y";
        "BASH_IS_NONE" = "y";
        "FEATURE_PIDFILE" = "y"; # monit needs this
        "FEATURE_USE_INITTAB" = "y"; # monit needs this
        "PID_FILE_PATH" = builtins.toJSON "/run";
      } // lib.attrByPath ["busybox" "config"] {} super;

      busybox.package = pkgs.busybox.override (derivationAttrs {
        config = self.busybox.config ;
        applets = self.busybox.applets;
      });
    }
