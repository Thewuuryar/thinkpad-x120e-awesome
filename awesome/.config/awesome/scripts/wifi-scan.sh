#!/bin/sh
# Trigger a wifi rescan and dump raw nmcli terse output for nearby networks.
# Deliberately does NOT parse/reformat fields here (nmcli's terse mode
# escapes ':' inside values with a backslash, which is easy to get wrong
# with awk/sed) -- parsing is done on the Lua side instead.
#
# Output: raw `nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list` lines.

nmcli dev wifi rescan >/dev/null 2>&1
sleep 1

nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null
