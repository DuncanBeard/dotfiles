-- Status text collection + mirrored Powerline gradient, adapted from Rashil.
-- Edit switches/intervals in ~/.wezterm.lua. This file explains the mechanics.
local wezterm = require 'wezterm'
local appearance = require 'tuned.appearance'
local M = {}

local function clean(value)
  -- CLI tools may return colored output. Strip SGR and control characters so
  -- their colors/newlines cannot leak into our one-line formatted status bar.
  return tostring(value or ''):gsub('\27%[[0-9;]*m', ''):gsub('[%c]', ' '):match('^%s*(.-)%s*$')
end
local function command(args)
  -- Unlike io.popen on Windows, run_child_process captures output without
  -- flashing a console window. It is SYNCHRONOUS, not a background worker:
  -- cache aggressively and never put slow/network commands in this function.
  -- pcall handles missing executables; failed/empty commands hide the segment.
  local called, success, stdout = pcall(wezterm.run_child_process, args)
  if not called or not success then return '' end
  return clean(stdout)
end

function M.apply(config, settings)
  -- Cache is local to this config instance. No persistent files, daemon,
  -- scheduled tasks, or shell subprocess at EVERY status event.
  local cache = { last_update = 0, memory = '', kube = '', spotify = '' }
  local function refresh()
    local now = os.time()
    if cache.last_update ~= 0 and now >= cache.last_update
      and now - cache.last_update < settings.external_refresh_seconds then return end
    -- Stamp first, even on error, to avoid retry storms when a tool is absent.
    cache.last_update = now
    if settings.show_memory then
      -- Native Windows RAM accounting replaces Starship (not installed here).
      -- Win32_OperatingSystem returns KiB. Divide by 1MB (2^20) for GiB.
      -- -NoProfile avoids your 590ms prompt setup and any unrelated side effects.
      local value = command { settings.powershell, '-NoProfile', '-NonInteractive', '-Command',
        "$m=Get-CimInstance Win32_OperatingSystem; if ($m) { '{0:N1}/{1:N1}G' -f (($m.TotalVisibleMemorySize-$m.FreePhysicalMemory)/1MB),($m.TotalVisibleMemorySize/1MB) }" }
      cache.memory = value ~= '' and ('host RAM ' .. value) or ''
    end
    if settings.show_kubernetes then
      -- Reads LOCAL kubeconfig only: no cluster query, no login, no mutation.
      -- Mark it 'host' so an SSH/WSL tab isn't mistaken for a remote context.
      local value = command { settings.kubectl, 'config', 'current-context' }
      cache.kube = value ~= '' and ('host K8s ' .. value) or ''
    end
    if settings.show_spotify then
      -- Opt-in only. spotify_player is a third-party terminal client, not the
      -- Windows Spotify app. Check its process first to avoid querying a dead
      -- client. If enabled, a slow CLI can still delay one refresh.
      local processes = command { 'C:/Windows/System32/tasklist.exe', '/FI', 'IMAGENAME eq spotify_player.exe', '/NH', '/FO', 'CSV' }
      cache.spotify = ''
      if processes:lower():find('"spotify_player.exe"', 1, true) then
        local raw = command { settings.spotify_player, 'get', 'key', 'playback' }
        local ok, data = pcall(wezterm.json_parse, raw)
        if ok and type(data) == 'table' and type(data.item) == 'table'
          and type(data.item.name) == 'string' then
          cache.spotify = (data.is_playing and '> ' or '|| ') .. clean(data.item.name)
        end
      end
    end
  end

  wezterm.on('update-status', function(window, pane)
    local dimensions = pane:get_dimensions()
    -- Keep scrollbar behavior independent of the optional status strip.
    if settings.show_status_bar ~= false then
    -- The status belongs to the entire tab bar, not just the focused split.
    -- Pane dimensions are still used below for that pane's scrollback policy.
    local tab = window:mux_window():active_tab()
    local cols = tab and tab:get_size().cols or dimensions.cols or 80
    local domain = pane:get_domain_name() or 'local'
    local local_domain = domain == 'local' or domain == 'default'
    local segments = {}
    local function add(value)
      value = clean(value)
      if value ~= '' then
        table.insert(segments, wezterm.truncate_right(value, settings.segment_max_width))
      end
    end

    if local_domain and cols >= settings.status_min_columns then
      refresh()
      add(cache.spotify); add(cache.kube); add(cache.memory)
    elseif not local_domain then
      -- Remote domains only: report their actual response metadata when known.
      -- Missing latency stays absent instead of displaying a meaningless 'ms'.
      local metadata = pane:get_metadata() or {}
      if type(metadata.since_last_response_ms) == 'number' then
        add(tostring(math.floor(metadata.since_last_response_ms)) .. 'ms')
      end
    end
    if settings.show_date and cols >= settings.status_min_columns then
      add(wezterm.strftime(settings.date_format))
    end
    if settings.show_time then add(wezterm.strftime(settings.time_format)) end
    if domain == 'default' then add('MUX') elseif not local_domain then add(domain) end
    -- Optional shell-provided custom label, as in upstream's latest segments.
    add((pane:get_user_vars() or {}).WIN_TITLE)

    -- Reserve at least roughly half the row for tabs. Drop low-priority left
    -- segments first; clock/domain survive longest. A tiny window is bounded too.
    local budget = math.max(0, math.floor(cols * 0.55))
    local function width()
      local n = 0
      for _, s in ipairs(segments) do n = n + wezterm.column_width(s) + 3 end
      return n
    end
    while #segments > 1 and width() > budget do table.remove(segments, 1) end
    if #segments == 1 then segments[1] = wezterm.truncate_right(segments[1], math.max(0, budget - 3)) end
    if budget < 3 or (#segments == 1 and segments[1] == '') then segments = {} end

    local palette = window:effective_config().resolved_palette
    local gradient = appearance.gradient(palette.background, #segments, settings, true)
    local elements = {}
    for i, segment in ipairs(segments) do
      table.insert(elements, { Background = { Color = i == 1 and palette.tab_bar.background or gradient[i - 1] } })
      table.insert(elements, { Foreground = { Color = gradient[i] } })
      table.insert(elements, { Text = settings.powerline and '\u{e0b2}' or '|' })
      table.insert(elements, { Background = { Color = gradient[i] } })
      table.insert(elements, { Foreground = { Color = palette.foreground } })
      table.insert(elements, { Text = ' ' .. segment .. ' ' })
    end
    -- An empty list is valid: clear old status instead of sampling 0 colors.
    window:set_right_status(wezterm.format(elements))
    else
      -- Clear prior status on hot reload; skip all metric commands while hidden.
      window:set_right_status('')
    end

    if settings.dynamic_scrollbar then
      local desired = (dimensions.scrollback_rows or 0) > (dimensions.viewport_rows or 0)
        and not pane:is_alt_screen_active()
      local overrides = window:get_config_overrides() or {}
      -- Setting overrides can trigger config/status events. The upstream
      -- unconditional write is avoided: write ONLY when the boolean changes.
      -- Preserve overrides set by other features (font size, padding, etc.).
      if overrides.enable_scroll_bar ~= desired then
        overrides.enable_scroll_bar = desired
        window:set_config_overrides(overrides)
      end
    else
      -- Disabling this feature in the tuning table must also release its old
      -- per-window override. Fall back to config.enable_scroll_bar immediately.
      local overrides = window:get_config_overrides() or {}
      if overrides.enable_scroll_bar ~= nil then
        overrides.enable_scroll_bar = nil
        window:set_config_overrides(overrides)
      end
    end
  end)
end
return M
