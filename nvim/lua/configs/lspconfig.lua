-- Load NvChad defaults
require("nvchad.configs.lspconfig").defaults()

local nvlsp = require "nvchad.configs.lspconfig"
local util = require "lspconfig.util"

local mason_bin = vim.fn.expand("~/.local/share/nvim/mason/bin")
if not vim.env.PATH:find(mason_bin, 1, true) then
  vim.env.PATH = mason_bin .. ":" .. vim.env.PATH
end

-- Auto-ensure essential Mason tools
local function ensure_mason_tools()
  local ok, mr = pcall(require, "mason-registry")
  if not ok then
    return
  end
  local tools = {
    "typescript-language-server",
    "tailwindcss-language-server",
    "biome",
    "prettier",
    "oxlint",
    "rustywind",
    "stylua",
    "css-lsp",
    "html-lsp",
  }
  for _, tool in ipairs(tools) do
    if mr.has_package(tool) then
      local p = mr.get_package(tool)
      if not p:is_installed() then
        p:install()
      end
    end
  end
end

vim.schedule(ensure_mason_tools)

local function read_first_line(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local line = file:read("*l")
  file:close()
  return line
end

local function project_root_from(fname)
  local root_files = {
    "tailwind.config.js",
    "tailwind.config.cjs",
    "tailwind.config.mjs",
    "tailwind.config.ts",
    "postcss.config.js",
    "postcss.config.cjs",
    "postcss.config.mjs",
    "postcss.config.ts",
    "tailwind.config.css",
    "src/tailwind.config.css",
    ".git",
  }

  root_files = util.insert_package_json(root_files, "tailwindcss", fname)

  local root = vim.fs.find(root_files, { path = fname, upward = true })[1]
  return root and vim.fs.dirname(root) or nil
end

local function is_tailwind_stylesheet(fname)
  local line = read_first_line(fname)
  if not line then
    return false
  end

  return line:find("^@import%s+[\"']tailwindcss[\"'];?$") ~= nil
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "css",
  callback = function(args)
    local line = vim.api.nvim_buf_get_lines(args.buf, 0, 1, false)[1] or ""
    if line:find("^@import%s+[\"']tailwindcss[\"'];?$") then
      vim.bo[args.buf].filetype = "tailwindcss"
    end
  end,
})

-- Servers with default config
local default_servers = { "html", "cssls" }

for _, lsp in ipairs(default_servers) do
  vim.lsp.config[lsp] = {
    on_attach = nvlsp.on_attach,
    on_init = nvlsp.on_init,
    capabilities = nvlsp.capabilities,
  }
  vim.lsp.enable(lsp)
end

vim.lsp.config.cssls = vim.tbl_deep_extend("force", vim.lsp.config.cssls or {}, {
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)

    if is_tailwind_stylesheet(fname) then
      return
    end

    local root = vim.fs.find({ "package.json", ".git" }, { path = fname, upward = true })[1]
    on_dir(root and vim.fs.dirname(root) or vim.fn.getcwd())
  end,
})

-- ESLint with auto-fix on save
local function eslint_fix_all(bufnr)
  local params = {
    context = {
      only = { "source.fixAll.eslint" },
      diagnostics = {},
    },
  }

  local results = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 2000)
  if not results then
    return
  end

  for client_id, result in pairs(results) do
    for _, action in ipairs(result.result or {}) do
      if action.edit then
        vim.lsp.util.apply_workspace_edit(action.edit, client_id)
      end
      if action.command then
        vim.lsp.buf.execute_command(action.command)
      end
    end
  end
end

vim.api.nvim_create_user_command("EslintFixAll", function(opts)
  eslint_fix_all(opts.buf)
end, {
  desc = "Apply ESLint fix-all code actions",
  bar = true,
})

