-- agentwatch — live view of what coding agents are changing in the repo.
--
-- A right-hand panel with three sections:
--   ACTIVITY  — feed of files as they change (● = seconds ago), seeded from
--               file mtimes on startup so it's never empty
--   CHANGES   — files changed vs. the base, newest first, expandable into
--               hunk rows (line range + size bar + counts)
--   COMMITS   — commits on this branch since the base
--
-- While the panel is open, file buffers get the full diff overlay from
-- gitsigns (line wash + word diff + deleted lines as virtual text). Closing
-- the panel puts the gutter back to plain signs.
--
-- Base modes (`b` in the panel, or <leader>hB anywhere):
--   branch — merge-base with main/master: everything this branch has done (default)
--   head   — HEAD: staged + unstaged
--   index  — working tree vs index: unstaged only
-- Gitsigns is kept in sync so the gutter marks match the panel.

local M = {}
local api, uv, fn = vim.api, vim.uv, vim.fn

local ns = api.nvim_create_namespace "agentwatch"
local flash_ns = api.nvim_create_namespace "agentwatch_flash"

M.config = {
  width = 48,
  poll_open_ms = 1500, -- refresh interval while the panel is visible
  poll_closed_ms = 8000, -- refresh interval while hidden (keeps the feed alive)
  hot_seconds = 45, -- changes newer than this glow
  warm_seconds = 300, -- ... and these are still highlighted
  recent_minutes = 30, -- files older than this collapse into an "older" group
  max_activity = 60,
  activity_rows = 14, -- rows shown in the feed
  max_commits = 12,
  base_branches = { "origin/main", "origin/master", "main", "master" },
  default_base = "branch",
  sync_gitsigns = true,
  overlay = true, -- full diff overlay in file buffers while the panel is open
  seed_activity = true, -- prefill the feed from file mtimes on first poll
}

local S = {
  buf = nil,
  win = nil,
  prev_win = nil,
  root = nil,
  base_mode = nil,
  base_rev = nil,
  base_label = "",
  files = {},
  commits = {},
  activity = {},
  snapshot = nil, -- path -> signature (nil until first poll finishes)
  commit_seen = nil,
  expanded = {}, -- path -> true (files are collapsed by default)
  show_older = false,
  rows = {}, -- lnum -> entry
  timer = nil,
  busy = false,
  preview_win = nil,
  overlay_on = false,
  error = nil,
}

---------------------------------------------------------------------------
-- highlights
---------------------------------------------------------------------------

local function palette()
  local ok, b46 = pcall(require, "base46")
  local c = ok and b46.get_theme_tb "base_30" or {}
  return {
    bg = c.darker_black or "#2d2d2d",
    bg2 = c.one_bg2 or "#3a3a3a",
    line = c.one_bg3 or "#424242",
    fg = c.white or "#e2e2df",
    dim = c.grey_fg2 or "#626262",
    dim2 = c.light_grey or "#767676",
    green = c.green or "#97c05c",
    vgreen = c.vibrant_green or "#b2d47e",
    red = c.red or "#e2726e",
    blue = c.blue or "#7aa5e8",
    yellow = c.yellow or "#e3c078",
    purple = c.purple or "#b98fdd",
    teal = c.teal or "#6fbfae",
    orange = c.orange or "#e39a5f",
  }
end

local function set_highlights()
  local p = palette()
  local hl = function(name, v)
    api.nvim_set_hl(0, name, v)
  end
  hl("AgentWatchNormal", { bg = p.bg, fg = p.fg })
  hl("AgentWatchCursorLine", { bg = p.bg2 })
  hl("AgentWatchTitle", { fg = p.blue, bold = true })
  hl("AgentWatchTitleRule", { fg = p.blue })
  hl("AgentWatchBase", { fg = p.dim2, italic = true })
  hl("AgentWatchSection", { fg = p.teal, bold = true })
  hl("AgentWatchRule", { fg = p.line })
  hl("AgentWatchFile", { fg = p.fg, bold = true })
  hl("AgentWatchDir", { fg = p.dim2 })
  hl("AgentWatchAdd", { fg = p.green, bold = true })
  hl("AgentWatchDel", { fg = p.red, bold = true })
  hl("AgentWatchChange", { fg = p.blue, bold = true })
  hl("AgentWatchBarAdd", { fg = p.green })
  hl("AgentWatchBarDel", { fg = p.red })
  hl("AgentWatchNew", { fg = p.vgreen, bold = true })
  hl("AgentWatchHot", { fg = p.vgreen, bold = true })
  hl("AgentWatchWarm", { fg = p.yellow })
  hl("AgentWatchDim", { fg = p.dim })
  hl("AgentWatchLnum", { fg = p.dim2 })
  hl("AgentWatchText", { fg = p.fg })
  hl("AgentWatchHash", { fg = p.purple })
  hl("AgentWatchFold", { fg = p.dim2 })
  hl("AgentWatchFlash", { bg = "#2e4a73" })
end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

local function rel_time(ts)
  local d = math.max(0, os.time() - (ts or 0))
  if d < 60 then
    return d .. "s"
  elseif d < 3600 then
    return math.floor(d / 60) .. "m"
  elseif d < 86400 then
    return math.floor(d / 3600) .. "h"
  end
  return math.floor(d / 86400) .. "d"
end

local function age_hl(ts)
  local d = os.time() - (ts or 0)
  if d < M.config.hot_seconds then
    return "AgentWatchHot"
  elseif d < M.config.warm_seconds then
    return "AgentWatchWarm"
  end
  return "AgentWatchDim"
end

local function is_hot(ts)
  return os.time() - (ts or 0) < M.config.hot_seconds
end

local function split_path(path)
  local dir, name = path:match "^(.*/)([^/]+)$"
  if not dir then
    return "", path
  end
  return dir, name
end

local dw = fn.strdisplaywidth

local function truncate(s, max)
  if max <= 0 then
    return ""
  end
  if dw(s) <= max then
    return s
  end
  return fn.strcharpart(s, 0, math.max(0, max - 1)) .. "…"
