--!nocheck
--!nolint
--[[
	Lumen UI Library  v0.0.3-stable
	Single file, no dependencies, loadstring-ready. Also works as a ModuleScript (require) in Studio.

	local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Lumen.lua"))()

	Load options can be passed straight into the loadstring call:
	local Lumen = loadstring(game:HttpGet(URL))({ Id = "MyHub", Theme = "Cosmos", Folder = "MyHub" })

	See DOCS.md for the full API and Example.lua for a complete demo.
]]

local LoadArgs = { ... }
local env = (getgenv and getgenv()) or _G

-- Options: first argument of the chunk, or getgenv().LumenOptions (read once, then cleared so the next script starts clean)
local LoadOptions = {}
do
	local src = (type(LoadArgs[1]) == "table" and LoadArgs[1]) or (type(env.LumenOptions) == "table" and env.LumenOptions) or nil
	if src then for k, v in pairs(src) do LoadOptions[k] = v end end
	if src ~= nil and src == env.LumenOptions then env.LumenOptions = nil end
	if env.LumenNoInter then LoadOptions.NoInter = true end
end

-- Every script gets its own instance, keyed by Id. Re-running a script replaces its own previous copy
-- (handy while developing) and leaves other scripts' interfaces alone. Reuse = true returns the running copy instead.
local InstanceId = tostring(LoadOptions.Id or "default")
env.LumenInstances = type(env.LumenInstances) == "table" and env.LumenInstances or {}
do
	local prev = env.LumenInstances[InstanceId]
	if prev == nil and InstanceId == "default" and type(env.LumenUI) == "table" and not env.LumenUI.Id then prev = env.LumenUI end
	if type(prev) == "table" and type(prev.Unload) == "function" and not prev.Unloaded then
		if LoadOptions.Reuse then return prev end
		pcall(function() prev:Unload() end)
	end
end

local cloneref = cloneref or function(o) return o end
local function Service(name) return cloneref(game:GetService(name)) end

local Players = Service("Players")
local UIS = Service("UserInputService")
local TweenService = Service("TweenService")
local RunService = Service("RunService")
local HttpService = Service("HttpService")
local Stats = Service("Stats")
local Lighting = Service("Lighting")
local TextService = Service("TextService")

local Lumen = {
	Version = "v0.0.3-stable",
	Id = InstanceId,
	LoadOptions = LoadOptions,
	NotifyErrors = LoadOptions.NotifyErrors ~= false,   -- a crashing callback shows a red notification
	Hints = LoadOptions.Hints ~= false,                 -- hover explanations
	HintDelay = 0.35,
	NotifyPosition = "TopRight",
	Flags = {},
	Options = {},
	Windows = {},
	Folder = LoadOptions.Folder or "Lumen",
	Unloaded = false,
	ShowWatermark = true,
	ShowHotkeys = true,
	ShowNotifications = true,
	ShowDock = true,
	Scale = LoadOptions.Scale or 1,
	FontName = "Inter",
	ThemeTransition = 0.3,          -- seconds colours blend when the theme changes (0 = instant)
	Preset = "Lavender",
	-- the non-colour half of a theme: shape, glow, font, particles, surface tint
	Style = { Radius = 1, Glow = 1, Font = "Inter", TextScale = 1, Particles = "Snow", ParticleColor = Color3.new(1, 1, 1) },
	-- dragged HUD pieces glide back home after a delay
	SnapBack = { Enabled = true, Delay = 5, Dock = true, Hotkeys = true, Watermark = false },
	-- colours sampled from the reference UI
	Theme = {
		Background = Color3.fromRGB(14, 13, 17),
		Group = Color3.fromRGB(17, 16, 21),
		GroupBorder = Color3.fromRGB(25, 24, 30),
		Control = Color3.fromRGB(24, 23, 28),
		ControlHover = Color3.fromRGB(34, 33, 39),
		Border = Color3.fromRGB(48, 47, 58),
		Outline = Color3.fromRGB(37, 35, 44),
		Text = Color3.fromRGB(208, 207, 219),
		Label = Color3.fromRGB(185, 184, 193),
		TextDim = Color3.fromRGB(134, 133, 141),
		TextMuted = Color3.fromRGB(102, 101, 108),
		Chip = Color3.fromRGB(23, 22, 26),
		ChipText = Color3.fromRGB(153, 152, 160),
		Accent = Color3.fromRGB(159, 150, 193),
		AccentText = Color3.fromRGB(159, 150, 193),
		AccentBorder = Color3.fromRGB(104, 98, 127),
		Toggle = Color3.fromRGB(68, 64, 81),
		TabActive = Color3.fromRGB(43, 40, 52),
		Success = Color3.fromRGB(80, 159, 119),
		Warning = Color3.fromRGB(168, 128, 82),
		Danger = Color3.fromRGB(159, 88, 88),
		Info = Color3.fromRGB(80, 158, 237),
		Caution = Color3.fromRGB(212, 178, 92),
		Error = Color3.fromRGB(209, 98, 104),
	},
	Presets = {
		Lavender = { Accent = Color3.fromRGB(159, 150, 193), Background = Color3.fromRGB(14, 13, 17), Group = Color3.fromRGB(17, 16, 21), GroupBorder = Color3.fromRGB(25, 24, 30), Control = Color3.fromRGB(24, 23, 28), ControlHover = Color3.fromRGB(34, 33, 39), Border = Color3.fromRGB(48, 47, 58), Outline = Color3.fromRGB(38, 36, 45), Text = Color3.fromRGB(210, 209, 220), Label = Color3.fromRGB(187, 186, 195), TextDim = Color3.fromRGB(134, 133, 141), TextMuted = Color3.fromRGB(108, 107, 114),
			Style = { Radius = 1, Glow = 1, Font = "Inter", Particles = "Snow", ParticleColor = Color3.new(1, 1, 1) } },
		Ocean = { Accent = Color3.fromRGB(110, 165, 225), Background = Color3.fromRGB(10, 14, 20), Group = Color3.fromRGB(14, 19, 27), GroupBorder = Color3.fromRGB(22, 30, 41), Control = Color3.fromRGB(20, 27, 38), ControlHover = Color3.fromRGB(29, 39, 54), Border = Color3.fromRGB(40, 54, 72), Outline = Color3.fromRGB(33, 45, 61), Text = Color3.fromRGB(210, 218, 230), Label = Color3.fromRGB(180, 190, 204), TextDim = Color3.fromRGB(122, 138, 158), TextMuted = Color3.fromRGB(96, 110, 128),
			Style = { Radius = 1.35, Glow = 1.35, Font = "Inter", Particles = "Bubbles", ParticleColor = Color3.fromRGB(140, 205, 255), Tint = Color3.fromRGB(40, 120, 200), TintPlace = "Bottom", TintAmount = 0.2, TopLine = { Color3.fromRGB(90, 210, 255), Color3.fromRGB(80, 110, 245) } } },
		Rose = { Accent = Color3.fromRGB(205, 120, 150), Background = Color3.fromRGB(17, 12, 15), Group = Color3.fromRGB(22, 16, 20), GroupBorder = Color3.fromRGB(33, 24, 29), Control = Color3.fromRGB(31, 23, 28), ControlHover = Color3.fromRGB(43, 32, 39), Border = Color3.fromRGB(62, 46, 54), Outline = Color3.fromRGB(50, 37, 44), Text = Color3.fromRGB(228, 214, 220), Label = Color3.fromRGB(200, 184, 191), TextDim = Color3.fromRGB(150, 130, 140), TextMuted = Color3.fromRGB(118, 100, 109),
			Style = { Radius = 1.75, Glow = 1.6, Font = "Inter", Particles = "Petals", ParticleColor = Color3.fromRGB(242, 150, 186), Tint = Color3.fromRGB(215, 95, 150), TintPlace = "Top", TintAmount = 0.16, TopLine = { Color3.fromRGB(245, 140, 185), Color3.fromRGB(255, 190, 150) } } },
		Emerald = { Accent = Color3.fromRGB(100, 190, 145), Background = Color3.fromRGB(10, 15, 13), Group = Color3.fromRGB(14, 20, 18), GroupBorder = Color3.fromRGB(22, 31, 28), Control = Color3.fromRGB(20, 28, 25), ControlHover = Color3.fromRGB(29, 40, 36), Border = Color3.fromRGB(42, 58, 52), Outline = Color3.fromRGB(34, 47, 42), Text = Color3.fromRGB(212, 226, 219), Label = Color3.fromRGB(184, 198, 191), TextDim = Color3.fromRGB(124, 144, 133), TextMuted = Color3.fromRGB(98, 114, 106),
			Style = { Radius = 1.1, Glow = 1.45, Font = "Inter", Particles = "Fireflies", ParticleColor = Color3.fromRGB(180, 255, 150), Tint = Color3.fromRGB(50, 210, 150), TintPlace = "Aurora", TintAmount = 0.2, TopLine = { Color3.fromRGB(90, 230, 160), Color3.fromRGB(60, 190, 220) } } },
		Sunset = { Accent = Color3.fromRGB(215, 150, 90), Background = Color3.fromRGB(17, 13, 11), Group = Color3.fromRGB(23, 18, 15), GroupBorder = Color3.fromRGB(34, 27, 22), Control = Color3.fromRGB(32, 26, 21), ControlHover = Color3.fromRGB(44, 36, 30), Border = Color3.fromRGB(64, 52, 43), Outline = Color3.fromRGB(51, 41, 34), Text = Color3.fromRGB(230, 220, 210), Label = Color3.fromRGB(202, 191, 180), TextDim = Color3.fromRGB(152, 138, 124), TextMuted = Color3.fromRGB(120, 108, 96),
			Style = { Radius = 1, Glow = 1.3, Font = "Inter", Particles = "Embers", ParticleColor = Color3.fromRGB(255, 150, 70), Tint = Color3.fromRGB(235, 110, 60), TintPlace = "Bottom", TintAmount = 0.2, TopLine = { Color3.fromRGB(255, 160, 80), Color3.fromRGB(230, 80, 140) } } },
		Mono = { Accent = Color3.fromRGB(190, 190, 196), Background = Color3.fromRGB(12, 12, 12), Group = Color3.fromRGB(17, 17, 17), GroupBorder = Color3.fromRGB(26, 26, 26), Control = Color3.fromRGB(25, 25, 25), ControlHover = Color3.fromRGB(36, 36, 36), Border = Color3.fromRGB(52, 52, 52), Outline = Color3.fromRGB(41, 41, 41), Text = Color3.fromRGB(222, 222, 222), Label = Color3.fromRGB(194, 194, 194), TextDim = Color3.fromRGB(136, 136, 136), TextMuted = Color3.fromRGB(106, 106, 106),
			Style = { Radius = 0.25, Glow = 0, Font = "Mono", Particles = "Glyphs", ParticleColor = Color3.fromRGB(205, 205, 205), Scanlines = true } },
		-- neon pink and cyan, wide futuristic type, an animated rainbow border and rising light streaks
		Synthwave = { Accent = Color3.fromRGB(255, 92, 205), Background = Color3.fromRGB(16, 10, 26), Group = Color3.fromRGB(22, 14, 36), GroupBorder = Color3.fromRGB(38, 24, 58), Control = Color3.fromRGB(30, 19, 46), ControlHover = Color3.fromRGB(44, 28, 66), Border = Color3.fromRGB(86, 52, 120), Outline = Color3.fromRGB(58, 36, 84), Text = Color3.fromRGB(245, 232, 255), Label = Color3.fromRGB(225, 205, 245), TextDim = Color3.fromRGB(170, 140, 200), TextMuted = Color3.fromRGB(130, 104, 160),
			Style = { Radius = 0.8, Glow = 1.8, Font = "Michroma", TextScale = 0.86, Particles = "Neon", ParticleColor = Color3.fromRGB(0, 229, 255), Tint = Color3.fromRGB(255, 60, 190), TintPlace = "Bottom", TintAmount = 0.22, TopLine = { Color3.fromRGB(0, 229, 255), Color3.fromRGB(255, 92, 205) }, Aura = { Color3.fromRGB(255, 92, 205), Color3.fromRGB(0, 229, 255), Color3.fromRGB(140, 90, 255), Color3.fromRGB(255, 92, 205) }, AuraSpeed = 0.5, AccentGradient = { Color3.fromRGB(255, 92, 205), Color3.fromRGB(0, 229, 255) } } },
		-- pale ice, thin rounded type, a frosted inner border and slowly spinning crystals
		Frost = { Accent = Color3.fromRGB(150, 215, 255), Background = Color3.fromRGB(12, 18, 26), Group = Color3.fromRGB(16, 24, 34), GroupBorder = Color3.fromRGB(26, 38, 52), Control = Color3.fromRGB(22, 32, 44), ControlHover = Color3.fromRGB(32, 46, 62), Border = Color3.fromRGB(60, 86, 112), Outline = Color3.fromRGB(42, 60, 80), Text = Color3.fromRGB(232, 244, 255), Label = Color3.fromRGB(205, 224, 240), TextDim = Color3.fromRGB(140, 166, 190), TextMuted = Color3.fromRGB(105, 128, 150),
			Style = { Radius = 1.25, Glow = 1.2, Font = "Jura", TextScale = 1.08, Particles = "Crystals", ParticleColor = Color3.fromRGB(215, 240, 255), Tint = Color3.fromRGB(120, 190, 255), TintPlace = "Top", TintAmount = 0.14, TopLine = { Color3.fromRGB(230, 248, 255), Color3.fromRGB(120, 190, 255) }, InnerLine = Color3.fromRGB(170, 215, 255), AccentGradient = { Color3.fromRGB(235, 248, 255), Color3.fromRGB(120, 190, 255) } } },
		-- midnight navy and gold, serif type, a gilded double border and glinting sparkles
		Royal = { Accent = Color3.fromRGB(222, 184, 92), Background = Color3.fromRGB(11, 13, 24), Group = Color3.fromRGB(15, 18, 32), GroupBorder = Color3.fromRGB(26, 28, 46), Control = Color3.fromRGB(20, 24, 40), ControlHover = Color3.fromRGB(30, 34, 56), Border = Color3.fromRGB(92, 78, 44), Outline = Color3.fromRGB(48, 46, 60), Text = Color3.fromRGB(244, 236, 214), Label = Color3.fromRGB(222, 212, 186), TextDim = Color3.fromRGB(160, 150, 126), TextMuted = Color3.fromRGB(120, 112, 94),
			Style = { Radius = 0.6, Glow = 1.1, Font = "Merriweather", TextScale = 0.94, Particles = "Sparkles", ParticleColor = Color3.fromRGB(255, 214, 120), Tint = Color3.fromRGB(200, 160, 70), TintPlace = "Top", TintAmount = 0.1, TopLine = { Color3.fromRGB(255, 214, 120), Color3.fromRGB(180, 130, 50) }, InnerLine = Color3.fromRGB(222, 184, 92), AccentGradient = { Color3.fromRGB(255, 226, 150), Color3.fromRGB(196, 148, 58) } } },
		-- bubblegum pastels, a soft rounded display font, extra-round shapes and tumbling confetti
		Candy = { Accent = Color3.fromRGB(255, 128, 190), Background = Color3.fromRGB(24, 16, 26), Group = Color3.fromRGB(32, 21, 35), GroupBorder = Color3.fromRGB(48, 32, 52), Control = Color3.fromRGB(42, 28, 46), ControlHover = Color3.fromRGB(58, 38, 62), Border = Color3.fromRGB(98, 66, 104), Outline = Color3.fromRGB(70, 46, 76), Text = Color3.fromRGB(255, 240, 250), Label = Color3.fromRGB(250, 220, 240), TextDim = Color3.fromRGB(200, 160, 190), TextMuted = Color3.fromRGB(160, 122, 150),
			Style = { Radius = 2.2, Glow = 1.7, Font = "FredokaOne", TextScale = 1, Particles = "Confetti", ParticleColor = Color3.fromRGB(255, 128, 190), Tint = Color3.fromRGB(130, 255, 210), TintPlace = "Bottom", TintAmount = 0.14, TopLine = { Color3.fromRGB(255, 128, 190), Color3.fromRGB(130, 255, 210) }, Aura = { Color3.fromRGB(255, 128, 190), Color3.fromRGB(130, 255, 210), Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 128, 190) }, AuraSpeed = 0.25, AccentGradient = { Color3.fromRGB(255, 128, 190), Color3.fromRGB(255, 190, 120) } } },
		-- 8-bit: pixel font, square corners, a thick yellow border, CRT scanlines and stepping pixels
		Arcade = { Accent = Color3.fromRGB(255, 214, 0), Background = Color3.fromRGB(8, 8, 14), Group = Color3.fromRGB(12, 12, 22), GroupBorder = Color3.fromRGB(30, 30, 58), Control = Color3.fromRGB(18, 18, 32), ControlHover = Color3.fromRGB(28, 28, 50), Border = Color3.fromRGB(70, 70, 140), Outline = Color3.fromRGB(44, 44, 90), Text = Color3.fromRGB(240, 240, 255), Label = Color3.fromRGB(210, 210, 240), TextDim = Color3.fromRGB(140, 140, 190), TextMuted = Color3.fromRGB(100, 100, 150),
			Style = { Radius = 0, Glow = 0.6, Font = "Arcade", TextScale = 0.72, Particles = "Pixels", ParticleColor = Color3.fromRGB(90, 255, 170), Scanlines = true, Aura = { Color3.fromRGB(255, 214, 0), Color3.fromRGB(255, 214, 0) }, AuraSpeed = 0, AuraThickness = 2 } },
		-- deep space: violet nebula band, a slowly turning aurora border, stars and shooting stars
		Cosmos = { Accent = Color3.fromRGB(150, 120, 255), Background = Color3.fromRGB(8, 8, 18), Group = Color3.fromRGB(12, 12, 26), GroupBorder = Color3.fromRGB(24, 22, 46), Control = Color3.fromRGB(18, 17, 36), ControlHover = Color3.fromRGB(28, 26, 54), Border = Color3.fromRGB(64, 56, 120), Outline = Color3.fromRGB(40, 36, 78), Text = Color3.fromRGB(236, 234, 255), Label = Color3.fromRGB(210, 206, 245), TextDim = Color3.fromRGB(150, 144, 200), TextMuted = Color3.fromRGB(110, 104, 160),
			Style = { Radius = 1.15, Glow = 1.5, Font = "TitilliumWeb", TextScale = 1.05, Particles = "Starfield", ParticleColor = Color3.fromRGB(230, 230, 255), Tint = Color3.fromRGB(110, 70, 255), TintPlace = "Aurora", TintAmount = 0.18, TopLine = { Color3.fromRGB(150, 120, 255), Color3.fromRGB(80, 200, 255) }, Aura = { Color3.fromRGB(150, 120, 255), Color3.fromRGB(80, 200, 255), Color3.fromRGB(255, 120, 220), Color3.fromRGB(150, 120, 255) }, AuraSpeed = 0.15, AccentGradient = { Color3.fromRGB(170, 130, 255), Color3.fromRGB(80, 200, 255) } } },
		-- slate and steel, condensed type, slanted rain and distant lightning
		Storm = { Accent = Color3.fromRGB(120, 180, 255), Background = Color3.fromRGB(13, 15, 19), Group = Color3.fromRGB(18, 21, 26), GroupBorder = Color3.fromRGB(28, 32, 40), Control = Color3.fromRGB(24, 28, 35), ControlHover = Color3.fromRGB(34, 39, 48), Border = Color3.fromRGB(62, 72, 88), Outline = Color3.fromRGB(42, 48, 60), Text = Color3.fromRGB(226, 232, 242), Label = Color3.fromRGB(200, 208, 222), TextDim = Color3.fromRGB(140, 150, 168), TextMuted = Color3.fromRGB(104, 112, 128),
			Style = { Radius = 0.9, Glow = 1.25, Font = "Oswald", TextScale = 1.05, Particles = "Rain", ParticleColor = Color3.fromRGB(170, 200, 240), Tint = Color3.fromRGB(90, 120, 170), TintPlace = "Top", TintAmount = 0.16, TopLine = { Color3.fromRGB(200, 225, 255), Color3.fromRGB(120, 180, 255) }, Lightning = true } },
		-- drafting paper: navy blue, a white grid, a ruled double border, handwritten labels and drafting marks
		Blueprint = { Accent = Color3.fromRGB(225, 238, 255), Background = Color3.fromRGB(18, 48, 92), Group = Color3.fromRGB(22, 56, 104), GroupBorder = Color3.fromRGB(52, 90, 140), Control = Color3.fromRGB(28, 64, 116), ControlHover = Color3.fromRGB(40, 80, 136), Border = Color3.fromRGB(120, 160, 210), Outline = Color3.fromRGB(70, 110, 165), Text = Color3.fromRGB(240, 246, 255), Label = Color3.fromRGB(214, 228, 248), TextDim = Color3.fromRGB(150, 180, 220), TextMuted = Color3.fromRGB(115, 145, 190),
			Style = { Radius = 0.3, Glow = 0.35, Font = "PatrickHand", TextScale = 1.15, Particles = "Drafting", ParticleColor = Color3.fromRGB(210, 230, 255), Grid = true, GridColor = Color3.fromRGB(220, 235, 255), InnerLine = Color3.fromRGB(200, 225, 255) } },
		-- film noir: black, white and one red, typewriter type, a dark vignette and flickering film grain
		Noir = { Accent = Color3.fromRGB(214, 40, 52), Background = Color3.fromRGB(11, 11, 11), Group = Color3.fromRGB(17, 17, 17), GroupBorder = Color3.fromRGB(30, 30, 30), Control = Color3.fromRGB(24, 24, 24), ControlHover = Color3.fromRGB(36, 36, 36), Border = Color3.fromRGB(70, 70, 70), Outline = Color3.fromRGB(44, 44, 44), Text = Color3.fromRGB(236, 236, 236), Label = Color3.fromRGB(205, 205, 205), TextDim = Color3.fromRGB(140, 140, 140), TextMuted = Color3.fromRGB(105, 105, 105),
			Style = { Radius = 0.3, Glow = 0.9, Font = "SpecialElite", TextScale = 1.02, Particles = "FilmGrain", ParticleColor = Color3.fromRGB(230, 230, 230), Vignette = true, TopLine = { Color3.fromRGB(214, 40, 52), Color3.fromRGB(120, 20, 28) } } },
		-- prism: a rainbow border that turns, accents that cycle through the spectrum, rising glass shards
		Prism = { Accent = Color3.fromRGB(180, 160, 255), Background = Color3.fromRGB(12, 12, 18), Group = Color3.fromRGB(17, 17, 26), GroupBorder = Color3.fromRGB(30, 30, 44), Control = Color3.fromRGB(24, 24, 36), ControlHover = Color3.fromRGB(34, 34, 50), Border = Color3.fromRGB(70, 70, 100), Outline = Color3.fromRGB(44, 44, 64), Text = Color3.fromRGB(240, 240, 255), Label = Color3.fromRGB(215, 215, 235), TextDim = Color3.fromRGB(150, 150, 180), TextMuted = Color3.fromRGB(110, 110, 140),
			Style = { Radius = 1.25, Glow = 1.6, Font = "Ubuntu", TextScale = 1, Particles = "Prisms", AccentCycle = true, Tint = Color3.fromRGB(120, 80, 255), TintPlace = "Aurora", TintAmount = 0.12,
				TopLine = { Color3.fromRGB(255, 120, 200), Color3.fromRGB(120, 200, 255) }, AuraSpeed = 0.2, AuraThickness = 1.6,
				Aura = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 190, 70), Color3.fromRGB(240, 255, 90), Color3.fromRGB(90, 255, 150), Color3.fromRGB(80, 210, 255), Color3.fromRGB(120, 110, 255), Color3.fromRGB(240, 100, 255), Color3.fromRGB(255, 90, 90) } } },
		-- hazard: industrial yellow and black, a striped warning-tape border, square corners and welding sparks
		Hazard = { Accent = Color3.fromRGB(255, 200, 0), Background = Color3.fromRGB(16, 15, 10), Group = Color3.fromRGB(22, 21, 14), GroupBorder = Color3.fromRGB(40, 38, 24), Control = Color3.fromRGB(30, 28, 18), ControlHover = Color3.fromRGB(42, 40, 26), Border = Color3.fromRGB(90, 84, 40), Outline = Color3.fromRGB(56, 52, 30), Text = Color3.fromRGB(250, 246, 230), Label = Color3.fromRGB(228, 222, 200), TextDim = Color3.fromRGB(165, 158, 130), TextMuted = Color3.fromRGB(125, 118, 95),
			Style = { Radius = 0.2, Glow = 0.9, Font = "Sarpanch", TextScale = 1.05, Particles = "Sparks", ParticleColor = Color3.fromRGB(255, 210, 90), Tint = Color3.fromRGB(255, 140, 0), TintPlace = "Bottom", TintAmount = 0.12,
				Aura = { Color3.fromRGB(255, 200, 0), Color3.fromRGB(24, 22, 14), Color3.fromRGB(255, 200, 0), Color3.fromRGB(24, 22, 14), Color3.fromRGB(255, 200, 0), Color3.fromRGB(24, 22, 14), Color3.fromRGB(255, 200, 0), Color3.fromRGB(24, 22, 14), Color3.fromRGB(255, 200, 0), Color3.fromRGB(24, 22, 14) },
				AuraHard = true, AuraSpeed = 0, AuraRotation = 45, AuraThickness = 3 } },
		-- glass: see-through frosted surfaces over a blurred world, soft rounded type and drifting bokeh
		Glass = { Accent = Color3.fromRGB(170, 215, 255), Background = Color3.fromRGB(22, 26, 36), Group = Color3.fromRGB(30, 36, 50), GroupBorder = Color3.fromRGB(60, 70, 92), Control = Color3.fromRGB(38, 45, 62), ControlHover = Color3.fromRGB(52, 60, 80), Border = Color3.fromRGB(110, 125, 155), Outline = Color3.fromRGB(70, 82, 108), Text = Color3.fromRGB(245, 248, 255), Label = Color3.fromRGB(220, 228, 242), TextDim = Color3.fromRGB(160, 172, 195), TextMuted = Color3.fromRGB(122, 134, 158),
			Style = { Radius = 1.6, Glow = 1, Font = "Nunito", TextScale = 1.04, Particles = "Bokeh", ParticleColor = Color3.fromRGB(180, 210, 255), SurfaceTransparency = 0.35, Blur = 18, InnerLine = Color3.fromRGB(255, 255, 255),
				TopLine = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 215, 255) }, AccentGradient = { Color3.fromRGB(220, 240, 255), Color3.fromRGB(140, 190, 255) } } },
		-- haunted: pumpkin orange on midnight purple, dripping type, ghostly green fog below, bats overhead
		Haunted = { Accent = Color3.fromRGB(255, 140, 40), Background = Color3.fromRGB(14, 10, 20), Group = Color3.fromRGB(20, 14, 28), GroupBorder = Color3.fromRGB(36, 26, 48), Control = Color3.fromRGB(28, 20, 38), ControlHover = Color3.fromRGB(40, 30, 54), Border = Color3.fromRGB(86, 60, 110), Outline = Color3.fromRGB(54, 38, 70), Text = Color3.fromRGB(245, 236, 225), Label = Color3.fromRGB(225, 212, 200), TextDim = Color3.fromRGB(165, 145, 150), TextMuted = Color3.fromRGB(125, 105, 120),
			Style = { Radius = 1.1, Glow = 1.5, Font = "Creepster", TextScale = 1.05, Particles = "Bats", ParticleColor = Color3.fromRGB(130, 90, 170), Tint = Color3.fromRGB(110, 220, 140), TintPlace = "Bottom", TintAmount = 0.13, Vignette = true,
				TopLine = { Color3.fromRGB(255, 140, 40), Color3.fromRGB(150, 70, 220) }, AccentGradient = { Color3.fromRGB(255, 170, 60), Color3.fromRGB(170, 90, 255) } } },
		-- parchment (a light theme): aged paper, ink-brown text, a wax-seal red accent, a calligraphic hand and falling leaves
		Parchment = { Accent = Color3.fromRGB(156, 52, 40), Background = Color3.fromRGB(236, 224, 198), Group = Color3.fromRGB(243, 234, 212), GroupBorder = Color3.fromRGB(214, 196, 160), Control = Color3.fromRGB(229, 215, 186), ControlHover = Color3.fromRGB(221, 205, 172), Border = Color3.fromRGB(168, 140, 100), Outline = Color3.fromRGB(200, 178, 140), Text = Color3.fromRGB(52, 36, 24), Label = Color3.fromRGB(70, 50, 34), TextDim = Color3.fromRGB(120, 96, 72), TextMuted = Color3.fromRGB(148, 124, 98),
			Style = { Radius = 0.55, Glow = 0.25, Font = "Fondamento", TextScale = 1.06, Particles = "Leaves", ParticleColor = Color3.fromRGB(200, 110, 50), InnerLine = Color3.fromRGB(120, 84, 54), Vignette = true,
				Tint = Color3.fromRGB(150, 100, 50), TintPlace = "Top", TintAmount = 0.06 } },
	},
}
env.LumenInstances[InstanceId] = Lumen
env.LumenUI = Lumen

local Connections, Themed, Refreshers, Keybinds, FontObjs, Gradients = {}, {}, {}, {}, {}, {}

------------------------------------------------------------------------------
-- Signals + events (connect from your own code: Lumen.Events.ThemeChanged:Connect(fn))
------------------------------------------------------------------------------

local function NewSignal()
	local S = { _h = {} }
	function S:Connect(fn)
		local h = { Fn = fn, Connected = true }
		function h:Disconnect() self.Connected = false end
		table.insert(self._h, h)
		return h
	end
	function S:Once(fn)
		local h
		h = self:Connect(function(...) h:Disconnect() fn(...) end)
		return h
	end
	function S:Fire(...)
		for i = #self._h, 1, -1 do
			if not self._h[i].Connected then table.remove(self._h, i) end
		end
		for _, h in ipairs(self._h) do
			if h.Connected then
				local fn, args = h.Fn, table.pack(...)
				task.spawn(function()
					local ok, err = pcall(fn, table.unpack(args, 1, args.n))
					if not ok then warn("[Lumen] event handler error: " .. tostring(err)) end
				end)
			end
		end
	end
	function S:Wait()
		local co = coroutine.running()
		self:Once(function(...) task.spawn(co, ...) end)
		return coroutine.yield()
	end
	return S
end
Lumen.Signal = NewSignal
Lumen.Events = {
	ThemeChanged = NewSignal(),       -- (themeTable)
	StyleChanged = NewSignal(),       -- (styleTable)
	FlagChanged = NewSignal(),        -- (flag, value)
	VisibilityChanged = NewSignal(),  -- (visible, window)
	TabChanged = NewSignal(),         -- (tabName, window)
	Notified = NewSignal(),           -- (options)
	Unloading = NewSignal(),          -- ()
}

-- Runs a user callback in its own thread. Errors are caught, printed with a traceback and (optionally) shown as a notification,
-- so one broken feature never takes the whole script down.
local function FirstLine(s) return (tostring(s):match("^[^\n]*") or tostring(s)):sub(1, 140) end
local function SafeCall(label, fn, ...)
	if type(fn) ~= "function" then return end
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = xpcall(function() return fn(table.unpack(args, 1, args.n)) end, function(e)
			return (debug and debug.traceback) and debug.traceback(tostring(e), 2) or tostring(e)
		end)
		if not ok then
			warn("[Lumen] error in " .. tostring(label) .. ": " .. tostring(err))
			if Lumen.NotifyErrors and not Lumen.Unloaded and Lumen.Notify then
				pcall(function()
					Lumen:Notify({ Title = "Script error", Content = tostring(label) .. ": " .. FirstLine(err), Type = "Error", Duration = 7 })
				end)
			end
		end
	end)
end
Lumen.SafeCall = SafeCall
local Gui, Overlay, OpenPopup
local ZCounter = 10
local Elements = {}

------------------------------------------------------------------------------
-- Fonts (Inter is downloaded once and cached; falls back to Gotham)
------------------------------------------------------------------------------

local GothamByWeight = {
	Regular = Enum.Font.Gotham, Medium = Enum.Font.GothamMedium,
	SemiBold = Enum.Font.GothamSemibold, Bold = Enum.Font.GothamBold,
}
local WeightEnum = {
	Regular = Enum.FontWeight.Regular, Medium = Enum.FontWeight.Medium,
	SemiBold = Enum.FontWeight.SemiBold, Bold = Enum.FontWeight.Bold,
}
local EnumToWeight = {}
for w, e in pairs(GothamByWeight) do EnumToWeight[e] = w end

-- Any Roblox font works: "Inter" (downloaded), "Gotham", "Mono", or an Enum.Font name like "Michroma", "FredokaOne", "Arcade".
local FamilyCache = {}
local function FamilyFor(name)
	if name == "Inter" then return Lumen._interAsset end
	if name == nil or name == "Gotham" then return nil end
	if name == "Mono" then name = "RobotoMono" end
	if FamilyCache[name] ~= nil then return FamilyCache[name] or nil end
	local fam = false
	pcall(function() fam = Font.fromEnum(Enum.Font[name]).Family end)
	FamilyCache[name] = fam
	return fam or nil
end

local function ApplyFont(obj, weight)
	local base = obj:GetAttribute("TS")
	if base then obj.TextSize = math.max(6, math.floor(base * (Lumen._textScale or 1) + 0.5)) end
	local fam = Lumen._fontFamily
	if fam then
		local ok = pcall(function() obj.FontFace = Font.new(fam, WeightEnum[weight]) end)
		if ok then return end
	end
	obj.Font = GothamByWeight[weight]
end

