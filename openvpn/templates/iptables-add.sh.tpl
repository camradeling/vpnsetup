#!/bin/sh
iptables -t nat -I POSTROUTING 1 -s __OVPN_VPN_IP__/__OVPN_VPN_CIDR__ -o __OVPN_NIC__ -j MASQUERADE
iptables -I INPUT 1 -i tun0 -j ACCEPT
iptables -I FORWARD 1 -i __OVPN_NIC__ -o tun0 -j ACCEPT
iptables -I FORWARD 1 -i tun0 -o __OVPN_NIC__ -j ACCEPT
iptables -I INPUT 1 -i __OVPN_NIC__ -p __OVPN_PROTOCOL__ --dport __OVPN_PORT__ -j ACCEPT
