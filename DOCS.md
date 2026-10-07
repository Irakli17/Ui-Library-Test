# Lumen v2.1.0 - API Reference

```lua
local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Lumen.lua"))()
```

Loading the script again automatically unloads the previous copy.

## Structure

`Lumen` -> `Window` -> `Tab` -> `Group` / `Tabbox` -> elements

## Window

```lua
local Window = Lumen:CreateWindow({
  Title = "My Hub", Tag = "Pro", Version = "v1.0.0", Subtitle = "Game name", Footer = "discord.gg/x",
  Size = Vector2.new(580, 430), MenuKey = Enum.KeyCode.RightShift,
  Watermark = true, Hotkeys = true, Dock = true,
  Snow = {Count = 70, Speed = 1},      -- or true / omit
  Backdrop = {Dim = 0.5, Blur = 8},    -- or false to disable
  Icon = "rbxassetid://123",           -- watermark logo (optional)
})
```

`Tag` and `Version` accept a string or `{Text = "Pro", Color = Color3}`.

| Method | Description |
|---|---|
| `Window:AddTab(name)` | Returns a Tab |
| `Window:AddConfigTab(name?)` | Ready-made settings tab. Menu: key, dock, watermark, hotkey list, notifications, UI scale, unload. Effects: snow on/amount/speed, backdrop dim and blur. Theme: preset dropdown plus a color picker for every theme color. Configs: save, load, delete, autoload |
| `Window:SelectTab(tab)` | Switch tab |
| `Window:Toggle()` / `SetVisible(bool)` | Show or hide |
| `Window:SetTitle / SetSubtitle / SetFooter(text)` | Update header and footer |
| `Window:Destroy()` | Remove just this window |

The window is draggable by its header and resizable from the bottom-right grip. Its size is clamped to the screen on creation.

## Tab

| Method | Returns |
|---|---|
| `Tab:AddGroup(title?, side?)` | Group (`side` = `"Left"`, `"Right"`, or omitted to alternate) |
| `Tab:AddTabbox(side?)` | Tabbox -> `Tabbox:AddTab(name)` returns a Group |
| `Tab:AddWarning({Title, Text, Type})` | Banner. `Type`: `Warning`, `Danger`, `Info`, `Success` |

## Elements (available on any Group)

Every element takes an options table. `Flag` stores the value in `Lumen.Flags[flag]`, makes it saveable in configs, and registers it in `Lumen.Options[flag]`. `Callback` fires on change. All elements also have `:OnChanged(fn)`, `:SetVisible(bool)` and `:Destroy()`.

### AddToggle
`{Text, Default, Flag, Callback, Tooltip}`. Methods: `:Set(bool)`, field `.Value`. Addons: `:AddKeybind`, `:AddColorPicker`, `:AddTooltip(text)` (can add several).

### AddSlider
`{Text, Min, Max, Default, Increment, Suffix, Flag, Callback}`. Methods: `:Set(n)`.

### AddDropdown
`{Text, Values, Default, Multi, Flag, Callback}`. Single mode value is a string. Multi mode value is `{[name] = true}`. Methods: `:Set(v)`, `:SetValues(list, keepSelection?)`.

### AddInput
`{Text, Placeholder, Default, Numeric, MaxLength, Realtime, Flag, Callback}`. Callback fires when focus is lost, or on every keystroke with `Realtime = true`. `.Value` is always current.

### AddButton
`{Text, Callback, Tooltip, DoubleClick}`. `DoubleClick = true` asks for a second click to confirm. `:AddSubButton({Text, Callback})` splits the row.

### AddLabel
`AddLabel(text, {Dim, Bold, Box})`. `Box = true` puts the text in a bordered box. Methods: `:SetText`, `:SetColor`. Supports `:AddKeybind` and `:AddColorPicker`, which is how you make standalone ones.

### AddDivider / AddImage
`AddDivider()`. `AddImage({Image, Height, ScaleType})`.

### AddViewport
`AddViewport({Height, Object, Character, Rotate})`. A rotating 3D preview. With no options it shows a gray block. `Character = true` shows a clone of your avatar, `Object` takes any Model or BasePart to clone-display. `:SetObject(inst)` swaps it later.

### AddImageGrid
`AddImageGrid({Items = {{Image = "rbxassetid://...", Name = "Skin"}}, Columns = 4, CellHeight = 64, Flag, Callback(item, index)})`. Click a cell to select it (accent outline). `.Value` is the selected index. Methods: `:Set(i)`, `:SetItems(list)`.

