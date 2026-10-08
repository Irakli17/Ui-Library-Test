# Lumen v2.2.0 - API Reference

```lua
local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Lumen.lua"))()
```

Loading the script again unloads the previous copy. Set `getgenv().LumenNoInter = true` before loading to skip the Inter font download.

## Structure

`Lumen` -> `Window` -> `Tab` -> `Group` / `Tabbox` -> elements. Free-floating `Panel`s sit outside windows.

## Window

```lua
local Window = Lumen:CreateWindow({
  Title = "My Hub", Tag = "Pro", Version = "v1.0.0", Subtitle = "Game name", Footer = "discord.gg/x",
  WatermarkTitle = "My Hub V1", Id = "MainWindow",
  Size = Vector2.new(560, 752), MenuKey = Enum.KeyCode.RightShift,
  Watermark = true, Hotkeys = true, Dock = true, Fill = true,
  Snow = {Count = 70, Speed = 1},        -- or true / omit
  Backdrop = {Dim = 0.5, Blur = 8},      -- or false to disable
  Icon = "rbxassetid://123",             -- watermark logo (optional)
  ScreenWatermark = "my text",           -- faint text tiled over the screen (optional)
})
```

`Tag` and `Version` accept a string or `{Text, Color}`. Size is clamped to the screen. `Id` is the first part of the path shown in the command palette.

| Method | Description |
|---|---|
| `Window:AddTab(name)` | Returns a Tab. Empty tabs simply show nothing |
| `Window:AddConfigTab(name?)` | Settings tab, see below |
| `Window:SelectTab(tab)` | Switch tab |
| `Window:SetTabVisible(name, bool)` | Hide or show a tab by name |
| `Window:Toggle()` / `SetVisible(bool)` | Show or hide the window |
| `Window:SetTitle / SetSubtitle / SetFooter(text)` | Update header and footer |
| `Window:Destroy()` | Remove just this window |

Draggable by its header, resizable from the bottom-right grip.

## Tab

| Method | Returns |
|---|---|
| `Tab:AddGroup(title, side)` or `Tab:AddGroup({Title, Icon, Side})` | Group. `Icon` is one of the built-in icons (`command`, `keyboard`, `window`, `scan`, `bell`, `user`, `gear`, `snow`, `list`, `discord`) |
| `Tab:AddTabbox(side)` | Tabbox. `Tabbox:AddTab(name)` returns a Group |
| `Tab:AddWarning({Title, Text, Type})` | Banner. `Type` (optional): `Warning`, `Danger`, `Info`, `Success` tints the title; without it the title is white as in the reference |
| `Tab:SetVisible(bool)` | Hide or show the tab button and page |
| `Tab:Destroy()` | Remove the tab |

`side` is `"Left"`, `"Right"` or omitted to alternate.

**Fill layout.** Like the reference, boxes in a column split the page height equally (and grow if their content is taller). Pass `Fill = false` to `CreateWindow` for content-sized boxes. The config tab always uses content-sized boxes.

### Hiding sections

```lua
local box = Tab:AddTabbox("Left")
local sub = box:AddTab("Alpha")
sub:SetVisible(false)     -- hides the sub-tab button and its content
sub:Destroy()             -- removes it
box:SetVisible(false)     -- hides the whole tabbox
group:SetVisible(false)   -- hides a group
```

The config tab also has a **Layout** group with a toggle for every tab and section, so end users can switch them off from the UI.

## Elements (available on any Group)

Every element takes an options table. `Flag` stores the value in `Lumen.Flags[flag]`, makes it saveable in configs and registers it in `Lumen.Options[flag]`. `Callback` fires on change. All elements also have `:OnChanged(fn)`, `:SetVisible(bool)`, `:SetDisabled(bool)` and `:Destroy()`. Pass `Disabled = true` to start dimmed and non-interactive. All named elements are searchable from the command palette.

### AddToggle
`{Text, Default, Flag, Callback, Tooltip, Disabled}`. `:Set(bool)`, `.Value`. Addons: `:AddKeybind`, `:AddColorPicker`, `:AddTooltip(text)`.