vim.lsp.config.eslint = {
  on_attach = function(client, bufnr)
    nvlsp.on_attach(client, bufnr)
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      callback = function()
        eslint_fix_all(bufnr)
      end,
    })
  end,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local root = vim.fs.find({
      ".eslintrc",
      ".eslintrc.js",
      ".eslintrc.cjs",
      ".eslintrc.json",
      ".eslintrc.yaml",
      ".eslintrc.yml",
      "eslint.config.js",
      "eslint.config.mjs",
      "eslint.config.cjs",
      "eslint.config.ts",
      "eslint.config.mts",
    }, { path = fname, upward = true })[1]
    if root then
      on_dir(vim.fs.dirname(root))
      return
    end
    local pkg = vim.fs.find("package.json", { path = fname, upward = true })[1]
    if pkg then
      local ok, lines = pcall(vim.fn.readfile, pkg)
      if ok and table.concat(lines, ""):find("eslint") then
        on_dir(vim.fs.dirname(pkg))
      end
    end
  end,
}
vim.lsp.enable('eslint')

-- TypeScript (ts_ls, formerly tsserver)
vim.lsp.config.ts_ls = {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,
  cmd = { "typescript-language-server", "--stdio" },
  before_init = function(_, config)
    local root_dir = config.root_dir or vim.fn.getcwd()
    local tsserver_path = util.get_typescript_server_path(root_dir)

    config.init_options = vim.tbl_deep_extend("force", config.init_options or {}, {
      hostInfo = "neovim",
    })

    if tsserver_path ~= "" then
      config.init_options = vim.tbl_deep_extend("force", config.init_options, {
        tsserver = {
          path = tsserver_path,
        },
      })
    end
  end,
  init_options = {
    plugins = {
      {
        name = "@vue/typescript-plugin",
        location = "/usr/local/lib/node_modules/@vue/typescript-plugin",
        languages = { "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" },
      },
    },
  },
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
}
vim.lsp.enable('ts_ls')

-- Tailwind CSS
vim.lsp.config.tailwindcss = {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,
  cmd = { "tailwindcss-language-server", "--stdio" },
  filetypes = {
    "tailwindcss",
    "css",
    "html",
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "astro",
    "mdx",
    "templ",
  },
  settings = {
    tailwindCSS = {
      classAttributes = { "class", "className", "class:list", "classList", "ngClass" },
      includeLanguages = {
        eelixir = "html-eex",
        eruby = "erb",
        htmlangular = "html",
        templ = "html",
        tailwindcss = "css",
      },
      lint = {
        cssConflict = "warning",
        invalidApply = "error",
        invalidConfigPath = "error",
        invalidScreen = "error",
        invalidTailwindDirective = "error",
        invalidVariant = "error",
        recommendedVariantOrder = "warning",
      },
      validate = true,
    },
  },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local filetype = vim.bo[bufnr].filetype

    if filetype == "tailwindcss" and not is_tailwind_stylesheet(fname) then
      return
    end

    on_dir(project_root_from(fname))
  end,
}
vim.lsp.enable('tailwindcss')

-- Biome LSP (for fast TypeScript/TSX/CSS linting, diagnostics & code actions)
vim.lsp.config.biome = {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,
  cmd = { "biome", "lsp-proxy" },
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "json",
    "jsonc",
    "css",
    "graphql",
    "astro",
    "svelte",
    "vue",
  },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local root = vim.fs.find({ "biome.json", "biome.jsonc" }, { path = fname, upward = true })[1]
    if root then
      on_dir(vim.fs.dirname(root))
      return
    end
    local pkg = vim.fs.find("package.json", { path = fname, upward = true })[1]
    if pkg then
      local ok, lines = pcall(vim.fn.readfile, pkg)
      if ok and table.concat(lines, ""):find("@biomejs/biome") then
        on_dir(vim.fs.dirname(pkg))
        return
      end
    end
  end,
}
vim.lsp.enable('biome')

-- Oxlint LSP (for projects using Oxlint)
vim.lsp.config.oxlint = {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,
  cmd = { "oxlint", "--lsp" },
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local root = vim.fs.find({ ".oxlintrc.json", "oxlint.json" }, { path = fname, upward = true })[1]
    if root then
      on_dir(vim.fs.dirname(root))
    end
  end,
}
vim.lsp.enable('oxlint')

