# Dotfiles / Laptop Config

Personal Arch Linux + AwesomeWM configuration, managed with GNU stow.

This directory is a **plain-file working copy** of `~/dotfiles/` from
the host, mounted here so files can move easily between the host and
Hermes. It is not itself a git repo. The real source of truth is
`~/dotfiles/` on the host (git, pushed to GitHub, stow-symlinked live).
Edit here, then copy changes back to `~/dotfiles/` and commit/push from
there.

## Contents (one directory per stow package)

- `awesome/.config/awesome/` -- AwesomeWM config (gruvbox theme)
- `bash/.bashrc` -- shell aliases/functions (`gbranch`, `gmerge`,
  `gmerge-squash`, `gcommit`) plus starship prompt init
- `cheatsheets/.config/cheatsheets/` -- markdown cheatsheets for the
  `Super+/` panel
- `git/.gitconfig` -- git identity + aliases
- `ly/etc/ly/config.ini` -- ly display manager config (system target,
  `sudo stow -t /`; `config.ini.orig` is the stock default, kept for
  diffing only)
- `starship/.config/starship.toml` -- prompt, gruvbox dark theme
- `systemd/.config/systemd/user/` -- Hermes container + agent units
- `xorg/.Xresources`, `xorg/.xinitrc` -- urxvt colors/fonts, X startup
- `vim/` -- reserved, empty for now
- `.gitignore` -- secrets/keys/`.env`/NetworkManager exclusions
- `LICENSE` -- MIT

## Docs

- `DOTFILES_STOW_WORKFLOW.md` -- how stow is wired, adding packages,
  secret hygiene, disaster recovery
- `LAPTOP_SETUP_REPRODUCIBILITY.md` -- full machine rebuild (OS,
  packages, Hermes systemd integration)

## Git workflow

Short-lived `<type>/<name>` branches off `main`, conventional commit
messages, squash or `--no-ff` merge back to main, delete branch after
merging. Full cheatsheet: `.config/cheatsheets/git.md`.
