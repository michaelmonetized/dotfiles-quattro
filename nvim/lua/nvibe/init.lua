---@meta

---@class NvibeConfig
---@field width_percent number Percentage of screen width for terminal panel (default: 20)
---@field cursor_agent_cmd string Command to run cursor-agent (default: "cursor-agent")
---@field coderabbit_cmd string Command to run coderabbit (default: "coderabbit")
---@field diff_width_percent number Percentage of screen width for diff panel (default: 30)

---@class NvibeModule
---@field create_terminal_split fun(): nil Creates the terminal split layout
---@field toggle fun(): nil Toggles the nvibe layout on/off
---@field close fun(): nil Closes all nvibe windows
---@field rebalance fun(): nil Rebalances window sizes
---@field setup fun(opts?: NvibeConfig): nil Initializes the plugin with optional configuration

-- Nvibe Plugin for Neovim
-- Opens a terminal pane on the left with cursor-agent and coderabbit
--
-- This plugin creates a split terminal layout when <leader>| is pressed,
-- with cursor-agent running in the top terminal and coderabbit in the bottom terminal.
-- The terminal panel takes up 20% of the screen width by default.
-- Includes a diff pane on the right that shows changes for the current buffer.

local M = {}

---Default configuration for the Nvibe plugin
---@type NvibeConfig
local config = {
  width_percent = 20,
  cursor_agent_cmd = "$HOME/.local/bin/claude --dangerously-skip-permissions",
  coderabbit_cmd = "coderabbit",
  diff_width_percent = 30,
}

---Cached NvChad term module
---@type table|nil
local nvchad_term = nil

---Track nvibe state
---@type boolean
local is_open = false

---Track nvibe-managed window IDs
---@type table<string, number>
local nvibe_windows = {}

---Track nvibe-managed buffer IDs
---@type table<string, number>
local nvibe_buffers = {}

---Track the main editor window
---@type number|nil
local main_editor_win = nil

---Track diff window per buffer
---@type table<number, number> buffer_id -> diff_window_id
local diff_windows = {}

---Calculates the terminal panel width based on environment or current window
---@return number The calculated width in columns
local function get_terminal_width()
  local cols = os.getenv "COLS"
  if cols then
    return math.floor(tonumber(cols) * (config.width_percent / 100))
  else
    return math.floor(vim.o.columns * (config.width_percent / 100))
  end
end

---Calculates the diff panel width
---@return number The calculated width in columns
local function get_diff_width()
  return math.floor(vim.o.columns * (config.diff_width_percent / 100))
end

---Check if a window is valid and exists
---@param win number|nil Window ID
---@return boolean
local function is_valid_window(win)
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

---Check if a buffer has changes (is modified or has git diff)
---@param bufnr number Buffer number
---@return boolean
local function buffer_has_changes(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)
  if filename == "" then
    return false
  end

  -- Check if buffer is modified
  if vim.bo[bufnr].modified then
    return true
  end

  -- Check git diff
  local result = vim.fn.system("git diff --quiet -- " .. vim.fn.shellescape(filename) .. " 2>/dev/null; echo $?")
  return vim.trim(result) ~= "0"
end

