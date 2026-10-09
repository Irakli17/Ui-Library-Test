# Lumen v0.0.4-stable - API Reference

## Loading

```lua
-- simplest
local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Lumen.lua"))()

-- with options (passed straight into the loaded chunk)
local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Lumen.lua"))({
  Id = "MyHub", Theme = "Cosmos", Folder = "MyHub",
})

-- sturdiest: GitHub, then the jsDelivr mirror, then a cached copy on disk; returns nil + error instead of crashing
local Lumen, err = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Loader.lua"))()({
  Id = "MyHub", Version = "main",   -- or a tag like "v0.0.4-stable" to pin a release
})
if not Lumen then return warn(err) end
```

### Load options

| Option | Default | What it does |
|---|---|---|
| `Id` | `"default"` | Each Id is its own instance. Re-running a script replaces **its own** previous UI (handy while developing) and leaves other scripts' UIs alone. |
| `Reuse` | `false` | If an instance with this Id is already running, return it instead of replacing it (lets several scripts share one UI). |
| `Theme` | `"Lavender"` | Start in any preset. |
| `Folder` | `"Lumen"` | Folder for configs, fonts and the loader cache. |
| `Font` | `"Inter"` | Any font name (see Themes). |
| `Scale` | `1` | UI scale. |
| `NotifyPosition` | `"TopRight"` | `TopRight`, `BottomRight`, `TopLeft`, `BottomLeft`. |
| `NotifyErrors` | `true` | Show a red notification when one of your callbacks errors. |
| `Hints` | `true` | Hover explanations. |
| `NoInter` | `false` | Skip the one-time Inter font download. |
| `NoImages` | `false` | Skip all image downloads: vector icons stay, and theme art (nebula, brick, ...) is left out. |
| `TextureBase` | this repo | URL folder holding the theme textures (`<TextureBase>/<name>.png`), tried first. Defaults to `AssetBase` with `icons/` swapped for `textures/`. |
| `Textures` | `{}` | Your own images per texture name, e.g. `{nebula = "rbxassetid://123"}`. Also settable via `Lumen.TextureAssets`. |
| `AssetBase` | this repo | URL folder holding the icon PNGs (`<AssetBase>/<name>.png`), tried before GitHub and jsDelivr. |
| `Icons` | `{}` | Your own images per icon name, e.g. `{gear = "rbxassetid://123"}`. Also settable later via `Lumen.IconAssets`. |
| `Parent` | auto | Where the ScreenGui goes. By default: `gethui()`, then CoreGui, then PlayerGui. |
| `DisplayOrder`, `Name` | `10000`, `"LumenUI"` | ScreenGui properties. |

You can also set `getgenv().LumenOptions = {...}` before loading; it is read once and cleared so the next script starts clean.

### Studio / ModuleScript

`Lumen.lua` also works as a **ModuleScript**: put it in ReplicatedStorage and `local Lumen = require(path.Lumen)` from a LocalScript. Executor-only features (configs on disk, the Inter download, HTTP, clipboard) switch themselves off when the functions aren't there; everything else works the same.

### Safe callbacks

Every callback (elements, buttons, notification actions, events) runs in its own thread inside `xpcall`. If one errors, the traceback is printed with the element's name, a red "Script error" notification appears (turn off with `NotifyErrors = false` or in the config tab), and the rest of your script keeps running.

## Structure

`Lumen` -> `Window` -> `Tab` -> `Group` / `Tabbox` -> elements. Free-floating `Panel`s sit outside windows.

Everything you create is a plain Lua object you can keep and change later (`:Set`, `:SetText`, `:SetVisible`, `:SetDisabled`, `:SetDescription`, `:Destroy`).

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
| `Window:CycleTab(step)` | Next (`1`) / previous (`-1`) visible tab. Also **Ctrl+Tab** / **Ctrl+Shift+Tab** |
| `Window:SetCollapsed(bool)` / `IsCollapsed()` | Fold the window down to its title bar. Also **double-click the title bar** |
| `Window:Toggle()` / `SetVisible(bool)` | Show or hide the window |
| `Window:SetTitle / SetSubtitle / SetFooter(text)` | Update header and footer |
| `Window:Destroy()` | Remove just this window |

Draggable by its header or its footer strip, resizable from the bottom-right grip. Opening pops the window up, closing shrinks it away; the backdrop fades with it.