local FontToken = 0
-- fade (seconds, optional): text dips, the font swaps at the bottom of the dip, text rises again
function Lumen:SetFont(name, fade)
	self.FontName = name
	self._fontFamily = FamilyFor(name)
	if self._fontDropdown then pcall(function() self._fontDropdown:Set(name, true) end) end
	local function Swap()
		for i = #FontObjs, 1, -1 do
			local e = FontObjs[i]
			if e[1].Parent == nil then table.remove(FontObjs, i) else ApplyFont(e[1], e[2]) end
		end
	end
	FontToken = FontToken + 1
	local mine = FontToken
	fade = fade or 0
	if fade <= 0 or #FontObjs > 6000 then Swap() return end
	local half = fade / 2
	local dip = TweenInfo.new(half, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	local rise = TweenInfo.new(half, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local items = {}
	for _, e in ipairs(FontObjs) do
		local o = e[1]
		if o.Parent and o:IsDescendantOf(Gui) then
			local t0 = o:GetAttribute("TT0")
			if t0 == nil then t0 = o.TextTransparency o:SetAttribute("TT0", t0) end
			table.insert(items, { o, t0 })
			TweenService:Create(o, dip, { TextTransparency = math.min(1, t0 + 0.9) }):Play()
		end
	end
	task.delay(half, function()
		if mine ~= FontToken or Lumen.Unloaded then return end
		Swap()
		for _, it in ipairs(items) do
			if it[1].Parent then TweenService:Create(it[1], rise, { TextTransparency = it[2] }):Play() end
		end
	end)
end

local INTER_URL = "https://raw.githubusercontent.com/rsms/inter/v3.19/docs/font-files/Inter-"
function Lumen:_LoadInter()
	if not (writefile and readfile and isfile and isfolder and makefolder and getcustomasset) then return false end
	local ok = pcall(function()
		if not isfolder(self.Folder) then makefolder(self.Folder) end
		local dir = self.Folder .. "/fonts"
		if not isfolder(dir) then makefolder(dir) end
		local faces = {}
		for name, weight in pairs({ Regular = 400, Medium = 500, SemiBold = 600, Bold = 700 }) do
			local path = dir .. "/Inter-" .. name .. ".otf"
			if not isfile(path) then
				local data = game:HttpGet(INTER_URL .. name .. ".otf")
				assert(data and #data > 10000, "download failed")
				writefile(path, data)
			end
			table.insert(faces, { name = name, weight = weight, style = "normal", assetId = getcustomasset(path) })
		end
		writefile(dir .. "/Inter.json", HttpService:JSONEncode({ name = "Inter", faces = faces }))
		self._interAsset = getcustomasset(dir .. "/Inter.json")
	end)
	return ok and self._interAsset ~= nil
end

------------------------------------------------------------------------------
-- Core helpers
------------------------------------------------------------------------------

local function Connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(Connections, c)
	return c
end

local function Tween(obj, time, props)
	local tw = TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }

local function New(class, props, children)
	local obj = Instance.new(class)
	local isText = TEXT_CLASSES[class]
	if isText then
		obj.Font = Enum.Font.GothamSemibold
		obj.TextSize = 12
		obj.TextColor3 = Lumen.Theme.Label
		if class ~= "TextBox" then obj.BackgroundTransparency = 1 end
		if class == "TextButton" then
			obj.AutoButtonColor = false
			obj.Text = ""
		end
	end
	if obj:IsA("GuiObject") then obj.BorderSizePixel = 0 end
	local parent, theme
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		elseif k == "Theme" then
			theme = v
		else
			obj[k] = v
		end
	end
	if theme then
		for prop, key in pairs(theme) do
			obj[prop] = Lumen.Theme[key]
			table.insert(Themed, { obj, prop, key })
		end
	end
	if isText then
		if not (theme and theme.TextColor3) then
			local c = obj.TextColor3
			for _, key in ipairs({ "Label", "Text", "TextDim", "TextMuted" }) do
				if c == Lumen.Theme[key] then
					table.insert(Themed, { obj, "TextColor3", key })
					break
				end
			end
		end
		local w = EnumToWeight[obj.Font] or "SemiBold"
		table.insert(FontObjs, { obj, w })
		obj:SetAttribute("TS", obj.TextSize)
		if Lumen._fontFamily or (Lumen._textScale or 1) ~= 1 then ApplyFont(obj, w) end
	end
	for _, c in ipairs(children or {}) do c.Parent = obj end
	if parent then obj.Parent = parent end
	return obj
end

local function Corner(r)
	r = r or 4
	local c = New("UICorner", { CornerRadius = UDim.new(0, math.floor(r * Lumen.Style.Radius + 0.5)) })
	c:SetAttribute("R", r)
	return c
end
local function CornerFixed(r) return New("UICorner", { CornerRadius = UDim.new(0, r or 4) }) end

local function UpdateGradient(g)
	local T = Lumen.Theme
	g.Color = ColorSequence.new(T.Border:Lerp(Color3.new(1, 1, 1), 0.1), T.Border:Lerp(T.Background, 0.45))
end

-- grad = true gives the soft top-lit border used on windows and HUD panels
local function Stroke(key, grad)
	if grad then
		local st = New("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.new(1, 1, 1) })
		local g = New("UIGradient", { Rotation = 90, Parent = st })
		table.insert(Gradients, g)
		UpdateGradient(g)
		return st
	end
	return New("UIStroke", {
		Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Theme = { Color = key or "Outline" },
	})
end

local function Pad(l, t, r, b)
	if t == nil then t, r, b = l, l, l end
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b),
	})
end

local function List(pad, dir, ha, va)
	return New("UIListLayout", {
		Padding = UDim.new(0, pad or 6),
		FillDirection = dir or Enum.FillDirection.Vertical,
		HorizontalAlignment = ha or Enum.HorizontalAlignment.Left,
		VerticalAlignment = va or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

-- soft glow from four concentric rings (no image assets). `color` is a theme key or a Color3.
-- Measured from the reference: ring alphas 19% / 15% / 10% / 6%.
local GLOW_ALPHA = { 0.19, 0.15, 0.10, 0.06 }
local Glows = {}
local function Glow(host, color, radius, fixed)
	local G = { rings = {}, mult = 1 }
	table.insert(Glows, G)
	for i = 1, #GLOW_ALPHA do
		local props = { Thickness = 1, Transparency = 1 - GLOW_ALPHA[i], ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
		if type(color) == "string" then props.Theme = { Color = color } else props.Color = color end
		local st = New("UIStroke", props)
		New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, i * 2, 1, i * 2),
			BackgroundTransparency = 1, Parent = host,
		}, { (fixed and CornerFixed or Corner)((radius or 5) + i), st })
		G.rings[i] = st
	end
	function G:Set(mult, info)
		self.mult = mult
		local k = Lumen.Style.Glow or 1
		for i, st in ipairs(self.rings) do
			local tr = 1 - math.min(1, GLOW_ALPHA[i] * mult * k)
			if info then TweenService:Create(st, info, { Transparency = tr }):Play() else st.Transparency = tr end
		end
	end
	G:Set(1)
	function G:SetColor(c)
		for _, st in ipairs(self.rings) do st.Color = c end
	end
	return G
end

-- While a theme morphs, StyleBlend holds the old style, the new one and how far along it is (A = 0..1).
local StyleBlend = nil

-- Accent overlays: a white frame with a gradient laid over anything that shows the accent colour, so themes with
-- AccentGradient = {c1, c2} paint toggles, slider fills and progress bars with that gradient (and blend it smoothly).
local AccentFills = {}
local function AccentEnds()
	local acc = Lumen.Theme.Accent
	local to = Lumen.Style
	local from = StyleBlend and StyleBlend.From or to
	local a = StyleBlend and StyleBlend.A or 1
	local function ends(st)
		if st.AccentCycle then
			local h = (os.clock() * 0.07) % 1
			return Color3.fromHSV(h, 0.5, 1), Color3.fromHSV((h + 0.3) % 1, 0.5, 1)
		end
		local g = st.AccentGradient
		if g then return g[1], g[2] or g[1] end
		return acc, acc
	end
	local f1, f2 = ends(from)
	local t1, t2 = ends(to)
	return f1:Lerp(t1, a), f2:Lerp(t2, a)
end
local function PaintAccent(e)
	local c1, c2 = AccentEnds()
	e.Grad.Color = ColorSequence.new(c1, c2)
end
local function AccentOverlay(host, radius, fixedCorner, visible)
	local ov = New("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = visible == false and 1 or 0,
		ZIndex = host.ZIndex, Parent = host,
	}, { (fixedCorner and CornerFixed or Corner)(radius or 4) })
	local e = { Frame = ov, Grad = New("UIGradient", { Parent = ov }) }
	table.insert(AccentFills, e)
	PaintAccent(e)
	return ov
end
table.insert(Refreshers, function()
	for i = #AccentFills, 1, -1 do
		if AccentFills[i].Frame.Parent then PaintAccent(AccentFills[i]) else table.remove(AccentFills, i) end
	end
end)

-- Surfaces: windows, panels and the dock take the theme's tint gradient, top light, scanlines, aura border and inner line.
local Surfaces = {}

local function TintSeq(base, tint, amt, place)
	if not tint or amt <= 0.001 then return ColorSequence.new(base) end
	local tc = base:Lerp(tint, amt)
	if place == "Bottom" then
		return ColorSequence.new({ ColorSequenceKeypoint.new(0, base), ColorSequenceKeypoint.new(0.5, base), ColorSequenceKeypoint.new(1, tc) })
	elseif place == "Aurora" then
		return ColorSequence.new({ ColorSequenceKeypoint.new(0, base:Lerp(tint, amt * 0.5)), ColorSequenceKeypoint.new(0.1, tc),
			ColorSequenceKeypoint.new(0.32, base), ColorSequenceKeypoint.new(1, base) })
	end
	return ColorSequence.new({ ColorSequenceKeypoint.new(0, tc), ColorSequenceKeypoint.new(0.45, base), ColorSequenceKeypoint.new(1, base) })
end

local SurfaceSet = {}

-- hard-edged stripes (hazard tape) instead of a smooth blend
local function HardSeq(list)
	local kps, n = {}, #list
	for i, c in ipairs(list) do
		local a0, b0 = (i - 1) / n, i / n
		table.insert(kps, ColorSequenceKeypoint.new(a0 == 0 and 0 or a0 + 0.0005, c))
		table.insert(kps, ColorSequenceKeypoint.new(b0 == 1 and 1 or b0 - 0.0005, c))
	end
	return ColorSequence.new(kps)
end

local function MultiSeq(list)
	if #list == 1 then return ColorSequence.new(list[1]) end
	local kps = {}
	for i, c in ipairs(list) do table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#list - 1), c)) end
	return ColorSequence.new(kps)
end

local function StyleSurface(e)
	if not e.Frame.Parent then return end
	local base = Lumen.Theme.Background
	local to = Lumen.Style
	local from = StyleBlend and StyleBlend.From or to
	local a = StyleBlend and StyleBlend.A or 1
	local k = (e.Kind == "Window" and 1 or 0.75)
	local function presence(key) return (from[key] and 1 or 0) * (1 - a) + (to[key] and 1 or 0) * a end

	-- tint: blend colour/amount when both themes tint the same side, otherwise fade one out and the other in
	local ft, tt = from.Tint, to.Tint
	local fa, ta = (from.TintAmount or 0.15) * k, (to.TintAmount or 0.15) * k
	local fp, tp = from.TintPlace or "Top", to.TintPlace or "Top"
	local seq
	if not ft and not tt then
		seq = ColorSequence.new(base)
	elseif ft and tt and fp == tp then
		seq = TintSeq(base, ft:Lerp(tt, a), fa + (ta - fa) * a, tp)
	elseif ft and tt then
		if a < 0.5 then seq = TintSeq(base, ft, fa * (1 - a * 2), fp) else seq = TintSeq(base, tt, ta * (a * 2 - 1), tp) end
	elseif tt then
		seq = TintSeq(base, tt, ta * a, tp)
	else
		seq = TintSeq(base, ft, fa * (1 - a), fp)
	end
	e.Frame.BackgroundColor3 = Color3.new(1, 1, 1)
	e.Gradient.Color = seq

	-- light along the window's top edge
	if e.Line then
		local p = presence("TopLine")
		local fl, tl = from.TopLine, to.TopLine
		e.Line.Visible = p > 0.01
		e.Leak.Visible = p > 0.01
		if fl or tl then
			local c1, c2
			if fl and tl then
				c1 = fl[1]:Lerp(tl[1], a)
				c2 = (fl[2] or fl[1]):Lerp(tl[2] or tl[1], a)
			else
				local l = tl or fl
				c1, c2 = l[1], l[2] or l[1]
			end
			local cs = ColorSequence.new(c1, c2)
			e.LineGrad.Color = cs
			e.LeakGrad.Color = cs
		end
		e.Line.BackgroundTransparency = 1 - p
		e.Leak.BackgroundTransparency = 1 - p
	end

	-- scanlines (windows)
	if e.Kind == "Window" then
		local p = presence("Scanlines")
		if p > 0.01 and not e.Scan then
			e.Scan = New("Frame", {
				BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 0, Parent = e.Frame,
			})
			e.ScanLines = {}
			for y = 0, 1200, 3 do
				table.insert(e.ScanLines, New("Frame", {
					Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1, ZIndex = 0, Parent = e.Scan,
				}))
			end
			e.ScanP = -1
		end
		if e.Scan then
			e.Scan.Visible = p > 0.01
			if math.abs((e.ScanP or -1) - p) > 0.004 then
				e.ScanP = p
				for _, ln in ipairs(e.ScanLines) do ln.BackgroundTransparency = 1 - 0.028 * p end
			end
		end
	end

	-- surface see-through (glass themes)
	local fs, ts = from.SurfaceTransparency or 0, to.SurfaceTransparency or 0
	e.Frame.BackgroundTransparency = fs + (ts - fs) * a

	-- aura: the surface's own border takes an animated gradient (no extra frames, so layouts and auto-sizing are untouched)
	local ap = presence("Aura")
	if e.Stroke and e.StrokeGrad then
		local list = to.Aura or from.Aura
		if ap > 0.01 and list then
			local edge = Lumen.Theme.Border:Lerp(Color3.new(1, 1, 1), 0.1)
			local cols = {}
			for i, c in ipairs(list) do cols[i] = edge:Lerp(c, ap) end
			e.StrokeGrad.Color = ((to.Aura and to.AuraHard) or (not to.Aura and from.AuraHard)) and HardSeq(cols) or MultiSeq(cols)
			local th = (to.Aura and to.AuraThickness) or (from.Aura and from.AuraThickness) or 1.5
			e.Stroke.Thickness = 1 + (th - 1) * ap
			e.AuraSpeed = (to.Aura and (to.AuraSpeed or 0.3)) or (from.AuraSpeed or 0.3)
			if e.AuraSpeed <= 0 then
				e.StrokeGrad.Rotation = (to.Aura and to.AuraRotation) or (from.Aura and from.AuraRotation) or 90
			end
			e.AuraOn = true
		elseif e.AuraOn then
			e.AuraOn = false
			e.Stroke.Thickness = 1
			e.StrokeGrad.Rotation = 90
			UpdateGradient(e.StrokeGrad)
		end
	end

	-- the rest only goes on windows (they have no layout, so overlays can't push content around)
	if e.Kind ~= "Window" then return end

	-- inner line: a thin second border inset from the edge
	local ip = presence("InnerLine")
	if ip > 0.01 and not e.Inner then
		e.Inner = New("Frame", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), ZIndex = 19, Parent = e.Frame,
		}, { Corner(math.max(e.Radius - 3, 2)) })
		e.InnerStroke = New("UIStroke", { Thickness = 1, Transparency = 1, Color = Color3.new(1, 1, 1), Parent = e.Inner })
	end
	if e.Inner then
		local fc, tc = from.InnerLine, to.InnerLine
		e.Inner.Visible = ip > 0.01
		e.InnerStroke.Color = (fc and tc) and fc:Lerp(tc, a) or (tc or fc or Color3.new(1, 1, 1))
		e.InnerStroke.Transparency = 1 - ip * 0.45
	end

	-- blueprint grid
	local gp = presence("Grid")
	if gp > 0.01 and not e.Grid then
		e.Grid = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 0, Parent = e.Frame })
		e.GridLines = {}
		for x = 0, 1600, 22 do
			table.insert(e.GridLines, New("Frame", { Position = UDim2.fromOffset(x, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundTransparency = 1, ZIndex = 0, Parent = e.Grid }))
		end
		for y = 0, 1200, 22 do
			table.insert(e.GridLines, New("Frame", { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 1, ZIndex = 0, Parent = e.Grid }))
		end
		e.GridP = -1
	end
	if e.Grid then
		e.Grid.Visible = gp > 0.01
		local gc = to.GridColor or from.GridColor or Color3.new(1, 1, 1)
		if math.abs((e.GridP or -1) - gp) > 0.004 or e.GridC ~= gc then
			e.GridP, e.GridC = gp, gc
			for i, ln in ipairs(e.GridLines) do
				ln.BackgroundColor3 = gc
				-- every 4th line is a major line
				ln.BackgroundTransparency = 1 - gp * ((i % 4 == 1) and 0.09 or 0.04)
			end
		end
	end
end

local function RegisterSurface(frame, kind, radius)
	local e = { Frame = frame, Kind = kind, Radius = radius or 10, Gradient = New("UIGradient", { Rotation = 90, Parent = frame }) }
	e.Stroke = frame:FindFirstChildOfClass("UIStroke")
	e.StrokeGrad = e.Stroke and e.Stroke:FindFirstChildOfClass("UIGradient")
	SurfaceSet[frame] = true
	if kind == "Window" then
		e.LineGrad = New("UIGradient", { Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) })
		e.Line = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.72, 0, 0, 1),
			BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 6, Parent = frame,
		}, { e.LineGrad })
		e.LeakGrad = New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.86), NumberSequenceKeypoint.new(1, 1) }) })
		e.Leak = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 1), Size = UDim2.new(0.6, 0, 0, 22),
			BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 0, Parent = frame,
		}, { e.LeakGrad })
	end
	table.insert(Surfaces, e)
	StyleSurface(e)
	return e
end
table.insert(Refreshers, function()
	for i = #Surfaces, 1, -1 do
		if Surfaces[i].Frame.Parent then StyleSurface(Surfaces[i]) else table.remove(Surfaces, i) end
	end
end)
Connect(RunService.RenderStepped, function()
	local t = os.clock()
	for _, e in ipairs(Surfaces) do
		if e.AuraOn and (e.AuraSpeed or 0) > 0 and e.Frame.Visible then
			e.StrokeGrad.Rotation = (t * e.AuraSpeed * 360) % 360
		end
	end
	-- prism themes: the accent gradient slowly cycles through the spectrum
	if Lumen.Style.AccentCycle and t - (Lumen._cycleT or 0) > 0.05 then
		Lumen._cycleT = t
		for _, e in ipairs(AccentFills) do if e.Frame.Parent then PaintAccent(e) end end
	end
end)

local Scales = {}
local function RegisterScale(parent)
	local sc = New("UIScale", { Scale = Lumen.Scale, Parent = parent })
	table.insert(Scales, sc)
	return sc
end

function Lumen:SetScale(n)
	n = math.clamp(n, 0.6, 1.6)
	self.Scale = n
	for i = #Scales, 1, -1 do
		local sc = Scales[i]
		if sc.Parent then sc.Scale = n else table.remove(Scales, i) end
	end
end

-- keeps UI toggles in sync when a setting is changed from code / dock
local function SyncOption(flag, v)
	local o = Lumen.Options[flag]
	if o and o.Value ~= v then o:Set(v, true) end
end

-- High-res icons: 96px PNGs drawn as vectors (assets/icons in the repo), tinted by the theme through ImageColor3.
-- They are downloaded once and cached in <Folder>/icons, then loaded with getcustomasset. Until they're ready (or where
-- the executor can't load files, e.g. Studio) every icon falls back to the vector version drawn from frames below.
-- Studio / your own uploads: pass Icons = {window = "rbxassetid://...", ...} as a load option, or set Lumen.IconAssets.
local ICON_NAMES = { "window", "scan", "keyboard", "command", "user", "bell", "check", "cross", "warn", "info", "discord",
	"gear", "snow", "list", "heart", "chevron", "search", "eye", "sparkle", "lock", "palette" }
local ICON_VERSION = "v1"
local IconImages = {}
Lumen.IconAssets = IconImages
if type(LoadOptions.Icons) == "table" then for k, v in pairs(LoadOptions.Icons) do IconImages[k] = v end end
local LiveIcons = setmetatable({}, { __mode = "k" })

local function IconImage(f, kind, colorKey, fadeIn)
	local img = New("ImageLabel", {
		Name = "IconImage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = IconImages[kind],
		ScaleType = Enum.ScaleType.Fit, ImageTransparency = fadeIn and 1 or 0, ZIndex = f.ZIndex, Parent = f,
		Theme = { ImageColor3 = colorKey },
	})
	if fadeIn then Tween(img, 0.3, { ImageTransparency = 0 }) end
	return img
end

-- Vector icons drawn from frames: window, keyboard, command, scan, bell, user, gear, snow, list, discord
local CustomIcons = {}
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local function Icon(kind, parent, size, colorKey)
	size = size or 16
	colorKey = colorKey or "Label"
	local s = size / 16
	local f = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Parent = parent })
	-- a rounded line from (x1, y1) to (x2, y2), positioned by its centre so glyphs come out exactly centred
	local function Seg(x1, y1, x2, y2, th)
		local dx, dy = x2 - x1, y2 - y1
		local len = math.sqrt(dx * dx + dy * dy)
		return New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((x1 + x2) / 2 * s, (y1 + y2) / 2 * s),
			Size = UDim2.fromOffset((len + th) * s, th * s), Rotation = math.deg(atan2(dy, dx)), Parent = f,
			Theme = { BackgroundColor3 = colorKey },
		}, { CornerFixed(th / 2 * s) })
	end
	local function Dot(cx, cy, d)
		return New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx * s, cy * s), Size = UDim2.fromOffset(d * s, d * s),
			Parent = f, Theme = { BackgroundColor3 = colorKey },
		}, { CornerFixed(d / 2 * s) })
	end
	if CustomIcons[kind] then
		local ok, err = pcall(CustomIcons[kind], f, size, colorKey, { Seg = Seg, Dot = Dot })
		if not ok then warn("[Lumen] icon '" .. tostring(kind) .. "' failed: " .. tostring(err)) end
		return f
	end
	if IconImages[kind] then
		IconImage(f, kind, colorKey)
		return f
	end
	-- vector fallback; swapped for the image as soon as the high-res set has loaded
	if table.find(ICON_NAMES, kind) then LiveIcons[f] = { Kind = kind, Key = colorKey } end
	local function Bar(x, y, w, h, r, key)
		local b = New("Frame", {
			Position = UDim2.fromOffset(x * s, y * s), Size = UDim2.fromOffset(w * s, h * s), Parent = f,
			Theme = { BackgroundColor3 = key or colorKey },
		}, { CornerFixed((r or 1) * s) })
		if key then b:SetAttribute("Fixed", true) end
		return b
	end
	local function Ring(x, y, w, h, r, th)
		return New("Frame", {
			Position = UDim2.fromOffset(x * s, y * s), Size = UDim2.fromOffset(w * s, h * s),
			BackgroundTransparency = 1, Parent = f,
		}, { CornerFixed((r or 3) * s), New("UIStroke", { Thickness = th or 1.4, Theme = { Color = colorKey } }) })
	end
	-- a clipping box, used to cut rounded shapes into arcs and domes
	local function Clip(x, y, w, h)
		return New("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(x * s, y * s),
			Size = UDim2.fromOffset(w * s, h * s), Parent = f })
	end
	local th = math.max(1, 1.35 * s)
	if kind == "window" then
		-- browser-style window: frame, title bar, a small inset panel
		Ring(1, 2.4, 14, 11.2, 2.6, th)
		Seg(1.6, 5.6, 14.4, 5.6, 1.3)
		Ring(8.2, 8.4, 4.4, 2.8, 0.9, math.max(1, 1.1 * s))
	elseif kind == "keyboard" then
		Ring(0.8, 3.4, 14.4, 9.2, 2.2, th)
		for _, x in ipairs({ 3.6, 5.8, 8, 10.2, 12.4 }) do Dot(x, 6.3, 1.25) Dot(x, 8.3, 1.25) end
		Seg(5.4, 10.5, 10.6, 10.5, 1.3)
	elseif kind == "command" then
		-- the command / looped-square symbol
		Ring(5.4, 5.4, 5.2, 5.2, 0.6, th)
		for _, p in ipairs({ { 1.5, 1.5 }, { 10.1, 1.5 }, { 1.5, 10.1 }, { 10.1, 10.1 } }) do
			Ring(p[1], p[2], 4.4, 4.4, 2.2, th)
		end
	elseif kind == "scan" then
		-- face-scan: four corner brackets around a head and shoulders
		local L = 3.4
		Seg(1.2, 1.2, 1.2 + L, 1.2, 1.3); Seg(1.2, 1.2, 1.2, 1.2 + L, 1.3)
		Seg(14.8, 1.2, 14.8 - L, 1.2, 1.3); Seg(14.8, 1.2, 14.8, 1.2 + L, 1.3)
		Seg(1.2, 14.8, 1.2 + L, 14.8, 1.3); Seg(1.2, 14.8, 1.2, 14.8 - L, 1.3)
		Seg(14.8, 14.8, 14.8 - L, 14.8, 1.3); Seg(14.8, 14.8, 14.8, 14.8 - L, 1.3)
		Ring(6, 3.6, 4, 4, 2, th)
		local c = Clip(4.1, 9.2, 7.8, 3.2)
		New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(7.8 * s, 7 * s), Parent = c },
			{ CornerFixed(3.5 * s), New("UIStroke", { Thickness = th, Theme = { Color = colorKey } }) })
	elseif kind == "bell" then
		-- filled bell: dome, flared rim, clapper, hanger
		Dot(8, 2.1, 1.9)
		local c = Clip(3.4, 2.6, 9.2, 8.6)
		New("Frame", { Size = UDim2.fromOffset(9.2 * s, 14 * s), Parent = c, Theme = { BackgroundColor3 = colorKey } }, { CornerFixed(4.6 * s) })
		Bar(2.2, 10.4, 11.6, 2, 1)
		Dot(8, 13.9, 2.6)
	elseif kind == "user" then
		-- a person with a small heart: "people who made this"
		Dot(6.6, 4.6, 5.4)
		local c = Clip(1.4, 9, 10.4, 5.8)
		New("Frame", { Size = UDim2.fromOffset(10.4 * s, 11 * s), Parent = c, Theme = { BackgroundColor3 = colorKey } }, { CornerFixed(5.2 * s) })
		Dot(11.4, 10.4, 3.4); Dot(13.8, 10.4, 3.4)
		local h = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(12.6 * s, 11.9 * s), Size = UDim2.fromOffset(3.5 * s, 3.5 * s),
			Rotation = 45, Parent = f, Theme = { BackgroundColor3 = colorKey } }, { CornerFixed(0.6 * s) })
	elseif kind == "gear" then
		Ring(2.5, 2.5, 11, 11, 5.5, 2)
		Bar(6, 6, 4, 4, 2)
	elseif kind == "snow" then
		for _, rot in ipairs({ 0, 60, 120 }) do Bar(1, 7.2, 14, 1.6).Rotation = rot end
	elseif kind == "list" then
		Bar(2, 3.5, 12, 1.6); Bar(2, 7.2, 12, 1.6); Bar(2, 10.9, 12, 1.6)
	elseif kind == "check" then
		Seg(3.4, 8.4, 6.6, 11.6, 2.4)
		Seg(6.6, 11.6, 12.8, 4.8, 2.4)
	elseif kind == "cross" then
		Seg(4.4, 4.4, 11.6, 11.6, 2.4)
		Seg(11.6, 4.4, 4.4, 11.6, 2.4)
	elseif kind == "warn" then
		-- exclamation mark: tall bar + dot
		Seg(8, 3.4, 8, 9.2, 2.8)
		Dot(8, 12.6, 3)
	elseif kind == "info" then
		-- a serif "i": dot, stem, small cap on the left, foot
		Dot(8, 3.4, 2.8)
		Seg(8, 7.2, 8, 12.4, 2.4)
		Seg(6.2, 7.2, 8, 7.2, 2)
		Seg(5.8, 12.6, 10.2, 12.6, 2)
	elseif kind == "discord" then
		Bar(2.4, 1.8, 4, 4, 2); Bar(9.6, 1.8, 4, 4, 2)
		Bar(1, 3.8, 14, 9.4, 4.7)
		Bar(4.4, 7.2, 2.2, 3, 1.1, "Background"); Bar(9.4, 7.2, 2.2, 3, 1.1, "Background")
	end
	return f
end

local function RecolorIcon(f, color)
	for _, d in ipairs(f:GetDescendants()) do
		if d:IsA("ImageLabel") and d.Name == "IconImage" then
			d.ImageColor3 = color
		elseif d:IsA("UIStroke") then
			d.Color = color
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 and not d:GetAttribute("Fixed") then
			d.BackgroundColor3 = color
		end
	end
end

local function Row(container, h)
	local n = (container:GetAttribute("Order") or 0) + 1
	container:SetAttribute("Order", n)
	return New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, h or 22),
		LayoutOrder = n,
		Parent = container,
	})
end

local function Esc(s) return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end

local function IsPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local function MouseInside(frame)
	local m = UIS:GetMouseLocation()
	local p, s = frame.AbsolutePosition, frame.AbsoluteSize
	return m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y
end

-- Calls cb(x, y) in GUI coordinates while the pointer is held down that started on `frame`.
-- The pointer position is read from the input object and calibrated on press, so it stays correct
-- whether or not the executor/Roblox reports it with the top-bar inset.
local function Dragger(frame, cb)
	local active, off = false, Vector2.new(0, 0)
	local function Pos(i) return Vector2.new(i.Position.X, i.Position.Y) + off end
	Connect(frame.InputBegan, function(i)
		if IsPress(i) then
			active = true
			local a = UIS:GetMouseLocation()
			local b = Vector2.new(i.Position.X, i.Position.Y)
			local ap, sz = frame.AbsolutePosition, frame.AbsoluteSize
			local inside = b.X >= ap.X and b.X <= ap.X + sz.X and b.Y >= ap.Y and b.Y <= ap.Y + sz.Y
			off = inside and Vector2.new(0, 0) or (a - b)
			local p = Pos(i)
			cb(p.X, p.Y)
		end
	end)
	Connect(UIS.InputChanged, function(i)
		if active and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local p = Pos(i)
			cb(p.X, p.Y)
		end
	end)
	Connect(UIS.InputEnded, function(i)
		if IsPress(i) then active = false end
	end)
end

local SnapHomes = {}
-- snapKey (optional): "Dock" / "Hotkeys" / "Watermark". When Lumen.SnapBack allows it, the target glides
-- back to where it started a few seconds after you let go. Grabbing it again cancels the return.
local function MakeDraggable(handle, target, onStart, snapKey)
	local dragging, startMouse, startPos = false, nil, nil
	local token, homeTween = 0, nil
	Connect(handle.InputBegan, function(i)
		if IsPress(i) then
			dragging = true
			token = token + 1
			if homeTween then homeTween:Cancel() homeTween = nil end
			if snapKey and not SnapHomes[target] then SnapHomes[target] = target.Position end
			startMouse = UIS:GetMouseLocation()
			startPos = target.Position
			if onStart then onStart() end
		end
	end)
	Connect(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = UIS:GetMouseLocation() - startMouse
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	Connect(UIS.InputEnded, function(i)
		if IsPress(i) and dragging then
			dragging = false
			local sb = Lumen.SnapBack
			if snapKey and sb.Enabled and sb[snapKey] then
				token = token + 1
				local mine = token
				task.delay(sb.Delay, function()
					if mine ~= token or dragging or Lumen.Unloaded then return end
					local home = SnapHomes[target]
					if not home or target.Position == home then return end
					homeTween = TweenService:Create(target, TweenInfo.new(0.75, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = home })
					homeTween:Play()
				end)
			end
		end
	end)
end

-- glide every snap-enabled HUD piece home now
function Lumen:ResetHudPositions()
	for target, home in pairs(SnapHomes) do
		if target.Parent then
			TweenService:Create(target, TweenInfo.new(0.75, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = home }):Play()
		end
	end
end

-- make the current spots the new home positions
function Lumen:SetHudHome()
	for target in pairs(SnapHomes) do
		if target.Parent then SnapHomes[target] = target.Position end
	end
end

local ShortKeys = {
	Insert = "ins", Delete = "del", LeftShift = "lshift", RightShift = "rshift",
	LeftControl = "lctrl", RightControl = "rctrl", LeftAlt = "lalt", RightAlt = "ralt",
	Return = "enter", Backspace = "bksp", CapsLock = "caps", Escape = "esc",
	PageUp = "pgup", PageDown = "pgdn", MouseButton2 = "m2", MouseButton3 = "m3",
	Zero = "0", One = "1", Two = "2", Three = "3", Four = "4",
	Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9",
}
local function KeyName(v)
	if not v then return "none" end
	return ShortKeys[v.Name] or v.Name:lower()
end

local function Matches(input, v)
	if not v then return false end
	if v.EnumType == Enum.KeyCode then return input.KeyCode == v end
	return input.UserInputType == v
end

local function PresetLabel(n) return n == "Lavender" and "Lavender (Default)" or n end
local function PresetName(l) return (tostring(l):gsub(" %(Default%)$", "")) end
Lumen.PresetLabel = PresetLabel

function Lumen:ApplyPreset(name)
	name = PresetName(name)
	local p = self.Presets[name]
	if not p then return end
	self.Preset = name
	local colors = {}
	for k, v in pairs(p) do if k ~= "Style" then colors[k] = v end end
	self:SetTheme(colors, self.ThemeTransition)
	self:SetStyle(p.Style or {}, self.ThemeTransition)
	SyncOption("Lumen_Preset", PresetLabel(name))
end

local ThemeToken = 0
local function ApplyThemeNow()
	local T = Lumen.Theme
	for i = #Themed, 1, -1 do
		local e = Themed[i]
		if e[1].Parent == nil then
			table.remove(Themed, i)
		else
			pcall(function() e[1][e[2]] = T[e[3]] end)
		end
	end
	for _, g in ipairs(Gradients) do UpdateGradient(g) end
	for _, fn in ipairs(Refreshers) do pcall(fn) end
end

-- t: theme keys to change. fade (seconds, optional): blend from the current palette instead of snapping.
function Lumen:SetTheme(t, fade)
	local T = self.Theme
	local N = {}
	for k, v in pairs(self._themeTarget or T) do N[k] = v end
	for k, v in pairs(t) do N[k] = v end
	if t.Accent or t.Background then
		if not t.AccentText then N.AccentText = N.Accent:Lerp(Color3.new(1, 1, 1), 0.02) end
		if not t.AccentBorder then N.AccentBorder = N.Accent:Lerp(N.Background, 0.36) end
		if not t.Toggle then N.Toggle = N.Accent:Lerp(N.Background, 0.64) end
		if not t.TabActive then N.TabActive = N.Accent:Lerp(N.Background, 0.79) end
	end
	if (t.Control or t.Background) and not t.Chip then N.Chip = N.Control:Lerp(N.Background, 0.08) end
	if (t.TextDim or t.Label) and not t.ChipText then N.ChipText = N.TextDim:Lerp(N.Label, 0.4) end
	if t.Control and not t.ControlHover then N.ControlHover = t.Control:Lerp(Color3.new(1, 1, 1), 0.07) end

	ThemeToken = ThemeToken + 1
	local mine = ThemeToken
	fade = fade or 0
	self.Events.ThemeChanged:Fire(N)
	if fade <= 0 or #Themed > 9000 then
		self._themeTarget = nil
		for k, v in pairs(N) do T[k] = v end
		ApplyThemeNow()
		return
	end
	self._themeTarget = N
	local before = {}
	for k, v in pairs(T) do before[k] = v end
	task.spawn(function()
		local steps = math.max(2, math.floor(fade * 30))
		for i = 1, steps do
			if mine ~= ThemeToken or Lumen.Unloaded then return end
			local a = i / steps
			a = 1 - (1 - a) * (1 - a)
			for k, v in pairs(N) do
				local b = before[k]
				if i < steps and typeof(v) == "Color3" and typeof(b) == "Color3" then T[k] = b:Lerp(v, a) else T[k] = v end
			end
			ApplyThemeNow()
			if i < steps then task.wait(fade / steps) end
		end
		if mine == ThemeToken then Lumen._themeTarget = nil end
	end)
end

------------------------------------------------------------------------------
-- Root GUI, popups, tooltip
------------------------------------------------------------------------------

Gui = Instance.new("ScreenGui")
Gui.Name = LoadOptions.Name or (InstanceId == "default" and "LumenUI" or ("LumenUI_" .. InstanceId))
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = LoadOptions.DisplayOrder or 10000
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
do
	if syn and syn.protect_gui then pcall(syn.protect_gui, Gui) end
	local ok = false
	if typeof(LoadOptions.Parent) == "Instance" then ok = pcall(function() Gui.Parent = LoadOptions.Parent end) end
	if (not ok or not Gui.Parent) and gethui then ok = pcall(function() Gui.Parent = gethui() end) end
	if not ok or not Gui.Parent then ok = pcall(function() Gui.Parent = Service("CoreGui") end) end
	if not ok or not Gui.Parent then Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
end

Overlay = New("Frame", {
	Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = Gui,
})

Lumen.Gui = Gui

local PopupCatcher = New("TextButton", {
	Name = "PopupCatcher", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 1,
	Active = true, Parent = Overlay,
})

local PopupInfoOpen = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local PopupInfoClose = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function ClosePopup()
	PopupCatcher.Visible = false
	if OpenPopup then
		local p = OpenPopup
		OpenPopup = nil
		local f, full = p.Frame, p.Full
		local tok = (f:GetAttribute("PopTok") or 0) + 1
		f:SetAttribute("PopTok", tok)
		TweenService:Create(f, PopupInfoClose, { Size = UDim2.fromOffset(full.X.Offset, 0) }):Play()
		task.delay(0.13, function()
			if f:GetAttribute("PopTok") == tok then
				f.Visible = false
				f.Size = full
			end
		end)
		if p.OnClose then p.OnClose() end
	end
end

Connect(PopupCatcher.MouseButton1Down, function() ClosePopup() end)
Connect(PopupCatcher.MouseButton2Down, function() ClosePopup() end)

-- popups unfold downward from their trigger (and fold back up when closed) instead of popping in
local function ShowPopup(frame, trigger, onClose)
	ClosePopup()
	local sc = frame:FindFirstChildOfClass("UIScale")
	if not sc then sc = New("UIScale", { Parent = frame }) end
	sc.Scale = Lumen.Scale
	local full = frame.Size
	local vp = Gui.AbsoluteSize
	local w, h = full.X.Offset * Lumen.Scale, full.Y.Offset * Lumen.Scale
	local tp, ts = trigger.AbsolutePosition, trigger.AbsoluteSize
	local x = math.clamp(tp.X, 6, math.max(6, vp.X - w - 6))
	local y = tp.Y + ts.Y + 4
	if y + h > vp.Y - 6 then y = math.max(6, tp.Y - h - 4) end
	frame.Position = UDim2.fromOffset(x, y)
	frame.ZIndex = 5
	frame.ClipsDescendants = true
	local tok = (frame:GetAttribute("PopTok") or 0) + 1
	frame:SetAttribute("PopTok", tok)
	frame.Size = UDim2.fromOffset(full.X.Offset, 0)
	PopupCatcher.Visible = true
	frame.Visible = true
	TweenService:Create(frame, PopupInfoOpen, { Size = full }):Play()
	OpenPopup = { Frame = frame, Trigger = trigger, OnClose = onClose, Full = full }
end

-- Hover explanations: a card that fades and lifts in after a short rest, glides between elements,
-- and fades out when the mouse leaves. Used by Description = "..." on any element, tooltips, dock buttons and chips.
local Hint = { Token = 0 }
local HintCard = New("CanvasGroup", {
	Visible = false, Size = UDim2.fromOffset(240, 0), AutomaticSize = Enum.AutomaticSize.Y, GroupTransparency = 1,
	BackgroundTransparency = 1, ZIndex = 300, Parent = Gui,
})
local HintScale = New("UIScale", { Scale = 1, Parent = HintCard })
New("Frame", { Size = UDim2.fromScale(1, 1), ZIndex = 300, Parent = HintCard, Theme = { BackgroundColor3 = "Background" } }, { Corner(8) })
-- border drawn 1px inside so the canvas never clips it
New("Frame", { Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), BackgroundTransparency = 1, ZIndex = 301, Parent = HintCard },
	{ Corner(7), Stroke("Border") })
