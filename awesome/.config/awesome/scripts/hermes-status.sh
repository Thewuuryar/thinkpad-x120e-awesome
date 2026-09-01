#!/bin/sh
# Prints two lines describing the Hermes stack for widgets/hermes_status.lua:
#   line 1: hermes.service systemd state (active/activating/inactive/failed/...)
#   line 2: hermes-agent.service systemd state (same set of values)
#
# Kept as a tiny standalone script (rather than inline shell in the widget)
# so it's easy to run by hand for debugging: `sh hermes-status.sh`.
#
# Deliberately cheap: two `systemctl --user is-active` calls, no podman/
# container exec here -- this runs on a periodic timer so it must stay
# lightweight on this hardware.

hermes_state=$(systemctl --user is-active hermes.service 2>/dev/null)
[ -n "$hermes_state" ] || hermes_state="unknown"

agent_state=$(systemctl --user is-active hermes-agent.service 2>/dev/null)
[ -n "$agent_state" ] || agent_state="unknown"

echo "$hermes_state"
echo "$agent_state"
