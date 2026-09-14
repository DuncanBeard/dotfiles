-- ============================================================================
-- DUNCAN'S WEZTERM -- Rashil's layout, adapted for Windows and commented to tune.
-- Inspiration: https://rashil2000.me/blogs/tune-wezterm
-- Source: https://github.com/rashil2000/dotfiles/tree/master/wezterm
-- Snapshot: 992a8b2b353bc30a6e31d5784e5b0059814af791
--
-- START HERE: change the values in `tune` below, save, and WezTerm hot-reloads.
-- Ctrl+Shift+R = reload; Ctrl+Shift+L = debug overlay (Lua errors/REPL).
-- Ctrl+Shift+, = edit this file in Notepad. Most changes affect existing windows;
-- shell, initial dimensions and shell integration take effect in NEW tabs/windows.
--
-- Supporting code: ~/.config/wezterm/tuned/{appearance,segments,keys}.lua
-- Guide + test command: ~/.config/wezterm/tuned/README.md
-- Original config backup: ~/.wezterm.lua.before-rashil.bak
-- ============================================================================
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- This table is OUR configuration, not WezTerm's schema. Unknown fields in
-- `config` error out; keep custom preferences here and map them below.
local tune = {
  -- THEME: 'auto' follows Windows app appearance, 'dark'/'light' force a theme.
  -- Palettes are Rashil's modified Bluloco (pure black/white backgrounds).
  -- Change exact foreground, ANSI, cursor and selection colors in appearance.lua.
  theme = 'auto',
  gradient_strength = 0.15, -- 0 = flat; 0.15 = article; larger = more contrast.
  powerline = true,        -- Only used if custom bars below are re-enabled.
  custom_tab_bar = false,  -- false = original WezTerm GUI tabs; true = article wedges.
  show_status_bar = false, -- false = clean tab row; no RAM/clock/context strip or polling.

  -- FONT: use the installed Hack Nerd Font Mono; it includes the
  -- private-use icons/wedges. Alternatives installed here: 'JetBrainsMono NF',
  -- 'FiraCode Nerd Font', 'Hack Nerd Font'. Size is points, NOT pixels.
  font = 'Hack Nerd Font Mono',
  font_size = 12.0,
  line_height = 1.0,       -- 1.1 adds breathing room; also changes screen capacity.

  -- WINDOW: keep the native title bar for easy dragging and window controls.
  -- 'RESIZE' hides it for the article's borderless look; 'TITLE | RESIZE'
  -- retains minimize/maximize/close above the custom tab and status bars.
  window_decorations = 'TITLE | RESIZE',
  initial_cols = 90,       -- New windows only; resizing a current window wins.
  initial_rows = 30,
  tab_bar_at_bottom = false,
  tab_max_width = 32,      -- Display cells per tab, including index and wedge.
  scrollback_lines = 10000,
  dynamic_scrollbar = true, -- Hide when no history or when a TUI uses alt screen.
  -- Scrollbar transitions reconfigure the window. If switching splits feels
  -- slow, set this false; old runtime overrides are cleared automatically.
  max_fps = 120,           -- Article value; reduce to 60 to limit rendering work.
  inactive_pane_brightness = 0.9, -- Slightly dim splits without keyboard focus.

  -- STATUS: cheap UI updates vs more expensive cached host measurements.
  -- One second keeps the clock responsive; native processes run at most once
  -- per 30 seconds, not every time you resize/focus a window.
  status_update_interval = 1000, -- Milliseconds.
  external_refresh_seconds = 30,
  status_min_columns = 75, -- Below this, omit host tools and keep a short clock.
  show_date = true,
  date_format = '%a, %b %d', -- Windows-safe strftime; %-d is Unix-specific.
  show_time = true,
  time_format = '%H:%M',   -- '%I:%M %p' for 12-hour time; '%H:%M:%S' for seconds.
  show_memory = true,      -- Windows RAM, replacing upstream's absent Starship.
  show_kubernetes = true,  -- LOCAL kubectl context, never remote pane context.
  show_spotify = false,    -- Requires spotify_player CLI, NOT Spotify desktop.
  segment_max_width = 28,  -- Bound long cluster/song names so tabs stay usable.

  -- EXECUTABLES: full paths avoid GUI PATH differences and .cmd shim issues.
  -- Missing optional status tools are hidden quietly, not shown as '1N/A'.
  powershell = 'C:/Program Files/PowerShell/7/pwsh.exe',
  kubectl = 'C:/Program Files/Docker/Docker/resources/bin/kubectl.exe',
  spotify_player = 'spotify_player',
  git_bash = 'C:/Program Files/Git/bin/bash.exe',
  k9s = 'C:/Users/duncanbeard/AppData/Local/Microsoft/WinGet/Links/k9s.exe',
  enable_k9s_shortcut = true,

  -- SHELL INTEGRATION: these bindings need shell-emitted OSC 133 semantic zones.
  -- They do NOT install a prompt wrapper. Your Oh My Posh profile is preserved.
  -- See README for its native `shell_integration: true` / `pwd: osc7` opt-in.
  semantic_bindings = true,
}

-- ============================================================================
-- BASIC WEZTERM SETTINGS (independent of the article's rendering helpers)
-- ============================================================================
-- KEEP WebGPU: this machine previously failed to create windows with OpenGL.
-- Do not copy upstream's implicit renderer default over this working setting.
config.front_end = 'WebGpu'
-- Keep your PowerShell profile (Oh My Posh, aliases, completions). No -NoProfile.
config.default_prog = { tune.powershell }
config.font = wezterm.font_with_fallback { tune.font, 'Cascadia Code', 'Consolas' }
config.font_size = tune.font_size
config.line_height = tune.line_height
config.window_decorations = tune.window_decorations
config.initial_cols = tune.initial_cols
config.initial_rows = tune.initial_rows
config.scrollback_lines = tune.scrollback_lines
config.max_fps = tune.max_fps
config.inactive_pane_hsb = { brightness = tune.inactive_pane_brightness }
config.switch_to_last_active_tab_when_closing_tab = true
config.automatically_reload_config = true

-- Restore the original GUI tab bar. The article's cell-rendered gradient
-- version is still available by setting custom_tab_bar = true above.
config.use_fancy_tab_bar = not tune.custom_tab_bar
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false -- Keep the status visible with 1 tab.
config.tab_bar_at_bottom = tune.tab_bar_at_bottom
config.tab_max_width = tune.tab_max_width
config.enable_scroll_bar = false -- Runtime handler enables only when useful.
config.status_update_interval = tune.status_update_interval

-- No automatic unix_domains, SSH endpoints, WSL defaults, or startup programs:
-- the article author's mux server and launch menu are not this machine's setup.
-- Existing mux/WSL sessions are neither started nor stopped by this config.
-- No PowerShell update-check suppression: retain your current behavior.

local appearance = require 'tuned.appearance'
appearance.apply(config, tune)
require('tuned.segments').apply(config, tune)
require('tuned.keys').apply(config, tune)

return config
