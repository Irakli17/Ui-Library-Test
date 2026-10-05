--!nonstrict
--[[
	Vantage 1.0.0
	==================================================================
	Interface, engineered.

	Vantage is a Roblox interface library built the way a component
	library should be: seeded themes derived with real colour maths, one
	shared animation scheduler for the whole application, components that
	report their own feedback, and a loading screen that tells the truth
	about what it is doing.

	Quick start
	-----------
	    local Vantage = require(game.ReplicatedStorage.Vantage)

	    -- The wave mark in the corner of the safe area while assets stream in.
	    Vantage.LoadingScreen.Run({
	        Assets = { "rbxassetid://0" },
	        Logo = { Image = "rbxassetid://0" },
	    }).wait()

	    local window = Vantage.Window.new({
	        Name = "My Game",
	        Subtitle = "Settings",
	        Theme = "obsidian",
	    })

	    local general = window:Tab({ Name = "General", Icon = "sliders" })
	    local section = general:Section({ Name = "Appearance", Description = "…" })
	    section:Toggle({ Name = "Reduce motion", Value = false, Callback = print })
	    section:Slider({ Name = "Interface scale", Min = 0.75, Max = 1.5, Value = 1 })

	The namespace below is the entire public surface. Every sub-module is
	exported so you can build standalone components without a window:

	    local button = Vantage.Button.new({ Text = "Save" }, { parent = myFrame })

	Nothing in this library requires a network request, an upload, or an
	account. The mark renders procedurally until you point it at your own
	asset ID.
]]

--[[ Core ------------------------------------------------------------ ]]

local Core = script.Core

local Util = require(Core.Util)
local Signal = require(Core.Signal)
local Maid = require(Core.Maid)
local Easing = require(Core.Easing)
local Motion = require(Core.Motion)
local Theme = require(Core.Theme)
local Config = require(Core.Config)
local Glyph = require(Core.Glyph)

--[[ Layout ---------------------------------------------------------- ]]

local Layout = script.Layout

local Window = require(Layout.Window)
local Tab = require(Layout.Tab)
local Section = require(Layout.Section)
local Elements = require(Layout.Elements)
local Field = require(Layout.Field)

--[[ Primitives ------------------------------------------------------ ]]

local Primitives = script.Primitives

local Button = require(Primitives.Button)
local Toggle = require(Primitives.Toggle)
local Slider = require(Primitives.Slider)
local Dropdown = require(Primitives.Dropdown)
local Input = require(Primitives.Input)
local Keybind = require(Primitives.Keybind)
local Segmented = require(Primitives.Segmented)
local Progress = require(Primitives.Progress)
local Ripple = require(Primitives.Ripple)

--[[ Overlay --------------------------------------------------------- ]]

local Overlay = script.Overlay

local Notify = require(Overlay.Notify)
local Modal = require(Overlay.Modal)
local Tooltip = require(Overlay.Tooltip)
local CommandPalette = require(Overlay.CommandPalette)

--[[ Feedback -------------------------------------------------------- ]]

local Feedback = script.Feedback

local LoadingScreen = require(Feedback.LoadingScreen)
local LogoWave = require(Feedback.LogoWave)

--[[ Namespace ------------------------------------------------------- ]]

local Vantage = {}

Vantage.name = "Vantage"
Vantage.version = Util.version
Vantage.build = Util.build

-- Core
Vantage.Util = Util
Vantage.Signal = Signal
Vantage.Maid = Maid
Vantage.Easing = Easing
Vantage.Motion = Motion
Vantage.Theme = Theme
Vantage.Config = Config
Vantage.Glyph = Glyph

-- Structure
Vantage.Window = Window
Vantage.Tab = Tab
Vantage.Section = Section
Vantage.Elements = Elements
Vantage.Field = Field

-- Controls
Vantage.Button = Button
Vantage.Toggle = Toggle
Vantage.Slider = Slider
Vantage.Dropdown = Dropdown
Vantage.Input = Input
Vantage.Keybind = Keybind
Vantage.Segmented = Segmented
Vantage.Progress = Progress
Vantage.Ripple = Ripple

-- Overlays
Vantage.Notify = Notify
Vantage.Modal = Modal
Vantage.Tooltip = Tooltip
Vantage.CommandPalette = CommandPalette

