-- Shortcuts and mouse behavior. The config keeps WezTerm's default bindings:
-- this table adds/overrides only named combinations, not the entire key map.
local wezterm = require 'wezterm'
local act = wezterm.action
local M = {}

function M.apply(config, settings)
  config.keys = {
    -- Article idea: one shortcut to edit terminal settings. Adapted to Notepad
    -- because Neovim is not installed. Launch GUI directly, NOT in a dummy tab.
    -- The file path is a separate argument: safe even with spaces in user paths.
    { key = ',', mods = 'CTRL|SHIFT', action = wezterm.action_callback(function()
      wezterm.background_child_process { 'C:/Windows/System32/notepad.exe', wezterm.home_dir .. '/.wezterm.lua' }
    end) },
    -- Open the file YOUR PowerShell profile actually dot-sources, not an empty
    -- CurrentUserAllHosts profile. This opens it only; we never rewrite it.
    { key = '.', mods = 'CTRL|SHIFT', action = wezterm.action_callback(function()
      wezterm.background_child_process { 'C:/Windows/System32/notepad.exe', wezterm.home_dir .. '/.powershell/profile.ps1' }
    end) },
    -- Quick launch tabs. No missing nvim/yazi/btm/spotify shortcuts are enabled.
    -- Alt+Ctrl+1 is an extra convenience; 2/3/9 mirror upstream's intent.
    { key = '1', mods = 'ALT|CTRL', action = act.SpawnCommandInNewTab { args = { settings.powershell } } },
    { key = '2', mods = 'ALT|CTRL', action = act.SpawnCommandInNewTab { args = { 'C:/Windows/System32/cmd.exe' } } },
    { key = '3', mods = 'ALT|CTRL', action = act.SpawnCommandInNewTab {
      args = { settings.git_bash, '--login', '-i' },
      set_environment_variables = { MSYSTEM = 'MINGW64', CHERE_INVOKING = '1' },
    } },
    { key = '`', mods = 'CTRL', action = act.ActivateLastTab },
    { key = 'h', mods = 'CTRL|SHIFT', action = act.Search { CaseInSensitiveString = '' } },
    -- Unlike upstream, keep Alt+Enter fullscreen: useful with a hidden titlebar.
    -- Ctrl+Shift+R reload and Ctrl+Shift+L debug overlay retain their defaults.
  }
  if settings.enable_k9s_shortcut then
    table.insert(config.keys, { key = '9', mods = 'ALT|CTRL', action = act.SpawnCommandInNewTab { args = { settings.k9s } } })
  end
  if settings.semantic_bindings then
    -- Requires OSC 133 from the shell; these alone cannot discover prompt lines.
    table.insert(config.keys, { key = 'UpArrow', mods = 'SHIFT', action = act.ScrollToPrompt(-1) })
    table.insert(config.keys, { key = 'DownArrow', mods = 'SHIFT', action = act.ScrollToPrompt(1) })
  end

  config.mouse_bindings = {
    -- Preserve the Windows Terminal behavior you requested:
    -- selected text -> copy to WINDOWS clipboard, then clear selection;
    -- no selection -> paste clipboard. Clearing lets the next click paste.
    -- Do not use ClipboardAndPrimarySelection: X11 selection is not our target.
    { event = { Down = { streak = 1, button = 'Right' } }, mods = 'NONE',
      action = wezterm.action_callback(function(window, pane)
        if window:get_selection_text_for_pane(pane) ~= '' then
          window:perform_action(act.CopyTo 'Clipboard', pane)
          window:perform_action(act.ClearSelection, pane)
        else
          window:perform_action(act.PasteFrom 'Clipboard', pane)
        end
      end),
    },
  }
  -- Reserve Ctrl-click for links, including in mouse-aware applications.
  -- Consume the press too, so applications do not receive an unmatched press.
  for _, reporting in ipairs { false, true } do
    table.insert(config.mouse_bindings, {
      event = { Down = { streak = 1, button = 'Left' } }, mods = 'CTRL',
      mouse_reporting = reporting, action = act.Nop,
    })
    table.insert(config.mouse_bindings, {
      event = { Up = { streak = 1, button = 'Left' } }, mods = 'CTRL',
      mouse_reporting = reporting, action = act.OpenLinkAtMouseCursor,
    })
  end
  if settings.semantic_bindings then
    -- Article's triple-click selects the command output's semantic zone.
    -- Without shell markers, turn semantic_bindings off for normal line select.
    table.insert(config.mouse_bindings, {
      event = { Down = { streak = 3, button = 'Left' } }, mods = 'NONE',
      action = act.SelectTextAtMouseCursor 'SemanticZone',
    })
  end
  -- Mouse-aware TUIs (vim/tmux/etc.) keep their mouse events by default.
  -- Hold Shift to bypass application mouse reporting for terminal selection.

  -- Launcher contents are explicit so they don't silently use a broken Ubuntu
  -- or inherit the author's private mux configuration. No distro is started here.
  config.launch_menu = {
    { label = 'PowerShell 7', args = { settings.powershell } },
    { label = 'Command Prompt', args = { 'C:/Windows/System32/cmd.exe' } },
    { label = 'Git Bash', args = { settings.git_bash, '--login', '-i' },
      set_environment_variables = { MSYSTEM = 'MINGW64', CHERE_INVOKING = '1' } },
  }
end
return M
