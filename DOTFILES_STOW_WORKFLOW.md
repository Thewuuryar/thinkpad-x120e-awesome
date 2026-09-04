# Dotfiles / GNU Stow Workflow — AwesomeWM, ly, and secret hygiene

Companion to LAPTOP_SETUP_REPRODUCIBILITY.md (section 3 there points here).
Status: DONE. ~/dotfiles is a git repo, pushed to GitHub, and every
package in it (awesome, bash, cheatsheets, git, ly, starship, systemd,
xorg) is already stow-symlinked live into place. This doc is now the
reference for how that setup works and how to extend it, not a
step-by-step to run from scratch -- keep it around for restoring on a
new machine (section 7) and for adding new packages later (section 5).

--------------------------------------------------------------------------
1. HOW IT'S WIRED
--------------------------------------------------------------------------
Real files live under ~/dotfiles/<package>/<same relative path>, and
stow symlinks them out to their real config locations:

  ~/dotfiles/<package>/<same relative path>   (real files, in git)
         |
         v  (stow creates symlinks)
  ~/.config/awesome, /etc/ly/config.ini, etc.  (symlinks pointing back)

So the git repo is the single source of truth, and the actual config
locations (~/.config/awesome, ~/.bashrc, /etc/ly/config.ini, ...) are
just symlinks into it. If the disk dies, `git clone` + `stow <package>`
(and `sudo stow -t / ly` for the one system-path package) restores every
symlink in one shot -- see section 7.

NOTE: ~/ai-workspace/dotfiles/ (this copy, mounted into the Hermes
container at /opt/data/workspace/dotfiles/) is a SEPARATE plain-file
copy of the whole ~/dotfiles/ folder, kept here purely so files can be
passed back and forth to Hermes without one-off copies. It is NOT a git
repo itself and is NOT what's stowed live -- edits made here need to be
copied back into the real ~/dotfiles/ on the host (and committed/pushed
from there) to actually take effect or be saved. See README.md in this
directory for the full package list.

--------------------------------------------------------------------------
2. PACKAGE LAYOUT (for reference / adding new packages)
--------------------------------------------------------------------------
A stow package directory's structure mirrors where its contents should
land relative to the stow target dir (default: your home directory, one
level up from ~/dotfiles). Current packages:

    ~/dotfiles/
      awesome/.config/awesome/       -- AwesomeWM config, stow (home target)
      bash/.bashrc                   -- shell rc, stow (home target)
      cheatsheets/.config/cheatsheets/ -- Super+/ panel markdown, stow (home target)
      git/.gitconfig                 -- git identity + aliases, stow (home target)
      ly/etc/ly/config.ini           -- ly display manager, sudo stow -t /
      starship/.config/starship.toml -- prompt config, stow (home target)
      systemd/.config/systemd/user/  -- hermes*.service, stow (home target)
      xorg/.Xresources, xorg/.xinitrc -- urxvt/X session, stow (home target)
      vim/                           -- reserved, empty so far