## Addons

```lua
local t = Group:AddToggle({Text = "Fly"})
t:AddKeybind({Default = Enum.KeyCode.F, Mode = "Toggle", Name = "Fly"})
t:AddColorPicker({Default = Color3.new(1, 0, 0), Flag = "FlyColor"})
```

**Keybind** options: `Default`, `Mode` (`Toggle`, `Hold`, `Press`), `Name`, `ShowInList`, `Flag`, `Callback(active)`, `ChangedCallback(key)`. Click the chip to rebind (Esc clears). Right-click switches Toggle/Hold. `Press` fires the callback on every press. Methods: `:SetKey`, `:SetMode`, `:IsActive`, `:OnKeyChanged(fn)`.

**ColorPicker** options: `Default`, `Flag`, `Callback(color)`. Methods: `:Set(color)`. Has hue bar, saturation/brightness square and hex input.

## Panels

```lua
local p = Lumen:CreatePanel({Title = "Info", Width = 300, Position = UDim2.new(0.5, 0, 0.5, 0)})
p:AddLabel("Any element works here")
```

`Lumen:CreateCredits({Title, Subtitle, Entries = {{Name, Role, RoleColor, Description}}})` and `panel:AddEntry({...})`.

`Lumen:CreateKeySystem({Title, Note, Validate, OnSuccess, GetKey, GetKeyLink})`. `Validate(key)` is your own function and must return `true`, or `false, "message"`.

## Dock

The icon bar at the top centre (menu, hotkey list, watermark, snow). It stays visible when the window is hidden, so it doubles as the mobile toggle.

```lua
Lumen:AddDockButton({Icon = "gear", Tooltip = "Settings", Callback = function() end, Active = function() return true end})
Lumen:SetDockVisible(false)
```

Built-in icons: `window, keyboard, list, bell, user, snow, gear`, or any `rbxassetid://` / `rbxthumb://` string. `Active` returns whether the button should look highlighted.

## Notifications

```lua
Lumen:Notify({Title = "Hi", Content = "Hello", Type = "Success", Duration = 4})
Lumen:Notify("Quick message")
```

Types: default (accent), `Success`, `Warning`, `Danger`, `Info` (tint the bell icon). Options: `Title`, `Content`, `Type`, `Duration`, `Progress` (show a countdown bar). Turn them all off with `Lumen.ShowNotifications = false`.

## HUD

`Lumen:SetWatermarkVisible(bool)`, `Lumen:SetWatermark("custom text")`, `Lumen:SetIcon(assetId | nil)`, `Lumen:SetHotkeysVisible(bool)`. The hotkey list shows every non-`Press` keybind with its state.

## Snow and backdrop

```lua
Lumen:SetSnow(true, {Count = 100, Speed = 1.5})   -- falling snow
Lumen:SetSnowOptions({Count = 50})                -- tweak while running
Lumen:SetBackdrop({Dim = 0.5, Blur = 12})         -- darken (0-1) and blur (0-40) the game world
```

Drawn behind the UI and only while a window is open. Dim defaults to 0.35, blur to 0, snow to off. All of it is adjustable from the config tab.

## Themes and scale

```lua
Lumen:SetTheme({Accent = Color3.fromRGB(255, 90, 120)})
Lumen:ApplyPreset("Ocean")     -- Lavender, Ocean, Rose, Emerald, Sunset, Mono
Lumen:SetScale(1.15)           -- scales windows, panels and popups (0.6 - 1.6)
```

Keys: `Background, Group, Control, ControlHover, Border, Text, TextDim, Accent, AccentText, TabActive, Success, Warning, Danger, Info`. Everything updates live. Setting `Accent` also derives `AccentText` and `TabActive` unless you pass them.

## Configs

Needs an executor with `writefile`, `readfile`, `listfiles`, `isfolder`, `makefolder`.

```lua
Lumen.Folder = "MyHub"          -- before creating the window
Lumen:SaveConfig("legit")
Lumen:LoadConfig("legit")
Lumen:ListConfigs()
Lumen:DeleteConfig("legit")
Lumen:SetAutoload("legit")
Lumen:LoadAutoload()            -- call once, after building your UI
```

Only elements with a `Flag` are saved.

## Misc

`Lumen:Unload()` removes everything and disconnects all events. Set `Lumen.OnUnload = function() ... end` to clean up your own code.
Tip: keep your own state in `Lumen.Flags.YourFlag` and read it inside your loops.
