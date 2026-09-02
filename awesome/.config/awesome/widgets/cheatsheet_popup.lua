-- widgets/cheatsheet_popup.lua
-- Super+/ opens a docked panel on the right listing cheatsheets found in
-- ~/.config/cheatsheets/*.md; pressing the sheet's key/number replaces the
-- panel content with that sheet. Any keypress dismisses the whole panel.
-- Long sheets scroll with the mouse wheel (same pattern as the wifi
-- popup's network list: a negative-margin offset + hand-drawn scrollbar).
--
-- To add a cheatsheet: drop a .md file into ~/.config/cheatsheets/. See
-- cheatsheets.md in that directory for the frontmatter/markup format.

local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local xresources = require("beautiful.xresources")
local dpi = xresources.apply_dpi

local M = {}

local font = "Fantasque Sans Mono 10"
local header_font = "Fantasque Sans Mono 11"

local CHEATSHEETS_DIR = os.getenv("HOME") .. "/.config/cheatsheets"

-- Fixed width for the panel so it always lands in the same place and never
-- depends on content size. forced_width (not min/max) locks the size in
-- immediately, with no dependency on layout timing before placement.
local POPUP_WIDTH = dpi(420)
local CONTENT_MARGIN = dpi(14)
-- Outer gap from the workarea edge to the OUTSIDE of the popup's border --
-- X11 draws a window's border outside its declared width/height, so bw is
-- folded into the x/y offsets below rather than trying to inset the
-- content size itself. Top/right kept tighter than bottom by preference.
local PANEL_MARGIN_TOP = dpi(4)
local PANEL_MARGIN_RIGHT = dpi(4)
local PANEL_MARGIN_BOTTOM = dpi(8)
local CONTENT_SPACING = dpi(8)

-- Approximate line height for the monospace cheatsheet font, used only as
-- the mouse-wheel scroll step size (actual scrollable content height is
-- measured directly via textbox:get_height_for_width, not estimated).
local LINE_HEIGHT = dpi(18)
local SCROLLBAR_WIDTH = dpi(6)
local SCROLLBAR_GAP = dpi(6)

-- Width actually available to the sheet's text: total popup width minus
-- the outer content margins and the reserved scrollbar column. Constant
-- since POPUP_WIDTH never changes at runtime.
local TEXT_WIDTH = POPUP_WIDTH - (2 * CONTENT_MARGIN) - SCROLLBAR_WIDTH - SCROLLBAR_GAP

-- ==== Directory scan + frontmatter/markdown parsing ====
--
-- Rescanned on every Super+/ press (a one-shot `ls`, not a background
-- watcher), so newly added files show up on the very next open with zero
-- idle/polling cost while the panel is closed.

local function capitalize(word)
    return word:sub(1, 1):upper() .. word:sub(2)
end

-- Splits optional leading "---\nkey: v\ntitle: v\n---\n" frontmatter off
-- the file body. Returns (frontmatter_table, remaining_body).
local function parse_frontmatter(text)
    local fm_block, rest = text:match("^%-%-%-\r?\n(.-)\r?\n%-%-%-\r?\n?(.*)$")
    if not fm_block then
        return {}, text
    end
    local fm = {}
    for line in fm_block:gmatch("[^\r\n]+") do
        local k, v = line:match("^(%w+):%s*(.-)%s*$")
        if k then fm[k] = v end
    end
    return fm, rest
end

-- Escapes text for safe use inside Pango markup.
local function escape_markup(s)
    return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- Applies **bold** and `inline code` inline spans within a single line.
-- Code spans get a slightly dimmed foreground since we have no monospace
-- background box to draw here without a heavier custom widget.
local function render_inline(line)
    line = escape_markup(line)
    line = line:gsub("%*%*(.-)%*%*", "<b>%1</b>")
    line = line:gsub("`(.-)`", "<span foreground='" .. beautiful.fg_focus .. "'>%1</span>")
    return line
end

-- Converts the small supported Markdown subset (# / ## headers, -/* bullet
-- lists, **bold**, `code`) into Pango markup text. Anything else passes
-- through as plain escaped text -- deliberately simple; see cheatsheets.md.
local function markdown_to_pango(body)
    local out = {}
    for line in (body .. "\n"):gmatch("(.-)\n") do
        local heading = line:match("^#+%s*(.*)$")
        local bullet = line:match("^[%-%*]%s+(.*)$")
        if heading then
            table.insert(out, "<b>" .. render_inline(heading) .. "</b>")
        elseif bullet then
            table.insert(out, "  " .. render_inline(bullet))
        elseif line:match("^%s*$") then
            table.insert(out, "")
        else
            table.insert(out, render_inline(line))
        end
    end
    -- Trim a single trailing blank line from the gsub loop's extra iteration.
    if out[#out] == "" then table.remove(out) end
    return table.concat(out, "\n")
end

-- Scans CHEATSHEETS_DIR and returns an ordered list of
-- {key, title, markup, path}, sorted alphabetically by filename (also the
-- key-collision tiebreak: first filename alphabetically keeps its key).
local function scan_sheets()
    local sheets = {}
    local used_keys = {}

    local names = {}
    local pfile = io.popen("ls -1 " .. CHEATSHEETS_DIR:gsub("'", "'\\''") .. " 2>/dev/null")
    if pfile then
        for name in pfile:lines() do
            if name:match("%.md$") then
                table.insert(names, name)
            end
        end
        pfile:close()
    end
    table.sort(names)

    for _, name in ipairs(names) do
        local path = CHEATSHEETS_DIR .. "/" .. name
        local f = io.open(path, "r")
        if f then
            local text = f:read("*a")
            f:close()

            local fm, body = parse_frontmatter(text)
            local stem = name:gsub("%.md$", "")

            local title = fm.title or capitalize(stem)
            local key = (fm.key or stem:sub(1, 1)):lower()

            if used_keys[key] then
                -- Collision: fall back to first free letter in the title/stem.
                for c in (stem .. title):lower():gmatch(".") do
                    if c:match("%a") and not used_keys[c] then
                        key = c
                        break
                    end
                end
            end
            used_keys[key] = true

            table.insert(sheets, {
                key    = key,
                title  = title,
                markup = markdown_to_pango(body),
                path   = path,
            })
        end
    end

    return sheets
end

-- ==== Sheet view (scrollable) ====

local sheet_title_widget = wibox.widget { widget = wibox.widget.textbox, font = header_font }

-- forced_width is set once here (not per-show) so get_height_for_width's
-- wrap measurement below matches exactly what will actually be rendered.
local sheet_textbox = wibox.widget {
    widget       = wibox.widget.textbox,
    font         = font,
    forced_width = TEXT_WIDTH,
}
local sheet_scroll_margin = wibox.widget { sheet_textbox, top = 0, widget = wibox.container.margin }
local sheet_viewport_constraint = wibox.widget {
    sheet_scroll_margin,
    strategy = "exact",
    height   = dpi(200), -- placeholder, resized per-show in show_sheet()
    widget   = wibox.container.constraint,
}
-- wibox.container.constraint only limits the LAYOUT size handed to its
-- child -- it does not clip drawing. Scrolling works by giving the
-- textbox a negative top margin, so once scrolled the (already laid out)
-- text keeps drawing above the viewport's top edge with nothing to stop
-- it, bleeding up behind the title. shape_clip on a background container
-- clips the child's drawing to `shape` -- it requires a shape to be set
-- (a plain rectangle here) to have any effect; "clip" alone is NOT a real
-- property and silently does nothing.
local sheet_viewport = wibox.widget {
    sheet_viewport_constraint,
    shape      = gears.shape.rectangle,
    shape_clip = true,
    widget     = wibox.container.background,
}

local sheet_scrollbar_thumb = wibox.widget { widget = wibox.container.background, bg = beautiful.fg_focus }
local sheet_scrollbar_thumb_wrap = wibox.widget { sheet_scrollbar_thumb, top = 0, widget = wibox.container.margin }
local sheet_scrollbar_track = wibox.widget {
    sheet_scrollbar_thumb_wrap,
    forced_width = SCROLLBAR_WIDTH,
    bg           = beautiful.bg_minimize,
    widget       = wibox.container.background,
    visible      = false,
}

local sheet_row = wibox.layout.align.horizontal()
sheet_row:set_first(sheet_viewport)
sheet_row:set_third(wibox.widget { sheet_scrollbar_track, left = SCROLLBAR_GAP, widget = wibox.container.margin })
sheet_row.expand = "none"

-- Opaque background (matches popup bg) so scrolled text can never show
-- through underneath the title, even before layout settles on a resize.
-- fixed.vertical stretches each child to the full content width, so this
-- already spans edge-to-edge within the panel's content area.
local sheet_title_bar = wibox.widget {
    sheet_title_widget,
    bg     = beautiful.bg_normal,
    widget = wibox.container.background,
}

local sheet_view = wibox.widget {
    sheet_title_bar,
    sheet_row,
    spacing = CONTENT_SPACING,
    layout  = wibox.layout.fixed.vertical,
}

-- ==== Picker view ====

local picker_inner = wibox.widget { layout = wibox.layout.fixed.vertical, spacing = 2 }

local picker_view = wibox.widget {
    {
        widget = wibox.widget.textbox,
        font   = header_font,
        markup = "<b>Cheatsheets</b>",
    },
    picker_inner,
    spacing = CONTENT_SPACING,
    layout  = wibox.layout.fixed.vertical,
}

-- ==== Single popup, content swapped between picker_view / sheet_view ====

local content_margin = wibox.container.margin(picker_view, CONTENT_MARGIN, CONTENT_MARGIN, CONTENT_MARGIN, CONTENT_MARGIN)

local panel = awful.popup {
    widget       = content_margin,
    ontop        = true,
    visible      = false,
    bg           = beautiful.bg_normal,
    fg           = beautiful.fg_normal,
    border_width = beautiful.border_width,
    border_color = beautiful.cheatsheet_border_color,
    forced_width = POPUP_WIDTH,
    -- awful.popup is "auto-resized": by default it re-runs its own
    -- placement (awful.placement.next_to) any time its widget content or
    -- layout changes (e.g. swapping sheets, resizing the viewport), which
    -- silently overrides any x/y set via dock() below. Disabling it here
    -- makes dock() the ONLY thing that ever moves this popup.
    placement    = false,
    shape        = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 6) end,
}

-- Docks the panel to the right edge, top aligned just under the wibar.
-- X11 draws a window's border outside its declared width/height, so bw is
-- folded into the x/y offsets here rather than trying to inset the
-- content size itself.
--
-- awful.popup re-fits itself to its widget's NATURAL content size on every
-- layout pass (independent of placement=false, which only disables
-- re-positioning, not re-sizing) -- so panel:geometry()'s height alone gets
-- silently overwritten back to the content height shortly after. Forcing
-- forced_height on the top-level widget itself is what actually pins the
-- size, since fit_widget() uses forced_height instead of computing one.
local function dock(content_height)
    local workarea = awful.screen.focused().workarea
    local bw = beautiful.border_width
    content_margin.forced_width = POPUP_WIDTH
    content_margin.forced_height = content_height
    panel:geometry({
        x      = workarea.x + workarea.width - PANEL_MARGIN_RIGHT - bw - POPUP_WIDTH,
        y      = workarea.y + PANEL_MARGIN_TOP + bw,
        width  = POPUP_WIDTH,
        height = content_height,
    })
end

-- Content height that makes the panel's bottom border land exactly
-- PANEL_MARGIN_BOTTOM above the bottom of the workarea.
local function fill_height()
    local workarea = awful.screen.focused().workarea
    local bw = beautiful.border_width
    return workarea.height - PANEL_MARGIN_TOP - PANEL_MARGIN_BOTTOM - (2 * bw)
end

-- ==== Scroll state (sheet view only -- the picker is always short) ====

local sheet_scroll_offset_lines = 0
local sheet_viewport_height = 0
local sheet_measured_content_height = 0

local function apply_sheet_scroll()
    local content_px = sheet_measured_content_height
    local max_offset_px = math.max(0, content_px - sheet_viewport_height)
    local offset_px = math.max(0, math.min(sheet_scroll_offset_lines * LINE_HEIGHT, max_offset_px))
    sheet_scroll_margin.top = -offset_px

    if max_offset_px <= 0 then
        sheet_scrollbar_track.visible = false
        return
    end

    sheet_scrollbar_track.visible = true
    local thumb_h = math.max(dpi(16), math.floor(sheet_viewport_height * sheet_viewport_height / content_px))
    local thumb_travel = sheet_viewport_height - thumb_h
    local thumb_top = 0
    if max_offset_px > 0 then
        thumb_top = math.floor(thumb_travel * (offset_px / max_offset_px))
    end
    sheet_scrollbar_thumb.forced_height = thumb_h
    sheet_scrollbar_thumb_wrap.top = thumb_top
end

local function scroll_sheet_by(delta_lines)
    sheet_scroll_offset_lines = sheet_scroll_offset_lines + delta_lines
    if sheet_scroll_offset_lines < 0 then sheet_scroll_offset_lines = 0 end
    apply_sheet_scroll()
end

sheet_viewport:buttons(gears.table.join(
    awful.button({}, 4, function() scroll_sheet_by(-3) end),
    awful.button({}, 5, function() scroll_sheet_by(3) end)
))

-- ==== Show/hide ====

local active_keygrabber = nil
local current_sheets = {}

local function stop_keygrabber()
    if active_keygrabber then
        awful.keygrabber.stop(active_keygrabber)
        active_keygrabber = nil
    end
end

local function hide_panel()
    stop_keygrabber()
    panel.visible = false
end

local function show_sheet(entry)
    content_margin.widget = sheet_view
    sheet_title_widget.markup = "<b>" .. entry.title .. "</b>"
    sheet_textbox.markup = entry.markup

    local panel_height = fill_height()

    -- Reserve space for the title row + spacing + outer margins so the
    -- viewport (where scrolling happens) gets exactly what's left.
    local _, title_h = sheet_title_widget:get_preferred_size(awful.screen.focused())
    sheet_viewport_height = panel_height - title_h - CONTENT_SPACING - (2 * CONTENT_MARGIN)
    sheet_viewport_constraint.height = sheet_viewport_height

    -- Measure the ACTUAL rendered height at the text's real width (wrapped
    -- lines take more vertical space than a naive newline count assumes --
    -- this was the cause of content being unreachable via scroll before).
    sheet_measured_content_height = sheet_textbox:get_height_for_width(TEXT_WIDTH, awful.screen.focused())
    sheet_scroll_offset_lines = 0
    apply_sheet_scroll()

    dock(panel_height)

    stop_keygrabber()
    active_keygrabber = awful.keygrabber.run(function(mods, key, event)
        if event ~= "press" then return end
        hide_panel()
    end)
end

function M.show_picker()
    if panel.visible then
        hide_panel()
        return
    end

    current_sheets = scan_sheets()

    picker_inner:reset()
    if #current_sheets == 0 then
        picker_inner:add(wibox.widget {
            widget = wibox.widget.textbox,
            font   = font,
            text   = "No cheatsheets found in " .. CHEATSHEETS_DIR,
        })
    end
    for i, entry in ipairs(current_sheets) do
        picker_inner:add(wibox.widget {
            widget = wibox.widget.textbox,
            font   = font,
            markup = string.format("<b>%d</b> / <b>%s</b>  %s", i, entry.key, entry.title),
        })
    end

    content_margin.widget = picker_view
    panel.visible = true

    -- Keep the picker the same fixed size as the sheet view (fill_height),
    -- rather than auto-sizing to its natural (short) content height.
    dock(fill_height())

    active_keygrabber = awful.keygrabber.run(function(mods, key, event)
        if event ~= "press" then return end

        local lower_key = key:lower()

        if key == "Escape" then
            hide_panel()
            return
        end

        local selected = nil
        for i, entry in ipairs(current_sheets) do
            if entry.key == lower_key or tostring(i) == key then
                selected = entry
                break
            end
        end

        if selected then
            show_sheet(selected)
        end
    end)
end

return M
