local M = {}

local lsp_installer_servers = require "nvim-lsp-installer.servers"
local lspconfig = require "lspconfig"
local cmp_nvim_lsp = require "cmp_nvim_lsp"
local null_ls = require "null-ls"
local trouble = require "trouble"

local setup_copilot = function()
  vim.g.copilot_filetypes = {
    TelescopePrompt = false,
  }
end

local setup_trouble = function()
  trouble.setup()
end

local setup_lsp_installer = function()
  local lsp_servers = {
    "bashls",
    "clangd",
    "cssls",
    "dockerls",
    "emmet_ls",
    "gopls",
    "graphql",
    "html",
    "jsonls",
    "kotlin_language_server",
    "pyright",
    "rust_analyzer",
    "sorbet",
    "stylelint_lsp",
    "sumneko_lua",
    "svelte",
    "tailwindcss",
    "terraformls",
    "tsserver",
    "vimls",
    "yamlls",
  }

  local on_server_ready = function(server)
    local opts = {}
    local capabilities = cmp_nvim_lsp.update_capabilities(vim.lsp.protocol.make_client_capabilities())

    if server.name == "sumneko_lua" then
      local runtime_path = vim.split(package.path, ";")
      table.insert(runtime_path, "lua/?.lua")
      table.insert(runtime_path, "lua/?/init.lua")

      opts.settings = {
        Lua = {
          runtime = {
            version = "LuaJIT",
            path = runtime_path,
          },
          diagnostics = {
            globals = { "vim" },
          },
          workspace = {
            library = vim.api.nvim_get_runtime_file("", true),
          },
        },
      }
    end

    if server.name == "yamlls" then
      opts.settings = {
        yaml = {
          validate = false,
          hover = true,
          completion = true,
          schemaStore = {
            enable = true,
            url = "https://www.schemastore.org/api/json/catalog.json",
          },
        },
      }
    end

    if server.name == "cssls" then
      opts.settings = {
        css = {
          validate = false,
        },
        less = {
          validate = false,
        },
        scss = {
          validate = false,
        },
      }
    end

    if server.name == "jsonls" then
      opts.settings = {
        json = {
          schemas = require("schemastore").json.schemas(),
        },
      }

      opts.get_language_id = function(_, filetype)
        return filetype == "json" and "jsonc" or filetype
      end
    end

    if server.name == "tsserver" then
      opts.init_options = {
        preferences = {
          disableSuggestions = true,
          includeCompletionsForImportStatements = true,
          importModuleSpecifierPreference = "shortest",
          lazyConfiguredProjectsFromExternalProject = true,
        },
      }
    end

    opts.on_attach = function(client, bufnr)
      client.resolved_capabilities.document_formatting = false
      client.resolved_capabilities.document_range_formatting = false

      require("core.keymap").buf_register(bufnr)
    end

    opts.capabilities = capabilities

    server:setup(opts)
  end

  for _, lsp_name in ipairs(lsp_servers) do
    local server_available, requested_server = lsp_installer_servers.get_server(lsp_name)

    if server_available then
      requested_server:on_ready(function()
        on_server_ready(requested_server)
      end)

      if not requested_server:is_installed() then
        requested_server:install()
      end
    end
  end
end

local function setup_null_ls()
  null_ls.config {
    sources = {
      null_ls.builtins.formatting.trim_newlines,
      null_ls.builtins.formatting.trim_whitespace,
      null_ls.builtins.formatting.stylua,
      null_ls.builtins.formatting.prettierd,
      null_ls.builtins.formatting.gofmt,
      null_ls.builtins.formatting.rustfmt,
      null_ls.builtins.formatting.taplo,
      null_ls.builtins.formatting.terraform_fmt,
      null_ls.builtins.formatting.clang_format,
      null_ls.builtins.formatting.sqlformat,
      null_ls.builtins.formatting.shfmt.with {
        filetypes = { "sh", "zsh" },
        extra_args = { "-i", 2 },
      },
      null_ls.builtins.formatting.fish_indent,
      null_ls.builtins.formatting.nginx_beautifier,
      null_ls.builtins.diagnostics.eslint_d,
    },
  }

  lspconfig["null-ls"].setup {
    on_attach = function(client)
      if client.resolved_capabilities.document_formatting then
        vim.cmd "autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_sync()"
      end
    end,
  }
end

function M.setup()
  setup_lsp_installer()
  setup_copilot()
  setup_trouble()

  vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
    update_in_insert = true,
  })

  setup_null_ls()
end

return M