---Get git diff for a buffer
---@param bufnr number Buffer number
---@return string[]
local function get_buffer_diff(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  if filename == "" then
    return { "No file associated with buffer" }
  end

  -- Get diff output
  local diff_output = vim.fn.systemlist("git diff --color=never -- " .. vim.fn.shellescape(filename) .. " 2>/dev/null")

  -- If buffer is modified but not saved, show unsaved indicator
  if vim.bo[bufnr].modified then
    table.insert(diff_output, 1, "--- Buffer has unsaved changes ---")
    table.insert(diff_output, 2, "")
  end

  if #diff_output == 0 then
    return { "No changes" }
  end

  return diff_output
end

---Update the diff pane for the current buffer
local function update_diff_pane()
  if not is_open then
    return
  end

  local current_buf = vim.api.nvim_get_current_buf()
  local current_win = vim.api.nvim_get_current_win()

  -- Don't update if we're in a terminal or special buffer
  if vim.bo[current_buf].buftype ~= "" then
    return
  end

  local has_changes = buffer_has_changes(current_buf)
  local diff_win = nvibe_windows.diff

  if has_changes then
    -- Create or update diff window
    if not is_valid_window(diff_win) then
      -- Find the main editor window and create diff to the right
      if is_valid_window(main_editor_win) then
        vim.api.nvim_set_current_win(main_editor_win)
      end

      -- Create diff window to the right
      vim.cmd "rightbelow vnew"
      diff_win = vim.api.nvim_get_current_win()
      nvibe_windows.diff = diff_win

      local diff_buf = vim.api.nvim_get_current_buf()
      nvibe_buffers.diff = diff_buf

      -- Configure diff buffer
      vim.bo[diff_buf].buftype = "nofile"
      vim.bo[diff_buf].bufhidden = "wipe"
      vim.bo[diff_buf].swapfile = false
      vim.bo[diff_buf].filetype = "diff"
      vim.api.nvim_buf_set_name(diff_buf, "[Nvibe Diff]")

      -- Set width
      vim.cmd("vertical resize " .. get_diff_width())

      -- Return to original window
      vim.api.nvim_set_current_win(current_win)
    end

    -- Update diff content
    if is_valid_window(diff_win) then
      local diff_buf = vim.api.nvim_win_get_buf(diff_win)
      local diff_lines = get_buffer_diff(current_buf)
      vim.bo[diff_buf].modifiable = true
      vim.api.nvim_buf_set_lines(diff_buf, 0, -1, false, diff_lines)
      vim.bo[diff_buf].modifiable = false
    end
  else
    -- Close diff window if no changes
    if is_valid_window(diff_win) then
      vim.api.nvim_win_close(diff_win, true)
      nvibe_windows.diff = nil
      nvibe_buffers.diff = nil
    end
  end
end

---Close all nvibe windows
function M.close()
  if not is_open then
    return
  end

  -- Close all tracked windows
  for name, win_id in pairs(nvibe_windows) do
    if is_valid_window(win_id) then
      pcall(vim.api.nvim_win_close, win_id, true)
    end
  end

  -- Reset state
  nvibe_windows = {}
  nvibe_buffers = {}
  diff_windows = {}
  is_open = false
  main_editor_win = nil

  -- Remove autocmds
  pcall(vim.api.nvim_del_augroup_by_name, "NvibeDiff")
  pcall(vim.api.nvim_del_augroup_by_name, "NvibeResize")
end

---Rebalance all nvibe window sizes
function M.rebalance()
  if not is_open then
    return
  end

  local width = get_terminal_width()
  local diff_width = get_diff_width()
  local bottom_height = math.floor(vim.o.lines * 0.2)

  -- Rebalance left panel windows
  for _, name in ipairs { "cursor_agent", "coderabbit" } do
    local win = nvibe_windows[name]
    if is_valid_window(win) then
      vim.api.nvim_win_set_width(win, width)
    end
  end

  -- Rebalance bottom panel windows
  for _, name in ipairs { "shell_left", "lazygit", "shell_right" } do
    local win = nvibe_windows[name]
    if is_valid_window(win) then
      vim.api.nvim_win_set_height(win, bottom_height)
    end
  end

  -- Rebalance lazygit width
  if is_valid_window(nvibe_windows.lazygit) then
    vim.api.nvim_win_set_width(nvibe_windows.lazygit, math.floor(vim.o.columns * 0.33))
  end

  -- Rebalance diff window
  if is_valid_window(nvibe_windows.diff) then
    vim.api.nvim_win_set_width(nvibe_windows.diff, diff_width)
  end
end

---Creates the terminal split layout with cursor-agent and coderabbit
---@return nil
function M.create_terminal_split()
  -- Check if NvChad term module is available
  if not nvchad_term then
    vim.notify(
      "Nvibe Error: nvchad.term module not available!\n\n"
        .. "Nvibe requires NvChad to function properly.\n"
        .. "Please install NvChad: https://github.com/NvChad/NvChad",
      vim.log.levels.ERROR,
      { title = "Nvibe - Missing Dependency" }
    )
    return
  end

  -- Store the main editor window
  main_editor_win = vim.api.nvim_get_current_win()

  -- Validate that required commands are executable
  local cursor_cmd_path = vim.fn.expand(config.cursor_agent_cmd:match("^%S+"))
  if vim.fn.executable(cursor_cmd_path) ~= 1 then
    vim.notify(
      "Nvibe Error: claude command not found!\n\n"
        .. "Command: "
        .. cursor_cmd_path
        .. "\n"
        .. "Please install claude or update the cursor_agent_cmd configuration.",
      vim.log.levels.ERROR,
      { title = "Nvibe - Command Not Found" }
    )
    return
  end

  local coderabbit_cmd_path = config.coderabbit_cmd:match("^%S+")
  if vim.fn.executable(coderabbit_cmd_path) ~= 1 then
    vim.notify(
      "Nvibe Error: coderabbit command not found!\n\n"
        .. "Command: "
        .. coderabbit_cmd_path
        .. "\n"
        .. "Please install coderabbit or update the coderabbit_cmd configuration.",
      vim.log.levels.ERROR,
      { title = "Nvibe - Command Not Found" }
    )
    return
  end

  -- Get the calculated width
  local width = get_terminal_width()

  -- Create vertical split to the left
  vim.cmd "leftabove vnew"

  -- Set the width
  vim.cmd("vertical resize " .. width)

  -- Create cursor-agent terminal in top-left using NvChad method
  local success, err = pcall(function()
    nvchad_term.new {
      pos = "sp",
      cmd = config.cursor_agent_cmd,
      size = 0.5,
    }
  end)

  if success then
    nvibe_windows.cursor_agent = vim.api.nvim_get_current_win()
    nvibe_buffers.cursor_agent = vim.api.nvim_get_current_buf()
  else
    vim.notify(
      "Nvibe Error: Failed to create cursor-agent terminal\n\n" .. "Command: " .. config.cursor_agent_cmd .. "\n" .. "Error: " .. tostring(err),
      vim.log.levels.ERROR,
      { title = "Nvibe - Terminal Creation Failed" }
    )
  end

  -- Create coderabbit terminal in bottom-left using NvChad method
  local success2, err2 = pcall(function()
    nvchad_term.new {
      pos = "sp",
      cmd = config.coderabbit_cmd,
      size = 0.5,
    }
  end)

  if success2 then
    nvibe_windows.coderabbit = vim.api.nvim_get_current_win()
    nvibe_buffers.coderabbit = vim.api.nvim_get_current_buf()
  else
    vim.notify(
      "Nvibe Error: Failed to create coderabbit terminal\n\n" .. "Command: " .. config.coderabbit_cmd .. "\n" .. "Error: " .. tostring(err2),
      vim.log.levels.ERROR,
      { title = "Nvibe - Terminal Creation Failed" }
    )
  end

  -- Close the empty buffer above cursor-agent
  vim.cmd "wincmd k"
  vim.cmd "wincmd k"
  vim.cmd "close"
  vim.cmd("vertical resize " .. width)

  -- Switch back to main window (right side)
  vim.cmd "wincmd l"

  -- Update main editor window reference after layout changes
  main_editor_win = vim.api.nvim_get_current_win()

  vim.cmd "belowright split"
  vim.cmd("resize " .. math.floor(vim.o.lines * 0.2))

  vim.cmd "belowright vnew"
  vim.cmd("vertical resize " .. math.floor(vim.o.columns * 0.33))

  -- Create lazygit terminal
  local success3, err3 = pcall(function()
    nvchad_term.new {
      pos = "sp",
      cmd = "lazygit",
      size = 0.2,
    }
  end)

  if success3 then
    nvibe_windows.lazygit = vim.api.nvim_get_current_win()
    nvibe_buffers.lazygit = vim.api.nvim_get_current_buf()
  else
    vim.notify(
      "Nvibe Error: Failed to create lazygit terminal\n\n" .. "Command: lazygit\n" .. "Error: " .. tostring(err3),
      vim.log.levels.ERROR,
      { title = "Nvibe - Terminal Creation Failed" }
    )
  end

  vim.cmd "wincmd k"
  vim.cmd "close"
  vim.cmd "wincmd h"
  vim.cmd("resize " .. math.floor(vim.o.lines * 0.2))

  vim.cmd "belowright vnew"

  local success4, err4 = pcall(function()
    nvchad_term.new {
      pos = "sp",
      cmd = vim.o.shell,
      size = 0.2,
    }
  end)

  if success4 then
    nvibe_windows.shell_right = vim.api.nvim_get_current_win()
    nvibe_buffers.shell_right = vim.api.nvim_get_current_buf()
  else
    vim.notify(
      "Nvibe Error: Failed to create shell terminal\n\n" .. "Shell: " .. vim.o.shell .. "\n" .. "Error: " .. tostring(err4),
      vim.log.levels.ERROR,
      { title = "Nvibe - Terminal Creation Failed" }
    )
  end

  vim.cmd "wincmd k"
  vim.cmd "close"
  vim.cmd "wincmd h"
  vim.cmd("resize " .. math.floor(vim.o.lines * 0.2))

  local success5, err5 = pcall(function()
    nvchad_term.new {
      pos = "sp",
      cmd = vim.o.shell,
      size = 0.2,
    }
  end)

  if success5 then
    nvibe_windows.shell_left = vim.api.nvim_get_current_win()
    nvibe_buffers.shell_left = vim.api.nvim_get_current_buf()
  else
    vim.notify(
      "Nvibe Error: Failed to create shell terminal\n\n" .. "Shell: " .. vim.o.shell .. "\n" .. "Error: " .. tostring(err5),
      vim.log.levels.ERROR,
      { title = "Nvibe - Terminal Creation Failed" }
    )
  end

  vim.cmd "wincmd k"
  vim.cmd "close"
  vim.cmd("resize " .. math.floor(vim.o.lines * 0.2))
  vim.cmd "wincmd k"

  vim.cmd "wincmd h"
  vim.cmd("vertical resize " .. width)
  vim.cmd "wincmd l"
  vim.cmd "stopinsert"

  -- Mark as open
  is_open = true

  -- Setup autocmds for diff pane and resize
  local augroup = vim.api.nvim_create_augroup("NvibeDiff", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "TextChangedI" }, {
    group = augroup,
    callback = function()
      vim.defer_fn(update_diff_pane, 100)
    end,
  })

  local resize_group = vim.api.nvim_create_augroup("NvibeResize", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = resize_group,
    callback = function()
      M.rebalance()
    end,
  })

  -- Initial diff check
  vim.defer_fn(update_diff_pane, 200)