**Tab switching.** The highlight is one pill that slides to the clicked tab; the old page drifts out under a soft veil and the new one slides in from the side you're moving towards. Sub-tabs inside tabboxes do the same.

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

Every element takes an options table. `Flag` stores the value in `Lumen.Flags[flag]`, makes it saveable in configs and registers it in `Lumen.Options[flag]`. `Callback` fires on change. All elements also have `:OnChanged(fn)`, `:SetVisible(bool)`, `:SetDisabled(bool)`, `:SetDescription(text)`, `:Get()` and `:Destroy()`. Pass `Disabled = true` to start dimmed and non-interactive. All named elements are searchable from the command palette.

**`Description = "..."`** on any element adds a hover explanation (see **Hover explanations**).

### AddToggle
`{Text, Default, Flag, Callback, Tooltip, Description, Disabled, Risky}`. `:Set(bool)`, `:SetText(text)`, `.Value`. `Risky = true` tints the label red. The box squashes and pops when toggled, and the fill fades in (in the theme's accent gradient when it has one). Addons: `:AddKeybind`, `:AddColorPicker`, `:AddTooltip(text)`.

### AddSlider
`{Text, Min, Max, Default, Increment, Suffix, Flag, Callback, Description}`. `:Set(n)`. **Click the value to type an exact number.** Values set from code glide to their spot.

### AddDropdown
`{Text, Values, Default, Multi, Search, Flag, Callback, Description}`. Single mode value is a string, multi mode is `{[name] = true}`. `:Set(v)`, `:SetValues(list, keepSelection?)`. Lists longer than 8 entries get a **search box** (force it with `Search = true`, hide it with `Search = false`). The list unfolds open and folds closed.

### AddPlayerDropdown
A dropdown of everyone in the server that updates itself as players join and leave. Same options as AddDropdown plus `IncludeLocal` (default `false`). `:GetPlayer()` returns the `Player` (or a list in Multi mode).

### AddProgress
`{Text, Default, Max = 100, Suffix, Color, Description}`. An animated bar with a moving sheen; it brightens briefly when it fills. `:Set(v)`, `:Increment(n)`, `:SetMax(m)`, `:SetText(t)`. Without `Suffix` it shows a percentage.

### AddParagraph
`{Title, Content}` (or just a string). A titled block of wrapping text. `:SetTitle(t)`, `:SetContent(t)`.

### AddInput
`{Text, Placeholder, Default, Numeric, MaxLength, Realtime, Dynamic, Flag, Callback}`. Fires on focus lost, or on every keystroke with `Realtime = true`. `.Value` is always current.

`Dynamic = true` makes a live text box that grows taller as the text wraps (up to 130px), fires on every keystroke, and submits on Enter.

### AddButton
`{Text, Callback, Tooltip, Description, DoubleClick, Confirm}`. Pressing sends a ripple across the button. `DoubleClick = true` asks for a second click. `Confirm = {Title, Text, Type, Confirm, Cancel, Hold}` opens a confirmation dialog first and only runs `Callback` if accepted (see **Confirmation dialog**). `:AddSubButton({Text, Callback, Confirm})` splits the row.

### AddCredits
`group:AddCredits({{Name, Role, RoleColor, Description}, ...})` puts credit cards inside any group or tab. Returns an object with `:Add(entry)`.

### AddLabel
`AddLabel(text, {Dim, Bold, Box})`. `:SetText`, `:SetColor`. Supports `:AddKeybind` and `:AddColorPicker` for standalone ones.

### AddDivider / AddImage
`AddDivider()`. `AddImage({Image, Height, ScaleType})`.

### AddViewport
`AddViewport({Height, Object, Character, Rotate, Color, ESP})`. A 3D preview. No options shows a gray block, `Character = true` shows a clone of your avatar, `Object` takes a Model or BasePart. **Drag with the mouse to orbit in any direction; when you let go it eases back to its default tilt and keeps auto-rotating.** The mouse wheel zooms. `Rotate = false` turns auto-rotation off (dragging still works). `:SetObject(inst)` swaps the model.

**ESP preview.** `ESP = {Box = "Full" | "Corner", Name = true | "text", Health = 0-1, Distance = true, DistanceText, Color}` draws an ESP overlay that tracks the model's real on-screen bounds as it rotates: a box (full outline or corner brackets), the name above, a health bar on the left (green to red) and distance below. Update it live with `viewport:SetESP({Health = 0.3, Name = "Enemy", DistanceText = "42m", Color = Color3})` (`Color` recolours the box, name and distance smoothly).

**Highlight.** Roblox `Highlight` instances don't render inside ViewportFrames, so Lumen draws its own: a tinted fill over the model plus an outline traced around its silhouette. Pass `Highlight = true` or a table, and change it live:

```lua
local v = Group:AddViewport({Character = true, Highlight = {Enabled = true, Fill = Color3.fromRGB(255, 70, 110), FillTransparency = 0.55,
  Outline = Color3.new(1, 1, 1), OutlineTransparency = 0, Thickness = 2}})
v:SetHighlight({Enabled = false})          -- fades out
v:SetHighlight({Outline = Color3.new(0, 1, 0), Thickness = 3})
```

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

`Height = 0` grows with content. `Visible = false` creates the panel hidden (it fades in the first time it is shown); use it for extra windows so a script's first run shows only the main UI. This works for `CreateCredits` and `CreateKeySystem` too. `Lumen:CreateCredits({Title, Subtitle, Entries = {{Name, Role, RoleColor, Description}}, Height, Dock})` and `panel:AddEntry({...})`.

`Lumen:CreateKeySystem({Title, Placeholder, Validate, OnSuccess, GetKey, GetKeyLink, DiscordLink, Note})`. `Validate(key)` is your own function and must return `true`, or `false, "message"`. `DiscordLink` adds the Discord icon (click copies the link).

## Dock

The icon bar at the top centre. Icons are high-resolution images (see **Icons** below), so a default setup (menu, a preview panel, hotkeys, palette, a credits panel) stays crisp at any UI scale. Built-in buttons: menu, hotkey list and command palette are shown by default; a particles button also exists but starts hidden (there is no watermark button; the watermark is toggled in the config tab). Choose which built-ins are shown with `Dock = {"menu", "hotkeys", "palette", "particles"}` in `CreateWindow`, or `Dock = false` for none. Every dock button can also be switched on or off from the config tab's Layout group, or with `Lumen:SetDockButtonVisible(name, bool)` (name = its tooltip). Active buttons are highlighted. It stays visible when the window is hidden, so it doubles as the mobile toggle. Drag it to move it.

```lua
Lumen:AddDockButton({Icon = "gear", Tooltip = "Settings", Order = 50, Callback = function() end, Active = function() return true end})
Lumen:SetDockVisible(false)
```

`Order` sorts the buttons (menu = 1, panel buttons default 20, hotkeys = 30, particles = 34, palette = 40, custom default 50).

## Hover explanations

Hints never appear while a dropdown list or colour picker is open (they wait until it closes), and opening one hides any hint straight away. The card is a plain frame, not a CanvasGroup, so its text renders sharp at every UI scale.

Rest the mouse on anything with a `Description` (or `Tooltip`) and, after a short pause, a card fades and slides in **beside the window, panel or dock it belongs to**, never on top of what you are about to click. If there is no room on either side it sits beside the element, then below it, always clear of the element itself. Moving to another explained element makes the card glide over instead of popping again; leaving fades it out. Every setting in the config tab has one.

```lua
Group:AddToggle({Text = "Fullbright", Description = "Lights the whole map evenly so dark areas are visible."})
someElement:SetDescription("Changed text")
Lumen.HintDelay = 0.35   -- seconds before it appears
Lumen.Hints = false      -- turn them all off (also in the config tab)
```

## Icons

The built-in icons (`window, scan, keyboard, command, user, bell, check, cross, warn, info, discord, gear, snow, list, heart, chevron, search, eye, sparkle, lock, palette`) are 96 px white PNGs tinted to the theme. On load Lumen draws crisp vector versions immediately, downloads the PNGs in the background (`AssetBase`, then GitHub, then jsDelivr), caches them in `<Folder>/icons/v1/` and fades each icon over to its image. Without `writefile`/`getcustomasset`, or with `NoImages = true`, the vector icons stay.

To use your own: `Icons = {gear = "rbxassetid://..."}` in the load options, `Lumen.IconAssets.gear = "..."` before building the UI, or `Lumen:RegisterIcon(name, fn)` for a fully custom one. To change or add PNGs, edit and run `tools/build_icons.py` (Python with `cairosvg` and `Pillow`), then upload `assets/icons/` to your repo.

## Theme textures

Some themes paint real art into the window: Cosmos has drifting nebula clouds over a parallax star layer (and the nebula faintly across the whole screen), Criminality has a grimy brick wall lit by a flickering street lamp. The images are high-resolution PNGs generated by `tools/build_textures.py` (procedural, nothing copied), stored in `assets/textures/`, downloaded the first time a theme needs them and cached in `<Folder>/textures/v1/`. Until they arrive, or without `writefile`/`getcustomasset`, the theme simply shows without its art.

```lua
Lumen:RegisterTheme("Deep Field", {
  Accent = Color3.fromRGB(120, 200, 255), Background = Color3.fromRGB(6, 8, 16),
  Style = {
    Particles = "Galaxy",
    Texture = {
      {Image = "nebula", Transparency = 0.5, Drift = 0.03, Zoom = 0.9},              -- slow pan, never jumps
      {Image = "stars", Transparency = 0.15, Drift = 0.06, Pulse = 0.25},           -- breathes gently
      {Image = "lamp", Mode = "Lamp", Color = Color3.fromRGB(255, 184, 105), Flicker = true}, -- light cone from the top
      {Image = "rbxassetid://1234567", Transparency = 0.8},                          -- any image works
    },
    BackdropTexture = {Image = "nebula", Transparency = 0.85, Drift = 0.01},       -- art across the whole screen
    Glitch = true,                                                                   -- title + screen glitches now and then
  },
})
```

Layer keys: `Image`, `Transparency` (0-1), `Drift` (pan speed; 0 = still), `Zoom` (image pixels per screen pixel), `Pulse` (breathing amount), `Color` (tint), `Mode` (`"Fill"` default, or `"Lamp"` for a cone of light from the top edge) and `Flicker` (a failing street lamp). Layers crossfade when you switch themes.

## Fader

`Lumen.Fader(frame)` fades a whole tree like a CanvasGroup's `GroupTransparency` but keeps text rendered natively (CanvasGroups rasterise their contents, which makes text soft). Hints, notifications and the confirm dialog use it. `f:Tween(seconds, alpha)`, `f:Set(alpha)`, `f:Hide()`. Give an object the attribute `NoFade` if it animates its own transparency.

## Dropdowns

Opening a dropdown unfolds the list and the rows cascade in. Hovering a row (about to pick) gives it a soft wash, grows a short accent bar on its edge and nudges the label in; pressing squeezes the row slightly; picking it flashes the accent, settles into the selected fill with a full-height bar, pops a check mark in and slides the new value up into the field. The chevron turns as the list opens and closes.

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

Dims the screen, shows a centred card with a glowing status badge (circle for success/info, diamond for warning, rounded square for errors), and closes on Esc or a click outside. Returns `{Close = function}`.

## Command palette

Press **Ctrl+K** or click the dock command button. Search every named option, see its path (`MainWindow/Tab/Group`) and current value. Up/Down to move, Enter or click to act: toggles flip, buttons run, everything else jumps to its tab, opens the right sub-tab, scrolls it into view and pulses a highlight around it. Esc closes. API: `Lumen:OpenPalette()`, `ClosePalette()`, `TogglePalette()`.

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
Lumen:Notify("test notif")                                                   -- compact, reference style (the bell rings)
Lumen:Notify({Title = "Saved", Content = "Settings applied.", Type = "Success"})  -- green circle, the check spins in
Lumen:Notify({Title = "Careful", Content = "May be unstable.", Type = "Warning"}) -- yellow diamond, the ! wobbles
Lumen:Notify({Title = "Failed", Content = "Server unreachable.", Type = "Error"})  -- red square, the card shakes
Lumen:Notify({Title = "Tip", Content = "Ctrl+K searches.", Type = "Info"})          -- blue circle, the i drops in

local n = Lumen:Notify({Title = "Loading", Content = "Fetching...", Type = "Loading"})   -- spinner, waits
n:Update({Title = "Done", Content = "Loaded.", Type = "Success"})                         -- morphs in place
n:Dismiss()

Lumen:Notify({Title = "Update available", Content = "v0.0.4 is out.", Type = "Info", Duration = 8,
  Actions = {{Text = "Changelog", Callback = function() end}, {Text = "Later"}}})       -- buttons inside the card

Lumen:SetNotifyPosition("BottomRight")   -- TopRight, BottomRight, TopLeft, BottomLeft
```

Each type has its own badge **shape** as well as colour, so they're readable at a glance, and the glyphs are drawn centred in the badge. Cards slide in from their screen edge with a slight overshoot, a pulse ring expands out of the badge, a light sweep passes over the card, the accent bar breathes (harder for warnings and errors), and the countdown bar drains with a bright head. The stack reflows smoothly when one leaves. **Hover pauses** the countdown, **click dismisses**. At most six are shown at once.

Types: `Success`, `Warning` (alias `Caution`), `Error` (alias `Danger`), `Info`, `Loading`. Colours come from the theme keys `Success`, `Caution`, `Error`, `Info` and `Accent`. Options: `Title`, `Content` (rich text), `Type`, `Duration`, `Progress`, `Actions`. Disable all with `Lumen.ShowNotifications = false`.

## Particles and backdrop

```lua
Lumen:SetSnow(true, {Count = 100, Speed = 1.5, Kind = "Theme"})
Lumen:SetParticles("Confetti")
Lumen:SetSnowOptions({Count = 50})
Lumen:SetBackdrop({Dim = 0.5, Blur = 12})
```

Kinds: `Theme` (whatever the active theme ships with), `Snow`, `Bubbles`, `Petals`, `Embers`, `Fireflies`, `Stars`, `Glyphs`, `Rain`, `Confetti`, `Sparkles`, `Pixels`, `Starfield` (with shooting stars), `Crystals`, `Neon`, `Drafting` (pencil marks), `FilmGrain`, `Prisms`, `Sparks` (arcing under gravity), `Bokeh`, `Bats` (flapping), `Leaves`, `Galaxy` (parallax stars, spiked bright stars, shooting stars, comets), `Grit` (dust in lamp light, screen glitches, a blade glint), `MLG` (spinning doritos, hitmarkers, rainbow words). Switching kind, amount or theme **crossfades** the old particles out and the new ones in. The whole backdrop fades in when a window opens and out when the last one closes.

## Themes, fonts and scale

Every preset changes the **shape and feel** of every element, not just the colours: corner roundness, glow strength, font and text size, window lighting, borders, accent gradients and particles. Switching blends all of it over `Lumen.ThemeTransition` seconds (0.3 by default, **Theme fade** in the config tab): colours blend, corners morph, glow fades, text dips and comes back in the new font, the window lighting crossfades and the particles crossfade.

| Preset | Shape | Font | Surface & border | Accent | Particles |
|---|---|---|---|---|---|
| Lavender | reference | Inter | flat, as in the reference | solid | Snow |
| Ocean | rounder | Inter | deep-water glow from below, cyan-blue top light | solid | Bubbles rising |
| Rose | very round, strong glow | Inter | pink haze from above, pink-peach top light | solid | Petals spinning down |
| Emerald | slightly rounder | Inter | aurora band across the top | solid | Fireflies |
| Sunset | reference | Inter | warm glow from below | solid | Embers rising |
| Mono | sharp, no glow | RobotoMono | scanlines | solid | Glyph rain |
| **Frost** | round | Jura | icy top light, **frosted inner border** | white-to-ice gradient | Spinning ice crystals |
| **Royal** | sharp-ish | Merriweather (serif) | gold top light, **gilded double border** | gold gradient | Glinting sparkles |
| **Candy** | extra round, big glow | Fredoka One | mint glow from below, **slow pastel border** | pink-to-peach gradient | Tumbling confetti |
| **Arcade** | square | Press Start (pixel) | CRT scanlines, **thick yellow border** | solid | Stepping pixels |
| **Cosmos** | round | Titillium Web | **drifting nebula + parallax star layer in the window**, nebula across the screen, turning aurora border | violet-to-cyan gradient | Galaxy: parallax stars, shooting stars, comets |
| **Storm** | reference | Oswald (condensed) | steel top light | solid | Slanted rain + distant lightning |
| **Blueprint** | sharp | Patrick Hand | **drafting grid** over the window, white inner line | solid | Pencil marks |
| **Prism** | round | Ubuntu | aurora band, **8-colour rainbow border** | **accent cycles through the spectrum** | Floating prisms |
| **Hazard** | square | Sarpanch | **static yellow/black striped border** at 45° | solid | Sparks arcing under gravity |
| **Glass** | very round | Nunito | **translucent, blurred surfaces**, white inner line | gradient | Soft bokeh |
| **Criminality** | tight | Roboto Condensed | **brick wall under a flickering street lamp**, vignette, **glitching title and screen** | blood-red gradient | Grit: dust in the light, blade glints |
| **MLG** | reference, big glow | Cartoon (comic) | **fast rainbow border**, green glow from below | **rainbow, cycling** | Spinning doritos, hitmarkers, rainbow words |

Lavender is the default and is shown as **"Lavender (Default)"** in the config tab; `Lumen:ApplyPreset("Lavender (Default)")` also works.

```lua
Lumen:ApplyPreset("Cosmos")
Lumen:SetTheme({Accent = Color3.fromRGB(255, 90, 120)})             -- colours only (instant)
Lumen:SetTheme({Accent = Color3.fromRGB(255, 90, 120)}, 0.4)        -- colours, blended
Lumen:SetStyle({Radius = 1.4, Glow = 1.3, Font = "Nunito"}, 0.4)    -- shape / feel, blended
Lumen:SetScale(1.15)           -- windows, panels and popups (0.6 - 1.6)
Lumen:SetFont("Michroma", 0.35) -- any Roblox font name, "Inter", "Gotham" or "Mono"; optional fade
```

**Style keys** (all optional): `Radius` (corner scale), `Glow` (0 = off), `Font`, `TextScale`, `Particles`, `ParticleColor`, `Tint` + `TintPlace` (`"Top"`, `"Bottom"`, `"Aurora"`) + `TintAmount`, `TopLine = {c1, c2}`, `Scanlines`, `Aura = {c1, c2, ...}` + `AuraSpeed` + `AuraThickness`, `InnerLine = Color3`, `AccentGradient = {c1, c2}`, `Lightning`, `Grid = true` + `GridColor`, `Vignette = 0-1`, `SurfaceTransparency = 0-1`, `Blur` (world blur behind the UI), `AccentCycle = true`, `AuraHard = true` (hard colour bands instead of a smooth gradient), `AuraRotation` (border angle when `AuraSpeed = 0`), `CycleSpeed` (how fast `AccentCycle` turns), `Texture`, `BackdropTexture` and `Glitch` (see **Theme textures**).

**Your own theme:**

```lua
Lumen:RegisterTheme("Matcha", {
  Accent = Color3.fromRGB(140, 200, 120), Background = Color3.fromRGB(14, 17, 13), Group = Color3.fromRGB(18, 22, 17),
  Style = { Radius = 1.3, Font = "Nunito", Particles = "Petals", ParticleColor = Color3.fromRGB(190, 230, 160),
    Tint = Color3.fromRGB(110, 180, 90), TintPlace = "Bottom", AccentGradient = {Color3.fromRGB(170, 230, 140), Color3.fromRGB(90, 160, 90)} },
}, "Soft greens and drifting leaves.")   -- shows up in the config tab's Preset dropdown with this description
```

Theme keys: `Background, Group, GroupBorder, Control, ControlHover, Border, Outline, Text, Label, TextDim, TextMuted, Chip, ChipText, Accent, AccentText, AccentBorder, Toggle, TabActive, Success, Warning, Danger, Info, Caution, Error`. Setting `Accent` or `Background` also derives `AccentText`, `AccentBorder`, `Toggle` and `TabActive` unless you pass them.

**Fonts.** Inter is downloaded once from GitHub into your `Lumen/fonts` folder (needs `writefile` and `getcustomasset`); until it is ready, or if your executor can't do it, Gotham is used. Any other name is looked up as a built-in Roblox font (`Michroma`, `Jura`, `Merriweather`, `FredokaOne`, `Arcade`, `TitilliumWeb`, `Oswald`, `Ubuntu`, `Nunito`, `SourceSans`, ...). Unknown names fall back to Gotham.

## Config tab

`Window:AddConfigTab()` builds a settings tab where everything is adjustable, and every setting explains itself on hover:

- **Menu**: menu key, dock, watermark, hotkey list, notifications, notification position, hover explanations, script error alerts, UI scale, font, screen watermark, unload
- **Effects**: particles on/off, particle style, amount, speed, backdrop dim and blur
- **HUD Positions**: return-to-place on/off, delay, which pieces (dock, hotkey list, watermark), Return now, Set as home
- **Layout**: dropdowns (Tabs, Sections, Panels, Dock buttons); tick or untick entries to show or hide them
- **Theme**: preset dropdown with a one-line description of each look, theme fade time, a colour picker for each theme colour, reset button
- **Tests**: Success, Warning, Error and Info notifications, Loading -> Done, plain, with action buttons, a deliberate script error, and a hold-to-confirm dialog
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

## Events

```lua
Lumen.Events.FlagChanged:Connect(function(flag, value) end)
Lumen.Events.ThemeChanged:Connect(function(theme) end)
Lumen.Events.StyleChanged:Connect(function(style) end)
Lumen.Events.TabChanged:Connect(function(tabName, window) end)
Lumen.Events.VisibilityChanged:Connect(function(visible, window) end)
Lumen.Events.Notified:Connect(function(options) end)
Lumen.Events.Unloading:Connect(function() end)   -- runs before the UI is removed: restore anything your script changed
```

Each signal has `:Connect(fn)` (returns a handle with `:Disconnect()`), `:Once(fn)` and `:Wait()`. Make your own with `Lumen.Signal()`.

## Flags

```lua
Lumen:GetFlag("Speed")                      -- same as Lumen.Flags.Speed
Lumen:SetFlag("Speed", 50)                  -- moves the slider and fires its callback
Lumen:OnFlagChanged("Speed", function(v) end)
```

## Helpers

```lua
local res, err = Lumen:Request({Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = json})
-- uses request / http_request / syn.request / http.request, whichever the executor has; nil + message if none

Lumen:Clipboard("text")   -- setclipboard / toclipboard; returns false if unsupported
```

## Extending Lumen

Add your own elements, particles and icons. They get the theme, flags, configs, hover explanations and the command palette for free.

```lua
-- a +/- number stepper available as group:AddStepper({...})
Lumen:RegisterElement("Stepper", function(group, o, api)
  local opt = api.NewOption("Stepper", o)          -- gives :OnChanged, :SetVisible, :SetDescription, ...
  opt.Value = o.Default or 0
  local row = api.Row(group._container, 24)
  opt.Row = row
  local label = api.New("TextLabel", {Text = (o.Text or "Stepper") .. ": " .. opt.Value, Size = UDim2.fromScale(1, 1),
    TextXAlignment = Enum.TextXAlignment.Left, Parent = row})
  function opt:Set(v, silent)
    self.Value = v
    label.Text = (o.Text or "Stepper") .. ": " .. v
    if not silent then api.Fire(self, v) end
  end
  api.Register(opt, o.Flag)                        -- saved in configs
  api.Catalog(group, opt, o.Text)                  -- searchable in Ctrl+K
  if o.Description then opt:SetDescription(o.Description) end
  return opt
end)

-- a particle style
Lumen:RegisterParticles("Leaves", {
  Build = function(f, color, parent)               -- f.X, f.Y (0-1), f.Phase, f.Sway are pre-filled
    f.Speed, f.Base = 0.03 + math.random() * 0.03, 0.3
    f.Frame = Instance.new("Frame")
    f.Frame.Size = UDim2.fromOffset(10, 6)
    f.Frame.BackgroundColor3 = color
    f.Frame.Parent = parent
  end,
  Update = function(f, dt, t, speed)               -- may return a transparency; fading is handled for you
    f.Y = (f.Y + f.Speed * speed * dt) % 1
    f.Frame.Rotation = t * 60 + f.Phase * 50
    f.Frame.Position = UDim2.fromScale(f.X + math.sin(t + f.Phase) * 0.03, f.Y)
  end,
})

-- an icon, drawn on a 16x16 grid with rounded segments and dots
Lumen:RegisterIcon("heart", function(frame, size, colorKey, h)
  h.Dot(5.5, 6, 5); h.Dot(10.5, 6, 5); h.Seg(3.4, 8.2, 8, 13, 3); h.Seg(12.6, 8.2, 8, 13, 3)
end)
```

`api` contains `New, Corner, Stroke, Pad, List, Row, Tween, Glow, Icon, NewOption, Register, Fire, Connect, Describe, Catalog, AccentOverlay, SafeCall, Theme, Gui, Overlay, ShowPopup, ClosePopup, Dragger`. `api.New(class, props, children)` accepts `Theme = {BackgroundColor3 = "Group"}` to follow theme changes automatically.

## Misc

`Lumen:Unload()` runs `Events.Unloading` handlers, then removes everything and disconnects all events. `Lumen.OnUnload = function() end` still works. Read your own state from `Lumen.Flags.YourFlag`.

## Changelog

**v0.0.4-stable**
- Fixed: dropdown values (and sometimes tab names) going blank after picking something. A theme's font fade restored text to whatever transparency it had mid-animation; it now always returns to its resting value
- Fixed: the tab highlight pill getting stuck between tabs, mostly after theme switches. It re-aims when tab widths change mid-glide and a watchdog keeps it on the active tab
- Fixed: leftover colours from the previous theme. A settle pass re-applies the final theme after hover animations finish; placeholders, the resize grip and tab banners now follow the theme
- Hover hints no longer appear over an open dropdown or colour picker
- Sharper, more readable text: hints, notifications and the confirm dialog no longer use CanvasGroups (new `Lumen.Fader`); hint and notification body text is larger and brighter; picked dropdown rows choose the higher-contrast text colour
- Themes: removed Synthwave, Noir, Haunted and Parchment. Cosmos rebuilt with drifting nebula and star art and the new Galaxy particles. New **Criminality** (brick alley, flickering street lamp, glitches, dust, blade glints) and **MLG** (doritos, hitmarkers, rainbow everything)
- Theme textures: `Style.Texture`, `Style.BackdropTexture`, `Style.Glitch`, `CycleSpeed`; images generated by `tools/build_textures.py`, loaded on demand and cached (`TextureBase`, `Textures` load options)
- New particles: Galaxy, Grit, MLG

**v0.0.3-stable**
- High-resolution icons: 96 px PNGs tinted to the theme, cached on disk, with vector fallback (`AssetBase`, `Icons`, `NoImages`; `tools/build_icons.py` to rebuild)
- Seven new themes (Blueprint, Noir, Prism, Hazard, Glass, Haunted, Parchment) and seven new particle styles, with new Style keys: `Grid`, `Vignette`, `SurfaceTransparency`, `Blur`, `AccentCycle`, `AuraHard`, `AuraRotation`
- Fixed: some themes showed an empty window (overlay frames fed back into auto-sized panels and the dock). Borders now animate on the surface's own stroke
- Hover hints sit beside the window, panel or dock instead of covering the element under the mouse
- Dropdowns: unfold and cascade, separate hover (about to pick) and press feedback, accent fill and check mark on pick, value slides in, turning chevron
- Viewport `Highlight` (fill + silhouette outline) and `SetHighlight`; `SetESP({Color})` recolours the ESP overlay
- Config tab: Layout organised into dropdowns; the default preset is labelled "Lavender (Default)"
- Tab highlight pill: accent border, top sheen, underline and soft glow; hover ghost on other tabs
- Panels accept `Visible = false` (CreatePanel, CreateCredits, CreateKeySystem) and fade in when shown
- Example: only the main window shows on first run, Lighting moved to World, highlight controls, "Cool Toggle With Colors" explained and wired to the preview

**v0.0.2-stable**
- Integration: load options as a loadstring argument, per-script instances (`Id`, `Reuse`), `Loader.lua` with a CDN mirror and offline cache, ModuleScript/Studio support, `Parent`/`DisplayOrder` options
- Events, flag helpers, `Request` and `Clipboard` helpers, safe callbacks with error notifications
- Extension API: `RegisterElement`, `RegisterTheme`, `RegisterParticles`, `RegisterIcon`, `Lumen.API`
- Seven new themes (Synthwave, Frost, Royal, Candy, Arcade, Cosmos, Storm) with their own fonts, borders, accent gradients and particles; seven new particle styles; any Roblox font
- Everything morphs when the theme changes: colours, corners, glow, fonts, window lighting, borders and particles
- Sliding tab and sub-tab indicators, page transitions, window open/close and collapse animations, unfolding popups, backdrop fade, button ripples
- Hover explanations on every element and config setting
- New elements: player dropdown, progress bar, paragraph; searchable dropdowns; type-in slider values; risky toggles
- Notifications: distinct badge shapes, centred glyphs, per-type motion, action buttons, four screen positions
- Command palette jumps to the element and highlights it; Ctrl+Tab switches tabs

**v0.0.1-stable** - first stable release
- Themes change shape, glow, font, surface and particles, not just colour; switching blends smoothly
- Seven particle styles, selectable or theme-driven
- Dock and hotkey list glide back to their spot after dragging (configurable delay and targets)
- Animated notifications: success / warning / error / info / loading, morphing handles, hover-to-pause, click-to-dismiss
- ESP preview overlay on viewports (box, name, health, distance)
- Watermark button removed from the dock
