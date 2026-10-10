-- KeyCastr-style overlay for streams. Float + pin so it stays on top.
-- Leave focus and decorations alone so clickable mode can drag the titlebar
-- (or Super + left-drag).
o.window({
  class = "(showmethekey-gtk|one.alynx.showmethekey)",
  title = "Floating Window - Show Me The Key",
}, {
  float = true,
  pin = true,
  opacity = "1.0 override 1.0 override 1.0 override",
  tag = "-default-opacity",
})

o.window({
  class = "(showmethekey-gtk|one.alynx.showmethekey)",
  title = "negative:Floating Window - Show Me The Key",
}, {
  float = true,
  center = true,
})
