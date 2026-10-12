# Elements

<sub>[Docs](README.md) › Elements</sub>

Every element lives in a Group (or a Panel) and takes one options table.

- [Shared options and methods](#shared-options-and-methods)
- [Toggle](#addtoggle) · [Slider](#addslider) · [Dropdown](#adddropdown) · [Player dropdown](#addplayerdropdown) · [Input](#addinput) · [Button](#addbutton)
- [Progress](#addprogress) · [Paragraph](#addparagraph) · [Label](#addlabel) · [Divider and image](#adddivider-and-addimage) · [Image grid](#addimagegrid) · [Viewport](#addviewport) · [Credits](#addcredits)
- [Addons: keybinds and colour pickers](#addons)
- [Hover explanations](#hover-explanations)
- [Confirmation dialog](#confirmation-dialog)
- [Notifications](#notifications)

## Shared options and methods

| Option | What it does |
|---|---|
| `Flag` | Stores the value in `TingUI.Flags[flag]`, registers the element in `TingUI.Options[flag]` and saves it in configs. |
| `Callback` | Runs when the value changes. It runs safely: an error shows a notification instead of breaking anything. |
| `Description` | A hover explanation (see [Hover explanations](#hover-explanations)). `Tooltip` works too. |
| `Disabled` | Start dimmed and non-interactive. |

Every element also has `:OnChanged(fn)`, `:SetVisible(bool)`, `:SetDisabled(bool)`, `:SetDescription(text)`, `:Get()` and `:Destroy()`. Every named element can be found from the [command palette](windows.md#command-palette).

## AddToggle

```lua
local t = Group:AddToggle({ Text = "Fly", Default = false, Flag = "Fly", Risky = false, Callback = function(on) end })
t:Set(true); t:SetText("Fly (fast)"); print(t.Value)
```

`Risky = true` tints the label red. The box squashes and pops when toggled, and the fill fades in, in the theme's accent gradient when it has one. Toggles take [addons](#addons): `:AddKeybind`, `:AddColorPicker` and `:AddTooltip(text)`.

## AddSlider

```lua
Group:AddSlider({ Text = "Speed", Min = 0, Max = 100, Default = 50, Increment = 1, Suffix = " studs", Flag = "Speed" })
```

**Click the value to type an exact number.** Values set from code with `:Set(n)` glide to their spot.

## AddDropdown

```lua
Group:AddDropdown({ Text = "Mode", Values = { "Legit", "Rage" }, Default = "Legit", Flag = "Mode" })
Group:AddDropdown({ Text = "Parts", Values = { "Head", "Torso", "Arms" }, Multi = true, Default = { "Head" }, Flag = "Parts" })
```

Single mode stores a string, and multi mode stores `{[name] = true}`. Use `:Set(v)` and `:SetValues(list, keepSelection?)`. Lists longer than 8 entries get a **search box**; force it with `Search = true` or hide it with `Search = false`.

Opening a dropdown unfolds the list and cascades the rows in. Hovering a row gives it a soft wash, grows a short accent bar on its edge and nudges the label in. Pressing squeezes the row slightly. Picking it flashes the accent, settles into the selected fill with a full-height bar, pops a check mark in and slides the new value up into the field. The chevron turns as the list opens and closes.

## AddPlayerDropdown

A dropdown of everyone in the server that updates itself as players join and leave. It takes the same options as AddDropdown, plus `IncludeLocal` (default `false`). `:GetPlayer()` returns the `Player`, or a list in multi mode.

## AddInput

```lua
Group:AddInput({ Text = "Name", Placeholder = "Type here", Default = "", Numeric = false, MaxLength = 32, Flag = "Name" })
Group:AddInput({ Text = "Notes", Dynamic = true, Callback = function(text) end })
```

It fires when focus is lost, or on every keystroke with `Realtime = true`. `.Value` is always current. `Dynamic = true` makes a live text box that grows taller as the text wraps (up to 130 px), fires on every keystroke and submits on Enter.

## AddButton

```lua
local b = Group:AddButton({ Text = "Teleport", Callback = function() end, DoubleClick = false,
	Confirm = { Title = "Teleport?", Text = "You'll leave this server.", Type = "Warning", Hold = 0.6 } })
b:AddSubButton({ Text = "Copy", Callback = function() end })
```

Pressing sends a ripple across the button. `DoubleClick = true` asks for a second click. `Confirm` opens a [confirmation dialog](#confirmation-dialog) first and only runs `Callback` if the player accepts. `:AddSubButton({Text, Callback, Confirm})` splits the row.

## AddProgress

```lua
local bar = Group:AddProgress({ Text = "Loading", Default = 0, Max = 100 })
bar:Increment(10); bar:Set(80); bar:SetMax(200); bar:SetText("Downloading")
```

An animated bar with a moving sheen that brightens briefly when it fills. Without a `Suffix` it shows a percentage. `Color` overrides the accent.

## AddParagraph

`Group:AddParagraph({ Title = "About", Content = "Wrapping text..." })`, or just a string. A titled block of wrapping text with `:SetTitle(t)` and `:SetContent(t)`.

## AddLabel

`Group:AddLabel(text, { Dim, Bold, Box })` with `:SetText` and `:SetColor`. A standalone label supports `:AddKeybind` and `:AddColorPicker`.

## AddDivider and AddImage

`Group:AddDivider()` draws a line. `Group:AddImage({ Image, Height, ScaleType })` shows an image.

## AddImageGrid

```lua
Group:AddImageGrid({ Items = { { Image = "rbxassetid://1", Name = "Skin A" }, { Image = "rbxassetid://2", Name = "Skin B" } },
	Columns = 4, CellHeight = 64, Flag = "Skin", Callback = function(item, index) end })
```

Click a cell to select it, and it gets an accent outline. Use `:Set(i)` and `:SetItems(list)`.

## AddViewport

```lua
local v = Group:AddViewport({ Height = 180, Character = true, Rotate = true,
	ESP = { Box = "Corner", Name = true, Health = 0.8, Distance = true, Color = Color3.fromRGB(255, 80, 110) } })
v:SetESP({ Health = 0.3, Name = "Enemy", DistanceText = "42m" })
v:SetObject(workspace.Model)
```

A 3D preview. With no options it shows a grey block. `Character = true` shows a clone of your avatar, and `Object` takes a Model or BasePart. **Drag to orbit in any direction.** When you let go it eases back to its default tilt and keeps auto-rotating. The mouse wheel zooms. `Rotate = false` turns auto-rotation off; dragging still works.

**ESP preview.** `ESP = {Box = "Full" | "Corner", Name = true | "text", Health = 0-1, Distance = true, DistanceText, Color}` draws an overlay that tracks the model's real on-screen bounds as it rotates. It has a box (a full outline or corner brackets), the name above, a health bar on the left that goes from green to red, and the distance below. `viewport:SetESP({...})` updates it live, and `Color` recolours the box, name and distance smoothly.

**Highlight.** Roblox `Highlight` objects don't render inside ViewportFrames, so TingUI draws its own: a tinted fill over the model plus an outline traced around its silhouette.

```lua
local v = Group:AddViewport({ Character = true, Highlight = { Enabled = true, Fill = Color3.fromRGB(255, 70, 110), FillTransparency = 0.55,
	Outline = Color3.new(1, 1, 1), OutlineTransparency = 0, Thickness = 2 } })
v:SetHighlight({ Enabled = false })          -- fades out
v:SetHighlight({ Outline = Color3.new(0, 1, 0), Thickness = 3 })
```

## AddCredits

`Group:AddCredits({ {Name, Role, RoleColor, Description}, ... })` puts credit cards inside any group. It returns an object with `:Add(entry)`. For a standalone credits panel, see [Key system and credits](windows.md#key-system-and-credits).

## Addons

```lua
local t = Group:AddToggle({ Text = "Fly" })
t:AddKeybind({ Default = Enum.KeyCode.F, Mode = "Toggle", Name = "Fly" })
t:AddColorPicker({ Default = Color3.new(1, 0, 0), Flag = "FlyColor" })
```

**Keybind.** Options: `Default`, `Mode` (`Toggle`, `Hold`, `Press` or `Always`), `Name`, `ShowInList`, `Flag`, `Callback(active)` and `ChangedCallback(key)`. Click the chip to rebind it (Esc clears), and right-click to switch between Toggle and Hold. `Always` is permanently active and needs no key; it shows as `[?]` in the hotkey list. Methods: `:SetKey`, `:SetMode`, `:IsActive` and `:OnKeyChanged(fn)`.

**ColorPicker.** Options: `Default`, `Flag` and `Callback(color)`, plus `:Set(color)`. It has a hue bar, a saturation and brightness square and a hex input, and the swatch glows in its own colour.

## Hover explanations

Rest the mouse on anything with a `Description` (or `Tooltip`). After a short pause, a card fades and slides in **beside the window, panel or dock it belongs to**, never on top of what you're about to click. If there's no room on either side, it sits beside the element, then below it, and always clear of the element itself. Moving to another explained element makes the card glide over instead of popping again, and leaving fades it out. Every setting in the config tab has one.

```lua
Group:AddToggle({ Text = "Fullbright", Description = "Lights the whole map evenly so dark areas are visible." })
someElement:SetDescription("Changed text")
TingUI.HintDelay = 0.35   -- seconds before it appears
TingUI.Hints = false      -- turn them all off (also in the config tab)
```

Hints never appear while a dropdown list or colour picker is open, and opening one hides any hint straight away. The card is a plain frame rather than a CanvasGroup, so its text stays sharp at every UI scale.

## Confirmation dialog

```lua
TingUI:Confirm({
	Title = "Reset everything?", Text = "This can't be undone.",
	Type = "Danger",          -- Warning (default), Danger, Info, Success: sets the colour, icon and glow
	Confirm = "Reset", Cancel = "Cancel",
	Hold = 1,                 -- seconds the confirm button must be held (0 = plain click, Enter confirms)
	Callback = function(accepted) end,   -- or OnConfirm / OnCancel
})
```

It dims the screen and shows a centred card with a glowing status badge: a circle for success and info, a diamond for warnings, and a rounded square for errors. Esc or a click outside closes it. It returns `{Close = function}`.

## Notifications

```lua
TingUI:Notify("test notif")                                                         -- compact (the bell rings)
TingUI:Notify({ Title = "Saved", Content = "Settings applied.", Type = "Success" })    -- green circle, the check spins in
TingUI:Notify({ Title = "Careful", Content = "May be unstable.", Type = "Warning" })   -- yellow diamond, the ! wobbles
TingUI:Notify({ Title = "Failed", Content = "Server unreachable.", Type = "Error" })    -- red square, the card shakes
TingUI:Notify({ Title = "Tip", Content = "Ctrl+K searches.", Type = "Info" })          -- blue circle, the i drops in

local n = TingUI:Notify({ Title = "Loading", Content = "Fetching...", Type = "Loading" })   -- spinner, waits
n:Update({ Title = "Done", Content = "Loaded.", Type = "Success" })                          -- morphs in place
n:Dismiss()

TingUI:Notify({ Title = "Update available", Content = "v0.0.8 is out.", Type = "Info", Duration = 8,
	Actions = { { Text = "Changelog", Callback = function() end }, { Text = "Later" } } })   -- buttons inside the card

TingUI:SetNotifyPosition("BottomRight")   -- TopRight, BottomRight, TopLeft, BottomLeft
```

Each type has its own badge **shape** as well as colour, so it reads at a glance. Cards slide in from their screen edge with a slight overshoot, a pulse ring expands out of the badge, a light sweep passes over the card, the accent bar breathes (harder for warnings and errors) and the countdown bar drains with a bright head. The stack reflows smoothly when one leaves. **Hovering pauses** the countdown and **clicking dismisses**. At most six show at once.

| Type | Aliases | Colour key |
|---|---|---|
| `Success` | | `Success` |
| `Warning` | `Caution` | `Caution` |
| `Error` | `Danger` | `Error` |
| `Info` | | `Info` |
| `Loading` | | `Accent` |

Options: `Title`, `Content` (rich text), `Type`, `Duration`, `Progress`, `Actions` and `Source`. `Source` puts a small label above the title, naming where the card came from. When several scripts share the screen, every card goes into one stack and is labelled with its script automatically (see [The Shell](shell.md)). Turn all notifications off with `TingUI.ShowNotifications = false`.

---

**Next:** [Themes](themes.md) · [Configs](configs.md)
