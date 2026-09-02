-- config/menu.lua
-- Main awesome menu, launcher widget, and menubar configuration.

local awful = require("awful")
local beautiful = require("beautiful")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")

local vars = require("config.vars")
local cheatsheet_popup = require("widgets.cheatsheet_popup")

local M = {}

local myawesomemenu = {
   { "hotkeys", function() hotkeys_popup.show_help(nil, awful.screen.focused()) end },
   { "cheatsheets", function() cheatsheet_popup.show_picker() end },
   { "manual", vars.terminal .. " -e man awesome" },
   { "edit config", vars.editor_cmd .. " " .. awesome.conffile },
   { "restart", awesome.restart },
   { "quit", function() awesome.quit() end },
}

M.menu = awful.menu({ items = { { "awesome", myawesomemenu, beautiful.awesome_icon },
                                 { "open terminal", vars.terminal }
                               }
                     })

M.launcher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                      menu = M.menu })

-- Menubar configuration
menubar.utils.terminal = vars.terminal -- Set the terminal for applications that require it

return M