end

local function run(cmd, cb)
  vim.system(cmd, { cwd = S.root or uv.cwd(), text = true }, function(out)
    vim.schedule(function()
      cb(out)
    end)
  end)
end

local function panel_open()
  return S.win and api.nvim_win_is_valid(S.win)
end

local function first_lines(path, upto)
  local bufnr = fn.bufnr(path)
  if bufnr > 0 and api.nvim_buf_is_loaded(bufnr) then
    return api.nvim_buf_get_lines(bufnr, 0, upto, false)
  end
  local ok, lines = pcall(fn.readfile, S.root .. "/" .. path, "", upto)
  return ok and lines or {}
end

---------------------------------------------------------------------------
-- git polling
---------------------------------------------------------------------------

local function resolve_base(cb)
  local mode = S.base_mode
  if mode == "index" then
    return cb(nil, "index")
  elseif mode == "head" then
    return cb("HEAD", "HEAD")
  end
  run({ "git", "symbolic-ref", "--short", "refs/remotes/origin/HEAD" }, function(o)
    local candidates = {}
    if o.code == 0 and vim.trim(o.stdout) ~= "" then
      table.insert(candidates, vim.trim(o.stdout))
    end
    vim.list_extend(candidates, M.config.base_branches)
    local i = 0
    local function try_next()
      i = i + 1
      local b = candidates[i]
      if not b then
        return cb("HEAD", "HEAD")
      end
      run({ "git", "merge-base", b, "HEAD" }, function(mb)
        if mb.code == 0 and vim.trim(mb.stdout) ~= "" then
          cb(vim.trim(mb.stdout), b)
        else
          try_next()
        end
      end)
    end
    try_next()
  end)
end

-- Parse `git diff -U0` output into file entries with hunks.
local function parse_diff(text)
  local files, order = {}, {}
  local cur, hunk
  for line in (text .. "\n"):gmatch "(.-)\n" do
    local a, b = line:match "^diff %-%-git a/(.-) b/(.*)$"
    if a then
      cur = { path = b, old_path = a ~= b and a or nil, status = "modified", added = 0, deleted = 0, hunks = {}, body = {} }
      files[b] = cur
      table.insert(order, b)
      hunk = nil
    elseif cur then
      if line:match "^new file mode" then
        cur.status = "new"
      elseif line:match "^deleted file mode" then
        cur.status = "deleted"
      elseif line:match "^rename from" then
        cur.status = "renamed"
      elseif line:match "^Binary files" then
        cur.binary = true
      else
        local os_, oc, ns_, nc = line:match "^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@"
        if os_ then
          oc = oc == "" and 1 or tonumber(oc)
          nc = nc == "" and 1 or tonumber(nc)
          hunk = {
            old_start = tonumber(os_),
            old_count = oc,
            new_start = tonumber(ns_),
            new_count = nc,
            added = 0,
            deleted = 0,
            kind = nc == 0 and "delete" or (oc == 0 and "add" or "change"),
          }
          hunk.line = nc == 0 and math.max(1, hunk.new_start) or hunk.new_start
          table.insert(cur.hunks, hunk)
        elseif hunk then
          local c = line:sub(1, 1)
          if c == "+" then
            hunk.added = hunk.added + 1
            cur.added = cur.added + 1
            table.insert(cur.body, line)
          elseif c == "-" then
            hunk.deleted = hunk.deleted + 1
            cur.deleted = cur.deleted + 1
            table.insert(cur.body, line)
          end
        end
      end
    end
  end
  return files, order
end

local function parse_status(text)
  local untracked = {}
  local toks = vim.split(text, "\0", { plain = true })
  local i = 1
  while i <= #toks do
    local t = toks[i]
    if t ~= "" then
      local xy, path = t:sub(1, 2), t:sub(4)
      if xy == "??" then
        table.insert(untracked, path)
      end
      if xy:sub(1, 1) == "R" or xy:sub(1, 1) == "C" then
        i = i + 1
      end
    end
    i = i + 1
  end
  return untracked
end

local function count_lines(path)
  local st = uv.fs_stat(S.root .. "/" .. path)
  if not st or st.type ~= "file" or st.size > 4 * 1024 * 1024 then
    return 0
  end
  local f = io.open(S.root .. "/" .. path, "rb")
  if not f then
    return 0
  end
  local data = f:read "*a"
  f:close()
  local _, n = data:gsub("\n", "")
  if #data > 0 and data:sub(-1) ~= "\n" then
    n = n + 1
  end
  return n
end

local function parse_log(text)
  local commits = {}
  for line in (text .. "\n"):gmatch "(.-)\n" do
    local parts = vim.split(line, "\0", { plain = true })
    if #parts >= 3 and parts[1]:match "^%x+$" and tonumber(parts[2]) then
      table.insert(commits, { hash = parts[1], time = tonumber(parts[2]), subject = table.concat(parts, "\0", 3) })
    end
  end
  return commits
end

-- What counts as "the file changed": hunk layout AND the changed text itself,
-- so an edit inside an already-changed line (same ranges, same counts) is
-- still an event. Untracked files have no diff body; use mtime + size.
local function signature(f)
  local parts = { f.status, f.added, f.deleted }
  for _, h in ipairs(f.hunks) do
    table.insert(parts, h.old_start .. "," .. h.old_count .. "+" .. h.new_start .. "," .. h.new_count)
  end
  if f.body and #f.body > 0 then
    table.insert(parts, fn.sha256(table.concat(f.body, "\n")))
  elseif f.untracked then
    local st = uv.fs_stat(S.root .. "/" .. f.path)
    table.insert(parts, st and (st.mtime.sec .. "." .. st.mtime.nsec .. "/" .. st.size) or "?")
  end
  return table.concat(parts, ":")
end

