-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "catppuccin",

  hl_override = {
    Comment = {
      italic = false,
      fg = "#d2f4ff",
    },
    ["@comment"] = {
      italic = false,
      fg = "#d2f4ff",
    },
  },
}

M.ui = {
  statusline = {
    theme = "minimal",
    separator_style = "round",
    order = nil,
    modules = nil,
  },
  tabufline = {
    order = { "buffers", "tabs", "btns" },
  },
}

return M