-- Feedback
Vantage.LoadingScreen = LoadingScreen
Vantage.LogoWave = LogoWave

--- The list of themes available out of the box, as `{ name, label,
--- description, mode, category, swatch }`. Used by theme pickers and by
--- the documentation's live theme gallery.
function Vantage.Themes()
	return Theme.list()
end

--- Switches theme across the whole interface with a token morph.
--- @param name string Theme name, or a hex seed like "#34D399".
--- @param options { transition?: boolean | {}, mode?: "dark" | "light" }
function Vantage.SetTheme(name: string, options: { [any]: any }?)
	return Theme.apply(name, options)
end

--- Registers a custom theme. Accepts a hex seed or a full token table.
---
---     Vantage.RegisterTheme("harbour", { seed = "#34D399", mode = "dark" })
function Vantage.RegisterTheme(name: string, definition: { [any]: any })
	return Theme.register(name, definition)
end

--- Builds a theme from a single accent colour.
function Vantage.ThemeFromSeed(seed: string, mode: string?)
	return Theme.fromSeed(seed, mode or "dark")
end

--- Serialises a theme to Luau source you can paste into a project.
function Vantage.ExportTheme(name: string): string
	return Theme.export(name)
end

--- Creates a window. Alias kept because `Vantage:CreateWindow(spec)`
--- reads naturally for people coming from other libraries.
function Vantage.CreateWindow(spec: { [any]: any })
	return Window.new(spec)
end

--- One-call bootstrap. Applies a theme, wires accessibility flags from
--- the player's system settings, and returns the library so it can be
--- chained:
---
---     local Vantage = require(path).Setup({ Theme = "porcelain" })
function Vantage.Setup(options: { [any]: any }?)
	local opts = options or {}

	if opts.Theme then
		Theme.apply(opts.Theme)
	end

	if opts.Animations ~= nil then
		Config.set("animations", opts.Animations == true)
	end

	-- Respect the player's OS-level reduced-motion preference unless the
	-- host explicitly opted out.
	local reduced = Config.respectSystemReducedMotion and Util.prefersReducedMotion()
	Motion.setReducedMotion(not Config.animations or reduced)

	if opts.Config then
		Config.merge(opts.Config)
	end

	if opts.Tagging ~= nil then
		Config.set("tagging", opts.Tagging == true)
	end

	return Vantage
end

--- Diagnostics: what the animation engine is doing right now. Useful in
--- a debug overlay, and used by the test suite.
function Vantage.Diagnostics()
	local inset = Util.insets()
	local viewport = Util.viewport()
	return {
		version = Vantage.version,
		theme = Theme.name(),
		mode = Theme.mode(),
		animations = Config.animations,
		reducedMotion = Motion.getReducedMotion(),
		motion = Motion.stats(),
		viewport = { width = viewport.X, height = viewport.Y },
		insets = inset,
		breakpoint = Util.breakpoint(),
		loadedAt = os.clock(),
	}
end

--- The window currently on screen, if any. Vantage keeps one interface at a
--- time: creating a second window replaces the first rather than stacking it,
--- and re-running the same loadstring therefore never leaves two shells on
--- top of each other.
function Vantage.GetWindow()
	return Window.Current()
end

--- The loading screen currently on screen, if any.
function Vantage.GetLoadingScreen()
	return LoadingScreen.Current()
end

--- Destroys every Vantage interface on screen — window and loading screen —
--- whichever copy of the library created it. Safe to call more than once, and
--- safe to call when nothing is on screen.
function Vantage.Destroy()
	local registry = Util.registry()

	local window = registry.window
	if window and type(window.Destroy) == "function" then
		pcall(function()
			window:Destroy()
		end)
	end
	registry.window = nil

	local loading = registry.loadingScreen
	if loading and type(loading.Destroy) == "function" then
		pcall(function()
			loading:Destroy()
		end)
	end
	registry.loadingScreen = nil
end

--- Every instance Vantage has tagged. Requires
--- `Config.tagging` to be enabled (default).
function Vantage.GetInstances()
	local ok, CollectionService = pcall(function()
		return game:GetService("CollectionService")
	end)
	if not ok or not CollectionService then
		return {}
	end
	return CollectionService:GetTagged(Config.tag)
end

return Vantage
