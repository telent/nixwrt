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

  # we had trouble building rsync with acl support, and
  rsync = super.rsync.override { enableACLs = false; } ;
}
