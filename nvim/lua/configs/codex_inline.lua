local M = {}

local ns = vim.api.nvim_create_namespace("remote_inline")

local state = {
  enabled = false,
  reasoning_enabled = false,
  supermaven_was_running = nil,
  timer = nil,
  job = nil,
  mark = nil,
  suggestion = "",
  request_id = 0,
}

local log_file = vim.fn.stdpath("state") .. "/openrouter-inline.log"

local function log(message)
  local line = os.date("!%Y-%m-%dT%H:%M:%SZ") .. " " .. message
  pcall(vim.fn.writefile, { line }, log_file, "a")
end

local function supermaven_stop()
  local ok, api = pcall(require, "supermaven-nvim.api")
  if not ok then
    return
  end
  if state.supermaven_was_running == nil and api.is_running then
    state.supermaven_was_running = api.is_running()
  end
  if api.stop then
    pcall(api.stop)
  end
end

local function supermaven_restore()
  local should_restore = state.supermaven_was_running
  state.supermaven_was_running = nil
  if not should_restore then
    return
  end
  local ok, api = pcall(require, "supermaven-nvim.api")
  if ok and api.start then
    pcall(api.start)
  end
end

local function clear()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  state.mark = nil
  state.suggestion = ""
end

local function strip_completion(text)
  if type(text) ~= "string" then
    log("non-string completion type=" .. type(text))
    return ""
  end
  text = text or ""
  text = text:gsub("^%s*```[%w_-]*%s*", "")
  text = text:gsub("%s*```%s*$", "")
  text = text:gsub("^%s*#+%s*File extension:[^\n]*\n?", "")
  text = text:gsub("^%s*[Ww]e need to[^\n]*\n?", "")
  text = text:gsub("^%s*[Tt]he cursor[^\n]*\n?", "")
  text = text:gsub("^%s*[Tt]hus[^\n]*\n?", "")
  text = text:gsub("^%s*[Ee]xplanation:[^\n]*\n?", "")
  text = text:gsub("^%s*[Aa]nswer:[ \t]*", "")
  text = text:gsub("^%s*[Cc]ompletion:[ \t]*", "")
  text = text:gsub("^%s+", "")
  text = text:gsub("%s+$", "")
  return text
end

