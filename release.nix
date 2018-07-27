let apps = { backuphost = ./backuphost.nix; wap = ./wap.nix; };
in
{
  firmware = { targetBoard, application } :
             (import (apps.${application}) { inherit targetBoard; } ).firmware;
}