local HintStrip = New("Frame", {
	Position = UDim2.fromOffset(0, 8), Size = UDim2.new(0, 2, 1, -16), ZIndex = 302, Parent = HintCard, Theme = { BackgroundColor3 = "Accent" },
}, { CornerFixed(1) })
local HintBody = New("Frame", {
	BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 302, Parent = HintCard,
}, { Pad(13, 9, 12, 10), List(3) })
local HintTitle = New("TextLabel", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = 12, Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 303, LayoutOrder = 1, TextColor3 = Lumen.Theme.Text, Parent = HintBody,
})
local HintText = New("TextLabel", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = 11, Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 303, LayoutOrder = 2, TextColor3 = Lumen.Theme.TextDim, Parent = HintBody,
})

local function HintMeasure(title, body)
	local w, h = 0, 0
	pcall(function()
		local b = TextService:GetTextSize(body, 11, Enum.Font.GothamMedium, Vector2.new(214, 10000))
		w, h = b.X, b.Y
		if title and title ~= "" then
			local t = TextService:GetTextSize(title, 12, Enum.Font.GothamBold, Vector2.new(214, 10000))
			w = math.max(w, t.X)
			h = h + t.Y + 3
		end
	end)
	if not w or w <= 0 then w, h = 214, 40 end
	w = math.clamp(math.ceil(w) + 30, 110, 246)
	return w, math.ceil(h) + 21
end

-- The card goes beside the window (or panel / dock) the element lives in, level with the element, so it never covers
-- what you're about to click. With no room on either side it goes beside the element itself, then below it.
local function HintRoot(anchor)
	local p = anchor
	while p and p ~= Gui do
		if SurfaceSet[p] then return p end
		p = p.Parent
	end
end
local function HintSpot(anchor, w, h)
	local vp = Gui.AbsoluteSize
	local ap, sz = anchor.AbsolutePosition, anchor.AbsoluteSize
	local cy = ap.Y + sz.Y / 2
	local y = math.clamp(cy - h / 2, 8, math.max(8, vp.Y - h - 8))
	local root = HintRoot(anchor)
	if root then
		local rp, rs = root.AbsolutePosition, root.AbsoluteSize
		if rp.X + rs.X + 12 + w <= vp.X - 8 then return rp.X + rs.X + 12, y, "right", cy end
		if rp.X - w - 12 >= 8 then return rp.X - w - 12, y, "left", cy end
	end
	if ap.X + sz.X + 10 + w <= vp.X - 8 then return ap.X + sz.X + 10, y, "right", cy end
	if ap.X - w - 10 >= 8 then return ap.X - w - 10, y, "left", cy end
	local by = ap.Y + sz.Y + 6
	if by + h > vp.Y - 8 then by = math.max(8, ap.Y - h - 6) end
	return math.clamp(ap.X, 8, math.max(8, vp.X - w - 8)), by, "below", cy
end

local function ShowHint(anchor, title, body)
	if not Lumen.Hints or type(body) ~= "string" or body == "" then return end
	Hint.Token = Hint.Token + 1
	local mine = Hint.Token
	local gliding = HintCard.Visible and HintCard.GroupTransparency < 0.6
	task.delay(gliding and 0.04 or Lumen.HintDelay, function()
		if mine ~= Hint.Token or Lumen.Unloaded or not anchor.Parent then return end
		HintTitle.Text = title or ""
		HintTitle.Visible = title ~= nil and title ~= ""
		HintText.Text = body
		local w, h = HintMeasure(title, body)
		HintCard.Size = UDim2.fromOffset(w, 0)
		local x, y, side, cy = HintSpot(anchor, w, h)
		-- the accent strip sits on the side facing the element, level with it, like a pointer
		local stripY = math.clamp(cy - y - 9, 6, math.max(6, h - 24))
		local stripGoal = { Position = side == "left" and UDim2.new(1, -2, 0, stripY) or UDim2.fromOffset(0, stripY) }
		HintStrip.Size = UDim2.fromOffset(2, 18)
		if gliding then
			TweenService:Create(HintCard, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{ Position = UDim2.fromOffset(x, y), GroupTransparency = 0 }):Play()
			TweenService:Create(HintStrip, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), stripGoal):Play()
			TweenService:Create(HintScale, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		else
			HintStrip.Position = stripGoal.Position
			local dx = side == "left" and 8 or (side == "right" and -8 or 0)
			HintCard.Position = UDim2.fromOffset(x + dx, side == "below" and y + 7 or y)
			HintScale.Scale = 0.95
			HintCard.GroupTransparency = 1
			HintCard.Visible = true
			TweenService:Create(HintCard, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{ Position = UDim2.fromOffset(x, y), GroupTransparency = 0 }):Play()
			TweenService:Create(HintScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)
end

local function HideHint()
	Hint.Token = Hint.Token + 1
	local mine = Hint.Token
	task.delay(0.07, function()
		if mine ~= Hint.Token then return end
		TweenService:Create(HintCard, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 }):Play()
		TweenService:Create(HintScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.97 }):Play()
		task.delay(0.16, function() if mine == Hint.Token then HintCard.Visible = false end end)
	end)
end
Lumen.ShowHint, Lumen.HideHint = function(_, anchor, title, body) ShowHint(anchor, title, body) end, function() HideHint() end

-- title / body may be strings or functions (read each time the hint opens)
local function AttachHint(inst, title, body)
	Connect(inst.MouseEnter, function()
		local t = type(title) == "function" and title() or title
		local b = type(body) == "function" and body() or body
		ShowHint(inst, t, b)
	end)
	Connect(inst.MouseLeave, HideHint)
	Connect(inst.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then HideHint() end
	end)
end
local function AttachTooltip(inst, text) AttachHint(inst, nil, text) end

------------------------------------------------------------------------------
-- Option base (shared by every element)
------------------------------------------------------------------------------

local OptBase = {}
OptBase.__index = OptBase

local function NewOpt(typ, o)
	return setmetatable({ Type = typ, Listeners = {}, Callback = o.Callback }, OptBase)
end

function OptBase:OnChanged(fn)
	table.insert(self.Listeners, fn)
	return self
end

-- hover explanation for any element: element:SetDescription("What this does")
function OptBase:SetDescription(text)
	self.Description = text
	if not self._hinted and self.Row then
		self._hinted = true
		AttachHint(self.Row, function() return self._text end, function() return self.Description end)
	end
	return self
end

function OptBase:Get() return self.Value end

function OptBase:SetVisible(v)
	if self.Row then self.Row.Visible = v end
end

function OptBase:SetDisabled(v)
	self.Disabled = v and true or false
	if self._onDisabled then self._onDisabled(self.Disabled) end
	if self.Row then
		if not self._blocker then
			self._blocker = New("TextButton", {
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = self._blockerAlpha or 0.45, ZIndex = 30,
				Active = true, Visible = false, Parent = self.Row, Theme = { BackgroundColor3 = "Group" },
			})
		end
		self._blocker.Visible = self.Disabled
	end
end

function OptBase:Destroy()
	if self.Flag then
		Lumen.Options[self.Flag] = nil
		Lumen.Flags[self.Flag] = nil
	end
	if self.Row then self.Row:Destroy() end
end

local function Register(opt, flag)
	if not flag then return end
	opt.Flag = flag
	Lumen.Options[flag] = opt
	Lumen.Flags[flag] = opt.Value
end

local function Fire(opt, ...)
	local label = tostring(opt.Type) .. " '" .. tostring(opt._text or opt.Flag or opt.Name or "?") .. "'"
	if opt.Flag then
		Lumen.Flags[opt.Flag] = opt.Value
		Lumen.Events.FlagChanged:Fire(opt.Flag, opt.Value)
	end
	if opt.Callback then SafeCall(label, opt.Callback, ...) end
	for _, cb in ipairs(opt.Listeners) do SafeCall(label, cb, ...) end
end

-- everything searchable from the command palette
Lumen._Catalog = {}
Lumen._Panels = {}
Lumen._presetDropdowns = {}
local function CatalogAdd(group, opt, name)
	if not name then return end
	opt._text = opt._text or name
	table.insert(Lumen._Catalog, { Opt = opt, Name = name, Path = group._path or "", Tab = group._tab, Group = group })
end

-- addon holder (keybind chip / color swatches / tooltip chip, right aligned in a row)
local function MakeAddonHolder(row)
	return New("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 5, Parent = row,
	}, { List(5, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
end

------------------------------------------------------------------------------
-- Notifications, watermark, hotkey list
------------------------------------------------------------------------------

local NotifHolder = New("Frame", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(290, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 100, Parent = Gui,
}, { List(0, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right) })

local NOTIFY_KINDS = {
	Success = { Key = "Success", Icon = "check", Shape = "circle" },
	Warning = { Key = "Caution", Icon = "warn", Shape = "diamond" },
	Caution = { Key = "Caution", Icon = "warn", Shape = "diamond" },
	Danger = { Key = "Error", Icon = "cross", Shape = "square" },
	Error = { Key = "Error", Icon = "cross", Shape = "square" },
	Info = { Key = "Info", Icon = "info", Shape = "circle" },
	Loading = { Key = "Accent", Icon = "spinner", Shape = "circle" },
}
local NotifyCount = 0
local LiveNotifs = {}
local NOTIFY_POS = { TopRight = { 1, 0 }, BottomRight = { 1, 1 }, TopLeft = { 0, 0 }, BottomLeft = { 0, 1 } }
Lumen.NotifyPositions = { "TopRight", "BottomRight", "TopLeft", "BottomLeft" }

local function Spinner(parent, color)
	return New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(14, 14), Parent = parent }, {
		CornerFixed(7),
		New("UIStroke", { Thickness = 2, Color = color }, {
			New("UIGradient", { Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(0.52, 1), NumberSequenceKeypoint.new(1, 1) }) }),
		}),
	})
end

-- A coloured status badge: circle (success / info), diamond (warning) or rounded square (error), with a centred glyph.
-- Distinct shapes as well as colours, so the type reads at a glance.
local function StatusBadge(parent, kind, size)
	size = size or 26
	local T = Lumen.Theme
	local color = T[kind.Key] or T.Accent
	local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Parent = parent })
	local plate
	if kind.Shape == "diamond" then
		local d = math.floor(size * 0.76 + 0.5)
		plate = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(d, d), Rotation = 45,
			BackgroundColor3 = color:Lerp(T.Background, 0.78), Parent = holder,
		}, { CornerFixed(math.floor(size * 0.2)), New("UIStroke", { Color = color:Lerp(T.Background, 0.35), Thickness = 1 }) })
	else
		plate = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = color:Lerp(T.Background, 0.78), Parent = holder,
		}, { CornerFixed(kind.Shape == "square" and math.floor(size * 0.3) or math.ceil(size / 2)),
			New("UIStroke", { Color = color:Lerp(T.Background, 0.35), Thickness = 1 }) })
	end
	local glyph
	if kind.Icon == "spinner" then
		glyph = Spinner(holder, color)
	else
		glyph = Icon(kind.Icon, holder, math.floor(size * 0.6 + 0.5), kind.Key)
	end
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.ZIndex = plate.ZIndex + 1
	return holder, plate, glyph, color
end
Lumen.StatusBadge = StatusBadge

function Lumen:SetNotifyPosition(pos)
	local p = NOTIFY_POS[pos]
	if not p then pos, p = "TopRight", NOTIFY_POS.TopRight end
	self.NotifyPosition = pos
	NotifHolder.AnchorPoint = Vector2.new(p[1], p[2])
	NotifHolder.Position = UDim2.new(p[1], p[1] == 1 and -12 or 12, p[2], p[2] == 1 and -12 or 12)
	local layout = NotifHolder:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.HorizontalAlignment = p[1] == 1 and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
		layout.VerticalAlignment = p[2] == 1 and Enum.VerticalAlignment.Bottom or Enum.VerticalAlignment.Top
	end
	SyncOption("Lumen_NotifyPos", pos)
end

-- o: string, or {
--   Title, Content, Type = "Success" | "Warning" | "Error" | "Info" | "Loading", Duration, Progress (bool),
--   Actions = {{Text = "Undo", Callback = fn}, ...}   -- small buttons under the text; clicking one closes the card
-- }
-- Returns a handle: handle:Update({...}) morphs it in place (e.g. Loading -> Success), handle:Dismiss() closes it.
-- Hover pauses the countdown, clicking the card dismisses it.
function Lumen:Notify(o, duration)
	if type(o) == "string" then o = { Content = o, Duration = duration } end
	o = o or {}
	local H = { Closed = false }
	function H:Update() end
	function H:Dismiss() end
	if not self.ShowNotifications or self.Unloaded then return H end
	self.Events.Notified:Fire(o)

	local side = NOTIFY_POS[self.NotifyPosition] or NOTIFY_POS.TopRight
	local offX = side[1] == 1 and 320 or -320
	NotifyCount = NotifyCount + 1
	local holder = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(290, 0), LayoutOrder = NotifyCount, Parent = NotifHolder,
	})
	local card = New("CanvasGroup", {
		Size = UDim2.fromOffset(280, 34), Position = UDim2.fromOffset(offX, 0), GroupTransparency = 1,
		Parent = holder, Theme = { BackgroundColor3 = "Background" },
	}, { Corner(9) })
	if side[1] == 1 then card.Position = UDim2.fromOffset(offX, 0) end
	-- border drawn 1px inside so the canvas can't clip it
	New("Frame", { Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), BackgroundTransparency = 1, ZIndex = 8, Parent = card },
		{ Corner(8), Stroke("Outline") })
	local hit = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = card })
	local body = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 3, Parent = card,
	}, { Pad(12, 9, 12, 10), New("UISizeConstraint", { MinSize = Vector2.new(0, 34) }),
		List(11, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local bar = New("Frame", { Size = UDim2.new(0, 3, 1, -12), Position = UDim2.fromOffset(0, 6), BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false, ZIndex = 4, Parent = card }, { CornerFixed(2) })
	local wash = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = card })
	New("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.84), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 1) }), Parent = wash })
	local shine = New("Frame", {
		Size = UDim2.new(0.45, 0, 1, 0), Position = UDim2.new(-0.6, 0, 0, 0), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 6, Parent = card,
	}, { New("UIGradient", { Rotation = 18, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.88), NumberSequenceKeypoint.new(1, 1) }) }) })
	local track = New("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 2), Visible = false, ZIndex = 5,
		Parent = card, Theme = { BackgroundColor3 = "Outline" },
	})
	local fill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5, Parent = track })
	-- bright head on the countdown bar
	local head = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(10, 2),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.2, ZIndex = 6, Parent = fill }, { CornerFixed(1) })

	local kind, color, dur, remaining, hovered = nil, nil, 4, 4, false
	local anim = { t = 0 }
	local glyph, plate, iconFrame, spin, ring
	local conn

	local function Fit()
		local h = math.max(34, body.AbsoluteSize.Y)
		card.Size = UDim2.fromOffset(280, h)
		if not H.Closed then Tween(holder, 0.25, { Size = UDim2.fromOffset(290, h + 6) }) end
	end
	Connect(body:GetPropertyChangedSignal("AbsoluteSize"), Fit)

	local function Close()
		if H.Closed then return end
		H.Closed = true
		if conn then conn:Disconnect() end
		for i, n in ipairs(LiveNotifs) do if n == H then table.remove(LiveNotifs, i) break end end
		TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
			{ Position = UDim2.fromOffset(offX, 0), GroupTransparency = 1 }):Play()
		task.delay(0.24, function()
			if holder.Parent then Tween(holder, 0.24, { Size = UDim2.fromOffset(290, 0) }) end
		end)
		task.delay(0.55, function() holder:Destroy() end)
	end

	local function Build(opts)
		for _, c in ipairs(body:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
		spin, ring, glyph, plate = nil, nil, nil, nil
		kind = NOTIFY_KINDS[opts.Type or ""]
		local T = Lumen.Theme
		color = kind and T[kind.Key] or T.Label

		-- icon
		if kind then
			local holderB
			holderB, plate, glyph = StatusBadge(body, kind, 26)
			holderB.LayoutOrder = 1
			iconFrame = holderB
			if kind.Icon == "spinner" then spin = glyph end
			-- pulse ring that expands out of the badge
			ring = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(26, 26),
				BackgroundTransparency = 1, ZIndex = 1, Parent = holderB,
			}, { CornerFixed(999), New("UIStroke", { Color = color, Thickness = 1.5, Transparency = 0.25 }) })
			TweenService:Create(ring, TweenInfo.new(0.75, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(52, 52) }):Play()
			TweenService:Create(ring:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
		else
			iconFrame = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(16, 16), LayoutOrder = 1, Parent = body })
			glyph = Icon("bell", iconFrame, 16, "Label")
		end

		-- text
		local text = New("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, -(kind and 37 or 27), 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2, Parent = body,
		}, { List(2) })
		if opts.Title then
			New("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Text = opts.Title,
				TextColor3 = kind and color or T.Text, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = text,
			})
		end
		if opts.Content then
			New("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = opts.Content, TextWrapped = true, RichText = true,
				TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, TextSize = opts.Title and 11 or 12,
				Font = opts.Title and Enum.Font.GothamMedium or Enum.Font.GothamSemibold,
				TextColor3 = opts.Title and T.TextDim or T.Label, Parent = text,
			})
		end
		if type(opts.Actions) == "table" and #opts.Actions > 0 then
			local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 3, Parent = text },
				{ Pad(0, 4, 0, 0), List(6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
			for i, act in ipairs(opts.Actions) do
				local b = New("TextButton", {
					AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), Text = tostring(act.Text or "OK"), TextSize = 11,
					BackgroundTransparency = 0, LayoutOrder = i, ZIndex = 7, TextColor3 = kind and color or T.Label,
					BackgroundColor3 = (kind and color or T.Accent):Lerp(T.Background, 0.82), Parent = row,
				}, { Corner(6), Pad(9, 0, 9, 0), New("UIStroke", { Color = (kind and color or T.Accent):Lerp(T.Background, 0.5), Thickness = 1 }) })
				Connect(b.MouseEnter, function() Tween(b, 0.1, { BackgroundColor3 = (kind and color or T.Accent):Lerp(T.Background, 0.66) }) end)
				Connect(b.MouseLeave, function() Tween(b, 0.1, { BackgroundColor3 = (kind and color or T.Accent):Lerp(T.Background, 0.82) }) end)
				Connect(b.MouseButton1Click, function()
					SafeCall("notification action '" .. tostring(act.Text) .. "'", act.Callback)
					Close()
				end)
			end
		end

		-- accent bar, colour wash and countdown only for typed notifications
		bar.Visible = kind ~= nil
		bar.BackgroundColor3 = color
		wash.BackgroundTransparency = kind and 0 or 1
		wash.BackgroundColor3 = color
		local loading = kind and kind.Icon == "spinner"
		dur = opts.Duration or (loading and math.huge or (kind and 4.5 or 4))
		remaining = dur
		track.Visible = (opts.Progress ~= false) and (kind ~= nil or opts.Progress == true) and not loading
		fill.BackgroundColor3 = color
		head.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.5)
		fill.Size = UDim2.fromScale(1, 1)

		-- entrance: every type has its own little motion
		anim.t = 0
		anim.kind = kind and kind.Icon or "bell"
		local sc = New("UIScale", { Scale = 0.3, Parent = glyph })
		TweenService:Create(sc, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if anim.kind == "check" then
			glyph.Rotation = -35
			TweenService:Create(glyph, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
		elseif anim.kind == "cross" then
			glyph.Rotation = 90
			TweenService:Create(glyph, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
		elseif anim.kind == "info" then
			glyph.Position = UDim2.new(0.5, 0, 0.5, -9)
			TweenService:Create(glyph, TweenInfo.new(0.6, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
		end
		shine.Position = UDim2.new(-0.6, 0, 0, 0)
		TweenService:Create(shine, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Position = UDim2.new(1.2, 0, 0, 0) }):Play()
		Fit()
	end

	function H:Update(o2)
		if self.Closed then return end
		for k, v in pairs(o2 or {}) do o[k] = v end
		if o2 and o2.Type == nil then o.Type = nil end
		Build(o)
	end
	function H:Dismiss() Close() end

	Connect(card.MouseEnter, function()
		hovered = true
		Tween(card, 0.18, { Position = UDim2.fromOffset(side[1] == 1 and -5 or 5, 0) })
	end)
	Connect(card.MouseLeave, function()
		hovered = false
		if not H.Closed then Tween(card, 0.18, { Position = UDim2.fromOffset(0, 0) }) end
	end)
	Connect(hit.MouseButton1Click, Close)

	conn = RunService.RenderStepped:Connect(function(dt)
		if H.Closed then return end
		anim.t = anim.t + dt
		local t, at = os.clock(), anim.t
		if spin then spin.Rotation = (spin.Rotation + dt * 380) % 360 end
		if kind then
			-- the accent bar breathes; warnings and errors breathe harder
			local k = (kind.Key == "Caution" or kind.Key == "Error") and 0.4 or 0.2
			bar.BackgroundTransparency = k * (0.5 + 0.5 * math.sin(t * 4.5))
		end
		if anim.kind == "warn" and glyph and at < 1.1 then
			-- the exclamation mark wobbles, settling over a second
			glyph.Rotation = math.sin(at * 22) * 16 * (1 - at / 1.1)
		elseif anim.kind == "bell" and glyph and at < 1.2 then
			-- the bell rings
			glyph.Rotation = math.sin(at * 26) * 20 * (1 - at / 1.2)
		elseif anim.kind == "cross" and at < 0.5 then
			-- errors shake the whole card
			card.Position = UDim2.fromOffset(math.sin(at * 70) * 7 * (1 - at / 0.5), 0)
		end
		if not hovered and remaining ~= math.huge then
			remaining = remaining - dt
			fill.Size = UDim2.fromScale(math.clamp(remaining / dur, 0, 1), 1)
			if remaining <= 0 then Close() end
		end
	end)
	table.insert(Connections, conn)

	Build(o)
	-- slide in from the screen edge with a little overshoot
	card.Position = UDim2.fromOffset(offX, 0)
	card.GroupTransparency = 1
	TweenService:Create(card, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, 0) }):Play()
	Tween(card, 0.3, { GroupTransparency = 0 })

	table.insert(LiveNotifs, H)
	if #LiveNotifs > 6 then LiveNotifs[1]:Dismiss() end
	return H
end

local Fps, WatermarkOverride, WatermarkTitle = 60, nil, nil
local Watermark = New("Frame", {
	Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X,
	ZIndex = 5, Parent = Gui, Theme = { BackgroundColor3 = "Background" },
}, { Corner(9), Stroke(nil, true), Pad(11, 0, 14, 0),
	List(9, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
MakeDraggable(Watermark, Watermark, nil, "Watermark")
SnapHomes[Watermark] = Watermark.Position
local WatermarkLogo = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(18, 18), LayoutOrder = 1, Parent = Watermark }, {
	New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, { CornerFixed(9), New("UIStroke", { Thickness = 2, Theme = { Color = "AccentBorder" } }) }),
	New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), Theme = { BackgroundColor3 = "AccentText" } }, { CornerFixed(3) }),
})
local WatermarkImage = New("ImageLabel", {
	BackgroundTransparency = 1, Size = UDim2.fromOffset(18, 18), LayoutOrder = 1, Visible = false, Parent = Watermark,
})
local WatermarkLabel = New("TextLabel", {
	Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, RichText = true, LayoutOrder = 2,
	TextColor3 = Lumen.Theme.Text, Parent = Watermark,
})

local HotkeyFrame = New("Frame", {
	Position = UDim2.fromOffset(12, 56), Size = UDim2.fromOffset(170, 0), AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false, ZIndex = 5, Parent = Gui, Theme = { BackgroundColor3 = "Background" },
}, { Corner(9), Stroke(nil, true), Pad(14, 10, 16, 12), List(8) })
MakeDraggable(HotkeyFrame, HotkeyFrame, nil, "Hotkeys")
SnapHomes[HotkeyFrame] = HotkeyFrame.Position
local HotkeyTitle = New("Frame", {
	BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 0, Parent = HotkeyFrame,
}, { List(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
local HotkeyIcon = Icon("keyboard", HotkeyTitle, 17, "Label")
HotkeyIcon.LayoutOrder = 1
local HotkeyTitleLabel = New("TextLabel", {
	Text = "Hotkeys", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18),
	LayoutOrder = 2, Parent = HotkeyTitle,
})
local HotkeyDivider = New("Frame", { Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 1, Parent = HotkeyFrame })
local HotkeyList = New("Frame", {
	BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY,
	LayoutOrder = 2, Parent = HotkeyFrame,
}, { List(6) })

-- the panel is as wide as its longest entry (never wider than 420px)
local function FitHotkeys()
	local w = math.max(HotkeyList.AbsoluteSize.X, HotkeyTitle.AbsoluteSize.X) + 30
	HotkeyFrame.Size = UDim2.fromOffset(math.clamp(w, 150, 420), 0)
end
Connect(HotkeyList:GetPropertyChangedSignal("AbsoluteSize"), FitHotkeys)
Connect(HotkeyTitle:GetPropertyChangedSignal("AbsoluteSize"), FitHotkeys)

-- hotkey panel colours are the accent dimmed toward the background (as in the reference)
local function StyleHotkeys()
	local T = Lumen.Theme
	local c = T.Accent:Lerp(T.Background, 0.11)
	HotkeyTitleLabel.TextColor3 = c
	HotkeyDivider.BackgroundColor3 = T.Accent:Lerp(T.Background, 0.27)
	RecolorIcon(HotkeyIcon, c)
end
StyleHotkeys()
table.insert(Refreshers, StyleHotkeys)

function Lumen:_UpdateHotkeys()
	for _, c in ipairs(HotkeyList:GetChildren()) do
		if c:IsA("TextLabel") then c:Destroy() end
	end
	local n = 0
	for i = #Keybinds, 1, -1 do
		if not Keybinds[i].Chip:IsDescendantOf(Gui) then table.remove(Keybinds, i) end
	end
	for _, K in ipairs(Keybinds) do
		if (K.Value or K.Mode == "Always") and K.Mode ~= "Press" and not K.Hidden then
			n = n + 1
			local active = K:IsActive()
			New("TextLabel", {
				Size = UDim2.fromOffset(0, 15), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = n,
				TextXAlignment = Enum.TextXAlignment.Left, Parent = HotkeyList,
				Font = Enum.Font.GothamMedium, TextColor3 = self.Theme.Label:Lerp(self.Theme.Background, active and 0.08 or 0.12),
				Text = string.format("[%s] %s - %s", K.Value and KeyName(K.Value):upper() or "?", K.Name, active and "Active" or "Inactive"),
			})
		end
	end
	HotkeyFrame.Visible = self.ShowHotkeys and n > 0
end

function Lumen:SetHotkeysVisible(v)
	self.ShowHotkeys = v
	SyncOption("Lumen_Hotkeys", v)
	self:_UpdateHotkeys()
	self:_UpdateDock()
end

function Lumen:SetWatermarkVisible(v)
	self.ShowWatermark = v
	Watermark.Visible = v
	SyncOption("Lumen_Watermark", v)
	self:_UpdateDock()
end

function Lumen:SetWatermark(text)
	WatermarkOverride = text
end

function Lumen:SetWatermarkTitle(text)
	WatermarkTitle = text
end

-- custom logo for the watermark, e.g. "rbxassetid://123"; pass nil for the default logo
function Lumen:SetIcon(id)
	local has = id ~= nil and id ~= ""
	WatermarkImage.Image = has and id or ""
	WatermarkImage.Visible = has
	WatermarkLogo.Visible = not has
end

task.spawn(function()
	while not Lumen.Unloaded do
		local T = Lumen.Theme
		local ping = 0
		pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
		local function col(c, s) return string.format('<font color="#%s">%s</font>', c:ToHex(), s) end
		if WatermarkOverride then
			WatermarkLabel.Text = Esc(WatermarkOverride)
		else
			local title = WatermarkTitle or (Lumen.Windows[1] and Lumen.Windows[1].Title) or "Lumen"
			local sep = col(T.Label:Lerp(T.Background, 0.15), "|")
			WatermarkLabel.Text = string.format("%s  %s  %s  %s  %s  %s  %s",
				Esc(title), sep, Esc(Players.LocalPlayer.Name), sep,
				col(T.Warning, Fps .. " FPS"), sep, col(T.Success, ping .. "ms"))
		end
		task.wait(0.5)
	end
end)

Connect(RunService.RenderStepped, function(dt)
	Fps = math.floor(Fps * 0.9 + (1 / math.max(dt, 1e-4)) * 0.1 + 0.5)
end)

------------------------------------------------------------------------------
-- Color picker addon
------------------------------------------------------------------------------

local function MakeColorPicker(holder, o, owner)
	local C = NewOpt("ColorPicker", o)
	local default = o.Default or Color3.fromRGB(255, 255, 255)
	C.H, C.S, C.V = default:ToHSV()
	C.Value = default

	local swatch = New("TextButton", {
		Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 0, BackgroundColor3 = default, Parent = holder,
	}, { Corner(5), New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, {
		Corner(5), New("UIGradient", { Rotation = 35, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.97), NumberSequenceKeypoint.new(0.4, 0.88), NumberSequenceKeypoint.new(0.62, 0.97),
			NumberSequenceKeypoint.new(1, 0.9) }) }) }) })
	local glow = { SetColor = function() end }
	if o.Tooltip or o.Description then AttachHint(swatch, o.Title, o.Description or o.Tooltip) end

	local pop = New("Frame", {
		Visible = false, Size = UDim2.fromOffset(196, 172), Parent = Overlay, Theme = { BackgroundColor3 = "Group" },
	}, { Corner(6), Stroke("Border") })
	local inner = New("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16), Parent = pop,
	})

	local sv = New("Frame", {
		Size = UDim2.new(1, 0, 0, 108), BackgroundColor3 = Color3.fromHSV(C.H, 1, 1), ClipsDescendants = true, Parent = inner,
	}, { Corner(4) })
	New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = sv }, {
		New("UIGradient", { Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = sv }, {
		New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }),
	})
	local cursor = New("Frame", {
		Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = sv,
	}, { Corner(5), New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }) })

	local hue = New("Frame", {
		Position = UDim2.fromOffset(0, 116), Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = Color3.new(1, 1, 1), Parent = inner,
	}, { Corner(4), New("UIGradient", { Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
		ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)), ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
		ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)), ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)) }) }) })
	local hueCursor = New("Frame", {
		Size = UDim2.fromOffset(4, 16), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), Parent = hue,
	}, { Corner(2), New("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.5 }) })

	local hex = New("TextBox", {
		Position = UDim2.fromOffset(0, 136), Size = UDim2.new(1, 0, 0, 22), ClearTextOnFocus = false,
		Text = "", Parent = inner, Theme = { BackgroundColor3 = "Control" },
	}, { Corner(4), Stroke("Border") })

	local function Update(fire)
		C.Value = Color3.fromHSV(C.H, C.S, C.V)
		swatch.BackgroundColor3 = C.Value
		glow:SetColor(C.Value)
		sv.BackgroundColor3 = Color3.fromHSV(C.H, 1, 1)
		cursor.Position = UDim2.new(C.S, 0, 1 - C.V, 0)
		hueCursor.Position = UDim2.new(C.H, 0, 0.5, 0)
		hex.Text = "#" .. C.Value:ToHex():upper()
		if fire then Fire(C, C.Value) end
	end

	Dragger(sv, function(x, y)
		C.S = math.clamp((x - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
		C.V = 1 - math.clamp((y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
		Update(true)
	end)
	Dragger(hue, function(x)
		C.H = math.clamp((x - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 1)
		Update(true)
	end)
	Connect(hex.FocusLost, function()
		local ok, col = pcall(Color3.fromHex, (hex.Text:gsub("#", "")))
		if ok and col then
			C.H, C.S, C.V = col:ToHSV()
			Update(true)
		else
			Update(false)
		end
	end)
	Connect(swatch.MouseButton1Click, function()
		if OpenPopup and OpenPopup.Frame == pop then ClosePopup() else ShowPopup(pop, swatch) end
	end)

	function C:Set(col, silent)
		if typeof(col) == "table" then col = Color3.new(col[1], col[2], col[3]) end
		C.H, C.S, C.V = col:ToHSV()
		Update(not silent)
	end

	C.Row = nil
	Register(C, o.Flag)
	Update(false)
	return C
end

------------------------------------------------------------------------------
-- Keybind addon
------------------------------------------------------------------------------

local MODES = { "Toggle", "Hold" }

local function MakeKeybind(holder, o, owner)
	local K = NewOpt("Keybind", o)
	K.KeyListeners = {}
	K.Mode = o.Mode or "Toggle"
	K.Owner = (owner and owner.Type == "Toggle") and owner or nil
	K.Active = (K.Mode == "Always")
	K.Hidden = o.ShowInList == false
	K.Name = o.Name or (owner and owner._text) or "Keybind"
	local key = o.Default
	if type(key) == "string" then
		local ok, v = pcall(function() return Enum.KeyCode[key] end)
		key = ok and v or nil
	end
	K.Value = key

	local chip = New("TextButton", {
		Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0,
		TextSize = 11, TextColor3 = Lumen.Theme.ChipText, Text = KeyName(key), Parent = holder, LayoutOrder = 10,
		Font = Enum.Font.GothamMedium, Theme = { BackgroundColor3 = "Chip" },
	}, { Corner(6), Stroke("Outline"), Pad(10, 0, 10, 0), New("UISizeConstraint", { MinSize = Vector2.new(34, 0) }) })
	K.Chip = chip
	AttachTooltip(chip, K.Mode == "Press" and "Click to rebind" or "Click to rebind  -  Right-click to switch Toggle/Hold")

	function K:IsActive()
		if self.Owner then return self.Owner.Value end
		return self.Active
	end

	function K:_Render()
		chip.Text = KeyName(self.Value)
	end

	function K:SetKey(k, silent)
		if type(k) == "string" then
			local ok, v = pcall(function() return Enum.KeyCode[k] end)
			k = ok and v or nil
		end
		self.Value = k
		if self.Flag then Lumen.Flags[self.Flag] = k end
		self:_Render()
		if not silent then
			for _, fn in ipairs(self.KeyListeners) do task.spawn(fn, k) end
		end
		Lumen:_UpdateHotkeys()
	end
	K.Set = K.SetKey

	function K:SetMode(m)
		if m == "Toggle" or m == "Hold" or m == "Press" then self.Mode = m end
		Lumen:_UpdateHotkeys()
	end

	function K:OnKeyChanged(fn)
		table.insert(self.KeyListeners, fn)
		return self
	end

	function K:_Apply(state)
		if self.Owner then
			self.Owner:Set(state)
		else
			self.Active = state
			Fire(self, state)
		end
		Lumen:_UpdateHotkeys()
	end

	Connect(chip.MouseButton1Click, function()
		Lumen._binding = K
		chip.Text = "..."
	end)
	Connect(chip.MouseButton2Click, function()
		if K.Mode == "Press" or K.Mode == "Always" then return end
		K.Mode = (K.Mode == "Toggle") and "Hold" or "Toggle"
		Lumen:Notify({ Content = (K.Name or "Keybind") .. ": " .. K.Mode .. " mode", Duration = 2 })
		Lumen:_UpdateHotkeys()
	end)

	table.insert(Keybinds, K)
	Register(K, o.Flag)
	if o.ChangedCallback then K:OnKeyChanged(o.ChangedCallback) end
	if K.Owner then owner._kb = K end
	Lumen:_UpdateHotkeys()
	return K
end

function OptBase:AddColorPicker(o)
	assert(self._addons, "This element does not support addons")
	return MakeColorPicker(self._addons, o or {}, self)
end

function OptBase:AddKeybind(o)
	assert(self._addons, "This element does not support addons")
	return MakeKeybind(self._addons, o or {}, self)
end

function OptBase:AddTooltip(text)
	assert(self._addons, "This element does not support addons")
	local T = Lumen.Theme
	local chip = New("TextButton", {
		Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Text = "?", TextSize = 11,
		TextColor3 = T.Accent:Lerp(T.Background, 0.5), Parent = self._addons, LayoutOrder = 100,
	}, { CornerFixed(10), Stroke("Outline") })
	AttachTooltip(chip, text)
	return self
end

------------------------------------------------------------------------------
-- Elements
------------------------------------------------------------------------------

function Elements:AddLabel(text, o)
	if type(text) == "table" then o, text = text, text.Text end
	o = o or {}
	local L = NewOpt("Label", o)
	L._text = text
	local order = (self._container:GetAttribute("Order") or 0) + 1
	self._container:SetAttribute("Order", order)
	local row = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order, Parent = self._container,
	}, { New("UISizeConstraint", { MinSize = Vector2.new(0, o.Box and 30 or 18) }) })
	L.Row = row
	L._addons = MakeAddonHolder(row)
	local holder = row
	if o.Box then
		holder = New("Frame", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = row,
			BackgroundTransparency = 1,
		}, { Corner(6), Stroke("Outline"), Pad(10, 7, 10, 7) })
	end
	local lbl = New("TextLabel", {
		Text = text or "", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
		RichText = true, TextXAlignment = Enum.TextXAlignment.Left,
		Font = o.Bold and Enum.Font.GothamBold or Enum.Font.GothamSemibold,
		TextColor3 = o.Dim and Lumen.Theme.TextDim or Lumen.Theme.Label, Parent = holder,
	})
	function L:SetText(t) lbl.Text = t; self._text = t end
	function L:SetColor(c) lbl.TextColor3 = c end
	if o.Description then L:SetDescription(o.Description) end
	return L
end

function Elements:AddDivider()
	local row = Row(self._container, 9)
	New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 1),
		Parent = row, Theme = { BackgroundColor3 = "Outline" },
	})
	return { Row = row, SetVisible = OptBase.SetVisible }
end

function Elements:AddImage(o)
	o = o or {}
	local row = Row(self._container, o.Height or 120)
	local frame = New("Frame", {
		Size = UDim2.fromScale(1, 1), ClipsDescendants = true, Parent = row, Theme = { BackgroundColor3 = "Background" },
	}, { Corner(6), Stroke("Outline") })
	local img = New("ImageLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = o.Image or "",
		ScaleType = o.ScaleType or Enum.ScaleType.Fit, Parent = frame,
	})
	return { Row = row, Image = img, SetImage = function(_, i) img.Image = i end, SetVisible = OptBase.SetVisible }