-- The feed is an append-only timeline of what the agent did. The only merge:
-- repeated edits to the same file fold into one row while that row is still
-- the file's latest event and no commit has landed since — so a file being
-- hammered on updates in place, and a commit "closes" the run. Edits after
-- the commit start a fresh row; nothing is ever rewritten by later events.
local function push_activity(ev)
  ev.time = ev.time or os.time()
  if ev.path then
    for i, old in ipairs(S.activity) do
      if old.kind == "commit" then
        break -- a commit sits between: don't merge across it
      end
      if old.path == ev.path then
        if old.kind == ev.kind then
          old.time, old.added, old.deleted, old.hunk = ev.time, ev.added, ev.deleted, ev.hunk
          table.remove(S.activity, i)
          table.insert(S.activity, 1, old)
          return
        end
        break
      end
    end
  end
  table.insert(S.activity, 1, ev)
  table.sort(S.activity, function(a, b)
    return a.time > b.time
  end)
  while #S.activity > M.config.max_activity do
    table.remove(S.activity)
  end
end

local function finish(results)
  S.busy = false
  local diff_out, status_out, log_out = results.diff, results.status, results.log

  -- A failed command (typically index.lock while the agent runs git add/commit)
  -- must not be read as "everything vanished": keep the previous state.
  if diff_out.code ~= 0 and diff_out.code ~= 1 then
    S.error = vim.trim(diff_out.stderr ~= "" and diff_out.stderr or "git diff failed")
    M.render()
    return
  end
  if status_out.code ~= 0 then
    S.error = vim.trim(status_out.stderr ~= "" and status_out.stderr or "git status failed")
    M.render()
    return
  end
  S.error = nil

  local files, order = parse_diff(diff_out.stdout or "")

  for _, path in ipairs(parse_status(status_out.stdout or "")) do
    if not files[path] then
      local n = count_lines(path)
      files[path] = {
        path = path,
        status = "new",
        untracked = true,
        added = n,
        deleted = 0,
        hunks = { { kind = "add", line = 1, new_start = 1, new_count = n, old_start = 0, old_count = 0, added = n, deleted = 0 } },
      }
      table.insert(order, path)
    end
  end

  for _, f in pairs(files) do
    local st = uv.fs_stat(S.root .. "/" .. f.path)
    f.mtime = st and st.mtime.sec or 0
  end

  local commits = parse_log(log_out and log_out.stdout or "")

  local snap = {}
  for path, f in pairs(files) do
    snap[path] = signature(f)
  end
  if S.snapshot then
    for path, sig in pairs(snap) do
      if S.snapshot[path] ~= sig then
        local f = files[path]
        push_activity {
          kind = f.status == "new" and "new" or (f.status == "deleted" and "deleted" or "modified"),
          path = path,
          added = f.added,
          deleted = f.deleted,
          hunk = f.hunks[1],
        }
      end
    end
    -- files leaving the diff (a commit, a revert, staging in index mode) are
    -- not events: the feed records what the agent did, not bookkeeping states
  elseif M.config.seed_activity then
    -- first poll: backfill the feed from mtimes so it's not empty on open
    local cutoff = os.time() - M.config.recent_minutes * 60
    for path, f in pairs(files) do
      if f.mtime >= cutoff then
        push_activity {
          kind = f.status == "new" and "new" or (f.status == "deleted" and "deleted" or "modified"),
          path = path,
          added = f.added,
          deleted = f.deleted,
          hunk = f.hunks[1],
          time = f.mtime,
          seeded = true,
        }
      end
    end
  end
  S.snapshot = snap

  local seen = {}
  for _, c in ipairs(commits) do
    seen[c.hash] = true
    if S.commit_seen and not S.commit_seen[c.hash] then
      push_activity { kind = "commit", hash = c.hash, subject = c.subject, time = c.time }
    end
  end
  S.commit_seen = seen
  S.commits = commits

  local list = {}
  for _, path in ipairs(order) do
    table.insert(list, files[path])
  end
  table.sort(list, function(a, b)
    if a.mtime ~= b.mtime then
      return a.mtime > b.mtime
    end
    return a.path < b.path
  end)
  S.files = list

  M.render()
end

function M.refresh()
  if S.busy or not S.root then
    return
  end
  S.busy = true
  S.last_poll = uv.now()
  resolve_base(function(rev, label)
    S.base_rev, S.base_label = rev, label
    local results, pending = {}, 3
    local function done(k, o)
      results[k] = o
      pending = pending - 1
      if pending == 0 then
        finish(results)
      end
    end
    local diff_cmd = { "git", "diff", "-U0", "--no-color", "--no-ext-diff", "-M" }
    if rev then
      table.insert(diff_cmd, rev)
    end
    run(diff_cmd, function(o)
      done("diff", o)
    end)
    run({ "git", "status", "--porcelain", "-z", "--untracked-files=all" }, function(o)
      done("status", o)
    end)
    local log_cmd = { "git", "log", "--format=%h%x00%ct%x00%s", "-n", tostring(M.config.max_commits) }
    if S.base_mode == "branch" and rev and rev ~= "HEAD" then
      table.insert(log_cmd, rev .. "..HEAD")
    end
    run(log_cmd, function(o)
      done("log", o)
    end)
  end)
end

---------------------------------------------------------------------------
-- gitsigns integration: base sync + diff overlay
---------------------------------------------------------------------------

local function gitsigns()
  local ok, gs = pcall(require, "gitsigns")
  return ok and gs or nil
end

local function sync_gitsigns()
  local gs = M.config.sync_gitsigns and gitsigns()
  if not gs then
    return
  end
  if S.base_mode == "index" then
    gs.change_base(nil, true)
  elseif S.base_mode == "head" then
    gs.change_base("HEAD", true)
  else
    resolve_base(function(rev)
      gs.change_base(rev ~= "HEAD" and rev or nil, true)
    end)
  end
end

-- Full diff overlay in file buffers: line wash + word diff + deleted lines.
local function set_overlay(on)
  if not M.config.overlay or S.overlay_on == on then
    return
  end
  local gs = gitsigns()
  if not gs then
    return
  end
  S.overlay_on = on
  gs.toggle_linehl(on)
  gs.toggle_word_diff(on)
  gs.toggle_deleted(on)
