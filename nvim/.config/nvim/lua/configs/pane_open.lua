-- Open a file in a new terminal pane (a fresh nvim beside this one) instead of
-- an nvim split. Same keys everywhere: <C-v>/<C-x> split inside nvim,
-- <M-v>/<M-x> split the terminal pane right/down.
--   herdr ($HERDR_PANE_ID) → herdr pane split; you're back at a shell after :q
--   tmux  ($TMUX)          → tmux split-window; the pane closes with nvim
--   neither                → plain nvim vsplit/split, so the keys never dead-end
local M = {}

local function notify_err(what, res)
  vim.schedule(function()
    vim.notify(what .. " failed: " .. vim.trim(res.stderr ~= "" and res.stderr or (res.stdout or "")), vim.log.levels.ERROR)
  end)
end

local function herdr(cmd, direction)
  local split = { "herdr", "pane", "split", vim.env.HERDR_PANE_ID, "--direction", direction, "--focus", "--cwd", vim.fn.getcwd() }
  vim.system(split, { text = true }, function(res)
    local ok, data = pcall(vim.json.decode, res.stdout or "")
    local pane = ok and type(data) == "table" and data.result and data.result.pane
    if res.code ~= 0 or not pane then
      return notify_err("herdr split", res)
    end
    vim.system { "herdr", "pane", "run", pane.pane_id, cmd }
  end)
end

local function tmux(cmd, direction)
  local split = { "tmux", "split-window", direction == "right" and "-h" or "-v", "-c", vim.fn.getcwd() }
  if vim.env.TMUX_PANE then
    vim.list_extend(split, { "-t", vim.env.TMUX_PANE })
  end
  table.insert(split, cmd)
  vim.system(split, { text = true }, function(res)
    if res.code ~= 0 then
      notify_err("tmux split", res)
    end
  end)
end

-- direction: "right" | "down"
function M.open(path, line, direction)
  if not path or path == "" then
    return
  end
  path = vim.fn.fnamemodify(path, ":p")
  local cmd = "nvim " .. (line and ("+" .. line .. " ") or "") .. vim.fn.shellescape(path)

  if vim.env.HERDR_PANE_ID and vim.fn.executable "herdr" == 1 then
    herdr(cmd, direction)
  elseif vim.env.TMUX then
    tmux(cmd, direction)
  else
    vim.cmd((direction == "right" and "vsplit " or "split ") .. vim.fn.fnameescape(path))
    if line then
      pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
    end
  end
end

-- The file + line under the cursor in the current buffer
function M.current(direction)
  M.open(vim.api.nvim_buf_get_name(0), vim.api.nvim_win_get_cursor(0)[1], direction)
end

-- nvim-tree: the node under the cursor (files only)
function M.tree(direction)
  return function()
    local node = require("nvim-tree.api").tree.get_node_under_cursor()
    if node and node.type == "file" then
      M.open(node.absolute_path, nil, direction)
    end
  end
end

-- Telescope: the selected entry (find_files, live_grep, oldfiles, lsp pickers…)
function M.telescope(direction)
  return function(prompt_bufnr)
    local entry = require("telescope.actions.state").get_selected_entry()
    require("telescope.actions").close(prompt_bufnr)
    if not entry then
      return
    end
    local path = entry.path or entry.filename or (type(entry.value) == "string" and entry.value) or nil
    M.open(path, entry.lnum, direction)
  end
end

return M
