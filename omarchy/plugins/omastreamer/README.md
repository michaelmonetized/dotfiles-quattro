# Omastreamer

OBS controls in the Omarchy bar. Hyper chords switch scenes, stream, record, and mute whether OBS is focused or not.

Wayland will not deliver OBS's own hotkeys to an unfocused window. This plugin owns the chords in Hyprland and talks to obs-websocket.

## Keys

Hyper is hold-Left-Control (Super+Ctrl+Alt+Shift via keyd).

| Chord | Action |
|---|---|
| Hyper+1…9, Hyper+0 | Scene 1–10 (top of the OBS scenes dock is 1) |
| Hyper+S | Toggle streaming |
| Hyper+R | Toggle recording |
| Hyper+F5 | Mute / unmute every audio input |

Left click the bar chip for the same controls. Right click cycles scenes. Middle click mutes.

## OBS websocket

Enable **Tools → WebSocket Server Settings** (port 4455) and restart OBS once. The plugin reads the password from `~/.config/obs-studio/plugin_config/obs-websocket/config.json`.
