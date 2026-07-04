{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "vless-reality-in",
      "listen": "0.0.0.0",
      "port": __SB_PORT__,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "__SB_UUID__",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "__SB_SNI__:443",
          "xver": 0,
          "serverNames": [
            "__SB_SNI__"
          ],
          "privateKey": "__SB_REALITY_PRIVATE_KEY__",
          "shortIds": [
            "__SB_SHORT_ID__"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
