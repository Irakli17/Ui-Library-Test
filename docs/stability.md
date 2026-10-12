# Stability

<sub>[Docs](README.md) › Stability</sub>

TingUI is meant to be dropped into a project and then forgotten about. It should look and behave the same in every game, on every device and in every executor, and updating it shouldn't mean rewriting your script. This page explains how it keeps that promise.

- [The UI keeps its size](#the-ui-keeps-its-size)
- [The menu key never triggers shift lock](#the-menu-key-never-triggers-shift-lock)
- [Scripts don't share settings by accident](#scripts-dont-share-settings-by-accident)
- [Compatibility promise](#compatibility-promise)
- [Pinning a version](#pinning-a-version)
- [If something still looks off](#if-something-still-looks-off)

## The UI keeps its size

TingUI's size is `TingUI.Scale`, and only `TingUI:SetScale`, the config tab's **UI scale** slider or a config you load can change it. Everything below used to change the size of the UI from one project to the next, and each one is now handled:

| What used to happen | Why | What TingUI does now |
|---|---|---|
| Windows opened squashed to their minimum size | A game's LocalScript required TingUI before its ScreenGui had measured the screen, so it read 0 x 0 | Falls back to the camera's viewport size, then to 1280 x 720 |
| The whole UI grew or shrank in some games | "Auto-scale" scripts drop a `UIScale` or `UIAspectRatioConstraint` into every GUI they find | **ScaleGuard** removes any it didn't create and warns once in the output |
| One script's UI picked up another script's UI scale | Every script shared one config folder, so one script's autoload landed in another's UI | Each script keeps its configs in `TingUI/<Id>` |
| Layout shifted on phones and some devices | Safe-area insets and notch clipping moved and clipped the ScreenGui | `ScreenInsets`, `ClipToDeviceSafeArea` and `SafeAreaCompatibility` are pinned off, and `IgnoreGuiInset` is on |
| Text widths changed in other languages | Roblox's auto-translation rewrote labels | `AutoLocalize` is off for the TingUI ScreenGui |
| Windows ended up off-screen after resizing | The window kept its old position | Windows are nudged back into reach when the screen changes size, and their size never changes |
| The UI vanished on respawn | ScreenGuis in PlayerGui reset when the character respawns | `ResetOnSpawn` is off |

> [!NOTE]
> If your project relies on putting a `UIScale` inside TingUI on purpose, load with `ScaleGuard = false`, or set `TingUI.ScaleGuard = false` at any time. TingUI's own scaling objects carry the attribute `TingUI` and are always left alone.

## The menu key never triggers shift lock

Roblox binds both RightShift and LeftShift to shift lock. TingUI claims every window's menu key through `ContextActionService`, at a priority above Roblox's camera controls, and sinks it. The key opens and closes your menu and does nothing else. The binding follows the key when it's rebound, and it's released when the window is destroyed or TingUI unloads. Opt out per window with `SinkMenuKey = false`. See [Menu key and shift lock](windows.md#menu-key-and-shift-lock).

## Scripts don't share settings by accident

| Thing | Scope |
|---|---|
| The UI, flags, theme and windows | Per instance (`Id`). Re-running a script only replaces its own UI. |
| Configs and the autoload choice | Per `Folder`, which defaults to `TingUI/<Id>` |
| Downloaded fonts, icons and textures | Shared through `CacheFolder`, so they're only downloaded once |
| Themes you save in the Theme Studio | Shared through `ThemeFolder`, on purpose, so your themes are in every script |
| The dock, notification stack, command palette and hotkey list | Shared on screen through [the Shell](shell.md) when several scripts run. Each script's settings stay its own. `Shell = false` opts out. |
| Shortcuts (Ctrl+K, Ctrl+Tab) | Per instance, and off with `Shortcuts = false` |

## Compatibility promise

From v0.0.6 on, an update shouldn't make you change your script:

- **Names stay.** Functions, options, element methods, events and flag names aren't renamed or removed. When something has to change, the old name keeps working alongside the new one. For example, `TingUI.SetParticlesEnabled` still points at `SetSnow`.
- **Defaults stay.** A new feature that would change how existing scripts look or behave starts switched off, or comes with an option to turn it off.
- **Configs stay.** Configs saved by an older version keep loading. The rename from Lumen is the proof: `Lumen_` settings are read as `TingUI_` settings, and old configs are copied into each script's new folder.
- **Links stay.** `Lumen.lua` and `Loader.lua` keep working at the same URLs.
- **Removals are announced.** Anything that does go away is listed in the [changelog](changelog.md) first. A removed theme name, whether in a load option, `ApplyPreset` or an old config, leaves the current theme in place instead of erroring.

## Pinning a version

For a public script, pin the version you tested with. Your users then get exactly that build until you choose to update.

| How you load | How to pin |
|---|---|
| `Loader.lua` | `Version = "v0.0.7-stable"` |
| Raw URL | Swap `main` for a tag: `.../Ui-Library-Test/v0.0.7-stable/TingUI.lua` |
| Wally | `TingUI = "irakli17/tingui@0.0.7"` |
| Rojo or a ModuleScript | The copy in your place is yours, so it only changes when you replace it |

## If something still looks off

1. Look in the output for a `[TingUI]` warning. TingUI tells you when it removed something or switched a feature off.
2. Check `TingUI.Scale`. If it isn't what you expect, a config set it, so look at `TingUI:GetAutoload()`.
3. Check `TingUI.Environment` (see [Executors](executors.md#the-environment-report)) to see what your executor supports.
4. Run `sh tests/run.sh` if you changed `TingUI.lua` yourself. The tests cover all of the above.

---

**Next:** [Extending](extending.md) · [Changelog](changelog.md)
