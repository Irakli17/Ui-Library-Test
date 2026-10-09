# Lumen

A dark, compact Roblox UI library in a single file. Loads with `loadstring`, no dependencies.

```lua
local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Lumen.lua"))()

local Window = Lumen:CreateWindow({ Title = "My Hub", Tag = "Pro", Version = "v0.0.1", Snow = true })
local Tab = Window:AddTab("Main")
local Group = Tab:AddGroup("Hello")

Group:AddToggle({ Text = "Enabled", Flag = "Enabled" }):AddKeybind({ Default = Enum.KeyCode.F })
Group:AddSlider({ Text = "Speed", Min = 0, Max = 100, Default = 50, Flag = "Speed" })
Group:AddButton({ Text = "Hello", Callback = function() Lumen:Notify("Hi!") end })

Window:AddConfigTab("Config")
```

## Features

- Tabs, tabboxes (sub-tabs), titled groups with icons, banners, equal-height column layout, tabs and sections you can switch off
- Toggle (with glow, disabled state), slider, dropdown (multi), input, button (with sub-buttons), label, image, selectable image grid
- 3D viewport you can orbit with the mouse in any direction; it returns to auto-rotating when released
- Keybinds (toggle / hold / press / always) and color pickers as addons, plus tooltips
- Top dock with pixel-traced icons, command palette (Ctrl+K), animated success / warning / error / info / loading notifications, draggable watermark and hotkey list
- Confirmation dialogs (hold-to-confirm), dynamic input, credits inside any group
- Dimmed and blurred backdrop with seven particle styles (snow, bubbles, petals, embers, fireflies, stars, glyph rain)
- Floating panels, credits panel, key prompt panel with Discord icon
- Themes that change shape, glow, font, surface and particles (not just colour), blended smoothly when you switch
- Dock and hotkey list glide back into place after you drag them
- ESP preview overlay on viewports
- Everything adjustable in the built-in settings tab, including a full theme editor with presets
- Inter font (downloaded once, falls back to Gotham), UI scale, config save / load / autoload
- Draggable, resizable window; safe reload

## Docs

See [DOCS.md](DOCS.md) for the API and [Example.lua](Example.lua) for a full demo.

## Versioning

`vX.X.X`. Current version: **v0.0.1-stable**.
