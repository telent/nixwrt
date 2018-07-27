let derivations = import ./backuphost.nix {
  targetBoard = "mt300n_v2";
};
in rec {
  inherit (derivations) firmware;
}
