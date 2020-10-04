lib : filesystems :
let baseFilesystems = ''
        proc /proc proc rw 0 0
        tmpfs /tmp tmpfs rw 0 0
        tmpfs /run tmpfs rw 0 0
        sysfs /sys sysfs rw 0 0
        devtmpfs /dev devtmpfs rw 0 0
    '';
    fstabLine = mountpoint : attrs : ''
       LABEL=${attrs.label} ${mountpoint} ${attrs.fstype} ${attrs.options} 0 0
    '';
in baseFilesystems + lib.strings.concatStringsSep "\n" (lib.attrsets.mapAttrsToList fstabLine filesystems)
