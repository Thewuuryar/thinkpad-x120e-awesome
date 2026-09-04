# Laptop + Hermes Agent Setup — Reproducibility Guide

Last generated: 2026-09-02, from a live inventory of the running system
(`installed-packages.txt` in this same directory). As of this update,
ai-workspace holds a full copy of ~/dotfiles/ (see section 3) rather
than just the AwesomeWM config in isolation.

Purpose: if the ThinkPad X120e's drive dies or is replaced, this doc plus
the files sitting next to it in ~/ai-workspace are everything needed to
rebuild the machine to its current state — OS, WM, look/feel, and the
Hermes agent integration — from a bare Arch install. The real disaster
recovery path, though, is the pushed ~/dotfiles GitHub repo (section 3)
+ this doc for everything outside dotfiles (packages, systemd units).

--------------------------------------------------------------------------
1. HARDWARE / OS BASELINE
--------------------------------------------------------------------------
- Machine: Lenovo ThinkPad X120e
- CPU: AMD E-350 APU (dual-core "Bobcat", Radeon HD6310 iGPU)
  IMPORTANT: this CPU does NOT support SSE4.2 or AVX. Any prebuilt binary,
  AUR package, or container image that assumes a "modern x86_64" baseline
  (many are built expecting x86-64-v2/v3) may crash with SIGILL. Always
  sanity-check before installing anything performance-sensitive (browsers
  are usually fine since they're built conservatively; things like modern
  ML/video libs may not be).
- RAM: 16GB (upgraded from base config)
- Storage: SSD (upgraded from base config)
- OS: Arch Linux, kernel 7.1.8-arch1-3, amd-ucode installed
- Window manager: AwesomeWM 4.3, theme gruvbox (custom, in dotfiles)
- Login manager: ly 1.4.1
- Terminal: rxvt-unicode (urxvt)
- Network: NetworkManager + iw (wifi scan/connect scripts call these)
- Remote access: tailscale, openssh

--------------------------------------------------------------------------
2. PACKAGE INVENTORY
--------------------------------------------------------------------------
Full explicit-install list (pacman -Qe) and AUR-only list (pacman -Qm)
are meant to be captured verbatim in: installed-packages.txt (this
directory) — NOT currently present in this ai-workspace copy as of this
update; regenerate it with the command below and drop it here before
relying on the "reinstall" command later in this section.

To regenerate that inventory at any time, run ON THE LAPTOP HOST (not
inside the Hermes container):

    { echo "=== pacman -Qe ==="; pacman -Qe; echo; \
      echo "=== AUR pkgs ==="; pacman -Qm; echo; \
      echo "=== running user services ==="; \
      systemctl --user list-units --type=service --state=running --no-pager; \
    } > ~/ai-workspace/installed-packages.txt

