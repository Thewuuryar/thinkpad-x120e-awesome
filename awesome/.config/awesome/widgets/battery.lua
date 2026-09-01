-- widgets/battery.lua
-- Battery status indicator for the wibar.
--
-- Shows a Nerd Font glyph:
--   * a charging icon while the battery is charging (or full/plugged in)
--   * a level icon (full/high/medium/low/empty) while discharging, giving
--     an approximate visual read of how much charge is left
--
-- Hovering the icon shows a tooltip with "Charging"/"Discharging" and the
-- exact percentage.
--
-- Reads straight from /sys/class/power_supply/BATx, so it has no extra
-- runtime dependency (no acpi/upower required). The battery is
-- auto-detected on load; if your machine has more than one and you want a
-- specific one, hardcode `battery_path` below.

local awful = require("awful")
local wibox = require("wibox")
local watch = require("awful.widget.watch")

local M = {}

-- Nerd Font (Font Awesome) battery glyphs.
local icons = {
    charging = "\u{f0e7}", --  bolt
    full     = "\u{f240}", --  battery-full
    high     = "\u{f241}", --  battery-three-quarters
    medium   = "\u{f242}", --  battery-half
    low      = "\u{f243}", --  battery-quarter
    empty    = "\u{f244}", --  battery-empty
}

-- Font used to render the icons above. Must be a Nerd Font (or a font
-- patched with Nerd Font glyphs), otherwise you'll see boxes/tofu instead
-- of icons. Keep in sync with widgets/wifi.lua and widgets/hermes_status.lua.
local icon_font = "FantasqueSansM Nerd Font Mono 20"

-- Gruvbox colors used to flag low charge, regardless of icon
-- (full/high/medium/low/empty) or charging state:
--   * NORMAL_COLOR (fg_normal)     - above 20%
--   * WARNING_COLOR (bright yellow) - 20% and below
--   * CRITICAL_COLOR (bright red)   - 10% and below
local NORMAL_COLOR = "#ebdbb2"
local WARNING_COLOR = "#fabd2f"
local CRITICAL_COLOR = "#fb4934"

-- Auto-detect the first BATx entry under /sys/class/power_supply.
local function find_battery()
    local base = "/sys/class/power_supply/"
    local p = io.popen("ls " .. base .. " 2>/dev/null")
    if not p then return nil end
    local path = nil
    for name in p:lines() do
        if name:match("^BAT") then
            path = base .. name
            break
        end
    end
    p:close()
    return path
end

local battery_path = find_battery()

M.widget = wibox.widget {
    widget = wibox.widget.textbox,
    font   = icon_font,
}

local battery_tooltip = awful.tooltip {
    objects = { M.widget },
    mode    = "outside",
}

local function icon_for(status, percent)
    if status == "Charging" then
        return icons.charging
    end
    if percent >= 90 then
        return icons.full
    elseif percent >= 60 then
        return icons.high
    elseif percent >= 30 then
        return icons.medium
    elseif percent >= 15 then
        return icons.low
    else
        return icons.empty
    end
end

local function color_for(percent)
    if percent <= 10 then
        return CRITICAL_COLOR
    elseif percent <= 20 then
        return WARNING_COLOR
    else
        return NORMAL_COLOR
    end
end

local function update_widget(_, stdout, _, _, _)
    local lines = {}
    for line in stdout:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local percent = tonumber(lines[1])
    local status = lines[2]

    if not percent or not status then
        M.widget.text = ""
        battery_tooltip:set_text("Battery status unavailable")
        return
    end

    M.widget.markup = string.format(
        "<span foreground='%s'>%s</span>",
        color_for(percent),
        icon_for(status, percent)
    )

    local label
    if status == "Charging" then
        label = "Charging"
    elseif status == "Discharging" then
        label = "Discharging"
    else
        -- "Full", "Not charging", "Unknown", etc.
        label = status
    end

    battery_tooltip:set_text(string.format("%s: %d%%", label, percent))
end

if battery_path then
    watch(
        string.format("sh -c 'cat %s/capacity %s/status'", battery_path, battery_path),
        30,
        update_widget,
        M.widget
    )
else
    -- No battery found (e.g. running on a desktop) — hide the widget.
    M.widget.visible = false
end

return M
