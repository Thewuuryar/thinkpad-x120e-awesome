-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:
require("awful.hotkeys_popup.keys")

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, font and wallpapers.
beautiful.init(gears.filesystem.get_configuration_dir() .. "themes/gruvbox/theme.lua")

-- Shared config (terminal, editor, modkey, ...). See config/vars.lua.
local vars = require("config.vars")

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = require("config.layouts")
-- }}}

-- {{{ Hermes agent
-- Show/hide toggle for the always-running Hermes agent window (its process
-- lifecycle is owned by the hermes-agent.service systemd user unit). See
-- config/hermes_agent.lua for details; bindings/global_keys.lua wires the
-- toggle to Super+A.
local hermes_agent = require("config.hermes_agent")
-- }}}

-- {{{ Menu
-- Main awesome menu, launcher widget, menubar config. See config/menu.lua.
local menu = require("config.menu")
-- }}}

-- {{{ Wibar
-- Wallpaper handling + per-screen wibar (taglist/tasklist/systray/clock).
-- See widgets/wibar.lua.
require("widgets.wibar")
-- }}}

-- {{{ Mouse bindings
root.buttons(require("bindings.global_buttons"))
-- }}}

-- {{{ Key bindings
local globalkeys = require("bindings.global_keys")
local clientkeys = require("bindings.client_keys")
local clientbuttons = require("bindings.client_buttons")

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
-- See config/rules.lua (it pulls in clientkeys/clientbuttons itself).
awful.rules.rules = require("config.rules")
-- }}}

-- {{{ Signals
-- Client/screen signal handlers. See config/signals.lua.
require("config.signals")
-- }}}
