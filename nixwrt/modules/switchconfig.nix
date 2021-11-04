{ name, interface, vlans }: nixpkgs: self: super:
with nixpkgs;
let exe = "${pkgs.swconfig}/bin/swconfig";
    cmd = vlan : ports :
      "${exe} dev ${name} vlan ${vlan} set ports '${ports}'";
    script = lib.strings.concatStringsSep "\n"
      (["${exe} dev ${name} set reset 1"
        "${exe} dev ${name} set enable_vlan 1"] ++
      (lib.attrsets.mapAttrsToList cmd vlans)  ++
      ["${exe} dev ${name} set apply 1"]
      );
    scriptFile = writeScriptBin "switchconfig.sh" script;
in lib.attrsets.recursiveUpdate super {
  busybox.applets = super.busybox.applets ++ [ "touch" ];
  kernel.config."BRIDGE_VLAN_FILTERING" = "y";
  kernel.config."SWCONFIG" = "y";
  interfaces.${interface}.depends =  [ name ];
  services.${name} = {
    start = "${self.busybox.package}/bin/sh -c '${scriptFile}/bin/switchconfig.sh'";
    type = "oneshot";
  };
}
