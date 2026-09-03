---
key: g
title: Git
---

# workflow

- branch off main for every change: `<type>/<short-desc>`
- commit as you go: `<type>(<scope>): <summary>`
- merge back to main when done, then delete the branch
- resume later by cutting a fresh branch, not reusing old ones
- see appendix below for the full list of types

# status / diff

- `git status`
    working tree state
- `git diff`
    unstaged changes
- `git diff --staged`
    staged changes

# stage / commit

- `git add -p`
    stage hunks interactively
- `git commit -m '...'`
    commit staged changes
- `git commit --amend`
    edit last commit

# branches

- `git switch -c <name>`
    create and switch
- `git switch <name>`
    switch to existing branch
- `git switch -`
    back to previous branch
- `git branch -m <old> <new>`
    rename (scope changed)
- `git branch -d <name>`
    delete merged branch
- `git branch -a`
    list local + remote branches

# merge branch back to main

- `git switch main`
    go to main first
- `git pull`
    make sure it's current
- `git merge --squash <branch>`
    squash into one clean commit (default)
- `git commit`
    write the message
- `git merge --no-ff <branch>`
    alt: keep merge commit + branch history
- `git push`
    push updated main
- `git branch -d <branch>`
    delete local
- `git push origin --delete <branch>`
    delete remote branch

# resuming a merged feature

- deleted branch:
    `git switch main && git pull`
    then `git switch -c feat/<name>`
- kept branch:
    `git rebase main` to update it

# sync

- `git fetch`
    fetch remote refs
- `git pull --rebase`
    fetch + rebase local commits
- `git push`
    push current branch
- `git push -u origin HEAD`
    push new branch, set upstream

# history

- `git log --oneline --graph -20`
    recent commit graph
- `git show <sha>`
    show one commit's changes
- `git blame <file>`
    who changed each line
- `git log --oneline main..<branch>`
    commits on branch not yet in main

# undo

- `git restore <file>`
    discard unstaged changes
- `git restore --staged <file>`
    unstage a file
- `git reset --soft HEAD~1`
    undo last commit, keep changes
- `git reflog`
    recover lost commits/branches

# stash

- `git stash`
    shelve working tree changes
- `git stash pop`
    reapply and drop latest stash
- `git stash list`
    list stashed changes

# appendix: branch/commit types

- naming: `<type>/<short-desc>` for branches,
    `<type>(<scope>): <summary>` for commits
- `feat`
    new feature or capability
- `fix`
    bug fix
- `docs`
    documentation only
- `style`
    formatting, no logic change (commit only)
- `refactor`
    restructure, no behavior change
- `perf`
    performance improvement (commit only)
- `test`
    add or fix tests (commit only)
- `chore`
    tooling, deps, config maintenance
- `ci`
    CI/CD config changes (commit only)
- `hotfix`
    urgent fix, often off a release (branch only)
- scope in commits is optional, e.g. `fix(menu): ...`
- commit summary uses imperative mood: "add", not "added"
- add a blank line + body to explain *why*, if not obvious
