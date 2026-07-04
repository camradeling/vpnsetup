client
__OVPN_PROTOCOL_PARAM__
remote __SERVER_PUBLIC_IP__ __OVPN_PORT__
dev tun
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
verify-x509-name __OVPN_SERVER_NAME__ name
auth __OVPN_HMAC_ALG__
auth-nocache
cipher __OVPN_CIPHER__
tls-client
tls-version-min 1.2
tls-cipher __OVPN_CC_CIPHER__
ignore-unknown-option block-outside-dns
setenv opt block-outside-dns
verb 3
__OVPN_COMPRESSION_PARAM__
