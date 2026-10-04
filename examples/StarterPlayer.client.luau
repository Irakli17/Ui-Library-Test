--[[
	Vantage · examples/StarterPlayer.client.luau
	==================================================================
	A complete interface in one LocalScript: loading screen, window,
	three tabs, every control, notifications, modal, palette.

	Drop it into StarterPlayerScripts (default.project.json already maps
	it when you use Rojo) and press play.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vantage = require(ReplicatedStorage.Vantage)

--[[ Loading screen ---------------------------------------------------- ]]

local loading = Vantage.LoadingScreen.Run({
	-- Replace with the assets your game actually needs. Progress is real:
	-- it comes from ContentProvider:PreloadAsync, not a timer.
	Assets = {},
	Title = "Vantage",
	Tagline = "Interface, engineered.",
	AutoContinue = 2.4,
	Logo = {
		-- Point this at your own upload; without it the bundled
		-- placeholder mark is used so the corner is never blank.
		Image = Vantage.LoadingScreen.LogoImage,
		Position = "bottom-right",
	},
})

loading.wait()

--[[ Setup ------------------------------------------------------------- ]]

Vantage.Setup({ Theme = "obsidian" })

local settings = {
	reduceMotion = false,
	scale = 1,
	quality = "High",
	nickname = "Player",
	keybind = "LeftShift+T",
	density = "Comfortable",
}

--[[ Window ------------------------------------------------------------ ]]

local window = Vantage.Window.new({
	Name = "Vantage",
	Subtitle = "Settings",
	Size = UDim2.fromOffset(760, 480),
	MinSize = Vector2.new(460, 320),
	Resizable = true,
	Draggable = true,
})

local notify = Vantage.Notify.new({ layer = window.NotifyLayer })
local palette = Vantage.CommandPalette.new({ layer = window.OverlayLayer, maid = window._maid })

--[[ General ----------------------------------------------------------- ]]

local general = window:Tab({ Name = "General", Icon = "sliders" })
local appearance = general:Section({
	Name = "Appearance",
	Description = "How the interface looks and moves.",
	Icon = "palette",
})

appearance:Toggle({
	Name = "Reduce motion",
	Description = "Turns off springs and easing across the whole library.",
	Value = settings.reduceMotion,
	Callback = function(value)
		settings.reduceMotion = value
		Vantage.Config.set("animations", not value)
		notify:push({
			Title = "Motion",
			Body = value and "Animations reduced." or "Animations restored.",
			Tone = "info",
			Duration = 2.4,
		})
	end,
})

appearance:Slider({
	Name = "Interface scale",
	Min = 0.75,
	Max = 1.5,
	Step = 0.05,
	Decimals = 2,
	Suffix = "×",
	Value = settings.scale,
	Callback = function(value)
		settings.scale = value
		window.UIScale.Scale = value
	end,
})

appearance:Segmented({
	Name = "Density",
	Options = { "Comfortable", "Compact" },
	Value = settings.density,
	Callback = function(value)
		settings.density = value
	end,
})

--[[ Gameplay ---------------------------------------------------------- ]]

local gameplay = window:Tab({ Name = "Gameplay", Icon = "gear" })
local quality = gameplay:Section({ Name = "Performance", Icon = "bolt" })

quality:Dropdown({
	Name = "Quality preset",
	Options = { "Low", "Medium", "High", "Ultra" },
	Value = settings.quality,
	Searchable = true,
	Callback = function(value)
		settings.quality = value
	end,
})

quality:Progress({ Name = "Asset streaming", Value = 0.35, Label = "Warming caches" })

local profile = gameplay:Section({ Name = "Profile", Description = "How other players see you." })

profile:Input({
	Name = "Nickname",
	Placeholder = "Enter a name",
	MaxLength = 18,
	Value = settings.nickname,
	Callback = function(value)
		settings.nickname = value
	end,
})

profile:Keybind({
	Name = "Push to talk",
	Value = settings.keybind,
	Callback = function(value)
		settings.keybind = value
	end,
})

--[[ Danger ------------------------------------------------------------ ]]

local advanced = window:Tab({ Name = "Advanced", Icon = "warning" })
local danger = advanced:Section({ Name = "Danger zone", Description = "These cannot be undone." })

danger:ButtonRow():Button({
	Text = "Reset settings",
	Variant = "secondary",
	Callback = function()
		settings.reduceMotion = false
		settings.scale = 1
		notify:push({ Title = "Settings", Body = "Defaults restored.", Tone = "success" })
	end,
})

danger:ButtonRow():Button({
	Text = "Delete profile",
	Variant = "danger",
	-- Ask once more before anything destructive runs.
	Confirm = true,
	ConfirmText = "Click again to delete",
	Callback = function()
		local modal = Vantage.Modal.new({
			Title = "Profile deleted",
			Body = "This was a demonstration; nothing was removed.",
			Tone = "danger",
			Layer = window.OverlayLayer,
			Actions = { { Text = "Close", Variant = "primary", Value = "ok" } },
		}, { maid = window._maid })
		modal:onResult(function()
			notify:push({ Title = "Deleted", Body = "Profile removed.", Tone = "danger", Duration = 3 })
		end)
	end,
})

advanced:Stats({
	{ Label = "Version", Value = Vantage.version },
	{ Label = "Theme", Value = Vantage.Theme.name() },
	{ Label = "Modules", Value = "30" },
})

--[[ Commands ---------------------------------------------------------- ]]

palette:Add({
	{
		Id = "theme-porcelain",
		Label = "Switch to Porcelain",
		Hint = "Theme",
		Run = function()
			window:SetTheme("porcelain")
		end,
	},
	{
		Id = "theme-obsidian",
		Label = "Switch to Obsidian",
		Hint = "Theme",
		Run = function()
			window:SetTheme("obsidian")
		end,
	},
	{
		Id = "close",
		Label = "Close the interface",
		Hint = "Window",
		Run = function()
			window:Hide()
		end,
	},
})

-- Ctrl+K opens the palette; the window's own keybinds handle the rest.
window:SelectTab("General")

print(string.format("[Vantage] %s ready (theme %s)", Vantage.version, window:GetTheme()))
