-- Keylens · ~/.config/keylens.lua
-- Return a flat table. Omitted values use defaults. Saved panel settings win.
-- Clear panel overrides in Advanced to restore this file's preferences.
return {
  mode = "desktop",         -- desktop | stream | both
  filter = "all",           -- all | shortcuts | modified
  style = "keycaps",        -- keycaps | minimal
  labels = "symbols",       -- symbols | words
  font = "auto",            -- current Omarchy monospace font, or a family name
  font_size = 30,
  background = "auto",      -- auto or #RRGGBB
  foreground = "auto",
  accent = "auto",
  border_color = "auto",
  background_opacity = 0.92,
  border_width = 1,
  radius = 16,
  padding = 18,
  gap = 8,
  shadow = true,
  hold_ms = 1200,
  fade_ms = 160,
  history = 4,
  modifiers = true,
  mouse = true,
  scroll = false,
  double_tap_ms = 350,
  monitor = "",             -- first display, or an output name such as eDP-1
  x = 64, y = 820,           -- logical pixels from the monitor's top-left
  layout = "auto",          -- Hyprland XKB rules; falls back to us elsewhere
  variant = "",
  options = "",
  excluded_apps = "keepassxc,1password,bitwarden,org.gnome.seahorse",
  stream_width = 1280,
  stream_height = 240,
  stream_align = "center",  -- left | center | right
  port = 18273,             -- loopback only
}
