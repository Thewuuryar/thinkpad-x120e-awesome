# Dotfiles / GNU Stow Workflow

Status: DONE. `~/dotfiles` is a git repo, pushed to GitHub, with every
package (awesome, bash, cheatsheets, git, ly, starship, systemd, xorg)
stow-symlinked live. This doc is a reference for how it's wired and how
to extend it -- see section 4 for restoring on a new machine.

--------------------------------------------------------------------------
1. HOW IT'S WIRED
--------------------------------------------------------------------------
    ~/dotfiles/<package>/<same relative path>   (real files, in git)
           |
           v  stow creates symlinks
    ~/.config/awesome, /etc/ly/config.ini, etc.  (symlinks)

The git repo is the source of truth; live config paths are symlinks into
it. `git clone` + `stow <package>` restores everything in one shot.

Note: `~/ai-workspace/dotfiles/` is a separate, non-git plain-file copy
of this whole repo, kept for easy file exchange with Hermes. It is not
what's stowed -- edits there must be copied back into `~/dotfiles/` and
committed/pushed to take effect.

--------------------------------------------------------------------------
2. ADDING A NEW PACKAGE
--------------------------------------------------------------------------
Home-dir target (no sudo):

    mkdir -p ~/dotfiles/<pkg>/.config
    mv ~/.config/<thing> ~/dotfiles/<pkg>/.config/<thing>
    cd ~/dotfiles && stow <pkg>
    ls -la ~/.config/<thing>   # should now be a symlink

System-path target (e.g. /etc, needs sudo -- this is how ly is set up):

    mkdir -p ~/dotfiles/<pkg>/etc/<thing>
    sudo mv /etc/<thing>/config ~/dotfiles/<pkg>/etc/<thing>/config
    sudo chown $(whoami):$(whoami) ~/dotfiles/<pkg>/etc/<thing>/config
    cd ~/dotfiles && sudo stow -t / <pkg>
    ls -la /etc/<thing>/config

One package per logical concern, mirroring the real path under the
package dir. `vim/` is already reserved for a future vim/nvim config.

--------------------------------------------------------------------------
3. KEEPING SECRETS OUT OF THE REPO
--------------------------------------------------------------------------
No hardcoded secrets found in the current dotfiles -- wifi-connect.sh
takes SSID/password as runtime CLI args and hands them to `nmcli`,
nothing is written to disk; `git/.gitconfig` uses a GitHub noreply email.

`.gitignore` already covers `*.nmconnection`, `*secret*`, `*token*`,
`*.key`, `*.pem`, `.env`, SSH keys, `known_hosts`. Watch for these traps
going forward:

  - NetworkManager `*.nmconnection` files store wifi PSKs in plaintext --
    never move these into dotfiles; NetworkManager manages them itself.
  - Never stow `~/.ssh` (keys). `~/.ssh/config` alone is fine.
  - Future API keys/tokens (weather widget, tailscale authkey, etc.):
    keep outside `~/dotfiles` (e.g. `~/.config/secrets/`, pass/gopass)
    and read from there or an env var -- never hardcode as a literal.
  - `~/.hermes/memories/{MEMORY,USER}.md` are plain text and fine to
    back up into dotfiles, but review contents before each push --
    future entries could record something private.

Before pushing: `git diff --cached`, or `git log -p | less` for a full
review. The repo is already public -- treat every file as visible
forever, including in history even if later deleted.

--------------------------------------------------------------------------
4. RESTORE PROCEDURE (fresh Arch install, disk replaced)
--------------------------------------------------------------------------
    sudo pacman -S --needed stow git
    git clone git@github.com:thewuuryar/dotfiles.git ~/dotfiles
    cd ~/dotfiles
    stow awesome bash cheatsheets git starship systemd xorg
    sudo stow -t / ly
    systemctl --user daemon-reload
    systemctl --user enable --now hermes.service
    systemctl --user enable hermes-agent.service

Then follow `LAPTOP_SETUP_REPRODUCIBILITY.md` for package reinstallation
and Hermes memory restoration.
