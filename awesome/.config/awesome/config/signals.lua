-- config/signals.lua
-- Client/screen signal handlers.

local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")

-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    -- Put new clients at the end of the stack (as a slave) instead of
    -- becoming the new master. With suit.tile, master sits on the left;
    -- without this, each new window would become master (left) and push
    -- prior clients into the slave stack (right). This makes new windows
    -- open on the right, splitting the slave stack in half each time.
    if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup
      and not c.size_hints.user_position
    then end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
    -- buttons for the titlebar
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.resize(c)
        end)
    )

    awful.titlebar(c) : setup {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal
        },
        { -- Middle
            { -- Title
                align  = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.floatingbutton (c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton   (c),
            awful.titlebar.widget.ontopbutton    (c),
            awful.titlebar.widget.closebutton    (c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }
end)

-- Enable sloppy focus, so that focus follows mouse -- but only on a real
-- pointer movement. A tiling layout reflow (e.g. a new window opening)
-- can shift another client's geometry underneath a stationary cursor,
-- which would otherwise fire mouse::enter on that client and steal focus
-- back from the client awful.autofocus just focused on "manage".
local last_mouse_coords = { x = -1, y = -1 }
client.connect_signal("mouse::enter", function(c)
    local coords = mouse.coords()
    if coords.x == last_mouse_coords.x and coords.y == last_mouse_coords.y then
        return
    end
    last_mouse_coords = coords
    c:emit_signal("request::activate", "mouse_enter", {raise = false})
end)

client.connect_signal("focus", function(c)
    if c.instance ~= "HermesAgent" then
        c.border_color = beautiful.border_focus
    end
end)
client.connect_signal("unfocus", function(c)
    if c.instance ~= "HermesAgent" then
        c.border_color = beautiful.border_normal
    end
end)
