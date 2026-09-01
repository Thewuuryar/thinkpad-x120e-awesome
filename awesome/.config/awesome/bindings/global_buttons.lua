-- bindings/global_buttons.lua
-- Mouse bindings on the root window.

local gears = require("gears")
local awful = require("awful")

local menu = require("config.menu")

return gears.table.join(
    awful.button({ }, 3, function () menu.menu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
)
