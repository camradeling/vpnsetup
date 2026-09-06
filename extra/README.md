# Hotspot-to-VPN routing for rooted Android

Routes all tethered clients' traffic through the phone's active VPN — and blocks them if the VPN drops (fail-closed kill-switch).

## How it works

`vpn-watcher.sh` is a daemon that:

1. Detects the active hotspot interface by inspecting Android's IP policy rule at priority 21000.
2. Detects the active VPN interface (`tun*`, `wg*`, `awg*`) and its routing table.
3. Installs iptables rules and an IP policy rule so hotspot clients are NATed through the VPN.
4. Drops all hotspot traffic (IPv4 + IPv6) when no VPN is up — clients get no connectivity rather than leaking through the plain uplink.
5. Disables Android's tethering hardware offload (`tether_offload_disabled=1`) so forwarded packets pass through netfilter and the kill-switch actually sees them.
6. Watches `ip monitor link route` and re-reconciles on every interface or route change (VPN connect/disconnect, hotspot toggle).

`vpn-watcher-shim.sh` is a one-liner boot entry point placed in Magisk's `service.d/`. It strips the `ASH_STANDALONE` variable (set by Magisk's BusyBox environment) before exec-ing the main script, so the script runs under the real system shell.

## Prerequisites

- Android phone rooted with **Magisk** (or KernelSU with a compatible `service.d` hook).
- A VPN app that creates a `tun*`, `wg*`, or `awg*` interface with a dedicated routing table (standard for WireGuard, OpenVPN, AmneziaVPN, etc.).

## Installation

```sh
# 1. Copy the main daemon
adb push vpn-watcher.sh /data/adb/vpn-watcher.sh
adb shell chmod 755 /data/adb/vpn-watcher.sh

# 2. Copy the shim into Magisk's late-boot service directory
adb push vpn-watcher-shim.sh /data/adb/service.d/vpn-watcher.sh
adb shell chmod 755 /data/adb/service.d/vpn-watcher.sh

# 3. Reboot
adb reboot
```

Magisk executes every script in `service.d/` after the framework is up and networking is available, so the daemon starts automatically on every boot.

## Verification

Check that the daemon is running and watch its log:

```sh
# Is it running?
adb shell ps -ef | grep vpn-watcher

# Live log
adb shell logcat -s tether-vpn
```

Expected log output when hotspot + VPN are both active:

```
tether-vpn: vpn-watcher started pid=…
tether-vpn: active: wlan1 -> wg0 table=1001
```

Expected when VPN is down:

```
tether-vpn: VPN absent: blocking wlan1
```

## Uninstall

```sh
adb shell rm /data/adb/service.d/vpn-watcher.sh
adb shell rm /data/adb/vpn-watcher.sh
adb reboot
```

iptables rules and policy routes installed by the daemon do not persist across reboots, so no manual cleanup is needed.
