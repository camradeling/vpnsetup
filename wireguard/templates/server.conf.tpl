# WireGuard server configuration example
# Generated values (keys, PSK) are NOT stored in this template.
# See wireguard/server/configure.sh for actual generation.

[Interface]
Address = __WG_SERVER_VPN_ADDR__
ListenPort = __WG_PORT__
PrivateKey = SERVER_PRIVATE_KEY_HERE

# Uncomment for full-tunnel NAT (set by configure.sh when WG_ENABLE_NAT=yes):
# PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o __WG_OUT_IFACE__ -j MASQUERADE
# PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o __WG_OUT_IFACE__ -j MASQUERADE

[Peer]
# __WG_CLIENT_NAME__
PublicKey = CLIENT_PUBLIC_KEY_HERE
# PresharedKey = PRESHARED_KEY_HERE   # optional
AllowedIPs = __WG_CLIENT_IP__/32
