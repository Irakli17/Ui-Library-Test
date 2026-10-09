# Lumen v0.0.1-stable - API Reference

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
  Snow = {Count = 70, Speed = 1, Kind = "Theme"},   -- particles; or true / omit
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

Draggable by its header or its footer strip, resizable from the bottom-right grip.

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
`{Text, Placeholder, Default, Numeric, MaxLength, Realtime, Dynamic, Flag, Callback}`. Fires on focus lost, or on every keystroke with `Realtime = true`. `.Value` is always current.

`Dynamic = true` makes a live text box that grows taller as the text wraps (up to 130px), fires on every keystroke, and submits on Enter.

### AddButton
`{Text, Callback, Tooltip, DoubleClick, Confirm}`. `DoubleClick = true` asks for a second click. `Confirm = {Title, Text, Type, Confirm, Cancel, Hold}` opens a confirmation dialog first and only runs `Callback` if accepted (see **Confirmation dialog**). `:AddSubButton({Text, Callback, Confirm})` splits the row.

### AddCredits
`group:AddCredits({{Name, Role, RoleColor, Description}, ...})` puts credit cards inside any group or tab. Returns an object with `:Add(entry)`.

### AddLabel
`AddLabel(text, {Dim, Bold, Box})`. `:SetText`, `:SetColor`. Supports `:AddKeybind` and `:AddColorPicker` for standalone ones.

### AddDivider / AddImage
`AddDivider()`. `AddImage({Image, Height, ScaleType})`.

### AddViewport
`AddViewport({Height, Object, Character, Rotate, Color, ESP})`. A 3D preview. No options shows a gray block, `Character = true` shows a clone of your avatar, `Object` takes a Model or BasePart. **Drag with the mouse to orbit in any direction; when you let go it eases back to its default tilt and keeps auto-rotating.** The mouse wheel zooms. `Rotate = false` turns auto-rotation off (dragging still works). `:SetObject(inst)` swaps the model.

**ESP preview.** `ESP = {Box = "Full" | "Corner", Name = true | "text", Health = 0-1, Distance = true, DistanceText, Color}` draws an ESP overlay that tracks the model's real on-screen bounds as it rotates: a box (full outline or corner brackets), the name above, a health bar on the left (green to red) and distance below. Update it live with `viewport:SetESP({Health = 0.3, Name = "Enemy", DistanceText = "42m"})`.

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

The icon bar at the top centre. The `window`, `scan`, `keyboard`, `command` and `user` icons are traced pixel-for-pixel from the reference, so a default setup (menu, a preview panel, hotkeys, palette, a credits panel) looks exactly like it. Built-in buttons: menu, hotkey list and command palette are shown by default; a particles button also exists but starts hidden (there is no watermark button; the watermark is toggled in the config tab). Choose which built-ins are shown with `Dock = {"menu", "hotkeys", "palette", "particles"}` in `CreateWindow`, or `Dock = false` for none. Every dock button can also be switched on or off from the config tab's Layout group, or with `Lumen:SetDockButtonVisible(name, bool)` (name = its tooltip). Active buttons are highlighted. It stays visible when the window is hidden, so it doubles as the mobile toggle. Drag it to move it.

```lua
Lumen:AddDockButton({Icon = "gear", Tooltip = "Settings", Order = 50, Callback = function() end, Active = function() return true end})
Lumen:SetDockVisible(false)
```

`Order` sorts the buttons (menu = 1, panel buttons default 20, hotkeys = 30, particles = 34, palette = 40, custom default 50).

## Confirmation dialog

```lua
Lumen:Confirm({
  Title = "Reset everything?", Text = "This can't be undone.",
  Type = "Danger",          -- Warning (default), Danger, Info, Success: sets the colour, icon and glow
  Confirm = "Reset", Cancel = "Cancel",
  Hold = 1,                 -- seconds the confirm button must be held (0 = plain click, Enter confirms)
  Callback = function(accepted) end,   -- or OnConfirm / OnCancel
})
```

Dims the screen, shows a centred card with a glowing status badge, and closes on Esc or a click outside. Returns `{Close = function}`.

## Command palette

