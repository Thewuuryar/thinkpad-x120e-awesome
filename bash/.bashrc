#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# Created by `pipx` on 2026-08-29 06:55:02
export PATH="$PATH:$HOME/.local/bin"

# ===== Starship prompt =====
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

# ===== Git Workflow Helpers =====
# gbranch <type>/<name>  -- start new branch off up-to-date main
gbranch() {
  if [ -z "$1" ]; then echo "usage: gbranch <type>/<name>"; return 1; fi
  git switch main && git pull && git switch -c "$1"
}

# gmerge (run from feature branch) -- Merge branch and delete
gmerge() {
  local branch
  branch=$(git branch --show-current)
  if [ "$branch" = "main" ]; then echo "on main branch, swich to different branch to merge"; return 1; fi

  git switch main && git pull \
    && git merge --no-ff "$branch" \
    && git push \
    && git branch -d "$branch" \
    && git push origin --delete "$branch" 2>/dev/null
}

# gmerge-squash -- Squash merge branch and delete
gmerge-squash() {
  local branch
  branch=$(git branch --show-current)
  if [ "$branch" = "main" ]; then echo "on main branch, swich to different branch to merge"; return 1; fi

  git switch main && git pull \
    && git merge --squash "$branch" \
    && git push \
    && git branch -d "$branch" \
    && git push origin --delete "$branch" 2>/dev/null
}

# gcommit                -- stage all, promp for message, commit
# gcommit path/to/file   -- stage only path, prompt for message, commit
# gcommit -m "fix: typo" -- stage all, commit with message
gcommit() {
  if [ "$1" = "-m" ]; then
    shift
    git add -A && git commit -m "$*"
    return
  fi

  if [ -n "$1" ]; then
    git add "$@"
  else
    git add -A
  fi

  if git diff --cached --quiet; then
    echo "nothing staged"
    return 1
  fi

  echo "type (feat/fit/docs/style/refactor/perf/test/chore/ci): "
  
  read -r type
  echo "scope (optional, enter to skip: "
  read -r scope
  echo "summary: "
  read -r summary

  if [ -n "$scope" ]; then
    git commit -m "${type}(${scope}): ${summary}"
  else
    git commit -m "${type}: ${summary}"
  fi
}
