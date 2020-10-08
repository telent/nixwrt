#!/bin/lua
ifname = arg[1]
state = arg[2]
prefixes = os.getenv("PREFIXES")
-- FIXME we should handle "excluded" and "class" here
for w in string.gmatch(prefixes, "%g+") do
  address,length, preferred, valid = string.match(w, "([%x:]+)/(%d+),(%d+),(%d+)") do
    os.execute(string.format("/bin/ip addr add %s1/%s dev br0 valid_lft %d preferred_lft %d\n",address,length, valid, preferred))
  end
end
for w in string.gmatch(os.getenv("RA_ROUTES"), "%g+") do
  net, length, gw, valid, metric = string.match(w, "([%x:]+)/(%d+),([%x:]+),(%d+),(%d+)") do
    -- this duplicates the default route set using RA, do we need it again?
    print(string.format("ip route add %s/%s metric %d via %s dev %s expires %d",
                         net, length, metric, gw, ifname, valid))
  end
end
dnss = os.getenv("RDNSS") ..  " " .. os.getenv("RA_DNS")
resolv_conf = io.open("/run/resolv.conf.upstream", "w")
for w in string.gmatch(dnss, "%g+") do
  resolv_conf:write(string.format("nameserver %s\n", w))
end
resolv_conf:close()
