return {
  {
    "stevearc/conform.nvim",
    event = 'BufWritePre',
    opts = require "configs.conform",
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- Enhanced TypeScript support
  {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    opts = {},
  },

  -- Better completion
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      require "configs.cmp"
    end,
  },

  -- FZF extension for Telescope (NvChad already includes telescope.nvim)
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
    config = function()
      require("telescope").load_extension("fzf")
    end,
  },

  -- Lightning fast motion
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    },
  },

  -- Smooth scrolling
  {
    "karb94/neoscroll.nvim",
    event = "VeryLazy",
    opts = {
      mappings = {'<C-u>', '<C-d>', '<C-b>', '<C-f>', '<C-y>', '<C-e>', 'zt', 'zz', 'zb'},
      hide_cursor = false,
      stop_eof = true,
      respect_scrolloff = false,
      cursor_scrolls_alone = true,
      easing_function = "quadratic",
      performance_mode = false,
    },
  },

  -- Project-wide find and replace
  {
    "nvim-pack/nvim-spectre",
    cmd = "Spectre",
    opts = {},
  },

  {
  	"nvim-treesitter/nvim-treesitter",
  	opts = {
  		ensure_installed = {
  			"vim", "lua", "vimdoc",
        "html", "css", "tsx", "typescript", "javascript", "json",
        "regex", "markdown", "markdown_inline",
        "python", "bash", "yaml", "toml", "dockerfile", "gitignore",
        "go", "gomod", "gosum", "gowork"
  		},
      highlight = {
        enable = true,
        use_languagetree = true,
      },
      indent = { enable = true },
      autotag = { enable = true },
  	},
    dependencies = {
      "windwp/nvim-ts-autotag",
    },
  },

  -- Commenting with context awareness
  {
    "numToStr/Comment.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "JoosepAlviste/nvim-ts-context-commentstring",
    },
    config = function()
      -- Setup context commentstring first
      vim.g.skip_ts_context_commentstring_module = true
      require('ts_context_commentstring').setup {
        enable_autocmd = false,
      }
      
      -- Then setup Comment.nvim with context support
      require('Comment').setup {
        pre_hook = require('ts_context_commentstring.integrations.comment_nvim').create_pre_hook(),
      }
    end,
  },

  -- Better diagnostics
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
  },

  -- LSP progress
  {
    "j-hui/fidget.nvim",
    event = "LspAttach",
    opts = {},
  },

  -- Better folding
  {
    "kevinhwang91/nvim-ufo",
    dependencies = "kevinhwang91/promise-async",
    config = function()
      require "configs.ufo"
    end,
  },

  -- Indent guides
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {
      scope = { enabled = false },
    },
  },

  -- Git integration
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      -- Heavy bars in the gutter + colored line numbers: strong "something
      -- changed here" signal without painting the whole line
      signs = {
        add = { text = "┃" },
        change = { text = "┃" },
        delete = { text = "▁" },
        topdelete = { text = "▔" },
        changedelete = { text = "┃" },
        untracked = { text = "┇" },
      },
      signs_staged = {
        add = { text = "┃" },
        change = { text = "┃" },
        delete = { text = "▁" },
        topdelete = { text = "▔" },
        changedelete = { text = "┃" },
        untracked = { text = "┇" },
      },
      numhl = true,
      linehl = false,
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 300,
      },
    },
  },

  -- Git diffs
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles", "DiffviewFileHistory" },
    config = function()
      require "configs.diffview"
    end,
  },

  -- Neogit - Magit for Neovim
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    cmd = "Neogit",
    config = function()
      require "configs.neogit"
    end,
  },

  -- Octo - GitHub PRs & issues in-editor (WebStorm-style PR review)
  {
    "pwntester/octo.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
      "sindrets/diffview.nvim",
    },
    cmd = "Octo",
    config = function()
      require "configs.octo"
    end,
  },

  -- pr.nvim - focused GitHub PR reviewer (A/B against octo)
  {
    "0xKitsune/pr.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    cmd = "PR",
    config = function()
      require("pr").setup()
    end,
  },

  -- TODO comments
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },

  -- Smear cursor animation (disabled)
  -- {
  --   "sphamba/smear-cursor.nvim",
  --   event = "VeryLazy",
  --   opts = {
  --     cursor_color = "#ffffff",
  --     stiffness = 0.9,
  --     trailing_stiffness = 0.7,
  --     distance_stop_animating = 0.3,
  --   },
  -- },

  -- Python specific
  {
    "linux-cultist/venv-selector.nvim",
    branch = "main", -- lockfile had drifted onto the retired `regexp` branch
    dependencies = { "neovim/nvim-lspconfig", "nvim-telescope/telescope.nvim" },
    ft = "python",
    opts = {
      name = { "venv", ".venv", "env", ".env" },
      auto_refresh = true,
    },
    keys = {
      { "<leader>pv", "<cmd>VenvSelect<cr>", desc = "Select Python venv" },
      { "<leader>pc", "<cmd>VenvSelectCached<cr>", desc = "Select cached venv" },
    },
  },

  -- Better Python indentation
  {
    "Vimjas/vim-python-pep8-indent",
    ft = "python",
  },

  -- Python docstrings
  {
    "danymat/neogen",
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = true,
    keys = {
      { "<leader>pd", "<cmd>Neogen<cr>", desc = "Generate docstring" },
    },
  },

  -- Tailwind class tooling
  {
    "luckasRanarison/tailwind-tools.nvim",
    name = "tailwind-tools",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-telescope/telescope.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = {},
  },

  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    lazy = false,
    config = function()
      require "configs.refactoring"
    end,
  },
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
      "TmuxNavigatorProcessList",
    },
    keys = {
      { "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
      { "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
      { "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
      { "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
      { "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
    },
  },

  -- Override nvim-tree configuration for better window navigation
  {
    "nvim-tree/nvim-tree.lua",
    opts = function()
      return require "configs.nvimtree"
    end,
  },

    {
        "rachartier/tiny-inline-diagnostic.nvim",
        event = "VeryLazy",
        priority = 1000,
        config = function()
            require("tiny-inline-diagnostic").setup()
            vim.diagnostic.config({ virtual_text = false }) -- Disable Neovim's default virtual text diagnostics
        end,
    },

  -- Render markdown in-buffer
  {
    "OXY2DEV/markview.nvim",
    lazy = false,
  },

  -- Claude Code IDE integration
  -- Two-terminal workflow: nvim runs here, `claude` runs in a SEPARATE terminal.
  -- This plugin only runs the WebSocket server + writes ~/.claude/ide/<port>.lock.
  -- In the other terminal: `cd` to the same project, run `claude`, then `/ide` to connect
  -- (or launch `claude --ide`). Diffs, selection, and diagnostics flow back into nvim.
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    -- Load at startup so the server + lock file are up before you open the other terminal.
    event = "VeryLazy",
    opts = {
      terminal = {
        provider = "none", -- don't spawn a Claude terminal inside nvim; you manage it yourself
      },
    },
    keys = {
      { "<leader>a", nil, desc = "AI/Claude Code" },
      -- Push context to Claude over the socket
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer to Claude" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection to Claude" },
      {
        "<leader>as",
        "<cmd>ClaudeCodeTreeAdd<cr>",
        desc = "Add file(s) from tree to Claude",
        ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw" },
      },
      -- Diff review (works anywhere; in the diff buffer :w / :q also work)
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept Claude diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny Claude diff" },
      -- Server control (auto-starts; here for when you need it)
      { "<leader>aS", "<cmd>ClaudeCodeStatus<cr>", desc = "Claude connection status" },
      { "<leader>ao", "<cmd>ClaudeCodeStart<cr>", desc = "Start Claude server" },
      { "<leader>ax", "<cmd>ClaudeCodeStop<cr>", desc = "Stop Claude server" },
    },
  },
}
