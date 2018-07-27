let derivations = import ./backuphost.nix { targetBoard = "mt300n_v2"; };
in rec {
  firmware = derivations.firmware.overrideAttrs {
    SSH_PUBLIC_KEYS="ssh-rsa AAAABLAHBLAH dan@example.org";
    RSYNC_PASSWORD="urbancookiecollective";
  };
}
