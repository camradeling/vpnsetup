port __OVPN_PORT__
proto __OVPN_PROTOCOL__
dev tun
user nobody
group __OVPN_NOGROUP__
persist-key
persist-tun
keepalive 10 120
topology subnet
server __OVPN_VPN_IP__ __OVPN_VPN_SUBNET_MASK__
ifconfig-pool-persist ipp.txt
push "dhcp-option DNS __OVPN_DNS1__"
push "dhcp-option DNS __OVPN_DNS2__"
push "redirect-gateway def1 bypass-dhcp"
__OVPN_COMPRESSION_PARAM__
__OVPN_DH_DEFINITION__
__OVPN_TLS_PARAM__
crl-verify crl.pem
ca ca.crt
cert __OVPN_SERVER_NAME__.crt
key __OVPN_SERVER_NAME__.key
auth __OVPN_HMAC_ALG__
cipher __OVPN_CIPHER__
ncp-ciphers __OVPN_CIPHER__
tls-server
tls-version-min 1.2
tls-cipher __OVPN_CC_CIPHER__
client-config-dir ccd
status logs/status.log
script-security 2
verb 3
