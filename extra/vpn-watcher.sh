#!/system/bin/sh

TAG="tether-vpn"
PREF=10500
BLOCK_TABLE=9999

IP=/system/bin/ip
IPT=/system/bin/iptables
IP6T=/system/bin/ip6tables
LOG=/system/bin/log
SETTINGS=/system/bin/settings

"$LOG" -t "$TAG" "vpn-watcher started pid=$$"

#
# Android tethering offload обходит netfilter.
# Отключаем его, чтобы IPv6 kill-switch видел forwarded traffic.
#
"$SETTINGS" put global tether_offload_disabled 1


logmsg()
{
    "$LOG" -t "$TAG" "$*"
}


get_hotspot()
{
    "$IP" rule 2>/dev/null |
    awk '
        /^21000:/ {
            for (i=1; i<=NF; i++) {
                if ($i == "iif") {
                    print $(i+1)
                    exit
                }
            }
        }
    '
}


get_vpn()
{
    "$IP" route show table all 2>/dev/null |
    awk '
        $1 == "default" && $2 == "dev" &&
        $3 ~ /^(tun|wg|awg)[0-9]*$/ {
            dev=$3
            table=""
            for (i=1; i<=NF; i++) {
                if ($i == "table")
                    table=$(i+1)
            }

            if (table != "") {
                print dev, table
                exit
            }
        }
    '
}


ensure_chains()
{
    "$IPT" -N TVPN_FWD 2>/dev/null
    "$IPT" -t nat -N TVPN_NAT 2>/dev/null

    "$IPT" -C FORWARD -j TVPN_FWD 2>/dev/null ||
        "$IPT" -I FORWARD 1 -j TVPN_FWD

    "$IPT" -t nat -C POSTROUTING -j TVPN_NAT 2>/dev/null ||
        "$IPT" -t nat -I POSTROUTING 1 -j TVPN_NAT
}


ensure_ipv6_killswitch()
{
    "$IP6T" -N TVPN6_FWD 2>/dev/null

    "$IP6T" -C FORWARD -j TVPN6_FWD 2>/dev/null ||
        "$IP6T" -I FORWARD 1 -j TVPN6_FWD
}


set_rule()
{
    HS="$1"
    TABLE="$2"

    CURRENT="$("$IP" rule | awk -v p="${PREF}:" '$1 == p {print}')"

    echo "$CURRENT" |
        grep -q "iif $HS lookup $TABLE" &&
        return 0

    while "$IP" rule del pref "$PREF" 2>/dev/null
    do
        :
    done

    "$IP" rule add pref "$PREF" iif "$HS" lookup "$TABLE"

    logmsg "policy: $HS -> table $TABLE"
}


reconcile()
{
    HS="$(get_hotspot)"

    #
    # Hotspot выключен
    #
    if [ -z "$HS" ]; then

        while "$IP" rule del pref "$PREF" 2>/dev/null
        do
            :
        done

        ensure_chains

        "$IPT" -F TVPN_FWD
        "$IPT" -t nat -F TVPN_NAT

        ensure_ipv6_killswitch
        "$IP6T" -F TVPN6_FWD

        return
    fi


    #
    # IPv6 hotspot:
    # пока полностью fail-closed.
    #
    ensure_ipv6_killswitch

    "$IP6T" -F TVPN6_FWD
    "$IP6T" -A TVPN6_FWD \
        -i "$HS" \
        -j DROP


    #
    # IPv4
    #
    ensure_chains

    VPNINFO="$(get_vpn)"
    VPNDEV="$(echo "$VPNINFO" | awk '{print $1}')"
    VPNTABLE="$(echo "$VPNINFO" | awk '{print $2}')"

    "$IPT" -F TVPN_FWD
    "$IPT" -t nat -F TVPN_NAT


    if [ -n "$VPNDEV" ] && [ -n "$VPNTABLE" ]; then

        # hotspot -> VPN
        "$IPT" -A TVPN_FWD \
            -i "$HS" \
            -o "$VPNDEV" \
            -j ACCEPT

        # ответы VPN -> hotspot
        "$IPT" -A TVPN_FWD \
            -i "$VPNDEV" \
            -o "$HS" \
            -m conntrack \
            --ctstate RELATED,ESTABLISHED \
            -j ACCEPT

        # Запрещаем hotspot использовать другой uplink
        "$IPT" -A TVPN_FWD \
            -i "$HS" \
            -j DROP

        # NAT непосредственно в VPN
        "$IPT" -t nat -A TVPN_NAT \
            -o "$VPNDEV" \
            -j MASQUERADE

        set_rule "$HS" "$VPNTABLE"

        logmsg "active: $HS -> $VPNDEV table=$VPNTABLE"

    else

        #
        # VPN отсутствует: IPv4 fail-closed
        #
        "$IP" route show table "$BLOCK_TABLE" 2>/dev/null |
            grep -q '^unreachable default' ||
            "$IP" route add unreachable default table "$BLOCK_TABLE"

        set_rule "$HS" "$BLOCK_TABLE"

        "$IPT" -A TVPN_FWD \
            -i "$HS" \
            -j DROP

        logmsg "VPN absent: blocking $HS"
    fi
}


#
# Ждём появления networking stack.
#
while ! "$IP" rule >/dev/null 2>&1
do
    sleep 2
done


reconcile


#
# Следим за изменениями интерфейсов и маршрутов.
#
while true
do
    logmsg "starting ip monitor"

    "$IP" monitor link route 2>/dev/null |
    while read -r event
    do
        sleep 1
        reconcile
    done

    logmsg "ip monitor exited, restarting"

    sleep 2
done