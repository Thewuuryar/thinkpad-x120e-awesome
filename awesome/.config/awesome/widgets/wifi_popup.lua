-- widgets/wifi_popup.lua
-- Click-to-open popup for the wifi widget: shows a scan of nearby
-- networks, a rescan button, and lets you click a network to enter a
-- password (or connect directly for open networks / already-saved ones).

local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local naughty = require("naughty")
local beautiful = require("beautiful")

local M = {}

local icon_font = "Symbols Nerd Font Mono 11"
local text_font = "Fantasque Sans Mono 10"

local icons = {
    wifi  = "\u{f1eb}", --  wifi
    lock  = "\u{f023}", --  lock (secured network)
    check = "\u{f00c}", --  check (currently connected)
}

local scan_script    = gears.filesystem.get_configuration_dir() .. "scripts/wifi-scan.sh"
local connect_script = gears.filesystem.get_configuration_dir() .. "scripts/wifi-connect.sh"

-- ==== State ====

local ROW_HEIGHT = 28
local VIEWPORT_HEIGHT = 260

local list_inner = wibox.widget { layout = wibox.layout.fixed.vertical, spacing = 2 }
local list_scroll_margin = wibox.widget { list_inner, top = 0, widget = wibox.container.margin }
local list_viewport = wibox.widget {
    list_scroll_margin,
    strategy = "exact",
    height   = VIEWPORT_HEIGHT,
    widget   = wibox.container.constraint,
}

-- Simple scrollbar indicator (track + thumb). AwesomeWM 4.3 doesn't have
-- wibox.layout.overflow, so scrolling and the scrollbar are done by hand:
-- list_scroll_margin.top is used as a (negative) pixel offset, and the
-- thumb's size/position are recomputed from the row count on every
-- rebuild/scroll.
local scrollbar_thumb = wibox.widget { widget = wibox.container.background, bg = beautiful.fg_focus }
local scrollbar_thumb_wrap = wibox.widget { scrollbar_thumb, top = 0, widget = wibox.container.margin }
local scrollbar_track = wibox.widget {
    scrollbar_thumb_wrap,
    forced_width  = 6,
    forced_height = VIEWPORT_HEIGHT,
    bg            = beautiful.bg_minimize,
    widget        = wibox.container.background,
    visible       = false,
}

local list_row = wibox.layout.align.horizontal()
list_row:set_second(list_viewport)
list_row:set_third(wibox.widget { scrollbar_track, left = 6, widget = wibox.container.margin })
list_row.expand = "none"

local scroll_offset_rows = 0
local total_rows = 0

local status_text   = wibox.widget { widget = wibox.widget.textbox, font = text_font, text = "" }
local password_area = wibox.widget { layout = wibox.layout.fixed.vertical, spacing = 4, visible = false }
local password_label = wibox.widget { widget = wibox.widget.textbox, font = text_font }
local password_display = wibox.widget {
    widget = wibox.widget.textbox,
    font = text_font,
    text = "",
}

local selected_ssid = nil
local pending_password = ""
local active_keygrabber = nil

-- Forward declarations
local refresh_networks
local rebuild_list
local show_password_prompt
local hide_password_prompt
local do_connect

-- ==== nmcli terse-format parsing ====
-- nmcli -t escapes ':' inside a field as '\:' and '\' as '\\'. Split on
-- unescaped ':' then unescape.
local function split_nmcli_line(line)
    local fields = {}
    local buf = {}
    local i = 1
    local n = #line
    while i <= n do
        local c = line:sub(i, i)
        if c == "\\" and i < n then
            table.insert(buf, line:sub(i + 1, i + 1))
            i = i + 2
        elseif c == ":" then
            table.insert(fields, table.concat(buf))
            buf = {}
            i = i + 1
        else
            table.insert(buf, c)
            i = i + 1
        end
    end
    table.insert(fields, table.concat(buf))
    return fields
end

-- ==== Row widget ====

local function make_row(net)
    local prefix = ""
    if net.in_use then
        prefix = icons.check .. " "
    end

    local icon_w = wibox.widget {
        widget = wibox.widget.textbox,
        font   = icon_font,
        text   = prefix .. icons.wifi,
    }

    local label_w = wibox.widget {
        widget = wibox.widget.textbox,
        font   = text_font,
        text   = net.ssid,
    }

    local right_w = wibox.widget {
        widget = wibox.widget.textbox,
        font   = text_font,
        text   = string.format("%s%d%%", net.secured and (icons.lock .. " ") or "", net.signal),
    }

    local row = wibox.layout.align.horizontal()
    row:set_first(wibox.widget {
        icon_w,
        label_w,
        spacing = 6,
        layout  = wibox.layout.fixed.horizontal,
    })
    row:set_third(right_w)
    row.expand = "none"

    local padded_row = wibox.widget {
        row,
        margins = 4,
        widget  = wibox.container.margin,
    }

    local bg = wibox.widget {
        padded_row,
        forced_height = ROW_HEIGHT,
        widget = wibox.container.background,
        shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 4) end,
    }

    bg:connect_signal("mouse::enter", function() bg.bg = beautiful.bg_focus end)
    bg:connect_signal("mouse::leave", function() bg.bg = nil end)

    bg:buttons(gears.table.join(
        awful.button({}, 1, function()
            if net.secured then
                show_password_prompt(net.ssid)
            else
                hide_password_prompt()
                do_connect(net.ssid, "")
            end
        end)
    ))

    return bg
