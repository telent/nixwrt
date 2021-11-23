{svc, iproute, nftables} :
{ ipv6-peer-address
, wanifname
, wan
, lan
} :
svc {
  depends = [ lan.ready wan.prefixes ipv6-peer-address ];
  outputs = [ "ready"];
  name = "forwarding";
  config = {
    kernel.config = {
      "BRIDGE_NETFILTER" = "y";
      "NETFILTER" = "y";
      "NETFILTER_ADVANCED" = "y";
      "NETFILTER_INGRESS" = "y";
      "NETFILTER_NETLINK" = "y";
      "NETFILTER_NETLINK_LOG" = "y";
      "NFT_CHAIN_NAT_IPV4" = "y";
      "NFT_CHAIN_NAT_IPV6" = "y";
      "NFT_CHAIN_ROUTE_IPV4" = "y";
      "NFT_CHAIN_ROUTE_IPV6" = "y";
      "NFT_CT" = "y";
      "NFT_MASQ" = "y";
      "NFT_NAT" = "y";
      "NFT_REJECT_IPV4" = "y";
      "NF_CONNTRACK" = "y";
      "NF_CONNTRACK_AMANDA" = "y";
      "NF_CONNTRACK_FTP" = "y";
      "NF_CONNTRACK_H323" = "y";
      "NF_CONNTRACK_IRC" = "y";
      "NF_CONNTRACK_LABELS" = "y";
      "NF_CONNTRACK_NETBIOS_NS" = "y";
      "NF_CONNTRACK_PPTP" = "y";
      "NF_CONNTRACK_SNMP" = "y";
      "NF_CT_PROTO_DCCP" = "y";
      "NF_CT_PROTO_GRE" = "y";
      "NF_CT_PROTO_SCTP" = "y";
      "NF_CT_PROTO_UDPLITE" = "y";
      "NF_TABLES" = "y";
      "NF_TABLES_BRIDGE" = "y";
      "NF_TABLES_IPV4" = "y";
      "NF_TABLES_IPV6" = "y";
    };
  };
  start = ''
    set -x
    prefix=$(cat ${wan.prefixes})
    prefix=''${prefix%%,*}
    network=''${prefix%%/*}
    bits=''${prefix#*/}
    peeraddr=$(cat ${ipv6-peer-address})
    ${iproute}/bin/ip address add ''${network}1/$bits dev ${lan.name}

    echo "1" > /proc/sys/net/ipv6/conf/all/forwarding
    echo "1" > /proc/sys/net/ipv4/ip_forward
    nft(){ ${nftables}/bin/nft $* ;}
    nft 'add table nat'
    nft 'add chain nat postrouting { type nat hook postrouting priority 100 ; }'
    nft 'add rule nat postrouting oif ${wanifname} masquerade'
    ip route add default dev ${wanifname}
    ip -6 route add default via $peeraddr dev ${wanifname}
    setstate ready true
  '';
}
