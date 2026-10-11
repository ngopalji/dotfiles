-- gopbeans — custom theme.
-- Neutral dark-grey backgrounds (no blue cast), panels slightly LIGHTER than
-- the editor, restrained syntax colors with saturated green/blue accents.
-- Reload after edits: :lua require("base46").load_all_highlights()

local M = {}

-- base_30: UI colors (statusline, nvim-tree, telescope, borders, etc.)
M.base_30 = {
  white = "#e2e2df",
  darker_black = "#2d2d2d", -- sidebar/floats — intentionally LIGHTER than bg
  black = "#262626", --  nvim bg
  black2 = "#2f2f2f",
  one_bg = "#333333",
  one_bg2 = "#3a3a3a",
  one_bg3 = "#424242",
  grey = "#4d4d4d",
  grey_fg = "#585858",
  grey_fg2 = "#626262",
  light_grey = "#767676", -- comments — readable, neutral grey
  red = "#e2726e",
  baby_pink = "#eb8f8b",
  pink = "#e08bc0",
  line = "#363636", -- for lines like vertsplit
  green = "#97c05c",
  vibrant_green = "#b2d47e",
  nord_blue = "#6b93d1",
  blue = "#7aa5e8",
  yellow = "#e3c078",
  sun = "#eeca82",
  purple = "#b98fdd",
  dark_purple = "#a97fd0",
  teal = "#6fbfae",
  orange = "#e39a5f",
  cyan = "#6cc2e8",
  statusline_bg = "#2b2b2b",
  lightbg = "#3a3a3a",
  pmenu_bg = "#7aa5e8",
  folder_bg = "#7aa5e8",
}

-- base_16: syntax (base08=variables, base09=numbers, base0A=types/classes,
-- base0B=strings, base0D=functions, base0E=keywords)
M.base_16 = {
  base00 = "#262626", -- editor bg
  base01 = "#303030",
  base02 = "#3a3a3a",
  base03 = "#4d4d4d",
  base04 = "#767676",
  base05 = "#d6d6d2", -- main text: neutral, no blue tint
  base06 = "#e2e2df",
  base07 = "#efefec",
  base08 = "#cfcfca", -- variables: near-plain neutral (readability)
  base09 = "#b98fdd", -- numbers/constants: violet (freed up by keywords)
  base0A = "#d5b06b", -- types/classes: soft gold
  base0B = "#97c05c", -- strings: saturated green
  base0C = "#6fbfae", -- teal accent
  base0D = "#7aa5e8", -- functions: saturated blue
  base0E = "#e08e45", -- keywords (return, const, type, if): orange
  base0F = "#d0806e",
}

