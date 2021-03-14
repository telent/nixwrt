self: super:
let
  stripped = p : p.overrideAttrs(o: { stripAllList = [ "bin" "sbin" ];});
in {

  busybox = stripped (super.busybox.overrideAttrs (o: {
    # busybox derivation has a postConfigure action conditional on useMusl that
    # forces linking against musl instead of the system libc.  It does not appear
    # to be required when musl *is* the system libc, and for me it seems to be
    # picking up the wrong musl.  So let's get rid of it
    postConfigure = "true";

    src = self.fetchgit{
		url = "https://git.busybox.net/busybox";
		rev = "f25d254dfd4243698c31a4f3153d4ac72aa9e9bd";
		sha256 = "ArjFhuc8z06Anjj0axRqnHHU6/35NxkNoAj2vOC0B6Q=";
		};
  }));

  coreutils =  super.coreutils.overrideAttrs (o: {
    # one of the tests fails under docker
    doCheck = false;
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
    outputs = [ "lib" "out" ];
    dontStrip = false;
  });

  # I don't know why I can't get nixpkgs lua to build without readline
  # but it seems simpler to start from upstream than figure it out
  lua = with self; stdenv.mkDerivation {
    pname = "lua";
    version = "5.4.0";
    src = builtins.fetchurl {
      url = "https://www.lua.org/ftp/lua-5.4.0.tar.gz";
      sha256 = "0a3ysjgcw41x5r1qiixhrpj2j1izp693dvmpjqd457i1nxp87h7a";
    };
    stripAllList = [ "bin" ];

    postPatch = let ar = "${stdenv.hostPlatform.config}-ar"; in ''
      sed -i src/Makefile -e 's/^AR= ar/AR= ${ar}/'
      sed -i src/luaconf.h -e '/LUA_USE_DLOPEN/d' -e '/LUA_USE_READLINE/d'
    '';
    makeFlags = ["linux"
                 "CC=${stdenv.hostPlatform.config}-cc"
                 "RANLIB=${stdenv.hostPlatform.config}-ranlib"
                 "INSTALL_TOP=${placeholder "out"}"
                ];
    installPhase = ''
      mkdir -p $out/bin
      cp src/lua $out/bin
    '';
  };

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

  # temporary fix, not needed after patchelf 0.12
  #patchelf = super.patchelf.overrideAttrs(o@{patches ? [], ...} :
  #  let u = self.fetchurl {
  #    url = "https://patch-diff.githubusercontent.com/raw/NixOS/patchelf/pull/151.diff" ;
  #    sha256 = "12bzxf9ijqdkiqb9ljy4cra67hlmkyswd0yp88h8s06n3yc9d8gj";
  #  }; in {
  #    patches = patches ++ [u];
  #  });

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
     postPatch = ''
       sed -i -e  's@_PATH_VARRUN@"/run/"@'  pppd/main.c
     '';
     buildPhase = ''
       runHook preBuild
       make -C pppd USE_TDB= HAVE_MULTILINK= USE_EAPTLS= USE_CRYPT=y
       make -C pppd/plugins/rp-pppoe
       make -C pppd/plugins/pppol2tp
       runHook postBuild;
     '';
     installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/lib/pppd/2.4.8
      cp pppd/pppd pppd/plugins/rp-pppoe/pppoe-discovery $out/bin
      cp pppd/plugins/rp-pppoe/rp-pppoe.so $out/lib/pppd/2.4.8
      cp pppd/plugins/pppol2tp/{open,pppo}l2tp.so $out/lib/pppd/2.4.8
      runHook postInstall
    '';
    postFixup = "";
  });

  # we had trouble building rsync with acl support
  rsync = stripped (super.rsync.override { enableACLs = false; } );

  swconfig =  stripped (self.callPackage ./pkgs/swconfig.nix { });

  tcpdump =super.tcpdump.overrideAttrs (o: { dontStrip = false; });


  xl2tpd = super.xl2tpd.overrideAttrs (o: {
    postPatch = ''
      substituteInPlace l2tp.h --replace /usr/sbin/pppd ${self.ppp}/bin/pppd

   '';
  });

  zlib = super.zlib.overrideAttrs (o: { dontStrip = false; });
}
