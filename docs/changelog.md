# Changelog

<sub>[Docs](README.md) › Changelog</sub>

## v0.0.7-stable

> [!NOTE]
> Nothing in your script has to change. The three new features are additions: the Shell switches itself on only when a second TingUI script is running (`Shell = false` opts out), and the Theme Studio and layouts are new calls.

**The Shell** ([docs](shell.md))
- Every TingUI script in the game now shares one desktop. The first script with a dock hosts, and the others hide their own dock, watermark and hotkey list.
- The host's dock gets a taskbar: a button per script, with its icon or initials and a dot that lights while it has a window open. Left-click shows or hides it. Right-click offers its own dock buttons, **Use my theme** and **Unload**.
- One notification stack for every script. Each card carries a small label naming the script that sent it. `Notify` also takes `Source` for your own labels.
- Ctrl+K searches every setting in every script, and toggling a result flips it in the script it belongs to. The hotkey list shows every script's keybinds, in a section per script.
- Only one script dims and blurs the screen at a time.
- **Menu key referee**: two scripts on one menu key, or a menu key that's another script's keybind, gets one notification with a button that moves the later script to a free key. Its config tab's menu key chip follows.
- `TingUI.Shell`: `Role`, `IsHost`, `List`, `Host`, `SetName`, `SetIcon`, `ApplyThemeTo`, `ApplyThemeToAll`, `SetEnabled`, and `Joined`, `Left` and `RoleChanged` events. New `Shell` load option: `{Name, Icon}` or `false`.
- The host is chosen by load order, which is remembered for the session, so re-running a script keeps its place. When the host unloads, the next script takes over.

**Theme Studio and share codes** ([docs](theme-studio.md))
- `TingUI:OpenThemeStudio()`, also on the config tab: a window that edits every theme colour and style key live, across Colours, Shape, Light, Motion and Share tabs, including each built-in scene's colours.
- Readability checks with contrast ratios, and **Fix contrast**, which moves failing colours only as far as they need to go. `TingUI.Readable(fg, bg, ratio)` does the same in code.
- **Share codes**: `TingUI:ExportTheme`, `DecodeTheme` and `ImportTheme`. A code is one `TUI1:` line holding data only. Every key is checked against its type and range before anything is installed, so codes are safe to paste from anyone.
- Saved themes: `SaveTheme`, `ListSavedThemes`, `DeleteTheme`. They're kept in a new shared `ThemeFolder` (`TingUI/themes`) through your config storage, load by themselves in every script, and work anywhere a theme name does, such as `Theme = "My Theme"`.
- **Use in every script** gives every running TingUI script your current look.

**Layouts and live reload** ([docs](layouts.md))
- `TingUI:Mount(layout, handlers)` builds a whole window from one table or JSON text, with tabs, groups, tabboxes, every element type, keybind and colour addons, and sub-buttons.
- `ui:Update(layout)` compares versions and rebuilds only what changed. Values, rebinds, the open tab, the window's position and its visibility are kept. A broken layout changes nothing and returns a message pointing at the exact element, with "did you mean" for misspelt types.
- `TingUI:MountFile(source, handlers)` and `TingUI:Watch(source, fn)`: live reload from a workspace file (Lua or JSON), a StringValue or a function. A broken save keeps the last good version and warns once with the line number.
- Callbacks come from the layout (`Callback`), a named handler (`Action`), or a handler named like the element's flag, and they're looked up each time they run.

**Smaller additions**
- `CreateWindow` takes `Closable = true` for a close button in the header, and `MenuKey = false` for a window without a menu key.
- `group:Destroy()` and `tabbox:Destroy()` remove a group with its settings.
- Colour picker and dropdown popups are removed with their element instead of staying hidden on the overlay.
- The dock's menu button follows the window when it's replaced.
- A style change that leaves the particles alone, such as dragging a Theme Studio slider, no longer rebuilds them.

**Tests and docs**
- 22 headless tests. New ones cover the Shell, share codes (including hostile codes), saved themes across instances, the Theme Studio, layouts, live reload from files, StringValues and functions, and the examples in these docs.
- New pages: [The Shell](shell.md), [Theme Studio](theme-studio.md) and [Layouts and live reload](layouts.md), with new images drawn by `tools/build_previews.py`.

## v0.0.6-stable

> [!IMPORTANT]
> **Lumen is now TingUI.** Nothing in your script has to change. `Lumen.lua` keeps working and loads TingUI with the same options, and old configs load as they did before. Removed themes and their particle styles are listed below.