end

local function apply_scroll()
    local max_offset_px = math.max(0, (total_rows * ROW_HEIGHT) - VIEWPORT_HEIGHT)
    local offset_px = math.max(0, math.min(scroll_offset_rows * ROW_HEIGHT, max_offset_px))
    list_scroll_margin.top = -offset_px

    if max_offset_px <= 0 then
        scrollbar_track.visible = false
        return
    end

    scrollbar_track.visible = true
    local content_px = total_rows * ROW_HEIGHT
    local thumb_h = math.max(16, math.floor(VIEWPORT_HEIGHT * VIEWPORT_HEIGHT / content_px))
    local thumb_travel = VIEWPORT_HEIGHT - thumb_h
    local thumb_top = 0
    if max_offset_px > 0 then
        thumb_top = math.floor(thumb_travel * (offset_px / max_offset_px))
    end
    scrollbar_thumb.forced_height = thumb_h
    scrollbar_thumb_wrap.top = thumb_top
end

local function scroll_by(delta_rows)
    scroll_offset_rows = scroll_offset_rows + delta_rows
    if scroll_offset_rows < 0 then scroll_offset_rows = 0 end
    apply_scroll()
end

list_viewport:buttons(gears.table.join(
    awful.button({}, 4, function() scroll_by(-2) end),
    awful.button({}, 5, function() scroll_by(2) end)
))

rebuild_list = function(networks)
    list_inner:reset()
    scroll_offset_rows = 0
    if #networks == 0 then
        list_inner:add(wibox.widget {
            widget = wibox.widget.textbox,
            font   = text_font,
            text   = "No networks found.",
        })
        total_rows = 0
        apply_scroll()
        return
    end
    for _, net in ipairs(networks) do
        list_inner:add(make_row(net))
    end
    total_rows = #networks
    apply_scroll()
end

refresh_networks = function()
    status_text.text = "Scanning..."
    hide_password_prompt()

    awful.spawn.easy_async({ "sh", scan_script }, function(stdout, stderr, reason, exit_code)
        local by_ssid = {}
        for line in stdout:gmatch("[^\r\n]+") do
            local fields = split_nmcli_line(line)
            local in_use, ssid, signal, security = fields[1], fields[2], fields[3], fields[4]
            if ssid and ssid ~= "" then
                local sig = tonumber(signal) or 0
                local existing = by_ssid[ssid]
                if not existing or sig > existing.signal then
                    by_ssid[ssid] = {
                        ssid    = ssid,
                        signal  = sig,
                        secured = (security ~= nil and security ~= "" and security ~= "--"),
                        in_use  = (in_use == "*"),
                    }
                elseif existing and in_use == "*" then
                    existing.in_use = true
                end
            end
        end

        local networks = {}
        for _, net in pairs(by_ssid) do
            table.insert(networks, net)
        end
        table.sort(networks, function(a, b) return a.signal > b.signal end)

        rebuild_list(networks)

        if #networks == 0 and (not stdout or stdout == "") then
            status_text.text = "nmcli unavailable or no networks found."
        else
            status_text.text = string.format("%d network(s) found.", #networks)
        end
    end)
end

-- ==== Password entry (custom keygrabber-driven text field) ====

local function stop_keygrabber()
    if active_keygrabber then
        awful.keygrabber.stop(active_keygrabber)
        active_keygrabber = nil
    end
end

hide_password_prompt = function()
    stop_keygrabber()
    password_area.visible = false
    selected_ssid = nil
    pending_password = ""
    password_display.text = ""
end

show_password_prompt = function(ssid)
    stop_keygrabber()
    selected_ssid = ssid
    pending_password = ""
    password_label.text = string.format("Password for \"%s\":", ssid)
    password_display.text = ""
    password_display.markup = "<span foreground='#928374'>(type password, Enter to connect, Esc to cancel)</span>"
    password_area.visible = true

    active_keygrabber = awful.keygrabber.run(function(mods, key, event)
        if event ~= "press" then return end

        if key == "Escape" then
            hide_password_prompt()
            return
        elseif key == "Return" or key == "KP_Enter" then
            local ssid_to_connect = selected_ssid
            local pw = pending_password
            hide_password_prompt()
            do_connect(ssid_to_connect, pw)
            return
        elseif key == "BackSpace" then
            pending_password = pending_password:sub(1, -2)
        elseif #key == 1 then
            pending_password = pending_password .. key
        else
            return
        end

        password_display.text = string.rep("*", #pending_password)
    end)
end

-- ==== Connect ====

do_connect = function(ssid, password)
    status_text.text = string.format("Connecting to \"%s\"...", ssid)

    awful.spawn.easy_async({ "sh", connect_script, ssid, password or "" }, function(stdout, stderr, reason, exit_code)
        if exit_code == 0 then
            naughty.notify({
                title = "Wi-Fi",
                text  = string.format("Connected to \"%s\".", ssid),
            })
            status_text.text = string.format("Connected to \"%s\".", ssid)
        else
            naughty.notify({
                preset = naughty.config.presets.critical,
                title  = "Wi-Fi",
                text   = string.format("Failed to connect to \"%s\":\n%s", ssid, (stdout .. stderr):gsub("%s+$", "")),
            })
            status_text.text = string.format("Failed to connect to \"%s\".", ssid)
        end
        refresh_networks()
    end)
end

-- ==== Popup assembly ====

local rescan_button = wibox.widget {
    {
        widget = wibox.widget.textbox,
        font   = text_font,
        text   = "Rescan",
    },
    margins = { left = 8, right = 8, top = 3, bottom = 3 },
    widget  = wibox.container.margin,
}

local rescan_bg = wibox.widget {
    rescan_button,
    widget = wibox.container.background,
    shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 4) end,
    bg     = beautiful.bg_minimize,
}

rescan_bg:connect_signal("mouse::enter", function() rescan_bg.bg = beautiful.bg_focus end)
rescan_bg:connect_signal("mouse::leave", function() rescan_bg.bg = beautiful.bg_minimize end)
rescan_bg:buttons(gears.table.join(
    awful.button({}, 1, function() refresh_networks() end)
))

local connect_button = wibox.widget {
    {
        widget = wibox.widget.textbox,
        font   = text_font,
        text   = "Connect",
    },
    margins = { left = 8, right = 8, top = 3, bottom = 3 },
    widget  = wibox.container.margin,
}

local connect_bg = wibox.widget {
    connect_button,
    widget = wibox.container.background,
    shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 4) end,
    bg     = beautiful.bg_minimize,
}

