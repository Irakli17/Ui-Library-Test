# Lumen

A dark, compact Roblox UI library in a single file. Loads with `loadstring`, no dependencies.

```lua
local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Lumen.lua"))()

local Window = Lumen:CreateWindow({ Title = "My Hub", Tag = "Pro", Version = "v1.0.0", Snow = true })
local Tab = Window:AddTab("Main")
local Group = Tab:AddGroup("Hello")

Group:AddToggle({ Text = "Enabled", Flag = "Enabled" }):AddKeybind({ Default = Enum.KeyCode.F })
Group:AddSlider({ Text = "Speed", Min = 0, Max = 100, Default = 50, Flag = "Speed" })
Group:AddButton({ Text = "Hello", Callback = function() Lumen:Notify("Hi!") end })

Window:AddConfigTab("Config")
```

## Features

- Tabs, tabboxes (sub-tabs), groups, warning banners
- Toggle, slider, dropdown (multi), input, button (with sub-buttons), label, divider, image, selectable image grid, rotating 3D viewport
- Keybinds (toggle / hold / press) and color pickers as addons, plus tooltips
- Top dock bar, compact notifications, watermark (FPS and ping), live hotkey list
- Dimmed and blurred backdrop with falling snow
- Floating panels, credits panel, key prompt panel
- Everything adjustable in the built-in settings tab: menu key, UI scale, HUD toggles, snow, backdrop, full theme editor with presets
- Config save / load / autoload
- Draggable, resizable window; safe reload (running the script again replaces the old copy)

## Docs

See [DOCS.md](DOCS.md) for the API and [Example.lua](Example.lua) for a full demo.

## Versioning

`vX.X.X`. Current version: **v2.1.0**.