NOTE ON CRUFT: the user has been testing several WMs/tools over time (e.g.
bspwm, sxhkd, polybar, lain-git are present but AwesomeWM is the one
actually settled on and in daily use). Don't assume every package in
installed-packages.txt is load-bearing for the current setup — cross-check
against section 3 below (what's actually wired into the dotfiles/configs)
before treating something as required. When in doubt, ask the user rather
than pruning packages automatically.

Core packages known to be load-bearing for the CURRENT setup (WM stack):
  awesome, ly, rxvt-unicode, xorg-server, xorg-xinit, xorg-xsetroot,
  feh (wallpaper), xcursor-themes, wmctrl, xdotool, sxhkd (used by AwesomeWM
  bindings? verify — was originally bspwm's hotkey daemon),
  ttf-dejavu, ttf-fantasque-nerd, ttf-fantasque-sans-mono,
  ttf-nerd-fonts-symbols-mono, networkmanager, iw, acpi, alsa-utils,
  yay (AUR helper), git, stow, podman, tailscale, openssh

Likely leftover from earlier experiments (verify with user before removing):
  bspwm, sxhkd, polybar, lain-git (lain is an AwesomeWM library though —
  may still be genuinely used by the AwesomeWM config; check config/ for
  `require("lain")` before assuming it's unused)

To reinstall the full explicit set on a fresh Arch install:

    sudo pacman -S --needed - < <(awk 'NR>1 && $1!="" {print $1}' \
      <(sed -n '/=== pacman -Qe ===/,/^$/p' installed-packages.txt))

  (Simpler/safer in practice: open installed-packages.txt, manually copy
  the package names between the pacman -Qe and AUR pkgs headers, review
  the list, drop what you don't want, then `sudo pacman -S --needed <list>`.)

For AUR packages (yay, yay-debug, lain-git), install yay first via the
standard bootstrap (base-devel + git are already in the list above):

    git clone https://aur.archlinux.org/yay.git
    cd yay && makepkg -si
    yay -S lain-git

--------------------------------------------------------------------------
3. DOTFILES (GNU Stow) — status: DONE, pushed to GitHub
--------------------------------------------------------------------------
The user maintains ~/dotfiles/ as a stow-managed git repo, already pushed
to GitHub, with every package stowed live: awesome (~/.config/awesome),
bash (~/.bashrc), cheatsheets (~/.config/cheatsheets), git (~/.gitconfig),
ly (/etc/ly/config.ini, via `sudo stow -t /`), starship
(~/.config/starship.toml), systemd (~/.config/systemd/user/*), and xorg
(~/.Xresources, ~/.xinitrc).

THIS IS THE SOURCE OF TRUTH for the WM look-and-feel and shell/git/prompt
setup. The actual backup mechanism is the GitHub remote, NOT the
ai-workspace copy described below.

Full reference (package layout, adding new packages, the ly /etc target,
and secret hygiene) lives in its own document since it grew too long to
keep inline here:

    DOTFILES_STOW_WORKFLOW.md   (same directory as this file)

Quick reproduction summary (see that doc section 7 for the full version):

    git clone git@github.com:thewuuryar/dotfiles.git ~/dotfiles
    cd ~/dotfiles
    stow awesome bash cheatsheets git starship systemd xorg
    sudo stow -t / ly

ai-workspace/dotfiles/ (mounted into the Hermes container at
/opt/data/workspace/dotfiles/) is a plain-file copy of the ENTIRE
~/dotfiles/ folder, kept there so files can be passed back and forth to
Hermes without one-off copies. It is not a git repo itself and is not
backed up on its own — ai-workspace is scratch space; changes made there
must be copied back into the real ~/dotfiles/ on the host and committed
from there to actually be saved or take effect.

--------------------------------------------------------------------------
4. HERMES AGENT INTEGRATION (systemd user services)
--------------------------------------------------------------------------
Two systemd --user units, copied into this workspace at:
  .config/systemd/user/hermes.service
  .config/systemd/user/hermes-agent.service

hermes.service (oneshot, WantedBy=default.target):
  - Runs `podman run -d --name hermes --restart unless-stopped`
  - Mounts: %h/.hermes -> /opt/data (agent state, persists across restarts)
            %h/ai-workspace -> /opt/data/workspace (file exchange)
  - Runs rootless with --userns=keep-id:uid=10000,gid=10000
  - Image: docker.io/nousresearch/hermes-agent, entrypoint `sleep infinity`
    (i.e. the container just idles; work happens via `podman exec`)

IMPORTANT: ly (and most minimal display managers/WMs) never calls
`systemctl --user start graphical-session.target` the way GNOME/KDE
session scripts do, so graphical-session.target never activates on
its own -- hermes-agent.service (WantedBy=graphical-session.target)
then silently never auto-starts on login, even when enabled; it only
ever runs after a manual `systemctl --user start`. Fix: rc.lua now
runs, near the very top (right after requiring awful):

    systemctl --user import-environment DISPLAY XAUTHORITY \
        XDG_SESSION_ID XDG_SEAT XDG_VTNR
    systemctl --user start graphical-session.target

This both hands systemd's user manager the X env vars units may need
(DISPLAY/XAUTHORITY, for urxvt) and fires the target so anything
WantedBy=graphical-session.target actually starts on login.

hermes-agent.service (simple, WantedBy=graphical-session.target,
  Requires/After=hermes.service):
  - Waits (up to 30s) for `podman exec hermes true` to succeed, i.e. for
    the container to actually be ready for execs, not just started
  - Launches: urxvt -name HermesAgent -e podman exec -it hermes hermes
  - ExecStop pkills the urxvt window by WM_CLASS instance so it closes
    immediately on `systemctl --user stop`
  - Restart=on-failure (crash-only restart, not a respawn loop)

AwesomeWM side (config/hermes_agent.lua):
  - Does NOT spawn the process — the systemd units own the process
    lifecycle entirely. Awesome only finds the already-running client by
    WM_CLASS instance "HermesAgent" and shows/hides/centers it.
  - Super+A (bindings/global_keys.lua) toggles visibility.
  - Window starts hidden on first management (c.hidden = true) so login
    doesn't pop the terminal up uninvited; it's ready instantly on first
    Super+A since the container + shell are already warm.
  - Border color #d3869b (gruvbox purple), 4px, floating+ontop, no taskbar.

To reproduce from scratch on a fresh install:

    mkdir -p ~/.config/systemd/user
    cp ai-workspace/.config/systemd/user/hermes*.service \
       ~/.config/systemd/user/
    systemctl --user daemon-reload
    systemctl --user enable --now hermes.service
    systemctl --user enable hermes-agent.service
    # hermes-agent.service will actually start once graphical-session.target
    # fires (i.e. on next graphical login), not immediately from a TTY

Requires podman installed and configured for rootless use (uid/gid
subordinate ranges set up for --userns=keep-id, typically automatic on
Arch via /etc/subuid /etc/subgid once the user's first rootless container
runs, or configured manually — check `podman info` if hermes.service
fails to start after a fresh install).

--------------------------------------------------------------------------
5. HERMES AGENT'S OWN MEMORY (context this doc doesn't duplicate)
--------------------------------------------------------------------------
Separately from this file, the Hermes agent itself holds two small
persistent memory files that get loaded into every conversation
automatically:

    /opt/data/memories/MEMORY.md   (agent's own operating notes)
    /opt/data/memories/USER.md     (facts about the user/their setup)

Because /opt/data is bind-mounted from ~/.hermes on the host, these files
already live at:

    ~/.hermes/memories/MEMORY.md
    ~/.hermes/memories/USER.md

BACKUP: since ~/.hermes persists on the host filesystem already, the
simplest backup is just including it in whatever you use to back up your
home directory (or add it to the dotfiles git repo / a separate private
repo — these files are small, plain text, and contain no secrets as of
this writing, but review before pushing anywhere public since future
entries could end up mentioning private details).

  Quick manual backup:
    cp ~/.hermes/memories/MEMORY.md ~/.hermes/memories/USER.md \
       ~/dotfiles/hermes-memory-backup/
    # or simply: git -C ~/dotfiles add hermes-memory-backup && git commit ...

RESTORE (fresh Hermes container / new laptop, ~/.hermes doesn't exist yet
or is empty):
  1. Recreate ~/.hermes/memories/ (or just let the container create it,
     then stop it before restoring)
  2. Copy your backed-up MEMORY.md and USER.md into ~/.hermes/memories/
  3. Start hermes.service — the mount means the container sees your
     restored files immediately, no extra step needed inside the agent.

If you don't have a backup and need to reconstruct from scratch, hand the
new agent this exact document (LAPTOP_SETUP_REPRODUCIBILITY.md) plus
installed-packages.txt and ask it to re-derive the same MEMORY.md/USER.md
entries — that's exactly what produced the current ones, so re-running it
against this doc should get you back to equivalent state without needing
the original conversation.

Current content of those two files as of this writing (also serves as a
fallback copy in case ~/.hermes is lost and this workspace file survives
independently, e.g. if it made it into the dotfiles repo). NOTE: these
drift as the agent learns more — treat ~/.hermes/memories/*.md itself as
authoritative, this is just a snapshot from the last time this doc was
regenerated:

--- MEMORY.md ---
Laptop: ThinkPad X120e, AMD E-350 APU (dual-core Bobcat, Radeon HD6310
iGPU) — NO SSE4.2/AVX support, so avoid software requiring those (check
builds/binaries). Upgraded to 16GB RAM + SSD. Host OS: Arch Linux, WM:
AwesomeWM (gruvbox theme), login manager: ly. IMPORTANT:
/opt/data/workspace/.config/awesome (ai-workspace) is a working copy
only, NOT the live/stowed config — real live config is
~/dotfiles/awesome/.config/awesome/, symlinked to ~/.config/awesome via
stow. Edits made in ai-workspace need manual copy by user into dotfiles
to take effect. Always state exactly which files changed and what
changed.
§
Docs in /opt/data/workspace/ (host ~/ai-workspace/):
LAPTOP_SETUP_REPRODUCIBILITY.md (disaster-recovery) and
DOTFILES_STOW_WORKFLOW.md (moving configs to ~/dotfiles via stow; never
stow NetworkManager/.nmconnection, SSH keys, tokens) — both now live
inside dotfiles/ since the user copied the whole ~/dotfiles/ folder into
ai-workspace for easier file exchange. Update these when systemd
units/stow packages/setup change; ai-workspace itself isn't backed up —
only pushed ~/dotfiles + backed-up ~/.hermes/memories are durable.
§
User priority for all laptop OS customization (Arch+AwesomeWM on weak
AMD E-350 hardware): minimize background/polling resource usage —
prefer static widgets, event-driven over polled where possible, and
podman-based systemd user services over ad-hoc spawned processes. Avoid
heavy compositor effects (shadows/blur/transparency) unless explicitly
requested; default stance is skip or minimal-effects compositor only.
Always verify packages don't require SSE4.2/AVX. Give iterative small
patches to the awesome config rather than large rewrites.
§
After completing any task that creates or modifies files, always list
the specific file paths changed/created in the final summary (when
applicable).
§
User's cheatsheets (.config/cheatsheets/*.md, AwesomeWM Super+/ popup)
use: YAML frontmatter (key/title), flat # headers, - bullets,
`code`/**bold** only (no tables/links). Panel 420px wide, ~380px usable
text in Fantasque Sans Mono 10 — keep lines <=55-60 chars, split long
ones onto indented continuation lines. User likes iterative
condense/restructure requests on these docs rather than full rewrites.

--- USER.md ---
Runs AwesomeWM (gruvbox theme, urxvt terminal) on an old Arch laptop
where low resource utilization matters — prefers static/simple widgets
over animated/polling-heavy ones, and podman-based systemd user services
over ad-hoc process spawning. Config lives in
/opt/data/workspace/.config/awesome/. Wants iterative refinement (icon
size, spacing, font choices) via direct small patches rather than big
rewrites each time.
§
User's AwesomeWM is 4.3 (Jan 2019), which is the latest stable release —
there is no 4.4 stable (only an unreleased draft on git master); don't
suggest upgrading to get "newer" features, and don't assume 4.4+-only
APIs (e.g. wibox.layout.overflow does not exist).
§
User is standardizing on git switch/restore (not checkout) for
branch/file ops. Git conventions settled on for their repos: GitHub-flow
style short-lived branches named <type>/<short-desc>, Conventional
Commits format <type>(<scope>): <summary>, squash-merge as default merge
strategy (--no-ff as alt). Prefers iterating cheatsheet/doc content
through several rounds of refinement (condense redundancy, reorganize
into logical sections, tighten formatting) rather than getting it right
in one pass — expects incremental small edits per request.

--------------------------------------------------------------------------
6. RECOMMENDED NEXT STEPS FOR THE USER
--------------------------------------------------------------------------
1. ~/dotfiles is already pushed to GitHub and fully stowed — the config
   backup is in place. No action needed there.
2. Consider adding ~/.hermes/memories/*.md into that same dotfiles repo
   (e.g. a hermes-memory-backup/ subfolder) so a single `git clone` +
   restore covers configs AND agent memory together. Not done yet.
3. Periodically re-run the inventory oneshot command in section 2 and
   drop the refreshed installed-packages.txt in ai-workspace so this
   document can be regenerated/updated as the package set evolves.
4. When ready, tell Hermes which of the "likely leftover" packages
   (bspwm, sxhkd, polybar) are safe to remove — this doc deliberately
   does not assume that for you.
