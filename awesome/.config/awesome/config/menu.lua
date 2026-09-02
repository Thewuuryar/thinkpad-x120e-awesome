-- config/menu.lua
-- Main awesome menu, launcher widget, and menubar configuration.

local awful = require("awful")
local beautiful = require("beautiful")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
local naughty = require("naughty")

local vars = require("config.vars")

local M = {}

-- Static reference text, not a live git status -- just the commands worth
-- remembering. Kept as a plain naughty.notify so there's no polling/process
-- spawn cost; look it up via the menu whenever needed.
local GIT_CHEATSHEET = table.concat({
    "status / diff",
    "  git status                    -- working tree state",
    "  git diff                      -- unstaged changes",
    "  git diff --staged             -- staged changes",
    "stage / commit",
    "  git add -p                    -- stage hunks interactively",
    "  git commit -m '...'           -- commit staged changes",
    "  git commit --amend            -- edit last commit",
    "branches",
    "  git switch -c <name>          -- create and switch to branch",
    "  git branch -d <name>          -- delete merged branch",
    "  git switch -                  -- back to previous branch",
    "sync",
    "  git fetch                     -- fetch remote refs",
    "  git pull --rebase             -- fetch + rebase local commits",
    "  git push                      -- push current branch",
    "  git push -u origin HEAD       -- push new branch, set upstream",
    "history",
    "  git log --oneline --graph -20 -- recent commit graph",
    "  git show <sha>                -- show one commit's changes",
    "  git blame <file>              -- who changed each line",
    "undo",
    "  git restore <file>            -- discard unstaged changes",
    "  git restore --staged <file>   -- unstage a file",
    "  git reset --soft HEAD~1       -- undo last commit, keep changes",
    "  git reflog                    -- recover lost commits/branches",
    "stash",
    "  git stash                     -- shelve working tree changes",
    "  git stash pop                 -- reapply and drop latest stash",
    "  git stash list                -- list stashed changes",
}, "\n")

local myawesomemenu = {
   { "hotkeys", function() hotkeys_popup.show_help(nil, awful.screen.focused()) end },
   { "git cheatsheet", function()
        naughty.notify({
            title = "Git cheat sheet",
            text = GIT_CHEATSHEET,
            timeout = 0,
        })
    end },
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
