# Dotfiles / Laptop Config

Personal Arch Linux + AwesomeWM configuration, managed with GNU stow.

This copy lives at `~/ai-workspace/dotfiles/` (mounted into the Hermes
container at `/opt/data/workspace/dotfiles/`) as a **working copy** --
it's the whole `~/dotfiles/` folder, copied in wholesale so files can be
passed back and forth between the host and Hermes without one-off copies.
The real, git-tracked source of truth is `~/dotfiles/` on the host; this
copy is not itself a git repo and is not backed up on its own (see
`LAPTOP_SETUP_REPRODUCIBILITY.md` section 3 for how the two relate and
how to keep them in sync).

## Contents (one directory per stow package)

- `awesome/.config/awesome/` -- AwesomeWM config (gruvbox theme)
- `bash/.bashrc` -- shell functions/aliases (`gbranch`, `gmerge`,
  `gmerge-squash`, `gcommit`) for the git workflow in `git.md`, plus
  starship prompt init
- `cheatsheets/.config/cheatsheets/` -- markdown cheatsheets shown by the
  `Super+/` panel (see `cheatsheets.md` for how the panel renders them,
  and `git.md` for the git workflow used in this repo)
- `git/.gitconfig` -- git identity (GitHub noreply email) and aliases
  (`create`, `st`, `unstage`, `amend`, `last`, `graph`, `unmerged`)
- `ly/etc/ly/config.ini` -- ly display manager config (needs
  `sudo stow -t /`, not a home-dir target); `config.ini.orig` alongside
  it is the untouched upstream default, kept only for diffing, not part
  of the stowed package
- `starship/.config/starship.toml` -- starship prompt, gruvbox dark theme
- `systemd/.config/systemd/user/` -- `hermes.service`,
  `hermes-agent.service`, `awesome-session.target` (see
  `LAPTOP_SETUP_REPRODUCIBILITY.md` section 4 for how these work)
- `xorg/.Xresources`, `xorg/.xinitrc` -- urxvt gruvbox colors/fonts, X
  session startup
- `vim/` -- reserved package, empty so far
- `.gitignore` -- never commit secrets/keys/`.env`/NetworkManager
  connection files; see that file for the full list
- `LICENSE` -- MIT

## Applying this config

See `DOTFILES_STOW_WORKFLOW.md` for the full stow workflow, and
`LAPTOP_SETUP_REPRODUCIBILITY.md` for full disaster-recovery
setup (OS, packages, systemd units).

## Git workflow

This repo follows the workflow documented in
`.config/cheatsheets/git.md`: short-lived `<type>/<name>` branches
off `main`, conventional commit messages, squash or `--no-ff`
merge back to main, delete branch after merging.
