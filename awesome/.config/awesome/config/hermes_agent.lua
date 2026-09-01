-- config/hermes_agent.lua
-- Show/hide toggle for the always-running Hermes agent window.
--
-- Unlike the old hermes_panel.lua (which spawned/managed the urxvt+podman
-- process itself via lain.util.quake), the process lifecycle now belongs
-- entirely to the hermes-agent.service systemd user unit:
--   * urxvt -name HermesAgent -e podman exec -it hermes hermes
--   * After=hermes.service, WantedBy=graphical-session.target
--   * Restart=on-failure, so a killed/crashed window comes back on its own
--
-- Awesome's only job is to find that one persistent client (matched by
-- WM_CLASS instance "HermesAgent", set via urxvt's -name flag) and
-- show/hide/center it. Super+A (bindings/global_keys.lua) calls toggle()
-- below. Nothing here spawns a process -- if no client exists yet
-- (service still starting, or briefly restarting), toggle() is a no-op.

local awful = require("awful")

local M = {}

-- Must match hermes-agent.service's `-name` flag exactly -- that's what
-- sets WM_CLASS instance, which is what this file and config/rules.lua
-- match against (NOT the window title/name property).
M.CLIENT_INSTANCE = "HermesAgent"

-- Gruvbox bright purple, used for this window's border so it reads as
-- "the AI agent window" at a glance, distinct from ordinary urxvt windows.
M.ACCENT_COLOR = "#d3869b"
local BORDER_WIDTH = 4

-- Cached reference to the live client, if any.
local agent_client = nil

local function apply_settings(c)
    c.border_color = M.ACCENT_COLOR
    c.border_width = BORDER_WIDTH
    c.floating = true
    c.ontop = true
    c.skip_taskbar = true
end

local function center_on_focused_screen(c)
    local screen = awful.screen.focused()
    local geo = screen.workarea
    c.width = math.floor(geo.width * 0.7)
    c.height = math.floor(geo.height * 0.7)
    awful.placement.centered(c, { parent = screen })
end

-- Show/hide the agent window. Does nothing if the systemd-managed client
-- hasn't appeared yet (service still starting/restarting) -- there is
-- nothing to spawn from here by design.
function M.toggle()
    if not (agent_client and agent_client.valid) then
        return
    end

    if agent_client.hidden then
        agent_client.hidden = false
        agent_client.minimized = false
        center_on_focused_screen(agent_client)
        agent_client:raise()
        client.focus = agent_client
    else
        agent_client.hidden = true
    end
end

client.connect_signal("manage", function(c)
    if c.instance ~= M.CLIENT_INSTANCE then
        return
    end

    agent_client = c
    apply_settings(c)
    center_on_focused_screen(c)

    -- Start hidden -- systemd starts this unit automatically at login
    -- (after hermes.service), well before any Super+A press. Popping the
    -- window up immediately would surprise the user; the first Super+A
    -- press reveals the already-running (and thus instant) window.
    c.hidden = true
end)

client.connect_signal("unmanage", function(c)
    if c.instance == M.CLIENT_INSTANCE and c == agent_client then
        agent_client = nil
    end
end)

return M
