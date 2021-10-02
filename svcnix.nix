{ stdenv
, writeTextFile
, writeScript
, lib
, runtimeShell
, utillinux

,  baseDir ? "/run/services"
} :
rec {
  statefns =
    writeScript "state-fns.sh" ''
      state_dir="${baseDir}/$1"
      rmstate(){ rm $state_dir/$1; }
      setstate(){ mkdir -p $state_dir && echo $2 > $state_dir/$1 ; }
    '';
  build = {
    name
    , pid ? null
    , start
    , stop ? null
    , outputs ? []
    , depends ? []
  } :
    let
      stop' = if (stop != null)
              then stop
              else if (pid != null)
              then "test -f ${pid} && ${utillinux}/bin/kill --signal 15 --timeout 15000 9 $(cat ${pid})"
              else "true";
      outputSet = lib.lists.foldr
        (el : m : m //
                  (builtins.listToAttrs
                    [{name=el; value= "${baseDir}/${name}/${el}";}]))
        {}
        (["blocked"] ++ outputs);
      package =
        let waitDepends =
              if depends != []
              then "setstate blocked; until test ${lib.strings.concatStringsSep " -a " (map (f: "-f ${f}") depends)} ; do sleep 1; done; rmstate blocked"
              else "";
        in writeScript "${name}-ctl" ''
          #! ${runtimeShell}
          . ${statefns} ${name}
          case $1 in
            start)
              if test -d ${baseDir}/${name}; then
                echo "service $name: already started"
              else
                mkdir ${baseDir}/${name}
                ${waitDepends}
                ${start}
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
    in { inherit package; } // outputSet;
}
