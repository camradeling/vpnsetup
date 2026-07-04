{
  "log": {
    "level": "__SB_LOG_LEVEL__",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "type": "local",
        "tag": "local"
      }
    ],
    "final": "local"
  },
  "inbounds": [
    {
      "type": "tun",
      "interface_name": "singtun0",
      "address": [
        "172.19.0.1/30"
      ],
      "auto_route": true,
      "strict_route": false,
      "mtu": __SB_TUN_MTU__,
      "stack": "system"
    }
  ],
  "outbounds": [
    {
      "type": "vless",
      "tag": "proxy",
      "server": "__SERVER_PUBLIC_IP__",
      "server_port": __SB_PORT__,
      "uuid": "__SB_UUID__",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "__SB_SNI__",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
        "reality": {
          "enabled": true,
          "public_key": "__SB_REALITY_PUBLIC_KEY__",
          "short_id": "__SB_SHORT_ID__"
        }
      }
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "auto_detect_interface": true,
    "rules": [
      {
        "action": "sniff"
      },
      {
        "protocol": "dns",
        "action": "hijack-dns"
      },
      {
        "ip_cidr": [
          "__SERVER_PUBLIC_IP__/32"
        ],
        "outbound": "direct"
      }
    ],
    "final": "proxy"
  }
}