M.polish_hl = {
  treesitter = {
    -- Components (<Foo>) in blue, native tags (<div>) in yellow
    ["@tag"] = { fg = M.base_30.blue },
    ["@tag.builtin"] = { fg = M.base_30.yellow },
  },
  telescope = {
    -- panel bg inside the boxes; the space between boxes stays editor bg
    TelescopeNormal = { bg = M.base_30.darker_black },
    TelescopePromptNormal = { bg = M.base_30.darker_black },
    TelescopeBorder = { fg = "#82aaff", bg = "NONE" },
    TelescopePromptBorder = { fg = "#82aaff", bg = "NONE" },
    -- Selected row: blue bar that clearly stands out from the panel bg,
    -- fg = NONE keeps each item's own colors (PR numbers, icons, etc.)
    TelescopeSelection = { bg = "#2e4a73", fg = "NONE", bold = true },
    TelescopeSelectionCaret = { fg = "#7aa5e8", bg = "#2e4a73" },
  },
  defaults = {
    FloatBorder = { fg = "#82aaff" },
  },
  git = {
    -- Diff views (octo PR review, diffview, vimdiff): background wash only,
    -- keep normal syntax colors for the text instead of painting it all green/red
    -- Deep saturated green/red, claude-code style
    DiffAdd = { fg = "NONE", bg = "#336426" },
    -- Modified lines: blue wash on both sides, with the exact changed
    -- span popping in green (DiffText paints over DiffChange)
    DiffChange = { fg = "NONE", bg = "#344a63" },
    DiffText = { fg = "NONE", bg = "#4a9036", bold = true },
    -- DiffDelete only draws the `----` filler that pads the shorter pane;
    -- real deleted lines get DiffviewDiffAddAsDelete. Keep filler near-invisible.
    DiffDelete = { fg = "#3f3f3f", bg = "#383838" },

    -- Gutter marks (gitsigns): saturated + bold so agent edits jump out.
    -- *Nr variants color the line number too (numhl = true).
    GitSignsAdd = { fg = "#8ee04a", bold = true },
    GitSignsChange = { fg = "#7aa5e8", bold = true },
    GitSignsDelete = { fg = "#ff5f57", bold = true },
    GitSignsChangedelete = { fg = "#e39a5f", bold = true },
    GitSignsTopdelete = { fg = "#ff5f57", bold = true },
    GitSignsUntracked = { fg = "#b2d47e", bold = true },
    GitSignsAddNr = { fg = "#8ee04a", bold = true },
    GitSignsChangeNr = { fg = "#7aa5e8", bold = true },
    GitSignsDeleteNr = { fg = "#ff5f57", bold = true },
    GitSignsChangedeleteNr = { fg = "#e39a5f", bold = true },
    GitSignsTopdeleteNr = { fg = "#ff5f57", bold = true },
    GitSignsUntrackedNr = { fg = "#b2d47e", bold = true },
    -- Agent Watch overlay (gitsigns linehl / word_diff / show_deleted while the
    -- panel is open): soft line wash, with the exact changed words popping
    GitSignsAddLn = { bg = "#2c3f24" },
    GitSignsChangeLn = { bg = "#2b3648" },
    GitSignsDeleteVirtLn = { bg = "#3d2320", fg = "#8a6a66" },
    GitSignsAddInline = { bg = "#3f6d2c" },
    GitSignsChangeInline = { bg = "#3b5a86" },
    GitSignsDeleteInline = { bg = "#7a2e28" },
    GitSignsAddLnInline = { bg = "#3f6d2c" },
    GitSignsChangeLnInline = { bg = "#3b5a86" },
    GitSignsDeleteLnInline = { bg = "#7a2e28" },
    GitSignsDeleteVirtLnInLine = { bg = "#7a2e28" },
    -- staged hunks: same hue, dimmer, so unstaged (fresh agent work) reads hotter
    GitSignsStagedAdd = { fg = "#5f8f38" },
    GitSignsStagedChange = { fg = "#4f6f9e" },
    GitSignsStagedDelete = { fg = "#9e4a45" },
    GitSignsStagedChangedelete = { fg = "#9e6b45" },
    GitSignsStagedTopdelete = { fg = "#9e4a45" },
    GitSignsStagedAddNr = { fg = "#5f8f38" },
    GitSignsStagedChangeNr = { fg = "#4f6f9e" },
    GitSignsStagedDeleteNr = { fg = "#9e4a45" },
  },
  diffview = {
    -- deleted lines in the left pane of side-by-side diffs: deep red
    DiffviewDiffAddAsDelete = { bg = "#5a201a" },
    -- alignment filler (used in BOTH panes — next to adds on one side and
    -- deletes on the other, diffview can't tell them apart): neutral grey
    DiffviewDiffDelete = { fg = "#3f3f3f", bg = "#383838" },
    DiffviewDiffDeleteDim = { fg = "#3f3f3f", bg = "#383838" },
  },
  cmp = {
    CmpBorder = { fg = "#82aaff" },
    CmpDocBorder = { fg = "#82aaff" },
  },
}

M.type = "dark"

return M
