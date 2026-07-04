# OpenVPN Configuration Reference

All variables are set via `./configure.sh` and stored in `config.env`.

| Variable | Default | Description |
|---|---|---|
| `OVPN_SERVER_NAME` | `myvpnserver` | Name used for certs, workdir, and systemd service |
| `OVPN_WORKDIR` | `/root/servers/<name>` | Where all server runtime files are written |
| `OVPN_PORT` | `1194` | UDP/TCP listen port |
| `OVPN_PROTOCOL` | `udp` | `udp` or `tcp` |
| `OVPN_VPN_IP` | `10.9.0.0` | VPN tunnel subnet base address |
| `OVPN_VPN_SUBNET_MASK` | `255.255.255.0` | VPN subnet mask |
| `OVPN_DNS1` | `8.8.8.8` | Primary DNS pushed to clients |
| `OVPN_DNS2` | `4.4.4.4` | Secondary DNS pushed to clients |
| `OVPN_CIPHER` | `AES-128-GCM` | Data channel cipher (`AES-128-GCM`, `AES-256-GCM`, `AES-128-CBC`, `AES-256-CBC`) |
| `OVPN_CERT_TYPE` | `ECDSA` | `ECDSA` or `RSA` |
| `OVPN_CERT_CURVE` | `prime256v1` | ECDSA curve (`prime256v1`, `secp384r1`, `secp521r1`) |
| `OVPN_RSA_KEY_SIZE` | `2048` | RSA key size in bits (if `CERT_TYPE=RSA`) |
| `OVPN_CC_CIPHER` | `TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256` | Control channel TLS cipher |
| `OVPN_DH_TYPE` | `ECDH` | `ECDH` (ephemeral, no file) or `DH` (generates dh.pem) |
| `OVPN_DH_CURVE` | `prime256v1` | ECDH curve (if `DH_TYPE=ECDH`) |
| `OVPN_DH_KEY_SIZE` | `2048` | DH parameter size in bits (if `DH_TYPE=DH`) |
| `OVPN_HMAC_ALG` | `SHA256` | HMAC digest (`SHA256`, `SHA384`, `SHA512`) |
| `OVPN_TLS_SIG` | `tls-crypt` | `tls-crypt` (encrypts + auths control channel) or `tls-auth` (auth only) |
| `OVPN_COMPRESSION_ENABLED` | `n` | `y` or `n` — compression is not recommended (VORACLE) |
| `OVPN_COMPRESSION_ALG` | `lz4-v2` | `lz4-v2`, `lz4`, or `lzo` (if compression enabled) |

## Template placeholders → config.env variables

| Template placeholder | Variable |
|---|---|
| `__OVPN_SERVER_NAME__` | `OVPN_SERVER_NAME` |
| `__OVPN_WORKDIR__` | `OVPN_WORKDIR` |
| `__OVPN_PORT__` | `OVPN_PORT` |
| `__OVPN_PROTOCOL__` | `OVPN_PROTOCOL` |
| `__OVPN_VPN_IP__` | `OVPN_VPN_IP` |
| `__OVPN_VPN_SUBNET_MASK__` | `OVPN_VPN_SUBNET_MASK` |
| `__OVPN_DNS1__` | `OVPN_DNS1` |
| `__OVPN_DNS2__` | `OVPN_DNS2` |
| `__OVPN_CIPHER__` | `OVPN_CIPHER` |
| `__OVPN_CC_CIPHER__` | `OVPN_CC_CIPHER` |
| `__OVPN_HMAC_ALG__` | `OVPN_HMAC_ALG` |
| `__OVPN_NOGROUP__` | Detected at runtime (`nogroup` or `nobody`) |
| `__OVPN_NIC__` | Detected from default route at runtime |
| `__OVPN_VPN_CIDR__` | Computed from `OVPN_VPN_SUBNET_MASK` |
| `__OVPN_COMPRESSION_PARAM__` | Computed: `compress <alg>` or empty |
| `__OVPN_DH_DEFINITION__` | Computed: `dh none\necdh-curve <curve>` or `dh dh.pem` |
| `__OVPN_TLS_PARAM__` | Computed: `tls-crypt tls-crypt.key` or `tls-auth tls-auth.key 0` |
| `__OVPN_PROTOCOL_PARAM__` | Computed: `proto udp\nexplicit-exit-notify` or `proto tcp-client` |
| `__SERVER_PUBLIC_IP__` | `SERVER_PUBLIC_IP` (shared) |
