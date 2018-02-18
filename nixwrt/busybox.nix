{ stdenv, pkgs, applets }:
let lib = stdenv.lib; bb = pkgs.busybox.override {
    enableStatic = true;
    enableMinimal = true;
    extraConfig = ''
      CONFIG_ASH y
      CONFIG_ASH_ECHO y
      CONFIG_BASH_IS_NONE y
      CONFIG_ASH_BUILTIN_ECHO y
      CONFIG_ASH_BUILTIN_TEST y
      CONFIG_ASH_OPTIMIZE_FOR_SIZE y
      CONFIG_FEATURE_MOUNT_LABEL y
      CONFIG_FEATURE_MOUNT_FLAGS y      
      CONFIG_FEATURE_REMOTE_LOG y
      CONFIG_FEATURE_USE_INITTAB y
      CONFIG_FEATURE_PIDFILE y
      CONFIG_FEATURE_BLKID_TYPE y
      CONFIG_FEATURE_VOLUMEID_EXT y
      CONFIG_PID_FILE_PATH "/run"
      CONFIG_FEATURE_SYSLOGD_READ_BUFFER_SIZE 256
      '' + builtins.concatStringsSep
              "\n" (map (n : "CONFIG_${lib.strings.toUpper n} y") applets);
  }; in lib.overrideDerivation bb (a: {
    LDFLAGS = "-L${stdenv.cc.libc.static}/lib";
  })
