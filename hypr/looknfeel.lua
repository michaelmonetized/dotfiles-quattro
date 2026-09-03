-- Change the default Omarchy look'n'feel.

-- Default rule is 0.985 / 0.96. Nudge the focused window a hair more open.
o.window({ tag = "default-opacity" }, { opacity = "0.90 0.86" })

-- Omasnap capture/annotation overlay: no animation, never screen-shared.
hl.layer_rule({
	match = { namespace = "^omasnap$" },
	no_anim = true,
	animation = "none",
	no_screen_share = true,
})

-- Stock Omarchy 4.0.2 drops *.lua from git-cloned themes, so Hurleyus
-- hyprland.lua never reaches Hyprland there. This file always loads.
hl.config({
	general = {
		gaps_in = 20,
		gaps_out = 20,
	},
	decoration = {
		rounding = 20,
	},
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })
