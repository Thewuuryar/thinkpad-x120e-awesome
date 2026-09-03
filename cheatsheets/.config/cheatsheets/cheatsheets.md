---
key: c
title: Cheatsheets
---

# Adding a new cheatsheet

- Drop a new `.md` file into `~/.config/cheatsheets/`
- Press `Super+/` again
  the picker rescans the directory every time it opens
- No AwesomeWM restart needed

# Picking key and title

- Default key is the file's first letter
  default title is the filename (without `.md`), capitalized
- Example: `tmux.md` -> key `t`, title "Tmux"
- Override either with frontmatter at the top of the file:

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

- `# Heading` / `## Heading`
  section headers (bold)
- `- item` or `* item`
  bullet list
- `` `inline code` ``
  monospace-style emphasis
- `**bold**`
  bold text

# Not supported

- Tables, links, images, numbered lists, nested lists
  these render as plain text rather than styled

# Panel size (keep lines readable)

- Panel is 420px wide, rendered in Fantasque Sans Mono 10
- Usable text width is ~380px after margins and scrollbar
- Keep lines at or under ~55-60 characters so they don't wrap
- Wrapped lines lose their indent and fall back to column 0
  (Pango wrap has no hanging-indent support), so don't rely
  on wrapping to stay readable -- break long lines yourself

# Item + description formatting

- For a command/term with a short description, put the
  description on its own line under the item
- Bullet items render with a 2-space indent automatically;
  indent the description line 2 more (4 spaces) in the source
  so it reads as clearly nested under the item
- Example source:

```
- `git status`
    working tree state
```

- Keeps entries short and flat -- one description line per
  item, no wrapping, no nested bullets
