# Neovim TypeScript Cheatsheet

## Search
- `<leader>fw` - Live grep
- `<leader>ff` - Find files
- `<leader>fb` - Buffers
- `<leader>fo` - Recent files
- `<leader>fz` - Search current file
- `<leader>fs` - Document symbols
- `<leader>fS` - Workspace symbols
- `<leader>fd` - Diagnostics

## Navigation
- `gd` - Definition
- `gr` - References
- `gi` - Implementations
- `gt` - Type definition
- `K` - Hover docs
- `s` - Flash jump
- `S` - Flash treesitter

## Code Actions
- `<leader>ca` - Code action
- `<leader>rn` - Rename
- `<leader>fm` - Format file
- `[d` / `]d` - Prev/next diagnostic

## TypeScript
- `<leader>to` - Organize imports
- `<leader>ta` - Add missing imports
- `<leader>tf` - Fix all
- `<leader>tr` - Remove unused
- `<leader>tg` - Go to source

## Refactoring
- `<leader>rr` - Refactor menu (visual)
- `<leader>re` - Extract function
- `<leader>rv` - Extract variable
- `<leader>ri` - Inline variable
- `<leader>rI` - Inline function

## Git
- `<leader>gs` - Stage hunk
- `<leader>gr` - Reset hunk
- `<leader>gb` - Blame line
- `<leader>gp` - Preview hunk
- `<leader>gd` - Diff view
- `[h` / `]h` - Prev/next hunk

## GitHub PR Review (Octo)
Launch (leader = space):
- `<leader>op` - List PRs
- `<leader>oP` - Search PRs
- `<leader>oc` - Checkout PR branch
- `<leader>or` - Start review
- `<leader>oR` - Resume review
- `<leader>os` - Submit review
- `<leader>oi` - List issues
- `<leader>ob` - Open PR in browser

In review (localleader = `\`):
- `]q` / `[q` - Next/prev changed file
- `<leader>e` - Toggle file panel
- `\ca` - Add comment (works on visual selection)
- `\sa` - Add suggestion
- `\ja` / `\jd` - Approve / request changes (in submit window)

## PR Review — pr.nvim (focused, A/B vs octo)
- `<leader>gr` - List / review PRs (`:PR`, `:PR 123`, `:PR owner/repo#123`)
In review:
- `]f` / `[f` - Next/prev file
- `]c` / `[c` - Next/prev comment
- `f` - File picker, `F` - toggle full-file vs diff, `p` - PR info
- `c` - comment, `s` - suggestion, `r` - reply
- `S` - submit review, `Q` - close, `?` - help

## Find & Replace
- `<leader>sr` - Open Spectre
- `<leader>sw` - Search word
- `<leader>sp` - Search in file

## Diagnostics
- `<leader>xx` - Toggle Trouble
- `<leader>xw` - Workspace diagnostics
- `<leader>xd` - Document diagnostics

## Completion
- `<C-n>/<C-p>` - Next/prev item
- `<Tab>` - Accept/navigate
- `<C-Space>` - Trigger completion
- `<C-e>` - Cancel

## Folding
- `zR` - Open all folds
- `zM` - Close all folds
- `zK` - Peek fold

## Comments
- `gcc` - Comment line
- `gc` - Comment motion
- Auto-detects JSX/TSX context
## Agent Watch (live view of what coding agents are changing)
- `<leader>aw` - Toggle panel (`:AgentWatch`)
- `<leader>hB` - Cycle diff base: branch (merge-base w/ main) → HEAD → index; syncs gutter signs too
- Gutter: heavy `┃` bars + colored line numbers mark changed lines vs the current base
- While the panel is open, buffers get the full diff overlay (line wash, word diff, deleted lines); closes with the panel
In panel:
- `<CR>` / double-click - Jump to hunk (or open commit in Diffview)
- `o` - Jump but keep focus in panel
- `p` - Preview diff in a float
- `d` - Open file (vs base) or commit in Diffview
- `l` / `h` / `<Tab>` - Expand / collapse / toggle file, `zR` / `zM` - all; files start collapsed
- `b` - Cycle base, `r` - refresh, `c` - clear activity feed, `q` - close, `?` - help
- Activity feed: timeline of agent actions (edit / new / del / commit). Repeated edits to a file update its row until a commit lands; `●` = last 45s, yellow = last 5 min

## Tab pages
- `<leader>.` / `<leader>,` - Next / previous tab (Diffview, Neogit each open in a tab)
- `<leader>tc` - Close tab
- `gT` - Previous tab (`gt` is remapped to LSP type definition)

## LSP inside Diffview
- `gd` - Go to definition: opens the file in your editor tab at the definition
- `<C-o>` - From that landing spot, jumps straight back to the diff (same window, same line)
- `gr` - References (Telescope, in editor tab)
- `gh` - Hover, shown in place over the diff
