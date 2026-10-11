require("octo").setup({
  picker = "telescope",
  default_merge_method = "squash",

  -- Auth token lacks the 'project' scope; skip the Projects v2 warning on load.
  -- Re-auth with `gh auth refresh -s project` if you want PR projects support.
  suppress_missing_scope = {
    projects_v2 = true,
  },
})

-- Octo hardcodes foldlevel=0 on review diff windows, so every file opens
-- fully folded until you hit zR. Start unfolded instead.
require("octo.reviews.file-entry").FileEntry.winopts.foldlevel = 99
