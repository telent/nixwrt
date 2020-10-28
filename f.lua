#!/nix/store/ns9zwy2q5jsq2rrhrq1xwfimm8716xkw-swarm-mips-unknown-linux-musl/bin/lua-swarm
package.path = {"/nix/store/ns9zwy2q5jsq2rrhrq1xwfimm8716xkw-swarm-mips-unknown-linux-musl/lib/?.lua" "/nix/store/ns9zwy2q5jsq2rrhrq1xwfimm8716xkw-swarm-mips-unknown-linux-musl/scripts/?.lua" }
xl2tpd = require("xl2tpd")
xl2tpd({
  name = "upstream",
  config = "/nix/store/91ssrpbh26h7nrgqsdkzwjg0465y6bm5-xl2tpd.conf",
  secrets = "/etc/xl2tpd.secrets",
  iface = "l2tp-aaisp",
  paths = {
    xl2tpd = "/nix/store/qb3gi6nql42bnspg5dilj05aaqgb06rx-xl2tpd-1.3.15-mips-unknown-linux-musl/bin/xl2tpd"
  }
})
