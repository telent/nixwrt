{
  firmware = { targetBoard } : (import ./backuphost.nix { inherit targetBoard; } ).firmware;
}