end

function Elements:AddToggle(o)
	o = type(o) == "string" and { Text = o } or o or {}
	local T = NewOpt("Toggle", o)
	T.Value = o.Default == true
	T._text = o.Text or "Toggle"
	T._blockerAlpha = 1
	local row = Row(self._container, 20)
	T.Row = row
	T._addons = MakeAddonHolder(row)

	local btn = New("TextButton", { Size = UDim2.new(1, 0, 1, 0), Parent = row, ZIndex = 1 })
	local stroke = New("UIStroke", { Thickness = 1, Theme = { Color = "AccentBorder" } })
	local box = New("Frame", {
		Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 0, 0.5, -9), ZIndex = 2, Parent = row,
		Theme = { BackgroundColor3 = "Toggle" },
	}, { Corner(5), stroke })
	local glow = Glow(box, "Accent", 5)
	-- the "on" fill is an overlay that fades in, so themes with accent gradients paint it smoothly
	local onFill = AccentOverlay(box, 5, false, false)
	local boxScale = New("UIScale", { Parent = box })
	local lbl = New("TextLabel", {
		Text = T._text, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -26, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, Parent = row,
	})

	local function Colors()
		local TH = Lumen.Theme
		if T.Disabled then
			return TH.Toggle:Lerp(TH.Background, 0.55), TH.AccentBorder:Lerp(TH.Background, 0.7), TH.TextMuted
		end
		return TH.Toggle, TH.AccentBorder, o.Risky and TH.Error or TH.Label
	end
	local function Render(instant)
		local base, border, text = Colors()
		stroke.Color = border
		lbl.TextColor3 = text
		local onT = T.Value and (T.Disabled and 0.55 or 0) or 1
		if instant then
			box.BackgroundColor3 = base
			onFill.BackgroundTransparency = onT
		else
			Tween(box, 0.12, { BackgroundColor3 = base })
			TweenService:Create(onFill, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = onT }):Play()
		end
		glow:Set(T.Disabled and 0 or 1)
	end
	T._onDisabled = function() Render() end
	table.insert(Refreshers, function() Render(true) end)

	function T:Set(v, silent)
		v = v and true or false
		if self.Value == v then return end
		self.Value = v
		Render()
		-- a little squash-and-pop on the box
		boxScale.Scale = 0.82
		TweenService:Create(boxScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if not silent then Fire(self, v) end
		if self._kb then Lumen:_UpdateHotkeys() end
	end
	Connect(btn.MouseButton1Click, function() T:Set(not T.Value) end)
	Connect(btn.MouseEnter, function()
		if not T.Disabled then Tween(box, 0.1, { BackgroundColor3 = (Colors()):Lerp(Color3.new(1, 1, 1), 0.08) }) end
	end)
	Connect(btn.MouseLeave, function() Render() end)

	function T:SetText(t) self._text = t lbl.Text = t end
	Register(T, o.Flag)
	CatalogAdd(self, T, T._text)
	Render(true)
	if o.Disabled then T:SetDisabled(true) end
	if o.Tooltip then T:AddTooltip(o.Tooltip) end
	if o.Description then T:SetDescription(o.Description) end
	return T
end

function Elements:AddSlider(o)
	o = o or {}
	local S = NewOpt("Slider", o)
	S._text = o.Text or "Slider"
	S.Min, S.Max, S.Inc, S.Suffix = o.Min or 0, o.Max or 100, o.Increment or 1, o.Suffix or ""
	S.Value = math.clamp(o.Default or S.Min, S.Min, S.Max)
	local dec = #((tostring(S.Inc):match("%.(%d+)")) or "")
	local row = Row(self._container, 32)
	S.Row = row

	New("TextLabel", {
		Text = o.Text or "Slider", Size = UDim2.new(0.6, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
	})
	-- the value is a text box: click it to type an exact number
	local valueLabel = New("TextBox", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.4, 0, 0, 16), BackgroundTransparency = 1,
		ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Right, Text = "", ZIndex = 3, Parent = row,
	})
	local track = New("Frame", {
		Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 4), Parent = row, Theme = { BackgroundColor3 = "Group" },
	}, { Corner(3), Stroke("Outline") })
	local fill = New("Frame", {
		Size = UDim2.new(0, 0, 1, 0), Parent = track, Theme = { BackgroundColor3 = "Accent" },
	}, { Corner(3) })
	AccentOverlay(fill, 3)
	local knob = New("Frame", {
		Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = fill,
	}, { CornerFixed(4) })
	Glow(knob, Color3.new(1, 1, 1), 4, true):Set(0.2)
	local hit = New("TextButton", { Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 18), Parent = row })

	local dragging = false
	local function Render(animate)
		local a = (S.Value - S.Min) / math.max(S.Max - S.Min, 1e-9)
		if animate then
			TweenService:Create(fill, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(a, 0, 1, 0) }):Play()
		else
			fill.Size = UDim2.new(a, 0, 1, 0)
		end
		if not valueLabel:IsFocused() then valueLabel.Text = string.format("%." .. dec .. "f", S.Value) .. S.Suffix end
	end
	function S:Set(v, silent)
		v = tonumber(v)
		if not v then return end
		v = math.clamp(S.Min + math.floor((v - S.Min) / S.Inc + 0.5) * S.Inc, S.Min, S.Max)
		v = tonumber(string.format("%." .. dec .. "f", v))
		if v == S.Value then return end
		S.Value = v
		Render(not dragging)
		if not silent then Fire(S, v) end
	end
	function S:SetText(t) self._text = t end
	Connect(valueLabel.Focused, function()
		valueLabel.Text = string.format("%." .. dec .. "f", S.Value)
		Tween(valueLabel, 0.12, { TextColor3 = Lumen.Theme.AccentText })
	end)
	Connect(valueLabel.FocusLost, function()
		local n = tonumber((valueLabel.Text:gsub("[^%d%.%-]", "")))
		Tween(valueLabel, 0.12, { TextColor3 = Lumen.Theme.Label })
		if n then S:Set(n) end
		valueLabel.Text = string.format("%." .. dec .. "f", S.Value) .. S.Suffix
	end)
	Dragger(hit, function(x)
		dragging = true
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		S:Set(S.Min + a * (S.Max - S.Min))
	end)
	Connect(UIS.InputEnded, function(i) if IsPress(i) then dragging = false end end)
	Register(S, o.Flag)
	CatalogAdd(self, S, o.Text or "Slider")
	Render()
	if o.Disabled then S:SetDisabled(true) end
	if o.Description then S:SetDescription(o.Description) end
	return S
end

local function Chevron(parent)
	local f = New("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(9, 6), Parent = parent,
	})
	for _, r in ipairs({ 40, -40 }) do
		New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(r > 0 and 0.28 or 0.72, 0, 0.5, 0),
			Size = UDim2.fromOffset(6, 1.6), Rotation = r, Parent = f, Theme = { BackgroundColor3 = "Label" },
		}, { Corner(1) })
	end
	return f
end

function Elements:AddDropdown(o)
	o = o or {}
	local D = NewOpt("Dropdown", o)
	D._text = o.Text or "Dropdown"
	D.Values = o.Values or {}
	D.Multi = o.Multi == true
	D.Value = D.Multi and {} or nil
	local hasLabel = o.Text ~= nil
	local h = hasLabel and 48 or 28
	local row = Row(self._container, h)
	D.Row = row
	if hasLabel then
		New("TextLabel", { Text = o.Text, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	end
	local stroke = Stroke("Outline")
	local box = New("TextButton", {
		Position = UDim2.fromOffset(0, h - 28), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = row,
	}, { Corner(6), stroke })
	box.ClipsDescendants = true
	local valueText = New("TextLabel", {
		Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -30, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Font = Enum.Font.GothamMedium, Parent = box,
	})
	local chevron = Chevron(box)
	local isOpen = false
	Connect(box.MouseEnter, function() if not isOpen then Tween(stroke, 0.1, { Color = Lumen.Theme.Border }) end end)
	Connect(box.MouseLeave, function() if not isOpen then Tween(stroke, 0.1, { Color = Lumen.Theme.Outline }) end end)
	local function SetOpen(v)
		isOpen = v
		TweenService:Create(chevron, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = v and 180 or 0 }):Play()
		Tween(stroke, 0.15, { Color = v and Lumen.Theme.AccentBorder or Lumen.Theme.Outline })
	end

	local pop = New("Frame", {
		Visible = false, Size = UDim2.fromOffset(200, 100), Parent = Overlay, Theme = { BackgroundColor3 = "Background" },
	}, { Corner(7), Stroke("Border") })
	local scroll = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 2, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = pop, Theme = { ScrollBarImageColor3 = "Accent" },
	}, { Pad(4), List(2) })
	-- long lists get a search box at the top (or force it with Search = true)
	local search
	local function WantsSearch() return o.Search == true or (o.Search ~= false and #D.Values > 8) end
	search = New("TextBox", {
		Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 26), BackgroundTransparency = 1, Text = "",
		PlaceholderText = "Search...", PlaceholderColor3 = Lumen.Theme.TextMuted, ClearTextOnFocus = false, Visible = false,
		TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamMedium, Parent = pop,
	}, { Corner(5), Stroke("Outline"), Pad(8, 0, 8, 0) })

	local items, order = {}, {}
	local function IsSelected(v)
		if D.Multi then return D.Value[v] == true end
		return D.Value == v
	end
	local quick = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local pop2 = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	-- each row has three looks: resting, "about to pick" (hover / press) and picked
	local function PaintItem(it, instant)
		local T = Lumen.Theme
		local on = IsSelected(it.Value)
		local goals = {
			{ it.Sel, { BackgroundTransparency = on and 0 or 1 } },
			{ it.Hover, { BackgroundTransparency = (it.Hovered and not on) and 0 or 1 } },
			{ it.Bar, { Size = UDim2.fromOffset(2, on and 14 or (it.Hovered and 7 or 0)), BackgroundTransparency = on and 0 or (it.Hovered and 0.35 or 1) } },
			{ it.Label, { Position = UDim2.fromOffset(it.Hovered and 15 or 11, 0),
				TextColor3 = on and T.AccentText or (it.Hovered and T.Text or T.Label) } },
			{ it.CheckScale, { Scale = on and 1 or 0 } },
		}
		for _, g in ipairs(goals) do
			if instant then
				for k, val in pairs(g[2]) do g[1][k] = val end
			else
				TweenService:Create(g[1], (g[1] == it.CheckScale and on) and pop2 or quick, g[2]):Play()
			end
		end
	end
	local lastText
	local function Render(instant)
		local txt
		if D.Multi then
			local sel = {}
			for _, v in ipairs(D.Values) do if D.Value[v] then table.insert(sel, tostring(v)) end end
			txt = #sel > 0 and table.concat(sel, ", ") or "--"
		else
			txt = D.Value ~= nil and tostring(D.Value) or "--"
		end
		if txt ~= lastText then
			valueText.Text = txt
			-- the new value slides up into place
			if lastText ~= nil and not instant then
				valueText.Position = UDim2.fromOffset(10, 9)
				valueText.TextTransparency = 1
				TweenService:Create(valueText, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
					{ Position = UDim2.fromOffset(10, 0), TextTransparency = 0 }):Play()
			end
			lastText = txt
		end
		valueText.TextColor3 = (txt == "--") and Lumen.Theme.TextDim or Lumen.Theme.Label
		for _, it in pairs(items) do PaintItem(it, instant) end
	end
	table.insert(Refreshers, function() Render(true) end)
	local function PopupSize()
		local s2 = WantsSearch()
		search.Visible = s2
		scroll.Position = UDim2.fromOffset(0, s2 and 32 or 0)
		scroll.Size = UDim2.new(1, 0, 1, s2 and -32 or 0)
		pop.Size = UDim2.fromOffset(math.max(box.AbsoluteSize.X / Lumen.Scale, 120), math.min(#D.Values * 26 + 8, 184) + (s2 and 32 or 0))
	end
	local function Filter()
		local q = search.Text:lower()
		for v, it in pairs(items) do
			it.Button.Visible = q == "" or tostring(v):lower():find(q, 1, true) ~= nil
		end
	end
	Connect(search:GetPropertyChangedSignal("Text"), Filter)
	local function Build()
		for _, it in pairs(items) do it.Button:Destroy() end
		items, order = {}, {}
		for i, v in ipairs(D.Values) do
			local b = New("TextButton", { Size = UDim2.new(1, 0, 0, 24), LayoutOrder = i, Parent = scroll })
			local it = { Value = v, Button = b }
			it.Hover = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = b, Theme = { BackgroundColor3 = "ControlHover" } }, { Corner(5) })
			it.Sel = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = b, Theme = { BackgroundColor3 = "TabActive" } }, { Corner(5) })
			it.Bar = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(2, 0),
				BackgroundTransparency = 1, ZIndex = 3, Parent = b, Theme = { BackgroundColor3 = "Accent" } }, { CornerFixed(1) })
			it.Label = New("TextLabel", { Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -36, 1, 0), Text = tostring(v),
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = b })
			local check = Icon("check", b, 12, "AccentText")
			check.AnchorPoint = Vector2.new(0.5, 0.5)
			check.Position = UDim2.new(1, -13, 0.5, 0)
			check.ZIndex = 3
			it.CheckScale = New("UIScale", { Scale = 0, Parent = check })
			it.Press = New("UIScale", { Scale = 1, Parent = b })
			items[v] = it
			order[i] = it
			Connect(b.MouseEnter, function() it.Hovered = true PaintItem(it) end)
			Connect(b.MouseLeave, function()
				it.Hovered = false
				TweenService:Create(it.Press, quick, { Scale = 1 }):Play()
				PaintItem(it)
			end)
			-- pressing squeezes the row slightly: the "about to pick" moment
			Connect(b.MouseButton1Down, function() TweenService:Create(it.Press, TweenInfo.new(0.08), { Scale = 0.96 }):Play() end)
			Connect(b.MouseButton1Up, function() TweenService:Create(it.Press, pop2, { Scale = 1 }):Play() end)
			Connect(b.MouseButton1Click, function()
				-- a quick accent flash confirms the pick
				it.Sel.BackgroundColor3 = Lumen.Theme.Accent:Lerp(Lumen.Theme.Background, 0.55)
				it.Sel.BackgroundTransparency = 0
				TweenService:Create(it.Sel, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = Lumen.Theme.TabActive }):Play()
				if D.Multi then
					local nv = {}
					for k in pairs(D.Value) do nv[k] = true end
					nv[v] = (not nv[v]) or nil
					D:Set(nv)
				else
					D:Set(v)
					task.delay(0.14, function() if OpenPopup and OpenPopup.Frame == pop then ClosePopup() end end)
				end
			end)
		end
		PopupSize()
		Render(true)
	end
	-- rows cascade in when the list opens
	local function Cascade()
		local n = 0
		for _, it in ipairs(order) do
			if it.Button.Visible then
				n = n + 1
				it.Label.TextTransparency = 1
				it.Label.Position = UDim2.fromOffset(22, 0)
				local delay = math.min(n, 10) * 0.022
				task.delay(delay, function()
					if not it.Label.Parent then return end
					TweenService:Create(it.Label, TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
						{ TextTransparency = 0, Position = UDim2.fromOffset(it.Hovered and 15 or 11, 0) }):Play()
				end)
			end
		end
	end

	function D:Set(v, silent)
		if self.Multi then
			local nv = {}
			if type(v) == "table" then
				for k, val in pairs(v) do
					if type(k) == "number" then nv[val] = true elseif val then nv[k] = true end
				end
			end
			self.Value = nv
		else
			if type(v) == "number" and self.Values[v] ~= nil and not table.find(self.Values, v) then v = self.Values[v] end
			if v ~= nil and not table.find(self.Values, v) then v = nil end
			self.Value = v
		end
		Render()
		if not silent then Fire(self, self.Value) end
	end
	function D:SetValues(vals, keep)
		self.Values = vals or {}
		if not keep then self.Value = self.Multi and {} or nil end
		Build()
	end
	function D:Get() return self.Value end

	Connect(box.MouseButton1Click, function()
		if OpenPopup and OpenPopup.Frame == pop then
			ClosePopup()
		else
			PopupSize()
			search.Text = ""
			Filter()
			ShowPopup(pop, box, function() SetOpen(false) end)
			SetOpen(true)
			Cascade()
			if search.Visible then task.defer(function() pcall(function() search:CaptureFocus() end) end) end
		end
	end)

	Build()
	if o.Default ~= nil then D:Set(o.Default, true) end
	Register(D, o.Flag)
	CatalogAdd(self, D, o.Text or "Dropdown")
	Render(true)
	if o.Disabled then D:SetDisabled(true) end
	if o.Description then D:SetDescription(o.Description) end
	return D
end

function Elements:AddInput(o)
	o = type(o) == "string" and { Text = o } or o or {}
	local I = NewOpt("Input", o)
	I._text = o.Text or "Input"
	I.Value = tostring(o.Default or "")
	local h = o.Text and 48 or 28
	local row = Row(self._container, h)
	I.Row = row
	if o.Text then
		New("TextLabel", { Text = o.Text, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	end
	local stroke = Stroke("Outline")
	local box = New("TextBox", {
		Position = UDim2.fromOffset(0, h - 28), Size = UDim2.new(1, 0, 0, 28), Text = I.Value, BackgroundTransparency = 1,
		PlaceholderText = o.Placeholder or "", PlaceholderColor3 = Lumen.Theme.TextDim, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, ClipsDescendants = true, Font = Enum.Font.GothamMedium, Parent = row,
	}, { Corner(6), stroke, Pad(11, 0, 11, 0) })

	if o.Dynamic then
		o.Realtime = true
		box.MultiLine = true
		box.TextWrapped = true
		box.TextYAlignment = Enum.TextYAlignment.Top
	end
	local function Resize()
		if not o.Dynamic then return end
		local bh = math.clamp(box.TextBounds.Y + 14, 28, 130)
		box.Size = UDim2.new(1, 0, 0, bh)
		row.Size = UDim2.new(1, 0, 0, (o.Text and 20 or 0) + bh)
	end
	Connect(box:GetPropertyChangedSignal("TextBounds"), Resize)
	Connect(box.Focused, function() Tween(stroke, 0.1, { Color = Lumen.Theme.AccentBorder }) end)
	Connect(box.FocusLost, function()
		Tween(stroke, 0.1, { Color = Lumen.Theme.Outline })
		if not o.Realtime then Fire(I, I.Value) end
	end)
	Connect(box:GetPropertyChangedSignal("Text"), function()
		if o.Dynamic and box.Text:find("\n") then
			box.Text = box.Text:gsub("\n", "")
			box:ReleaseFocus(true)
			return
		end
		if o.Numeric then
			local f = box.Text:gsub("[^%d%.%-]", "")
			if f ~= box.Text then box.Text = f return end
		end
		if o.MaxLength and #box.Text > o.MaxLength then box.Text = box.Text:sub(1, o.MaxLength) return end
		I.Value = box.Text
		if o.Realtime then Fire(I, I.Value) end
	end)
	function I:Set(v, silent)
		v = tostring(v or "")
		self.Value = v
		box.Text = v
		if not silent then Fire(self, v) end
	end
	I.Box = box
	Register(I, o.Flag)
	CatalogAdd(self, I, o.Text or "Input")
	if o.Disabled then I:SetDisabled(true) end
	if o.Description then I:SetDescription(o.Description) end
	return I
end

function Elements:AddButton(o)
	o = type(o) == "string" and { Text = o } or o or {}
	local B = NewOpt("Button", {})
	B._text = o.Text or "Button"
	local row = Row(self._container, 28)
	B.Row = row
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center, Parent = row,
	})
	local buttons = {}
	local function Layout()
		local n = #buttons
		for _, b in ipairs(buttons) do
			b.Size = UDim2.new(1 / n, -(5 * (n - 1)) / n, 0, 30)
		end
	end
	local function Make(opts)
		local b = New("TextButton", {
			BackgroundTransparency = 0, Text = opts.Text or "Button", Font = Enum.Font.GothamBold,
			LayoutOrder = #buttons + 1, Parent = row, Theme = { BackgroundColor3 = "Control" },
		}, { Corner(6), Stroke("Outline") })
		-- soft glow along the inner bottom edge, peaking ~77% down and easing off at the border (measured from the reference)
		New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = b }, {
			Corner(6), New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(0.68, 0.975),
				NumberSequenceKeypoint.new(0.77, 0.952), NumberSequenceKeypoint.new(0.9, 0.958), NumberSequenceKeypoint.new(1, 0.985) }) }),
		})
		table.insert(buttons, b)
		Layout()
		if opts.Tooltip or opts.Description then AttachHint(b, opts.Text, opts.Description or opts.Tooltip) end
		local confirming = false
		local original = b.Text
		Connect(b.MouseEnter, function() Tween(b, 0.1, { BackgroundColor3 = Lumen.Theme.ControlHover }) end)
		Connect(b.MouseLeave, function() Tween(b, 0.1, { BackgroundColor3 = Lumen.Theme.Control }) end)
		local function Press()
			if opts.Confirm then
				local c = {}
				for k, v in pairs(opts.Confirm) do c[k] = v end
				c.Callback = function(ok) if ok and opts.Callback then SafeCall("Button '" .. tostring(opts.Text or "Button") .. "'", opts.Callback) end end
				Lumen:Confirm(c)
				return
			end
			if opts.DoubleClick and not confirming then
				confirming = true
				b.Text = "Click again to confirm"
				b.TextColor3 = Lumen.Theme.Warning
				task.delay(2.5, function()
					if confirming then
						confirming = false
						b.Text = original
						b.TextColor3 = Lumen.Theme.Label
					end
				end)
				return
			end
			if confirming then
				confirming = false
				b.Text = original
				b.TextColor3 = Lumen.Theme.Label
			end
			b.BackgroundColor3 = Lumen.Theme.TabActive
			Tween(b, 0.25, { BackgroundColor3 = Lumen.Theme.ControlHover })
			-- press ripple
			local rip = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6),
				BackgroundColor3 = Lumen.Theme.Accent, BackgroundTransparency = 0.7, ZIndex = b.ZIndex, Parent = b,
			}, { CornerFixed(999) })
			b.ClipsDescendants = true
			TweenService:Create(rip, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.fromOffset(b.AbsoluteSize.X * 1.3, b.AbsoluteSize.X * 1.3), BackgroundTransparency = 1 }):Play()
			task.delay(0.5, function() rip:Destroy() end)
			if opts.Callback then SafeCall("Button '" .. tostring(opts.Text or "Button") .. "'", opts.Callback) end
		end
		Connect(b.MouseButton1Click, Press)
		return b, Press
	end
	local first, press = Make(o)
	B.Button = first
	B.Press = press
	function B:AddSubButton(o2)
		if type(o2) == "string" then o2 = { Text = o2 } end
		Make(o2 or {})
		return self
	end
	function B:SetText(t) buttons[1].Text = t end
	CatalogAdd(self, B, o.Text or "Button")
	if o.Disabled then B:SetDisabled(true) end
	return B
end

-- A titled block of wrapping text. Returns { SetTitle, SetContent }.
function Elements:AddParagraph(o)
	if type(o) == "string" then o = { Content = o } end
	o = o or {}
	local order = (self._container:GetAttribute("Order") or 0) + 1
	self._container:SetAttribute("Order", order)
	local card = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order,
		Parent = self._container,
	}, { Corner(6), Stroke("Outline"), Pad(10, 8, 10, 9), List(3) })
	local title = New("TextLabel", {
		Text = o.Title or "", Visible = o.Title ~= nil, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Lumen.Theme.Text, LayoutOrder = 1, Parent = card,
	})
	local body = New("TextLabel", {
		Text = o.Content or "", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, RichText = true,
		TextSize = 11, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Lumen.Theme.TextDim,
		LayoutOrder = 2, Parent = card,
	})
	return {
		Row = card,
		SetTitle = function(_, t) title.Text = t or "" title.Visible = t ~= nil end,
		SetContent = function(_, t) body.Text = t or "" end,
		SetVisible = function(_, v) card.Visible = v end,
		Destroy = function() card:Destroy() end,
	}
end

-- Animated progress bar. Options: Text, Default, Max (default 100), Suffix ("%" by default shows a percentage),
-- Color (fixed colour instead of the accent). Methods: :Set(value), :SetText(text), :Increment(by).
local ProgressBars = {}
function Elements:AddProgress(o)
	o = o or {}
	local Pg = NewOpt("Progress", o)
	Pg._text = o.Text or "Progress"
	Pg.Max = o.Max or 100
	Pg.Value = math.clamp(o.Default or 0, 0, Pg.Max)
	local hasText = o.Text ~= nil
	local row = Row(self._container, hasText and 34 or 12)
	Pg.Row = row
	local label = hasText and New("TextLabel", {
		Text = o.Text, Size = UDim2.new(0.65, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
	})
	local valueLabel = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.35, 0, 0, 16), Visible = hasText,
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Lumen.Theme.TextDim, Font = Enum.Font.GothamMedium, Parent = row,
	})
	local track = New("Frame", {
		Position = UDim2.fromOffset(0, hasText and 22 or 2), Size = UDim2.new(1, 0, 0, 8), ClipsDescendants = true, Parent = row,
		Theme = { BackgroundColor3 = "Group" },
	}, { Corner(4), Stroke("Outline") })
	local fill = New("Frame", { Size = UDim2.new(0, 0, 1, 0), Parent = track, Theme = { BackgroundColor3 = "Accent" } }, { Corner(4) })
	local ov = AccentOverlay(fill, 4)
	if o.Color then ov.BackgroundColor3 = o.Color ov:FindFirstChildOfClass("UIGradient").Enabled = false end
	-- a soft highlight that sweeps along the filled part
	local sheen = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = fill.ZIndex + 1, Parent = fill }, { Corner(4) })
	local sheenGrad = New("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.75),
		NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1) }), Parent = sheen })
	table.insert(ProgressBars, { Grad = sheenGrad, Row = row })
	local function Text()
		if o.Suffix then return string.format("%d", math.floor(Pg.Value + 0.5)) .. o.Suffix end
		return string.format("%d%%", math.floor(Pg.Value / Pg.Max * 100 + 0.5))
	end
	function Pg:Set(v, silent)
		v = math.clamp(tonumber(v) or 0, 0, self.Max)
		local was = self.Value
		self.Value = v
		TweenService:Create(fill, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(v / self.Max, 0, 1, 0) }):Play()
		valueLabel.Text = Text()
		if v >= self.Max and was < self.Max then
			-- finished: a brief brighten
			sheen.BackgroundTransparency = 0.55
			TweenService:Create(sheen, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0 }):Play()
			task.delay(0.6, function() sheen.BackgroundTransparency = 0 end)
		end
		if not silent then Fire(self, v) end
	end
	function Pg:Increment(by) self:Set(self.Value + (by or 1)) end
	function Pg:SetText(t) self._text = t if label then label.Text = t end end
	function Pg:SetMax(m) self.Max = math.max(m, 1e-9) self:Set(self.Value, true) end
	fill.Size = UDim2.new(Pg.Value / Pg.Max, 0, 1, 0)
	valueLabel.Text = Text()
	if o.Description then Pg:SetDescription(o.Description) end
	return Pg
end
Connect(RunService.RenderStepped, function()
	local t = os.clock()
	for i = #ProgressBars, 1, -1 do
		local p = ProgressBars[i]
		if not p.Row.Parent then table.remove(ProgressBars, i) else p.Grad.Offset = Vector2.new(((t * 0.6) % 2) - 1, 0) end
	end
end)

-- Dropdown that lists the players in the server and keeps itself up to date as people join and leave.
-- Options: everything AddDropdown takes, plus IncludeLocal (default false). :GetPlayer() returns the Player (or a list when Multi).
function Elements:AddPlayerDropdown(o)
	o = o or {}
	local function Names()
		local t = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if o.IncludeLocal or p ~= Players.LocalPlayer then table.insert(t, p.Name) end
		end
		table.sort(t, function(a, b) return a:lower() < b:lower() end)
		return t
	end
	o.Values = Names()
	o.Text = o.Text or "Player"
	local D = self:AddDropdown(o)
	local function Refresh() if D.Row and D.Row.Parent then D:SetValues(Names(), true) end end
	Connect(Players.PlayerAdded, Refresh)
	Connect(Players.PlayerRemoving, function() task.defer(Refresh) end)
	function D:GetPlayer()
		if self.Multi then
			local out = {}
			for n in pairs(self.Value) do local p = Players:FindFirstChild(n) if p then table.insert(out, p) end end
			return out
		end
		return self.Value and Players:FindFirstChild(self.Value) or nil
	end
	return D
end

