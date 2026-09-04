# Laptop + Hermes Agent Setup — Reproducibility Guide

Purpose: if the ThinkPad X120e's drive dies or is replaced, this doc is
what's needed to rebuild it -- OS, WM, look/feel, and the Hermes agent
integration -- from a bare Arch install. The dotfiles config itself is
recovered from the pushed `~/dotfiles` GitHub repo (see
`DOTFILES_STOW_WORKFLOW.md`); this doc covers everything else: packages
and the Hermes systemd integration.

--------------------------------------------------------------------------
1. HARDWARE / OS BASELINE
--------------------------------------------------------------------------
- Machine: Lenovo ThinkPad X120e
- CPU: AMD E-350 APU (dual-core "Bobcat", Radeon HD6310 iGPU) -- NO
  SSE4.2/AVX. Prebuilt binaries/AUR packages/container images assuming a
  "modern x86_64" baseline (x86-64-v2/v3) may crash with SIGILL. Sanity
  check before installing anything performance-sensitive.
- RAM: 16GB, Storage: SSD (both upgraded from base config)
- OS: Arch Linux, amd-ucode installed
- WM: AwesomeWM 4.3, gruvbox theme (custom, in dotfiles)
- Login manager: ly 1.4.1
- Terminal: rxvt-unicode (urxvt)
- Network: NetworkManager + iw
- Remote access: tailscale, openssh

--------------------------------------------------------------------------
2. PACKAGE INVENTORY
--------------------------------------------------------------------------
Regenerate the full package list any time by running ON THE LAPTOP HOST
(not inside the Hermes container):

    { echo "=== pacman -Qe ==="; pacman -Qe; echo; \
      echo "=== AUR pkgs ==="; pacman -Qm; echo; \
      echo "=== running user services ==="; \
      systemctl --user list-units --type=service --state=running --no-pager; \
    } > ~/ai-workspace/installed-packages.txt

Core packages load-bearing for the current WM stack:
  awesome, ly, rxvt-unicode, xorg-server, xorg-xinit, xorg-xsetroot,
  feh, xcursor-themes, wmctrl, xdotool, ttf-dejavu, ttf-fantasque-nerd,
  ttf-fantasque-sans-mono, ttf-nerd-fonts-symbols-mono, networkmanager,
  iw, acpi, alsa-utils, yay, git, stow, podman, tailscale, openssh

Possible leftovers from earlier WM experiments (bspwm, sxhkd) -- verify
with the user before removing anything.

To reinstall: open `installed-packages.txt`, copy the package names
under `=== pacman -Qe ===`, review, then `sudo pacman -S --needed <list>`.
For AUR packages, bootstrap yay first:

    git clone https://aur.archlinux.org/yay.git
    cd yay && makepkg -si
    yay -S <aur-pkg>

--------------------------------------------------------------------------
3. DOTFILES
--------------------------------------------------------------------------
`~/dotfiles` is the source of truth for WM/shell/git/prompt config --
git repo, pushed to GitHub, fully stowed. See `DOTFILES_STOW_WORKFLOW.md`
for the full workflow and secret hygiene. Quick restore:

    git clone git@github.com:thewuuryar/dotfiles.git ~/dotfiles
    cd ~/dotfiles
    stow awesome bash cheatsheets git starship systemd xorg
    sudo stow -t / ly

`~/ai-workspace/dotfiles/` is a separate, non-git plain-file copy of
that whole repo for exchanging files with Hermes -- not backed up on its
own; changes there must be copied back to `~/dotfiles` and committed.

--------------------------------------------------------------------------
4. HERMES AGENT INTEGRATION (systemd user services)
--------------------------------------------------------------------------
Two systemd --user units (`systemd/.config/systemd/user/` in dotfiles):

hermes.service (oneshot, WantedBy=default.target):
  - `podman run -d --name hermes --restart unless-stopped`
  - Mounts: `%h/.hermes` -> `/opt/data` (agent state),
    `%h/ai-workspace` -> `/opt/data/workspace` (file exchange)
  - Rootless via `--userns=keep-id:uid=10000,gid=10000`
  - Image: `docker.io/nousresearch/hermes-agent`, entrypoint
    `sleep infinity` (idles; work happens via `podman exec`)

hermes-agent.service (simple, WantedBy=graphical-session.target,
Requires/After=hermes.service):
  - Waits up to 30s for `podman exec hermes true` to succeed
  - Launches `urxvt -name HermesAgent -e podman exec -it hermes hermes`
  - ExecStop pkills the urxvt window by WM_CLASS instance
  - Restart=on-failure

IMPORTANT: ly never calls `systemctl --user start
graphical-session.target` the way GNOME/KDE do, so anything
WantedBy=graphical-session.target (like hermes-agent.service) would
never auto-start. Fix, near the top of rc.lua:

    systemctl --user import-environment DISPLAY XAUTHORITY \
        XDG_SESSION_ID XDG_SEAT XDG_VTNR
    systemctl --user start graphical-session.target

AwesomeWM side (`config/hermes_agent.lua`): does not spawn the process --
systemd owns its lifecycle. Awesome only finds the running client by
WM_CLASS instance "HermesAgent" and shows/hides/centers it. Super+A
toggles visibility; window starts hidden so login doesn't pop it up.
Border: `#d3869b` (gruvbox purple), 4px, floating+ontop, no taskbar.

To reproduce from scratch:

    mkdir -p ~/.config/systemd/user
    cp ~/dotfiles/systemd/.config/systemd/user/hermes*.service \
       ~/.config/systemd/user/
    systemctl --user daemon-reload
    systemctl --user enable --now hermes.service
    systemctl --user enable hermes-agent.service
    # hermes-agent.service starts once graphical-session.target fires
    # (next graphical login), not immediately from a TTY

Requires podman configured for rootless use (uid/gid subordinate ranges
via /etc/subuid, /etc/subgid -- usually automatic on Arch after the
first rootless container run; check `podman info` if hermes.service
fails to start).

--------------------------------------------------------------------------
5. HERMES AGENT'S OWN MEMORY
--------------------------------------------------------------------------
Two small persistent files, loaded into every conversation automatically:

    ~/.hermes/memories/MEMORY.md   (agent's own operating notes)
    ~/.hermes/memories/USER.md     (facts about the user/setup)

(`/opt/data` in the container is bind-mounted from `~/.hermes` on the
host, so these are the same files at `/opt/data/memories/*.md`.)

BACKUP: include in your regular home-directory backup, or add to the
dotfiles repo (e.g. a `hermes-memory-backup/` subfolder) -- review
contents before pushing anywhere public, since entries can accumulate
private details over time. Not currently in `~/dotfiles`.

RESTORE (fresh Hermes container / new laptop): recreate
`~/.hermes/memories/`, copy in your backed-up `MEMORY.md`/`USER.md`,
then start `hermes.service` -- the mount means the container sees them
immediately.

If no backup exists, hand a fresh agent this document plus
`installed-packages.txt` and ask it to re-derive equivalent memory
entries from the setup described here.

--------------------------------------------------------------------------
6. NEXT STEPS
--------------------------------------------------------------------------
1. Consider adding `~/.hermes/memories/*.md` into the dotfiles repo
   (e.g. `hermes-memory-backup/`) so one `git clone` restores configs
   and agent memory together. Not done yet.
2. Periodically re-run the section 2 inventory command and refresh
   `installed-packages.txt`.
3. Confirm with the user whether bspwm/sxhkd are safe to remove.
