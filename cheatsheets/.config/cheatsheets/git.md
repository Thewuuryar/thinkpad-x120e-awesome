---
key: g
title: Git
---

# status / diff

- `git status`                    -- working tree state
- `git diff`                      -- unstaged changes
- `git diff --staged`             -- staged changes

# stage / commit

- `git add -p`                    -- stage hunks interactively
- `git commit -m '...'`           -- commit staged changes
- `git commit --amend`            -- edit last commit

# branches

- `git switch -c <name>`          -- create and switch to branch
- `git branch -d <name>`          -- delete merged branch
- `git switch -`                  -- back to previous branch

# merge branch back to main

- `git switch main`               -- go to main first
- `git pull`                      -- make sure main is up to date
- `git merge <branch>`            -- merge branch into main
- `git push`                      -- push updated main
- `git branch -d <branch>`        -- delete local branch after merge
- `git push origin --delete <branch>` -- delete remote branch after merge

# sync

- `git fetch`                     -- fetch remote refs
- `git pull --rebase`             -- fetch + rebase local commits
- `git push`                      -- push current branch
- `git push -u origin HEAD`       -- push new branch, set upstream

# history

- `git log --oneline --graph -20` -- recent commit graph
- `git show <sha>`                -- show one commit's changes
- `git blame <file>`              -- who changed each line

# undo

- `git restore <file>`            -- discard unstaged changes
- `git restore --staged <file>`   -- unstage a file
- `git reset --soft HEAD~1`       -- undo last commit, keep changes
- `git reflog`                    -- recover lost commits/branches

# stash

- `git stash`                     -- shelve working tree changes
- `git stash pop`                 -- reapply and drop latest stash
- `git stash list`                -- list stashed changes
