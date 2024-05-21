local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config = {
		color_scheme = "Catppuccin Mocha", -- or Macchiato, Frappe, Latte
		automatically_reload_config = true,
		default_cursor_style = 'BlinkingBlock',
		hide_tab_bar_if_only_one_tab = false,
		pane_focus_follows_mouse = true,
		scrollback_lines = 10000,
		use_fancy_tab_bar = false,
		window_frame = {
			inactive_titlebar_bg = '#1e1e2e',
			active_titlebar_bg = '#181825',
			inactive_titlebar_fg = '#cccccc',
			active_titlebar_fg = '#ffffff',
			inactive_titlebar_border_bottom = '#2b2042',
			active_titlebar_border_bottom = '#2b2042',
			button_fg = '#cccccc',
			button_bg = '#2b2042',
			button_hover_fg = '#ffffff',
			button_hover_bg = '#3b3052',
			font = require('wezterm').font 'Roboto',
		},
		inactive_pane_hsb = {
			saturation = 0.9,
			brightness = 0.8,
		}
}

return config
