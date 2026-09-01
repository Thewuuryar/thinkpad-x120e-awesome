-- config/hermes_panel.lua
-- Instant-toggle "quake style" dropdown panel for chatting with the Hermes
-- agent, backed by lain.util.quake (AUR: lain-git). Bound to Super+A in
-- bindings/global_keys.lua (replaces the old ai-sandbox binding).
--
-- The urxvt instance runs .local/bin/hermes-panel.sh, which just execs
-- `podman exec -it hermes hermes chat --tui` against the always-on hermes
-- container (see the hermes.service systemd user unit). We pre-warm this
-- process once at login (see below) so the very first Super+A press just
-- shows an already-running client instead of waiting on the container
-- attach + TUI boot. hermes-panel.sh itself uses a flock so at most one
-- copy of it (and therefore one `hermes chat --tui`) can ever be running,
-- no matter how it gets launched.
--
-- Session history: press Ctrl+X inside the TUI (or click the session
-- counter in its status bar) to open Hermes's own session-switcher overlay
-- and resume/select a past session, or just keep typing to continue/start
-- fresh. Hermes's TUI has no left-docked sidebar; this overlay is the real
-- equivalent.

local gears = require("gears")
local awful = require("awful")
local lain = require("lain")
local naughty = require("naughty")

local vars = require("config.vars")

-- Must match the urxvt "-name" value below, which sets WM_CLASS instance --
-- that's what lain.util.quake and config/rules.lua match against (NOT the
-- window title/name property).
local CLIENT_INSTANCE = "HermesQuake"

-- All colors below are stock Gruvbox (see themes/gruvbox/theme.lua for the
-- rest of the palette) chosen for strong contrast against each other and
-- against every other (default-colored) urxvt window, so the panel reads as
-- "the AI panel" at a glance:
--   * ACCENT_COLOR  - border color (Gruvbox bright purple)
--   * BG_COLOR      - terminal background (Gruvbox dark0_hard, darker than
--                      the theme's own bg_normal so it doesn't blend in)
--   * FG_COLOR      - terminal foreground (Gruvbox bright green, high
--                      contrast on BG_COLOR, easily readable)
local ACCENT_COLOR = "#d3869b"
local BG_COLOR = "#1d2021"
local FG_COLOR = "#b8bb26"
local BORDER_WIDTH = 4

-- Shared with the manual prewarm spawn below, so the prewarmed client is
-- byte-for-byte the same command lain.util.quake would itself run -- no
-- risk of the two paths drifting apart.
--
-- +sb disables urxvt's scrollbar (on by default, normally left side).
-- -bg/-fg set the Gruvbox colors above, scoped to just this panel -- your
-- other urxvt windows are untouched since these are CLI flags, not a
-- global ~/.Xresources change.
local ARGNAME = "-name %s +sb -bg " .. BG_COLOR .. " -fg " .. FG_COLOR .. " -e "
    .. os.getenv("HOME") .. "/.local/bin/hermes-panel.sh"

local function apply_panel_settings(c)
    c.border_color = ACCENT_COLOR
    c.border_width = BORDER_WIDTH
end

local hermes_quake = lain.util.quake({
    app       = vars.terminal,
    name      = CLIENT_INSTANCE,
    argname   = ARGNAME,
    height    = 0.7,
    width     = 0.6,
    vert      = "center",
    horiz     = "center",
    followtag = true,
    overlap   = false,
    together  = true,
    settings  = apply_panel_settings,
})

-- Exposed so config/signals.lua's focus/unfocus handlers can identify this
-- client without hardcoding the instance string in two places.
hermes_quake.accent_color = ACCENT_COLOR

-- False until the prewarmed client has actually appeared. Read by
-- bindings/global_keys.lua's Super+A handler: while false, it shows a
-- "Hermes is initializing" toast instead of calling toggle() -- calling
-- toggle() before any client exists just spawns one and leaves the user
-- staring at a blank desktop with no feedback while it boots.
hermes_quake.ready = false

-- Coarse lifecycle state for the wibar status widget (widgets/hermes_status
-- .lua): "not running" | "starting" | "running". Kept in sync with `ready`
-- above, but as a 3-way string so the widget can distinguish "never
-- started" from "currently booting" (both read as ready == false).
hermes_quake.status = "not running"

