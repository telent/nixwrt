self: super:
let stripped = p : p.overrideAttrs(o: { stripAllList = [ "bin" "sbin" ];});
in {

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

  kexectools = let ovr = o @ {patches ? []
                              , buildInputs ? []
                              , nativeBuildInputs ? []
                              , ...}: {
    patches = patches ++ [
      (self.buildPackages.fetchpatch {
        name = "mips-uimage.patch";
        url = "https://github.com/telent/kexec-tools/compare/f1c610f3e3f5e773295bf15764b391055f5cabfe.diff";
        sha256 = "1b5yilvvinic33y9l2wqbxx5b7j6dva8d4kgv658fm8xvskqiap9";
      })
    ];
    buildInputs = buildInputs ++ [self.xz];
  }; in super.kexectools.overrideAttrs ovr;

  ubootMalta = self.pkgs.buildUBoot rec {
    name = "uboot-malta";
    defconfig = "qemu_mipsel_defconfig";
    extraMeta.platforms = self.stdenv.lib.platforms.linux;# ["mipsel-unknown-linux-musl"];
    filesToInstall = ["u-boot.bin"];
  };

  monit = stripped (super.monit.override { usePAM = false; openssl = null; });

  # temporary until patchelf#151 is applied upstream and nixpkgs gets new revision
  patchelf = super.patchelf.overrideAttrs(o@{patches ? [], ...} :
    let u = self.fetchurl {
      url = "https://patch-diff.githubusercontent.com/raw/NixOS/patchelf/pull/151.diff" ;
      sha256 = "12bzxf9ijqdkiqb9ljy4cra67hlmkyswd0yp88h8s06n3yc9d8gj";
    }; in {
      patches = patches ++ [u];
  });


  swconfig =  stripped (self.callPackage ./swconfig.nix { });

  libnl = (super.libnl.override({  pythonSupport = false; })).overrideAttrs (o: {
    outputs = [ "dev" "out" "man" ];
    preConfigure = ''
      configureFlagsArray+=(--enable-cli=no --disable-pthreads --disable-debug)
    '';
  });

  dropbearSmall = stripped (super.dropbear.overrideAttrs (o: {
    PROGRAMS = "dropbear";
    LDFLAGS="-Wl,--gc-sections";
    CFLAGS="-ffunction-sections -fdata-sections";

    preConfigure =
      let undefs = [
                    "DO_MOTD"
                    "DROPBEAR_3DES"
                    "DROPBEAR_CURVE25519"
                    "DROPBEAR_DELAY_HOSTKEY"
                    "DROPBEAR_DH_GROUP1"
                    "DROPBEAR_DH_GROUP16"
                    "DROPBEAR_DSS"
                    "DROPBEAR_ECDSA"
                    "DROPBEAR_ECDH"
                    "DROPBEAR_ENABLE_CBC_MODE"
                    "DROPBEAR_PASSWORD_ENV"
                    "DROPBEAR_SHA1_96_HMAC"
                    "DROPBEAR_TWOFISH128"
                    "DROPBEAR_TWOFISH256"
                    "ENABLE_SVR_AGENTFWD"
                    "ENABLE_SVR_LOCALTCPFWD"
                    "DROPBEAR_SVR_PASSWORD_AUTH"
                    "ENABLE_SVR_REMOTETCPFWD"
                    "ENABLE_USER_ALGO_LIST"
                    "ENABLE_X11FWD"
                    "INETD_MODE"
                    "SFTPSERVER_PATH"];
      toInsert = builtins.concatStringsSep "\n"
                  (map (n: "#undef ${n}") undefs);
      in ''
         echo "${toInsert}"  > localoptions.h
      '';


  }));

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
  in stripped ((super.hostapd.override { sqlite = null; }).overrideAttrs(o:  {
      extraConfig = "";
      configurePhase = ''
        cp -v ${confFile} hostapd/defconfig
        ${o.configurePhase}
      '';
  }));

  iprouteFull = super.iproute;
  iproute = stripped ((super.iproute.override {
    # db dep is only if we need arpd
    db = null; iptables = null;
  }).overrideAttrs (o: {
    # we don't need these and they depend on bash
    postInstall = o.postInstall + ''
      rm $out/sbin/routef $out/sbin/routel $out/sbin/rtpr $out/sbin/ifcfg

    '';
  }));

  busybox = stripped (super.busybox.overrideAttrs (o: {
    # busybox derivation has a postConfigure action conditional on useMusl that
    # forces linking against musl instead of the system libc.  It does not appear
    # to be required when musl *is* the system libc, and for me it seems to be
    # picking up the wrong musl.  So let's get rid of it
    postConfigure = "true";
  }));

  # we had trouble building rsync with acl support, and
  rsync = stripped (super.rsync.override { enableACLs = false; } );

}
