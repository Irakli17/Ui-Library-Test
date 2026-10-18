# Windows and layout

<sub>[Docs](README.md) › Windows and layout</sub>

- [Window](#window)
- [Menu key and shift lock](#menu-key-and-shift-lock)
- [Tab](#tab)
- [Hiding sections](#hiding-sections)
- [Panels](#panels)
- [Key system and credits](#key-system-and-credits)
- [Dock](#dock)
- [HUD](#hud)
- [Command palette](#command-palette)
- [Several scripts at once](#several-scripts-at-once)
- [Windows from a table](#windows-from-a-table)

## Window

```lua
local Window = TingUI:CreateWindow({
	Title = "My Hub", Tag = "Pro", Version = "v1.0.0", Subtitle = "Game name", Footer = "discord.gg/x",
	WatermarkTitle = "My Hub V1", Id = "MainWindow",
	Size = Vector2.new(560, 752), MenuKey = Enum.KeyCode.RightShift,
	Watermark = true, Hotkeys = true, Dock = true, Fill = true,
	Snow = { Count = 70, Speed = 1, Kind = "Theme" },   -- particles; or true / omit
	Backdrop = { Dim = 0.5, Blur = 8 },                 -- or false to disable
	Icon = "rbxassetid://123",                          -- watermark logo (optional)
	ScreenWatermark = "my text",                        -- faint text tiled over the screen (optional)
})
```

| Option | Default | What it does |
|---|---|---|
| `Title`, `Subtitle`, `Footer` | `"TingUI"`, none, none | Header and footer text. |
| `Tag`, `Version` | none | Pills beside the title. Each takes a string or `{Text, Color}`. |
| `Id` | `"MainWindow"` | The first part of the path shown in the command palette. |
| `Size` | `560 x 752` | Clamped to the screen, so it never opens off-screen. |
| `Position` | centred | A `UDim2`. Windows are kept reachable when the screen size changes. |
| `MenuKey` | `RightShift` | Shows and hides the window. A `KeyCode` or a mouse `UserInputType`. `false` gives the window no key, for windows you open from code, the dock or their close button. |
| `SinkMenuKey` | `true` | Stops the menu key from reaching Roblox, so it never toggles shift lock. See below. |
| `Fill` | `true` | Boxes in a column share the page height. `false` gives content-sized boxes. |
| `Closable` | `false` | Adds a small close button to the header that hides the window. |
| `Watermark`, `Hotkeys` | `true` | The draggable watermark and hotkey list. |
| `WatermarkTitle`, `Icon` | none | Watermark text and logo. |
| `Dock` | `true` | The icon bar. `false` hides it, or pass a list of built-ins (see [Dock](#dock)). |
| `MobileButton` | `true` | When `Dock = false` on a touch-only device, a small round "UI" button toggles the window. |
| `Snow` | off | The theme's particles. `true`, or `{Count, Speed, Kind}`. |
| `Backdrop` | `{Dim = 0.35}` | Screen dim and world blur behind the UI while a window is open. `false` disables it. |
| `ScreenWatermark` | none | Faint text tiled over the whole screen. |

| Method | Description |
|---|---|
| `Window:AddTab(name)` | Returns a Tab. Empty tabs simply show nothing. |
| `Window:AddConfigTab(name?, options?)` | The built-in settings tab (see [Configs](configs.md#the-config-tab)). |
| `Window:SelectTab(tab)` | Switch to a tab object. |
| `Window:SetTabVisible(name, bool)` | Hide or show a tab by name. |
| `Window:CycleTab(step)` | Next (`1`) or previous (`-1`) visible tab. Also **Ctrl+Tab** and **Ctrl+Shift+Tab**. |
| `Window:SetCollapsed(bool)` / `IsCollapsed()` | Fold the window down to its title bar. **Double-clicking the title bar** does the same. |
| `Window:Toggle()` / `SetVisible(bool)` | Show or hide the window. |
| `Window:SetMenuKey(key)` | Change the menu key. Shift-lock protection moves with it. |
| `Window:SetTitle(text)` / `SetSubtitle(text)` / `SetFooter(text)` | Update the header and footer. |
| `Window:Destroy()` | Remove just this window. |

Groups and tabboxes can be removed too, with `group:Destroy()` or `tabbox:Destroy()`. Their settings leave `TingUI.Options` and `TingUI.Flags` with them.

The window drags by its header or its footer strip and resizes from the bottom-right grip. Opening pops it up and closing shrinks it away, and the backdrop fades with it.

**Tab switching.** The highlight is one pill that slides to the clicked tab. The old page drifts out under a soft veil, and the new one slides in from the side you're moving towards. Sub-tabs inside tabboxes do the same.

**Tabs always fit.** A theme with a wide font, a narrow window or a long list of tabs never pushes tabs past the edge. The spacing tightens first, then the labels shrink slightly (never below 84%). Only if that still isn't enough does the bar scroll, sliding the active tab into view, with soft fades marking the hidden side. Nothing changes when the tabs already fit.

## Menu key and shift lock

Roblox binds **both** shift keys to shift lock. When a script uses RightShift or LeftShift as its menu key, pressing it to open the menu can also lock the camera. TingUI claims its menu keys through `ContextActionService` at a priority above Roblox's camera controls and sinks them, so the key toggles your menu and nothing else. It does this for every window's menu key and keeps it up to date when a key is rebound in the config tab or with `Window:SetMenuKey`. It releases the keys when the window is destroyed or TingUI unloads.

> [!NOTE]
> If your game needs the menu key to reach other scripts too, create the window with `SinkMenuKey = false`.

## Tab

| Method | Returns |
|---|---|
| `Tab:AddGroup(title, side)` or `Tab:AddGroup({Title, Icon, Side})` | A Group. `Icon` is a built-in icon name (see [Icons](extending.md#icons)). |
| `Tab:AddTabbox(side)` | A Tabbox. `Tabbox:AddTab(name)` returns a Group. |
| `Tab:AddWarning({Title, Text, Type})` | A banner. The optional `Type` (`Warning`, `Danger`, `Info`, `Success`) tints the title; without it the title is white. |
| `Tab:SetVisible(bool)` | Hide or show the tab button and page. |
| `Tab:Destroy()` | Remove the tab. |

`side` is `"Left"` or `"Right"`. Leave it out to alternate.

**Fill layout.** Boxes in a column split the page height equally, and grow if their content is taller. Pass `Fill = false` to `CreateWindow` for content-sized boxes. The config tab always uses content-sized boxes.

## Hiding sections

```lua
local box = Tab:AddTabbox("Left")
local sub = box:AddTab("Alpha")
sub:SetVisible(false)     -- hides the sub-tab button and its content
sub:Destroy()             -- removes it
box:SetVisible(false)     -- hides the whole tabbox
group:SetVisible(false)   -- hides a group
```

The config tab also has a **Layout** group with an entry for every tab, section, panel and dock button, so players can switch them off from the UI.

## Panels

Panels are free-floating cards outside any window.

```lua
local p = TingUI:CreatePanel({
	Title = "Preview", Subtitle = "optional", Width = 300, Height = 0, Position = UDim2.new(0.5, 0, 0.5, 0),
	Dock = { Icon = "scan", Tooltip = "Preview", Order = 20 },       -- a dock button that shows and hides it
	HeaderIcon = { Icon = "discord", Tooltip = "Invite", Callback = function() end },
})
p:AddLabel("Any element works here")
p:SetVisible(false); p:Toggle(); p:Destroy()
```

`Height = 0` grows with the content. `Visible = false` creates the panel hidden, and it fades in the first time it's shown. Use it for extra windows so a script's first run shows only the main UI. It works for `CreateCredits` and `CreateKeySystem` too.

## Key system and credits

```lua
TingUI:CreateKeySystem({
	Title = "My Hub", Placeholder = "Paste your key",
	Validate = function(key)                     -- your own check
		if key == "secret" then return true end
		return false, "Wrong key"
	end,
	OnSuccess = function() end,
	GetKeyLink = "https://example.com/key", DiscordLink = "https://discord.gg/x",
	Note = "Keys reset every 24 hours.",
})
```

`Validate(key)` is your own function. It must return `true`, or `false, "message"`. `GetKey` (a function) or `GetKeyLink` (copied to the clipboard) powers the "Get key" button, and `DiscordLink` adds the Discord icon, which copies the link when clicked.

```lua
local credits = TingUI:CreateCredits({ Title = "Credits", Subtitle = "Made by",
	Entries = { { Name = "You", Role = "Developer", RoleColor = Color3.fromRGB(255, 120, 160), Description = "Everything." } },
	Height = 0, Dock = { Icon = "heart", Tooltip = "Credits" } })
credits:AddEntry({ Name = "Friend", Role = "Tester" })
```

Inside any group, `group:AddCredits({ {Name, Role, RoleColor, Description}, ... })` puts the same cards there. It returns an object with `:Add(entry)`.

## Dock

The dock is the icon bar at the top centre. Its icons are high-resolution images, so a full setup stays crisp at any UI scale. The menu, hotkey list and command palette buttons show by default. A particles button and a notifications button (the bell, which opens the [notification history](elements.md#handling-a-stack)) also exist but start hidden. The watermark is toggled in the config tab, not the dock.

Pick which built-ins show with `Dock = {"menu", "hotkeys", "notifications", "palette", "particles"}` in `CreateWindow`, or `Dock = false` for none. Every dock button can also be switched on or off in the config tab's Layout group, or with `TingUI:SetDockButtonVisible(name, bool)`, where `name` is its tooltip. Active buttons are highlighted. The dock stays visible when the window is hidden, so it doubles as the mobile toggle. Drag it to move it.

```lua
TingUI:AddDockButton({ Icon = "gear", Tooltip = "Settings", Order = 50, Callback = function() end, Active = function() return true end })
TingUI:SetDockVisible(false)
```

`Order` sorts the buttons: menu is 1, panel buttons default to 20, hotkeys 30, particles 34, notifications 36, palette 40, and custom buttons default to 50.

## HUD

The watermark, hotkey list and dock can all be dragged anywhere.

**Return to place.** After you drag the dock or the hotkey list, it glides back to its spot 5 seconds after you let go, with a smooth 0.75 second ease and never a jump. Grabbing it again before then cancels the return. Everything is adjustable in the config tab's **HUD Positions** group, or from code:

```lua
TingUI.SnapBack = { Enabled = true, Delay = 5, Dock = true, Hotkeys = true, Watermark = false }
TingUI:ResetHudPositions()   -- glide everything home now
TingUI:SetHudHome()          -- make the current spots the new home
```

Other HUD calls: `TingUI:SetWatermarkVisible(bool)`, `SetWatermark("custom text")`, `SetWatermarkTitle(text)`, `SetIcon(assetId | nil)`, `SetHotkeysVisible(bool)` and `SetScreenWatermark(text | nil)`.

## Command palette

Press **Ctrl+K** or click the dock's command button. It searches every named option and shows its path (`MainWindow/Tab/Group`) and current value. Up and Down move, and Enter or a click acts. Toggles flip and buttons run. Anything else jumps to its tab, opens the right sub-tab, scrolls it into view and pulses a highlight around it. Esc closes the palette.

API: `TingUI:OpenPalette()`, `ClosePalette()` and `TogglePalette()`. Load with `Shortcuts = false` if your game needs Ctrl+K or Ctrl+Tab.

## Several scripts at once

When more than one TingUI script runs, they share one dock, one notification stack, one command palette and one hotkey list. The first script hosts, and its dock gets a taskbar button for each of the others. Nothing needs to change in your script. See [The Shell](shell.md).

## Windows from a table

`TingUI:Mount(layout)` builds a whole window from one table, and `ui:Update(newLayout)` changes it in place while keeping every value. `TingUI:MountFile(path)` reloads it every time you save the file. See [Layouts and live reload](layouts.md).

---

**Next:** [Elements](elements.md) · [Themes](themes.md)
