-- Appearance and smart tab titles, adapted from Rashil's WezTerm configuration.
-- Source: https://rashil2000.me/blogs/tune-wezterm
-- Upstream wezterm/ snapshot: 992a8b2b353bc30a6e31d5784e5b0059814af791
-- Normal tuning belongs in ~/.wezterm.lua; edit this file for deeper changes.
local wezterm = require 'wezterm'
local M = {}

-- These are Rashil's modified Bluloco palettes: pure black/white backgrounds,
-- not precisely the stock 'Bluloco Dark'/'Bluloco Light' schemes in the article.
-- ANSI order: black, red, green, yellow, blue, magenta, cyan, white.
local palettes = {
  dark = {
    foreground = '#b9c0cb', background = '#000000',
    cursor_bg = '#ffcc00', cursor_border = '#ffcc00', cursor_fg = '#282c34',
    selection_bg = '#b9c0ca', selection_fg = '#272b33',
    ansi = { '#41444d', '#fc2f52', '#25a45c', '#ff936a', '#3476ff', '#7a82da', '#4483aa', '#cdd4e0' },
    brights = { '#8f9aae', '#ff6480', '#3fc56b', '#f9c859', '#10b1fe', '#ff78f8', '#5fb9bc', '#ffffff' },
    split = '#777777', scrollbar_thumb = '#2b2042',
  },
  light = {
    foreground = '#373a41', background = '#ffffff',
    cursor_bg = '#f32759', cursor_border = '#f32759', cursor_fg = '#ffffff',
    selection_bg = '#daf0ff', selection_fg = '#373a41',
    ansi = { '#373a41', '#d52753', '#23974a', '#df631c', '#275fe4', '#823ff1', '#27618d', '#babbc2' },
    brights = { '#676a77', '#ff6480', '#3cbc66', '#c5a332', '#0099e1', '#ce33c0', '#6d93bb', '#d3d3d3' },
    split = '#777777', scrollbar_thumb = '#f0f0f0',
  },
}

function M.is_dark(settings)
  if settings.theme ~= 'auto' then return settings.theme == 'dark' end
  -- CLI validation has no GUI/appearance; use a deterministic dark fallback.
  local appearance = (wezterm.gui and wezterm.gui.get_appearance()) or 'Dark'
  return appearance:find('Dark', 1, true) ~= nil
end

function M.palette(settings)
  local dark = M.is_dark(settings)
  local p = palettes[dark and 'dark' or 'light']
  -- Palette foreground/background above are also used by our custom renderer.
  -- Active and hover emphasis is set explicitly there; otherwise custom tab
  -- formatting can mask the built-in active_tab colors/styles.
  p.tab_bar = {
    background = p.background,
    active_tab = { bg_color = dark and '#2b2042' or '#f0f0f0', fg_color = p.foreground, intensity = 'Bold', italic = true },
    inactive_tab = { bg_color = p.background, fg_color = p.foreground },
    inactive_tab_hover = { bg_color = dark and '#3b3052' or '#e4e4e4', fg_color = p.foreground, italic = true, underline = 'Single' },
    new_tab = { bg_color = p.background, fg_color = '#808080' },
    new_tab_hover = { bg_color = dark and '#3b3052' or '#e4e4e4', fg_color = p.foreground, intensity = 'Bold' },
  }
  return p
end

-- Mirror the gradient: tabs get darker->lighter from left to right in dark
-- mode, status segments get lighter->darker. Light mode reverses luminance.
function M.gradient(background, count, settings, reverse)
  if count <= 0 then return {} end
  local base = wezterm.color.parse(background)
  local edge = M.is_dark(settings) and base:lighten(settings.gradient_strength)
    or base:darken(settings.gradient_strength)
  -- Avoid asking the gradient sampler to interpolate a one-element sequence.
  if count == 1 then return { tostring(edge) } end
  return wezterm.color.gradient({
    orientation = 'Horizontal',
    colors = reverse and { edge, base } or { base, edge },
  }, count)
end

local shells = { pwsh=true, powershell=true, cmd=true, bash=true, zsh=true,
  fish=true, sh=true, csh=true, tcsh=true, nu=true, elvish=true, xonsh=true }