**Renamed to TingUI**
- The library, its file (`TingUI.lua`), its Wally package (`irakli17/tingui`), its folders and its built-in flags (`TingUI_...`) all carry the new name.
- `Lumen.lua` is now a small shim. It downloads `TingUI.lua` (GitHub, then jsDelivr), passes your options through and also reads `getgenv().LumenOptions`.
- Configs saved by Lumen load correctly: `Lumen_` settings are read as `TingUI_` settings. The first time a script with the default folder looks for configs, the configs and autoload choice in the old shared `Lumen` folder are copied into its own folder. The originals stay put.

**Themes**
- Removed **Emerald**, **Arcade** and **Prism**, along with the `Pixels` and `Prisms` particle styles. A removed theme name in a load option, `ApplyPreset` or a saved config now leaves the current theme in place.
- New **Hologram**: a cyan light projection. Corner brackets lock on as it opens, a projector beam glows underneath, telemetry ticks beside it, a scan line sweeps each page, the image tears now and then, and clicks ripple out as hexagons.
- New **Circuit**: the window is a chip on a board. Copper traces run from pins on every edge, current races along them, pins warm under the cursor, a boot chase runs on open and tab switches, and clicks fire bursts with a solder flash.
- New **Abyss**: the deep sea. Light shafts fall from above, jellyfish pulse around the window, plankton glow and part as the cursor passes, and clicks bloom light that startles everything nearby.
- **Scenes**: a new engine for living artwork in and around each window (`Style.Scene`, `TingUI:RegisterScene`, `TingUI.SceneKinds`). Scenes react to clicks, tab switches and the window opening. They pause while hidden, crossfade with theme blends, are destroyed when unused, and switch themselves off with one warning if they error. Any theme can borrow one.
- New particle styles: `Holo`, `Static` and `MarineSnow`.
- **Reduced motion**: `ReducedMotion` load option, `TingUI:SetReducedMotion`, and a toggle in the config tab. It holds scenes and particles still and stops glitches, lightning, flicker, aura rotation and texture drift.
- Josefin Sans is in the font list.

**Stable in any project**
- The menu key never toggles shift lock, for RightShift or LeftShift. TingUI sinks it through `ContextActionService` above Roblox's camera controls, follows rebinds and releases it on unload. Opt out with `SinkMenuKey = false`. New `Window:SetMenuKey(key)`.
- The UI keeps its size:
  - Windows no longer open squashed when TingUI is required before the screen has been measured.
  - **ScaleGuard** removes `UIScale` and `UIAspectRatioConstraint` objects other scripts insert. Turn it off with `ScaleGuard = false`.
  - The ScreenGui's safe-area, inset and auto-translate properties are pinned.
  - Windows are nudged back into reach when the screen size changes.
- Each script keeps its configs in its own folder (`TingUI/<Id>`), so one script's autoload never changes another's theme or scale. Downloads go to a shared `CacheFolder`, so they're only fetched once.

**Executors**
- `TingUI.Environment` reports the executor's name and version and what it supports: files, custom assets, clipboard, HTTP and a hidden GUI container.

**Docs and tooling**
- New GitHub docs in `docs/`, with a theme gallery, animated scene previews and a labelled window diagram. `DOCS.md` now points there.
- `tools/build_previews.py` draws every docs image straight from the presets in `TingUI.lua`.
- 15 headless tests. New ones cover scenes, shift lock, scale stability, the Lumen compatibility path and the code examples in these docs.

