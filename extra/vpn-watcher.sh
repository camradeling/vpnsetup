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


#
# Определяем интерфейс hotspot.
#
# Android создаёт rule примерно такого вида:
#
#   21000: from all iif wlan1 lookup rmnet_data1
#
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


#
# Определяем таблицу обычного uplink для hotspot.
#
# Например:
#
#   21000: from all iif wlan1 lookup rmnet_data1
#
# -> rmnet_data1
#
get_uplink_table()
{
    HS="$1"

    "$IP" rule 2>/dev/null |
    awk -v hs="$HS" '
        /^21000:/ {
            iif=""
            table=""

            for (i=1; i<=NF; i++) {
                if ($i == "iif")
                    iif=$(i+1)

                if ($i == "lookup")
                    table=$(i+1)
            }

            if (iif == hs && table != "") {
                print table
                exit
            }
        }
    '
}


#
# Определяем физический интерфейс uplink из его routing table.
#
# Например:
#
#   default via 198.51.100.1 dev rmnet_data1
#
# -> rmnet_data1
#
get_uplink_dev()
{
    TABLE="$1"

    [ -n "$TABLE" ] || return

    "$IP" route show table "$TABLE" 2>/dev/null |
    awk '
        $1 == "default" {
            for (i=1; i<=NF; i++) {
                if ($i == "dev") {
                    print $(i+1)
                    exit
                }
            }
        }
    '
}


#
# Находим VPN-интерфейс и его routing table.
#
# Например:
#
#   default dev tun0 table tun0
#
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


#
# Получаем IPv4 endpoint VPN-сервера.
#
# Android/VPN-клиент может создавать в VPN routing table
# throw route для адреса самого VPN-сервера:
#
#   throw 203.0.113.42 table tun0
#
# Благодаря throw пакет не зацикливается внутри VPN,
# а продолжает проходить следующие ip rule и в итоге
# попадает в обычный uplink.
#
# Берём только host routes (/32 или адрес без маски),
# чтобы случайно не открыть наружу целую подсеть.
#
get_vpn_endpoints()
{
    TABLE="$1"

    [ -n "$TABLE" ] || return

    "$IP" route show table "$TABLE" 2>/dev/null |
    awk '
        $1 == "throw" {
            addr=$2

            # Только IPv4
            if (addr !~ /\./)
                next

            # Если присутствует CIDR, разрешаем только /32
            if (addr ~ /\// && addr !~ /\/32$/)
                next

            print addr
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

    UPLINKTABLE="$(get_uplink_table "$HS")"
    UPLINKDEV="$(get_uplink_dev "$UPLINKTABLE")"

    "$IPT" -F TVPN_FWD
    "$IPT" -t nat -F TVPN_NAT


    if [ -n "$VPNDEV" ] && [ -n "$VPNTABLE" ]; then

        #
        # Исключение для самого VPN-сервера.
        #
        # Его адрес имеет throw route в VPNTABLE.
        # Поэтому routing после lookup VPNTABLE продолжится
        # и попадёт в обычный Android rule 21000.
        #
        # Но firewall должен отдельно разрешить такой FORWARD,
        # поскольку пакет идёт:
        #
        #   hotspot -> physical uplink
        #
        # а не:
        #
        #   hotspot -> VPN
        #
        if [ -n "$UPLINKDEV" ]; then

            VPN_ENDPOINTS="$(get_vpn_endpoints "$VPNTABLE")"

            for ENDPOINT in $VPN_ENDPOINTS
            do
                #
                # Laptop -> VPN server напрямую через uplink
                #
                "$IPT" -A TVPN_FWD \
                    -i "$HS" \
                    -o "$UPLINKDEV" \
                    -d "$ENDPOINT" \
                    -j ACCEPT

                #
                # Ответ VPN server -> laptop
                #
                "$IPT" -A TVPN_FWD \
                    -i "$UPLINKDEV" \
                    -o "$HS" \
                    -s "$ENDPOINT" \
                    -m conntrack \
                    --ctstate RELATED,ESTABLISHED \
                    -j ACCEPT

                #
                # NAT для прямого соединения с VPN-сервером.
                #
                "$IPT" -t nat -A TVPN_NAT \
                    -o "$UPLINKDEV" \
                    -d "$ENDPOINT" \
                    -j MASQUERADE

                logmsg "VPN endpoint bypass: $ENDPOINT via $UPLINKDEV"
            done
        else
            logmsg "warning: cannot determine uplink dev from table=$UPLINKTABLE"
        fi


        #
        # Обычный hotspot -> VPN
        #
        "$IPT" -A TVPN_FWD \
            -i "$HS" \
            -o "$VPNDEV" \
            -j ACCEPT

        #
        # Ответы VPN -> hotspot
        #
        "$IPT" -A TVPN_FWD \
            -i "$VPNDEV" \
            -o "$HS" \
            -m conntrack \
            --ctstate RELATED,ESTABLISHED \
            -j ACCEPT

        #
        # Всё остальное с hotspot наружу запрещаем.
        #
        # Это правило обязательно идёт ПОСЛЕ исключения
        # для VPN endpoint.
        #
        "$IPT" -A TVPN_FWD \
            -i "$HS" \
            -j DROP

        #
        # NAT непосредственно в VPN.
        #
        "$IPT" -t nat -A TVPN_NAT \
            -o "$VPNDEV" \
            -j MASQUERADE

        set_rule "$HS" "$VPNTABLE"

        logmsg "active: $HS -> $VPNDEV table=$VPNTABLE uplink=$UPLINKDEV"

    else

        #
        # VPN отсутствует: IPv4 fail-closed.
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