local function basename(path)
  return (path or ''):gsub('.*[/\\]', ''):gsub('%.[eE][xX][eE]$', '')
end
local function first(a, b) return (a and a ~= '') and a or (b or '') end

local function title_for(tab)
  -- Preference order preserves explicit `wezterm cli set-tab-title` titles.
  -- For ordinary shells use OSC 1337 WEZTERM_CMD if emitted by the shell;
  -- otherwise process/title information remains a useful fallback. We do not
  -- pretend a remote WSL/SSH process is visible when WezTerm only sees wsl/ssh.
  if tab.tab_title and tab.tab_title ~= '' then return tab.tab_title end
  local pane = tab.active_pane or {}
  local title, process = pane.title or '', basename(pane.foreground_process_name)
  local command = (pane.user_vars or {}).WEZTERM_CMD or ''
  if title == '' then return first(command, first(process, 'WezTerm')) end
  if shells[basename(title):lower()] then
    return first(command, first(process, basename(title)))
  end
  return title:gsub('%.[eE][xX][eE]$', '')
end

local function with_progress(pane, title, foreground, palette)
  -- Stable 20240203 has no progress field. Newer builds may provide a string
  -- ('None'/'Indeterminate') or a tagged table. Type-check before indexing:
  -- the blog's unguarded progress.Percentage can break for string variants.
  -- Reading a nonexistent field on older PaneInformation userdata raises an
  -- error (it is not a plain Lua table). Protect the read as well as its type.
  local ok, progress = pcall(function() return pane and pane.progress end)
  if not ok then return title, foreground end
  if progress == 'Indeterminate' then return '~ ' .. title, palette.ansi[3] end
  if type(progress) == 'table' then
    if type(progress.Percentage) == 'number' then
      return string.format('%d%% %s', math.floor(progress.Percentage), title), palette.ansi[3]
    elseif type(progress.Error) == 'number' then
      return string.format('%d%% %s', math.floor(progress.Error), title), palette.ansi[2]
    end
  end
  return title, foreground
end

function M.apply(config, settings)
  config.colors = M.palette(settings)
  config.command_palette_bg_color = config.colors.tab_bar.active_tab.bg_color
  config.command_palette_fg_color = config.colors.foreground
  if settings.custom_tab_bar == false then
    -- Leave GUI tab titles and colors to WezTerm, not our Powerline renderer.
    config.colors.tab_bar = nil
    return
  end

  -- format-tab-title must be fast: do not spawn commands here. WezTerm supplies
  -- snapshot data (tab.active_pane is PaneInformation, NOT a live Pane object).
  wezterm.on('format-tab-title', function(tab, tabs, _, effective, hover, max_width)
    local p = effective.resolved_palette
    local count = math.max(1, #tabs)
    local gradient = M.gradient(p.background, count, settings, false)
    local index = math.min((tab.tab_index or 0) + 1, count)
    local background = gradient[index]
    local next_background = gradient[index + 1] or p.tab_bar.background
    local title, foreground = with_progress(tab.active_pane, title_for(tab), p.foreground, p)
    local label = string.format('%d: %s', (tab.tab_index or 0) + 1, title)
    -- Reserve two spaces and a one-cell Powerline wedge. truncate_right counts
    -- display cells correctly for emoji/CJK, unlike string.sub's byte slicing.
    if max_width < 3 then return { { Text = wezterm.truncate_right(label, max_width) } } end
    label = wezterm.truncate_right(label, max_width - 3)
    return {
      { Background = { Color = background } }, { Foreground = { Color = foreground } },
      { Attribute = { Intensity = tab.is_active and 'Bold' or 'Normal' } },
      { Attribute = { Italic = tab.is_active or hover } },
      { Attribute = { Underline = hover and 'Single' or 'None' } },
      { Text = ' ' .. label .. ' ' },
      { Background = { Color = next_background } }, { Foreground = { Color = background } },
      { Text = settings.powerline and '\u{e0b0}' or '|' },
    }
  end)
end
return M
