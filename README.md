# Lumen UI

A clean, single-file UI library for Roblox. **No ModuleScript, no dependencies**: one `.lua` file you can load with `loadstring` or paste into your own script.

- Window with draggable title bar, resize grip, minimize and hide
- Tabs with icons
- Buttons, toggles, sliders, dropdowns (single and multi), textboxes, keybinds, colour pickers
- Notifications (Info / Success / Warning / Error), click to dismiss
- 4 built-in themes, switchable live
- Optional descriptions under any element
- Save / load configs through `Flags`
- Mobile friendly: touch-sized controls, ☰ toggle button, scroll lock while dragging sliders
- Errors in your callbacks are caught, so they can't crash the UI

## Quick start

```lua
local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_NAME/YOUR_REPO/main/Lumen.lua"))()

local Window = Lumen:CreateWindow({ Title = "My Hub", Subtitle = "v1.0" })
local Tab = Window:AddTab({ Name = "Main", Icon = "★" })

Tab:AddToggle({
    Name = "Enabled",
    Default = false,
    Callback = function(on) print("Enabled:", on) end,
})

Tab:AddSlider({
    Name = "Speed", Min = 16, Max = 100, Default = 16,
    Callback = function(v) print(v) end,
})

Lumen:Notify({ Title = "Ready", Content = "Everything loaded.", Type = "Success" })
```

Press **RightShift** (or tap **☰** on mobile) to show/hide the menu.

### Using it in Roblox Studio

Paste the contents of `Lumen.lua` at the top of a **LocalScript**, delete the final `return Lumen` line, then write your UI code underneath using the `Lumen` variable.

## Files

| File | Purpose |
|---|---|
| `Lumen.lua` | The library |
| `Example.lua` | A demo using every element |
| `DOCS.md` | Full API documentation |

## Documentation

See [DOCS.md](DOCS.md) for every option and method.

## Notes

- Callbacks run once on creation when you pass a `Default`, so your feature starts matching what the UI shows.
- Config saving needs file functions (`writefile` / `readfile`) from your environment. Without them, `SaveConfig` returns `false` and a message.
- Tested for syntax with the Luau compiler. Please open an issue if something misbehaves on your setup.

## License

MIT. Use it, modify it, ship it. Add your own `LICENSE` file before publishing.
