require("nvchad.configs.lspconfig").defaults()

-- defaults() already wires capabilities + on_init globally via vim.lsp.config("*", ...)
-- and registers the NvChad keymaps on LspAttach, so servers with no extra config
-- just need to be enabled.
vim.lsp.enable { "html", "cssls", "tailwindcss", "eslint" }

-- TypeScript Tools setup (better than tsserver)
require("typescript-tools").setup {
  on_attach = function(client, bufnr)
    require("nvchad.configs.lspconfig").on_attach(client, bufnr)
  end,
  capabilities = require("nvchad.configs.lspconfig").capabilities,
  settings = {
    separate_diagnostic_server = true,
    publish_diagnostic_on = "insert_leave",
    expose_as_code_action = { "fix_all", "add_missing_imports", "remove_unused" },
    tsserver_path = nil,
    tsserver_plugins = {},
    tsserver_max_memory = "auto",
    tsserver_format_options = {
      insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces = false,
      insertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets = false,
      insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis = false,
    },
    tsserver_file_preferences = {
      includeInlayParameterNameHints = "all",
      includeInlayParameterNameHintsWhenArgumentMatchesName = false,
      includeInlayFunctionParameterTypeHints = true,
      includeInlayVariableTypeHints = true,
      includeInlayPropertyDeclarationTypeHints = true,
      includeInlayFunctionLikeReturnTypeHints = true,
      includeInlayEnumMemberValueHints = true,
    },
    tsserver_locale = "en",
    complete_function_calls = true,
    include_completions_with_insert_text = true,
    code_lens = "off",
    disable_member_code_lens = true,
    jsx_close_tag = {
      enable = true,
      filetypes = { "javascriptreact", "typescriptreact" },
    }
  },
}

-- Python setup with Pyrefly for type checking and Ruff for linting/formatting
-- Prefer the project's own <root>/.venv/bin/<bin> so the version matches what the
-- repo pins (and CI runs); fall back to the brew-installed one on PATH.
local function venv_cmd(bin, args)
  return function(dispatchers, config)
    local exe = bin
    local local_bin = config.root_dir and (config.root_dir .. "/.venv/bin/" .. bin)
    if local_bin and vim.uv.fs_stat(local_bin) then
      exe = local_bin
    end
    return vim.lsp.rpc.start(vim.list_extend({ exe }, args), dispatchers, {
      cwd = config.cmd_cwd or config.root_dir,
      env = config.cmd_env,
    })
  end
end

-- Pyrefly for types / go-to-definition. It reads [tool.pyrefly] from pyproject.toml,
-- so search paths and the interpreter come from the repo, not from here.
vim.lsp.config("pyrefly", { cmd = venv_cmd("pyrefly", { "lsp" }) })

-- Ruff for fast Python linting and formatting
vim.lsp.config("ruff", {
  cmd = venv_cmd("ruff", { "server" }),
  on_attach = function(client, _)
    -- Disable hover in favor of Pyrefly
    client.server_capabilities.hoverProvider = false
  end,
})

vim.lsp.enable { "pyrefly", "ruff" }

-- Go setup with gopls (helper binaries managed by go.nvim's :GoInstallBinaries)
vim.lsp.config("gopls", {
  settings = {
    gopls = {
      gofumpt = true,
      staticcheck = true,
      usePlaceholders = true,
      completeUnimported = true,
      semanticTokens = true,
      analyses = {
        unusedparams = true,
        unusedwrite = true,
        nilness = true,
        shadow = true,
        useany = true,
      },
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
    },
  },
})

vim.lsp.enable { "gopls" }