#!/bin/sh
# Connect to a wifi network via NetworkManager.
# Usage: wifi-connect.sh <ssid> [password]
# If password is empty, connects without one (open network, or a network
# NetworkManager already has saved credentials for).
# Always invoked with an explicit argv (no shell interpolation of
# ssid/password), so special characters in either are safe.

ssid="$1"
password="$2"

if [ -z "$ssid" ]; then
    echo "No SSID given" >&2
    exit 1
fi

if [ -n "$password" ]; then
    nmcli dev wifi connect "$ssid" password "$password" 2>&1
else
    nmcli dev wifi connect "$ssid" 2>&1
fi
