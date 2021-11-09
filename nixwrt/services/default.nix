{ stdenv
, writeTextFile
, writeScript
, lib
, runtimeShell
, utillinux

,  baseDir ? "/run/services"
} :
let
  statefns =
    writeScript "state-fns.sh" ''
      state_dir="${baseDir}/$1"
      rmstate(){ rm $state_dir/$1; }
      setstate(){ mkdir -p $state_dir && echo "''${2-null}" > $state_dir/$1 ; }
    '';
in {
  name
, pid ? null
, start
, stop ? null
, outputs ? []
, depends ? []
, foreground ? false
} :
  let
    stop' = if (stop != null)
            then stop
            else if (pid != null)
            then "test -f ${pid} && ${utillinux}/bin/kill --signal 15 --timeout 15000 9 $(cat ${pid})"
            else "true";
    mkOutput = self : o : { service = self; outPath = o; };
    package =
      let waitDepends =
            if depends != []
            then "until test ${lib.strings.concatStringsSep " -a " (map (f: "-f ${f}") depends)} ; do sleep 1; done"
            else "";
          servicesForDepends = lib.lists.unique (map (f: f.service) depends);
      in writeScript "${name}-ctl" ''
          #! ${runtimeShell}
          . ${statefns} ${name}
          case $1 in
            start)
              if test -d ${baseDir}/${name}; then
                echo "service ${name}: already started"
              else
                mkdir ${baseDir}/${name}
                setstate blocked
                for d in ${lib.strings.concatStringsSep " " servicesForDepends}; do
                  $d start &
                done
                ${waitDepends}
                rmstate blocked
                ${start}
                ${if foreground then "echo ${name} process exited; $0 stop" else ""}
              fi
              ;;
            stop)
              ${stop'}
              rm -r ${baseDir}/${name}
              ;;
            *)
              echo "unrecognised action $1"
              exit 1
              ;;
           esac
      '';
    outputSet = lib.lists.foldr
      (el : m : m //
                (builtins.listToAttrs
                  [{name=el; value= (mkOutput package "${baseDir}/${name}/${el}");}]))
      {}
      (["blocked"] ++ outputs);
  in { inherit package statefns; } // outputSet