connect_bg:connect_signal("mouse::enter", function() connect_bg.bg = beautiful.bg_focus end)
connect_bg:connect_signal("mouse::leave", function() connect_bg.bg = beautiful.bg_minimize end)
connect_bg:buttons(gears.table.join(
    awful.button({}, 1, function()
        if selected_ssid then
            local ssid_to_connect = selected_ssid
            local pw = pending_password
            hide_password_prompt()
            do_connect(ssid_to_connect, pw)
        end
    end)
))

local cancel_button = wibox.widget {
    {
        widget = wibox.widget.textbox,
        font   = text_font,
        text   = "Cancel",
    },
    margins = { left = 8, right = 8, top = 3, bottom = 3 },
    widget  = wibox.container.margin,
}

local cancel_bg = wibox.widget {
    cancel_button,
    widget = wibox.container.background,
    shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 4) end,
    bg     = beautiful.bg_minimize,
}

cancel_bg:connect_signal("mouse::enter", function() cancel_bg.bg = beautiful.bg_focus end)
cancel_bg:connect_signal("mouse::leave", function() cancel_bg.bg = beautiful.bg_minimize end)
cancel_bg:buttons(gears.table.join(
    awful.button({}, 1, function() hide_password_prompt() end)
))

password_area:add(password_label)
password_area:add(password_display)
password_area:add(wibox.widget {
    connect_bg,
    cancel_bg,
    spacing = 6,
    layout  = wibox.layout.fixed.horizontal,
})

local header = wibox.layout.align.horizontal()
header:set_first(wibox.widget {
    widget = wibox.widget.textbox,
    font   = text_font,
    markup = "<b>Wi-Fi Networks</b>",
})
header:set_third(rescan_bg)
header.expand = "none"

local content = wibox.widget {
    header,
    status_text,
    list_row,
    password_area,
    spacing = 8,
    layout  = wibox.layout.fixed.vertical,
}

M.popup = awful.popup {
    widget = wibox.widget {
        content,
        margins = 12,
        widget  = wibox.container.margin,
    },
    ontop        = true,
    visible      = false,
    bg           = beautiful.bg_normal,
    fg           = beautiful.fg_normal,
    border_width = beautiful.border_width,
    border_color = beautiful.border_focus,
    minimum_width = 320,
    maximum_width = 320,
    shape        = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 6) end,
}

function M.toggle()
    if M.popup.visible then
        M.popup.visible = false
        hide_password_prompt()
        return
    end

    -- Capture the click position (over the wifi icon) before showing the
    -- popup, then map it first and place it afterwards -- positioning a
    -- popup before it has ever been mapped can get reset back to (0,0)
    -- once awesome actually maps the window.
    local coords = mouse.coords()
    M.popup.visible = true
    awful.placement.next_to(M.popup, {
        geometry        = { x = coords.x, y = coords.y, width = 1, height = 1 },
        position        = "bottom_right",
        margins         = { top = 8 },
        honor_workarea  = true,
    })

    refresh_networks()
end

return M
