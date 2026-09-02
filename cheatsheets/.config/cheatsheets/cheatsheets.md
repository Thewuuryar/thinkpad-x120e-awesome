---
key: c
title: Cheatsheets
---

# Adding a new cheatsheet

- Drop a new `.md` file into `~/.config/cheatsheets/`
- Press `Super+/` again -- the picker rescans the directory every time it opens
- No AwesomeWM restart needed

# Picking key and title

- By default the **key** is the file's first letter and the **title** is
  the filename (without `.md`), capitalized
- Example: `tmux.md` -> key `t`, title "Tmux"
- Override either with optional frontmatter at the top of the file:

```
---
key: x
title: My Custom Title
---
```

# If two files want the same key

- Whichever file sorts first alphabetically keeps that key
- Give the other file an explicit `key:` in its frontmatter to fix it

# Supported markup (kept intentionally simple)

- `# Heading` / `## Heading`      -- section headers (bold)
- `- item` or `* item`            -- bullet list
- `` `inline code` ``             -- monospace-style emphasis
- `**bold**`                      -- bold text

# Not supported

- Tables, links, images, numbered lists, nested lists -- these render as
  plain text rather than styled. Keep entries short and flat.
