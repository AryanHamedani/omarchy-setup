-- WezTerm: kept alongside Ghostty because it renders Persian/RTL text (BiDi); Ghostty can't.
local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- BiDi: reorder RTL runs, paragraph direction auto with LTR fallback
config.bidi_enabled = true
config.bidi_direction = "AutoLeftToRight"

config.font = wezterm.font_with_fallback({ "JetBrainsMono Nerd Font", "Vazir Code" })
config.font_size = 8

-- Colors from the active Omarchy theme's ghostty.conf, so theme switches carry over
local theme = wezterm.home_dir .. "/.local/state/omarchy/current/theme/ghostty.conf"
wezterm.add_to_config_reload_watch_list(theme)
local ok, lines = pcall(io.lines, theme)
if ok then
  local colors, ansi, brights = {}, {}, {}
  for line in lines do
    local idx, hex = line:match("^palette%s*=%s*(%d+)=(#%x+)")
    if idx then
      idx = tonumber(idx)
      if idx < 8 then ansi[idx + 1] = hex else brights[idx - 7] = hex end
    else
      local key, val = line:match("^([%w-]+)%s*=%s*(#%x+)")
      local map = {
        ["background"] = "background", ["foreground"] = "foreground",
        ["cursor-color"] = "cursor_bg", ["selection-background"] = "selection_bg",
        ["selection-foreground"] = "selection_fg",
      }
      if key and map[key] then colors[map[key]] = val end
    end
  end
  colors.ansi, colors.brights = ansi, brights
  config.colors = colors
end

config.window_padding = { left = 14, right = 14, top = 14, bottom = 14 }
config.enable_tab_bar = false
config.window_close_confirmation = "NeverPrompt"
config.default_cursor_style = "SteadyBlock"
-- Match Ghostty's Shift+Enter (CSI-u) so Claude Code can tell it apart from Enter
config.keys = {
  { key = "Enter", mods = "SHIFT", action = wezterm.action.SendString("\x1b[13;2u") },
}

return config