Press **Ctrl+K** or click the dock command button. Search every named option, see its path (`MainWindow/Tab/Group`) and current value. Up/Down to move, Enter or click to act: toggles flip, buttons run, everything else jumps to its tab. Esc closes. API: `Lumen:OpenPalette()`, `ClosePalette()`, `TogglePalette()`.

## HUD

The watermark, hotkey list and dock can be dragged anywhere.

**Return to place.** After you drag the dock or the hotkey list, it glides back to where it was (a smooth 0.75s ease, never a jump) 5 seconds after you let go. Grabbing it again before then cancels the return. Everything is adjustable in the config tab's **HUD Positions** group, or from code:

```lua
Lumen.SnapBack = {Enabled = true, Delay = 5, Dock = true, Hotkeys = true, Watermark = false}
Lumen:ResetHudPositions()   -- glide everything home now
Lumen:SetHudHome()          -- make the current spots the new home
```

`Lumen:SetWatermarkVisible(bool)`, `SetWatermark("custom text")`, `SetWatermarkTitle(text)`, `SetIcon(assetId | nil)`, `SetHotkeysVisible(bool)`, `SetScreenWatermark(text | nil)`.

## Notifications

```lua
Lumen:Notify("test notif")                                                   -- compact, reference style
Lumen:Notify({Title = "Saved", Content = "Settings applied.", Type = "Success"})  -- green
Lumen:Notify({Title = "Careful", Content = "May be unstable.", Type = "Warning"}) -- yellow
Lumen:Notify({Title = "Failed", Content = "Server unreachable.", Type = "Error"})  -- red
Lumen:Notify({Title = "Tip", Content = "Ctrl+K searches.", Type = "Info"})          -- blue

local n = Lumen:Notify({Title = "Loading", Content = "Fetching...", Type = "Loading"})   -- spinner, waits
n:Update({Title = "Done", Content = "Loaded.", Type = "Success"})                         -- morphs in place
n:Dismiss()
```

Nothing is static: cards slide in from the right with a slight overshoot, a light sweep passes over them, the icon pops in, the accent bar on the left breathes (harder for warnings and errors), errors give a short shake, and the countdown bar drains. The stack reflows smoothly when one leaves. **Hover pauses** the countdown, **click dismisses**. At most six are shown at once.

Types: `Success`, `Warning` (alias `Caution`), `Error` (alias `Danger`), `Info`, `Loading`. Colours come from the theme keys `Success`, `Caution`, `Error`, `Info` and `Accent`. Options: `Title`, `Content`, `Type`, `Duration`, `Progress` (force the countdown bar on or off). Disable all with `Lumen.ShowNotifications = false`.

## Particles and backdrop

```lua
Lumen:SetSnow(true, {Count = 100, Speed = 1.5, Kind = "Theme"})
Lumen:SetParticles("Petals")     -- Theme, Snow, Bubbles, Petals, Embers, Fireflies, Stars, Glyphs
Lumen:SetSnowOptions({Count = 50})
Lumen:SetBackdrop({Dim = 0.5, Blur = 12})
```

`Theme` (the default) uses whatever the active theme ships with. Drawn behind the UI and only while a window is open.

## Themes, fonts and scale

Every preset changes the **shape and feel**, not just the colours:

| Preset | Corners | Glow | Font | Surface | Particles |
|---|---|---|---|---|---|
| Lavender | reference | reference | Inter | flat, as in the reference | Snow |
| Ocean | rounder (1.35x) | stronger | Inter | deep-water glow from below, cyan-to-blue light along the top edge | Bubbles rising |
| Rose | very round (1.75x) | strongest | Inter | pink haze from above, pink-to-peach top light | Petals spinning down |
| Emerald | slightly rounder | strong | Inter | aurora band across the top | Fireflies drifting and pulsing |
| Sunset | reference | strong | Inter | warm glow from below, orange-to-magenta top light | Embers rising and flickering |
| Mono | sharp (0.25x) | none | Mono | scanlines | Glyph rain |

Switching presets blends the whole palette over `Lumen.ThemeTransition` seconds (0.3 by default, adjustable as **Theme fade** in the config tab) instead of snapping.

