require "nvchad.mappings"

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- Focus nvim-tree window
map("n", "<leader>n", "<cmd>NvimTreeFocus<CR>", { desc = "Focus file tree" })

-- Fast movement with Shift + hjkl
map("n", "H", "5h", { desc = "Move 5 left" })
map("n", "J", "5j", { desc = "Move 5 down" })
map("n", "K", "5k", { desc = "Move 5 up" })
map("n", "L", "5l", { desc = "Move 5 right" })
map("v", "H", "5h", { desc = "Move 5 left" })
map("v", "J", "5j", { desc = "Move 5 down" })
map("v", "K", "5k", { desc = "Move 5 up" })
map("v", "L", "5l", { desc = "Move 5 right" })


-- Telescope advanced search
map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
map("n", "<leader>fw", "<cmd>Telescope live_grep<CR>", { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Find buffers" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "Help tags" })
map("n", "<leader>fo", "<cmd>Telescope oldfiles<CR>", { desc = "Recent files" })
map("n", "<leader>fz", "<cmd>Telescope current_buffer_fuzzy_find<CR>", { desc = "Find in current buffer" })
map("n", "<leader>fs", "<cmd>Telescope lsp_document_symbols<CR>", { desc = "Document symbols" })
map("n", "<leader>fS", "<cmd>Telescope lsp_workspace_symbols<CR>", { desc = "Workspace symbols" })
map("n", "<leader>fd", "<cmd>Telescope diagnostics<CR>", { desc = "Diagnostics" })

-- LSP
map("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
map("n", "gr", "<cmd>Telescope lsp_references<CR>", { desc = "Find references" })
map("n", "gi", "<cmd>Telescope lsp_implementations<CR>", { desc = "Find implementations" })
map("n", "gt", vim.lsp.buf.type_definition, { desc = "Go to type definition" })
map("n", "gh", vim.lsp.buf.hover, { desc = "Hover documentation" })
map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })

-- Diagnostics ([d / ]d are Neovim defaults)
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostic list" })

-- Trouble
map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Toggle Trouble" })
map("n", "<leader>xw", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Workspace diagnostics" })
map("n", "<leader>xd", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", { desc = "Document diagnostics" })
map("n", "<leader>xq", "<cmd>Trouble qflist toggle<CR>", { desc = "Quickfix list" })
map("n", "<leader>xl", "<cmd>Trouble loclist toggle<CR>", { desc = "Location list" })

-- Git with Neogit + Diffview + Gitsigns
-- Neogit (main git interface)
map("n", "<leader>gg", "<cmd>Neogit<CR>", { desc = "Neogit (Git status)" })
map("n", "<leader>gc", "<cmd>Neogit commit<CR>", { desc = "Git commit" })
map("n", "<leader>gp", "<cmd>Neogit push<CR>", { desc = "Git push" })
map("n", "<leader>gl", "<cmd>Neogit pull<CR>", { desc = "Git pull" })
map("n", "<leader>gB", "<cmd>Neogit branch<CR>", { desc = "Git branches" })

-- Diffview (PR review & diffs)
map("n", "<leader>gd", "<cmd>DiffviewOpen<CR>", { desc = "Open diff view" })
map("n", "<leader>gD", "<cmd>DiffviewOpen HEAD~1<CR>", { desc = "Diff last commit" })
map("n", "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", { desc = "Current file history" })
map("n", "<leader>gH", "<cmd>DiffviewFileHistory<CR>", { desc = "Branch history" })
map("n", "<leader>gq", "<cmd>DiffviewClose<CR>", { desc = "Close diff view" })
-- PR diff view. Diff the branch against the PR's actual base (via gh, handles
-- stacked PRs), falling back to origin's default branch.
--
-- Already-merged PRs: once the branch is merged with a merge commit, HEAD is an
-- ancestor of the base, so `base...HEAD` is empty. In that case diff from the
-- base as it was right before the merge (the merge commit's first parent), so
-- reviewing a merged PR shows exactly what it landed.
map("n", "<leader>gP", function()
  local function sh(cmd)
    local out = vim.trim(vim.fn.system(cmd .. " 2>/dev/null"))
    return vim.v.shell_error == 0 and out ~= "" and out or nil
  end
  local function ok(cmd)
    vim.fn.system(cmd .. " 2>/dev/null")
    return vim.v.shell_error == 0
  end

  -- PR metadata (gh finds the PR for the current branch, merged or not)
  local pr
  local raw = sh "gh pr view --json number,state,baseRefName,mergeCommit"
  if raw then
    local dec_ok, dec = pcall(vim.json.decode, raw)
    pr = dec_ok and dec or nil
  end

  -- base branch
  local base_branch = pr and pr.baseRefName or nil
  local base = base_branch and ("origin/" .. base_branch) or nil
  if base and not sh("git rev-parse --verify --quiet " .. base) then
    vim.notify("Fetching " .. base_branch .. "…", vim.log.levels.INFO)
    sh("git fetch origin " .. base_branch)
  end
  base = base and sh("git rev-parse --verify --quiet " .. base) and base
    or sh "git symbolic-ref refs/remotes/origin/HEAD --short"
  if not base then
    for _, b in ipairs { "origin/main", "origin/master" } do
      if sh("git rev-parse --verify --quiet " .. b) then
        base = b
        break
      end
    end
  end
  if not base then
    vim.notify("Couldn't find a base branch — try `git fetch origin`", vim.log.levels.ERROR)
    return
  end

  local from = base
  local label = base
  if ok("git merge-base --is-ancestor HEAD " .. base) then
    -- branch is already inside the base (merged with a merge commit)
    local merge = pr and pr.state == "MERGED" and pr.mergeCommit and pr.mergeCommit.oid or nil
    if merge and not ok("git cat-file -e " .. merge .. "^{commit}") then
      sh("git fetch origin " .. (base_branch or ""))
    end
    if not (merge and ok("git cat-file -e " .. merge .. "^{commit}")) then
      -- no gh data: the first merge commit on the base whose history includes HEAD
      merge = sh("git rev-list --merges --ancestry-path --reverse HEAD.." .. base .. " | head -1")
    end
    if merge then
      from = merge .. "^1"
      label = "base before merge " .. merge:sub(1, 8)
    else
      vim.notify("Branch is fully merged into " .. base .. " but no merge commit found (squash/rebase?) — showing HEAD~1", vim.log.levels.WARN)
      from = "HEAD~1"
      label = from
    end
  end

  local n = tonumber(sh("git rev-list --count " .. from .. "..HEAD")) or 0
  vim.notify(string.format("PR diff: %s → HEAD (%d commit%s)%s", label, n, n == 1 and "" or "s",
    pr and pr.number and ("  #" .. pr.number .. " " .. (pr.state or "")) or ""))
  vim.cmd("DiffviewOpen " .. from .. "...HEAD")
end, { desc = "PR diff view (vs PR base, works for merged PRs)" })

-- Octo (GitHub PRs & issues — full PR review in-editor)
map("n", "<leader>op", "<cmd>Octo pr list<CR>", { desc = "Octo: list PRs" })
map("n", "<leader>oP", "<cmd>Octo pr search<CR>", { desc = "Octo: search PRs" })
map("n", "<leader>oc", "<cmd>Octo pr checkout<CR>", { desc = "Octo: checkout PR" })
map("n", "<leader>or", "<cmd>Octo review start<CR>", { desc = "Octo: start review" })
map("n", "<leader>oR", "<cmd>Octo review resume<CR>", { desc = "Octo: resume review" })
map("n", "<leader>os", "<cmd>Octo review submit<CR>", { desc = "Octo: submit review" })
map("n", "<leader>oi", "<cmd>Octo issue list<CR>", { desc = "Octo: list issues" })
map("n", "<leader>ob", "<cmd>Octo pr browser<CR>", { desc = "Octo: open PR in browser" })

-- pr.nvim (focused PR reviewer — A/B against octo)
map("n", "<leader>gr", "<cmd>PR<CR>", { desc = "PR.nvim: list/review PRs" })

-- Gitsigns (inline hunks)
map("n", "<leader>hs", "<cmd>Gitsigns stage_hunk<CR>", { desc = "Stage hunk" })
map("n", "<leader>hr", "<cmd>Gitsigns reset_hunk<CR>", { desc = "Reset hunk" })
map("n", "<leader>hS", "<cmd>Gitsigns stage_buffer<CR>", { desc = "Stage buffer" })
map("n", "<leader>hu", "<cmd>Gitsigns undo_stage_hunk<CR>", { desc = "Undo stage hunk" })
map("n", "<leader>hR", "<cmd>Gitsigns reset_buffer<CR>", { desc = "Reset buffer" })
map("n", "<leader>hp", "<cmd>Gitsigns preview_hunk<CR>", { desc = "Preview hunk" })
map("n", "<leader>hb", "<cmd>Gitsigns blame_line<CR>", { desc = "Blame line" })
map("n", "<leader>hd", "<cmd>Gitsigns diffthis<CR>", { desc = "Diff this" })
map("n", "<leader>hD", "<cmd>Gitsigns diffthis ~<CR>", { desc = "Diff this ~" })

-- Toggle the full in-buffer diff overlay: line highlights for added/changed,
-- intra-line word diff, and deleted lines shown as virtual text
map("n", "<leader>ht", function()
  local gs = require "gitsigns"
  local on = gs.toggle_linehl()
  gs.toggle_word_diff(on)
  gs.toggle_deleted(on)
end, { desc = "Toggle inline diff overlay" })

-- Cycle what the gutter signs AND the Agent Watch panel diff against:
--   merge-base with main (all branch changes) -> HEAD (staged + unstaged) -> index (unstaged only)
map("n", "<leader>hB", function()
  require("agentwatch").cycle_base()
end, { desc = "Cycle diff base (gitsigns + agentwatch)" })

-- Agent Watch: live panel of what coding agents are changing
map("n", "<leader>aw", "<cmd>AgentWatch<CR>", { desc = "Toggle Agent Watch panel" })
map("n", "<leader>aW", function()
  require("agentwatch").open()
end, { desc = "Focus Agent Watch panel" })

-- Navigation
map("n", "[h", "<cmd>Gitsigns prev_hunk<CR>", { desc = "Previous hunk" })
map("n", "]h", "<cmd>Gitsigns next_hunk<CR>", { desc = "Next hunk" })

-- Spectre (find and replace)
map("n", "<leader>sr", "<cmd>Spectre<CR>", { desc = "Open Spectre" })
map("n", "<leader>sw", "<cmd>lua require('spectre').open_visual({select_word=true})<CR>", { desc = "Search current word" })
map("v", "<leader>sw", "<esc><cmd>lua require('spectre').open_visual()<CR>", { desc = "Search current selection" })
map("n", "<leader>sp", "<cmd>lua require('spectre').open_file_search({select_word=true})<CR>", { desc = "Search in current file" })

-- TypeScript specific
map("n", "<leader>to", "<cmd>TSToolsOrganizeImports<CR>", { desc = "Organize imports" })
map("n", "<leader>ta", "<cmd>TSToolsAddMissingImports<CR>", { desc = "Add missing imports" })
map("n", "<leader>tf", "<cmd>TSToolsFixAll<CR>", { desc = "Fix all" })
map("n", "<leader>tr", "<cmd>TSToolsRemoveUnused<CR>", { desc = "Remove unused" })
map("n", "<leader>tg", "<cmd>TSToolsGoToSourceDefinition<CR>", { desc = "Go to source definition" })

-- Python specific
map("n", "<leader>pi", function()
  vim.lsp.buf.code_action { context = { only = { "source.organizeImports" } }, apply = true }
end, { desc = "Organize Python imports" })
map("n", "<leader>pt", "<cmd>lua vim.lsp.buf.type_definition()<CR>", { desc = "Type definition" })

-- Make tab more useful
map("n", "<leader><Tab>", "<C-^>", { desc = "Switch to last buffer" })

-- Tab pages (Diffview / Neogit open in their own tab). `gt` is taken by LSP
-- type definition, so use ]t / [t.
map("n", "<leader>.", "<cmd>tabnext<CR>", { desc = "Next tab" })
map("n", "<leader>,", "<cmd>tabprevious<CR>", { desc = "Previous tab" })
map("n", "<leader>tc", "<cmd>tabclose<CR>", { desc = "Close tab" })
