# ChaseUI

A clean, original Roblox UI library for script hubs and private testing tools.
Black by default, **fully re-themeable at runtime**, with config save/load, a key
system, notifications, and full mobile/touch support. One file, no dependencies,
loads straight from a `loadstring`.

```lua
local ChaseUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/ChaseUI.lua"))()
```

> **Heads up — ChaseUI is a *library*, not a self-running hub.** The line above
> only loads it; it draws nothing on its own and will look like "nothing
> happens." You then build a window with `CreateWindow` → `CreateTab` →
> elements (see [Quick start](#quick-start)). To just *see* everything working,
> run **`Demo.lua`** from this repo instead.

---

## Features

- **Window → Tabs → Sections → Elements** structure that stays tidy as it grows
- Elements: Button, Toggle, Slider, Dropdown (single + multi), Input, Keybind, ColorPicker (HSV), Label, Paragraph, Divider, Section
- **Live theming** — black base, every colour changeable on the fly (`SetTheme` / `SetAccent`)
- **Config save/load** to JSON via a `Flag` on any element
- **Key system** — optional blocking gate before the UI opens
- **Notifications** — stacked, auto-dismissing toasts
- **Mobile / touch** — drag, sliders, colour picker and dropdowns all work by touch, plus a floating re-open button
- **Executor-safe** — guarded `gethui` / `protect_gui` / `CoreGui` / `PlayerGui` parenting, guarded file-system calls, double-injection guard

---

## Table of contents

- [Quick start](#quick-start)
- [Creating a window](#creating-a-window)
- [Tabs & sections](#tabs--sections)
- [Elements](#elements)
- [Theming](#theming)
- [Config (save/load)](#config-saveload)
- [Key system](#key-system)
- [Notifications](#notifications)
- [Flags & global get/set](#flags--global-getset)
- [Mobile support](#mobile-support)
- [Teardown](#teardown)
- [Executor compatibility](#executor-compatibility)

<!-- CHUNK_1 -->

## Quick start

```lua
local ChaseUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/ChaseUI.lua"))()

local Window = ChaseUI:CreateWindow({
    Title = "My Hub",
    Accent = Color3.fromRGB(120, 90, 255),
})

local Tab = Window:CreateTab("Main", "🏠")

Tab:CreateButton({
    Name = "Click me",
    Callback = function()
        ChaseUI:Notify({ Title = "Hi", Content = "Button pressed." })
    end,
})

Tab:CreateToggle({
    Name = "God mode",
    Default = false,
    Callback = function(on) print("toggled:", on) end,
})
```

---

## Creating a window

```lua
local Window = ChaseUI:CreateWindow({
    Title      = "ChaseUI",                    -- topbar title
    Name       = "ChaseUI",                    -- ScreenGui name + default config folder
    Size       = UDim2.fromOffset(580, 420),   -- window size
    Theme      = { Background = Color3.fromRGB(14,14,16) }, -- optional theme overrides
    Accent     = Color3.fromRGB(120, 90, 255), -- optional accent shortcut
    ToggleKey  = Enum.KeyCode.RightShift,       -- show/hide key (desktop)
    ToggleIcon = "C",                           -- glyph on the mobile re-open button
    KeySystem  = nil,                           -- see "Key system" below
})
```

| Option | Type | Default | Notes |
|---|---|---|---|
| `Title` | string | `"ChaseUI"` | Topbar title |
| `Name` | string | `"ChaseUI"` | ScreenGui name |
| `Size` | UDim2 | `fromOffset(580,420)` | Scale-based sizes are supported |
| `Theme` | table | – | Partial theme merged into the live theme |
| `Accent` | Color3 | – | Shortcut for `SetAccent` |
| `ToggleKey` | KeyCode | `RightShift` | Toggles window visibility |
| `ToggleIcon` | string | `"C"` | Text on the floating button |
| `KeySystem` | table/bool | – | Optional key gate |

**Window methods:** `Window:CreateTab(name, icon)`, `Window:SelectTab(tab)`,
`Window:SetOpen(bool)`, `Window:Toggle()`, `Window:Notify(opts)`, `Window:Destroy()`.

<!-- CHUNK_2 -->

## Tabs & sections

```lua
local Tab = Window:CreateTab("Combat", "⚔️")   -- icon is optional

local Section = Tab:CreateSection("Aim")        -- returns an object with the same
Section:CreateToggle({ Name = "Enabled" })      -- Create* methods as a tab
```

Both tabs and sections expose the full set of `Create*` methods, so you can
group related controls under a titled section.

---

## Elements

Every element returns an **api** object exposing at least `.Instance` and
`.Type`. The **value elements** — Toggle, Slider, Input, Keybind, Dropdown and
ColorPicker — additionally expose `:Set(value)`, `:Get()` and `.Value`, and
accept an optional `Flag` for config/global access plus a `Callback`.
(Button, Label, Paragraph and Divider are display/action elements: they expose
helpers like `:SetText` / `:SetCallback` but no `:Get`/`.Value`.)

### Button

```lua
Tab:CreateButton({
    Name = "Teleport",
    Callback = function() print("clicked") end,
})
```

### Toggle

```lua
local t = Tab:CreateToggle({
    Name = "Fly",
    Default = false,          -- `CurrentValue` also accepted
    Flag = "FlyEnabled",
    Callback = function(state) print(state) end,
})
t:Set(true)                   -- programmatic change (fires callback)
print(t:Get())                -- -> true
```

### Slider

```lua
Tab:CreateSlider({
    Name = "Speed",
    Min = 16, Max = 300,
    Increment = 1,            -- step; decimals (e.g. 0.05) are supported
    Suffix = " studs/s",
    Default = 16,
    Flag = "Speed",
    Callback = function(v) print(v) end,
})
```

### Dropdown (single or multi)

```lua
-- single select
Tab:CreateDropdown({
    Name = "Mode",
    Options = { "A", "B", "C" },
    Default = "A",
    Callback = function(choice) print(choice) end,
})

-- multi select (callback receives an array)
local dd = Tab:CreateDropdown({
    Name = "ESP",
    Options = { "Names", "Boxes", "Health" },
    Multi = true,
    Default = { "Names" },
    Callback = function(selected) print(table.concat(selected, ",")) end,
})
dd:Refresh({ "New", "Options" })   -- replace options; pass true as 2nd arg to keep selection
```

<!-- CHUNK_3 -->

### Input / Textbox

```lua
Tab:CreateInput({                 -- CreateTextbox is an alias
    Name = "Target",
    Placeholder = "username…",
    ClearOnFocus = false,
    Default = "",
    Flag = "Target",
    Callback = function(text, enterPressed) print(text, enterPressed) end,
})
```

### Keybind

```lua
Tab:CreateKeybind({
    Name = "Panic",
    Default = Enum.KeyCode.F,      -- KeyCode or a string like "F"
    Flag = "PanicKey",
    Callback = function() print("fired") end,
})
```

Click the keybind, press a new key to rebind, or press `Escape` to clear it.

### ColorPicker

```lua
Tab:CreateColorPicker({
    Name = "Accent",
    Default = Color3.fromRGB(120, 90, 255),
    Flag = "AccentColor",
    Callback = function(color) ChaseUI:SetAccent(color) end,
})
```

### Label, Paragraph, Divider

```lua
local l = Tab:CreateLabel({ Text = "A short label" })
l:SetText("updated")

local p = Tab:CreateParagraph({ Title = "Notes", Content = "Wrapped body text." })
p:SetText("new body"); p:SetTitle("new title")

Tab:CreateDivider()
```

<!-- CHUNK_4 -->

## Theming

Black is the default base. Change any colour at runtime — all registered
elements retween to the new value instantly.

```lua
ChaseUI:SetAccent(Color3.fromRGB(60, 210, 120))   -- accent only

ChaseUI:SetTheme({                                 -- any subset of keys
    Background = Color3.fromRGB(24, 24, 30),
    Element    = Color3.fromRGB(34, 34, 42),
    Text       = Color3.fromRGB(240, 240, 240),
})
```

**Theme keys:** `Accent`, `AccentText`, `Background`, `Topbar`, `Sidebar`,
`Element`, `ElementHover`, `ElementBorder`, `Divider`, `Text`, `SubText`,
`Notification`.

You can also pass `Theme = {...}` and/or `Accent = ...` directly to
`CreateWindow`.

---

## Config (save/load)

Any element given a `Flag` is persisted. Config is stored as JSON; `Color3`
and `EnumItem` values are serialised automatically.

```lua
ChaseUI:SaveConfig("ChaseUI/myconfig.json")   -- true, or false + reason
ChaseUI:LoadConfig("ChaseUI/myconfig.json")   -- true/false; applies to all flags
```

Loading calls each flagged element's `:Set`, so toggles/sliders/etc. restore
their state (and fire their callbacks). Requires an executor with
`writefile`/`readfile`; on executors without file access `SaveConfig` returns
`false` with a message instead of erroring.

---

## Key system

An optional blocking gate shown before the window is created. If the user
closes it, `CreateWindow` returns a safe no-op window so chained calls never
error.

```lua
local Window = ChaseUI:CreateWindow({
    Title = "My Hub",
    KeySystem = {
        Title    = "My Hub",
        Subtitle = "Enter your key to continue.",
        Note     = "Get a key from our Discord.",
        Keys     = { "chase123", "vip-key" },
    },
})
```

Shorthand: `KeySystem = true` with a top-level `Keys = { ... }` on the window
config also works.

<!-- CHUNK_5 -->

## Notifications

```lua
ChaseUI:Notify({
    Title    = "Saved",
    Content  = "Your config was written.",
    Duration = 4,              -- seconds (default 4)
})

-- also available per-window:
Window:Notify({ Title = "Hi" })
```

Notifications stack in the bottom-right and fade out on their own.

---

## Flags & global get/set

Elements with a `Flag` are reachable from anywhere:

```lua
ChaseUI:GetFlag("Speed")            -- current value
ChaseUI:SetFlag("Speed", 120)       -- updates the element (and its callback)

-- the flag registry is also exposed:
ChaseUI.Flags["Speed"].Value
ChaseUI.Flags["Speed"]:Set(80)
```

---

## Mobile support

ChaseUI is touch-first:

- The window drags by its topbar with a finger.
- Sliders, the hue strip and the SV square all respond to touch, and the page
  stops scrolling while you drag a value so gestures don't fight.
- Minimising hides the window and shows a **draggable floating button** (the
  `ToggleIcon`) to reopen it — tapping reopens, dragging just repositions.

No extra setup is required; the same script runs on PC and mobile executors.

---

## Teardown

```lua
ChaseUI:Destroy()     -- removes every window, notifications, and connections
ChaseUI:Unload()      -- alias of Destroy
Window:Destroy()      -- just one window
```

Re-running the script is safe: ChaseUI destroys any previous instance (via a
`getgenv` guard where available, and by removing leftover window roots
otherwise), so you won't stack duplicate UIs or leaked input listeners.

<!-- CHUNK_6 -->

## Executor compatibility

ChaseUI resolves everything defensively, so it degrades gracefully instead of
erroring:

- **Parenting** prefers `gethui()`, then a protected `CoreGui` (via
  `syn.protect_gui` / `protectgui` if present), then `PlayerGui` — each wrapped
  in `pcall`.
- **File system** (`writefile`/`readfile`/`isfile`/`makefolder`/`isfolder`) is
  feature-detected; config calls no-op safely when it's missing.
- **`setclipboard`, `getgenv`, `cloneref`** are all optional and guarded.
- Works in Roblox Studio too (no executor globals needed), which makes
  iterating on your layout easy before you ship.

Tested conceptually against the common modern executor API surface
(`gethui`, `protect_gui`/`protectgui`, `getgenv`, `cloneref`, file I/O).

---

## Install on GitHub

1. Create a repo and upload `ChaseUI.lua` to it.
2. Open the file on GitHub → **Raw** → copy the URL.
3. Use it in your script:

```lua
local ChaseUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/ChaseUI.lua"))()
```

See **`Demo.lua`** in this repo for a full working example that exercises every
feature.

---

## License

MIT — do what you like, no warranty.






