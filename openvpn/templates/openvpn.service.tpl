[Unit]
Description=OpenVPN server __OVPN_SERVER_NAME__
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/openvpn --daemon ovpn-__OVPN_SERVER_NAME__ --status /run/openvpn/__OVPN_SERVER_NAME__.status 10 --cd __OVPN_WORKDIR__ --config __OVPN_WORKDIR__/__OVPN_SERVER_NAME__.conf
ExecReload=/bin/kill -HUP $MAINPID
ExecStartPost=__OVPN_WORKDIR__/iptables-add.sh
ExecStopPost=__OVPN_WORKDIR__/iptables-remove.sh
WorkingDirectory=__OVPN_WORKDIR__

[Install]
WantedBy=multi-user.target
