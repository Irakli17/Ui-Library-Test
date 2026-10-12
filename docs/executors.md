# Executors

<sub>[Docs](README.md) › Executors</sub>

TingUI was built for `loadstring` first. It looks for each executor function before using it and has a fallback for every one, so the same script runs on a full-featured executor, a minimal one, in Studio or in a published game.

- [What TingUI uses](#what-tingui-uses)
- [The environment report](#the-environment-report)
- [Where files go](#where-files-go)
- [One instance per script](#one-instance-per-script)
- [Loading reliably](#loading-reliably)
- [Good habits](#good-habits)

## What TingUI uses

| Function | What TingUI uses it for | Without it |
|---|---|---|
| `game:HttpGet` | Loading the library, fonts, icons and theme art | Needed for `loadstring`. In a game, use `require` instead. |
| `getgenv` | Keeping track of each script's instance, and `getgenv().TingUIOptions` | Uses `_G` |
| `gethui` | A hidden container for the ScreenGui | CoreGui, then the player's PlayerGui |
| `syn.protect_gui` | Protecting the ScreenGui on executors that have it | Skipped |
| `cloneref` | Wrapping service references | Uses `game:GetService` directly |
| `writefile`, `readfile`, `isfile`, `isfolder`, `makefolder`, `listfiles` | Saving configs and caching downloads | Configs live in memory for the session, and downloads aren't cached |
| `delfile` | Deleting configs | Delete reports that it isn't supported |
| `getcustomasset` | The Inter font, high-res icon PNGs and theme art | Gotham, crisp vector icons, themes without painted art. Scenes are unaffected. |
| `request`, `http_request`, `syn.request`, `http.request`, `fluxus.request` | `TingUI:Request` | Returns `nil, "this executor has no HTTP request function"` |
| `setclipboard`, `toclipboard`, `set_clipboard` | `TingUI:Clipboard` and the key system's link buttons | Returns `false` |
| `identifyexecutor`, `getexecutorname` | `TingUI.Environment.Executor` | `Executor` is `nil` |

## The environment report

`TingUI.Environment` is worked out once at load. Scripts can adapt to it, and it's the first thing to paste into a bug report.

```lua
local E = TingUI.Environment
-- { Executor = "Name", ExecutorVersion = "1.2", Files = true, CustomAssets = true, Clipboard = true,
--   Http = true, HiddenGui = true, Studio = false, Version = "0.0.7" }

if not E.Files then
	TingUI:Notify({ Title = "Heads up", Content = "Your executor can't save files, so configs reset when you leave.", Type = "Warning" })
end
```

## Where files go

```text
TingUI/                  CacheFolder, shared by every script
├── fonts/               Inter, downloaded once
├── icons/v1/            icon PNGs
├── textures/v1/         theme art (nebula, brick, lamp, ...)
├── themes/              ThemeFolder: themes saved from the Theme Studio, shared by every script
│   └── Midnight Mint.tui
├── TingUI-main.lua      Loader.lua's offline copy
├── autoload.txt         configs and autoload for the default Id
├── legit.json
└── MyHub/               Folder for Id = "MyHub"
    ├── autoload.txt
    └── legit.json
```

- `Folder` (default `TingUI/<Id>`) holds a script's configs and autoload choice. Two scripts never share settings by accident.
- `CacheFolder` (default `TingUI`) holds downloads. It's shared on purpose, so fonts and images are only downloaded once for every script.
- `ThemeFolder` (default `TingUI/themes`) holds the themes you save. It's shared too, so a theme you make in one hub is in every hub's preset list.
- Files are only written when they're needed. A script that never saves a config never creates its folder.

## One instance per script

Every script that loads TingUI gets its own instance, keyed by `Id`.

| You want | Do this |
|---|---|
| Re-running a script to replace its old UI | Give it an `Id`. The previous instance with that Id unloads itself first. |
| Two scripts to share one UI | Load both with the same `Id` and `Reuse = true`. The second gets the running instance back. |
| Several separate UIs from one script | `TingUI.new({ Id = "Second" })` |
| To find a running instance | `getgenv().TingUIInstances[id]` |

`TingUI:Unload()` runs your `Events.Unloading` handlers, removes the GUI, disconnects every event, releases the menu keys and removes the instance from `TingUIInstances`.

Instances with different Ids share the screen through [the Shell](shell.md): one dock with a taskbar button per script, one notification stack, one command palette and one hotkey list. Load with `Shell = false` to keep a script on its own.

## Loading reliably

```lua
local TingUI, err = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Loader.lua"))()({
	Id = "MyHub",
	Version = "v0.0.7-stable",   -- pin a release so updates never surprise your users
})
if not TingUI then return warn(err) end
```

`Loader.lua` does four things:

1. It tries raw.githubusercontent.com, then the jsDelivr CDN mirror, which helps when GitHub is slow or blocked.
2. It checks that the download really is TingUI before running it.
3. It keeps a copy on disk, if your executor has `writefile`, and falls back to it when you're offline.
4. It returns `nil` plus a readable error instead of crashing your script.

You can also pass options through `getgenv().TingUIOptions = {...}` before any `loadstring`. They're read once and cleared, so the next script starts clean.

> [!TIP]
> Old `Lumen.lua` links still work. `Lumen.lua` downloads `TingUI.lua` with the same options and returns it, and it also reads `getgenv().LumenOptions`.

## Good habits

- **Give every script an `Id`.** It keeps re-runs clean and configs separate.
- **Restore what you change.** Put cleanup in `TingUI.Events.Unloading`, such as walk speed, lighting or connections you made. The config tab's Unload button and re-running both call it.
- **Pin a version for public scripts.** Use `Version` with `Loader.lua`, or a tag in the raw URL. See [Stability](stability.md#pinning-a-version).
- **Turn off what clashes.** Use `Shortcuts = false` if a game uses Ctrl+K or Ctrl+Tab, and `SinkMenuKey = false` if your menu key has to reach other scripts.
- **Use `ReducedMotion` for heavy games.** It holds scenes and particles still while keeping every theme's look.
- **Iterate with live reload.** Keep your layout in a workspace file and mount it with `TingUI:MountFile("MyHub/layout.lua", handlers)`. Every save updates the open window. See [Layouts and live reload](layouts.md#live-reload).

---

**Next:** [Stability](stability.md) · [Extending](extending.md)