### AddSlider
`{Text, Min, Max, Default, Increment, Suffix, Flag, Callback}`. `:Set(n)`.

### AddDropdown
`{Text, Values, Default, Multi, Flag, Callback}`. Single mode value is a string, multi mode is `{[name] = true}`. `:Set(v)`, `:SetValues(list, keepSelection?)`.

### AddInput
`{Text, Placeholder, Default, Numeric, MaxLength, Realtime, Flag, Callback}`. Fires on focus lost, or on every keystroke with `Realtime = true`. `.Value` is always current.

### AddButton
`{Text, Callback, Tooltip, DoubleClick}`. `DoubleClick = true` asks for a second click. `:AddSubButton({Text, Callback})` splits the row.

### AddLabel
`AddLabel(text, {Dim, Bold, Box})`. `:SetText`, `:SetColor`. Supports `:AddKeybind` and `:AddColorPicker` for standalone ones.

### AddDivider / AddImage
`AddDivider()`. `AddImage({Image, Height, ScaleType})`.

### AddViewport
`AddViewport({Height, Object, Character, Rotate, Color})`. A 3D preview. No options shows a gray block, `Character = true` shows a clone of your avatar, `Object` takes a Model or BasePart. **Drag with the mouse to orbit in any direction; when you let go it eases back to its default tilt and keeps auto-rotating.** The mouse wheel zooms. `Rotate = false` turns auto-rotation off (dragging still works). `:SetObject(inst)` swaps the model.

### AddImageGrid
`AddImageGrid({Items = {{Image, Name}}, Columns = 4, CellHeight = 64, Flag, Callback(item, index)})`. Click to select (accent outline). `:Set(i)`, `:SetItems(list)`.

## Addons

```lua
local t = Group:AddToggle({Text = "Fly"})
t:AddKeybind({Default = Enum.KeyCode.F, Mode = "Toggle", Name = "Fly"})
t:AddColorPicker({Default = Color3.new(1, 0, 0), Flag = "FlyColor"})
```

**Keybind**: `Default`, `Mode` (`Toggle`, `Hold`, `Press`, `Always`), `Name`, `ShowInList`, `Flag`, `Callback(active)`, `ChangedCallback(key)`. Click the chip to rebind (Esc clears), right-click switches Toggle/Hold. `Always` is permanently active and needs no key (shown as `[?]` in the hotkey list). `:SetKey`, `:SetMode`, `:IsActive`, `:OnKeyChanged(fn)`.

**ColorPicker**: `Default`, `Flag`, `Callback(color)`, `:Set(color)`. Hue bar, saturation/brightness square, hex input. The swatch glows in its own colour.

## Panels

```lua
local p = Lumen:CreatePanel({
  Title = "Preview", Subtitle = "optional", Width = 300, Height = 0, Position = UDim2.new(0.5, 0, 0.5, 0),
  Dock = {Icon = "scan", Tooltip = "Preview", Order = 20},       -- dock button that shows/hides it
  HeaderIcon = {Icon = "discord", Tooltip = "Invite", Callback = function() end},
})
p:AddLabel("Any element works here")
p:SetVisible(false); p:Toggle(); p:Destroy()
```

`Height = 0` grows with content. `Lumen:CreateCredits({Title, Subtitle, Entries = {{Name, Role, RoleColor, Description}}, Height, Dock})` and `panel:AddEntry({...})`.

`Lumen:CreateKeySystem({Title, Placeholder, Validate, OnSuccess, GetKey, GetKeyLink, DiscordLink, Note})`. `Validate(key)` is your own function and must return `true`, or `false, "message"`. `DiscordLink` adds the Discord icon (click copies the link).

## Dock

The icon bar at the top centre. Built-in buttons: menu, hotkey list, watermark, snow and command palette, plus any panel with a `Dock` option. Choose which built-ins to create with `Dock = {"menu", "hotkeys", "watermark", "snow", "palette"}` in `CreateWindow`, or `Dock = false` for none. Active buttons are highlighted. It stays visible when the window is hidden, so it doubles as the mobile toggle. Drag it to move it.

