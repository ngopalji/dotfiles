-- LSP navigation from inside Diffview.
--
-- Diffview's diff buffers are `diffview://` snapshots of a git revision, so no
-- language server attaches to them and gd / gr / hover have nowhere to go.
-- This proxies them through the working-tree file:
--
--   gd  — open the same file at the same line in your editor tab and run the
--         real go-to-definition there. <C-o> from the landing spot brings you
--         straight back to the diff, cursor where you left it.
--   gr  — same, but Telescope references.
--   gh  — hover, shown in place over the diff (no tab switch).
--
-- Line numbers are taken from the diff buffer as-is, which is exact when the
-- working tree matches the revision you're viewing (the normal case when
-- reviewing your own branch), and close enough otherwise.

local M = {}
local api, fn = vim.api, vim.fn

-- absolute working-tree path of the file under the cursor in the current view
local function current_file()
  local ok, lib = pcall(require, "diffview.lib")
  if not ok then
    return nil
  end
  local view = lib.get_current_view()
  local entry = view and view.cur_entry
  if not entry or not view.adapter then
    return nil
  end
  local top = view.adapter.ctx.toplevel
  return top .. "/" .. entry.path, view
end

-- load the working-tree buffer (LSP attaches on load) and call fn once a client is there
local function with_lsp(bufnr, cb, timeout_ms)
  if #vim.lsp.get_clients { bufnr = bufnr } > 0 then
    return cb()
  end
  local done = false
  local id
  id = api.nvim_create_autocmd("LspAttach", {
    callback = function(a)
      if a.buf == bufnr and not done then
        done = true
        vim.schedule(cb)
        return true
      end
    end,
  })
  vim.defer_fn(function()
    if not done then
      done = true
      pcall(api.nvim_del_autocmd, id)
      vim.notify("diffview: no language server attached to " .. fn.fnamemodify(api.nvim_buf_get_name(bufnr), ":t"), vim.log.levels.WARN)
    end
  end, timeout_ms or 4000)
end

-- a plain file window in `tab`, or a new split there
local function editor_window(tab)
  local function plain(w)
    local b = api.nvim_win_get_buf(w)
    return vim.bo[b].buftype == "" and api.nvim_win_get_config(w).relative == "" and not vim.wo[w].diff
  end
  local cur = api.nvim_tabpage_get_win(tab)
  if plain(cur) then
    return cur
  end
  for _, w in ipairs(api.nvim_tabpage_list_wins(tab)) do
    if plain(w) then
      return w
    end
  end
  api.nvim_set_current_tabpage(tab)
  vim.cmd "aboveleft vsplit"
  return api.nvim_get_current_win()
end

-- Jump into the editor tab at the diff cursor's file/line, remember where we
-- came from, then run `action` in that window.
local function to_editor(action)
  local file = current_file()
  if not file then
    return vim.notify("diffview: no file under cursor", vim.log.levels.WARN)
  end
  local pos = api.nvim_win_get_cursor(0)
  local origin = { tab = api.nvim_get_current_tabpage(), win = api.nvim_get_current_win(), pos = pos }

  local lib = require "diffview.lib"
  local tab = lib.get_prev_non_view_tabpage()
  if not tab then
    vim.cmd "tabnew"
    tab = api.nvim_get_current_tabpage()
  end
  local win = editor_window(tab)
  api.nvim_set_current_tabpage(tab)
  api.nvim_set_current_win(win)
  vim.cmd("keepjumps edit " .. fn.fnameescape(file))
  local last = api.nvim_buf_line_count(0)
  pcall(api.nvim_win_set_cursor, 0, { math.min(pos[1], last), pos[2] })

  local bufnr = api.nvim_get_current_buf()
  with_lsp(bufnr, function()
    action(origin)
  end)
end

-- mark the current window position as "press <C-o> here to return to the diff"
local function set_return(origin)
  vim.w.diffview_return = {
    tab = origin.tab,
    win = origin.win,
    pos = origin.pos,
    landing = { buf = api.nvim_get_current_buf(), line = api.nvim_win_get_cursor(0)[1] },
  }
end

function M.definition()
  to_editor(function(origin)
    vim.lsp.buf.definition {
      on_list = function(opts)
        local items = opts.items or {}
        if #items == 0 then
          return vim.notify("no definition found", vim.log.levels.INFO)
        end
        local it = items[1]
        if it.filename and fn.fnamemodify(it.filename, ":p") ~= api.nvim_buf_get_name(0) then
          vim.cmd("keepjumps edit " .. fn.fnameescape(it.filename))
        end
        pcall(api.nvim_win_set_cursor, 0, { it.lnum, math.max(0, (it.col or 1) - 1) })
        vim.cmd "normal! zz"
        set_return(origin)
        if #items > 1 then
          vim.notify(#items .. " definitions — showing the first", vim.log.levels.INFO)
        end
      end,
    }
  end)
end

function M.references()
  to_editor(function(origin)
    set_return(origin)
    vim.cmd "Telescope lsp_references"
  end)
end

-- hover in place: ask the working-tree buffer's server about the diff cursor position
function M.hover()
  local file = current_file()
  if not file then
    return
  end
  local pos = api.nvim_win_get_cursor(0)
  local bufnr = fn.bufadd(file)
  fn.bufload(bufnr)
  with_lsp(bufnr, function()
    local params = {
      textDocument = { uri = vim.uri_from_bufnr(bufnr) },
      position = { line = pos[1] - 1, character = pos[2] },
    }
    vim.lsp.buf_request(bufnr, "textDocument/hover", params, function(err, result)
      if err or not result or not result.contents then
        return vim.notify("no hover info", vim.log.levels.INFO)
      end
      local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
      if vim.tbl_isempty(lines) then
        return
      end
      vim.lsp.util.open_floating_preview(lines, "markdown", { border = "rounded", focusable = true })
    end)
  end)
end

-- <C-o>: at the spot we landed from a diff, go back to the diff instead
function M.jump_back()
  local r = vim.w.diffview_return
  if r then
    local at_landing = r.landing.buf == api.nvim_get_current_buf() and r.landing.line == api.nvim_win_get_cursor(0)[1]
    if at_landing then
      vim.w.diffview_return = nil
      if api.nvim_tabpage_is_valid(r.tab) then
        api.nvim_set_current_tabpage(r.tab)
        if api.nvim_win_is_valid(r.win) then
          api.nvim_set_current_win(r.win)
          pcall(api.nvim_win_set_cursor, r.win, r.pos)
        end
        return
      end
    end
  end
  -- normal <C-o>
  vim.cmd "normal! \15"
end

-- called from diffview's diff_buf_win_enter hook
function M.attach(bufnr)
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = bufnr, nowait = true, silent = true, desc = desc })
  end
  map("gd", M.definition, "Go to definition (in editor tab)")
  map("gr", M.references, "References (in editor tab)")
  map("gh", M.hover, "Hover (from working tree)")
end

function M.setup()
  vim.keymap.set("n", "<C-o>", M.jump_back, { desc = "Jump back (returns to Diffview after gd from a diff)" })
end

return M
