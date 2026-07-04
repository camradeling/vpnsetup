#!/bin/sh
iptables -t nat -D POSTROUTING -s __OVPN_VPN_IP__/__OVPN_VPN_CIDR__ -o __OVPN_NIC__ -j MASQUERADE
iptables -D INPUT -i tun0 -j ACCEPT
iptables -D FORWARD -i __OVPN_NIC__ -o tun0 -j ACCEPT
iptables -D FORWARD -i tun0 -o __OVPN_NIC__ -j ACCEPT
iptables -D INPUT -i __OVPN_NIC__ -p __OVPN_PROTOCOL__ --dport __OVPN_PORT__ -j ACCEPT
