macOS configs managed with GNU Stow. Each top-level folder is a package mirroring paths under `~`; the `~` paths are symlinks into this repo, so edit files here.

## Goal

This repo exists to build a terminal workspace for agentic coding that beats the Claude and Codex desktop apps: running many agents at once, knowing which one needs attention, and seeing and understanding what each one changed. Expect it to grow through herdr config, nvim plugins, and small custom tools, whatever makes that workflow better.

The desktop apps are good at surfacing what Nihaar needs to see, and they keep getting better, but they're hard to customize and weak on keyboard control. Here we can build anything. Stay open-minded, research the latest tools and practices, and think hard about what helps Nihaar work best.

## Rules

- Never commit secrets. Tokens/API keys go in `~/.zshrc.secrets` (untracked). This repo is public.
- Dry-run first: `stow -nv <pkg>`, show the result, then `stow <pkg>`.
- New tool the setup depends on → add it to `Brewfile` so a fresh Mac gets it from `install.sh`.
- File-level links (`.zshrc`, `.zprofile`, `.p10k.zsh`, `.tmux.conf`, `.gitconfig`, `.ideavimrc`, herdr's `config.toml`, `~/.claude/CLAUDE.md`) get replaced by anything that writes-then-renames (`sed -i`, `p10k configure`). Edit the repo file directly. `stow -nv */` reports a replaced link as a conflict; fix with `stow --adopt <pkg>` + `git diff`.
- `~/.config/herdr`, `~/.claude` and `~/.local/bin` must stay real directories (sockets, sessions, other tools' binaries live there); `install.sh` creates them before stowing so stow links files, not the folder.
- Small custom tools go in the `bin` package (`bin/.local/bin/`, on `PATH`).
- After changing a config, tell the user how to reload it rather than restarting apps unasked:

| App | Reload |
|---|---|
| Karabiner | auto on save; else `fix-keys` |
| tmux | `prefix` + `r` |
| nvim | restart; `:Lazy sync` for plugin changes |
| Ghostty | `cmd+shift+,` |
| Hammerspoon | menu bar → Reload Config |
| zsh | `exec zsh` |
| herdr | `prefix` + `r` (`herdr server reload-config`) |
