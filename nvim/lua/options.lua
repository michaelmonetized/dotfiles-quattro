require "nvchad.options"

local o = vim.o

o.number = true
o.relativenumber = true

-- Re-apply after NvChad loads (it can override during startup)
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.o.number = true
    vim.o.relativenumber = true
  end,
})

-- Save files in-place so external file watchers like Turbopack see consistent
-- write events instead of backup/rename-style churn.
-- Diagnostics: truncate inline virtual text, show full message in float
vim.diagnostic.config({
  virtual_text = {
    suffix = "",
    format = function(diagnostic)
      local max = 60
      local msg = diagnostic.message:gsub("\n", " ")
      if #msg > max then
        return msg:sub(1, max) .. "…"
      end
      return msg
    end,
  },
  float = {
    max_width = 80,
    wrap = true,
    border = "rounded",
    source = true,
  },
})

o.backup = false
o.writebackup = false
o.backupcopy = "yes"

-- macOS only: follow system appearance (Catppuccin Mocha ↔ Latte).
-- `defaults` is not a Linux command; skip the poll on Omarchy.
if vim.fn.has "mac" == 1 then
  local function sync_macos_appearance()
    local handle = io.popen "defaults read -g AppleInterfaceStyle 2>/dev/null"
    if not handle then
      return
    end
    local result = handle:read "*a"
    handle:close()

    local is_dark = result:match "Dark" ~= nil
    local bg = is_dark and "dark" or "light"

    if vim.o.background ~= bg then
      vim.o.background = bg
    end
  end

  sync_macos_appearance()

  local timer = vim.uv.new_timer()
  if timer then
    timer:start(5000, 5000, vim.schedule_wrap(sync_macos_appearance))
  end
end
