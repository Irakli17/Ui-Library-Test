--!nonstrict
--[[
	Vantage 1.0.0 · Core/Config
	------------------------------------------------------------------
	Library-wide runtime configuration. Every flag here is observable,
	so components can react to a config change without being rebuilt.
]]

local Signal = require(script.Parent.Signal)

local Config = {}

Config.name = "Vantage"
Config.version = "1.0.0"
Config.build = "1.0.0-stable"

--- Master animation switch. When false, every transition collapses to
--- a direct property write while keeping the same code path.
Config.animations = true

--- Accessibility: also honours the player's OS-level reduced-motion
--- preference unless explicitly overridden.
Config.respectSystemReducedMotion = true

--- Falls back to no-op when set false. Useful for CI screenshots and
--- for headless smoke tests.
Config.allowWarnings = true

--- Prints lifecycle events. Never enabled by default.
Config.debug = false

--- When true, every Vantage instance is tagged with `Config.tag` so
--- `CollectionService:GetTagged` can highlight the whole interface.
Config.tagging = true
Config.tag = "Vantage"

--- Component sounds. Ship-safe defaults: Roblox's own UI click is
--- available to every experience without an upload, and anything the
--- developer wants to swap out is a plain property write.
Config.sounds = {
	enabled = true,
	volume = 0.35,
	hover = "",
	click = "rbxasset://sounds/electronicpingshort.wav",
	toggle = "rbxasset://sounds/electronicpingshort.wav",
	open = "rbxasset://sounds/electronicpingshort.wav",
	close = "rbxasset://sounds/electronicpingshort.wav",
	notify = "rbxasset://sounds/electronicpingshort.wav",
	error = "",
}

--- When true, `Window` refuses to open the native Roblox chat/backpack
--- while it is focused. Off by default: never fight the game.
Config.isolateControls = false

--- Global keybinds. Set to nil to disable an entry entirely.
Config.keybinds = {
	toggleInterface = Enum.KeyCode.RightShift,
	commandPalette = Enum.KeyCode.K,
	commandPaletteModifier = Enum.KeyCode.LeftControl,
	closeOverlay = Enum.KeyCode.Escape,
}

--- Serialization hooks for window position/size persistence. Supply
--- your own to store in a DataStore, ProfileService, or anywhere else.
Config.persistence = {
	load = nil :: ((key: string) -> any?)?,
	save = nil :: ((key: string, value: any) -> ())?,
}

--- Hosting defaults applied to every `Window` unless overridden. The
--- window opens at a size that reads as a real application on the
--- reference client, and never wider than the viewport allows.
Config.defaults = {
	theme = "obsidian",
	size = UDim2.fromOffset(880, 560),
	position = UDim2.fromScale(0.5, 0.5),
	anchor = Vector2.new(0.5, 0.5),
	minSize = Vector2.new(620, 420),
	resizable = true,
	draggable = true,
	closeOnEscape = true,
	sidebarWidth = 196,
	titleBarHeight = 48,
	statusBarHeight = 26,
	uiScale = nil :: number?,
}

Config.Changed = Signal.new("Config.Changed")

local internal = {}
for key, value in pairs(Config) do
	internal[key] = value
end

--- Reads a config value.
function Config.get(key: string): any
	return Config[key]
end

--- Writes a config value and notifies observers when it changed.
function Config.set(key: string, value: any)
	local previous = Config[key]
	if previous == value then
		return
	end
	Config[key] = value
	if key == "animations" then
		local Motion = require(script.Parent.Motion)
		Motion.setReducedMotion(not (value == true)
			or (Config.respectSystemReducedMotion and require(script.Parent.Util).prefersReducedMotion()))
	end
	Config.Changed:fire(key, value, previous)
	if Config.debug then
		print(string.format("[Vantage] config.%s = %s", key, tostring(value)))
	end
end

--- Sets several keys at once, firing a single Changed batch.
function Config.merge(patch: { [string]: any })
	for key, value in pairs(patch) do
		Config.set(key, value)
	end
end

--- Calls `callback(key, value)` now and on every subsequent change.
--- Returns an unsubscribe function.
function Config.observe(key: any, callback: (any, any, any) -> ())
	if key ~= nil then
		callback(key, Config[key], nil)
	end
	local connection = Config.Changed:connect(function(changedKey, value, previous)
		if key == nil or changedKey == key then
			callback(changedKey, value, previous)
		end
	end)
	return function()
		connection:disconnect()
	end
end

--- Restores every flag to its factory value.
function Config.reset()
	for key, value in pairs(internal) do
		if type(value) ~= "function" and type(value) ~= "table" then
			Config.set(key, value)
		end
	end
end

return Config
