sudo id
set -e
echo "^/ ${PWD}" >/tmp/atftpd.map
nix run nixpkgs.atftp -c sudo atftpd --pcre /tmp/atftpd.map --logfile - --no-fork --daemon --user dan   --verbose=3 `pwd`
