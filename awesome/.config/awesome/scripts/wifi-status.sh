#!/bin/sh
# Print the connected wifi SSID (line 1) and IPv4 address (line 2) if
# connected to a wifi network via NetworkManager. Prints nothing if not
# connected or if nmcli isn't available.

ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')

if [ -n "$ssid" ]; then
    iface=$(nmcli -t -f device,type,state dev status 2>/dev/null \
        | awk -F: '$2=="wifi" && $3=="connected"{print $1; exit}')
    ip=$(nmcli -t -f IP4.ADDRESS dev show "$iface" 2>/dev/null \
        | head -n1 | cut -d: -f2 | cut -d/ -f1)
    echo "$ssid"
    echo "$ip"
fi