-- 3D preview. Options: Height, Object (Model/BasePart to display), Character (use your avatar), Rotate (auto-rotate, default true),
-- Color (background). Drag with the mouse to orbit in any direction; it eases back into auto-rotation when released. Wheel zooms.
function Elements:AddViewport(o)
	o = o or {}
	local V = NewOpt("Viewport", o)
	local row = Row(self._container, o.Height or 150)
	V.Row = row
	local vf = New("ViewportFrame", {
		Size = UDim2.fromScale(1, 1), ClipsDescendants = true, Parent = row, Theme = { BackgroundColor3 = "Background" },
	}, { Corner(6), Stroke("Outline") })
	if o.Color then vf.BackgroundColor3 = o.Color end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 45
	cam.Parent = vf
	vf.CurrentCamera = cam

	local model, center, dist = nil, Vector3.new(0, 0, 0), 8
	local yaw, pitch, zoom = 0.6, 0.12, 1
	local dragging, lastMouse = false, nil
	local bbCF, bbSize

	-- ESP overlay: a box (corner brackets or full), name, health bar and distance that track the model as it turns
	local esp
	if o.ESP then
		local E = type(o.ESP) == "table" and o.ESP or {}
		local col = E.Color or Color3.new(1, 1, 1)
		esp = { E = E }
		esp.Root = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = row })
		esp.Box = New("Frame", { BackgroundTransparency = 1, ZIndex = 3, Parent = esp.Root })
		if (E.Box or "Full") == "Full" then
			esp.BoxStroke = New("UIStroke", { Color = col, Thickness = 1, Parent = esp.Box })
			New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 2, 1, 2), Position = UDim2.fromOffset(-1, -1), ZIndex = 3, Parent = esp.Box },
				{ New("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.55, Thickness = 1 }) })
		else
			esp.Corners = {}
			for i = 1, 8 do
				esp.Corners[i] = New("Frame", { BackgroundColor3 = col, ZIndex = 4, Parent = esp.Box },
					{ New("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.6, Thickness = 1 }) })
			end
		end
		if E.Name then
			local name = E.Name == true and (Players.LocalPlayer and (Players.LocalPlayer.DisplayName or Players.LocalPlayer.Name) or "Player") or tostring(E.Name)
			esp.Name = New("TextLabel", {
				Text = name, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(160, 14), TextSize = 11, TextColor3 = col,
				TextStrokeTransparency = 0.6, ZIndex = 4, Parent = esp.Root,
			})
		end
		if E.Health then
			esp.HealthBack = New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, ZIndex = 4, Parent = esp.Root })
			esp.HealthFill = New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), ZIndex = 5, Parent = esp.HealthBack })
		end
		if E.Distance then
			esp.Dist = New("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(120, 14), TextSize = 10, TextColor3 = col, Font = Enum.Font.GothamMedium,
				TextStrokeTransparency = 0.6, ZIndex = 4, Parent = esp.Root,
			})
		end
	end

	local function UpdateESP()
		if not esp or not bbCF then return end
		local sz = row.AbsoluteSize / Lumen.Scale
		if sz.X < 2 or sz.Y < 2 then return end
		local tanf = math.tan(math.rad(cam.FieldOfView / 2))
		local aspect = sz.X / sz.Y
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		local hx, hy, hz = bbSize.X / 2, bbSize.Y / 2, bbSize.Z / 2
		for _, c in ipairs({ { 1, 1, 1 }, { 1, 1, -1 }, { 1, -1, 1 }, { 1, -1, -1 }, { -1, 1, 1 }, { -1, 1, -1 }, { -1, -1, 1 }, { -1, -1, -1 } }) do
			local p = bbCF * Vector3.new(c[1] * hx, c[2] * hy, c[3] * hz)
			local lp = cam.CFrame:PointToObjectSpace(p)
			if lp.Z < -0.05 then
				local x = (lp.X / (-lp.Z * tanf * aspect) + 1) / 2 * sz.X
				local y = (1 - lp.Y / (-lp.Z * tanf)) / 2 * sz.Y
				minX, minY = math.min(minX, x), math.min(minY, y)
				maxX, maxY = math.max(maxX, x), math.max(maxY, y)
			end
		end
		if minX == math.huge then esp.Root.Visible = false return end
		esp.Root.Visible = true
		minX, minY = math.floor(math.max(minX, 4)), math.floor(math.max(minY, 16))
		maxX, maxY = math.floor(math.min(maxX, sz.X - 4)), math.floor(math.min(maxY, sz.Y - 16))
		local w, h = math.max(maxX - minX, 4), math.max(maxY - minY, 4)
		esp.Box.Position = UDim2.fromOffset(minX, minY)
		esp.Box.Size = UDim2.fromOffset(w, h)
		if esp.Corners then
			local lw, lh = math.floor(w * 0.25), math.floor(h * 0.2)
			local spec = {
				{ 0, 0, lw, 1 }, { 0, 0, 1, lh }, { w - lw, 0, lw, 1 }, { w - 1, 0, 1, lh },
				{ 0, h - 1, lw, 1 }, { 0, h - lh, 1, lh }, { w - lw, h - 1, lw, 1 }, { w - 1, h - lh, 1, lh },
			}
			for i, c in ipairs(spec) do
				esp.Corners[i].Position = UDim2.fromOffset(c[1], c[2])
				esp.Corners[i].Size = UDim2.fromOffset(c[3], c[4])
			end
		end
		if esp.Name then esp.Name.Position = UDim2.fromOffset(minX + w / 2, minY - 3) end
		if esp.HealthBack then
			local hp = math.clamp(tonumber(esp.E.Health) or 1, 0, 1)
			esp.HealthBack.Position = UDim2.fromOffset(minX - 6, minY)
			esp.HealthBack.Size = UDim2.fromOffset(3, h)
			esp.HealthFill.Size = UDim2.new(1, 0, hp, 0)
			esp.HealthFill.BackgroundColor3 = Color3.fromRGB(220, 80, 80):Lerp(Color3.fromRGB(90, 220, 120), hp)
		end
		if esp.Dist then
			esp.Dist.Position = UDim2.fromOffset(minX + w / 2, maxY + 3)
			esp.Dist.Text = esp.E.DistanceText or (math.floor(dist * zoom + 0.5) .. " studs")
		end
	end

	local function Place()
		if not model then return end
		local d = dist * zoom
		local cp = math.cos(pitch)
		cam.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(yaw) * cp * d, math.sin(pitch) * d, math.cos(yaw) * cp * d), center)
		UpdateESP()
	end
	local function Prepare(obj)
		if model then model:Destroy() model = nil end
		if not obj then
			obj = Instance.new("Part")
			obj.Size = Vector3.new(4, 1.6, 2)
			obj.Color = Color3.fromRGB(165, 165, 170)
			obj.Material = Enum.Material.SmoothPlastic
		end
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("BasePart") then d.Anchored = true
			elseif d:IsA("LuaSourceContainer") then d:Destroy() end
		end
		if obj:IsA("BasePart") then obj.Anchored = true end
		obj.Parent = vf
		model = obj
		local cf, sz
		if obj:IsA("Model") then cf, sz = obj:GetBoundingBox() else cf, sz = obj.CFrame, obj.Size end
		bbCF, bbSize = cf, sz
		center = cf.Position
		dist = math.max(sz.X, sz.Y, sz.Z) * 0.5 / math.tan(math.rad(cam.FieldOfView / 2)) * 1.25 + sz.Z * 0.5
		Place()
	end
	-- Highlight preview. Roblox Highlights don't render inside ViewportFrames, so the effect is rebuilt from layers:
	-- four flat silhouette copies nudged a couple of pixels up/down/left/right make the outline, the real model is drawn
	-- over them, and one more silhouette on top at FillTransparency makes the fill. Every layer fades in and out.
	local hl = { Enabled = false, Fill = Color3.fromRGB(255, 70, 110), FillTransparency = 0.55,
		Outline = Color3.new(1, 1, 1), OutlineTransparency = 0, Thickness = 2 }
	local layers = nil
	local HlToken = 0
	local WHITE = Color3.new(1, 1, 1)
	local function Silhouette(src)
		local c = src:Clone()
		local list = c:GetDescendants()
		table.insert(list, c)
		for _, d in ipairs(list) do
			if d:IsA("BasePart") then
				d.Color = WHITE
				d.Material = Enum.Material.SmoothPlastic
				pcall(function() d.TextureID = "" end)
			elseif d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance") or d:IsA("Clothing") or d:IsA("ShirtGraphic") then
				d:Destroy()
			elseif d:IsA("SpecialMesh") then
				pcall(function() d.TextureId = "" end)
			end
		end
		return c
	end
	local function Layer(z, dx, dy, flat)
		local l = New("ViewportFrame", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(dx, dy), ImageTransparency = 1,
			ZIndex = vf.ZIndex + z, Parent = vf,
		})
		l.CurrentCamera = cam
		if flat then
			-- full ambient, no directional light: the copy renders as one flat colour, tinted by ImageColor3
			l.Ambient = WHITE
			l.LightColor = Color3.new(0, 0, 0)
		else
			l.Ambient, l.LightColor = vf.Ambient, vf.LightColor
			pcall(function() l.LightDirection = vf.LightDirection end)
		end
		return l
	end
	local OFFSETS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
	local function DestroyLayers()
		if not layers then return end
		if model and model.Parent == layers.Top then model.Parent = vf end
		for _, l in ipairs(layers.Outlines) do l:Destroy() end
		layers.Top:Destroy()
		layers.Fill:Destroy()
		layers = nil
	end
	local function BuildLayers()
		if layers or not model then return end
		layers = { Outlines = {} }
		for i, off in ipairs(OFFSETS) do
			local l = Layer(1, off[1] * hl.Thickness, off[2] * hl.Thickness, true)
			Silhouette(model).Parent = l
			layers.Outlines[i] = l
		end
		layers.Top = Layer(2, 0, 0, false)
		layers.Top.ImageTransparency = 0
		model.Parent = layers.Top
		layers.Fill = Layer(3, 0, 0, true)
		Silhouette(model).Parent = layers.Fill
	end
	local function ApplyHighlight(instant)
		HlToken = HlToken + 1
		local mine = HlToken
		local info = TweenInfo.new(instant and 0.01 or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if hl.Enabled and model then
			BuildLayers()
			for i, l in ipairs(layers.Outlines) do
				local off = OFFSETS[i]
				TweenService:Create(l, info, {
					ImageColor3 = hl.Outline, ImageTransparency = hl.OutlineTransparency,
					Position = UDim2.fromOffset(off[1] * hl.Thickness, off[2] * hl.Thickness),
				}):Play()
			end
			TweenService:Create(layers.Fill, info, { ImageColor3 = hl.Fill, ImageTransparency = hl.FillTransparency }):Play()
		elseif layers then
			for _, l in ipairs(layers.Outlines) do TweenService:Create(l, info, { ImageTransparency = 1 }):Play() end
			TweenService:Create(layers.Fill, info, { ImageTransparency = 1 }):Play()
			task.delay(instant and 0 or 0.36, function()
				if mine == HlToken and not hl.Enabled then DestroyLayers() end
			end)
		end
	end

	local function CharacterClone()
		local ch = Players.LocalPlayer and Players.LocalPlayer.Character
		if not ch then return nil end
		local ok, c = pcall(function() ch.Archivable = true return ch:Clone() end)
		return ok and c or nil
	end
	Prepare(o.Object or (o.Character and CharacterClone()) or nil)
	if o.Highlight then
		if type(o.Highlight) == "table" then for k, v in pairs(o.Highlight) do hl[k] = v end end
		if type(o.Highlight) ~= "table" or o.Highlight.Enabled == nil then hl.Enabled = true end
		ApplyHighlight(true)
	end

	local function BeginDrag(i)
		if IsPress(i) then
			dragging = true
			lastMouse = UIS:GetMouseLocation()
		end
	end
	Connect(vf.InputBegan, BeginDrag)
	if esp then Connect(esp.Root.InputBegan, BeginDrag) end
	Connect(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local m = UIS:GetMouseLocation()
			local d = m - lastMouse
			lastMouse = m
			yaw = yaw - d.X * 0.012
			pitch = math.clamp(pitch + d.Y * 0.012, -1.3, 1.3)
			Place()
		end
	end)
	Connect(UIS.InputEnded, function(i)
		if IsPress(i) then dragging = false end
	end)
	Connect(vf.InputChanged, function(i)
		if i.UserInputType == Enum.UserInputType.MouseWheel then
			zoom = math.clamp(zoom - i.Position.Z * 0.08, 0.45, 1.8)
			Place()
		end
	end)
	Connect(RunService.RenderStepped, function(dt)
		if not model or dragging or not vf:IsDescendantOf(Gui) then return end
		if o.Rotate ~= false then yaw = yaw + dt * 0.9 end
		pitch = pitch + (0.12 - pitch) * math.min(1, dt * 3)   -- ease back to the default tilt
		Place()
	end)

	function V:SetObject(obj)
		DestroyLayers()
		Prepare(obj)
		if hl.Enabled then ApplyHighlight(true) end
	end
	-- viewport:SetHighlight({Enabled = true, Fill = Color3, FillTransparency = 0-1, Outline = Color3, OutlineTransparency = 0-1, Thickness = px})
	function V:SetHighlight(t)
		for k, v in pairs(t or {}) do hl[k] = v end
		ApplyHighlight(false)
	end
	-- live-update the ESP preview: V:SetESP({Health = 0.4, Name = "Enemy", DistanceText = "42m"})
	function V:SetESP(t)
		if not esp then return end
		for k, v in pairs(t or {}) do esp.E[k] = v end
		if esp.Name and t and t.Name then esp.Name.Text = tostring(t.Name) end
		if t and typeof(t.Color) == "Color3" then
			-- recolour the box, name and distance smoothly
			local c, ti = t.Color, 0.25
			if esp.BoxStroke then Tween(esp.BoxStroke, ti, { Color = c }) end
			for _, f in ipairs(esp.Corners or {}) do Tween(f, ti, { BackgroundColor3 = c }) end
			if esp.Name then Tween(esp.Name, ti, { TextColor3 = c }) end
			if esp.Dist then Tween(esp.Dist, ti, { TextColor3 = c }) end
		end
		UpdateESP()
	end
	V.Viewport = vf
	return V
end

-- Selectable image grid. Options: Items = {{Image, Name}}, Columns, CellHeight, Callback(item, index)
function Elements:AddImageGrid(o)
	o = o or {}
	local G = NewOpt("ImageGrid", o)
	G.Items = o.Items or {}
	G.Value = nil
	local cols, gap = o.Columns or 4, 6
	local order = (self._container:GetAttribute("Order") or 0) + 1
	self._container:SetAttribute("Order", order)
	local grid = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order, Parent = self._container,
	}, { New("UIGridLayout", {
		CellSize = UDim2.new(1 / cols, -(gap * (cols - 1)) / cols, 0, o.CellHeight or 64),
		CellPadding = UDim2.fromOffset(gap, gap), SortOrder = Enum.SortOrder.LayoutOrder,
	}) })
	G.Row = grid
	local cells = {}
	local function Render()
		for i, c in ipairs(cells) do
			local on = (G.Value == i)
			c.Stroke.Color = on and Lumen.Theme.AccentBorder or Lumen.Theme.Outline
			c.Stroke.Thickness = on and 1.5 or 1
		end
	end
	table.insert(Refreshers, Render)
	local function Build()
		for _, c in ipairs(cells) do c.Button:Destroy() end
		cells = {}
		for i, item in ipairs(G.Items) do
			local stroke = Stroke("Outline")
			local b = New("TextButton", {
				BackgroundTransparency = 0, LayoutOrder = i, Parent = grid, Theme = { BackgroundColor3 = "Background" },
			}, { Corner(6), stroke })
			New("ImageLabel", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4),
				Size = UDim2.new(1, -8, 1, item.Name and -22 or -8), Image = item.Image or "",
				ScaleType = Enum.ScaleType.Fit, Parent = b,
			})
			if item.Name then
				New("TextLabel", {
					AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 14),
					Text = item.Name, TextSize = 10, TextColor3 = Lumen.Theme.TextDim, Parent = b,
				})
			end
			table.insert(cells, { Button = b, Stroke = stroke })
			Connect(b.MouseButton1Click, function() G:Set(i) end)
		end
		Render()
	end
	function G:Set(i, silent)
		self.Value = i
		Render()
		if not silent and i and self.Items[i] then Fire(self, self.Items[i], i) end
	end
	function G:SetItems(items)
		self.Items = items or {}
		self.Value = nil
		Build()
	end
	Register(G, o.Flag)
	Build()
	return G
end

------------------------------------------------------------------------------
-- Groups, pills, panels
------------------------------------------------------------------------------

local function NewGroupObject(container, frame, path, tab)
	local g = setmetatable({ _container = container, Frame = frame, _path = path, _tab = tab }, { __index = Elements })
	function g:SetVisible(v)
		frame.Visible = v
		if tab and tab._Relayout then tab._Relayout() end
	end
	return g
end

local function SubTabButton(parent, text, order)
	return New("TextButton", {
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), BackgroundTransparency = 1,
		Text = text, TextColor3 = Lumen.Theme.Label, LayoutOrder = order, Parent = parent,
		Theme = { BackgroundColor3 = "TabActive" },
	}, { Corner(6), Pad(9, 0, 9, 0) })
end

-- Measured from the reference: fill = colour 80% toward the background, border = 50%, text = the colour.
local function Pill(parent, text, color, order, height, textSize, bg)
	bg = bg or Lumen.Theme.Background
	return New("TextLabel", {
		Text = text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, height or 21), TextSize = textSize or 12,
		TextColor3 = color, BackgroundTransparency = 0, BackgroundColor3 = color:Lerp(bg, 0.78),
		LayoutOrder = order or 0, Parent = parent,
	}, { Corner(11), Pad(11, 0, 11, 0), New("UIStroke", { Color = color:Lerp(bg, 0.45), Thickness = 1 }) })
end

-- Free-floating draggable panel. Options: Title, Subtitle, Width, Height (0 = grows with content), Position,
-- HeaderIcon = {Icon, Tooltip, Callback}, Dock = {Icon, Tooltip, Order} (adds a dock button that shows/hides it)
function Lumen:CreatePanel(o)
	o = o or {}
	local P = setmetatable({}, { __index = Elements })
	P._path = o.Title or "Panel"
	local autoH = (o.Height or 0) == 0
	local frame = New("Frame", {
		Position = o.Position or UDim2.new(0.5, -(o.Width or 300) / 2, 0.5, -100),
		Size = UDim2.fromOffset(o.Width or 300, o.Height or 0),
		AutomaticSize = autoH and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		Parent = Gui, Theme = { BackgroundColor3 = "Background" },
	}, { Corner(10), Stroke(nil, true), Pad(18, 16, 18, 18), List(12) })
	local header = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 0, Parent = frame,
	}, { List(3) })
	local titleRow = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, Parent = header })
	New("TextLabel", {
		Text = o.Title or "Panel", Size = UDim2.new(1, -30, 1, 0), TextSize = 13, TextColor3 = Lumen.Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = titleRow,
	})
	if o.HeaderIcon then
		local hb = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(22, 22), Parent = titleRow,
		})
		local ic = Icon(o.HeaderIcon.Icon or "gear", hb, 18, "TextDim")
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.5)
		if o.HeaderIcon.Tooltip then AttachTooltip(hb, o.HeaderIcon.Tooltip) end
		Connect(hb.MouseEnter, function() RecolorIcon(ic, Lumen.Theme.Label) end)
		Connect(hb.MouseLeave, function() RecolorIcon(ic, Lumen.Theme.TextDim) end)
		Connect(hb.MouseButton1Click, function()
			if o.HeaderIcon.Callback then task.spawn(o.HeaderIcon.Callback) end
		end)
	end
	if o.Subtitle then
		New("TextLabel", {
			Text = o.Subtitle, Size = UDim2.new(1, 0, 0, 15), TextSize = 11, TextColor3 = Lumen.Theme.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, Parent = header,
		})
	end
	local content = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1, Parent = frame,
	}, { List(6) })
	P._container, P.Frame = content, frame
	RegisterScale(frame)
	RegisterSurface(frame, "Panel", 10)

	local function Front()
		ZCounter = ZCounter + 1
		frame.ZIndex = ZCounter
	end
	MakeDraggable(header, frame, Front)
	Front()

	local pscale = frame:FindFirstChildOfClass("UIScale")
	local PToken = 0
	function P:SetVisible(v)
		PToken = PToken + 1
		local mine = PToken
		if v then
			if not frame.Visible and pscale then
				pscale.Scale = Lumen.Scale * 0.94
				TweenService:Create(pscale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = Lumen.Scale }):Play()
			end
			frame.Visible = true
			Front()
		elseif frame.Visible then
			if pscale then
				TweenService:Create(pscale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = Lumen.Scale * 0.94 }):Play()
				task.delay(0.16, function()
					if mine == PToken then frame.Visible = false pscale.Scale = Lumen.Scale Lumen:_UpdateDock() end
				end)
			else
				frame.Visible = false
			end
		end
		Lumen:_UpdateDock()
	end
	function P:Toggle() self:SetVisible(not frame.Visible) end
	function P:Destroy()
		ClosePopup()
		frame:Destroy()
		for i, q in ipairs(Lumen._Panels) do if q == P then table.remove(Lumen._Panels, i) break end end
		Lumen:_UpdateDock()
	end
	P.Name = o.Title or "Panel"
	table.insert(Lumen._Panels, P)
	if o.Visible == false then frame.Visible = false end
	if o.Dock then
		Lumen:AddDockButton({
			Icon = o.Dock.Icon or "window", Tooltip = o.Dock.Tooltip or o.Title, Order = o.Dock.Order or 20,
			Callback = function() P:Toggle() end, Active = function() return frame.Visible end,
		})
	end
	return P
end

local function BuildCreditCard(container, e)
	local color = e.RoleColor or Lumen.Theme.Accent
	local order = (container:GetAttribute("Order") or 0) + 1
	container:SetAttribute("Order", order)
	local card = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = container,
		Theme = { BackgroundColor3 = "Group" },
	}, { Corner(7), Stroke("Outline"), Pad(12, 9, 12, 10), List(5) })
	local line = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Parent = card,
	}, { List(9, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	New("TextLabel", {
		Text = e.Name or "Name", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22),
		TextSize = 13, TextColor3 = Lumen.Theme.Text, LayoutOrder = 1, Parent = line,
	})
	if e.Role then Pill(line, e.Role:upper(), color, 2, 20, 10, Lumen.Theme.Group) end
	if e.Description then
		New("TextLabel", {
			Text = e.Description, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 11,
			TextColor3 = Lumen.Theme.TextMuted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamMedium, LayoutOrder = 2, Parent = card,
		})
	end
	return card
end

-- credits inside any group or tab: group:AddCredits({{Name, Role, RoleColor, Description}, ...})
function Elements:AddCredits(entries)
	local cards = {}
	for _, e in ipairs(entries or {}) do table.insert(cards, BuildCreditCard(self._container, e)) end
	return { Cards = cards, Add = function(_, e) local c = BuildCreditCard(self._container, e) table.insert(cards, c) return c end }
end

function Lumen:CreateCredits(o)
	o = o or {}
	local P = self:CreatePanel({
		Title = o.Title or "CREDITS", Subtitle = o.Subtitle or "People behind this script",
		Width = o.Width or 340, Height = o.Height, Position = o.Position, Dock = o.Dock, Visible = o.Visible,
	})
	function P:AddEntry(e) return BuildCreditCard(self._container, e) end
	for _, e in ipairs(o.Entries or {}) do P:AddEntry(e) end
	return P
end


------------------------------------------------------------------------------
-- Confirmation dialog
------------------------------------------------------------------------------

-- o: Title, Text, Type ("Warning" default, "Danger", "Info", "Success"), Confirm / Cancel (button labels),
--    Hold (seconds the confirm button must be held, 0 = plain click), Callback(accepted), OnConfirm, OnCancel
function Lumen:Confirm(o)
	o = o or {}
	local kind = NOTIFY_KINDS[o.Type or "Warning"] or NOTIFY_KINDS.Warning
	if kind.Icon == "spinner" then kind = NOTIFY_KINDS.Info end
	local key = kind.Key
	local T = self.Theme
	local color = T[key]
	local symbol = kind.Icon
	local hold = o.Hold or 0
	local done = false
	local keyConn

	local dim = New("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
		Active = true, ZIndex = 70, Parent = Gui,
	})
	local card = New("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 14), Size = UDim2.fromOffset(410, 0),
		AutomaticSize = Enum.AutomaticSize.Y, GroupTransparency = 1, ZIndex = 71, Parent = Gui,
		Theme = { BackgroundColor3 = "Background" },
	}, { Corner(12), Stroke(nil, true), List(0) })
	-- soft coloured light along the top edge
	New("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = color, LayoutOrder = 0, Parent = card }, {
		New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	local body = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = card,
	}, { Pad(22, 20, 22, 18), List(16) })

	local top = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = body },
		{ List(14, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	local badge, badgePlate, badgeGlyph = StatusBadge(top, kind, 44)
	badge.LayoutOrder = 1
	Glow(badgePlate, color, kind.Shape == "square" and 13 or 22, true)
	local bsc = New("UIScale", { Scale = 0.4, Parent = badgeGlyph })
	TweenService:Create(bsc, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local texts = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -58, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = top,
	}, { List(5) })
	New("TextLabel", {
		Text = o.Title or "Are you sure?", Size = UDim2.new(1, 0, 0, 20), TextSize = 15, TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = texts,
	})
	if o.Text then
		New("TextLabel", {
			Text = o.Text, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = 12,
			TextColor3 = T.TextDim, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2, Parent = texts,
		})
	end

	local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 2, Parent = body },
		{ List(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
	local cancelBtn = New("TextButton", {
		Size = UDim2.fromOffset(104, 32), BackgroundTransparency = 0, Text = o.Cancel or "Cancel", LayoutOrder = 1, Parent = row,
		Theme = { BackgroundColor3 = "Control" },
	}, { Corner(7), Stroke("Outline") })
	local confirmBtn = New("TextButton", {
		Size = UDim2.fromOffset(hold > 0 and 150 or 120, 32), BackgroundTransparency = 0, BackgroundColor3 = color:Lerp(T.Background, 0.78),
		Text = "", ClipsDescendants = true, LayoutOrder = 2, Parent = row,
	}, { Corner(7), New("UIStroke", { Color = color:Lerp(T.Background, 0.45), Thickness = 1 }) })
	Glow(confirmBtn, color, 7)
	local fill = New("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = color:Lerp(T.Background, 0.45), Parent = confirmBtn })
	local confirmLabel = New("TextLabel", {
		Size = UDim2.fromScale(1, 1), Text = (o.Confirm or "Confirm") .. (hold > 0 and "  (hold)" or ""),
		TextColor3 = color, Font = Enum.Font.GothamBold, ZIndex = 2, Parent = confirmBtn,
	})
	New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14), Text = hold > 0 and "Hold to confirm  -  Esc to cancel" or "Enter to confirm  -  Esc to cancel",
		TextSize = 10, TextColor3 = T.TextMuted, Font = Enum.Font.GothamMedium, LayoutOrder = 3, Parent = body,
	})

	local scale = New("UIScale", { Scale = 0.94, Parent = card })
	Tween(dim, 0.18, { BackgroundTransparency = 0.45 })
	Tween(card, 0.2, { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0) })
	Tween(scale, 0.2, { Scale = 1 })

	local function Close(accepted)
		if done then return end
		done = true
		if keyConn then keyConn:Disconnect() end
		Tween(dim, 0.15, { BackgroundTransparency = 1 })
		Tween(card, 0.15, { GroupTransparency = 1 })
		Tween(scale, 0.15, { Scale = 0.96 })
		task.delay(0.2, function()
			dim:Destroy()
			card:Destroy()
		end)
		if accepted then
			if o.OnConfirm then task.spawn(o.OnConfirm) end
		else
			if o.OnCancel then task.spawn(o.OnCancel) end
		end
		if o.Callback then task.spawn(o.Callback, accepted) end
	end

	Connect(cancelBtn.MouseButton1Click, function() Close(false) end)
	Connect(cancelBtn.MouseEnter, function() Tween(cancelBtn, 0.1, { BackgroundColor3 = Lumen.Theme.ControlHover }) end)
	Connect(cancelBtn.MouseLeave, function() Tween(cancelBtn, 0.1, { BackgroundColor3 = Lumen.Theme.Control }) end)
	Connect(dim.MouseButton1Click, function() Close(false) end)

	if hold > 0 then
		local holding, t0 = false, 0
		local function Release()
			holding = false
			Tween(fill, 0.15, { Size = UDim2.new(0, 0, 1, 0) })
		end
		Connect(confirmBtn.MouseButton1Down, function()
			holding = true
			t0 = os.clock()
			Tween(fill, hold, { Size = UDim2.new(1, 0, 1, 0) })
			task.delay(hold, function()
				if holding and os.clock() - t0 >= hold - 0.05 then Close(true) end
			end)
		end)
		Connect(confirmBtn.MouseButton1Up, Release)
		Connect(confirmBtn.MouseLeave, Release)
	else
		Connect(confirmBtn.MouseButton1Click, function() Close(true) end)
		Connect(confirmBtn.MouseEnter, function() Tween(fill, 0.15, { Size = UDim2.new(1, 0, 1, 0) }) end)
		Connect(confirmBtn.MouseLeave, function() Tween(fill, 0.15, { Size = UDim2.new(0, 0, 1, 0) }) end)
	end

	keyConn = UIS.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape then
			Close(false)
		elseif input.KeyCode == Enum.KeyCode.Return and hold <= 0 then
			Close(true)
		end
	end)
	table.insert(Connections, keyConn)
	return { Close = function() Close(false) end }
end

-- Generic key prompt. `Validate(key)` is YOUR function; it should return true (or false, "message").
-- DiscordLink adds the Discord icon in the header (click copies the link).
function Lumen:CreateKeySystem(o)
	o = o or {}
	local header
	if o.DiscordLink or o.HeaderIcon then
		header = o.HeaderIcon or {
			Icon = "discord", Tooltip = "Copy Discord invite",
			Callback = function()
				if setclipboard then setclipboard(o.DiscordLink) end
				Lumen:Notify({ Content = "Discord invite copied.", Type = "Info" })
			end,
		}
	end
	local P = self:CreatePanel({
		Title = o.Title or "Key System", Width = o.Width or 440, Position = o.Position, HeaderIcon = header, Dock = o.Dock, Visible = o.Visible,
	})
	if o.Note then P:AddLabel(o.Note, { Dim = true }) end
	local input = P:AddInput({ Placeholder = o.Placeholder or "Enter your key...", Realtime = true })
	local function Submit()
		if not o.Validate then return end
		local ok, valid, msg = pcall(o.Validate, input.Value)
		if ok and valid then
			Lumen:Notify({ Title = "Key System", Content = "Key accepted.", Type = "Success" })
			P:Destroy()
			if o.OnSuccess then task.spawn(o.OnSuccess, input.Value) end
		else
			Lumen:Notify({ Title = "Key System", Content = (ok and msg) or "Invalid key.", Type = "Danger" })
		end
	end
	P:AddButton({
		Text = "Get Key",
		Callback = function()
			if o.GetKey then
				task.spawn(o.GetKey)
			elseif o.GetKeyLink and setclipboard then
				setclipboard(o.GetKeyLink)
				Lumen:Notify({ Content = "Link copied to clipboard.", Type = "Info" })
			end
		end,
	}):AddSubButton({ Text = "Submit", Callback = Submit })
	return P
end

------------------------------------------------------------------------------
-- Config system
------------------------------------------------------------------------------

local function CanFile()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfolder) == "function"
		and type(makefolder) == "function" and type(listfiles) == "function"
end

function Lumen:_Serialize()
	local data = {}
	for flag, o in pairs(self.Options) do
		local t = o.Type
		if t == "Toggle" or t == "Slider" or t == "Input" then
			data[flag] = { t = t, v = o.Value }
		elseif t == "Dropdown" then
			if o.Multi then
				local arr = {}
				for k, val in pairs(o.Value) do if val then table.insert(arr, k) end end
				data[flag] = { t = t, v = arr }
			else
				data[flag] = { t = t, v = o.Value }
			end
		elseif t == "ColorPicker" then
			data[flag] = { t = t, v = { o.Value.R, o.Value.G, o.Value.B } }
		elseif t == "Keybind" then
			data[flag] = {
				t = t, mode = o.Mode,
				k = o.Value and o.Value.Name or nil,
				e = o.Value and (o.Value.EnumType == Enum.KeyCode and "KeyCode" or "UserInputType") or nil,
			}
		end
	end
	return data
end

function Lumen:_Apply(data)
	if data.Lumen_Preset and self.Options.Lumen_Preset then
		local fade = self.ThemeTransition
		self.ThemeTransition = 0
		pcall(function() self.Options.Lumen_Preset:Set(PresetLabel(PresetName(data.Lumen_Preset.v))) end)
		self.ThemeTransition = fade
		local rest = {}
		for k, v in pairs(data) do if k ~= "Lumen_Preset" then rest[k] = v end end
		data = rest
	end
	for flag, d in pairs(data) do
		local o = self.Options[flag]
		if o and o.Type == d.t then
			pcall(function()
				if d.t == "Keybind" then
					if d.mode then o:SetMode(d.mode) end
					if d.k and d.e then o:SetKey(Enum[d.e][d.k]) else o:SetKey(nil) end
				elseif d.t == "Dropdown" and o.Multi then
					o:Set(d.v)
				else
					o:Set(d.v)
				end
			end)
		end
	end
end

local function CfgPath(name) return Lumen.Folder .. "/" .. name .. ".json" end

function Lumen:ListConfigs()
	local out = {}
	if not CanFile() then return out end
	if not isfolder(self.Folder) then return out end
	for _, p in ipairs(listfiles(self.Folder)) do
		local n = p:match("([^/\\]+)%.json$")
		if n then table.insert(out, n) end
	end
	table.sort(out)
	return out
end

function Lumen:SaveConfig(name)
	if not CanFile() then return false, "Your executor does not support file functions" end
	if not name or name:gsub("%s", "") == "" then return false, "Enter a config name first" end
	if not isfolder(self.Folder) then makefolder(self.Folder) end
	local ok, err = pcall(function() writefile(CfgPath(name), HttpService:JSONEncode(self:_Serialize())) end)
	return ok, err
end

function Lumen:LoadConfig(name)
	if not CanFile() then return false, "Your executor does not support file functions" end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CfgPath(name))) end)
	if not ok then return false, "Could not read config" end
	self:_Apply(data)
	return true
end

function Lumen:DeleteConfig(name)
	if type(delfile) ~= "function" then return false, "delfile is not supported" end
	local ok, err = pcall(delfile, CfgPath(name))
	return ok, err
end

function Lumen:SetAutoload(name)
	if not CanFile() then return false end
	if not isfolder(self.Folder) then makefolder(self.Folder) end
	writefile(self.Folder .. "/autoload.txt", name or "")
	return true
end

function Lumen:GetAutoload()
	if not CanFile() then return nil end
	local ok, v = pcall(function() return readfile(self.Folder .. "/autoload.txt") end)
	if ok and v and v ~= "" then return v end
end

function Lumen:LoadAutoload()
	local n = self:GetAutoload()
	if n then
		local ok = self:LoadConfig(n)
		if ok then self:Notify({ Title = "Config", Content = "Autoloaded '" .. n .. "'.", Type = "Success" }) end
	end
end

------------------------------------------------------------------------------
-- Backdrop (dim + blur + snow). Shown only while a window is open.
------------------------------------------------------------------------------

local Snow = { Enabled = false, Count = 70, Speed = 1, Kind = "Theme", Layers = {}, Time = 0, Show = 0, ShowTarget = 0, NextBolt = 6 }
local Backdrop = { Dim = 0.35, Blur = 0 }
local BlurEffect

local BackdropFrame = New("Frame", {
	Name = "Backdrop", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true,
	Visible = false, ZIndex = 0, Parent = Gui,
})
local DimFrame = New("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Parent = BackdropFrame,
})
local FlashFrame = New("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(215, 228, 255), BackgroundTransparency = 1, ZIndex = 3, Parent = BackdropFrame,
})

-- vignette (film themes): soft dark edges built from four gradient strips
local Vignette = {}
for i, spec in ipairs({
	{ UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0.3, 0), 90, false }, { UDim2.new(0, 0, 0.7, 0), UDim2.new(1, 0, 0.3, 0), 90, true },
	{ UDim2.new(0, 0, 0, 0), UDim2.new(0.25, 0, 1, 0), 0, false }, { UDim2.new(0.75, 0, 0, 0), UDim2.new(0.25, 0, 1, 0), 0, true },
}) do
	local fr = New("Frame", { Position = spec[1], Size = spec[2], BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 2, Parent = BackdropFrame })
	New("UIGradient", { Rotation = spec[3], Transparency = NumberSequence.new(spec[4] and 1 or 0.15, spec[4] and 0.15 or 1), Parent = fr })
	Vignette[i] = fr
end
local function StyleVignette()
	local to = Lumen.Style
	local from = StyleBlend and StyleBlend.From or to
	local a = StyleBlend and StyleBlend.A or 1
	local p = (from.Vignette and 1 or 0) * (1 - a) + (to.Vignette and 1 or 0) * a
	for _, fr in ipairs(Vignette) do fr.BackgroundTransparency = 1 - p end
end

local function AnyWindowVisible()
	for _, w in ipairs(Lumen.Windows) do
		if w.Visible then return true end
	end
	return false
end

