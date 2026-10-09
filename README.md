# Lumen

A dark, compact Roblox UI library in a single file. Loads with `loadstring`, no dependencies.

```lua
local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Lumen.lua"))({ Id = "MyHub" })

local Window = Lumen:CreateWindow({ Title = "My Hub", Tag = "Pro", Version = "v0.0.4", Snow = true })
local Tab = Window:AddTab("Main")
local Group = Tab:AddGroup("Hello")

Group:AddToggle({ Text = "Enabled", Flag = "Enabled" }):AddKeybind({ Default = Enum.KeyCode.F })
Group:AddSlider({ Text = "Speed", Min = 0, Max = 100, Default = 50, Flag = "Speed" })
Group:AddButton({ Text = "Hello", Callback = function() Lumen:Notify("Hi!") end })

Window:AddConfigTab("Config")
```

## Features

- **Built for loadstring:** options passed into the call, one instance per script (`Id`), safe re-running, `Loader.lua` with a CDN mirror and offline cache, works as a ModuleScript too
- **Easy to extend:** add your own elements, themes, particle styles and icons; events, flag helpers, HTTP and clipboard helpers; every callback is crash-safe
- **18 themes** that change shape, glow, font, borders, window lighting and particles (not just colour), morphing smoothly when you switch
- **Every element:** toggle, slider (type-in), dropdown (multi, searchable), player dropdown, input (dynamic), button (sub-buttons, confirm, ripple), label, paragraph, progress bar, image, image grid, 3D viewport with ESP overlay and character highlight, keybinds, colour pickers, credits
- **Motion everywhere:** sliding tab highlight and page transitions, window open/close/collapse, unfolding popups, backdrop fade, particle crossfades
- **Hover explanations** on any element and every setting, placed beside the window so they never cover what you click
- **Notifications:** success, warning, error, info and loading, each with its own badge shape and motion, action buttons, four positions
- Tabs, tabboxes, groups with icons, banners, equal-height columns, everything switchable on and off
- High-res icons tinted to the theme, top dock, command palette (Ctrl+K) that jumps to and highlights any setting, Ctrl+Tab tab switching
- Draggable watermark and hotkey list that glide back into place, floating panels, key system, credits
- Built-in settings tab: theme editor, particles, backdrop, layout, HUD, notifications, tests, configs with autoload

## Images

Upload the `assets` folder (`assets/icons` and `assets/textures`) with `Lumen.lua`; the library downloads the PNGs from the same repo when needed and caches them. Rebuild them with `tools/build_icons.py` and `tools/build_textures.py`. See DOCS.md for using your own.

## Docs

See [DOCS.md](DOCS.md) for the API, [Example.lua](Example.lua) for a full demo, and [Loader.lua](Loader.lua) for the sturdier loader.

## Versioning

`vX.X.X`. Current version: **v0.0.4-stable**.
