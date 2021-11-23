{ dnsmasq, svc, lib }:
{ name
, lan
, resolvFile
, ranges
, domain
} :
svc rec {
  foreground = true;
  inherit name;
  depends = [ lan.ready ];
  pid = "/run/${name}.pid";
  start = ''
    setstate ready true
    ${dnsmasq}/bin/dnsmasq \
    --user=dnsmasq \
    --domain=${domain} \
    --group=dnsmasq \
    --interface=${lan.name} \
    ${lib.concatStringsSep " " (builtins.map (r: "--dhcp-range=${r}") ranges)} \
    --keep-in-foreground \
    --dhcp-authoritative \
    --resolv-file=${resolvFile} \
    --log-dhcp \
    --enable-ra \
    --log-debug \
    --log-facility=- \
    --dhcp-leasefile=/run/${name}.leases \
    --pid-file=${pid}
  '';
  outputs = ["ready"];
  config = {
    users.dnsmasq = {
      uid = 51; gid= 51; gecos = "DNS/DHCP service user";
      dir = "/run/dnsmasq";
      shell = "/bin/false";
    };
    groups.dnsmasq = {
      gid = 51; usernames = ["dnsmasq"];
    };
  };
}