end

local base_order = { "branch", "head", "index" }
local base_names = {
  head = "HEAD (staged + unstaged)",
  branch = "merge-base with main (all branch changes)",
  index = "index (unstaged only)",
}

function M.set_base(mode)
  S.base_mode = mode
  S.snapshot = nil
  S.commit_seen = nil
  S.show_older = false
  sync_gitsigns()
  M.refresh()
end

function M.cycle_base()
  local idx = 1
  for i, m in ipairs(base_order) do
    if m == S.base_mode then
      idx = i
    end
  end
  local mode = base_order[idx % #base_order + 1]
  M.set_base(mode)
  vim.notify("agentwatch base: " .. base_names[mode])
end

---------------------------------------------------------------------------
-- rendering
---------------------------------------------------------------------------

local Line = {}
Line.__index = Line
local function L()
  return setmetatable({ text = "", hls = {} }, Line)
end
function Line:add(s, hl)
  if s == nil or s == "" then
    return self
  end
  local start = #self.text
  self.text = self.text .. s
  if hl then
    table.insert(self.hls, { start, #self.text, hl })
  end
  return self
end
function Line:width()
  return dw(self.text)
end
-- append another Line directly (keeps its highlight spans)
function Line:append(other)
  local off = #self.text
  for _, h in ipairs(other.hls) do
    table.insert(self.hls, { h[1] + off, h[2] + off, h[3] })
  end
  self.text = self.text .. other.text
  return self
end
-- append another Line right-aligned to `width`
function Line:right(other, width)
  local gap = width - self:width() - other:width()
  self:add(string.rep(" ", math.max(1, gap)))
  return self:append(other)
end

local function counts(added, deleted)
  local l = L()
  if added and added > 0 then
    l:add("+" .. added, "AgentWatchAdd")
  end
  if deleted and deleted > 0 then
    l:add(l.text ~= "" and " " or ""):add("−" .. deleted, "AgentWatchDel")
  end
  return l
end

-- proportional size bar: ▮▮▮▮▮▮▮▮ (green = added, red = deleted), log scale
local function size_bar(added, deleted, cells)
  local total = added + deleted
  local l = L()
  if total == 0 then
    return l:add(string.rep(" ", cells))
  end
  local n = math.min(cells, math.max(1, math.ceil(math.log(total + 1) / math.log(2))))
  local g = math.floor(n * added / total + 0.5)
  if added > 0 and g == 0 then
    g = 1
  end
  if deleted > 0 and g == n then
    g = n - 1
  end
  l:add(string.rep(" ", cells - n))
  l:add(string.rep("▮", g), "AgentWatchBarAdd")
  l:add(string.rep("▮", n - g), "AgentWatchBarDel")
  return l
end

local function fit_path(dir, name, room)
  if dw(dir .. name) <= room then
    return dir, name
  end
  local dir_room = room - dw(name) - 1
  if dir_room >= 4 then
    return "…" .. fn.strcharpart(dir, fn.strchars(dir) - (dir_room - 1)), name
  end
  return "", truncate(name, room)
end

local function hunk_glyph(h)
  if h.kind == "add" then
    return "┃", "AgentWatchAdd"
  elseif h.kind == "delete" then
    return "▁", "AgentWatchDel"
  end
  return "┃", "AgentWatchChange"
end

local function hunk_range(h)
  if h.kind == "delete" then
    return "at " .. h.line
  elseif h.new_count <= 1 then
    return tostring(h.new_start)
  end
  return h.new_start .. "–" .. (h.new_start + h.new_count - 1)
end

local IND = " " -- left margin
local BADGES = {
  modified = { "edit", "AgentWatchChange" },
  new = { "new", "AgentWatchNew" },
  deleted = { "del", "AgentWatchDel" },
  commit = { "commit", "AgentWatchHash" },
}
local PULSE = 6 -- cells in the poll progress bar

-- footer: ▪▪▪▪▫▫ fills up until the next poll, then resets
local function footer_line(inner)
  local l = L():add(IND)
  local interval = panel_open() and M.config.poll_open_ms or M.config.poll_closed_ms
  local elapsed = S.last_poll and (uv.now() - S.last_poll) or 0
  local filled = math.min(PULSE, math.floor(elapsed / interval * PULSE + 0.5))
  for i = 1, PULSE do
    local on = i <= filled
    l:add(on and "▪" or "▫", S.busy and "AgentWatchWarm" or (on and "AgentWatchHot" or "AgentWatchDim"))
  end
  l:add(S.busy and "  syncing" or "  live", "AgentWatchDim")
  l:right(L():add("↵ jump   p peek   d diff   ? keys", "AgentWatchDim"), inner)
  return l
end

function M.render()
  if not (S.buf and api.nvim_buf_is_valid(S.buf)) then
    return
  end
  local W = panel_open() and api.nvim_win_get_width(S.win) or M.config.width
  local inner = W - 1 -- content width incl. margin, leaving right breathing room
  local lines, rows = {}, {}
  local function emit(l, entry)
    table.insert(lines, l)
    rows[#lines] = entry
  end
  local function blank()
    if #lines > 0 and lines[#lines].text == "" then
      return -- never stack two blank rows
    end
    emit(L(), nil)
  end
  local function section(title, meta)
    local l = L():add(IND):add(title, "AgentWatchSection")
    if meta and meta.text ~= "" then
      l:right(meta, inner)
    end
    emit(l, nil)
    emit(L():add(IND):add(string.rep("─", inner - 1), "AgentWatchRule"), nil)
  end

  -- header ---------------------------------------------------------------
  blank()
  local hdr = L():add(IND):add("󰄛  AGENT WATCH", "AgentWatchTitle")
  hdr:right(L():add("vs " .. (S.base_label or ""), "AgentWatchBase"), inner)
  emit(hdr, nil)
  emit(L():add(IND):add(string.rep("━", inner - 1), "AgentWatchTitleRule"), nil)

  if not S.root then
    blank()
    emit(L():add(IND):add("not inside a git repository", "AgentWatchDim"), nil)
  elseif S.error then
    blank()
    emit(L():add(IND):add(S.error, "AgentWatchDel"), nil)
  end

  -- activity ---------------------------------------------------------------
  -- basenames that appear under more than one path get their parent dir shown
  -- (Next.js: page.tsx everywhere)
  local by_name = {}
  for _, ev in ipairs(S.activity) do
    if ev.path then
      local _, nm = split_path(ev.path)
      by_name[nm] = by_name[nm] or {}
      by_name[nm][ev.path] = true
    end
  end
  local function display_name(path)
    local dir, nm = split_path(path)
    if vim.tbl_count(by_name[nm] or {}) <= 1 or dir == "" then
      return nm
    end
    local parent = dir:match "([^/]+)/$" or ""
    return parent .. "/" .. nm
  end

  blank()
  section("ACTIVITY", L():add(#S.activity == 0 and "quiet" or (#S.activity .. " recent"), "AgentWatchDim"))
  if #S.activity == 0 then
    emit(L():add(IND):add("  waiting for changes…", "AgentWatchDim"), nil)
  end
  for i, ev in ipairs(S.activity) do
    if i > M.config.activity_rows then
      break
    end
    local ahl = age_hl(ev.time)
    local l = L():add(IND)
    l:add(is_hot(ev.time) and "●" or "·", ahl):add("  ")
    l:add(string.format("%-4s", rel_time(ev.time)), ahl):add("  ")
    -- badge: what kind of event this is
    local b = BADGES[ev.kind] or { "?", "AgentWatchDim" }
    local badge, bhl = b[1], b[2]
    l:add(string.format("%-6s", badge), bhl):add("  ")
    if ev.kind == "commit" then
      local right = L():add(ev.hash, "AgentWatchHash")
      local room = inner - l:width() - right:width() - 2
      l:add(truncate(ev.subject, room), "AgentWatchText")
      l:right(right, inner)
    else
      local right = counts(ev.added or 0, ev.deleted or 0)
      local name = display_name(ev.path)
      local label_hl = ev.kind == "new" and "AgentWatchNew" or (ev.kind == "deleted" and "AgentWatchDel" or "AgentWatchText")
      local room = inner - l:width() - right:width() - 2
      l:add(truncate(name, room), label_hl)
      l:right(right, inner)
    end
    emit(l, { type = "activity", ev = ev })
  end

  -- changes ----------------------------------------------------------------
  local cutoff = os.time() - M.config.recent_minutes * 60
  local recent, older = {}, {}
  for _, f in ipairs(S.files) do
    table.insert(f.mtime >= cutoff and recent or older, f)
  end
  local ta, td = 0, 0
  for _, f in ipairs(S.files) do
    ta, td = ta + f.added, td + f.deleted
  end
  blank()
  local meta = L()
  if #S.files == 0 then
    meta:add("clean", "AgentWatchDim")
  else
    meta:add(#S.files .. (#S.files == 1 and " file" or " files"), "AgentWatchDim"):add("  "):append(counts(ta, td))
  end
  section("CHANGES", meta)

  local function file_rows(f)
    local expanded = S.expanded[f.path]
    local l = L():add(IND)
    l:add(expanded and "▾" or "▸", is_hot(f.mtime) and "AgentWatchHot" or "AgentWatchFold"):add("  ")
    local right = L()
    if f.status == "new" then
      right:add("new", "AgentWatchNew"):add("  ")
    elseif f.status == "deleted" then
      right:add("deleted", "AgentWatchDel"):add("  ")
    elseif f.status == "renamed" then
      right:add("renamed", "AgentWatchChange"):add("  ")
    end
    if f.binary then
      right:add("binary", "AgentWatchDim")
    else
      right:append(counts(f.added, f.deleted))
    end
    right:add("  "):add(string.format("%3s", f.mtime > 0 and rel_time(f.mtime) or ""), age_hl(f.mtime))
    local dir, name = split_path(f.path)
    local room = inner - l:width() - right:width() - 2
    dir, name = fit_path(dir, name, room)
    l:add(dir, "AgentWatchDir"):add(name, "AgentWatchFile")
    l:right(right, inner)
    emit(l, { type = "file", file = f })

    if expanded and not f.binary then
      for _, h in ipairs(f.hunks) do
        local glyph, ghl = hunk_glyph(h)
        local hl = L():add(IND):add("   "):add(glyph, ghl):add("  ")
        hl:add(hunk_range(h), "AgentWatchLnum")
        local r = size_bar(h.added, h.deleted, 8):add("  "):append(counts(h.added, h.deleted))
        hl:right(r, inner)
        emit(hl, { type = "hunk", file = f, hunk = h })
      end
      blank()
    end
  end

  for _, f in ipairs(recent) do
    file_rows(f)
  end
  if #older > 0 then
    local l = L():add(IND)
    l:add(S.show_older and "▾" or "▸", "AgentWatchFold"):add("  ")
    l:add(string.format("%d older file%s", #older, #older == 1 and "" or "s"), "AgentWatchDim")
    l:right(L():add("> " .. M.config.recent_minutes .. "m", "AgentWatchDim"), inner)
    emit(l, { type = "older" })
    if S.show_older then
      for _, f in ipairs(older) do
        file_rows(f)
      end
    end
  end

  -- commits ----------------------------------------------------------------
  if #S.commits > 0 then
    blank()
    local cmeta = S.base_mode == "branch" and S.base_rev ~= "HEAD" and (#S.commits .. " ahead of " .. S.base_label) or "recent"
    section("COMMITS", L():add(cmeta, "AgentWatchDim"))
    for _, c in ipairs(S.commits) do
      local l = L():add(IND)
      l:add(c.hash, "AgentWatchHash"):add("  ")
      l:add(string.format("%-4s", rel_time(c.time)), age_hl(c.time)):add("  ")
      l:add(truncate(c.subject, inner - l:width()), "AgentWatchText")
      emit(l, { type = "commit", commit = c })
    end
  end

  -- footer -----------------------------------------------------------------
  blank()
  blank()
  emit(footer_line(inner), nil)
  S.footer_lnum = #lines

  -- write buffer -----------------------------------------------------------
  local cursor = panel_open() and api.nvim_win_get_cursor(S.win) or nil
  vim.bo[S.buf].modifiable = true
  local texts = {}
  for i, l in ipairs(lines) do
    texts[i] = l.text
  end
  api.nvim_buf_set_lines(S.buf, 0, -1, false, texts)
  vim.bo[S.buf].modifiable = false
  api.nvim_buf_clear_namespace(S.buf, ns, 0, -1)
  for i, l in ipairs(lines) do
    for _, h in ipairs(l.hls) do
      pcall(api.nvim_buf_set_extmark, S.buf, ns, i - 1, h[1], { end_col = h[2], hl_group = h[3] })
    end
  end
  S.rows = rows
  if cursor then
    cursor[1] = math.min(cursor[1], #texts)
    pcall(api.nvim_win_set_cursor, S.win, cursor)
  end
end

---------------------------------------------------------------------------
-- actions
---------------------------------------------------------------------------

-- Open Diffview, reusing a single tab: close any view that is already open
-- first, otherwise every commit row would pile up another tab.
local function open_diffview(args)
  local ok, lib = pcall(require, "diffview.lib")
  if ok then
    for _, v in ipairs(vim.list_slice(lib.views)) do
      pcall(function()
        v:close()
      end)
    end
  end
  vim.cmd("DiffviewOpen " .. args)
end

local function entry_at_cursor()
  if not panel_open() then
    return nil
  end
  return S.rows[api.nvim_win_get_cursor(S.win)[1]]
end

local function file_for_path(path)
  for _, f in ipairs(S.files) do
    if f.path == path then
      return f
    end
  end
end

-- A split inherits the panel's window options. Give a new file window the
-- editor's *global* defaults instead (vim.o would read the inherited local value).
local function reset_window(w)
  for _, name in ipairs {
    "number", "relativenumber", "signcolumn", "foldcolumn", "cursorline", "cursorlineopt",
    "statuscolumn", "wrap", "list", "spell", "foldmethod", "foldlevel", "scrollbind",
  } do
    pcall(api.nvim_set_option_value, name, api.nvim_get_option_value(name, { scope = "global" }), { win = w })
  end
  for name, val in pairs { winhl = "", winfixwidth = false, diff = false } do
    api.nvim_set_option_value(name, val, { scope = "local", win = w })
  end
end

local function target_window()
  local function usable(w)
    if not (w and api.nvim_win_is_valid(w)) or w == S.win then
      return false
    end
    if api.nvim_win_get_tabpage(w) ~= api.nvim_get_current_tabpage() then
      return false
    end
    local b = api.nvim_win_get_buf(w)
    -- plain file windows only: no floats, no diff panes, no tree/panel buffers
    return vim.bo[b].buftype == "" and api.nvim_win_get_config(w).relative == "" and not vim.wo[w].diff
  end
  if usable(S.prev_win) then
    return S.prev_win
  end
  for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
    if usable(w) then
      return w
    end
  end
  api.nvim_set_current_win(S.win)
  vim.cmd "aboveleft vsplit"
  local w = api.nvim_get_current_win()
  reset_window(w)
  api.nvim_win_set_width(S.win, M.config.width)
  return w
end

local function flash_range(bufnr, first, last)
  api.nvim_buf_clear_namespace(bufnr, flash_ns, 0, -1)
  for l = first, last do
    pcall(api.nvim_buf_set_extmark, bufnr, flash_ns, l - 1, 0, { line_hl_group = "AgentWatchFlash", priority = 250 })
  end
  vim.defer_fn(function()
    if api.nvim_buf_is_valid(bufnr) then
      api.nvim_buf_clear_namespace(bufnr, flash_ns, 0, -1)
    end
  end, 350)
end

local function jump(file, hunk, keep_focus)
  if file.status == "deleted" then
    vim.notify("agentwatch: file was deleted — use `p` to peek or `d` for diffview", vim.log.levels.INFO)
    return
  end
  local win = target_window()
  api.nvim_set_current_win(win)
  vim.cmd("edit " .. fn.fnameescape(S.root .. "/" .. file.path))
  -- a freshly loaded buffer can pick up a stray global 'diff' (e.g. after a
  -- Diffview session); we only ever jump into plain windows, so force it off
  if vim.wo[win].diff then
    api.nvim_set_option_value("diff", false, { scope = "local", win = win })
  end
  local line = hunk and hunk.line or (file.hunks and file.hunks[1] and file.hunks[1].line) or 1
  local last = api.nvim_buf_line_count(0)
  line = math.max(1, math.min(line, last))
  api.nvim_win_set_cursor(0, { line, 0 })
  vim.cmd "normal! zz"
  if hunk and hunk.kind ~= "delete" then
    flash_range(api.nvim_get_current_buf(), line, math.min(last, line + math.max(0, hunk.new_count - 1)))
  else
    flash_range(api.nvim_get_current_buf(), line, line)
  end
  if keep_focus and panel_open() then
    api.nvim_set_current_win(S.win)
  end
end

function M.open_entry(keep_focus)
  local e = entry_at_cursor()
  if not e then
    return
  end
  if e.type == "file" then
    jump(e.file, nil, keep_focus)
  elseif e.type == "hunk" then
    jump(e.file, e.hunk, keep_focus)
  elseif e.type == "older" then
    S.show_older = not S.show_older
    M.render()
  elseif e.type == "commit" then
    open_diffview(e.commit.hash .. "^!")
  elseif e.type == "activity" then
    local ev = e.ev
    if ev.kind == "commit" then
      open_diffview(ev.hash .. "^!")
    elseif ev.path then
      local f = file_for_path(ev.path)
      if f then
        jump(f, ev.hunk, keep_focus)
      elseif uv.fs_stat(S.root .. "/" .. ev.path) then
        jump({ path = ev.path, hunks = {} }, nil, keep_focus)
      end
    end
  end
end

local function close_preview()
  if S.preview_win and api.nvim_win_is_valid(S.preview_win) then
    api.nvim_win_close(S.preview_win, true)
  end
  S.preview_win = nil
end

local function show_float(lines, ft, title)
  close_preview()
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = ft
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, dw(l))
  end
  local max_w = math.max(40, vim.o.columns - M.config.width - 8)
  width = math.min(math.max(40, width + 2), max_w)
  local height = math.min(math.max(3, #lines), math.floor(vim.o.lines * 0.7))
  local col = vim.o.columns - M.config.width - width - 3
  local row = math.max(1, api.nvim_win_get_cursor(S.win)[1] - api.nvim_win_call(S.win, function()
    return fn.line "w0"
  end))
  row = math.min(row, vim.o.lines - height - 4)
  S.preview_win = api.nvim_open_win(buf, false, {
    relative = "editor",
    row = row,
    col = math.max(0, col),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = title and (" " .. title .. " ") or nil,
    title_pos = "left",
    focusable = true,
    zindex = 60,
  })
  api.nvim_set_option_value("winhl", "Normal:NormalFloat,FloatBorder:FloatBorder", { scope = "local", win = S.preview_win })
  api.nvim_set_option_value("wrap", false, { scope = "local", win = S.preview_win })
  api.nvim_create_autocmd({ "CursorMoved", "BufLeave", "WinLeave" }, {
    buffer = S.buf,
    once = true,
    callback = function()
      vim.schedule(close_preview)
    end,
  })
end

local function diff_args(path)
  local args = { "git", "diff", "--no-color", "--no-ext-diff" }
  if S.base_rev then
    table.insert(args, S.base_rev)
  end
  table.insert(args, "--")
  table.insert(args, path)
  return args
end

function M.preview()
  local e = entry_at_cursor()
  if not e then
    return
  end
  if e.type == "commit" or (e.type == "activity" and e.ev.kind == "commit") then
    local hash = e.type == "commit" and e.commit.hash or e.ev.hash
    run({ "git", "show", "--stat", "--no-color", hash }, function(o)
      show_float(vim.split(o.stdout or "", "\n"), "git", hash)
    end)
    return
  end
  local file = e.file or (e.ev and e.ev.path and file_for_path(e.ev.path))
  if not file then
    return
  end
  if file.untracked then
    local lines = first_lines(file.path, 200)
    show_float(#lines > 0 and lines or { "(empty file)" }, vim.filetype.match { filename = file.path } or "", file.path .. "  (new)")
    return
  end
  local hunk = e.hunk or (e.ev and e.ev.hunk)
  run(diff_args(file.path), function(o)
    local all = vim.split(o.stdout or "", "\n")
    if not hunk then
      show_float(all, "diff", file.path)
      return
    end
    local out, keep = {}, false
    for _, l in ipairs(all) do
      local ns_, nc = l:match "^@@ %-%d+,?%d* %+(%d+),?(%d*) @@"
      if ns_ then
        ns_, nc = tonumber(ns_), nc == "" and 1 or tonumber(nc)
        local lo, hi = ns_, ns_ + math.max(nc, 1) - 1
        keep = hunk.line >= lo - 3 and hunk.line <= hi + 3
      end
      if keep then
        table.insert(out, l)
      end
    end
    show_float(#out > 0 and out or all, "diff", string.format("%s :%d", file.path, hunk.line))
  end)
end

function M.diffview()
  local e = entry_at_cursor()
  if not e then
    return
  end
  if e.type == "commit" then
    open_diffview(e.commit.hash .. "^!")
  elseif e.type == "activity" and e.ev.kind == "commit" then
    open_diffview(e.ev.hash .. "^!")
  else
    local path = e.file and e.file.path or (e.ev and e.ev.path)
    if not path then
      return
    end
    local rev = S.base_rev and (S.base_rev .. " ") or ""
    open_diffview(rev .. "-- " .. fn.fnameescape(path))
  end
end

function M.toggle_expand(force)
  local e = entry_at_cursor()
  if not e then
    return
  end
  if e.type == "older" then
    if force == nil then
      S.show_older = not S.show_older
    else
      S.show_older = force
    end
  elseif e.file then
    local want
    if force == nil then
      want = not S.expanded[e.file.path]
    else
      want = force
    end
    S.expanded[e.file.path] = want or nil
  else
    return
  end
  M.render()
end

function M.expand_all(expand)
  S.expanded = {}
  if expand then
    for _, f in ipairs(S.files) do
      S.expanded[f.path] = true
    end
  end
  M.render()
end

function M.clear_activity()
  S.activity = {}
  M.render()
end

function M.help()
  show_float({
    "",
    "   ↵  /  double-click   jump to change (or open commit diff)",
    "   o                    jump, keep focus here",
    "   p                    peek at the diff in a float",
    "   d                    open in Diffview",
    "   l / h / ⇥            expand / collapse / toggle a file",
    "   zR / zM              expand / collapse all",
    "   b                    cycle base: branch → HEAD → index",
    "   r                    refresh now",
    "   c                    clear activity feed",
    "   q                    close",
    "",
  }, "", "agentwatch")
end

---------------------------------------------------------------------------
-- panel lifecycle
---------------------------------------------------------------------------

local function ensure_buf()
  if S.buf and api.nvim_buf_is_valid(S.buf) then
    return S.buf
  end
  local buf = api.nvim_create_buf(false, true)
  S.buf = buf
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = "agentwatch"
  vim.bo[buf].modifiable = false
  api.nvim_buf_set_name(buf, "agentwatch://changes")

  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true, silent = true, desc = desc })
  end
  map("<CR>", M.open_entry, "Jump to change")
  map("<2-LeftMouse>", M.open_entry, "Jump to change")
  map("o", function()
    M.open_entry(true)
  end, "Open, keep focus")
  map("p", M.preview, "Peek diff")
  map("d", M.diffview, "Open in Diffview")
  map("<Tab>", M.toggle_expand, "Toggle file")
  map("za", M.toggle_expand, "Toggle file")
  map("l", function()
    M.toggle_expand(true)
  end, "Expand file")
  map("h", function()
    M.toggle_expand(false)
  end, "Collapse file")
  map("zR", function()
    M.expand_all(true)
  end, "Expand all")
  map("zM", function()
    M.expand_all(false)
  end, "Collapse all")
  map("b", M.cycle_base, "Cycle base")
  map("r", function()
    S.snapshot = nil
    M.refresh()
  end, "Refresh")
  map("c", M.clear_activity, "Clear activity")
  map("q", M.close, "Close")
  map("?", M.help, "Help")
  return buf
end

-- redraw just the footer row (cheap enough to run many times a second)
local function update_footer()
  if not (panel_open() and S.buf and api.nvim_buf_is_valid(S.buf) and S.footer_lnum) then
    return
  end
  local inner = api.nvim_win_get_width(S.win) - 1
  local l = footer_line(inner)
  local row = S.footer_lnum - 1
  if row >= api.nvim_buf_line_count(S.buf) then
    return
  end
  vim.bo[S.buf].modifiable = true
  api.nvim_buf_set_lines(S.buf, row, row + 1, false, { l.text })
  vim.bo[S.buf].modifiable = false
  api.nvim_buf_clear_namespace(S.buf, ns, row, row + 1)
  for _, h in ipairs(l.hls) do
    pcall(api.nvim_buf_set_extmark, S.buf, ns, row, h[1], { end_col = h[2], hl_group = h[3] })
  end
end

local function stop_anim()
  if S.anim then
    S.anim:stop()
    S.anim:close()
    S.anim = nil
  end
end

local function restart_timer()
  if S.timer then
    S.timer:stop()
    S.timer:close()
    S.timer = nil
  end
  stop_anim()
  if panel_open() then
    S.anim = uv.new_timer()
    S.anim:start(120, 120, vim.schedule_wrap(update_footer))
  end
  local interval = panel_open() and M.config.poll_open_ms or M.config.poll_closed_ms
  S.timer = uv.new_timer()
  S.timer:start(
    interval,
    interval,
    vim.schedule_wrap(function()
      if S.root then
        M.refresh()
      end
    end)
  )
end

function M.open()
  if panel_open() then
    api.nvim_set_current_win(S.win)
    return
  end
  S.prev_win = api.nvim_get_current_win()
  local buf = ensure_buf()
  vim.cmd("botright " .. M.config.width .. "vsplit")
  S.win = api.nvim_get_current_win()
  api.nvim_win_set_buf(S.win, buf)
  -- local scope only: vim.wo[win] would also overwrite the editor's global
  -- defaults, leaving every window opened afterwards without numbers/signs
  local function setl(name, val)
    api.nvim_set_option_value(name, val, { scope = "local", win = S.win })
  end
  setl("number", false)
  setl("relativenumber", false)
  setl("signcolumn", "no")
  setl("foldcolumn", "0")
  setl("foldenable", false)
  setl("cursorline", true)
  setl("cursorlineopt", "line")
  setl("wrap", false)
  setl("list", false)
  setl("spell", false)
  setl("winfixwidth", true)
  setl("statuscolumn", "")
  setl("diff", false)
  setl("scrollbind", false)
  setl(
    "winhl",
    "Normal:AgentWatchNormal,NormalNC:AgentWatchNormal,EndOfBuffer:AgentWatchNormal,CursorLine:AgentWatchCursorLine,SignColumn:AgentWatchNormal"
  )
  set_overlay(true)
  M.render()
  M.refresh()
  restart_timer()
end

local function on_closed()
  close_preview()
  S.win = nil
  set_overlay(false)
  restart_timer()
end

function M.close()
  if panel_open() then
    api.nvim_win_close(S.win, true)
  end
  on_closed()
end

function M.toggle()
  if panel_open() then
    M.close()
  else
    M.open()
  end
end

---------------------------------------------------------------------------
-- setup
---------------------------------------------------------------------------

local function detect_root()
  run({ "git", "rev-parse", "--show-toplevel" }, function(o)
    local root = o.code == 0 and vim.trim(o.stdout) or nil
    if root ~= S.root then
      S.root = root
      S.snapshot, S.commit_seen = nil, nil
      S.files, S.commits, S.activity = {}, {}, {}
      S.expanded, S.show_older = {}, false
      if root then
        sync_gitsigns()
        M.refresh()
      else
        M.render()
      end
    end
  end)
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  S.base_mode = M.config.default_base
  set_highlights()

  local group = api.nvim_create_augroup("AgentWatch", { clear = true })
  api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_highlights })
  api.nvim_create_autocmd("DirChanged", { group = group, callback = detect_root })
  local pending = false
  api.nvim_create_autocmd({ "BufWritePost", "FocusGained", "FileChangedShellPost" }, {
    group = group,
    callback = function()
      if pending or not S.root then
        return
      end
      pending = true
      vim.defer_fn(function()
        pending = false
        M.refresh()
      end, 300)
    end,
  })
  api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      if S.win and tonumber(ev.match) == S.win then
        on_closed()
      end
    end,
  })

  api.nvim_create_user_command("AgentWatch", function(a)
    local sub = a.args
    if sub == "close" then
      M.close()
    elseif sub == "open" then
      M.open()
    elseif sub == "base" then
      M.cycle_base()
    elseif sub == "clear" then
      M.clear_activity()
    else
      M.toggle()
    end
  end, {
    nargs = "?",
    complete = function()
      return { "toggle", "open", "close", "base", "clear" }
    end,
    desc = "Agent Watch panel",
  })

  detect_root()
  restart_timer()
end

return M