## v0.0.5-stable
- Drop-in for any Roblox game: require it as a ModuleScript and it parents to PlayerGui, reads options from its attributes, and errors clearly if required on the server.
- `TingUI.new(options)` builds independent instances, `TingUI:Configure(options)` changes options after loading, and `TingUI:SetParent(instance)` moves the GUI.
- Pluggable config storage (`TingUI:SetStorage`, `Storage` option) with file, memory and DataStore adapters (`extras/DataStoreStorage.lua`). Configs now work outside executors.
- `TingUI:ExportConfig()` and `TingUI:ImportConfig(json)`. Config names with `/` or `\` are refused, and config errors come back as messages instead of throwing.
- `Shortcuts = false` turns off Ctrl+K and Ctrl+Tab.
- Rojo (`default.project.json`, `dev.project.json`) and Wally (`wally.toml`) support, a Studio demo, and headless tests (`sh tests/run.sh`).

## v0.0.4-stable
- Fixed: dropdown values, and sometimes tab names, going blank after picking something. A theme's font fade restored text to whatever transparency it had mid-animation; it now always returns to its resting value.
- Fixed: the tab highlight pill getting stuck between tabs, mostly after theme switches. It re-aims when tab widths change mid-glide, and a watchdog keeps it on the active tab.
- Fixed: leftover colours from the previous theme. A settle pass re-applies the final theme after hover animations finish, and placeholders, the resize grip and tab banners now follow the theme.
- Hover hints no longer appear over an open dropdown or colour picker.
- Sharper, more readable text: hints, notifications and the confirm dialog no longer use CanvasGroups (new `TingUI.Fader`). Hint and notification body text is larger and brighter, and picked dropdown rows choose the higher-contrast text colour.
- Themes: removed Synthwave, Noir, Haunted and Parchment. Cosmos was rebuilt with drifting nebula and star art and the new Galaxy particles. New **Criminality** (brick alley, flickering street lamp, glitches, dust, blade glints) and **MLG** (doritos, hitmarkers, rainbow everything).
- Theme textures: `Style.Texture`, `Style.BackdropTexture`, `Style.Glitch` and `CycleSpeed`. Images are generated by `tools/build_textures.py`, loaded on demand and cached (`TextureBase`, `Textures` load options).
- New particles: Galaxy, Grit and MLG.

## v0.0.3-stable
- High-resolution icons: 96 px PNGs tinted to the theme, cached on disk, with a vector fallback (`AssetBase`, `Icons`, `NoImages`; `tools/build_icons.py` rebuilds them).
- Seven new themes (Blueprint, Noir, Prism, Hazard, Glass, Haunted, Parchment) and seven new particle styles, with new style keys: `Grid`, `Vignette`, `SurfaceTransparency`, `Blur`, `AccentCycle`, `AuraHard` and `AuraRotation`.
- Fixed: some themes showed an empty window, because overlay frames fed back into auto-sized panels and the dock. Borders now animate on the surface's own stroke.
- Hover hints sit beside the window, panel or dock instead of covering the element under the mouse.
- Dropdowns unfold and cascade, with separate hover and press feedback, an accent fill and check mark on pick, a value that slides in and a turning chevron.
- Viewport `Highlight` (fill and silhouette outline) and `SetHighlight`. `SetESP({Color})` recolours the ESP overlay.
- Config tab: Layout is organised into dropdowns, and the default preset is labelled "Lavender (Default)".
- Tab highlight pill: an accent border, top sheen, underline and soft glow, plus a hover ghost on other tabs.
- Panels accept `Visible = false` (CreatePanel, CreateCredits, CreateKeySystem) and fade in when shown.
- Example: only the main window shows on first run, Lighting moved to World, highlight controls were added, and "Cool Toggle With Colors" is explained and wired to the preview.

## v0.0.2-stable
- Integration: load options as a loadstring argument, per-script instances (`Id`, `Reuse`), `Loader.lua` with a CDN mirror and offline cache, ModuleScript and Studio support, and `Parent` / `DisplayOrder` options.
- Events, flag helpers, `Request` and `Clipboard` helpers, and safe callbacks with error notifications.
- Extension API: `RegisterElement`, `RegisterTheme`, `RegisterParticles`, `RegisterIcon` and `TingUI.API`.
- Seven new themes (Synthwave, Frost, Royal, Candy, Arcade, Cosmos, Storm) with their own fonts, borders, accent gradients and particles, seven new particle styles, and support for any Roblox font.
- Everything morphs when the theme changes: colours, corners, glow, fonts, window lighting, borders and particles.
- Sliding tab and sub-tab indicators, page transitions, window open, close and collapse animations, unfolding popups, a backdrop fade and button ripples.
- Hover explanations on every element and config setting.
- New elements: player dropdown, progress bar and paragraph. Dropdowns became searchable, slider values can be typed in, and toggles can be marked risky.
- Notifications: distinct badge shapes, centred glyphs, per-type motion, action buttons and four screen positions.
- The command palette jumps to the element and highlights it, and Ctrl+Tab switches tabs.

## v0.0.1-stable
First stable release.
- Themes change shape, glow, font, surface and particles, not just colour, and switching blends smoothly.
- Seven particle styles, selectable or theme-driven.
- The dock and hotkey list glide back to their spot after dragging, with a configurable delay and targets.
- Animated notifications for success, warning, error, info and loading, with morphing handles, hover-to-pause and click-to-dismiss.
- ESP preview overlay on viewports (box, name, health, distance).
- The watermark button was removed from the dock.