-- the backdrop (dim, blur, particles) fades in when a window opens and out when the last one closes
function Lumen:_UpdateSnow()
	local any = AnyWindowVisible()
	Snow.ShowTarget = any and 1 or 0
	if any and (Snow.Enabled or Backdrop.Dim > 0) then BackdropFrame.Visible = true end
	TweenService:Create(DimFrame, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ BackgroundTransparency = any and (1 - math.clamp(Backdrop.Dim, 0, 1)) or 1 }):Play()
	local target = any and math.max(Backdrop.Blur, Lumen.Style.Blur or 0) or 0
	if target > 0 and not BlurEffect then
		pcall(function()
			BlurEffect = Instance.new("BlurEffect")
			BlurEffect.Size = 0
			BlurEffect.Parent = Lighting
		end)
	end
	if BlurEffect then Tween(BlurEffect, 0.35, { Size = target }) end
	self:_UpdateDock()
end

------------------------------------------------------------------------------
-- Particle kinds. Each has Build(f, color) (create f.Frame, set f.Base = resting transparency)
-- and Update(f, dt, t, speed) (move it; may return a transparency). Register your own with Lumen:RegisterParticles.
------------------------------------------------------------------------------

local GLYPH_CHARS = { "0", "1", "0", "1", "A", "F", "7", "3", "#", "*" }
local CONFETTI = { Color3.fromRGB(255, 128, 190), Color3.fromRGB(130, 255, 210), Color3.fromRGB(255, 220, 120), Color3.fromRGB(150, 170, 255), Color3.fromRGB(255, 160, 110) }
local function Dot(parent, size, color, tr)
	return New("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = color, BackgroundTransparency = tr, Parent = parent }, { CornerFixed(size) })
end
local function Fall(f, dt, sp, dir)
	f.Y = f.Y + f.Speed * sp * dt * (dir or 1)
	if f.Y > 1.05 then f.Y = -0.05 f.X = math.random() elseif f.Y < -0.05 then f.Y = 1.05 f.X = math.random() end
end

local KINDS = {}
KINDS.Snow = {
	Build = function(f, c, p)
		local size = math.random(4, 13)
		f.Speed = 0.03 + (size / 13) * 0.07
		f.Base = 0.3 + math.random() * 0.5
		f.Frame = Dot(p, size, c, f.Base)
	end,
	Update = function(f, dt, t, sp)
		Fall(f, dt, sp)
		f.Frame.Position = UDim2.fromScale(f.X + math.sin(t * f.Sway + f.Phase) * 0.008, f.Y)
	end,
}
KINDS.Bubbles = {
	Build = function(f, c, p)
		local size = math.random(6, 20)
		f.Speed = 0.025 + (size / 20) * 0.05
		f.Base = 0.92
		f.Frame = Dot(p, size, c, 0.92)
		f.Extra = { { New("UIStroke", { Color = c, Thickness = 1.2, Transparency = 0.5, Parent = f.Frame }), "Transparency", 0.35 + math.random() * 0.4 },
			{ Dot(f.Frame, math.max(2, math.floor(size / 4)), Color3.new(1, 1, 1), 0.45), "BackgroundTransparency", 0.45 } }
		f.Extra[2][1].Position = UDim2.fromScale(0.22, 0.2)
	end,
	Update = function(f, dt, t, sp)
		Fall(f, dt, sp, -1)
		f.Frame.Position = UDim2.fromScale(f.X + math.sin(t * f.Sway * 1.6 + f.Phase) * 0.012, f.Y)
	end,
}
KINDS.Petals = {
	Build = function(f, c, p)
		local size = math.random(6, 12)
		f.Speed = 0.025 + math.random() * 0.03
		f.Spin, f.Rot = (math.random() - 0.5) * 160, math.random() * 360
		f.Base = 0.15 + math.random() * 0.4
		f.Frame = New("Frame", { Size = UDim2.fromOffset(math.floor(size * 1.5), size), BackgroundColor3 = c:Lerp(Color3.new(1, 1, 1), math.random() * 0.3),
			BackgroundTransparency = f.Base, Parent = p }, { CornerFixed(size) })
	end,
	Update = function(f, dt, t, sp)
		Fall(f, dt, sp)
		f.Rot = f.Rot + f.Spin * sp * dt
		f.Frame.Position = UDim2.fromScale(f.X + math.sin(t * f.Sway + f.Phase) * 0.035, f.Y)
		f.Frame.Rotation = f.Rot
	end,
}
KINDS.Embers = {
	Build = function(f, c, p)
		local size = math.random(2, 5)
		f.Speed = 0.05 + math.random() * 0.07
		f.Base = 0.2
		f.Frame = New("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = c:Lerp(Color3.fromRGB(255, 230, 150), math.random() * 0.5),
			BackgroundTransparency = 0.2, Parent = p }, { CornerFixed(1) })
	end,
	Update = function(f, dt, t, sp)
		Fall(f, dt, sp, -1)
		f.Frame.Position = UDim2.fromScale(f.X + math.sin(t * f.Sway * 2 + f.Phase) * 0.018, f.Y)
		return math.clamp(0.1 + (1 - f.Y) * 0.75 + 0.15 * math.sin(t * 13 + f.Phase), 0, 1)
	end,
}
KINDS.Fireflies = {
	Build = function(f, c, p)
		local size = math.random(3, 6)
		f.Pulse = 1.2 + math.random() * 2
		f.Base = 0.2
		f.Frame = Dot(p, size, c, 0.2)
		local halo = Dot(f.Frame, size * 4, c, 0.88)
		halo.AnchorPoint = Vector2.new(0.5, 0.5)
		halo.Position = UDim2.fromScale(0.5, 0.5)
		f.Extra = { { halo, "BackgroundTransparency", 0.88 } }
	end,
	Update = function(f, dt, t, sp)
		f.X = (f.X + math.sin(t * f.Sway * 0.7 + f.Phase) * 0.018 * sp * dt) % 1
		f.Y = (f.Y + math.cos(t * f.Sway * 0.5 + f.Phase * 2) * 0.014 * sp * dt) % 1
		f.Frame.Position = UDim2.fromScale(f.X, f.Y)
		return 0.15 + 0.75 * (0.5 + 0.5 * math.sin(t * f.Pulse + f.Phase))
	end,
}
KINDS.Stars = {
	Build = function(f, c, p)
		local size = math.random(1, 3)
		f.Pulse = 0.6 + math.random() * 2.2
		f.Base = 0.3
		f.Frame = Dot(p, size, c, 0.3)
		f.Frame.Position = UDim2.fromScale(f.X, f.Y)
	end,
	Update = function(f, dt, t, sp)
		return 0.15 + 0.75 * (0.5 + 0.5 * math.sin(t * f.Pulse * sp + f.Phase))
	end,
}
KINDS.Glyphs = {
	Build = function(f, c, p)
		f.Speed = 0.06 + math.random() * 0.1
		f.Base = 0.3 + math.random() * 0.55
		-- plain Instance.new so theme font changes never touch these
		local tl = Instance.new("TextLabel")
		tl.BackgroundTransparency = 1
		tl.Size = UDim2.fromOffset(14, 16)
		tl.Font = Enum.Font.RobotoMono
		tl.TextSize = math.random(10, 16)
		tl.TextColor3 = c
		tl.TextTransparency = f.Base
		tl.Text = GLYPH_CHARS[math.random(#GLYPH_CHARS)]
		tl.Parent = p
		f.Frame = tl
	end,
	Update = function(f, dt, t, sp)
		Fall(f, dt, sp)
		if math.random() < dt * 1.5 then f.Frame.Text = GLYPH_CHARS[math.random(#GLYPH_CHARS)] end
		f.Frame.Position = UDim2.fromScale(f.X, f.Y)
	end,
}
-- rain streaks falling at a slant (the Storm theme adds distant lightning)
KINDS.Rain = {
	Build = function(f, c, p)
		local len = math.random(14, 30)
		f.Speed = 0.55 + math.random() * 0.45
		f.Base = 0.45 + math.random() * 0.35
		f.Frame = New("Frame", { Size = UDim2.fromOffset(1, len), Rotation = 14, BackgroundColor3 = c, BackgroundTransparency = f.Base, Parent = p })
	end,
	Update = function(f, dt, t, sp)
		Fall(f, dt, sp)
		f.X = f.X - f.Speed * sp * dt * 0.25
		if f.X < -0.02 then f.X = f.X + 1.04 end
		f.Frame.Position = UDim2.fromScale(f.X, f.Y)
	end,
}
-- tumbling multicolour confetti (ignores the particle colour)
KINDS.Confetti = {
	Build = function(f, c, p)
		f.Speed = 0.04 + math.random() * 0.05
		f.Spin, f.Rot, f.Flip = (math.random() - 0.5) * 300, math.random() * 360, math.random() * 6
		f.Base = 0.05 + math.random() * 0.25
		f.W = math.random(4, 7)
		f.Frame = New("Frame", { Size = UDim2.fromOffset(f.W, f.W * 2), BackgroundColor3 = CONFETTI[math.random(#CONFETTI)],
			BackgroundTransparency = f.Base, Parent = p }, { CornerFixed(1) })
	end,
	Update = function(f, dt, t, sp)
		Fall(f, dt, sp)
		f.Rot = f.Rot + f.Spin * sp * dt
		f.Frame.Rotation = f.Rot
		-- flutter: the width breathes as if the piece turns over in the air
		f.Frame.Size = UDim2.fromOffset(math.max(1, math.floor(f.W * math.abs(math.cos(t * 3 + f.Flip)) + 0.5)), f.W * 2)
		f.Frame.Position = UDim2.fromScale(f.X + math.sin(t * f.Sway * 1.4 + f.Phase) * 0.02, f.Y)
	end,
}
-- four-point twinkles that grow, glint and fade in place
KINDS.Sparkles = {
	Build = function(f, c, p)
		local size = math.random(8, 16)
		f.Pulse = 0.5 + math.random() * 1.1
		f.Base = 0.15
		f.Frame = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Position = UDim2.fromScale(f.X, f.Y), Parent = p })
		local a = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = c, Parent = f.Frame }, { CornerFixed(1) })
		local b = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = c, Parent = f.Frame }, { CornerFixed(1) })
		f.Scale = New("UIScale", { Parent = f.Frame })
		f.Extra = { { a, "BackgroundTransparency", 0 }, { b, "BackgroundTransparency", 0 } }
		f.NoSelf = true
	end,
	Update = function(f, dt, t, sp)
		local w = 0.5 + 0.5 * math.sin(t * f.Pulse * sp + f.Phase)
		f.Scale.Scale = 0.2 + w * 0.8
		f.Frame.Rotation = (t * 20 + f.Phase * 50) % 90
		if w < 0.03 and math.random() < 0.5 then f.X, f.Y = math.random(), math.random() f.Frame.Position = UDim2.fromScale(f.X, f.Y) end
		return 1 - w * 0.9
	end,
}
-- chunky square pixels drifting upward, blinking now and then
KINDS.Pixels = {
	Build = function(f, c, p)
		local size = math.random(1, 3) * 3
		f.Speed = 0.02 + math.random() * 0.04
		f.Base = 0.2 + math.random() * 0.4
		f.Frame = New("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = c, BackgroundTransparency = f.Base, Parent = p })
	end,
	Update = function(f, dt, t, sp)
		Fall(f, dt, sp, -1)
		-- snap to a coarse grid so the motion steps like old hardware
		local px = math.floor(f.X * 160) / 160
		local py = math.floor(f.Y * 90) / 90
		f.Frame.Position = UDim2.fromScale(px, py)
		if math.sin(t * 2 + f.Phase * 9) > 0.97 then return 1 end
	end,
}
-- twinkling stars with the occasional shooting star
KINDS.Starfield = {
	Build = function(f, c, p)
		local size = math.random(1, 3)
		f.Pulse = 0.4 + math.random() * 1.6
		f.Base = 0.2
		f.Frame = Dot(p, size, c, 0.2)
		f.Frame.Position = UDim2.fromScale(f.X, f.Y)
	end,
	Update = function(f, dt, t, sp)
		return 0.1 + 0.8 * (0.5 + 0.5 * math.sin(t * f.Pulse * sp + f.Phase))
	end,
	Layer = function(layer, dt, t, sp, color)
		layer.NextShot = layer.NextShot or (t + 1.5)
		if t >= layer.NextShot then
			layer.NextShot = t + 1.6 + math.random() * 3.5
			local x0, y0 = math.random() * 0.8, math.random() * 0.4
			local streak = New("Frame", {
				Size = UDim2.fromOffset(90, 2), Rotation = 25, Position = UDim2.fromScale(x0, y0), BackgroundColor3 = color,
				BackgroundTransparency = 1 - layer.Alpha * Snow.Show, Parent = layer.Folder,
			}, { CornerFixed(1), New("UIGradient", { Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.85, 0.1), NumberSequenceKeypoint.new(1, 0) }) }) })
			TweenService:Create(streak, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.fromScale(x0 + 0.22, y0 + 0.13), BackgroundTransparency = 1 }):Play()
			task.delay(0.95, function() streak:Destroy() end)
		end
	end,
}
-- slowly spinning six-armed ice crystals
KINDS.Crystals = {
	Build = function(f, c, p)
		local size = math.random(8, 16)
		f.Speed = 0.02 + (size / 16) * 0.04
		f.Spin, f.Rot = (math.random() - 0.5) * 50, math.random() * 60
		f.Base = 0.25 + math.random() * 0.45
		f.Frame = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Parent = p })
		f.Extra = {}
		for _, r in ipairs({ 0, 60, 120 }) do
			local arm = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 1),
				Rotation = r, BackgroundColor3 = c, BackgroundTransparency = f.Base, Parent = f.Frame })
			table.insert(f.Extra, { arm, "BackgroundTransparency", f.Base })
		end
		f.NoSelf = true
	end,
	Update = function(f, dt, t, sp)
		Fall(f, dt, sp)
		f.Rot = f.Rot + f.Spin * sp * dt
		f.Frame.Rotation = f.Rot
		f.Frame.Position = UDim2.fromScale(f.X + math.sin(t * f.Sway * 0.6 + f.Phase) * 0.01, f.Y)
	end,
}
-- neon light streaks rising, alternating the theme's two neon colours
KINDS.Neon = {
	Build = function(f, c, p)
		local len = math.random(18, 46)
		f.Speed = 0.12 + math.random() * 0.18
		f.Base = 0.15 + math.random() * 0.4
		local col = (math.random() < 0.5) and c or ((Lumen.Style.Aura and Lumen.Style.Aura[1]) or c)
		f.Frame = New("Frame", { Size = UDim2.fromOffset(2, len), BackgroundColor3 = col, BackgroundTransparency = f.Base, Parent = p },
			{ CornerFixed(1), New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }) })
	end,
	Update = function(f, dt, t, sp)
		Fall(f, dt, sp, -1)
		f.Frame.Position = UDim2.fromScale(f.X, f.Y)
	end,
}

-- blueprint: drafting marks (crosshairs, circles, dimension lines) drifting slowly and fading in and out
KINDS.Drafting = {
	Build = function(f, c, p)
		f.Speed = 0.006 + math.random() * 0.01
		f.Pulse = 0.3 + math.random() * 0.8
		f.Base = 0.4
		f.NoSelf = true
		local size = math.random(8, 15)
		f.Frame = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Parent = p })
		local function Line(pos, sz, anchor)
			return New("Frame", { AnchorPoint = anchor or Vector2.new(0.5, 0.5), Position = pos, Size = sz, BackgroundColor3 = c, Parent = f.Frame })
		end
		local r = math.random()
		if r < 0.45 then
			-- crosshair
			local a = Line(UDim2.fromScale(0.5, 0.5), UDim2.new(1, 0, 0, 1))
			local b = Line(UDim2.fromScale(0.5, 0.5), UDim2.new(0, 1, 1, 0))
			f.Extra = { { a, "BackgroundTransparency" }, { b, "BackgroundTransparency" } }
		elseif r < 0.75 then
			-- circle with a centre mark
			local ring = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = f.Frame }, { CornerFixed(size) })
			local st = New("UIStroke", { Color = c, Thickness = 1, Parent = ring })
			local dot = Line(UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(2, 2))
			f.Extra = { { st, "Transparency" }, { dot, "BackgroundTransparency" } }
		else
			-- dimension line: a span with end ticks
			f.Frame.Size = UDim2.fromOffset(size * 2, 7)
			local a = Line(UDim2.fromScale(0.5, 0.5), UDim2.new(1, 0, 0, 1))
			local b = Line(UDim2.fromScale(0, 0.5), UDim2.new(0, 1, 1, 0), Vector2.new(0, 0.5))
			local d = Line(UDim2.fromScale(1, 0.5), UDim2.new(0, 1, 1, 0), Vector2.new(1, 0.5))
			f.Extra = { { a, "BackgroundTransparency" }, { b, "BackgroundTransparency" }, { d, "BackgroundTransparency" } }
		end
	end,
	Update = function(f, dt, t, sp)
		f.X = (f.X + f.Speed * 0.5 * sp * dt) % 1
		f.Y = f.Y - f.Speed * sp * dt
		if f.Y < -0.04 then f.Y = 1.04 end
		f.Frame.Position = UDim2.fromScale(f.X, f.Y)
		return 0.35 + 0.55 * (0.5 + 0.5 * math.sin(t * f.Pulse + f.Phase))
	end,
}
-- noir: film grain that jumps every few frames, and the odd vertical scratch flickering across the screen
KINDS.FilmGrain = {
	Build = function(f, c, p)
		f.Scratch = math.random() < 0.08
		f.Next = math.random() * 0.2
		if f.Scratch then
			f.Frame = New("Frame", { Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = c, BackgroundTransparency = 1, Parent = p })
			f.Base = 1
		else
			local sz = math.random(1, 3)
			f.Frame = New("Frame", { Size = UDim2.fromOffset(sz, sz), BackgroundColor3 = c, Parent = p }, sz > 1 and { CornerFixed(sz) } or nil)
			f.Base = 0.6
		end
	end,
	Update = function(f, dt, t, sp)
		f.Next = f.Next - dt * sp
		if f.Scratch then
			if f.Next <= 0 then
				f.Show = (math.random() < 0.35) and (0.06 + math.random() * 0.2) or 0
				f.Next = 0.25 + math.random() * 0.7
				f.Frame.Position = UDim2.fromScale(math.random(), 0)
			end
			f.Show = (f.Show or 0) - dt
			return f.Show > 0 and 0.55 or 1
		end
		if f.Next <= 0 then
			f.Next = 0.05 + math.random() * 0.12
			f.Frame.Position = UDim2.fromScale(math.random(), math.random())
			f.Tr = 0.35 + math.random() * 0.55
		end
		return f.Tr or 0.6
	end,
}
-- prism: glassy shards that rise, turn and shift through the spectrum
KINDS.Prisms = {
	Build = function(f, c, p)
		local size = math.random(5, 11)
		f.Speed = 0.015 + math.random() * 0.03
		f.Spin, f.Rot = (math.random() - 0.5) * 120, math.random() * 360
		f.Base = 0.25 + math.random() * 0.35
		f.Hue = math.random()
		f.Frame = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, math.floor(size * 1.6)),
			BackgroundColor3 = Color3.fromHSV(f.Hue, 0.45, 1), BackgroundTransparency = f.Base, Parent = p,
		}, { CornerFixed(1), New("UIGradient", { Rotation = 35, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 0.1) }) }) })
	end,
	Update = function(f, dt, t, sp)
		Fall(f, dt, sp, -1)
		f.Rot = f.Rot + f.Spin * sp * dt
		f.Frame.Rotation = f.Rot
		f.Frame.BackgroundColor3 = Color3.fromHSV((f.Hue + t * 0.06) % 1, 0.45, 1)
		f.Frame.Position = UDim2.fromScale(f.X + math.sin(t * f.Sway + f.Phase) * 0.01, f.Y)
		return f.Base + 0.3 * (0.5 + 0.5 * math.sin(t * 2.3 + f.Phase))
	end,
}
-- hazard: welding sparks that burst up and out, arc under gravity, cool from white-hot to orange and die
KINDS.Sparks = {
	Build = function(f, c, p)
		f.Color = c
		f.Frame = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(2, 7), BackgroundColor3 = c, Parent = p }, { CornerFixed(1) })
		f.Base = 1
		f.Dead, f.Life = true, math.random() * 1.6
	end,
	Update = function(f, dt, t, sp)
		dt = dt * sp
		if f.Dead then
			f.Life = f.Life - dt
			if f.Life > 0 then return 1 end
			f.X, f.Y = 0.1 + math.random() * 0.8, 0.1 + math.random() * 0.35
			local ang = math.rad(-90 + (math.random() - 0.5) * 140)
			local spd = 0.25 + math.random() * 0.35
			-- x is scaled down so the arc looks right on a wide screen
			f.VX, f.VY = math.cos(ang) * spd * 0.56, math.sin(ang) * spd
			f.Age, f.MaxAge, f.Dead = 0, 0.7 + math.random() * 0.9, false
		end
		f.Age = f.Age + dt
		f.VY = f.VY + 0.9 * dt
		f.X, f.Y = f.X + f.VX * dt, f.Y + f.VY * dt
		f.Frame.Position = UDim2.fromScale(f.X, f.Y)
		f.Frame.Rotation = math.deg(atan2(f.VY, f.VX / 0.56)) + 90
		local k = f.Age / f.MaxAge
		f.Frame.BackgroundColor3 = Color3.fromRGB(255, 250, 225):Lerp(f.Color:Lerp(Color3.fromRGB(255, 90, 20), 0.6), math.min(1, k * 1.4))
		if k >= 1 or f.Y > 1.05 then
			f.Dead, f.Life = true, math.random() * 0.8
			return 1
		end
		return k * k
	end,
}
-- glass: big soft out-of-focus circles of light drifting upward and breathing
KINDS.Bokeh = {
	Build = function(f, c, p)
		local size = math.random(28, 90)
		f.Speed = 0.004 + math.random() * 0.008
		f.Pulse = 0.2 + math.random() * 0.5
		f.Base = 0.9
		local col = c:Lerp(Color3.fromHSV(math.random(), 0.35, 1), 0.35)
		f.Frame = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size), BackgroundColor3 = col,
			BackgroundTransparency = 0.9, Parent = p }, { CornerFixed(size) })
		local core = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62),
			BackgroundColor3 = col, BackgroundTransparency = 0.88, Parent = f.Frame }, { CornerFixed(size) })
		local rim = New("UIStroke", { Color = col, Thickness = 1, Transparency = 0.75, Parent = f.Frame })
		f.Extra = { { core, "BackgroundTransparency", 0.88 }, { rim, "Transparency", 0.75 } }
	end,
	Update = function(f, dt, t, sp)
		f.X = (f.X + math.sin(t * 0.2 + f.Phase) * f.Speed * sp * dt) % 1
		f.Y = f.Y - f.Speed * sp * dt
		if f.Y < -0.1 then f.Y = 1.1 end
		f.Frame.Position = UDim2.fromScale(f.X, f.Y)
		return 0.86 + 0.08 * math.sin(t * f.Pulse + f.Phase)
	end,
}
-- haunted: bats flapping across the screen; each wing is hinged at the body
KINDS.Bats = {
	Build = function(f, c, p)
		local sz = math.random(7, 13)
		f.Speed = (0.035 + math.random() * 0.05) * (math.random() < 0.5 and -1 or 1)
		f.Flap = 9 + math.random() * 6
		f.Base = 0.15 + math.random() * 0.35
		f.NoSelf = true
		f.Y = math.random() * 0.7
		f.Frame = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Size = UDim2.fromOffset(sz * 3, sz * 2), Parent = p })
		local body = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(math.max(2, sz * 0.45), sz * 0.8),
			BackgroundColor3 = c, Parent = f.Frame }, { CornerFixed(sz) })
		local function Wing(side)
			local hinge = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(sz * 2.6, sz * 0.5),
				BackgroundTransparency = 1, Parent = f.Frame })
			local w = New("Frame", { Position = UDim2.fromScale(side < 0 and 0 or 0.5, 0), Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = c, Parent = hinge },
				{ CornerFixed(math.max(1, sz * 0.25)) })
			return hinge, w
		end
		f.HL, f.WL = Wing(-1)
		f.HR, f.WR = Wing(1)
		f.Extra = { { body, "BackgroundTransparency" }, { f.WL, "BackgroundTransparency" }, { f.WR, "BackgroundTransparency" } }
	end,
	Update = function(f, dt, t, sp)
		f.X = f.X + f.Speed * sp * dt
		if f.X > 1.08 then f.X, f.Y = -0.08, math.random() * 0.7 elseif f.X < -0.08 then f.X, f.Y = 1.08, math.random() * 0.7 end
		local flap = math.sin(t * f.Flap * sp + f.Phase)
		f.HL.Rotation = flap * 30
		f.HR.Rotation = -flap * 30
		f.Frame.Position = UDim2.fromScale(f.X, f.Y + math.sin(t * 1.3 + f.Phase) * 0.03)
		return f.Base
	end,
}
-- parchment: autumn leaves tumbling down, turning over as they fall
local LEAF_COLORS = { Color3.fromRGB(214, 120, 40), Color3.fromRGB(190, 70, 40), Color3.fromRGB(228, 170, 60), Color3.fromRGB(150, 90, 40), Color3.fromRGB(200, 140, 60) }
KINDS.Leaves = {
	Build = function(f, c, p)
		local sz = math.random(9, 15)
		f.Speed = 0.02 + math.random() * 0.03
		f.Spin, f.Rot, f.Flip = (math.random() - 0.5) * 140, math.random() * 360, math.random() * 6
		f.Base = 0.05 + math.random() * 0.3
		f.W = sz
		local col = LEAF_COLORS[math.random(#LEAF_COLORS)]:Lerp(c, 0.25)
		f.Frame = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(sz, math.floor(sz * 0.55)), BackgroundColor3 = col,
			BackgroundTransparency = f.Base, Parent = p }, { CornerFixed(sz) })
		local rib = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.8, 0, 0, 1),
			BackgroundColor3 = col:Lerp(Color3.new(0, 0, 0), 0.35), Parent = f.Frame })
		f.Extra = { { rib, "BackgroundTransparency", 0.3 } }
	end,
	Update = function(f, dt, t, sp)
		Fall(f, dt, sp)
		f.Rot = f.Rot + f.Spin * sp * dt
		f.Frame.Rotation = f.Rot
		f.Frame.Size = UDim2.fromOffset(math.max(2, math.floor(f.W * (0.35 + 0.65 * math.abs(math.cos(t * 1.7 + f.Flip))) + 0.5)), math.floor(f.W * 0.55))
		f.Frame.Position = UDim2.fromScale(f.X + math.sin(t * f.Sway * 0.9 + f.Phase) * 0.04, f.Y)
	end,
}

local BUILTIN_KINDS = { "Snow", "Bubbles", "Petals", "Embers", "Fireflies", "Stars", "Glyphs", "Rain", "Confetti", "Sparkles", "Pixels", "Starfield", "Crystals", "Neon",
	"Drafting", "FilmGrain", "Prisms", "Sparks", "Bokeh", "Bats", "Leaves" }
Lumen.ParticleKinds = { "Theme" }
for _, k in ipairs(BUILTIN_KINDS) do table.insert(Lumen.ParticleKinds, k) end
Lumen._particleDropdowns = {}

local function CurrentKind()
	if Snow.Kind == "Theme" then return Lumen.Style.Particles or "Snow" end
	return Snow.Kind
end

local function ApplyFlake(f, tr, alpha)
	local final = 1 - (1 - math.clamp(tr, 0, 1)) * alpha
	if not f.NoSelf then
		if f.Frame:IsA("TextLabel") then f.Frame.TextTransparency = final else f.Frame.BackgroundTransparency = final end
	end
	if f.Extra then
		for _, x in ipairs(f.Extra) do
			x[1][x[2]] = 1 - (1 - ((f.NoSelf or x[3] == nil) and math.clamp(tr, 0, 1) or x[3])) * alpha
		end
	end
end

-- Rebuilding never pops: the old layer fades out while the new one fades in.
local function BuildFlakes()
	for _, L in ipairs(Snow.Layers) do L.Target = 0 end
	if not Snow.Enabled then return end
	local kind = CurrentKind()
	local def = KINDS[kind]
	if not def then kind, def = "Snow", KINDS.Snow end
	local color = (Snow.Kind == "Theme" and Lumen.Style.ParticleColor) or Color3.new(1, 1, 1)
	if Snow.Kind ~= "Theme" then
		color = ({ Bubbles = Color3.fromRGB(140, 205, 255), Petals = Color3.fromRGB(242, 150, 186), Embers = Color3.fromRGB(255, 150, 70),
			Fireflies = Color3.fromRGB(180, 255, 150), Glyphs = Color3.fromRGB(205, 205, 205), Rain = Color3.fromRGB(170, 200, 240),
			Sparkles = Color3.fromRGB(255, 214, 120), Pixels = Color3.fromRGB(90, 255, 170), Crystals = Color3.fromRGB(215, 240, 255),
			Neon = Color3.fromRGB(0, 229, 255), Drafting = Color3.fromRGB(210, 230, 255), FilmGrain = Color3.fromRGB(230, 230, 230),
			Sparks = Color3.fromRGB(255, 210, 90), Bokeh = Color3.fromRGB(180, 210, 255), Bats = Color3.fromRGB(130, 90, 170),
			Leaves = Color3.fromRGB(200, 110, 50) })[kind] or color
	end
	local L = { Kind = kind, Def = def, Color = color, Flakes = {}, Alpha = 0, Target = 1,
		Folder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = BackdropFrame }) }
	for i = 1, Snow.Count do
		local f = { X = math.random(), Y = math.random(), Phase = math.random() * 6.28, Sway = 0.4 + math.random() * 0.8, Speed = 0.05, Base = 0.3 }
		local ok, err = pcall(def.Build, f, color, L.Folder)
		if not ok then
			warn("[Lumen] particle '" .. kind .. "' failed to build: " .. tostring(err))
			break
		end
		if f.Frame then
			if not f.Frame.Parent then f.Frame.Parent = L.Folder end
			ApplyFlake(f, f.Base, 0)
			table.insert(L.Flakes, f)
		end
	end
	table.insert(Snow.Layers, L)
end

function Lumen:_RefreshParticles()
	if Snow.Enabled then BuildFlakes() end
end

-- opts (all optional): Count, Speed, Dim, Kind
function Lumen:SetSnow(enabled, opts)
	if opts then
		if opts.Count then Snow.Count = math.floor(opts.Count) end
		if opts.Speed then Snow.Speed = opts.Speed end
		if opts.Dim then Backdrop.Dim = opts.Dim end
		if opts.Kind then Snow.Kind = opts.Kind end
	end
	Snow.Enabled = enabled and true or false
	BuildFlakes()
	SyncOption("Lumen_Snow", Snow.Enabled)
	self:_UpdateSnow()
end
Lumen.SetParticlesEnabled = Lumen.SetSnow

function Lumen:SetSnowOptions(opts)
	if opts.Kind then Snow.Kind = opts.Kind end
	if opts.Count then Snow.Count = math.floor(opts.Count) end
	if opts.Speed then Snow.Speed = opts.Speed end
	if (opts.Kind or opts.Count) and Snow.Enabled then BuildFlakes() end
end

-- "Theme" follows the active theme; or any name in Lumen.ParticleKinds
function Lumen:SetParticles(kind)
	self:SetSnowOptions({ Kind = kind })
	SyncOption("Lumen_Particles", kind)
end

-- Add your own particle style. def = { Build = function(f, color, parent) ... end, Update = function(f, dt, t, speed) ... end }
-- Build must set f.Frame (a GuiObject) and may set f.Base (resting transparency). f.X / f.Y (0-1), f.Phase, f.Sway are pre-filled.
-- Update moves it and may return a transparency (0-1). Fading in/out and the theme crossfade are handled for you.
function Lumen:RegisterParticles(name, def)
	assert(type(name) == "string" and type(def) == "table" and type(def.Build) == "function", "RegisterParticles(name, {Build = fn, Update = fn})")
	KINDS[name] = def
	if not table.find(self.ParticleKinds, name) then table.insert(self.ParticleKinds, name) end
	for _, d in ipairs(self._particleDropdowns) do pcall(function() d:SetValues(self.ParticleKinds, true) end) end
end

-- opts: Dim (0-1 darkness of the backdrop), Blur (0-40 world blur)
function Lumen:SetBackdrop(opts)
	if opts.Dim ~= nil then Backdrop.Dim = opts.Dim end
	if opts.Blur ~= nil then Backdrop.Blur = opts.Blur end
	self:_UpdateSnow()
end

