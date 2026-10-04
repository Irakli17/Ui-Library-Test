# Vantage — the short tutorial

Everything below is copy-paste. Six steps, one file, no build tools required.

---

## 0 · Load it

Vantage ships as a single Luau file that runs from `loadstring` — it never
touches the `script` global, so a URL fetch is all it needs.

```lua
local Vantage = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Vantage.luau"
))()
```

Smaller download (comments stripped, same code):

```lua
local Vantage = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/dist/Vantage.min.luau"
))()
```

> **Requirements:** the repository has to be **public**, and the branch in the
> URL has to exist (`main`). If raw.githubusercontent.com ever rate-limits you,
> the same file is mirrored by jsDelivr:
> `https://cdn.jsdelivr.net/gh/Irakli17/Ui-Library-Test@main/Vantage.luau`
>
> In **Roblox Studio** (not an executor), `loadstring` only exists when
> `ServerScriptService.LoadStringEnabled` is on. Everyone else should use the
> ModuleScript install in the [README](../README.md#install).

---

## 1 · Preload with the loading screen

The loading screen reports real `ContentProvider` progress, and the logo sits
in the bottom-right corner of the safe area, waving — the image is sliced into
32 bands, each offset by a phase-shifted travelling wave.

```lua
local loading = Vantage.LoadingScreen.Run({
    -- Everything you want preloaded. Real progress, not a fake bar.
    Assets = {
        "rbxassetid://0",   -- replace with your own asset ids
    },
    Logo = {
        Image = "rbxassetid://0",   -- your logo; omit it to use the bundled placeholder
        Size = 92,
        Position = "bottom-right",
    },
    Title = "My Game",
    Tagline = "Loading your world",
    AutoContinue = 2.4,   -- seconds after finishing; false = wait for the player
})

loading.wait()   -- optional: yields until the player continues or it finishes
```

`AutoContinue = false` keeps the screen up until the player presses
**Continue**. `RequireInput = true` makes it "press any key".

---

## 2 · Create a window

```lua
Vantage.Setup({ Theme = "obsidian" })   -- apply the house theme

local window = Vantage.Window.new({
    Name = "My Game",
    Subtitle = "Settings",
    Size = UDim2.fromOffset(720, 460),
    MinSize = Vector2.new(420, 300),
    Resizable = true,
    Draggable = true,
})
```

Drag it by the title bar, resize from the edges, double-click the title to
maximise. Every key in the spec is also accepted in lowercase (`name`, `size`)
if you prefer.

---

## 3 · Add tabs and sections

```lua
local general = window:Tab({ Name = "General", Icon = "sliders" })
local advanced = window:Tab({ Name = "Advanced", Icon = "gear" })

local appearance = general:Section({
    Name = "Appearance",
    Description = "How the interface looks and moves.",
    Icon = "palette",
})
```

Sections collapse with a real height animation, and the controls inside them
are created through the section:

```lua
appearance:Toggle({ Name = "Reduce motion", Value = false, Callback = print })
appearance:Slider({ Name = "Interface scale", Min = 0.75, Max = 1.5, Value = 1, Step = 0.05, Callback = print })
```

---

## 4 · Every control

```lua
local settings = window:Tab({ Name = "Settings", Icon = "gear" })
local gameplay = settings:Section({ Name = "Gameplay", Collapsed = false })

gameplay:Toggle({
    Name = "Streamer mode",
    Description = "Hides names in screenshots.",
    Value = false,
    Callback = function(on) print("streamer:", on) end,
})

gameplay:Slider({
    Name = "Field of view", Min = 40, Max = 110, Value = 70,
    Suffix = "°", Decimals = 0, Ticks = { 40, 70, 90, 110 },
    Callback = function(value) print("fov:", value) end,
})

gameplay:Dropdown({
    Name = "Quality", Options = { "Low", "Medium", "High" }, Value = "High",
    Searchable = true, Callback = print,
})

gameplay:Input({
    Name = "Nickname", Placeholder = "Enter a name", MaxLength = 18,
    Callback = print,
})

gameplay:Keybind({
    Name = "Push to talk", Value = "LeftShift+T", Callback = print,
})

gameplay:Segmented({
    Name = "Density", Options = { "Comfortable", "Compact" }, Value = "Comfortable",
    Callback = print,
})

gameplay:Progress({ Name = "Indexing", Value = 0, Label = "Scanning assets" })

gameplay:Button({
    Text = "Apply changes", Variant = "primary", Tooltip = "Writes your settings",
    Callback = function() end,
})

gameplay:Button({ Text = "Wipe data", Variant = "danger", Confirm = true, Callback = function() end })

gameplay:Divider()
gameplay:Heading({ Text = "Advanced" })
gameplay:Paragraph({ Text = "Longer explanations wrap instead of overflowing." })
gameplay:Stats({ { Label = "Version", Value = "1.0.0" } })
```

`Confirm = true` makes a destructive button ask once more before it fires.
`Variant` is one of `primary`, `secondary`, `ghost`, `link`, `success`,
`danger`, `outline`; `Size` is `sm`, `md` or `lg`.

---

## 5 · Notifications, modals, palette

```lua
local notify = Vantage.Notify.new({ layer = window.NotifyLayer })

notify:push({
    Title = "Settings saved",
    Body = "Your preferences were written.",
    Tone = "success",
    Duration = 4,
})

notify:push({
    Title = "Update available",
    Body = "Version 1.1 is ready to install.",
    Key = "update",            -- same Key groups repeats instead of stacking
    Actions = { { Text = "Install", Tone = "primary", Callback = function() end } },
})

local modal = Vantage.Modal.new({
    Title = "Discard changes?",
    Body = "This cannot be undone.",
    Tone = "danger",
    Layer = window.OverlayLayer,
    Actions = {
        { Text = "Cancel", Variant = "secondary", Value = false },
        { Text = "Discard", Variant = "danger", Value = true },
    },
}, { maid = window._maid })

modal:onResult(function(result) print("result:", result) end)
```

`Ctrl+K` opens the command palette (`Vantage.CommandPalette`), `Escape` closes
the window, and every button carries an optional `Shortcut` chip.

---

## 6 · Themes, and shipping your own

```lua
Vantage.SetTheme("sakura")            -- morphs, never flashes
Vantage.SetTheme("#7C8CFF", { mode = "dark" })   -- or from a single seed

for _, theme in ipairs(Vantage.Themes()) do
    print(theme.name, theme.label, theme.mode, theme.category)
end
```

Ten themes ship in the box — `obsidian` (amber on charcoal, the house theme),
`graphite`, `porcelain`, `sakura`, `ember`, `verdant`, `amethyst`, `rosewood`,
`midnight`, `frost`. None of them is blue by default; the logo is the only
blue thing in the product.

Register your own and export it as runnable source:

```lua
Vantage.RegisterTheme("harbour", { seed = "#34D399", mode = "dark" })
local code = Vantage.ExportTheme("harbour")   -- paste-ready Luau
```

---

## Where to go next

| Want | Read |
| --- | --- |
| Full install options (Rojo, ModuleScript, Wally-style) | [README](../README.md#install) |
| Every module and method | `Vantage.Diagnostics()` at runtime, and the module headers in `src/` |
| How it is verified | [`README.md` → Verification](../README.md#verification) |
| The interactive component gallery | `docs/index.html` (open it locally, no server needed) |
