self: super:
let
  stripped = p : p.overrideAttrs(o: { stripAllList = [ "bin" "sbin" ];});
in {
  lib = super.lib // rec {
    trace1 = x: builtins.trace (builtins.deepSeq x x) x;
    mergeConfigs = import ./merge_configs.nix { inherit (self) lib; };
    merge2Configs = a : b : mergeConfigs [a b];
  };

  busybox = stripped (super.busybox.overrideAttrs (o: {
    # busybox derivation has a postConfigure action conditional on
    # useMusl that forces linking against musl instead of the system
    # libc.  It does not appear to be required when musl *is* the
    # system libc, and for me it seems to be picking up the wrong
    # musl.  So let's get rid of it
    postConfigure = "true";
  }));

  coreutils =  super.coreutils.overrideAttrs (o: {
    # one of the tests fails under docker
    doCheck = !self.stdenv.isMips && o.doCheck;
  });

  dnsmasq = super.dnsmasq.overrideAttrs(o: {
    preBuild = "";
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

  git = if self.stdenv.isMips
        then
          super.git.override {
            # git manual uses various graphic libraries which use X
            # libraries which depend on Wayland (don't ask) which depends on
            # llvm, and llvm for some reason doesn't build today.
            perlSupport = false;
            withManual = false;
            pythonSupport = false;
          }
        else super.git;

  hostapd =
    let configuration = [
          "CONFIG_DRIVER_NL80211=y"
          "CONFIG_IAPP=y"
          "CONFIG_IEEE80211AC=y"
          "CONFIG_IEEE80211N=y"
          "CONFIG_IEEE80211W=y"
          "CONFIG_INTERNAL_LIBTOMMATH=y"
          "CONFIG_INTERNAL_LIBTOMMATH_FAST=y"
          "CONFIG_IPV6=y"
          "CONFIG_LIBNL32=y"
          "CONFIG_PKCS12=y"
          "CONFIG_RSN_PREAUTH=y"
          "CONFIG_TLS=internal"
        ];
        confFile = super.writeText "hostap.config"
          (builtins.concatStringsSep "\n" configuration);
    in stripped ((super.hostapd.override { sqlite = null; }).
      overrideAttrs(o:  {
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
  }).overrideAttrs (o @ {postInstall ? "", ...}: {
    # we don't need these and they depend on bash
    postInstall = postInstall + ''
      rm $out/sbin/routef $out/sbin/routel $out/sbin/rtpr $out/sbin/ifcfg

    '';
  }));

  kernelBuilders = import ./kernel { inherit (self) lib runCommand; };

  kexectools = let ovr = o @ {patches ? []
                              , buildInputs ? []
                              , nativeBuildInputs ? []
                              , ...}: {
    patches = patches ++ [
      (self.buildPackages.fetchpatch {
        name = "mips-uimage.patch";
        url = "https://github.com/telent/kexec-tools/compare/5aaa7b33d48b72e804509ebb47e250f1fc851a26.diff";
        sha256 = "1anx4rbswc6928d4z0wsrqf8x02s3r10pz08x01q6g3dwfcn7q2x";
      })
    ];
    buildInputs = buildInputs ++ [self.xz];
  }; in super.kexectools.overrideAttrs ovr;

  klogforward =
    let ref = "47af2c6d451b9fec6ceff96002cbb938bd056f8a"; in
    stripped (self.callPackage (builtins.fetchTarball "https://github.com/telent/klogforward/archive/${ref}.tar.gz" ) { } );

  libnl = (super.libnl.override({  pythonSupport = false; })).overrideAttrs (o: {
    outputs = [ "dev" "out" "man" ];
    preConfigure = ''
      configureFlagsArray+=(--enable-cli=no --disable-pthreads --disable-debug)
    '';
  });

  libpcap = super.libpcap.overrideAttrs (o: {
    # tcpdump only wants the shared libraries, not all the
    # headers and stuff
    outputs = if self.stdenv.isMips then [ "lib" "out" ] else ["out"];
  } // (if self.stdenv.isMips then { dontStrip = false; } else {})  );

  # we need to build real lzma instead of using xz, because the lzma
  # decoder in u-boot doesn't understand streaming lzma archives
  # ("Stream with EOS marker is not supported") and xz can't create
  # non-streaming ones.  See
  # https://sourceforge.net/p/squashfs/mailman/message/26599379/

  lzma = self.stdenv.mkDerivation {
    pname = "lzma";
    version = "4.32.7";
    configureFlags = [ "--enable-static" "--disable-shared"];
    srcs = super.buildPackages.fetchurl {
      url = "https://tukaani.org/lzma/lzma-4.32.7.tar.gz";
      sha256 = "0b03bdvm388kwlcz97aflpr3ir1zpa3m0bq3s6cd3pp5a667lcwz";
    };
  };

  monit = stripped (super.monit.override { usePAM = false; useSSL = false; openssl = null; });

  odhcp6c = stripped (self.callPackage ./pkgs/odhcp6c.nix { });

  patchImage = self.stdenv.mkDerivation {
    name = "patch-dtb";
    src = self.fetchFromGitHub {
      owner = "openwrt";
      repo = "openwrt";
      name = "openwrt-source" ;
      rev = "a74095c68c4fc66195f7c4885171e4f1d9e5c5e6";
      sha256 = "1kk4qvrp5wbrci541bjvb6lld60n003w12dkpwl18bxs9ygpnzlq";
    };
    configurePhase = "true";
    buildPhase = ''
      $CC -o patch-dtb tools/patch-image/src/patch-dtb.c
      $CC -o patch-cmdline tools/patch-image/src/patch-cmdline.c
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp patch-dtb patch-cmdline $out/bin
    '';
  };

  ppp = (super.ppp.override {
    libpcap = null;
  }).overrideAttrs (o : {
     stripAllList = [ "bin" ];
     buildInputs = [];

     patches =
       o.patches ++
       [(self.fetchpatch {
         name = "ipv6-script-options.patch";
         url = "https://github.com/telent/ppp/compare/ipv6-script-options.patch";
         sha256 = "0q6ackl3k8qqx4fdx56lsn57jics5qddk3sq5fgcnnvmgc6rjlhz";
       })];

     postPatch = ''
       sed -i -e  's@_PATH_VARRUN@"/run/"@'  pppd/main.c
       sed -i -e  's@^FILTER=y@# FILTER unset@'  pppd/Makefile.linux
     '';
     buildPhase = ''
       runHook preBuild
       make -C pppd CC=$CC USE_TDB= HAVE_MULTILINK= USE_EAPTLS= USE_CRYPT=y
       make -C pppd/plugins/pppoe CC=$CC
       make -C pppd/plugins/pppol2tp CC=$CC
       runHook postBuild;
     '';
     installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/lib/pppd/2.4.9
      cp pppd/pppd pppd/plugins/pppoe/pppoe-discovery $out/bin
      cp pppd/plugins/pppoe/pppoe.so $out/lib/pppd/2.4.9
      cp pppd/plugins/pppol2tp/{open,pppo}l2tp.so $out/lib/pppd/2.4.9
      runHook postInstall
    '';
    postFixup = "";
  });

  # we had trouble building rsync with acl support
  rsync = stripped (super.rsync.override { enableACLs = false; } );

  svc = self.callPackage ./services/service.nix {};

  strace = super.strace.override { libunwind = null; };

  swconfig =  stripped (self.callPackage ./pkgs/swconfig.nix { });

  tcpdump =super.tcpdump.overrideAttrs (o: { dontStrip = false; });

  utillinux = super.utillinux.override {
    systemd = null; ncurses = null;
  } ;

  xl2tpd = super.xl2tpd.overrideAttrs (o: {
    postPatch = ''
      substituteInPlace l2tp.h --replace /usr/sbin/pppd ${self.ppp}/bin/pppd

   '';
  });

  zlib = super.zlib.overrideAttrs (o: { dontStrip = false; });
}