```lua
Lumen:ApplyPreset("Rose")
Lumen:SetTheme({Accent = Color3.fromRGB(255, 90, 120)})             -- colours only (instant)
Lumen:SetTheme({Accent = Color3.fromRGB(255, 90, 120)}, 0.4)        -- colours, blended
Lumen:SetStyle({Radius = 1.4, Glow = 1.3, Font = "Inter", Particles = "Fireflies",
  ParticleColor = Color3.fromRGB(180, 255, 150), Tint = Color3.fromRGB(60, 200, 150), TintPlace = "Aurora",
  TintAmount = 0.2, TopLine = {Color3.fromRGB(90, 230, 160), Color3.fromRGB(60, 190, 220)}, Scanlines = false})
Lumen:SetScale(1.15)           -- windows, panels and popups (0.6 - 1.6)
Lumen:SetFont("Inter")         -- "Inter", "Gotham" or "Mono"
```

Add your own preset by putting a table in `Lumen.Presets` with colour keys plus a `Style` table; it shows up in the config dropdown.

Theme keys: `Background, Group, GroupBorder, Control, ControlHover, Border, Outline, Text, Label, TextDim, TextMuted, Chip, ChipText, Accent, AccentText, AccentBorder, Toggle, TabActive, Success, Warning, Danger, Info, Caution, Error`. Setting `Accent` or `Background` also derives `AccentText`, `AccentBorder`, `Toggle` and `TabActive` unless you pass them. The default theme was sampled from the reference screenshots.

**Fonts.** Inter is downloaded once from GitHub into your `Lumen/fonts` folder (needs `writefile` and `getcustomasset`). Until it is ready, or if your executor can't do it, Gotham is used. Mono uses Roblox's RobotoMono. Applying a preset switches to its font; you can still pick another in the config tab.

## Config tab

`Window:AddConfigTab()` builds a settings tab where everything is adjustable:

- **Menu**: menu key, dock, watermark, hotkey list, notifications, UI scale, font, screen watermark, unload
- **Effects**: particles on/off, particle style, amount, speed, backdrop dim and blur
- **HUD Positions**: return-to-place on/off, delay, which pieces (dock, hotkey list, watermark), Return now, Set as home
- **Layout**: a toggle for every tab, section, floating panel and dock button
- **Theme**: preset dropdown with a one-line description of each look, theme fade time, a colour picker for each theme colour, reset button
- **Tests**: Success, Warning, Error and Info notifications, a Loading -> Done notification, a plain one, and a hold-to-confirm dialog
- **Configs**: save, load, delete, autoload
- **Credits** (optional): `Window:AddConfigTab("Config", {Credits = {...entries}})`

## Configs

Needs `writefile`, `readfile`, `listfiles`, `isfolder`, `makefolder`.

```lua
Lumen.Folder = "MyHub"          -- before creating the window
Lumen:SaveConfig("legit"); Lumen:LoadConfig("legit"); Lumen:ListConfigs()
Lumen:DeleteConfig("legit"); Lumen:SetAutoload("legit")
Lumen:LoadAutoload()            -- call once, after building your UI
```

Only elements with a `Flag` are saved. The theme preset is saved too and is applied before your custom colours when a config loads.

## Misc

`Lumen:Unload()` removes everything and disconnects all events. Set `Lumen.OnUnload = function() ... end` for your own cleanup. Read your own state from `Lumen.Flags.YourFlag`.

## Changelog

**v0.0.1-stable** - first stable release
- Themes change shape, glow, font, surface and particles, not just colour; switching blends smoothly
- Seven particle styles (snow, bubbles, petals, embers, fireflies, stars, glyph rain), selectable or theme-driven
- Dock and hotkey list glide back to their spot after dragging (configurable delay and targets)
- Animated notifications: success / warning / error / info / loading, morphing handles, hover-to-pause, click-to-dismiss
- ESP preview overlay on viewports (box, name, health, distance)
- Watermark button removed from the dock
- Everything from the earlier development builds: pixel-traced dock icons, command palette, confirmation dialogs, dynamic input, credits, layout toggles, config system
