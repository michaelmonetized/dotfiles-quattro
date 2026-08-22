vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

-- Indent-blankline highlight fallback (NvChad theme cache can miss these).
vim.api.nvim_set_hl(0, "IblChar", { fg = "#45475a" })
vim.api.nvim_set_hl(0, "IblScopeChar", { fg = "#7f849c" })

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"

-- load plugins
require("lazy").setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },

  { import = "plugins" },
}, lazy_config)

-- load theme
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

require "options"
require "autocmds"

require "configs.catppuccin"
require "configs.gitsigns"
require "configs.neogit"
require "configs.noice"
require "configs.notify"
require "configs.nvimtree"
require "configs.supermaven"
require("configs.codex_inline").setup()
pcall(function()
  require("config.remote_clipboard").setup()
end)

vim.schedule(function()
  require "mappings"
end)

vim.o.termguicolors = true
require("nvibe").setup()
