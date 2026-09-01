-- widgets/hermes_status.lua
-- Wibar status indicator for the Hermes stack: hermes.service (the systemd
-- user unit keeping the podman container alive) and hermes-agent.service
-- (the systemd user unit keeping the floating urxvt+podman-exec agent
-- window alive -- see config/hermes_agent.lua for the show/hide side).
--
-- Purely a visual indicator: no click/button behavior. Hovering shows a
-- tooltip with the exact systemd state of both units.
--
-- Icon color:
--   * both services active -> gruvbox orange (matches beautiful.border_focus)
--   * anything else        -> gruvbox grey (inactive/activating/failed/unknown)
-- No flashing/animation -- a static color swap on each poll tick, kept
-- deliberately cheap (two `systemctl --user is-active` calls, no podman
-- exec) since this hardware is resource-constrained.

local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local watch = require("awful.widget.watch")

local M = {}

-- Nerd Font Codicons "claude" glyph (Claude AI assistant logo), added to
-- nerd-fonts via its Codicons sync (upstream vscode-codicons name
-- "claude", codepoint 60546 decimal == U+EC82, inside nerd-fonts' documented
-- Codicons range ea60-ec84). Font family matches widgets/wifi.lua and
-- widgets/battery.lua so all wibar status icons stay visually consistent.
local ICON = "\u{ec82}" -- nf-cod-claude
local icon_font = "FantasqueSansM Nerd Font Mono 20"

-- Gruvbox colors: orange matches theme.border_focus (themes/gruvbox/theme.lua)
-- and is used elsewhere in this config as the "active/focused" accent; grey
-- matches the inactive convention used by the other wibar status widgets.
local ACTIVE_COLOR = "#fe8019" -- gruvbox orange
local GREY_COLOR = "#7c6f64"   -- gruvbox gray

M.widget = wibox.widget {
    widget = wibox.widget.textbox,
    font   = icon_font,
    text   = ICON,
}

local tooltip = awful.tooltip {
    objects = { M.widget },
    mode    = "outside",
}

local function service_label(state)
    if state == "active" then
        return "running"
    elseif state == "activating" or state == "reloading" then
        return "starting"
    elseif state == "failed" then
        return "failed"
    elseif state == "unknown" then
        return "unknown"
    else
        return "not running" -- inactive, deactivating, etc.
    end
end

local function refresh_appearance(hermes_state, agent_state)
    local both_active = (hermes_state == "active") and (agent_state == "active")

    local color = both_active and ACTIVE_COLOR or GREY_COLOR
    M.widget.markup = string.format(
        "<span foreground='%s'>%s</span>", color, ICON
    )

    tooltip:set_text(string.format(
        "hermes.service: %s\nhermes-agent.service: %s",
        service_label(hermes_state),
        service_label(agent_state)
    ))
end

local script_path = gears.filesystem.get_configuration_dir() .. "scripts/hermes-status.sh"

local function on_poll(_, stdout)
    local lines = {}
    for line in stdout:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local hermes_state = lines[1] or "unknown"
    local agent_state = lines[2] or "unknown"

    refresh_appearance(hermes_state, agent_state)
end

-- 10s poll: cheap systemctl-only calls, no container exec in the poll path.
watch("sh " .. script_path, 10, on_poll, M.widget)

refresh_appearance("unknown", "unknown")

return M