local function Lightning()
	-- a distant flash: quick rise, slow fade, sometimes a second flicker
	FlashFrame.BackgroundTransparency = 1
	TweenService:Create(FlashFrame, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.8 }):Play()
	task.delay(0.07, function()
		TweenService:Create(FlashFrame, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		if math.random() < 0.5 then
			task.delay(0.18, function()
				TweenService:Create(FlashFrame, TweenInfo.new(0.05), { BackgroundTransparency = 0.88 }):Play()
				task.delay(0.06, function()
					TweenService:Create(FlashFrame, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
				end)
			end)
		end
	end)
end

Connect(RunService.RenderStepped, function(dt)
	if not BackdropFrame.Visible then return end
	Snow.Time = Snow.Time + dt
	local t, sp = Snow.Time, Snow.Speed
	-- whole-backdrop fade with the windows
	local rate = dt / 0.35
	if Snow.Show < Snow.ShowTarget then Snow.Show = math.min(Snow.ShowTarget, Snow.Show + rate)
	elseif Snow.Show > Snow.ShowTarget then Snow.Show = math.max(Snow.ShowTarget, Snow.Show - rate) end
	if Snow.Show <= 0 and Snow.ShowTarget == 0 then
		BackdropFrame.Visible = false
		return
	end
	for li = #Snow.Layers, 1, -1 do
		local L = Snow.Layers[li]
		local lr = dt / 0.7
		if L.Alpha < L.Target then L.Alpha = math.min(L.Target, L.Alpha + lr) elseif L.Alpha > L.Target then L.Alpha = math.max(L.Target, L.Alpha - lr) end
		if L.Alpha <= 0 and L.Target == 0 then
			L.Folder:Destroy()
			table.remove(Snow.Layers, li)
		else
			local alpha = L.Alpha * Snow.Show
			for _, f in ipairs(L.Flakes) do
				local ok, tr = pcall(L.Def.Update, f, dt, t, sp)
				ApplyFlake(f, (ok and tr) or f.Base, alpha)
			end
			if L.Def.Layer then pcall(L.Def.Layer, L, dt, t, sp, L.Color) end
			if L.Kind == "Rain" and L.Target == 1 and Lumen.Style.Lightning and t >= Snow.NextBolt then
				Snow.NextBolt = t + 5 + math.random() * 8
				Lightning()
			end
		end
	end
end)

------------------------------------------------------------------------------
-- Style: the non-colour half of a theme. Keys (all optional):
--   Radius (corner scale), Glow (glow strength, 0 = off), Font (any Roblox font name, "Inter", "Mono"), TextScale,
--   Particles + ParticleColor, Tint + TintPlace ("Top" | "Bottom" | "Aurora") + TintAmount,
--   TopLine = {c1, c2} (light along the window's top edge), Scanlines (bool),
--   Aura = {c1, c2, ...} + AuraSpeed + AuraThickness (animated gradient border),
--   InnerLine = Color3 (thin second border), AccentGradient = {c1, c2} (toggles, sliders, progress bars), Lightning (bool)
-- fade (seconds): corners, glow, fonts, surfaces and particles all blend instead of switching.
------------------------------------------------------------------------------

local StyleToken = 0
function Lumen:SetStyle(st, fade)
	fade = fade or 0
	local new = { Radius = 1, Glow = 1, TextScale = 1, Particles = "Snow", ParticleColor = Color3.new(1, 1, 1) }
	for k, v in pairs(st or {}) do new[k] = v end
	local old = self.Style
	self.Style = new
	local fontChanged = (new.Font and new.Font ~= self.FontName) or (new.TextScale or 1) ~= (self._textScale or 1)
	self._textScale = new.TextScale or 1

	local info = fade > 0 and TweenInfo.new(fade, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) or nil
	-- corners morph
	for _, d in ipairs(Gui:GetDescendants()) do
		if d:IsA("UICorner") then
			local r = d:GetAttribute("R")
			if r then
				local goal = UDim.new(0, math.floor(r * new.Radius + 0.5))
				if info then TweenService:Create(d, info, { CornerRadius = goal }):Play() else d.CornerRadius = goal end
			end
		end
	end
	-- glow strength
	for i = #Glows, 1, -1 do
		local g = Glows[i]
		if g.rings[1] and g.rings[1].Parent and g.rings[1].Parent.Parent then g:Set(g.mult, info) else table.remove(Glows, i) end
	end
	-- font + text size
	if fontChanged then self:SetFont(new.Font or self.FontName, fade > 0 and math.max(fade, 0.35) or 0) end
	-- surfaces and accent gradients blend step by step
	StyleToken = StyleToken + 1
	local mine = StyleToken
	local function Paint()
		for _, e in ipairs(Surfaces) do StyleSurface(e) end
		for _, e in ipairs(AccentFills) do if e.Frame.Parent then PaintAccent(e) end end
		StyleVignette()
	end
	if fade > 0 then
		StyleBlend = { From = old, To = new, A = 0 }
		task.spawn(function()
			local steps = math.max(2, math.floor(fade * 30))
			for i = 1, steps do
				if mine ~= StyleToken or Lumen.Unloaded then return end
				local a = i / steps
				StyleBlend.A = a * a * (3 - 2 * a)
				if i == steps then StyleBlend = nil end
				Paint()
				if i < steps then task.wait(fade / steps) end
			end
		end)
	else
		StyleBlend = nil
		Paint()
	end
	self:_RefreshParticles()
	if (new.Blur or 0) ~= (old.Blur or 0) then self:_UpdateSnow() end
	self.Events.StyleChanged:Fire(new)
end

-- faint diagonal text tiled over the whole screen (anti-leak watermark). Pass nil to remove.
local ScreenWM
function Lumen:SetScreenWatermark(text)
	if ScreenWM then ScreenWM:Destroy() ScreenWM = nil end
	if not text or text == "" then return end
	ScreenWM = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 90, Parent = Gui,
	})
	for r = 0, 7 do
		for c = 0, 4 do
			New("TextLabel", {
				Text = text, Size = UDim2.fromOffset(520, 28), Position = UDim2.new((c + (r % 2) * 0.5) / 4.2, -120, r / 7.2, 0),
				Rotation = -28, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 0.94,
				Font = Enum.Font.GothamBold, Parent = ScreenWM,
			})
		end
	end
end

------------------------------------------------------------------------------
-- Dock (icon bar at the top centre)
------------------------------------------------------------------------------

local Dock
local DockButtons = {}

local function EnsureDock()
	if Dock then return Dock end
	Dock = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 6, Visible = Lumen.ShowDock, Parent = Gui,
		Theme = { BackgroundColor3 = "Background" },
	}, { Corner(11), Stroke(nil, true), Pad(7, 7, 7, 7),
		List(6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	RegisterSurface(Dock, "Dock", 11)
	MakeDraggable(Dock, Dock, nil, "Dock")
	SnapHomes[Dock] = Dock.Position
	return Dock
end

-- active buttons get the lighter plate and an accent icon; inactive ones are a plain light-grey icon (as in the reference)
function Lumen:_UpdateDock()
	local T = self.Theme
	local offColor = T.Label:Lerp(T.Background, 0.1)
	for i = #DockButtons, 1, -1 do
		local e = DockButtons[i]
		if e.Button.Parent == nil then
			table.remove(DockButtons, i)
		else
			local on = e.Active and e.Active() or false
			e.Button.BackgroundColor3 = T.TabActive
			Tween(e.Button, 0.12, { BackgroundTransparency = on and 0 or 1 })
			local c = on and T.Accent or offColor
			if e.Icon then RecolorIcon(e.Icon, c) end
			if e.Image then e.Image.ImageColor3 = c end
		end
	end
end
table.insert(Refreshers, function() Lumen:_UpdateDock() end)

-- o: Icon ("window","scan","keyboard","command","user" are the traced reference icons; also "bell","gear","snow","list","discord"
-- or an rbxassetid), Tooltip, Name, Callback, Active (function -> bool), Order, Visible
function Lumen:AddDockButton(o)
	o = o or {}
	local dock = EnsureDock()
	local ic = o.Icon or "window"
	local b = New("TextButton", {
		Size = UDim2.fromOffset(31, 30), BackgroundTransparency = 1, LayoutOrder = o.Order or 50, Visible = o.Visible ~= false,
		Parent = dock, Theme = { BackgroundColor3 = "TabActive" },
	}, { Corner(8) })
	local entry = { Button = b, Active = o.Active, Name = o.Name or o.Tooltip or ic }
	if ic:find("rbxasset") or ic:find("rbxthumb") then
		entry.Image = New("ImageLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(17, 17), Image = ic, Parent = b,
		})
	else
		entry.Icon = Icon(ic, b, 18)
		entry.Icon.AnchorPoint = Vector2.new(0.5, 0.5)
		entry.Icon.Position = UDim2.fromScale(0.5, 0.5)
	end
	if o.Tooltip then AttachTooltip(b, o.Tooltip) end
	table.insert(DockButtons, entry)
	Connect(b.MouseEnter, function()
		if not (entry.Active and entry.Active()) then
			b.BackgroundColor3 = Lumen.Theme.ControlHover
			Tween(b, 0.1, { BackgroundTransparency = 0.35 })
		end
	end)
	Connect(b.MouseLeave, function() Lumen:_UpdateDock() end)
	Connect(b.MouseButton1Click, function()
		if o.Callback then task.spawn(o.Callback) end
		Lumen:_UpdateDock()
	end)
	Lumen:_UpdateDock()
	return b
end

function Lumen:SetDockVisible(v)
	self.ShowDock = v
	if Dock then Dock.Visible = v end
	SyncOption("Lumen_Dock", v)
end

-- show / hide a single dock button by its name (tooltip text)
function Lumen:SetDockButtonVisible(name, v)
	for _, e in ipairs(DockButtons) do
		if e.Name == name then e.Button.Visible = v end
	end
end

function Lumen:GetDockButtons()
	return DockButtons
end

------------------------------------------------------------------------------
-- Command palette: search every option, see its path and value (Ctrl+K or the dock button)
------------------------------------------------------------------------------

local Palette = { Open = false, Results = {}, Selected = 1, Rows = {} }
local PaletteDim, PaletteFrame, PaletteInput, PaletteList
local PaletteRefresh

local function FormatValue(opt)
	local t = opt.Type
	if t == "Toggle" or t == "Slider" then
		return tostring(opt.Value)
	elseif t == "Dropdown" then
		if opt.Multi then
			local sel = {}
			for _, v in ipairs(opt.Values) do if opt.Value[v] then table.insert(sel, tostring(v)) end end
			return #sel > 0 and table.concat(sel, ", ") or "nil"
		end
		return opt.Value == nil and "nil" or tostring(opt.Value)
	elseif t == "Input" then
		return '"' .. tostring(opt.Value) .. '"'
	end
	return "..."
end

local function PaletteScore(q, text)
	if q == "" then return 1 end
	text = text:lower()
	local i = text:find(q, 1, true)
	if i then return 1000 - i end
	local qi = 1
	for ci = 1, #text do
		if text:sub(ci, ci) == q:sub(qi, qi) then
			qi = qi + 1
			if qi > #q then return 100 end
		end
	end
	return nil
end

local function PaletteSearch(query)
	local q = query:lower():gsub("^%s*>?%s*", "")
	local out = {}
	local cat = Lumen._Catalog
	for i = #cat, 1, -1 do
		local e = cat[i]
		if not (e.Opt.Row and e.Opt.Row.Parent) then
			table.remove(cat, i)
		end
	end
	for _, e in ipairs(cat) do
		local sc = PaletteScore(q, e.Name .. " " .. e.Path)
		if sc then table.insert(out, { Entry = e, Score = sc }) end
	end
	table.sort(out, function(a, b)
		if a.Score ~= b.Score then return a.Score > b.Score end
		return a.Entry.Name < b.Entry.Name
	end)
	local res = {}
	for _, r in ipairs(out) do table.insert(res, r.Entry) end
	return res
end

local function PaletteHighlight()
	for i, row in ipairs(Palette.Rows) do
		row.BackgroundTransparency = (i == Palette.Selected) and 0 or 1
	end
end

local function PaletteActivate(e)
	local opt = e.Opt
	if opt.Disabled then return end
	if opt.Type == "Toggle" then
		opt:Set(not opt.Value)
		PaletteRefresh()
	elseif opt.Type == "Button" then
		Lumen:ClosePalette()
		if opt.Press then opt.Press() end
	else
		Lumen:ClosePalette()
		local tab = e.Tab
		if tab and tab.Window then
			tab.Window:SetVisible(true)
			tab.Window:SelectTab(tab)
			task.delay(0.15, function()
				if e.Group and e.Group._activate then e.Group._activate() end
				task.delay(0.12, function() Lumen:_Spotlight(opt.Row, tab.Page) end)
			end)
		end
	end
end

-- scroll an element into view and pulse a highlight around it
function Lumen:_Spotlight(row, page)
	if not row or not row.Parent then return end
	if page and row:IsDescendantOf(page) then
		local sc = math.max(self.Scale, 0.01)
		local y = (row.AbsolutePosition.Y - page.AbsolutePosition.Y) / sc + page.CanvasPosition.Y
		TweenService:Create(page, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ CanvasPosition = Vector2.new(0, math.max(0, y - 70)) }):Play()
	end
	local hl = New("Frame", {
		Size = UDim2.new(1, 10, 1, 8), Position = UDim2.fromOffset(-5, -4), BackgroundTransparency = 1, ZIndex = 0, Parent = row,
		Theme = { BackgroundColor3 = "Accent" },
	}, { Corner(7) })
	local st = New("UIStroke", { Thickness = 1.5, Transparency = 1, Parent = hl, Theme = { Color = "Accent" } })
	task.spawn(function()
		for _ = 1, 2 do
			TweenService:Create(hl, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.82 }):Play()
			TweenService:Create(st, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 0.2 }):Play()
			task.wait(0.25)
			TweenService:Create(hl, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(st, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
			task.wait(0.46)
		end
		hl:Destroy()
	end)
end

function PaletteRefresh()
	for _, r in ipairs(Palette.Rows) do r:Destroy() end
	Palette.Rows = {}
	Palette.Results = PaletteSearch(PaletteInput.Text)
	Palette.Selected = math.clamp(Palette.Selected, 1, math.max(#Palette.Results, 1))
	for i, e in ipairs(Palette.Results) do
		if i > 60 then break end
		local row = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 30), LayoutOrder = i, BackgroundTransparency = 1, Parent = PaletteList,
			Theme = { BackgroundColor3 = "Control" },
		}, { Corner(6) })
		local left = New("Frame", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -130, 1, 0), Parent = row,
		}, { List(10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
		New("TextLabel", {
			Text = e.Name, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30),
			TextColor3 = Lumen.Theme.Text, LayoutOrder = 1, Parent = left,
		})
		New("TextLabel", {
			Text = e.Path, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), TextSize = 11,
			TextColor3 = Lumen.Theme.TextDim, Font = Enum.Font.GothamMedium, LayoutOrder = 2, Parent = left,
		})
		New("TextLabel", {
			Text = FormatValue(e.Opt), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(110, 30), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamMedium,
			TextColor3 = Lumen.Theme.Label, Parent = row,
		})
		Connect(row.MouseEnter, function()
			Palette.Selected = i
			PaletteHighlight()
		end)
		Connect(row.MouseButton1Click, function()
			Palette.Selected = i
			PaletteActivate(e)
		end)
		table.insert(Palette.Rows, row)
	end
	PaletteHighlight()
end

local function BuildPalette()
	if PaletteFrame then return end
	PaletteDim = New("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
		Visible = false, ZIndex = 60, Active = true, Parent = Gui,
	})
	PaletteFrame = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 98), Size = UDim2.fromOffset(580, 360),
		Visible = false, ZIndex = 61, Parent = Gui, Theme = { BackgroundColor3 = "Background" },
	}, { Corner(10), Stroke(nil, true) })
	RegisterScale(PaletteFrame)
	local head = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = PaletteFrame })
	New("TextLabel", {
		Text = ">", Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(14, 44), TextSize = 13,
		TextColor3 = Lumen.Theme.TextDim, Parent = head,
	})
	PaletteInput = New("TextBox", {
		Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -46, 1, 0), BackgroundTransparency = 1, Text = "",
		PlaceholderText = "Search options...", PlaceholderColor3 = Lumen.Theme.TextMuted, ClearTextOnFocus = false,
		TextSize = 13, TextColor3 = Lumen.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = head,
	})
	New("Frame", {
		Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 1), Parent = PaletteFrame,
		Theme = { BackgroundColor3 = "Outline" },
	})
	PaletteList = New("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46), BackgroundTransparency = 1, ScrollBarThickness = 2,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = PaletteFrame,
		Theme = { ScrollBarImageColor3 = "Accent" },
	}, { Pad(8, 8, 8, 8), List(2) })
	Connect(PaletteDim.MouseButton1Click, function() Lumen:ClosePalette() end)
	Connect(PaletteInput:GetPropertyChangedSignal("Text"), function()
		if Palette.Open then
			Palette.Selected = 1
			PaletteRefresh()
		end
	end)
	Connect(PaletteInput.FocusLost, function(enter)
		if enter and Palette.Open then
			local e = Palette.Results[Palette.Selected]
			if e then PaletteActivate(e) end
			if Palette.Open then pcall(function() PaletteInput:CaptureFocus() end) end
		end
	end)
end

function Lumen:OpenPalette()
	BuildPalette()
	ClosePopup()
	Palette.Open = true
	PaletteDim.Visible = true
	PaletteFrame.Visible = true
	PaletteInput.Text = ""
	Palette.Selected = 1
	PaletteRefresh()
	task.defer(function() pcall(function() PaletteInput:CaptureFocus() end) end)
	self:_UpdateDock()
end

function Lumen:ClosePalette()
	if not Palette.Open then return end
	Palette.Open = false
	PaletteDim.Visible = false
	PaletteFrame.Visible = false
	pcall(function() PaletteInput:ReleaseFocus() end)
	self:_UpdateDock()
end

function Lumen:TogglePalette()
	if Palette.Open then self:ClosePalette() else self:OpenPalette() end
end

