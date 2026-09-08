-- Capture existing dispatchers so browser overrides retain desktop behavior.
local original_bind = hl.bind
local recorded = {}
local function canonical(key)
  local bits = {}; for part in key:gmatch('[^+]+') do bits[#bits+1] = part:match('^%s*(.-)%s*$'):upper() end
  local last = table.remove(bits); table.sort(bits); return table.concat(bits, '+') .. '+' .. last
end
hl.bind = function(key, dispatcher, opts)
  recorded[canonical(key)] = dispatcher
  return original_bind(key, dispatcher, opts)
end
local function chord(value)
  local mods, key = value:match('^(.*)%s+%+%s+(%S+)$')
  if not key then mods = ''; key = value end
  hl.dispatch(hl.dsp.send_key_state({mods=mods,key=key,state='down'}))
  hl.timer(function() hl.dispatch(hl.dsp.send_key_state({mods=mods,key=key,state='up'})) end, {timeout=50,type='oneshot'})
end
return { install = function()
  hl.bind = original_bind
  local path = os.getenv('HOME') .. '/.config/browser-keys/bindings.lua'
  local loaded, bindings = pcall(dofile, path)
  if not loaded then return end
  for _, entry in ipairs(bindings) do
    local fallback = recorded[canonical(entry.key)]
    hl.unbind(entry.key)
    o.bind(entry.key, 'Browser: ' .. (entry.action or entry.shortcut), function()
      local window = hl.get_active_window()
      local class = window and window.class or ''
      local browser = nil
      if class == 'chromium' or class == 'google-chrome' or class == 'Google-chrome' then browser = 'chrome'
      elseif class == 'zen' or class == 'zen-browser' or class == 'firefox' then browser = 'zen' end
      if browser then
        if entry.shortcut then chord(entry.shortcut)
        else hl.exec_cmd(os.getenv('HOME') .. '/.config/desktop/bin/browser-keys-send ' .. browser .. ' ' .. entry.action) end
      elseif fallback then
        if type(fallback) == 'function' then fallback() else hl.dispatch(fallback) end
      else chord(entry.key) end
    end)
  end
end }