```lua
Lumen:AddDockButton({Icon = "gear", Tooltip = "Settings", Order = 50, Callback = function() end, Active = function() return true end})
Lumen:SetDockVisible(false)
```

`Order` sorts the buttons (menu = 1, panel buttons default 20, hotkeys = 30, watermark = 32, snow = 34, palette = 40, custom default 50).

## Command palette

Press **Ctrl+K** or click the dock command button. Search every named option, see its path (`MainWindow/Tab/Group`) and current value. Up/Down to move, Enter or click to act: toggles flip, buttons run, everything else jumps to its tab. Esc closes. API: `Lumen:OpenPalette()`, `ClosePalette()`, `TogglePalette()`.

## HUD

The watermark and hotkey list can be dragged anywhere.

`Lumen:SetWatermarkVisible(bool)`, `SetWatermark("custom text")`, `SetWatermarkTitle(text)`, `SetIcon(assetId | nil)`, `SetHotkeysVisible(bool)`, `SetScreenWatermark(text | nil)`.

## Notifications

```lua
Lumen:Notify({Title = "Hi", Content = "Hello", Type = "Success", Duration = 4})
Lumen:Notify("Quick message")
```

Types: default (gray bell), `Success`, `Warning`, `Danger`, `Info`. Options: `Title`, `Content`, `Type`, `Duration`, `Progress`. Disable all with `Lumen.ShowNotifications = false`.

## Snow and backdrop

```lua
Lumen:SetSnow(true, {Count = 100, Speed = 1.5})
Lumen:SetSnowOptions({Count = 50})
Lumen:SetBackdrop({Dim = 0.5, Blur = 12})
```

Drawn behind the UI and only while a window is open.

## Themes, fonts and scale

```lua
Lumen:SetTheme({Accent = Color3.fromRGB(255, 90, 120)})
Lumen:ApplyPreset("Ocean")     -- Lavender, Ocean, Rose, Emerald, Sunset, Mono
Lumen:SetScale(1.15)           -- windows, panels and popups (0.6 - 1.6)
Lumen:SetFont("Inter")         -- or "Gotham"
```

Theme keys: `Background, Group, GroupBorder, Control, ControlHover, Border, Outline, Text, Label, TextDim, TextMuted, Chip, ChipText, Accent, AccentText, AccentBorder, Toggle, TabActive, Success, Warning, Danger, Info`. Everything updates live. Setting `Accent` or `Background` also derives `AccentText`, `AccentBorder`, `Toggle` and `TabActive` unless you pass them. The default theme was sampled from the reference screenshots.

**Fonts.** Inter is downloaded once from GitHub into your `Lumen/fonts` folder (needs `writefile` and `getcustomasset`). Until it is ready, or if your executor can't do it, Gotham is used.

## Config tab

`Window:AddConfigTab()` builds a settings tab where everything is adjustable:

- **Menu**: menu key, dock, watermark, hotkey list, notifications, UI scale, font, screen watermark, unload
- **Effects**: snow on/amount/speed, backdrop dim and blur
- **Layout**: a toggle for every tab and section
- **Theme**: preset dropdown and a colour picker for each theme colour, reset button
- **Configs**: save, load, delete, autoload

## Configs

Needs `writefile`, `readfile`, `listfiles`, `isfolder`, `makefolder`.

```lua
Lumen.Folder = "MyHub"          -- before creating the window
Lumen:SaveConfig("legit"); Lumen:LoadConfig("legit"); Lumen:ListConfigs()
Lumen:DeleteConfig("legit"); Lumen:SetAutoload("legit")
Lumen:LoadAutoload()            -- call once, after building your UI
```

Only elements with a `Flag` are saved.

## Misc

`Lumen:Unload()` removes everything and disconnects all events. Set `Lumen.OnUnload = function() ... end` for your own cleanup. Read your own state from `Lumen.Flags.YourFlag`.