local function build_prompt(bufnr, row, col)
  local filetype = vim.bo[bufnr].filetype
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local prefix_start = math.max(0, row - 80)
  local suffix_end = math.min(line_count, row + 30)

  local before = vim.api.nvim_buf_get_lines(bufnr, prefix_start, row, false)
  local current = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  before[#before + 1] = current:sub(1, col)

  local after = { current:sub(col + 1) }
  vim.list_extend(after, vim.api.nvim_buf_get_lines(bufnr, row + 1, suffix_end, false))

  return table.concat({
    "Fill the <CURSOR> hole in the file.",
    "Return ONLY raw text that should replace <CURSOR>.",
    "Do not explain. Do not mention the filetype. Do not restate the prompt.",
    "Do not use markdown fences unless those fences are literally the completion.",
    "Prefer a short continuation. If unsure, return an empty string.",
    "",
    "File: " .. filename,
    "Filetype: " .. filetype,
    "",
    "<file>",
    table.concat(before, "\n"),
    "<CURSOR>",
    table.concat(after, "\n"),
    "</file>",
  }, "\n")
end

local function json_escape(value)
  return vim.fn.json_encode(value)
end

local function build_openrouter_body(prompt)
  local body = {
    model = "openrouter/free",
    temperature = 0,
    max_tokens = 4096,
    stop = {
      "</file>",
      "<after_cursor>",
      "Explanation:",
      "We need to",
      "The cursor",
    },
    messages = {
      {
        role = "system",
        content = "You are an autocomplete engine. Output only raw completion text. Never explain your answer.",
      },
      {
        role = "user",
        content = prompt,
      },
    },
  }
  if state.reasoning_enabled then
    body.reasoning = { effort = "low" }
  else
    body.reasoning = { exclude = true }
  end
  return vim.fn.json_encode(body)
end

local function unquote_env_value(value)
  value = vim.trim(value or "")
  value = value:gsub("^export%s+", "")
  local quoted = value:match('^"(.*)"$') or value:match("^'(.*)'$")
  if quoted then
    return quoted
  end
  return value:gsub("%s+#.*$", "")
end

local function read_env_file_key(path, key)
  local expanded = vim.fn.expand(path)
  if vim.fn.filereadable(expanded) ~= 1 then
    log("env file missing: " .. expanded)
    return nil
  end

  for _, line in ipairs(vim.fn.readfile(expanded)) do
    local value = line:match("^%s*export%s+" .. key .. "%s*=%s*(.+)%s*$")
      or line:match("^%s*" .. key .. "%s*=%s*(.+)%s*$")
    if value then
      value = unquote_env_value(value)
      if value ~= "" then
        log("loaded " .. key .. " from " .. expanded)
        return value
      end
    end
  end
  log("key " .. key .. " not found in " .. expanded)
  return nil
end

local function get_openrouter_api_key()
  if vim.env.OPENROUTER_API_KEY and vim.env.OPENROUTER_API_KEY ~= "" then
    log("using inherited OPENROUTER_API_KEY")
    return vim.env.OPENROUTER_API_KEY
  end

  return read_env_file_key("~/.zshenv", "OPENROUTER_API_KEY")
    or read_env_file_key("~/Projects/.env.shared", "OPENROUTER_API_KEY")
end

local function render(bufnr, row, col, text)
  clear()
  text = strip_completion(text)
  if text == "" then
    log("empty completion")
    return
  end

  local first_line = text:match("^[^\n\r]*") or text
  if first_line == "" then
    log("empty first line")
    return
  end

  log("render completion len=" .. tostring(#text))
  state.suggestion = text
  state.mark = vim.api.nvim_buf_set_extmark(bufnr, ns, row, col, {
    virt_text = { { first_line, "Comment" } },
    virt_text_pos = "inline",
    hl_mode = "combine",
    invalidate = true,
  })
end

local function request_completion()
  if not state.enabled or vim.fn.mode() ~= "i" then
    log("skip request: disabled or not insert mode")
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].readonly then
    log("skip request: unsupported buffer")
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]
  local current = vim.api.nvim_get_current_line()
  if col < 2 or current:sub(1, col):match("^%s*$") then
    clear()
    log("skip request: too little prefix")
    return
  end

  if state.job then
    vim.fn.jobstop(state.job)
    state.job = nil
  end

  local request_id = state.request_id + 1
  state.request_id = request_id
  local output = {}
  local prompt = build_prompt(bufnr, row, col)
  local api_key = get_openrouter_api_key()

  if not api_key or api_key == "" then
    log("missing OPENROUTER_API_KEY")
    vim.notify("OPENROUTER_API_KEY is not set", vim.log.levels.WARN)
    return
  end

  log("start request id=" .. request_id .. " row=" .. row .. " col=" .. col)

  state.job = vim.fn.jobstart({
    "curl",
    "-sS",
    "--max-time",
    "8",
    "https://openrouter.ai/api/v1/chat/completions",
    "-H",
    "Authorization: Bearer " .. api_key,
    "-H",
    "Content-Type: application/json",
    "-H",
    "HTTP-Referer: http://localhost/nvim",
    "-H",
    "X-Title: Neovim Remote Inline",
    "-d",
    build_openrouter_body(prompt),
  }, {
    cwd = vim.fn.getcwd(),
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(output, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        local stderr = table.concat(data, "\n")
        if stderr ~= "" then
          log("curl stderr: " .. stderr)
        end
      end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        state.job = nil
        if not state.enabled or request_id ~= state.request_id or code ~= 0 then
          log("drop response id=" .. request_id .. " code=" .. tostring(code) .. " enabled=" .. tostring(state.enabled) .. " current_id=" .. tostring(state.request_id))
          return
        end
        if not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_get_current_buf() ~= bufnr then
          log("drop response: buffer changed")
          return
        end
        if vim.fn.mode() ~= "i" then
          log("drop response: not insert mode")
          return
        end
        local now = vim.api.nvim_win_get_cursor(0)
        if now[1] - 1 ~= row or now[2] ~= col then
          log("drop response: cursor moved")
          return
        end
        local ok, decoded = pcall(vim.fn.json_decode, table.concat(output, "\n"))
        if not ok or type(decoded) ~= "table" then
          log("json decode failed: " .. table.concat(output, "\n"):sub(1, 500))
          return
        end
        if decoded.error then
          log("openrouter error: " .. vim.inspect(decoded.error):gsub("\n", " "))
        end
        local choice = decoded.choices and decoded.choices[1]
        local message = choice and choice.message
        local content = message and message.content or ""
        if type(content) ~= "string" then
          log("unexpected content type=" .. type(content) .. " value=" .. vim.inspect(content):gsub("\n", " "):sub(1, 500))
          content = ""
        end
        log("response parsed has_choice=" .. tostring(choice ~= nil))
        render(bufnr, row, col, content)
      end)
    end,
  })

  if state.job <= 0 then
    state.job = nil
    log("jobstart failed")
    return
  end
end

local function schedule()
  if not state.enabled then
    log("schedule ignored: disabled")
    return
  end
  clear()
  if state.timer then
    state.timer:stop()
  else
    state.timer = vim.uv.new_timer()
  end
  log("schedule request")
  state.timer:start(300, 0, vim.schedule_wrap(request_completion))
end

function M.accept()
  if state.suggestion == "" then
    return ""
  end
  local text = state.suggestion
  clear()
  return text
end

function M.enable()
  state.enabled = true
  log("enabled")
  supermaven_stop()
  vim.notify("OpenRouter inline completion enabled", vim.log.levels.INFO)
end

function M.disable()
  state.enabled = false
  if state.job then
    vim.fn.jobstop(state.job)
    state.job = nil
  end
  clear()
  supermaven_restore()
  log("disabled")
  vim.notify("OpenRouter inline completion disabled", vim.log.levels.INFO)
end

function M.toggle()
  if state.enabled then
    M.disable()
  else
    M.enable()
  end
end

function M.reasoning_enable()
  state.reasoning_enabled = true
  log("reasoning enabled")
  vim.notify("OpenRouter inline reasoning enabled", vim.log.levels.INFO)
end

function M.reasoning_disable()
  state.reasoning_enabled = false
  log("reasoning disabled")
  vim.notify("OpenRouter inline reasoning disabled", vim.log.levels.INFO)
end

function M.reasoning_toggle()
  if state.reasoning_enabled then
    M.reasoning_disable()
  else
    M.reasoning_enable()
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("openrouter_inline", { clear = true })

  vim.api.nvim_create_user_command("CodexInlineEnable", M.enable, {})
  vim.api.nvim_create_user_command("CodexInlineDisable", M.disable, {})
  vim.api.nvim_create_user_command("CodexInlineToggle", M.toggle, {})
  vim.api.nvim_create_user_command("OpenRouterInlineEnable", M.enable, {})
  vim.api.nvim_create_user_command("OpenRouterInlineDisable", M.disable, {})
  vim.api.nvim_create_user_command("OpenRouterInlineToggle", M.toggle, {})
  vim.api.nvim_create_user_command("OpenRouterAutoComplete", M.enable, {})
  vim.api.nvim_create_user_command("OpenRouterAutocomplete", M.enable, {})
  vim.api.nvim_create_user_command("OpenRouterReasoningEnable", M.reasoning_enable, {})
  vim.api.nvim_create_user_command("OpenRouterReasoningDisable", M.reasoning_disable, {})
  vim.api.nvim_create_user_command("OpenRouterReasoningToggle", M.reasoning_toggle, {})
  vim.api.nvim_create_user_command("OpenRouterInlineStatus", function()
    local status = state.enabled and "enabled" or "disabled"
    local reasoning = state.reasoning_enabled and "reasoning on" or "reasoning off"
    vim.notify("OpenRouter inline completion is " .. status .. " (" .. reasoning .. ")", vim.log.levels.INFO)
    log("status requested: " .. status .. ", " .. reasoning)
  end, {})
  vim.api.nvim_create_user_command("OpenRouterInlineLog", function()
    vim.cmd("tabnew " .. vim.fn.fnameescape(log_file))
  end, {})
  vim.api.nvim_create_user_command("OpenRouterInlineClearLog", function()
    vim.fn.writefile({}, log_file)
    vim.notify("OpenRouter inline log cleared", vim.log.levels.INFO)
  end, {})

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
    group = group,
    callback = schedule,
  })
  vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave" }, {
    group = group,
    callback = clear,
  })

  vim.keymap.set("i", "<Tab>", function()
    local codex = require "configs.codex_inline"
    if codex.is_enabled() and codex.has_suggestion() then
      return codex.accept()
    end
    return vim.api.nvim_replace_termcodes("<Tab>", true, false, true)
  end, { expr = true, silent = true, desc = "Accept remote inline suggestion or insert tab" })
end

function M.is_enabled()
  return state.enabled
end

function M.has_suggestion()
  return state.suggestion ~= ""
end

return M