-- Sets both of the above together, persists it to a small state file (read
-- by scripts/hermes-status.sh for the wibar widget's periodic poll -- Lua
-- state here doesn't cross into that separate process any other way), and
-- emits a custom awesome signal so widgets/hermes_status.lua can also
-- refresh immediately instead of waiting on its next poll tick.
local STATUS_FILE = os.getenv("HOME") .. "/.cache/hermes-panel/status"

local function set_status(status)
    hermes_quake.status = status
    hermes_quake.ready = (status == "running")

    os.execute("mkdir -p " .. os.getenv("HOME") .. "/.cache/hermes-panel")
    local f = io.open(STATUS_FILE, "w")
    if f then
        -- hermes-status.sh expects "not-running"/"starting"/"running"
        -- (hyphenated, unlike the human-readable strings used elsewhere in
        -- this file).
        f:write((status:gsub(" ", "-")))
        f:close()
    end

    awesome.emit_signal("hermes_panel::status", status)
end

-- Pre-warm, WITHOUT going through lain's quake:display()/:toggle().
--
-- Those only know "does a client with this instance already exist" by
-- scanning live X clients -- they can't tell "no client because it was
-- never spawned" from "no client YET because urxvt/podman-exec/hermes-tui
-- is still booting". A previous version of this file spawned via
-- quake:display() and then hid it again after a fixed delay; on this
-- hardware the boot (container attach + TUI startup) can take longer than
-- that guessed delay, so the "hide" step saw no client yet and spawned a
-- SECOND, competing urxvt+podman-exec+hermes-tui chain -- two of those
-- racing (plausibly serializing on Hermes's own session-state lock) is
-- what produced the multi-minute stuck watch-cursor.
--
-- Fixing this properly means never guessing a delay at all: spawn the
-- process directly with awful.spawn, then hide it the instant Awesome's
-- real "manage" signal fires for it -- before it's ever shown on screen.
-- lain's own client search (quake:display) matches purely on
-- `c.instance`, with no regard for `c.hidden`, so once Super+A is
-- eventually pressed, quake finds this exact client and shows/positions it
-- normally; there is no dependency on lain having "known about" it
-- beforehand.
local prewarm_pending = false

gears.timer.start_new(1, function()
    prewarm_pending = true
    set_status("starting")
    awful.spawn(
        string.format("%s %s", vars.terminal, string.format(ARGNAME, CLIENT_INSTANCE)),
        { tag = awful.screen.focused().selected_tag }
    )
    return false
end)

client.connect_signal("manage", function(c)
    if c.instance ~= CLIENT_INSTANCE then
        return
    end

    -- Any appearance of the panel client (prewarm, or a later respawn if
    -- the process ever dies and Super+A/lain relaunches it) means the
    -- panel is usable again.
    set_status("running")

    if not prewarm_pending then
        -- Not our prewarm spawn -- e.g. a respawn after the panel process
        -- died and the user pressed Super+A again, which lain's own
        -- internal "manage" handler (registered inside lain.util.quake())
        -- already shows/positions per the current `visible` state. Leave
        -- it alone; forcibly hiding here would undo that and require a
        -- second keypress to actually see it.
        return
    end

    prewarm_pending = false

    -- Mirror what lain's own "hide" branch does (see util/quake.lua) so
    -- state stays consistent with what quake:display()/:toggle() expect
    -- to find later: floated, on top, off the taskbar, hidden, and
    -- detached from whatever tag it was spawned onto.
    apply_panel_settings(c)
    c.floating = true
    c.skip_taskbar = true
    c.hidden = true
    c:tags({})
end)

-- Called from bindings/global_keys.lua's Super+A handler instead of
-- calling hermes_quake:toggle() directly, so an early press (before the
-- prewarm client exists) gives feedback instead of silently spawning a
-- fresh, un-prewarmed client with no explanation for the wait.
function hermes_quake:toggle_or_notify()
    if self.ready then
        self:toggle()
        return
    end

    naughty.notify({
        title = "Hermes",
        text = "Hermes is initializing\u{2026}",
        timeout = 3,
    })
end

-- If the panel process/window ever dies (Ctrl+D, urxvt killed, etc.), drop
-- back to "not running" so the wibar widget and toast logic reflect reality
-- instead of still claiming the panel is up.
client.connect_signal("unmanage", function(c)
    if c.instance == CLIENT_INSTANCE then
        set_status("not running")
    end
end)

return hermes_quake
