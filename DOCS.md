# Lumen UI – API Documentation

Everything below assumes you loaded the library:

```lua
local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_NAME/YOUR_REPO/main/Lumen.lua"))()
```

- [Library](#library)
- [Window](#window)
- [Tab](#tab)
- [Elements](#elements)
- [Flags and configs](#flags-and-configs)
- [Themes](#themes)
- [Tips and troubleshooting](#tips-and-troubleshooting)

---

## Library

### `Lumen:CreateWindow(config) -> Window`

| Option | Type | Default | Description |
|---|---|---|---|
| `Title` | string | `"Lumen"` | Text in the title bar |
| `Subtitle` | string | `""` | Small text on the right of the title bar |
| `Theme` | string | `"Dark"` | `Dark`, `Light`, `Ocean`, `Rose` |
| `ToggleKey` | `Enum.KeyCode` | `RightShift` | Key that shows/hides the window |
| `Width` / `Height` | number | `560` / `390` | Starting size in pixels (auto-shrunk on small screens) |
| `Intro` | boolean | `true` | Set `false` to skip the "Loaded" notification |

### `Lumen:Notify(config) -> { Close }`

| Option | Type | Default | Description |
|---|---|---|---|
| `Title` | string | `"Notice"` | Bold heading |
| `Content` | string | `""` | Body text |
| `Duration` | number | `4` | Seconds before it fades away. Click a notification to dismiss it |
| `Type` | string | `"Info"` | `Info`, `Success`, `Warning`, `Error` (changes the border colour) |

### `Lumen:SetTheme(name)`
Switches every open window to a theme instantly.

### `Lumen:SaveConfig(name) -> ok, err` / `Lumen:LoadConfig(name) -> ok, err`
Saves/loads every element that has a `Flag` to `Lumen/<name>.json`. Requires an executor with `writefile`, `readfile`, `makefolder`, `isfolder` and `isfile`. If those are missing, you get `false` and a message instead of an error.

### `Lumen:Destroy()`
Removes all windows, notifications and event connections.

### `Lumen.Flags`
A table of current values for every element created with a `Flag`. Example: `Lumen.Flags.WalkSpeed`.

### `Lumen.Version`
Version string.

---

## Window

| Method | Description |
|---|---|
| `Window:AddTab(config) -> Tab` | `config` is a string, or `{ Name = "Main", Icon = "★" }`. `Icon` is optional text or an emoji |
| `Window:SelectTab(tab)` | Switch to a tab in code |
| `Window:Show()` / `Hide()` / `Toggle()` | Visibility |
| `Window:Minimize()` | Collapse to / restore from the title bar |
| `Window:SetTitle(text)` | Change the title |
| `Window:Destroy()` | Remove this window |

Built-in behaviour: drag the title bar to move, drag the `◢` corner to resize, `–` minimizes, `✕` hides (a notification tells you how to reopen it). On touch devices a round **☰** button appears to show/hide the menu.

---

## Tab

A tab is a scrolling page. Call the element methods on it, in the order you want them to appear.

---

## Elements

Every interactive element accepts these shared options:

| Option | Description |
|---|---|
| `Name` | Label text |
| `Description` | Optional small grey text under the name (makes the row taller) |
| `Flag` | Optional string. The value is stored in `Lumen.Flags[Flag]` and included in saved configs |
| `Callback` | Function called when the value changes. **It also runs once right after creation when you pass a `Default`**, so your feature starts in the state the UI shows |

Every interactive element returns an object with `:Set(value, silent)`, `:Get()` and `:Destroy()`. Pass `silent = true` to `:Set` to avoid firing the callback.

### Section / Divider / Label / Paragraph

```lua
Tab:AddSection("Combat")                 -- small coloured heading
Tab:AddDivider()                         -- thin line
local lbl = Tab:AddLabel("Some text")    -- lbl:SetText("new text")
local p = Tab:AddParagraph("Title", "Longer wrapped text")  -- p:SetTitle(), p:SetContent()
```

### Button

```lua
local b = Tab:AddButton({
    Name = "Do thing",
    Description = "optional",
    Callback = function() end,
})
b:SetText("New name")
```

### Toggle

```lua
local t = Tab:AddToggle({ Name = "Fly", Default = false, Flag = "Fly", Callback = function(on) end })
t:Set(true); print(t:Get())
```

### Slider

```lua
local s = Tab:AddSlider({
    Name = "Speed", Min = 0, Max = 100, Default = 16, Increment = 1, Suffix = "%",
    Flag = "Speed", Callback = function(value) end,
})
```
`Increment` can be decimal (`0.1`). Dragging a slider temporarily locks page scrolling so touch users don't scroll by accident.

### Dropdown

```lua
local d = Tab:AddDropdown({
    Name = "Mode", Options = { "A", "B", "C" }, Default = "A",
    Multi = false,            -- true = pick several; callback receives an array
    Placeholder = "Select…",
    Flag = "Mode", Callback = function(choice) end,
})
d:Set("B")
d:Refresh({ "X", "Y", "Z" }, true)   -- new options; true keeps valid existing selections
d:Open(); d:Close()
```
Multi example: `Default = { "A", "C" }` → `Callback(list)` receives `{ "A", "C" }`.

### Textbox

```lua
Tab:AddTextbox({
    Name = "Name", Default = "", Placeholder = "Type here…",
    Numeric = false,        -- true = value is a number (invalid input becomes 0)
    ClearOnFocus = false,
    OnlyOnEnter = false,    -- true = callback only when the user presses Enter
    Callback = function(text) end,
})
```

### Keybind

```lua
local k = Tab:AddKeybind({
    Name = "Panic key", Default = Enum.KeyCode.X, Flag = "Panic",
    Callback = function(key) end,       -- runs when the key is pressed
    OnChanged = function(newKey) end,   -- runs when the user rebinds
})
```
Click the button, then press a key. `Esc` cancels, `Backspace` clears. Keys are ignored while the player is typing in a chat or textbox.

### ColorPicker

```lua
Tab:AddColorPicker({
    Name = "Colour", Default = Color3.fromRGB(255, 0, 0), Flag = "Colour",
    Callback = function(color3) end,
})
```
Click the row to open the picker: large square = saturation/brightness, bar = hue.

---

## Flags and configs

```lua
Tab:AddToggle({ Name = "Auto farm", Flag = "AutoFarm" })

task.spawn(function()
    while task.wait(1) do
        if Lumen.Flags.AutoFarm then
            -- do work
        end
    end
end)

Lumen:SaveConfig("mysettings")
Lumen:LoadConfig("mysettings")
```

Supported saved types: booleans, numbers, strings, string arrays (multi dropdowns), `Color3`, `Enum.KeyCode`.

---

## Themes

Built in: `Dark`, `Light`, `Ocean`, `Rose`. You can add your own **before** creating a window:

```lua
Lumen.Themes.Mint = {
    Background = Color3.fromRGB(18, 28, 24), Topbar = Color3.fromRGB(22, 36, 30),
    Sidebar = Color3.fromRGB(20, 32, 27), Element = Color3.fromRGB(30, 48, 40),
    ElementHover = Color3.fromRGB(40, 62, 52), Accent = Color3.fromRGB(80, 220, 160),
    Text = Color3.fromRGB(235, 250, 244), SubText = Color3.fromRGB(150, 185, 170),
    Stroke = Color3.fromRGB(52, 84, 70),
}
Lumen:SetTheme("Mint")
```

---

## Tips and troubleshooting

- **Nothing shows up:** make sure the script runs on the client (LocalScript or executor). The library puts its GUI in `gethui()` / `CoreGui` when allowed, otherwise `PlayerGui`.
- **`HttpGet` is blocked:** paste the contents of `Lumen.lua` straight into your script instead.
- **Callback errors:** errors inside your callbacks are caught and printed as `[Lumen] callback error: …` so one bad callback can't break the UI.
- **Running the script twice:** the old UI is removed automatically before the new one is created.
- **Menu got hidden:** press the toggle key (default `RightShift`) or tap the ☰ button on mobile.
- **Mobile:** all controls have touch-sized targets, sliders and colour pickers lock scrolling while dragged, and the window auto-fits the screen.
