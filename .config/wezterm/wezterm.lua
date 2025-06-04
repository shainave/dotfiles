local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- General Settings
  config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
  -- config.bidi_enabled = true
  -- config.bidi_direction = "AutoLeftToRight"
  config.window_close_confirmation = 'NeverPrompt'

-- Colors & Appearance
  config.color_scheme = "Dracula (Official)"
  config.window_background_opacity = 0.9
  -- config.hide_tab_bar_if_only_one_tab = true

-- Fonts
  config.font = wezterm.font_with_fallback {
    'SauceCodePro Nerd Font',
}
  config.window_padding = {
    left = 10,
    right = 10,
    top = 0,
    bottom = 0,
  }

-- Launching programs
  config.default_prog = { 'pwsh.exe' }
  config.launch_menu = {
    { label = 'Git Bash', args = { 'C:\\Program Files\\Git\\bin\\bash.exe', '--login' } },
    { label = 'PowerShell', args = { 'C:\\Program Files\\PowerShell\\7\\pwsh.exe', '-NoLogo' } },
    { label = 'Windows PowerShell', args = { 'powershell.exe', '-NoLogo' } },
    { label = 'CMD', args = { 'cmd.exe' } }
  }

-- Leader Key Configuration
  -- The leader key is set to CTRL + Space, with a timeout of 2000 milliseconds (3 seconds).
  -- To execute any keybinding, press the leader key (CTRL + Space) first, then the corresponding key.
  config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 3000 }

-- Key Bindings
  config.keys = {

    -- 1. Tab Management:
    -- Create a new tab in the current pane's domain
    { key = 'c', mods = 'LEADER', action = wezterm.action.SpawnTab('CurrentPaneDomain') },
    -- Close the current pane (with confirmation)
    { key = 'x', mods = 'LEADER', action = wezterm.action.CloseCurrentPane { confirm = true } },
    -- Switch to the previous tab
    { key = 'b', mods = 'LEADER', action = wezterm.action.ActivateTabRelative(-1) },
    -- Switch to the next tab
    { key = 'n', mods = 'LEADER', action = wezterm.action.ActivateTabRelative(1) },
    -- Switch to specific tabs (0-9)
    { key = '1', mods = 'LEADER', action = wezterm.action.ActivateTab(0) },
    { key = '2', mods = 'LEADER', action = wezterm.action.ActivateTab(1) },
    { key = '3', mods = 'LEADER', action = wezterm.action.ActivateTab(2) },
    { key = '4', mods = 'LEADER', action = wezterm.action.ActivateTab(3) },
    { key = '5', mods = 'LEADER', action = wezterm.action.ActivateTab(4) },
    { key = '6', mods = 'LEADER', action = wezterm.action.ActivateTab(5) },
    { key = '7', mods = 'LEADER', action = wezterm.action.ActivateTab(6) },
    { key = '8', mods = 'LEADER', action = wezterm.action.ActivateTab(7) },
    { key = '9', mods = 'LEADER', action = wezterm.action.ActivateTab(8) },
    { key = '0', mods = 'LEADER', action = wezterm.action.ActivateTab(9) },

    -- 2. Pane Splitting:
    -- Split the current pane horizontally (creates a vertical division)
    { key = '|', mods = 'LEADER|SHIFT', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    -- Split the current pane vertically (creates a horizontal division)
    { key = '-', mods = 'LEADER', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } },

    -- 3. Pane Navigation:
    -- Move to the pane on the left
    { key = 'h', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection('Left') },
    -- Move to the pane below
    { key = 'j', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection('Down') },
    -- Move to the pane above
    { key = 'k', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection('Up') },
    -- Move to the pane on the right
    { key = 'l', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection('Right') },

    -- 4. Pane Resizing:
    -- Increase the pane size to the left
    { key = 'LeftArrow', mods = 'LEADER', action = wezterm.action.AdjustPaneSize { 'Left', 5 } },
    -- Increase the pane size to the right
    { key = 'RightArrow', mods = 'LEADER', action = wezterm.action.AdjustPaneSize { 'Right', 5 } },
    -- Increase the pane size downward
    { key = 'DownArrow', mods = 'LEADER', action = wezterm.action.AdjustPaneSize { 'Down', 5 } },
    -- Increase the pane size upward
    { key = 'UpArrow', mods = 'LEADER', action = wezterm.action.AdjustPaneSize { 'Up', 5 } },

    -- 5. Shell Management:
    -- Open shell launcher in a new tab (create tab + show launcher)
    { key = 't', mods = 'LEADER', action = wezterm.action.ShowLauncherArgs { flags = 'LAUNCH_MENU_ITEMS' } },

    -- Send actual CTRL+Space when pressing it twice
    { key = 'Space', mods = 'LEADER', action = wezterm.action.SendKey { key = 'Space', mods = 'CTRL' } },
  }

return config