--------------------------------------------------------------------------
3. MIGRATING A NEW HOME-DIR-TARGET PACKAGE (no sudo)
--------------------------------------------------------------------------
    # Move the real files into the dotfiles package
    mkdir -p ~/dotfiles/<pkg>/.config
    mv ~/.config/<thing> ~/dotfiles/<pkg>/.config/<thing>

    # Let stow symlink it back into place
    cd ~/dotfiles
    stow <pkg>

    # Verify: this should now be a symlink pointing into ~/dotfiles
    ls -la ~/.config/<thing>

  From now on, edit files under ~/dotfiles/<pkg>/... (or edit the live
  path directly -- same file, since it's a symlink) and
  `git add / commit / push` from ~/dotfiles whenever you want to save a
  checkpoint.

--------------------------------------------------------------------------
4. MIGRATING A SYSTEM-PATH PACKAGE (needs sudo + a custom stow target)
--------------------------------------------------------------------------
Anything living outside your home dir (like ly's /etc/ly/config.ini)
needs stow pointed at / explicitly, since stow's default target is your
home directory:

    mkdir -p ~/dotfiles/<pkg>/etc/<thing>
    sudo mv /etc/<thing>/config /home/dotfiles/<pkg>/etc/<thing>/config
    sudo chown $(whoami):$(whoami) ~/dotfiles/<pkg>/etc/<thing>/config

    cd ~/dotfiles
    sudo stow -t / <pkg>

    # Verify:
    ls -la /etc/<thing>/config

  (sudo is required both to move the original file, since /etc/<thing>
  is typically root-owned, and to create the symlink back into /etc.
  The file itself can stay owned by your user inside ~/dotfiles once
  moved.) This is exactly how ly/etc/ly/config.ini is already set up.

--------------------------------------------------------------------------
5. ADDING MORE PACKAGES LATER (systemd units, scripts, etc.)
--------------------------------------------------------------------------
Same pattern as section 3/4 for anything else worth centralizing. General
rule: one stow package per logical concern, mirroring the real path
under the package dir. vim/ is already reserved as an empty package for
whenever a vim/nvim config gets added.

--------------------------------------------------------------------------
6. KEEPING SECRETS OUT OF THE REPO
--------------------------------------------------------------------------
Nothing found in the current dotfiles is a hardcoded secret --
wifi-connect.sh takes the SSID/password as runtime CLI args from the
wifi_popup.lua widget and hands them straight to `nmcli`, nothing is
written to disk by that script. git/.gitconfig uses a GitHub-provided
noreply email (not a real address). Still, watch for these traps going
forward, since they're easy to stow by accident:

  a) NetworkManager connection profiles
     /etc/NetworkManager/system-connections/*.nmconnection files DO store
     wifi PSKs in plaintext (root-readable only, but plaintext). NEVER
     move these into ~/dotfiles. They're not part of your WM look/feel
     anyway — NetworkManager manages them itself and they don't need to
     be reproduced via stow; on a fresh install you just reconnect once.

  b) SSH keys / known_hosts
     Don't stow ~/.ssh. Keys should never touch a git repo (even private
     ones) unless deliberately encrypted (git-crypt / sops / age). If you
     want your ssh *config* (not keys) in dotfiles, that's fine — just
     the file at ~/.ssh/config, never id_ed25519 / id_rsa etc.

  c) Tailscale auth keys, API tokens, .env files
     If any future script/widget needs an API key or token (e.g. a
     future weather widget, or a tailscale authkey for scripted joins),
     keep it in a file OUTSIDE ~/dotfiles (e.g. ~/.config/secrets/ or
     pass/gopass) and have the script read from there, or from an
     environment variable set outside version control. Never hardcode a
     token as a string literal in a script/config that lives under
     ~/dotfiles.

  d) Hermes agent memory files
     ~/.hermes/memories/{MEMORY,USER}.md are plain text and, per the
     reproducibility doc, are fine to also back up into dotfiles — but
     review their contents before pushing each time, since future
     entries could end up recording something you'd consider private
     (this is a manual judgment call, not something to automate). Not
     currently in ~/dotfiles as of this writing.

  A .gitignore is already in place at ~/dotfiles/.gitignore (and mirrored
  in this ai-workspace copy) covering *.nmconnection, *secret*, *token*,
  *.key, *.pem, .env, ssh keys, known_hosts, plus editor/OS cruft
  (*.swp, *.bak, .DS_Store).

  Optional but not yet done: install git-secrets or a pre-commit hook
  that greps staged diffs for common credential patterns before every
  commit. Ask Hermes to set this up if you want it.

  Before pushing anything new: `git diff --cached` before each commit,
  or `git log -p | less` for a fuller review. The repo is already
  public/pushed, so treat every file as visible to anyone, forever,
  including in history even if later deleted.

--------------------------------------------------------------------------
7. RESTORE PROCEDURE (fresh Arch install, disk replaced)
--------------------------------------------------------------------------
    sudo pacman -S --needed stow git
    git clone git@github.com:thewuuryar/dotfiles.git ~/dotfiles
    cd ~/dotfiles
    stow awesome bash cheatsheets git starship systemd xorg
    sudo stow -t / ly
    systemctl --user daemon-reload
    systemctl --user enable --now hermes.service
    systemctl --user enable hermes-agent.service

Then follow LAPTOP_SETUP_REPRODUCIBILITY.md sections 2 and 4 for package
reinstallation and Hermes memory restoration.
