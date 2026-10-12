# Roadmap

<sub>[Docs](README.md) › Roadmap</sub>

v0.0.6 made TingUI safe to drop into any project and gave it themes that move. v0.0.7 shipped the first three big features from this page. What's left covers what could come next: the big features that would change what TingUI is, the design work that would lift every element, and more executor support. Nothing below is built yet.

- [Shipped in v0.0.7](#shipped-in-v007)
- [Big features](#big-features)
- [Design improvements](#design-improvements)
- [Executor support](#executor-support)
- [Suggested order](#suggested-order)

## Shipped in v0.0.7

Three of the big features from this page are now part of TingUI:

| Feature | What it became |
|---|---|
| **TingUI Shell** | Every TingUI script shares one dock with a taskbar, one command palette, one notification stack and one hotkey list, and menu key clashes are fixed with one click. See [The Shell](shell.md). |
| **Theme Studio and share codes** | A live theme editor with contrast checks, saved themes shared by every script, and `TUI1:` codes that are safe to paste. See [Theme Studio](theme-studio.md). |
| **Declarative layouts and live reload** | `TingUI:Mount`, `ui:Update` and `TingUI:MountFile`: a window from one table, updated in place, reloaded on every save. See [Layouts and live reload](layouts.md). |

Still open from those plans: a community theme gallery that TingUI can browse and install from, and per-script theme overrides inside the Shell.

## Big features

### 1. Gamepad, keyboard and phone-first input

Inside real games, a large share of players are on controllers and phones. Full input support would make TingUI usable by everyone in a game, not only mouse users.

- **Focus navigation.** Tab, the arrow keys and the D-pad move a visible focus ring. A selects and B goes back. It works with `GuiService.SelectedObject`.
- **A phone layout.** Below a width breakpoint, windows switch to one column with larger hit targets, and dropdowns open as bottom sheets.
- **Controller hints.** Small button glyphs (A, B, LB, RB) appear beside the actions they trigger.

### 2. A visual builder, inside TingUI

A TingUI window that builds TingUI windows. You drag elements into groups, edit their options in an inspector, try every theme on the result and export clean Lua, either as calls or as a declarative layout. People who don't write UI code could design a whole hub, and people who do would get a fast way to sketch one. Layouts and `ui:Update` from v0.0.7 are its foundation: the builder edits a layout, and the window you're designing is that layout mounted live.

### 3. A performance governor

TingUI doesn't measure its own cost yet. The governor would time its per-frame work and, when the game's frame rate drops, step down on its own. It would thin particles first, then freeze scenes, then drop the world blur, and recover when there's headroom again. A **Performance** readout in the config tab would show what it's doing, and `TingUI:Profile()` would report where the time goes.

### 4. Per-game profiles

Configs keyed by the game, automatically. Autoload picks the profile saved for the current `PlaceId` (or the whole universe), and each setting can be scoped to "this game" or "everywhere". A hub with one config per game becomes the default instead of something every script author builds by hand.

### 5. Notification centre and activity log

A panel holding every notification from the session, plus script errors with their full tracebacks and a copy button. Error toasts would link straight to their entry. It turns "something went wrong" into a bug report the player can actually send.

### 6. Data elements

Scripts that show stats need more than labels: sparklines and bar charts, sortable tables, a tree view, a scrolling log console and a read-only code view, all themed and animated like the rest.

## Design improvements

These would lift every element at once rather than adding new ones.

| Improvement | What changes |
|---|---|
| **Spacing and type tokens** | One spacing scale (4, 8, 12, 16) and one type ramp used by every element, so rows, labels and groups line up exactly in every theme |
| **Density modes** | Compact and Comfortable, switchable in the config tab. Compact suits hubs with many settings, and Comfortable suits phones. |
| **Motion tokens** | Shared durations and easing curves for every animation, so motion feels like one system. Reduced motion already plugs into it. |
| **Inline element states** | Buttons show a spinner while their callback runs, inputs flash red with a message when a value is rejected, and toggles show a pending state while they wait |
| **Collapsible groups** | Groups fold to their title, and remember it in configs |
| **Empty states** | A tab with nothing in it shows a short message instead of a blank page |
| **Window snapping** | Windows snap to screen edges and to each other, and two windows can tile side by side |
| **More icons** | A larger icon set, and icons on tabs |

## Executor support

Already built: an environment report (`TingUI.Environment`), a fallback for every executor function, a hidden GUI container, a loader with a mirror and offline cache, per-script instances and safe re-running (v0.0.6), and live reload from workspace files and the Shell (v0.0.7).

| Idea | What it gives players |
|---|---|
| **Teleport persistence** | With `PersistAcrossTeleport = true`, `queue_on_teleport` re-runs the script after a server hop and restores its flags, open tab and window position. |
| **Focus-aware pausing** | Scenes and particles pause while Roblox isn't the focused window (`isrbxactive`), which saves CPU when players alt-tab. |
| **Your own images from disk** | Put a PNG in `TingUI/images/` and use `Image = "file:logo.png"`. TingUI loads it through `getcustomasset`. |
| **Update notices** | Opt in to a check against the latest GitHub release, with a notification that links to the changelog. |
| **Companion app** | An optional local web page, connected over `WebSocket` to localhost only, for editing configs, reading logs and building themes on a bigger screen. Off by default. |
| **Executor quirk table** | Small per-executor adjustments driven by `TingUI.Environment`, such as path separators, broken `listfiles` results or missing font support, kept in one place instead of scattered checks. |
| **Crash reports** | One button copies the environment report plus the last error's traceback. |

## Suggested order

| # | Feature | Size | Why this position |
|---|---|---|---|
| 1 | Gamepad, keyboard and phone input | Medium | Opens TingUI to every player in a real game |
| 2 | Performance governor | Small | Protects every feature that comes after it |
| 3 | Visual builder | Large | Layouts and live reload are in place, so it can be built on them now |
| 4 | Per-game profiles | Small | A quick win for hubs |
| 5 | Notification centre | Small | A quick win for support, and the Shell already gathers every script's notifications in one place |
| 6 | Data elements | Medium | Whenever scripts ask for them |

Design improvements and executor support can land alongside any of these, a few at a time.
