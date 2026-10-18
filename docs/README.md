<p align="center">
  <img src="images/banner.png" alt="TingUI" width="100%">
</p>

# TingUI documentation

<sub>v0.0.8-stable · [Back to the project](../README.md)</sub>

<table>
  <tr>
    <td width="50%" valign="top">

### Start here
- [**Getting started**](getting-started.md): loading on executors and in games, every load option, your first window
- [**Windows and layout**](windows.md): windows, tabs, groups, panels, dock, HUD, command palette, menu keys
- [**Elements**](elements.md): every element and addon, hover explanations, dialogs, notifications

</td>
    <td width="50%" valign="top">

### Make it yours
- [**Themes**](themes.md): the 15 presets, scenes, particles, textures, fonts, scale, your own theme
- [**Configs**](configs.md): the config tab, saving, storage adapters, DataStore, events, flags
- [**Extending**](extending.md): your own elements, particles, icons and scenes

</td>
  </tr>
  <tr>
    <td valign="top">

### Build faster
- [**Layouts and live reload**](layouts.md): a whole window from one table, updated in place every time you save
- [**Theme Studio**](theme-studio.md): make themes live, check contrast, share them as codes

</td>
    <td valign="top">

### Play well with others
- [**The Shell**](shell.md): every TingUI script on screen shares one dock, palette, hotkey list and notification stack

</td>
  </tr>
  <tr>
    <td valign="top">

### Ship it
- [**Executors**](executors.md): what TingUI uses, fallbacks, files, one instance per script
- [**Stability**](stability.md): how the UI stays the same in every project, and the compatibility promise

</td>
    <td valign="top">

### What's new
- [**Changelog**](changelog.md): what changed in each release
- [**Roadmap**](roadmap.md): the big features, design work and executor support coming next

</td>
  </tr>
</table>

## Find it fast

| I want to... | Go to |
|---|---|
| Load TingUI in my executor script | [On an executor](getting-started.md#on-an-executor) |
| Use TingUI in my own Roblox game | [In a Roblox game](getting-started.md#in-a-roblox-game) |
| See every option `loadstring` and `require` take | [Load options](getting-started.md#load-options) |
| Stop RightShift from turning on shift lock | [Menu key and shift lock](windows.md#menu-key-and-shift-lock) |
| Stop another script from resizing my UI | [The UI keeps its size](stability.md#the-ui-keeps-its-size) |
| Save configs in a DataStore | [DataStore in a real game](configs.md#datastore-in-a-real-game) |
| Pick or make a theme | [Themes](themes.md#the-presets) and [Your own theme](themes.md#your-own-theme) |
| Write my own animated scene | [Scenes](extending.md#scenes) |
| Make TingUI quieter for players | [Reduced motion](themes.md#reduced-motion) |
| Find out what my executor supports | [The environment report](executors.md#the-environment-report) |
| Pin a version so updates never surprise me | [Pinning a version](stability.md#pinning-a-version) |
| Edit my UI and see it change without re-running | [Live reload](layouts.md#live-reload) |
| Describe a window as a table or JSON | [The layout format](layouts.md#the-layout-format) |
| Make a theme without writing code | [Theme Studio](theme-studio.md#opening-the-studio) |
| Share a theme, or install someone else's | [Share codes](theme-studio.md#share-codes) |
| Stop two scripts fighting over one key | [Menu key clashes](shell.md#menu-key-clashes) |
| Keep my script's dock to itself | [Staying out of the Shell](shell.md#staying-out-of-it) |

## The shape of a window

<p align="center">
  <img src="images/anatomy.png" alt="The parts of a TingUI window, numbered" width="100%">
</p>
