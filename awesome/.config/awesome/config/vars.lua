-- config/vars.lua
-- Global-ish configuration variables (terminal, editor, modkey).
-- Required by almost every other module.

local M = {}

-- This is used later as the default terminal and editor to run.
M.terminal   = "urxvt"
M.editor     = os.getenv("EDITOR") or "vim"
M.editor_cmd = M.terminal .. " -e " .. M.editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
M.modkey = "Mod4"

return M
