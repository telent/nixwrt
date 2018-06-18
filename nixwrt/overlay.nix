self: super: {

  # we need to build real lzma instead of using xz, because the lzma
  # decoder in u-boot doesn't understand streaming lzma archives
  # ("Stream with EOS marker is not supported") and xz can't create
  # non-streaming ones.  See
  # https://sourceforge.net/p/squashfs/mailman/message/26599379/

  lzma = super.buildPackages.stdenv.mkDerivation {
    name = "lzma";
    version = "4.32.7";
    # workaround for "forbidden reference to /tmp" message which will one
    # day be fixed by a new patchelf release
    # https://github.com/NixOS/nixpkgs/commit/cbdcc20e7778630cd67f6425c70d272055e2fecd
    preFixup = ''rm -rf "$(pwd)" && mkdir "$(pwd)" '';
    srcs = super.buildPackages.fetchurl {
      url = "https://tukaani.org/lzma/lzma-4.32.7.tar.gz";
      sha256 = "0b03bdvm388kwlcz97aflpr3ir1zpa3m0bq3s6cd3pp5a667lcwz";
    };
  };

  monit = super.monit.override { usePAM = false; openssl = null; };

  kernel = super.callPackage ./kernel/default.nix {};

  swconfig =  super.callPackage ./swconfig.nix {};

  iproute = super.iproute.override {
    # db cxxSupport causes closure size explosion because it drags in
    # gcc as runtime dependency.  I don't think it needs it, it's some
    # kind of rpath problem or similar
    db = super.db.override { cxxSupport = false;};
  };

  hostapd = let configuration = [
     "CONFIG_DRIVER_NL80211=y"
     "CONFIG_IAPP=y"
     "CONFIG_IEEE80211W=y"
     "CONFIG_IPV6=y"
     "CONFIG_LIBNL32=y"
     "CONFIG_PKCS12=y"
     "CONFIG_RSN_PREAUTH=y"
     "CONFIG_TLS=internal"
     "CONFIG_INTERNAL_LIBTOMMATH=y"
     "CONFIG_INTERNAL_LIBTOMMATH_FAST=y"
  ];
  confFile = super.writeText "hostap.config"
      (builtins.concatStringsSep "\n" configuration);
  in (super.hostapd.override { sqlite = null; }).overrideAttrs(o:  {
      extraConfig = "";
      configurePhase = ''
        cp -v ${confFile} hostapd/defconfig
        ${o.configurePhase}
      '';
  });

  iprouteSansBash = (super.iproute.override {
    # db dep is only if we need arpd
    db = null; iptables = null;
  }).overrideAttrs (o: {
    # we don't need these and they depend on bash
    postInstall = ''
      rm $out/sbin/routef $out/sbin/routel $out/sbin/rtpr $out/sbin/ifcfg
    '';
  });

  busybox = super.busybox.overrideAttrs (o: {
    # busybox derivation has a postConfigure action conditional on useMusl that
    # forces linking against musl instead of the system libc.  It does not appear
    # to be required when musl *is* the system libc, and for me it seems to be
    # picking up the wrong musl.  So let's get rid of it
    postConfigure = "true";
  });

  # we had trouble building rsync with acl support, and
  rsync = super.rsync.override { enableACLs = false; } ;
}
