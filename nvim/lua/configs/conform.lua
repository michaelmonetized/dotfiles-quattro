local mason_packages = vim.fn.expand("~/.local/share/nvim/mason/packages")
local tw_plugin = mason_packages .. "/prettier/node_modules/prettier-plugin-tailwindcss/dist/index.mjs"
local import_sort_plugin = mason_packages .. "/prettier/node_modules/@ianvs/prettier-plugin-sort-imports/dist/index.mjs"

local prettier_args = {}
if vim.uv.fs_stat(tw_plugin) then
  table.insert(prettier_args, "--plugin")
  table.insert(prettier_args, tw_plugin)
end
if vim.uv.fs_stat(import_sort_plugin) then
  table.insert(prettier_args, "--plugin")
  table.insert(prettier_args, import_sort_plugin)
end

local options = {
  formatters = {
    prettier = {
      prepend_args = #prettier_args > 0 and prettier_args or nil,
    },
  },

  formatters_by_ft = {
    lua = { "stylua" },
    css = { "prettier", "oxfmt", "biome", stop_after_first = true },
    tailwindcss = { "prettier", "oxfmt", "biome", stop_after_first = true },
    html = { "prettier", "oxfmt", stop_after_first = true },
    javascript = { "prettier", "oxfmt", "biome", stop_after_first = true },
    javascriptreact = { "prettier", "oxfmt", "biome", stop_after_first = true },
    typescript = { "prettier", "oxfmt", "biome", stop_after_first = true },
    typescriptreact = { "prettier", "oxfmt", "biome", stop_after_first = true },
    json = { "prettier", "biome", "oxfmt", stop_after_first = true },
    jsonc = { "prettier", "biome", "oxfmt", stop_after_first = true },
    markdown = { "prettier" },
  },

  format_on_save = {
    timeout_ms = 2000,
    lsp_format = "fallback",
  },
}

return options
