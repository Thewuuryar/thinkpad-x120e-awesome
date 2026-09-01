-- widgets/wifi.lua
-- Wi-Fi connection status indicator for the wibar.
--
-- Shows a Nerd Font glyph:
--   * a "connected" wifi icon when associated to a network
--   * a "disconnected" wifi icon otherwise
--
-- Hovering the icon shows a tooltip with the SSID + IP address when
-- connected, or "Not connected" otherwise.
--
-- Uses `nmcli` (NetworkManager CLI) via scripts/wifi-status.sh, which is
-- the standard way to query connection state on Arch. If `nmcli` isn't
-- installed or no wifi is connected, the widget shows the disconnected
-- icon and a "Not connected" tooltip.

local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local watch = require("awful.widget.watch")

local M = {}

-- Nerd Font (Font Awesome) wifi glyphs.
local icons = {
    connected    = "\u{f1eb}", --  wifi
    disconnected = "\u{f6ab}", --  wifi-slash
}

-- Font used to render the icon above. Must be a Nerd Font (or a font
-- patched with Nerd Font glyphs), otherwise you'll see boxes/tofu instead
-- of icons. Keep in sync with widgets/battery.lua and widgets/hermes_status.lua.
local icon_font = "FantasqueSansM Nerd Font Mono 20"

local script_path = gears.filesystem.get_configuration_dir() .. "scripts/wifi-status.sh"

local wifi_popup = require("widgets.wifi_popup")

M.widget = wibox.widget {
    widget = wibox.widget.textbox,
    font   = icon_font,
}

M.widget:buttons(gears.table.join(
    awful.button({}, 1, function() wifi_popup.toggle() end)
))

local wifi_tooltip = awful.tooltip {
    objects = { M.widget },
    mode    = "outside",
}

local function update_widget(_, stdout, _, _, _)
    local lines = {}
    for line in stdout:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local ssid = lines[1]
    local ip = lines[2]

    if ssid and ssid ~= "" then
        M.widget.text = icons.connected
        wifi_tooltip:set_text(string.format("%s\n%s", ssid, ip or "no IP"))
    else
        M.widget.text = icons.disconnected
        wifi_tooltip:set_text("Not connected")
    end
end

watch("sh " .. script_path, 15, update_widget, M.widget)

return M