-- called from the global input handler while the palette is open; returns true when the key was used
function Lumen:_PaletteKey(kc)
	if not Palette.Open then return false end
	if kc == Enum.KeyCode.Escape then
		self:ClosePalette()
	elseif kc == Enum.KeyCode.Down then
		Palette.Selected = math.min(Palette.Selected + 1, math.max(#Palette.Rows, 1))
		PaletteHighlight()
	elseif kc == Enum.KeyCode.Up then
		Palette.Selected = math.max(Palette.Selected - 1, 1)
		PaletteHighlight()
	else
		return false
	end
	return true
end

-- `which` lists the built-in dock buttons to show (default: menu, hotkeys, palette = the reference dock).
-- A "particles" button also exists but stays hidden unless listed (or switched on in the config tab's Layout group).
function Lumen:_InitDock(W, which)
	if self._dockInit then return end
	self._dockInit = true
	local want = {}
	for _, k in ipairs(which or { "menu", "hotkeys", "palette" }) do want[k] = true end
	if want.snow then want.particles = true end
	self:AddDockButton({ Icon = "window", Tooltip = "Toggle menu", Order = 1, Visible = want.menu ~= nil,
		Callback = function() W:Toggle() end, Active = function() return W.Visible end })
	self:AddDockButton({ Icon = "keyboard", Tooltip = "Hotkey list", Order = 30, Visible = want.hotkeys ~= nil,
		Callback = function() Lumen:SetHotkeysVisible(not Lumen.ShowHotkeys) end, Active = function() return Lumen.ShowHotkeys end })
	self:AddDockButton({ Icon = "snow", Tooltip = "Particles", Order = 34, Visible = want.particles ~= nil,
		Callback = function() Lumen:SetSnow(not Snow.Enabled) end, Active = function() return Snow.Enabled end })
	self:AddDockButton({ Icon = "command", Tooltip = "Command palette (Ctrl+K)", Order = 40, Visible = want.palette ~= nil,
		Callback = function() Lumen:TogglePalette() end, Active = function() return Palette.Open end })
end

------------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------------

local function PillSpec(v, default)
	if type(v) == "string" then return { Text = v, Color = default } end
	if type(v) == "table" then return { Text = v.Text, Color = v.Color or default } end
end

function Lumen:CreateWindow(o)
	o = o or {}
	local W = {
		Tabs = {}, Title = o.Title or "Lumen", Id = o.Id or "MainWindow", Visible = true,
		MenuKey = o.MenuKey or Enum.KeyCode.RightShift,
	}
	local vp = Gui.AbsoluteSize
	local size = o.Size or Vector2.new(560, 752)
	size = Vector2.new(math.min(size.X, math.max(vp.X * 0.94, 320)), math.min(size.Y, math.max(vp.Y * 0.9, 300)))
	if o.Watermark == false then self:SetWatermarkVisible(false) end
	if o.Hotkeys == false then self:SetHotkeysVisible(false) end
	if o.WatermarkTitle then self:SetWatermarkTitle(o.WatermarkTitle) end

	local main = New("Frame", {
		Name = "Window", Size = UDim2.fromOffset(size.X, size.Y),
		Position = o.Position or UDim2.new(0.5, -size.X / 2, 0.5, -size.Y / 2),
		Parent = Gui, Theme = { BackgroundColor3 = "Background" },
	}, { Corner(10), Stroke(nil, true) })
	W._scale = RegisterScale(main)
	RegisterSurface(main, "Window", 10)
	W.Frame = main

	local header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), Parent = main })
	local titleRow = New("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(0.7, 0, 1, 0), Parent = header,
	}, { List(10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local titleLabel = New("TextLabel", {
		Text = W.Title, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), TextSize = 13,
		TextColor3 = self.Theme.Text, LayoutOrder = 1, Parent = titleRow,
	})
	local pills = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 21), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2,
		Parent = titleRow,
	}, { List(4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local tag = PillSpec(o.Tag, self.Theme.Success)
	if tag then Pill(pills, tag.Text, tag.Color, 1) end
	local ver = PillSpec(o.Version, self.Theme.Danger)
	if ver then Pill(pills, ver.Text, ver.Color, 2) end
	local subtitle = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 0), Size = UDim2.new(0.3, 0, 1, 0),
		Text = o.Subtitle or "", TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = self.Theme.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Parent = header,
	})
	MakeDraggable(header, main)

	local tabbar = New("ScrollingFrame", {
		Position = UDim2.fromOffset(17, 49), Size = UDim2.new(1, -34, 0, 28), BackgroundTransparency = 1,
		ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X, Parent = main,
	}, { List(5, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })

	-- the active-tab highlight is one pill that slides between tabs
	local indHolder = New("Frame", {
		BackgroundTransparency = 1, Position = tabbar.Position, Size = tabbar.Size, ClipsDescendants = true, ZIndex = 0, Parent = main,
	})
	-- hover ghost: a faint pill under the tab you're pointing at
	local ghost = New("Frame", {
		Size = UDim2.fromOffset(0, 28), BackgroundTransparency = 1, ZIndex = 0, Parent = indHolder, Theme = { BackgroundColor3 = "ControlHover" },
	}, { Corner(7) })
	local ind = New("Frame", {
		Size = UDim2.fromOffset(0, 28), BackgroundTransparency = 1, ZIndex = 0, Parent = indHolder, Theme = { BackgroundColor3 = "TabActive" },
	}, { Corner(7) })
	-- the pill: soft top sheen, a hairline accent border and a small glowing accent underline
	New("UIStroke", { Thickness = 1, Transparency = 0.55, Parent = ind, Theme = { Color = "AccentBorder" } })
	New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 0, Parent = ind }, {
		Corner(7), New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.93), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	local under = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(0.42, 0, 0, 2), ZIndex = 1, Parent = ind,
	}, { CornerFixed(1) })
	AccentOverlay(under, 1, true)
	Glow(under, "Accent", 1, true):Set(0.8)
	local indTween = nil
	local function Ghost(t)
		if not t or t == W.Active or not t.Button.Parent then
			Tween(ghost, 0.18, { BackgroundTransparency = 1 })
			return
		end
		local sc = (W._scale and W._scale.Scale) or Lumen.Scale
		if sc <= 0 then return end
		local b = t.Button
		local pos = UDim2.fromOffset((b.AbsolutePosition.X - indHolder.AbsolutePosition.X) / sc, 0)
		local size = UDim2.fromOffset(b.AbsoluteSize.X / sc, 28)
		if ghost.BackgroundTransparency > 0.95 then ghost.Position, ghost.Size = pos, size end
		TweenService:Create(ghost, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Position = pos, Size = size, BackgroundTransparency = 0.45 }):Play()
	end

	local content = New("Frame", {
		BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(17, 87),
		Size = UDim2.new(1, -34, 1, -122), Parent = main,
	})
	-- veil used to soften page changes
	local veil = New("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 10, Parent = content,
		Theme = { BackgroundColor3 = "Background" },
	})

	-- footer strip (slightly lighter than the window, soft top edge)
	local footerBar = New("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 32), Parent = main,
		Theme = { BackgroundColor3 = "Group" },
	}, { Corner(10) })
	New("Frame", { Size = UDim2.new(1, 0, 0, 14), Parent = footerBar, Theme = { BackgroundColor3 = "Group" } })
	New("Frame", { Size = UDim2.new(1, 0, 0, 1), Parent = footerBar, Theme = { BackgroundColor3 = "GroupBorder" } })
	MakeDraggable(footerBar, main)
	local footer = New("TextLabel", {
		Size = UDim2.fromScale(1, 1), Text = o.Footer or "", TextSize = 12, Font = Enum.Font.GothamMedium,
		TextColor3 = self.Theme.TextMuted, Parent = footerBar,
	})

	-- resize grip
	local grip = New("TextButton", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4), Size = UDim2.fromOffset(14, 14),
		Text = "", ZIndex = 5, Parent = main,
	}, {
		New("Frame", { Size = UDim2.fromOffset(8, 1), Position = UDim2.new(1, -9, 1, -3), BackgroundColor3 = self.Theme.TextMuted, Rotation = -45, BackgroundTransparency = 0.3 }),
		New("Frame", { Size = UDim2.fromOffset(4, 1), Position = UDim2.new(1, -6, 1, -3), BackgroundColor3 = self.Theme.TextMuted, Rotation = -45, BackgroundTransparency = 0.3 }),
	})
	do
		local resizing, startMouse, startSize = false, nil, nil
		Connect(grip.InputBegan, function(i)
			if IsPress(i) then
				resizing, startMouse, startSize = true, UIS:GetMouseLocation(), main.AbsoluteSize
				ClosePopup()
			end
		end)
		Connect(UIS.InputChanged, function(i)
			if resizing and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				local d = (UIS:GetMouseLocation() - startMouse) / Lumen.Scale
				local base = startSize / Lumen.Scale
				main.Size = UDim2.fromOffset(math.max(400, base.X + d.X), math.max(320, base.Y + d.Y))
			end
		end)
		Connect(UIS.InputEnded, function(i) if IsPress(i) then resizing = false end end)
	end

	-- double-click the title bar to fold the window down to its header (and again to unfold)
	local collapsed, fullSize, lastClick = false, nil, -math.huge
	function W:SetCollapsed(v)
		if v == collapsed then return end
		collapsed = v
		ClosePopup()
		if v then
			fullSize = main.Size
			main.ClipsDescendants = true
			grip.Visible = false
			TweenService:Create(main, TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{ Size = UDim2.new(fullSize.X.Scale, fullSize.X.Offset, 0, 50) }):Play()
		else
			local tw = TweenService:Create(main, TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = fullSize })
			tw:Play()
			task.delay(0.4, function()
				if not collapsed then
					main.ClipsDescendants = false
					grip.Visible = true
				end
			end)
		end
	end
	function W:IsCollapsed() return collapsed end
	Connect(header.InputBegan, function(i)
		if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		local now = os.clock()
		if now - lastClick < 0.32 then
			lastClick = -math.huge
			W:SetCollapsed(not collapsed)
		else
			lastClick = now
		end
	end)

	function W:SetTitle(t) self.Title = t; titleLabel.Text = t end
	function W:SetSubtitle(t) subtitle.Text = t end
	function W:SetFooter(t) footer.Text = t end

	local function MoveIndicator(instant)
		local t = W.Active
		if not t or t.Hidden or not t.Button.Parent then
			Tween(ind, 0.15, { BackgroundTransparency = 1 })
			return
		end
		local sc = (W._scale and W._scale.Scale) or Lumen.Scale
		if sc <= 0 then return end
		local b = t.Button
		local x = (b.AbsolutePosition.X - indHolder.AbsolutePosition.X) / sc
		local w = b.AbsoluteSize.X / sc
		local goal = { Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(w, 28), BackgroundTransparency = 0 }
		if instant then
			if indTween then return end
			ind.Position, ind.Size, ind.BackgroundTransparency = goal.Position, goal.Size, 0
		else
			if indTween then indTween:Cancel() end
			indTween = TweenService:Create(ind, TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal)
			local mine = indTween
			indTween.Completed:Connect(function() if indTween == mine then indTween = nil end end)
			indTween:Play()
			task.delay(0.4, function() if indTween == mine then indTween = nil end end)
		end
	end
	W._MoveIndicator = MoveIndicator
	Connect(tabbar:GetPropertyChangedSignal("CanvasPosition"), function() MoveIndicator(true) end)

	function W:_StyleTabs(skipPages)
		for _, t in ipairs(self.Tabs) do
			local on = (t == self.Active) and not t.Hidden
			if not skipPages then t.Page.Visible = on end
			t.Button.BackgroundTransparency = 1
			Tween(t.Button, 0.18, { TextColor3 = on and Lumen.Theme.AccentText or Lumen.Theme.TextDim })
		end
		MoveIndicator(false)
	end

	local TabToken = 0
	local function IndexOf(t) for i, x in ipairs(W.Tabs) do if x == t then return i end end return 0 end
	-- switching tabs: the highlight slides over, the old page drifts out under a soft veil, the new one slides in
	function W:SelectTab(t)
		if t.Hidden then return end
		ClosePopup()
		local prev = self.Active
		self.Active = t
		TabToken = TabToken + 1
		local mine = TabToken
		Ghost(nil)
		self:_StyleTabs(true)
		local function Finish()
			for _, x in ipairs(self.Tabs) do
				if x ~= t then x.Page.Visible = false x.Page.Position = UDim2.new() end
			end
			t.Page.Visible = true
			if t._Relayout then t._Relayout() end
		end
		if prev and prev ~= t and prev.Page.Parent and main.Visible then
			local dir = IndexOf(t) >= IndexOf(prev) and 1 or -1
			veil.Visible = true
			TweenService:Create(veil, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0.2 }):Play()
			TweenService:Create(prev.Page, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(-dir * 14, 0) }):Play()
			task.delay(0.1, function()
				if mine ~= TabToken then return end
				Finish()
				t.Page.Position = UDim2.fromOffset(dir * 22, 0)
				TweenService:Create(t.Page, TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new() }):Play()
				TweenService:Create(veil, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
				task.delay(0.27, function() if mine == TabToken then veil.Visible = false end end)
			end)
		else
			Finish()
			t.Page.Position = UDim2.new()
		end
		if t.OnSelect then SafeCall("tab '" .. tostring(t.Name) .. "' OnSelect", t.OnSelect) end
		Lumen.Events.TabChanged:Fire(t.Name, W)
	end

	-- next / previous visible tab (Ctrl+Tab and Ctrl+Shift+Tab call these)
	function W:CycleTab(step)
		local list = {}
		for _, x in ipairs(self.Tabs) do if not x.Hidden then table.insert(list, x) end end
		if #list == 0 then return end
		local cur = table.find(list, self.Active) or 1
		self:SelectTab(list[((cur - 1 + step) % #list) + 1])
	end
	table.insert(Refreshers, function() W:_StyleTabs() end)

	function W:SetTabVisible(name, v)
		for _, t in ipairs(self.Tabs) do
			if t.Name == name then t:SetVisible(v) end
		end
	end

	local VisToken = 0
	-- opening pops the window up from 94%, closing shrinks it away before hiding
	function W:SetVisible(v)
		if self.Visible == v and main.Visible == v then return end
		self.Visible = v
		VisToken = VisToken + 1
		local mine = VisToken
		local sc = self._scale
		if v then
			main.Visible = true
			if sc then
				sc.Scale = Lumen.Scale * 0.94
				TweenService:Create(sc, TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = Lumen.Scale }):Play()
			end
			task.delay(0.36, function() if mine == VisToken then MoveIndicator(true) end end)
		else
			ClosePopup()
			HideHint()
			if sc then
				TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = Lumen.Scale * 0.94 }):Play()
				task.delay(0.17, function()
					if mine == VisToken and not self.Visible then
						main.Visible = false
						sc.Scale = Lumen.Scale
					end
				end)
			else
				main.Visible = false
			end
		end
		Lumen:_UpdateSnow()
		Lumen.Events.VisibilityChanged:Fire(v, W)
	end
	function W:Toggle() self:SetVisible(not self.Visible) end
	function W:Destroy()
		ClosePopup()
		main:Destroy()
		for i, w in ipairs(Lumen.Windows) do if w == self then table.remove(Lumen.Windows, i) break end end
		Lumen:_UpdateSnow()
	end

	function W:AddTab(name)
		local T = { Name = name, Window = W, _flip = false, Boxes = {}, Sections = {}, Fill = o.Fill ~= false }
		T.Button = New("TextButton", {
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), BackgroundTransparency = 1,
			Text = name, TextColor3 = Lumen.Theme.TextDim, LayoutOrder = #W.Tabs + 1, Parent = tabbar,
			Theme = { BackgroundColor3 = "TabActive" },
		}, { Corner(7), Pad(11, 0, 11, 0) })
		T.Page = New("ScrollingFrame", {
			Visible = false, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 2,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = content,
			Theme = { ScrollBarImageColor3 = "AccentBorder" },
		}, { List(8) })
		local banners = New("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 0, Visible = false, Parent = T.Page,
		}, { List(6) })
		local columns = New("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1, Parent = T.Page,
		}, { List(8, Enum.FillDirection.Horizontal) })
		local function Column(order)
			return New("Frame", {
				BackgroundTransparency = 1, Size = UDim2.new(0.5, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = order, Parent = columns,
			}, { List(8) })
		end
		local left, right = Column(1), Column(2)

		-- Fill layout (as in the reference): boxes in a column share the page height equally, and grow if their content is taller
		local function Relayout()
			local avail = T.Page.AbsoluteSize.Y
			if banners.Visible then avail = avail - banners.AbsoluteSize.Y - 8 end
			for _, col in ipairs({ left, right }) do
				local vis = {}
				for _, b in ipairs(T.Boxes) do
					if b.Col == col and b.Frame.Parent and b.Frame.Visible then table.insert(vis, b) end
				end
				local n = #vis
				for _, b in ipairs(vis) do
					local mh = 0
					if T.Fill and n > 0 then mh = math.max(0, math.floor((avail - (n - 1) * 8) / n)) end
					b.Constraint.MinSize = Vector2.new(0, mh)
				end
			end
		end
		T._Relayout = Relayout
		Connect(T.Page:GetPropertyChangedSignal("AbsoluteSize"), Relayout)

		local function PickColumn(side)
			if side == "Right" or side == 2 then return right end
			if side == "Left" or side == 1 then return left end
			T._flip = not T._flip
			return T._flip and left or right
		end

		local function NewBox(side)
			local col = PickColumn(side)
			local constraint = New("UISizeConstraint", {})
			local frame = New("Frame", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = col,
				Theme = { BackgroundColor3 = "Group" },
			}, { Corner(7), Stroke("GroupBorder"), Pad(6, 6, 6, 8), List(6), constraint })
			table.insert(T.Boxes, { Frame = frame, Constraint = constraint, Col = col })
			Relayout()
			return frame
		end

		-- AddGroup("Title", "Left")  or  AddGroup({Title = "Auto Parry", Icon = "command", Side = "Left"})
		function T:AddGroup(title, side)
			local icon
			if type(title) == "table" then title, side, icon = title.Title, title.Side or side, title.Icon end
			local frame = NewBox(side)
			if title then
				local titleRow = New("Frame", {
					BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 0, Parent = frame,
				}, { Pad(6, 0, 0, 0), List(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
				if icon then
					local ic = Icon(icon, titleRow, 15, "Label")
					ic.LayoutOrder = 1
				end
				New("TextLabel", {
					Text = title, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), LayoutOrder = 2, Parent = titleRow,
				})
			end
			local c = New("Frame", {
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1, Parent = frame,
			}, { Pad(6, 4, 6, 0), List(5) })
			local g = NewGroupObject(c, frame, W.Id .. "/" .. name .. "/" .. (title or "Group"), T)
			table.insert(T.Sections, {
				Get = function() return title or "Group" end,
				Set = function(v) g:SetVisible(v) end,
				IsVisible = function() return frame.Visible end,
			})
			return g
		end

		function T:AddTabbox(side)
			local frame = NewBox(side)
			local barWrap = New("Frame", {
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0, Parent = frame,
			})
			local subInd = New("Frame", {
				Size = UDim2.fromOffset(0, 24), BackgroundTransparency = 1, ZIndex = 0, Parent = barWrap, Theme = { BackgroundColor3 = "TabActive" },
			}, { Corner(6) })
			New("UIStroke", { Thickness = 1, Transparency = 0.6, Parent = subInd, Theme = { Color = "AccentBorder" } })
			New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 0, Parent = subInd }, {
				Corner(6), New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.93), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 1) }) }),
			})
			local bar = New("Frame", {
				BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = barWrap,
			}, { List(3, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
			local body = New("Frame", {
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true,
				LayoutOrder = 1, Parent = frame,
			})
			local bodyVeil = New("Frame", {
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 10, Parent = body,
				Theme = { BackgroundColor3 = "Group" },
			})
			local Box, subs, active = { Frame = frame }, {}, nil
			local subTween
			local function MoveSub(instant)
				if not active or not active.Button.Parent then
					Tween(subInd, 0.15, { BackgroundTransparency = 1 })
					return
				end
				local sc = (W._scale and W._scale.Scale) or Lumen.Scale
				if sc <= 0 then return end
				local b = active.Button
				local goal = {
					Position = UDim2.fromOffset((b.AbsolutePosition.X - barWrap.AbsolutePosition.X) / sc, 0),
					Size = UDim2.fromOffset(b.AbsoluteSize.X / sc, 24), BackgroundTransparency = 0,
				}
				if instant then
					if subTween then return end
					subInd.Position, subInd.Size, subInd.BackgroundTransparency = goal.Position, goal.Size, 0
				else
					if subTween then subTween:Cancel() end
					local tw = TweenService:Create(subInd, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal)
					subTween = tw
					tw:Play()
					task.delay(0.32, function() if subTween == tw then subTween = nil end end)
				end
			end
			local function Style()
				for _, sub in ipairs(subs) do
					local on = (sub == active)
					sub.Container.Visible = on
					sub.Button.BackgroundTransparency = 1
					Tween(sub.Button, 0.15, { TextColor3 = on and Lumen.Theme.AccentText or Lumen.Theme.Label })
				end
				MoveSub(false)
			end
			local SubToken = 0
			local function SelectSub(sub)
				if sub == active or sub.Hidden then return end
				ClosePopup()
				local prev = active
				active = sub
				SubToken = SubToken + 1
				local mine = SubToken
				for _, x in ipairs(subs) do
					Tween(x.Button, 0.15, { TextColor3 = (x == active) and Lumen.Theme.AccentText or Lumen.Theme.Label })
				end
				MoveSub(false)
				if not prev or not prev.Container.Parent then Style() return end
				local dir = (table.find(subs, sub) or 0) >= (table.find(subs, prev) or 0) and 1 or -1
				bodyVeil.Visible = true
				TweenService:Create(bodyVeil, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0 }):Play()
				task.delay(0.09, function()
					if mine ~= SubToken then return end
					for _, x in ipairs(subs) do x.Container.Visible = (x == active) end
					sub.Container.Position = UDim2.fromOffset(dir * 16, 0)
					TweenService:Create(sub.Container, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new() }):Play()
					TweenService:Create(bodyVeil, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
					task.delay(0.23, function() if mine == SubToken then bodyVeil.Visible = false end end)
				end)
			end
			local function PickActive()
				if active and not active.Hidden then return end
				active = nil
				for _, sub in ipairs(subs) do
					if not sub.Hidden then active = sub break end
				end
			end
			table.insert(Refreshers, Style)
			function Box:SetVisible(v)
				frame.Visible = v
				Relayout()
			end
			table.insert(T.Sections, {
				Get = function()
					local names = {}
					for _, sub in ipairs(subs) do table.insert(names, sub.Name) end
					return #names > 0 and table.concat(names, "/") or "Tabbox"
				end,
				Set = function(v) Box:SetVisible(v) end,
				IsVisible = function() return frame.Visible end,
			})
			function Box:AddTab(tabName)
				local sub = { Name = tabName }
				sub.Button = SubTabButton(bar, tabName, #subs + 1)
				sub.Container = New("Frame", {
					BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
					Visible = false, Parent = body,
				}, { Pad(6, 6, 6, 0), List(5) })
				table.insert(subs, sub)
				Connect(sub.Button.MouseButton1Click, function() SelectSub(sub) end)
				Connect(sub.Button:GetPropertyChangedSignal("AbsoluteSize"), function() if active == sub then MoveSub(true) end end)
				Connect(sub.Button:GetPropertyChangedSignal("AbsolutePosition"), function() if active == sub then MoveSub(true) end end)
				if not active then active = sub end
				Style()
				task.defer(function() MoveSub(true) end)
				local g = NewGroupObject(sub.Container, frame, W.Id .. "/" .. name .. "/" .. tabName, T)
				g._activate = function() SelectSub(sub) end
				function g:SetVisible(v)
					sub.Hidden = not v
					sub.Button.Visible = v
					if not v and active == sub then active = nil end
					if v and not active then active = sub end
					PickActive()
					Style()
				end
				function g:Destroy()
					for i, s in ipairs(subs) do if s == sub then table.remove(subs, i) break end end
					sub.Button:Destroy()
					sub.Container:Destroy()
					if active == sub then active = nil end
					PickActive()
					Style()
				end
				return g
			end
			return Box
		end

		function T:AddWarning(wo)
			if type(wo) == "string" then wo = { Text = wo } end
			local color = wo.Type and Lumen.Theme[wo.Type] or Lumen.Theme.Text
			banners.Visible = true
			local f = New("Frame", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = #banners:GetChildren(), Parent = banners, Theme = { BackgroundColor3 = "Group" },
			}, { Corner(7), Stroke("GroupBorder"), Pad(14, 9, 14, 10), List(2) })
			local tl = wo.Title and New("TextLabel", {
				Text = wo.Title, Size = UDim2.new(1, 0, 0, 16), TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = f,
			})
			local bl = New("TextLabel", {
				Text = wo.Text or "", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 11,
				TextColor3 = Lumen.Theme.Label:Lerp(Lumen.Theme.Background, 0.12), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
				Font = Enum.Font.GothamMedium, LayoutOrder = 2, Parent = f,
			})
			Relayout()
			return {
				SetText = function(_, t) bl.Text = t end,
				SetTitle = function(_, t) if tl then tl.Text = t end end,
				SetVisible = function(_, v) f.Visible = v Relayout() end,
				Destroy = function() f:Destroy() Relayout() end,
			}
		end

		-- hide / show / remove a whole tab
		function T:SetVisible(v)
			T.Hidden = not v
			T.Button.Visible = v
			if not v and W.Active == T then
				W.Active = nil
				for _, t in ipairs(W.Tabs) do
					if not t.Hidden then W:SelectTab(t) break end
				end
			end
			if v and not W.Active then W:SelectTab(T) end
			W:_StyleTabs()
		end
		function T:Destroy()
			for i, t in ipairs(W.Tabs) do if t == T then table.remove(W.Tabs, i) break end end
			T.Button:Destroy()
			T.Page:Destroy()
			if W.Active == T then
				W.Active = nil
				for _, t in ipairs(W.Tabs) do
					if not t.Hidden then W:SelectTab(t) break end
				end
			end
		end

		Connect(T.Button.MouseButton1Click, function() W:SelectTab(T) end)
		Connect(T.Button.MouseEnter, function()
			if W.Active ~= T then Tween(T.Button, 0.12, { TextColor3 = Lumen.Theme.Label }) end
			Ghost(T)
		end)
		Connect(T.Button.MouseLeave, function()
			if W.Active ~= T then Tween(T.Button, 0.12, { TextColor3 = Lumen.Theme.TextDim }) end
			Ghost(nil)
		end)
		Connect(T.Button:GetPropertyChangedSignal("AbsoluteSize"), function() if W.Active == T then MoveIndicator(true) end end)
		Connect(T.Button:GetPropertyChangedSignal("AbsolutePosition"), function() if W.Active == T then MoveIndicator(true) end end)
		table.insert(W.Tabs, T)
		if not W.Active then W:SelectTab(T) task.defer(function() MoveIndicator(true) end) end
		return T
	end

	-- Ready-made settings tab: everything adjustable from the UI (menu, effects, layout, theme, configs)
	function W:AddConfigTab(name, copts)
		local tab = self:AddTab(name or "Config")
		tab.Fill = false

		local menu = tab:AddGroup("Menu", "Left")
		menu:AddLabel({ Text = "Menu keybind", Description = "The key that shows and hides the whole menu. Click the chip, then press a new key." }):AddKeybind({
			Default = self.MenuKey, Mode = "Press", Flag = "Lumen_MenuKey", ShowInList = false,
			ChangedCallback = function(k) if k then W.MenuKey = k end end,
		})
		menu:AddToggle({ Text = "Show dock", Default = Lumen.ShowDock, Flag = "Lumen_Dock",
			Description = "The icon bar at the top of the screen. It stays visible when the menu is hidden, so you can reopen the menu with a click.",
			Callback = function(v) Lumen:SetDockVisible(v) end })
		menu:AddToggle({ Text = "Show watermark", Default = Lumen.ShowWatermark, Flag = "Lumen_Watermark",
			Description = "The bar in the top-left corner showing the script name, your username, FPS and ping.",
			Callback = function(v) Lumen:SetWatermarkVisible(v) end })
		menu:AddToggle({ Text = "Show hotkey list", Default = Lumen.ShowHotkeys, Flag = "Lumen_Hotkeys",
			Description = "A small panel listing every keybind and whether it is currently active.",
			Callback = function(v) Lumen:SetHotkeysVisible(v) end })
		menu:AddToggle({ Text = "Notifications", Default = Lumen.ShowNotifications, Flag = "Lumen_Notifs",
			Description = "Turns every pop-up message on or off. Errors are still printed to the console.",
			Callback = function(v) Lumen.ShowNotifications = v end })
		menu:AddDropdown({ Text = "Notification position", Values = Lumen.NotifyPositions, Default = Lumen.NotifyPosition, Flag = "Lumen_NotifyPos",
			Description = "Which corner of the screen messages slide in from.",
			Callback = function(v) if v then Lumen:SetNotifyPosition(v) end end })
		menu:AddToggle({ Text = "Hover explanations", Default = Lumen.Hints, Flag = "Lumen_Hints",
			Description = "Shows a short explanation, like this one, when you rest the mouse on a setting.",
			Callback = function(v) Lumen.Hints = v if not v then HideHint() end end })
		menu:AddToggle({ Text = "Script error alerts", Default = Lumen.NotifyErrors, Flag = "Lumen_NotifyErrors",
			Description = "If a feature's code crashes, show a red notification with the error instead of failing silently. Errors are always printed to the console.",
			Callback = function(v) Lumen.NotifyErrors = v end })
		menu:AddSlider({ Text = "UI scale", Min = 0.7, Max = 1.4, Default = Lumen.Scale, Increment = 0.05, Suffix = "x",
			Description = "Makes the menu, panels and pop-ups bigger or smaller. Handy on small screens or 4K monitors.",
			Flag = "Lumen_Scale", Callback = function(v) Lumen:SetScale(v) end })
		Lumen._fontDropdown = menu:AddDropdown({ Text = "Font",
			Values = { "Inter", "Gotham", "Mono", "Michroma", "Jura", "Merriweather", "FredokaOne", "Arcade", "TitilliumWeb", "Oswald", "Ubuntu", "Nunito", "SourceSans",
				"PatrickHand", "SpecialElite", "Sarpanch", "Creepster", "Fondamento" },
			Default = Lumen.FontName,
			Description = "The typeface used everywhere. Themes pick one automatically; choose here to override it.",
			Callback = function(v)
				if v == "Inter" and not Lumen._interAsset then
					Lumen:Notify({ Title = "Font", Content = "Inter needs file support in your executor. Using Gotham.", Type = "Warning" })
				end
				if v then Lumen:SetFont(v, 0.35) end
			end })
		menu:AddInput({ Text = "Screen watermark", Placeholder = "text tiled over the screen (empty = off)",
			Description = "Faint text tiled over the whole screen, e.g. your name, to discourage reposted screenshots.",
			Callback = function(v) Lumen:SetScreenWatermark(v) end })
		menu:AddDivider()
		menu:AddButton({ Text = "Unload", Description = "Removes the interface and stops everything it was doing.",
			Confirm = { Title = "Unload Lumen?", Text = "This removes the whole interface until you run the script again.", Type = "Danger", Confirm = "Unload" },
			Callback = function() Lumen:Unload() end })

		local fx = tab:AddGroup("Effects", "Left")
		fx:AddToggle({ Text = "Particles", Default = Snow.Enabled, Flag = "Lumen_Snow",
			Description = "Animated shapes drifting behind the menu while it is open.",
			Callback = function(v) Lumen:SetSnow(v) end })
		table.insert(Lumen._particleDropdowns, fx:AddDropdown({ Text = "Particle style", Values = Lumen.ParticleKinds, Default = Snow.Kind, Flag = "Lumen_Particles",
			Description = "\"Theme\" uses whatever the current theme ships with. Pick another to mix and match; switching crossfades.",
			Callback = function(v) if v then Lumen:SetSnowOptions({ Kind = v }) end end }))
		fx:AddSlider({ Text = "Amount", Min = 10, Max = 200, Default = Snow.Count, Flag = "Lumen_SnowCount",
			Description = "How many particles are on screen. Lower it if your frame rate drops.",
			Callback = function(v) Lumen:SetSnowOptions({ Count = v }) end })
		fx:AddSlider({ Text = "Speed", Min = 0.2, Max = 3, Default = Snow.Speed, Increment = 0.1, Suffix = "x",
			Description = "How fast particles move and twinkle.",
			Flag = "Lumen_SnowSpeed", Callback = function(v) Lumen:SetSnowOptions({ Speed = v }) end })
		fx:AddSlider({ Text = "Backdrop dim", Min = 0, Max = 90, Default = math.floor(Backdrop.Dim * 100), Suffix = "%",
			Description = "How much the game behind the menu is darkened while the menu is open.",
			Flag = "Lumen_Dim", Callback = function(v) Lumen:SetBackdrop({ Dim = v / 100 }) end })
		fx:AddSlider({ Text = "Backdrop blur", Min = 0, Max = 40, Default = Backdrop.Blur,
			Description = "How much the game behind the menu is blurred while the menu is open. 0 turns it off.",
			Flag = "Lumen_Blur", Callback = function(v) Lumen:SetBackdrop({ Blur = v }) end })

		-- HUD pieces glide back to their spot after you drag them
		local hud = tab:AddGroup("HUD Positions", "Left")
		local sb = Lumen.SnapBack
		hud:AddToggle({ Text = "Return to place after dragging", Default = sb.Enabled, Flag = "Lumen_Snap",
			Description = "After you drag the dock or hotkey list somewhere, it glides back to its spot after a few seconds.",
			Callback = function(v) sb.Enabled = v end })
		hud:AddSlider({ Text = "Return after", Min = 1, Max = 30, Default = sb.Delay, Suffix = "s", Flag = "Lumen_SnapDelay",
			Description = "How many seconds a moved panel waits before gliding back.",
			Callback = function(v) sb.Delay = v end })
		hud:AddToggle({ Text = "Dock", Default = sb.Dock, Flag = "Lumen_SnapDock", Description = "Whether the dock glides back after you move it.",
			Callback = function(v) sb.Dock = v end })
		hud:AddToggle({ Text = "Hotkey list", Default = sb.Hotkeys, Flag = "Lumen_SnapHotkeys", Description = "Whether the hotkey list glides back after you move it.",
			Callback = function(v) sb.Hotkeys = v end })
		hud:AddToggle({ Text = "Watermark", Default = sb.Watermark, Flag = "Lumen_SnapWatermark", Description = "Whether the watermark glides back after you move it.",
			Callback = function(v) sb.Watermark = v end })
		hud:AddButton({ Text = "Return now", Description = "Glide every moved panel back to its home spot right away.", Callback = function() Lumen:ResetHudPositions() end })
			:AddSubButton({ Text = "Set as home", Callback = function()
				Lumen:SetHudHome()
				Lumen:Notify({ Title = "HUD", Content = "Current positions saved as home.", Type = "Success" })
			end })

		-- turn tabs, sections, panels and dock buttons on or off: three multi-select dropdowns (ticked = shown)
		local layout = tab:AddGroup("Layout", "Left")
		local maps = { Tabs = {}, Sections = {}, Extras = {} }
		local drops = {}
		local function Apply(kind, picked)
			for label, e in pairs(maps[kind]) do
				local want = picked[label] == true
				if e.Get() ~= want then e.Set(want) end
			end
		end
		drops.Tabs = layout:AddDropdown({ Text = "Visible tabs", Multi = true, Values = {},
			Description = "Tick the tabs you want in the tab bar. Unticked tabs are hidden, not deleted.",
			Callback = function(v) Apply("Tabs", v) end })
		drops.Sections = layout:AddDropdown({ Text = "Visible sections", Multi = true, Values = {},
			Description = "Every group and tabbox, listed as Tab / Section. Untick one to hide it.",
			Callback = function(v) Apply("Sections", v) end })
		drops.Extras = layout:AddDropdown({ Text = "Panels & dock buttons", Multi = true, Values = {},
			Description = "Floating panels (credits, previews...) and the buttons on the dock.",
			Callback = function(v) Apply("Extras", v) end })
		local function RefreshLayout()
			maps = { Tabs = {}, Sections = {}, Extras = {} }
			for _, t in ipairs(W.Tabs) do
				if t ~= tab then
					maps.Tabs[t.Name] = { Get = function() return not t.Hidden end, Set = function(v) t:SetVisible(v) end }
					for _, sec in ipairs(t.Sections) do
						maps.Sections[t.Name .. " / " .. sec.Get()] = { Get = sec.IsVisible, Set = sec.Set }
					end
				end
			end
			for _, pnl in ipairs(Lumen._Panels) do
				maps.Extras["Panel: " .. pnl.Name] = { Get = function() return pnl.Frame.Visible end, Set = function(v) pnl:SetVisible(v) end }
			end
			for _, e in ipairs(Lumen:GetDockButtons()) do
				maps.Extras["Dock: " .. e.Name] = { Get = function() return e.Button.Visible end, Set = function(v) e.Button.Visible = v end }
			end
			for kind, d in pairs(drops) do
				local list, picked = {}, {}
				for label, e in pairs(maps[kind]) do
					table.insert(list, label)
					if e.Get() then picked[label] = true end
				end
				table.sort(list)
				d:SetValues(list)
				d:Set(picked, true)
			end
		end
		tab.OnSelect = RefreshLayout
		RefreshLayout()

		local th = tab:AddGroup("Theme", "Right")
		local pickers = {}
		local function SyncPickers()
			for k, pk in pairs(pickers) do pk:Set(Lumen.Theme[k], true) end
		end
		local names = {}
		for n in pairs(Lumen.Presets) do table.insert(names, PresetLabel(n)) end
		table.sort(names, function(x, y)
			if x == "Lavender (Default)" then return true elseif y == "Lavender (Default)" then return false end
			return x < y
		end)
		local DESCRIPTIONS = {
			Lavender = "The reference look: soft lilac, snow.",
			Ocean = "Rounder, deep-water glow, rising bubbles.",
			Rose = "Extra round and glowy, drifting petals.",
			Emerald = "Aurora band up top, fireflies.",
			Sunset = "Warm glow from below, rising embers.",
			Mono = "Sharp corners, no glow, monospace, scanlines, glyph rain.",
			Synthwave = "Neon pink and cyan, wide futuristic type, a spinning neon border, rising light streaks.",
			Frost = "Pale ice, thin rounded type, a frosted double border, spinning ice crystals.",
			Royal = "Midnight navy and gold, serif type, a gilded double border, glinting sparkles.",
			Candy = "Bubblegum pastels, a soft rounded font, extra-round shapes, tumbling confetti.",
			Arcade = "8-bit pixel font, square corners, a thick yellow border, CRT scanlines, stepping pixels.",
			Cosmos = "Deep space, a violet nebula band, a slowly turning aurora border, stars and shooting stars.",
			Storm = "Slate and steel, condensed type, slanted rain and distant lightning.",
			Blueprint = "Drafting paper: navy blue, a white grid, a ruled double border, handwritten labels, drafting marks.",
			Noir = "Film noir: black, white and one red, typewriter type, a dark vignette and flickering film grain.",
			Prism = "A turning rainbow border, accents that cycle through the spectrum, rising glass shards.",
			Hazard = "Industrial yellow and black, a striped warning-tape border, square corners, welding sparks.",
			Glass = "See-through frosted surfaces over a blurred world, soft rounded type, drifting bokeh lights.",
			Haunted = "Pumpkin orange on midnight purple, dripping type, ghostly green fog, bats overhead.",
			Parchment = "A light theme: aged paper, ink-brown text, a wax-seal red accent, calligraphy, falling leaves.",
		}
		local desc
		local presetDrop = th:AddDropdown({ Text = "Preset", Values = names, Default = PresetLabel(Lumen.Preset), Flag = "Lumen_Preset",
			Description = "A complete look: colours, corner shape, glow, font, window lighting and particles.",
			Callback = function(v)
				if v then
					Lumen:ApplyPreset(v)
					SyncPickers()
					if desc then desc:SetText(DESCRIPTIONS[PresetName(v)] or "") end
				end
			end })
		table.insert(Lumen._presetDropdowns, presetDrop)
		desc = th:AddLabel(DESCRIPTIONS[Lumen.Preset] or "", { Dim = true })
		Lumen._presetDescriptions = DESCRIPTIONS
		th:AddSlider({ Text = "Theme fade", Min = 0, Max = 1.5, Default = Lumen.ThemeTransition, Increment = 0.05, Suffix = "s",
			Description = "How long switching themes takes. Colours, corners, glow, fonts and particles all blend over this time. 0 makes theme changes instant.",
			Flag = "Lumen_ThemeFade", Callback = function(v) Lumen.ThemeTransition = v end })
		for _, entry in ipairs({ { "Accent", "Accent" }, { "Background", "Window" }, { "Group", "Panels" },
			{ "Control", "Controls" }, { "Outline", "Outlines" }, { "Border", "Borders" },
			{ "Text", "Text" }, { "Label", "Labels" }, { "TextDim", "Dim text" } }) do
			local key, label = entry[1], entry[2]
			pickers[key] = th:AddLabel(label):AddColorPicker({
				Default = Lumen.Theme[key], Flag = "Lumen_Theme_" .. key,
				Title = label, Description = "Fine-tune one colour of the current theme. Picking a preset resets it.",
				Callback = function(c) Lumen:SetTheme({ [key] = c }) end,
			})
		end
		th:AddButton({ Text = "Reset theme", Description = "Go back to the default Lavender look.", Callback = function()
			Lumen:ApplyPreset("Lavender")
			SyncPickers()
			if desc then desc:SetText(DESCRIPTIONS.Lavender) end
		end })

		local tests = tab:AddGroup("Tests", "Right")
		tests:AddButton({ Text = "Success", Callback = function()
			Lumen:Notify({ Title = "Success", Content = "Settings applied and saved.", Type = "Success" })
		end }):AddSubButton({ Text = "Warning", Callback = function()
			Lumen:Notify({ Title = "Warning", Content = "This feature can be unstable in some games.", Type = "Warning" })
		end })
		tests:AddButton({ Text = "Error", Callback = function()
			Lumen:Notify({ Title = "Error", Content = "Couldn't reach the server. Try again in a moment.", Type = "Error" })
		end }):AddSubButton({ Text = "Info", Callback = function()
			Lumen:Notify({ Title = "Info", Content = "Press Ctrl+K to search every option.", Type = "Info" })
		end })
		tests:AddButton({ Text = "Loading -> Done", Callback = function()
			local n = Lumen:Notify({ Title = "Loading", Content = "Fetching your config...", Type = "Loading" })
			task.delay(2, function() n:Update({ Title = "Done", Content = "Config loaded.", Type = "Success" }) end)
		end }):AddSubButton({ Text = "Plain", Callback = function() Lumen:Notify("test notif") end })
		tests:AddButton({ Text = "With actions", Description = "A notification with buttons inside it.", Callback = function()
			Lumen:Notify({ Title = "Config changed", Content = "You switched to a new theme.", Type = "Info", Duration = 8,
				Actions = {
					{ Text = "Undo", Callback = function() Lumen:ApplyPreset("Lavender") end },
					{ Text = "Keep", Callback = function() end },
				} })
		end }):AddSubButton({ Text = "Script error", Description = "Shows what happens when a feature's code crashes.", Callback = function()
			error("this is a test error")
		end })
		tests:AddButton({ Text = "Test confirmation", Callback = function()
			Lumen:Confirm({
				Title = "Run the confirmation test?", Type = "Warning", Confirm = "Confirm", Hold = 1,
				Text = "This is how confirmations look. Hold the button for a second to confirm, or press Esc to cancel.",
				Callback = function(ok)
					Lumen:Notify({ Title = ok and "Confirmed" or "Cancelled", Content = ok and "You held it. Nicely done." or "Nothing happened.",
						Type = ok and "Success" or "Info" })
				end,
			})
		end })

		local cfg = tab:AddGroup("Configs", "Right")
		local nameInput = cfg:AddInput({ Text = "Config name", Placeholder = "my-config", Realtime = true })
		local list = cfg:AddDropdown({ Text = "Saved configs", Values = Lumen:ListConfigs() })
		local autoLabel = cfg:AddLabel("Autoload: " .. (Lumen:GetAutoload() or "none"), { Dim = true })

		local function Refresh()
			list:SetValues(Lumen:ListConfigs())
			autoLabel:SetText("Autoload: " .. (Lumen:GetAutoload() or "none"))
		end
		local function Result(ok, err, good)
			Lumen:Notify({ Title = "Config", Content = ok and good or tostring(err), Type = ok and "Success" or "Danger" })
		end

		cfg:AddButton({ Text = "Create / Save", Callback = function()
			local n = nameInput.Value
			if n == "" then n = list.Value or "" end
			local ok, err = Lumen:SaveConfig(n)
			Result(ok, err, "Saved '" .. n .. "'.")
			Refresh()
		end }):AddSubButton({ Text = "Load", Callback = function()
			if not list.Value then return Result(false, "Select a config first") end
			local ok, err = Lumen:LoadConfig(list.Value)
			Result(ok, err, "Loaded '" .. list.Value .. "'.")
			SyncPickers()
		end })
		cfg:AddButton({ Text = "Set autoload", Callback = function()
			if not list.Value then return Result(false, "Select a config first") end
			Lumen:SetAutoload(list.Value)
			Result(true, nil, "'" .. list.Value .. "' will load automatically.")
			Refresh()
		end }):AddSubButton({ Text = "Delete", DoubleClick = true, Callback = function()
			if not list.Value then return Result(false, "Select a config first") end
			local n = list.Value
			local ok, err = Lumen:DeleteConfig(n)
			Result(ok, err, "Deleted '" .. n .. "'.")
			Refresh()
		end })
		if not CanFile() then
			cfg:AddLabel("Your executor has no file functions, so configs cannot be saved.", { Dim = true })
		end
		if copts and copts.Credits then
			local cr = tab:AddGroup("Credits", "Right")
			cr:AddCredits(copts.Credits)
		end
		return tab
	end

	table.insert(Lumen.Windows, W)
	if o.Dock ~= false then Lumen:_InitDock(W, type(o.Dock) == "table" and o.Dock or nil) end

	-- mobile fallback when the dock is disabled
	if o.Dock == false and UIS.TouchEnabled and not UIS.KeyboardEnabled and o.MobileButton ~= false then
		local mb = New("TextButton", {
			Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 14, 0.5, -22), Text = "UI",
			BackgroundTransparency = 0, ZIndex = 20, Parent = Gui, Theme = { BackgroundColor3 = "Group" },
		}, { CornerFixed(22), Stroke("Border") })
		Connect(mb.MouseButton1Click, function() W:Toggle() end)
	end

	if o.Icon then self:SetIcon(o.Icon) end
	if o.ScreenWatermark then self:SetScreenWatermark(o.ScreenWatermark) end
	if o.Backdrop == false then
		Backdrop.Dim, Backdrop.Blur = 0, 0
	elseif type(o.Backdrop) == "table" then
		if o.Backdrop.Dim ~= nil then Backdrop.Dim = o.Backdrop.Dim end
		if o.Backdrop.Blur ~= nil then Backdrop.Blur = o.Backdrop.Blur end
	end
	if o.Snow then
		self:SetSnow(true, type(o.Snow) == "table" and o.Snow or nil)
	else
		self:_UpdateSnow()
	end
	return W
end

------------------------------------------------------------------------------
-- Global input
------------------------------------------------------------------------------

Connect(UIS.InputBegan, function(input, gp)
	-- binding a key
	if Lumen._binding then
		local K = Lumen._binding
		if input.UserInputType == Enum.UserInputType.Keyboard then
			Lumen._binding = nil
			K:SetKey(input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode or nil)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
			Lumen._binding = nil
			K:SetKey(input.UserInputType)
		elseif IsPress(input) then
			Lumen._binding = nil
			K:_Render()
		end
		return
	end


	-- command palette: Escape / arrows while open, Ctrl+K to toggle
	if Lumen:_PaletteKey(input.KeyCode) then return end
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.K
		and (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then
		Lumen:TogglePalette()
		return
	end

	if UIS:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.Tab and (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then
		for _, w in ipairs(Lumen.Windows) do
			if w.Visible then
				w:CycleTab((UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)) and -1 or 1)
				return
			end
		end
	end
	local mouseBtn = input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3
	if mouseBtn and gp then return end

	for _, w in ipairs(Lumen.Windows) do
		if Matches(input, w.MenuKey) then w:Toggle() end
	end
	for _, K in ipairs(Keybinds) do
		if K.Value and K.Mode ~= "Always" and Matches(input, K.Value) then
			if K.Mode == "Press" then
				Fire(K, true)
			elseif K.Mode == "Hold" then
				K:_Apply(true)
			else
				K:_Apply(not K:IsActive())
			end
		end
	end
end)

Connect(UIS.InputEnded, function(input)
	for _, K in ipairs(Keybinds) do
		if K.Mode == "Hold" and K.Value and Matches(input, K.Value) then K:_Apply(false) end
	end
end)

------------------------------------------------------------------------------
-- Unload
------------------------------------------------------------------------------

function Lumen:Unload()
	if self.Unloaded then return end
	-- handlers run synchronously here so your clean-up (restoring lighting, camera, etc.) happens before the UI goes away
	for _, h in ipairs(self.Events.Unloading._h) do
		if h.Connected then
			local ok, err = pcall(h.Fn)
			if not ok then warn("[Lumen] Unloading handler error: " .. tostring(err)) end
		end
	end
	if self.OnUnload then pcall(self.OnUnload) end
	self.Unloaded = true
	for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
	if BlurEffect then pcall(function() BlurEffect:Destroy() end) end
	Gui:Destroy()
	if env.LumenInstances and env.LumenInstances[self.Id] == self then env.LumenInstances[self.Id] = nil end
	if env.LumenUI == self then env.LumenUI = nil end
end

------------------------------------------------------------------------------
-- Integration API: flags, HTTP, clipboard, and extending the library from your own script
------------------------------------------------------------------------------

function Lumen:GetFlag(flag) return self.Flags[flag] end

-- sets an option by flag (updates its control and fires its callback); unknown flags are just stored
function Lumen:SetFlag(flag, value)
	local o = self.Options[flag]
	if o and o.Set then o:Set(value) else self.Flags[flag] = value self.Events.FlagChanged:Fire(flag, value) end
end

function Lumen:OnFlagChanged(flag, fn)
	return self.Events.FlagChanged:Connect(function(f, v) if f == flag then fn(v) end end)
end

-- HTTP through whichever request function the executor provides (request, http_request, syn.request, ...).
-- opts: {Url, Method = "GET", Headers = {}, Body = string}. Returns the response table, or nil + error.
function Lumen:Request(opts)
	local fn = (type(request) == "function" and request) or (type(http_request) == "function" and http_request)
		or (syn and type(syn.request) == "function" and syn.request) or (http and type(http.request) == "function" and http.request)
		or (fluxus and type(fluxus.request) == "function" and fluxus.request)
	if not fn then return nil, "this executor has no HTTP request function" end
	local ok, res = pcall(fn, opts)
	if not ok then return nil, tostring(res) end
	return res
end

-- copy text to the clipboard; returns true when the executor supports it
function Lumen:Clipboard(text)
	local fn = (type(setclipboard) == "function" and setclipboard) or (type(toclipboard) == "function" and toclipboard)
		or (type(set_clipboard) == "function" and set_clipboard)
	if not fn then return false end
	return (pcall(fn, tostring(text)))
end

-- Add your own element type. builder(group, options, api) builds it inside group and returns an object.
-- After Lumen:RegisterElement("Stepper", fn) every group has group:AddStepper({...}).
function Lumen:RegisterElement(name, builder)
	assert(type(name) == "string" and type(builder) == "function", "RegisterElement(name, function(group, options, api) ... end)")
	Elements["Add" .. name] = function(group, o) return builder(group, o or {}, self.API) end
end

-- Add your own theme. def = colour keys (Accent, Background, ...) plus an optional Style table. It appears in the config dropdown.
function Lumen:RegisterTheme(name, def, description)
	assert(type(name) == "string" and type(def) == "table", "RegisterTheme(name, {Accent = ..., Style = {...}})")
	self.Presets[name] = def
	if description and self._presetDescriptions then self._presetDescriptions[name] = description end
	local names = {}
	for n in pairs(self.Presets) do table.insert(names, PresetLabel(n)) end
	table.sort(names, function(x, y)
		if x == "Lavender (Default)" then return true elseif y == "Lavender (Default)" then return false end
		return x < y
	end)
	for _, d in ipairs(self._presetDropdowns) do pcall(function() d:SetValues(names, true) end) end
end

-- Add your own icon. draw(frame, size, colorKey, helpers): helpers.Seg(x1, y1, x2, y2, thickness) and helpers.Dot(x, y, d)
-- draw in a 16x16 grid. Works everywhere icons do (groups, dock buttons, panel headers).
function Lumen:RegisterIcon(name, draw)
	assert(type(name) == "string" and type(draw) == "function", "RegisterIcon(name, function(frame, size, colorKey, helpers) ... end)")
	CustomIcons[name] = draw
end

-- Building blocks for custom elements, so they match the theme and work with flags, configs, hints and the palette.
Lumen.Elements = Elements
Lumen.API = {
	New = New, Corner = Corner, Stroke = Stroke, Pad = Pad, List = List, Row = Row, Tween = Tween, Glow = Glow, Icon = Icon,
	NewOption = NewOpt, Register = Register, Fire = Fire, Connect = Connect, Describe = AttachHint, Catalog = CatalogAdd,
	AccentOverlay = AccentOverlay, SafeCall = SafeCall, Theme = Lumen.Theme, Gui = Gui, Overlay = Overlay,
	ShowPopup = ShowPopup, ClosePopup = ClosePopup, Dragger = Dragger,
}

-- Load options that need the whole library in place
do
	local fade = Lumen.ThemeTransition
	Lumen.ThemeTransition = 0
	if LoadOptions.Theme and Lumen.Presets[LoadOptions.Theme] then pcall(function() Lumen:ApplyPreset(LoadOptions.Theme) end) end
	Lumen.ThemeTransition = fade
	if LoadOptions.Font then pcall(function() Lumen:SetFont(LoadOptions.Font) end) end
	if LoadOptions.NotifyPosition then pcall(function() Lumen:SetNotifyPosition(LoadOptions.NotifyPosition) end) end
end

-- High-res icons: fetched once (GitHub, then the jsDelivr mirror), cached on disk, then swapped in with a fade
local ICON_BASES = {
	"https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/assets/icons/",
	"https://cdn.jsdelivr.net/gh/Irakli17/Ui-Library-Test@main/assets/icons/",
}
-- your own host (a fork, a CDN) is tried first
if type(LoadOptions.AssetBase) == "string" then table.insert(ICON_BASES, 1, LoadOptions.AssetBase) end
function Lumen:_LoadIcons()
	if not (writefile and readfile and isfile and isfolder and makefolder and getcustomasset) then return false end
	local dir = self.Folder .. "/icons"
	local ok = pcall(function()
		if not isfolder(self.Folder) then makefolder(self.Folder) end
		if not isfolder(dir) then makefolder(dir) end
		dir = dir .. "/" .. ICON_VERSION
		if not isfolder(dir) then makefolder(dir) end
	end)
	if not ok then return false end
	local pending, got = #ICON_NAMES, 0
	for _, name in ipairs(ICON_NAMES) do
		task.spawn(function()
			if not IconImages[name] then
				pcall(function()
					local path = dir .. "/" .. name .. ".png"
					if not isfile(path) then
						for _, base in ipairs(ICON_BASES) do
							local okGet, data = pcall(function() return game:HttpGet(base .. name .. ".png") end)
							if okGet and type(data) == "string" and data:sub(1, 4) == "\137PNG" then
								writefile(path, data)
								break
							end
						end
					end
					if isfile(path) then
						IconImages[name] = getcustomasset(path)
						got = got + 1
					end
				end)
			end
			pending = pending - 1
		end)
	end
	local t0 = os.clock()
	while pending > 0 and os.clock() - t0 < 30 and not self.Unloaded do task.wait(0.1) end
	if self.Unloaded then return false end
	-- swap every vector icon still on screen for its image
	for f, info in pairs(LiveIcons) do
		if f.Parent and IconImages[info.Kind] then
			for _, c in ipairs(f:GetChildren()) do
				if c:IsA("GuiObject") then c:Destroy() end
			end
			IconImage(f, info.Kind, info.Key, true)
		end
		LiveIcons[f] = nil
	end
	for _, fn in ipairs(Refreshers) do pcall(fn) end
	return got > 0
end

if not LoadOptions.NoImages then
	task.spawn(function() Lumen:_LoadIcons() end)
end

-- Inter font: downloaded once into the Lumen folder (needs writefile + getcustomasset), otherwise Gotham stays.
if not LoadOptions.NoInter then
	task.spawn(function()
		if Lumen:_LoadInter() and not Lumen.Unloaded and Lumen.FontName == "Inter" then Lumen:SetFont("Inter", 0.4) end
	end)
end

return Lumen
