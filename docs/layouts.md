# Layouts and live reload

<sub>[Docs](README.md) › Layouts and live reload</sub>

A layout describes a whole window as one table: its tabs, its groups and every element in them. `TingUI:Mount` builds the window from it. Hand it a changed table later and only the parts that changed are rebuilt, while every value, keybind and the open tab stay as they were.

That makes **live reload** possible. Keep the layout in a file, mount it with `MountFile`, and every time you save the file the open window follows. You don't need to re-run the script, close the menu or set your toggles again.

- [A first layout](#a-first-layout)
- [Live reload](#live-reload)
- [The layout format](#the-layout-format)
- [Actions and handlers](#actions-and-handlers)
- [What an update keeps](#what-an-update-keeps)
- [Mistakes in a layout](#mistakes-in-a-layout)
- [JSON layouts](#json-layouts)
- [In Studio and in games](#in-studio-and-in-games)
- [API](#api)

## A first layout

```lua
local ui = TingUI:Mount({
	Title = "My Hub", Subtitle = "Game name", ConfigTab = true,
	Tabs = {
		{ Name = "Main", Groups = {
			{ Title = "Movement", Icon = "sparkle", Elements = {
				{ "Toggle", "Fly", Flag = "Fly", Keybind = "F" },
				{ "Slider", "Speed", Flag = "Speed", Min = 16, Max = 200, Default = 16 },
				{ "Dropdown", "Mode", Flag = "Mode", Values = { "Walk", "Swim" }, Default = "Walk" },
				{ "Button", "Reset", Action = "Reset" },
			} },
		} },
	},
}, {
	-- handlers: an element with Action = "Reset" runs Reset; an element with Flag = "Fly" runs Fly
	Fly = function(on) setFly(on) end,
	Speed = function(v) humanoid.WalkSpeed = v end,
	Reset = function() TingUI.Options.Speed:Set(16) end,
})

ui:Get("Speed"):Set(50)          -- every element is still a normal TingUI element
print(TingUI.Flags.Fly)          -- and flags, configs and the command palette work as usual
```

`Mount` returns a **ui** object. Its window is a normal TingUI window (`ui.Window`), so anything else in these docs still applies to it.

## Live reload

```lua
-- your script
local TingUI = loadstring(game:HttpGet(URL))({ Id = "MyHub" })
local ui = TingUI:MountFile("MyHub/layout.lua", {
	Fly = function(on) setFly(on) end,
	Reset = function() TingUI.Options.Speed:Set(16) end,
})
```

```lua
-- MyHub/layout.lua, in your executor's workspace folder
local TingUI = ...   -- the file is given the TingUI instance

return {
	Title = "My Hub", ConfigTab = true,
	Tabs = {
		{ Name = "Main", Groups = {
			{ Title = "Movement", Elements = {
				{ "Toggle", "Fly", Flag = "Fly", Keybind = "F" },
				{ "Slider", "Speed", Flag = "Speed", Min = 16, Max = 200, Default = 16 },
				{ "Button", "Reset", Action = "Reset" },
				{ "Button", "Print", Callback = function() print(TingUI.Flags.Speed) end },
			} },
		} },
	},
}
```

Open the file in any editor and save. Within half a second the window picks up the change, and a small **Live reload** notification says what changed, for example *1 changed, 2 added*.

| When you save... | What happens |
|---|---|
| A working layout | The window updates, and the notification lists what changed |
| A file with a syntax error | Nothing changes. One warning says which line is wrong, and the last good version stays on screen. |
| A layout TingUI can't use (an unknown element type, two elements with one flag) | The same: nothing changes, and the warning says exactly where the problem is |
| A file that has been fixed | It's applied straight away, and the warning clears |

The file can return a table (Lua) or be JSON. Callbacks written in a Lua file are replaced on every save, so a changed function takes effect without rebuilding anything. If the file doesn't exist yet, `MountFile` says so once and keeps checking. The window appears with the first version that works.

`MountFile(source, handlers, options)` takes these options:

| Option | Default | What it does |
|---|---|---|
| `Interval` | `0.5` | Seconds between checks. Unchanged files cost a single `readfile`. |
| `Notify` | `true` | The Live reload and error notifications. Warnings in the output are always shown. |
| `OnError` | none | `function(message)`, called once for each new problem |
| `Immediate` | `true` | Read the file straight away instead of after the first interval |

## The layout format

### The window

Any option `CreateWindow` takes can go at the top level, next to `Tabs`.

| Field | When it changes in an update |
|---|---|
| `Title`, `Subtitle`, `Footer`, `MenuKey`, `Icon` | Updated in place |
| `Size`, `Tag`, `Version`, `Dock`, `Closable`, `Fill`, `Id`, `MobileButton`, `ConfigTab` | The window is rebuilt. Values, the open tab, its position and whether it's shown are kept. |
| Everything else, such as `Position`, `Snow`, `Backdrop` or `Watermark` | Only used when the window is first made |

`ConfigTab = true` adds the [config tab](configs.md#the-config-tab), and it always stays last. Pass a name (`ConfigTab = "Settings"`), or `{Name = "Settings", Credits = {...}}` to give it credits.

### Tabs and groups

```lua
Tabs = {
	{ Name = "Main", Groups = { ... } },
	{ "Misc", { Title = "Other", Elements = { ... } } },   -- the short form: the name first, then the groups
}
```

| Group field | What it does |
|---|---|
| `Title`, `Icon` | The group's header |
| `Side` | `"Left"` or `"Right"`. Without it, groups alternate: the first goes left, the second right, and so on. |
| `Elements` | The list of elements. They can also go straight into the group's list: `{ Title = "Movement", {"Toggle", "Fly"}, ... }`. |
| `Tabs` | Makes the group a tabbox: `Tabs = { {Name = "Aim", Elements = {...}}, {Name = "ESP", Elements = {...}} }` |
| `Key` | Tells two groups with the same title apart |

A tab can have `Fill = false` for content-sized boxes, and a `Key` to tell two tabs with the same name apart.

### Elements

Each element is a table. The type comes first, then its text, then any option that element takes in [Elements](elements.md):

```lua
{ "Toggle", "Fly", Flag = "Fly", Default = false, Risky = true, Description = "Shown on hover." }
{ Type = "Toggle", Text = "Fly", Flag = "Fly" }      -- the same thing, spelled out
```

| Type | Made with | Notes |
|---|---|---|
| `Toggle` | `AddToggle` | |
| `Slider` | `AddSlider` | `Min`, `Max`, `Default`, `Increment`, `Suffix` |
| `Dropdown` | `AddDropdown` | `Values`, `Default`, `Multi`, `Search`. A changed `Values` list is updated in place. |
| `Input` | `AddInput` | `Default`, `Placeholder`, `Numeric`, `MaxLength`, `Realtime` |
| `Button` | `AddButton` | `Sub = { {"Undo", Action = "Undo"} }` adds buttons beside it |
| `Label`, `Paragraph`, `Divider`, `Progress` | The matching `Add...` | A paragraph is `{ "Paragraph", "Title", Content = "..." }` |
| `ColorPicker` | A label with a colour picker | `Default = "#ff6080"`, `Flag` |
| `Keybind` | A label with a keybind | `Default = "G"`, `Mode`, `Flag`, `Action` (runs when the key is pressed) |
| Anything registered | `TingUI:RegisterElement` | `{ "Stepper", "Count", Flag = "Count" }` works once a Stepper is registered |

Types aren't case-sensitive. Three fields work on most elements:

| Field | What it does |
|---|---|
| `Keybind` | Adds a keybind. A key name (`"F"`) or `{Default = "F", Mode = "Hold", Flag = "FlyKey", Action = "..."}`. On a toggle, the key flips the toggle. |
| `ColorPicker` | Adds a colour picker: `"#ff0000"` or `{Default = "#ff0000", Flag = "TintColor", Action = "..."}` |
| `Visible` | `false` hides the element. It's updated in place. |

Colours can be written as `"#rrggbb"` (a colour picker's `Default`, and any option whose name ends in `Color`), and keys by name (`"RightShift"`). That's what makes [JSON layouts](#json-layouts) possible. Real `Color3` and `Enum.KeyCode` values work too.

## Actions and handlers

An element runs the first of these that exists, looked up each time it fires:

1. Its own `Callback` function, in a Lua layout.
2. The handler named by its `Action`.
3. The handler named like its `Flag`, when it has no `Action`.

Handlers are the second argument to `Mount` or `MountFile`, and can be added or replaced later with `ui:On(name, fn)`. Because they're looked up when they run, a handler added after mounting still works, and the layout file never needs to know your game code. An `Action` with no handler warns once in the output.

```lua
ui:On("Teleport", function() TeleportService:Teleport(game.PlaceId) end)
```

## What an update keeps

`ui:Update(newLayout)` compares the new layout with the one on screen, piece by piece.

| Kept | How |
|---|---|
| Values | Every toggle, slider, dropdown, input and colour, even when its element is rebuilt. Elements with a `Flag` are matched by flag, and the rest by their tab, group and text. |
| Keybinds | The key you rebound and the Toggle or Hold mode you switched to, unless the layout itself now asks for a different mode |
| The open tab | It stays open as long as it's still in the layout |
| The window | Its position and whether it's shown. It's only remade when one of the [window fields that rebuild](#the-window) changes. |

An element is matched to its older version by its `Key`, then its `Flag`, then its type and text. A matched element that only changed its `Description`, `Disabled`, `Visible` or a dropdown's `Values` is updated in place. Any other change rebuilds just that element. A group that changed its icon or side is rebuilt with everything in it, and keeps its values. Renaming a group makes it a new group, so give it a `Key` if you plan to rename it. Elements with a `Flag` keep their values either way.

A changed `Default` doesn't move a value that's already there. It's used when the element is first made. Remove an element and add it back later, and it comes back with the value it had.

`Update` returns `true, changes`, where `changes` is `{Added, Changed, Removed, Kept, Window}`, and `ui.Updated` fires with the same table.

## Mistakes in a layout

A layout is checked completely before anything on screen changes. If something is wrong, `Update` returns `false` with a message that says where the problem is, and the window stays exactly as it was. `Mount` raises the same message as an error.

```text
Tabs[1] 'Main' > Groups[1] 'Movement' > Elements[2] has an unknown type 'Togle' - did you mean Toggle?
Tabs[2] 'Misc' > Groups[1] 'Other' > Elements[1] uses the Flag 'Fly', which Tabs[1] 'Main' > Groups[1] 'Movement' > Elements[1] already uses
Tabs[1] 'Main' > Groups[2] 'Look' has Side 'Middle' (Left or Right)
```

It catches unknown element types, a missing tab name, two tabs or two groups with the same name, two elements with the same key in one group, a flag used twice anywhere in the window, a `Side` that isn't Left or Right, and options of the wrong kind.

## JSON layouts

JSON can't hold functions, so JSON layouts use `Action` and handlers. Write each element as an object with `Type` and `Text`, colours as `"#rrggbb"`, keys by name and sizes as `[width, height]`:

```json
{
  "Title": "My Hub",
  "Size": [560, 640],
  "ConfigTab": true,
  "Tabs": [
    { "Name": "Main", "Groups": [
      { "Title": "Movement", "Elements": [
        { "Type": "Toggle", "Text": "Fly", "Flag": "Fly", "Keybind": "F" },
        { "Type": "Slider", "Text": "Speed", "Flag": "Speed", "Min": 16, "Max": 200, "Default": 16 },
        { "Type": "ColorPicker", "Text": "Trail", "Flag": "Trail", "Default": "#ff6080" },
        { "Type": "Button", "Text": "Reset", "Action": "Reset" }
      ] }
    ] }
  ]
}
```

`Mount` and `Update` accept JSON text directly, and `MountFile` reads `.json` files the same way.

## In Studio and in games

A game's LocalScripts can't run Lua text (there's no `loadstring` on the client) and can't read a ModuleScript's code while the game runs. Live reload still works through two other sources:

```lua
-- a StringValue holding a JSON layout: changing its Value updates the window at once
local ui = TingUI:MountFile(ReplicatedStorage.Layouts.MainLayout, handlers)

-- or any function that returns a layout table or text; it's called every Interval
local ui = TingUI:MountFile(function() return currentLayout end, handlers)
```

Rojo turns a `.txt` file into a StringValue, so a JSON layout kept as `MainLayout.txt` in your project shows up as one. For a release build you don't need watching at all: keep the layout in a ModuleScript and `require` it.

```lua
local ui = TingUI:Mount(require(ReplicatedStorage.Layouts.Main), handlers)
```

## API

| Call | Returns or does |
|---|---|
| `TingUI:Mount(layout, handlers?)` | Builds the window and returns `ui`. `layout` is a table or JSON text. Raises an error for a broken layout. |
| `TingUI:MountFile(source, handlers?, options?)` | Returns `ui` straight away, and builds the window from `source` as soon as it holds a working layout. `source` is a file path, a StringValue or a function. |
| `TingUI:Watch(source, fn, options?)` | The watcher on its own: calls `fn(layout)` for each new version. `fn` can return `false, "why"` to refuse one. Returns a watcher. |
| `ui:Update(layout)` | `true, changes`, or `false, message`, in which case nothing changed |
| `ui:Get(key)` | The element made for a `Flag` or `Key` |
| `ui:On(name, fn)` | Adds or replaces a handler. Returns `ui`. |
| `ui:Destroy()` | Removes the window and its flags, and stops watching |
| `ui.Window`, `ui.Elements`, `ui.Handlers` | The window, elements by flag and key, and the handlers |
| `ui.Updated` | Fires with the `changes` table after every update |
| `ui.Watcher` | For `MountFile`: the watcher below |

| Watcher | What it does |
|---|---|
| `watcher:Check()` | Reads the source now and applies it, even if it hasn't changed |
| `watcher:Stop()` | Stops watching. Watching also stops when TingUI unloads. |
| `watcher.LastError` | The current problem, or `nil` when the last version worked |
| `watcher.Version` | How many versions have been applied |

---

**Next:** [Windows and layout](windows.md) · [Elements](elements.md)
