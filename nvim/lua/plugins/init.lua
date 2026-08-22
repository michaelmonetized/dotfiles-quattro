return {
  {
    "MeanderingProgrammer/markdown.nvim",
    lazy = false,
    main = "render-markdown",
    opts = {},
    name = "render-markdown",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
  },
  {
    "supermaven-inc/supermaven-nvim",
    lazy = false,
  },
  {
    "NeogitOrg/neogit",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim", -- required
      "sindrets/diffview.nvim", -- optional - Diff integration
      "nvim-telescope/telescope.nvim", -- optional
      "ibhagwan/fzf-lua", -- optional
    },
    config = true,
  },
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
  },
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = require "configs.conform",
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },
  -- {
  --   "xiyaowong/transparent.nvim",
  --   lazy = false,
  -- },
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
    cmd = { "TmuxNavigateLeft", "TmuxNavigateDown", "TmuxNavigateUp", "TmuxNavigateRight", "TmuxNavigatePrevious" },
    keys = {
      { "<C-H>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
      { "<C-J>", "<cmd><C-U>TmuxNavigateDown<cr>" },
      { "<C-K>", "<cmd><C-U>TmuxNavigateUp<cr>" },
      { "<C-L>", "<cmd><C-U>TmuxNavigateRight<cr>" },
      { "<C-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "vim", "lua", "vimdoc", "html", "css" },
      matchup = { enable = true },
    },
  },
  {
    "wfxr/minimap.vim",
    lazy = false,
    cmd = { "Minimap", "MinimapClose", "MinimapToggle", "MinimapRefresh", "MinimapUpdateHighlight" },
    config = function()
      vim.cmd "let g:minimap_auto_start = 1"
      vim.cmd "let g:minimap_auto_start_win_enter = 1"
      vim.cmd "let g:minimap_highlight_range = 0"
      vim.cmd "let g:minimap_highlight_search = 1"
      vim.cmd "let g:minimap_git_colors = 1"
      vim.cmd "let g:minimap_left = 0"

      vim.cmd "hi minimapRange guibg=#dce0e8 guifg=#5c5f77"
      vim.g.minimap_range_color = "minimapRange"

      vim.cmd "hi minimap_cursor_color guibg=#e6e9ef guifg=#209fb5"
      vim.g.minimap_cursor_color = "minimap_cursor_color"
    end,
  },
  { "catppuccin/nvim", name = "catppuccin", priority = 1000, lazy = false },
  {
    "windwp/nvim-ts-autotag",
    event = "InsertEnter",
    opts = {},
  },
  {
    "andymass/vim-matchup",
    event = "BufReadPost",
    config = function()
      vim.g.matchup_matchparen_offscreen = { method = "popup" }
    end,
  },
}

-- updated notify config
-- fix signature conflict