end

---Toggle nvibe layout on/off
function M.toggle()
  if is_open then
    M.close()
  else
    M.create_terminal_split()
  end
end

---Initializes the Nvibe plugin with optional configuration
---@param opts NvibeConfig|nil Optional configuration table
---@return nil
function M.setup(opts)
  -- Check for NvChad dependency first and store the module
  local success, term_module = pcall(require, "nvchad.term")
  if not success then
    vim.notify(
      "Nvibe Setup Error: nvchad.term module not found!\n\n"
        .. "Nvibe requires NvChad to function properly.\n"
        .. "Please install NvChad: https://github.com/NvChad/NvChad\n\n"
        .. "Error: "
        .. tostring(term_module),
      vim.log.levels.ERROR,
      { title = "Nvibe - Missing Dependency" }
    )
    return
  end

  -- Store the module for reuse
  nvchad_term = term_module

  if opts then
    config = vim.tbl_deep_extend("force", config, opts)
  end

  -- Create keybinding to toggle on <leader>|
  vim.keymap.set("n", "<leader>|", function()
    -- Only run if we're not in a terminal buffer already (for create), or allow toggle
    if is_open or vim.bo.buftype ~= "terminal" then
      M.toggle()
    end
  end, { desc = "Nvibe: Toggle terminal split layout" })
end

return M
