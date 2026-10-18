--!nocheck
--!nolint
--[[
	TingUI Library  v0.0.8-stable
	Single file, no dependencies. Loads with loadstring, or as a ModuleScript (require) in any Roblox game.

	local TingUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/TingUI.lua"))()

	Load options can be passed straight into the loadstring call:
	local TingUI = loadstring(game:HttpGet(URL))({ Id = "MyHub", Theme = "Cosmos", Folder = "MyHub" })

	As a ModuleScript (ReplicatedStorage, Rojo or Wally), from a LocalScript:
	local TingUI = require(ReplicatedStorage.TingUI)                 -- options come from the ModuleScript's attributes
	local Other = TingUI.new({ Id = "Admin", Theme = "Ocean" })     -- a second, independent instance with its own options
	TingUI:Configure({ Theme = "Rose", Parent = someScreenGuiHolder }) -- change options after loading

	See docs/README.md for the full API and Example.lua for a complete demo.
]]

local InstanceCount = 0

-- The whole library is built inside Build so TingUI.new can make independent instances (each with its own options),
-- including from a ModuleScript, where require() only ever runs the file once.
local function Build(...)
local LoadArgs = { ... }
local env = (getgenv and getgenv()) or _G

do
	local RS = game:GetService("RunService")
	if RS:IsServer() and not RS:IsClient() then
		error("[TingUI] TingUI is a client UI library: require it from a LocalScript (or a client executor), not a server Script.", 2)
	end
end

-- Options: first argument of the chunk, or getgenv().TingUIOptions (read once, then cleared so the next script starts clean)
local LoadOptions = {}
do
	local src = (type(LoadArgs[1]) == "table" and LoadArgs[1]) or (type(env.TingUIOptions) == "table" and env.TingUIOptions) or nil
	if src then for k, v in pairs(src) do LoadOptions[k] = v end end
	if src ~= nil and src == env.TingUIOptions then env.TingUIOptions = nil end
	if env.TingUINoInter then LoadOptions.NoInter = true end
end

-- Every script gets its own instance, keyed by Id. Re-running a script replaces its own previous copy
-- (handy while developing) and leaves other scripts' interfaces alone. Reuse = true returns the running copy instead.
local InstanceId = tostring(LoadOptions.Id or "default")
env.TingUIInstances = type(env.TingUIInstances) == "table" and env.TingUIInstances or {}
do
	local prev = env.TingUIInstances[InstanceId]
	if prev == nil and InstanceId == "default" and type(env.TingUI) == "table" and not env.TingUI.Id then prev = env.TingUI end
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

local TingUI = {
	Version = "v0.0.8-stable",
	ConfirmsConfigDelete = true,                        -- the config tab asks before it deletes a config
	ConfigProgressNotices = true,                       -- saving, loading and autoloading show Loading -> result
	Id = InstanceId,
	LoadOptions = LoadOptions,
	NotifyErrors = LoadOptions.NotifyErrors ~= false,   -- a crashing callback shows a red notification
	Hints = LoadOptions.Hints ~= false,                 -- hover explanations
	HintDelay = 0.35,
	NotifyPosition = "TopRight",
	Flags = {},
	Options = {},
	Windows = {},
	-- configs live per script (TingUI/<Id>), so one script's autoload (theme, UI scale, ...) never lands in another's UI
	Folder = LoadOptions.Folder or (InstanceId == "default" and "TingUI" or ("TingUI/" .. InstanceId)),
	CacheFolder = LoadOptions.CacheFolder or "TingUI",  -- downloaded fonts, icons and textures, shared by every script
	-- your saved themes (Theme Studio, ImportTheme), shared by every script so a theme you make shows up everywhere
	ThemeFolder = LoadOptions.ThemeFolder or ((LoadOptions.CacheFolder or "TingUI") .. "/themes"),
	Unloaded = false,
	Shortcuts = LoadOptions.Shortcuts ~= false,         -- Ctrl+K (command palette) and Ctrl+Tab (switch tabs)
	ReducedMotion = LoadOptions.ReducedMotion == true,  -- hold scenes and particles still, no flicker, glitches or lightning
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
		-- ocean: the window floats in water. Waves roll along its bottom edge and rise toward the pointer, caustic light
		-- plays across the header, a tide washes over the window when you switch to it, clicks drop ripples, and the
		-- bubbles are all different (fizz, glass, big wobbly ones, clusters) and pop at depth, at the surface or on touch
		Ocean = { Accent = Color3.fromRGB(86, 196, 246), Background = Color3.fromRGB(7, 15, 24), Group = Color3.fromRGB(10, 21, 33), GroupBorder = Color3.fromRGB(20, 40, 58), Control = Color3.fromRGB(15, 30, 46), ControlHover = Color3.fromRGB(22, 42, 62), Border = Color3.fromRGB(42, 82, 112), Outline = Color3.fromRGB(28, 56, 80), Text = Color3.fromRGB(222, 240, 252), Label = Color3.fromRGB(188, 214, 232), TextDim = Color3.fromRGB(122, 156, 182), TextMuted = Color3.fromRGB(92, 122, 146),
			Style = { Radius = 1.4, Glow = 1.45, Font = "JosefinSans", TextScale = 1.06, Particles = "Bubbles", ParticleColor = Color3.fromRGB(120, 210, 255), Scene = "Ocean",
				WaterColor = Color3.fromRGB(64, 170, 236), FoamColor = Color3.fromRGB(205, 242, 255),
				Tint = Color3.fromRGB(30, 130, 200), TintPlace = "Bottom", TintAmount = 0.24,
				TopLine = { Color3.fromRGB(150, 236, 255), Color3.fromRGB(60, 120, 245) },
				Aura = { Color3.fromRGB(90, 210, 255), Color3.fromRGB(30, 90, 170), Color3.fromRGB(140, 240, 255), Color3.fromRGB(40, 110, 200), Color3.fromRGB(90, 210, 255) },
				AuraSpeed = 0.06, AuraThickness = 1.3,
				AccentGradient = { Color3.fromRGB(140, 236, 255), Color3.fromRGB(50, 120, 236) } } },
		Rose = { Accent = Color3.fromRGB(205, 120, 150), Background = Color3.fromRGB(17, 12, 15), Group = Color3.fromRGB(22, 16, 20), GroupBorder = Color3.fromRGB(33, 24, 29), Control = Color3.fromRGB(31, 23, 28), ControlHover = Color3.fromRGB(43, 32, 39), Border = Color3.fromRGB(62, 46, 54), Outline = Color3.fromRGB(50, 37, 44), Text = Color3.fromRGB(228, 214, 220), Label = Color3.fromRGB(200, 184, 191), TextDim = Color3.fromRGB(150, 130, 140), TextMuted = Color3.fromRGB(118, 100, 109),
			Style = { Radius = 1.75, Glow = 1.6, Font = "Inter", Particles = "Petals", ParticleColor = Color3.fromRGB(242, 150, 186), Tint = Color3.fromRGB(215, 95, 150), TintPlace = "Top", TintAmount = 0.16, TopLine = { Color3.fromRGB(245, 140, 185), Color3.fromRGB(255, 190, 150) } } },
		Sunset = { Accent = Color3.fromRGB(215, 150, 90), Background = Color3.fromRGB(17, 13, 11), Group = Color3.fromRGB(23, 18, 15), GroupBorder = Color3.fromRGB(34, 27, 22), Control = Color3.fromRGB(32, 26, 21), ControlHover = Color3.fromRGB(44, 36, 30), Border = Color3.fromRGB(64, 52, 43), Outline = Color3.fromRGB(51, 41, 34), Text = Color3.fromRGB(230, 220, 210), Label = Color3.fromRGB(202, 191, 180), TextDim = Color3.fromRGB(152, 138, 124), TextMuted = Color3.fromRGB(120, 108, 96),
			Style = { Radius = 1, Glow = 1.3, Font = "Inter", Particles = "Embers", ParticleColor = Color3.fromRGB(255, 150, 70), Tint = Color3.fromRGB(235, 110, 60), TintPlace = "Bottom", TintAmount = 0.2, TopLine = { Color3.fromRGB(255, 160, 80), Color3.fromRGB(230, 80, 140) } } },
		Mono = { Accent = Color3.fromRGB(190, 190, 196), Background = Color3.fromRGB(12, 12, 12), Group = Color3.fromRGB(17, 17, 17), GroupBorder = Color3.fromRGB(26, 26, 26), Control = Color3.fromRGB(25, 25, 25), ControlHover = Color3.fromRGB(36, 36, 36), Border = Color3.fromRGB(52, 52, 52), Outline = Color3.fromRGB(41, 41, 41), Text = Color3.fromRGB(222, 222, 222), Label = Color3.fromRGB(194, 194, 194), TextDim = Color3.fromRGB(136, 136, 136), TextMuted = Color3.fromRGB(106, 106, 106),
			Style = { Radius = 0.25, Glow = 0, Font = "Mono", Particles = "Glyphs", ParticleColor = Color3.fromRGB(205, 205, 205), Scanlines = true } },
		-- pale ice, thin rounded type, a frosted inner border and slowly spinning crystals
		Frost = { Accent = Color3.fromRGB(150, 215, 255), Background = Color3.fromRGB(12, 18, 26), Group = Color3.fromRGB(16, 24, 34), GroupBorder = Color3.fromRGB(26, 38, 52), Control = Color3.fromRGB(22, 32, 44), ControlHover = Color3.fromRGB(32, 46, 62), Border = Color3.fromRGB(60, 86, 112), Outline = Color3.fromRGB(42, 60, 80), Text = Color3.fromRGB(232, 244, 255), Label = Color3.fromRGB(205, 224, 240), TextDim = Color3.fromRGB(140, 166, 190), TextMuted = Color3.fromRGB(105, 128, 150),
			Style = { Radius = 1.25, Glow = 1.2, Font = "Jura", TextScale = 1.08, Particles = "Crystals", ParticleColor = Color3.fromRGB(215, 240, 255), Tint = Color3.fromRGB(120, 190, 255), TintPlace = "Top", TintAmount = 0.14, TopLine = { Color3.fromRGB(230, 248, 255), Color3.fromRGB(120, 190, 255) }, InnerLine = Color3.fromRGB(170, 215, 255), AccentGradient = { Color3.fromRGB(235, 248, 255), Color3.fromRGB(120, 190, 255) } } },
		-- midnight navy and gold, serif type, a gilded double border and glinting sparkles
		Royal = { Accent = Color3.fromRGB(222, 184, 92), Background = Color3.fromRGB(11, 13, 24), Group = Color3.fromRGB(15, 18, 32), GroupBorder = Color3.fromRGB(26, 28, 46), Control = Color3.fromRGB(20, 24, 40), ControlHover = Color3.fromRGB(30, 34, 56), Border = Color3.fromRGB(92, 78, 44), Outline = Color3.fromRGB(48, 46, 60), Text = Color3.fromRGB(244, 236, 214), Label = Color3.fromRGB(222, 212, 186), TextDim = Color3.fromRGB(160, 150, 126), TextMuted = Color3.fromRGB(120, 112, 94),
			Style = { Radius = 0.6, Glow = 1.1, Font = "Merriweather", TextScale = 0.94, Particles = "Sparkles", ParticleColor = Color3.fromRGB(255, 214, 120), Tint = Color3.fromRGB(200, 160, 70), TintPlace = "Top", TintAmount = 0.1, TopLine = { Color3.fromRGB(255, 214, 120), Color3.fromRGB(180, 130, 50) }, InnerLine = Color3.fromRGB(222, 184, 92), AccentGradient = { Color3.fromRGB(255, 226, 150), Color3.fromRGB(196, 148, 58) } } },
		-- deep space: drifting violet and blue nebula clouds over a parallax star layer inside the window, the same nebula
		-- faintly across the whole screen, a slowly turning aurora border, twinkling stars, shooting stars and comets
		Cosmos = { Accent = Color3.fromRGB(160, 130, 255), Background = Color3.fromRGB(7, 7, 17), Group = Color3.fromRGB(11, 11, 25), GroupBorder = Color3.fromRGB(26, 24, 52), Control = Color3.fromRGB(18, 17, 38), ControlHover = Color3.fromRGB(28, 26, 56), Border = Color3.fromRGB(70, 60, 130), Outline = Color3.fromRGB(42, 38, 82), Text = Color3.fromRGB(238, 236, 255), Label = Color3.fromRGB(214, 210, 248), TextDim = Color3.fromRGB(156, 150, 206), TextMuted = Color3.fromRGB(114, 108, 166),
			Style = { Radius = 1.2, Glow = 1.6, Font = "TitilliumWeb", TextScale = 1.05, Particles = "Galaxy", ParticleColor = Color3.fromRGB(225, 228, 255), Tint = Color3.fromRGB(110, 70, 255), TintPlace = "Aurora", TintAmount = 0.14,
				TopLine = { Color3.fromRGB(170, 140, 255), Color3.fromRGB(90, 210, 255) },
				Aura = { Color3.fromRGB(160, 130, 255), Color3.fromRGB(90, 210, 255), Color3.fromRGB(255, 120, 220), Color3.fromRGB(120, 90, 255), Color3.fromRGB(160, 130, 255) }, AuraSpeed = 0.1, AuraThickness = 1.4,
				AccentGradient = { Color3.fromRGB(180, 140, 255), Color3.fromRGB(90, 210, 255) },
				Texture = { { Image = "nebula", Transparency = 0.5, Drift = 0.03, Zoom = 0.9 }, { Image = "stars", Transparency = 0.15, Drift = 0.055, Zoom = 1.15, Pulse = 0.25 } },
				BackdropTexture = { Image = "nebula", Transparency = 0.84, Drift = 0.012, Zoom = 0.6 } } },
		-- slate and steel, condensed type, slanted rain and distant lightning
		Storm = { Accent = Color3.fromRGB(120, 180, 255), Background = Color3.fromRGB(13, 15, 19), Group = Color3.fromRGB(18, 21, 26), GroupBorder = Color3.fromRGB(28, 32, 40), Control = Color3.fromRGB(24, 28, 35), ControlHover = Color3.fromRGB(34, 39, 48), Border = Color3.fromRGB(62, 72, 88), Outline = Color3.fromRGB(42, 48, 60), Text = Color3.fromRGB(226, 232, 242), Label = Color3.fromRGB(200, 208, 222), TextDim = Color3.fromRGB(140, 150, 168), TextMuted = Color3.fromRGB(104, 112, 128),
			Style = { Radius = 0.9, Glow = 1.25, Font = "Oswald", TextScale = 1.05, Particles = "Rain", ParticleColor = Color3.fromRGB(170, 200, 240), Tint = Color3.fromRGB(90, 120, 170), TintPlace = "Top", TintAmount = 0.16, TopLine = { Color3.fromRGB(200, 225, 255), Color3.fromRGB(120, 180, 255) }, Lightning = true } },
		-- drafting paper: navy blue, a white grid, a ruled double border, handwritten labels and drafting marks
		Blueprint = { Accent = Color3.fromRGB(225, 238, 255), Background = Color3.fromRGB(18, 48, 92), Group = Color3.fromRGB(22, 56, 104), GroupBorder = Color3.fromRGB(52, 90, 140), Control = Color3.fromRGB(28, 64, 116), ControlHover = Color3.fromRGB(40, 80, 136), Border = Color3.fromRGB(120, 160, 210), Outline = Color3.fromRGB(70, 110, 165), Text = Color3.fromRGB(240, 246, 255), Label = Color3.fromRGB(214, 228, 248), TextDim = Color3.fromRGB(150, 180, 220), TextMuted = Color3.fromRGB(115, 145, 190),
			Style = { Radius = 0.3, Glow = 0.35, Font = "PatrickHand", TextScale = 1.15, Particles = "Drafting", ParticleColor = Color3.fromRGB(210, 230, 255), Grid = true, GridColor = Color3.fromRGB(220, 235, 255), InnerLine = Color3.fromRGB(200, 225, 255) } },
		-- hazard: industrial yellow and black, a striped warning-tape border, square corners and welding sparks
		Hazard = { Accent = Color3.fromRGB(255, 200, 0), Background = Color3.fromRGB(16, 15, 10), Group = Color3.fromRGB(22, 21, 14), GroupBorder = Color3.fromRGB(40, 38, 24), Control = Color3.fromRGB(30, 28, 18), ControlHover = Color3.fromRGB(42, 40, 26), Border = Color3.fromRGB(90, 84, 40), Outline = Color3.fromRGB(56, 52, 30), Text = Color3.fromRGB(250, 246, 230), Label = Color3.fromRGB(228, 222, 200), TextDim = Color3.fromRGB(165, 158, 130), TextMuted = Color3.fromRGB(125, 118, 95),
			Style = { Radius = 0.2, Glow = 0.9, Font = "Sarpanch", TextScale = 1.05, Particles = "None", Tint = Color3.fromRGB(255, 140, 0), TintPlace = "Bottom", TintAmount = 0.12,
				Aura = { Color3.fromRGB(255, 200, 0), Color3.fromRGB(24, 22, 14), Color3.fromRGB(255, 200, 0), Color3.fromRGB(24, 22, 14), Color3.fromRGB(255, 200, 0), Color3.fromRGB(24, 22, 14), Color3.fromRGB(255, 200, 0), Color3.fromRGB(24, 22, 14), Color3.fromRGB(255, 200, 0), Color3.fromRGB(24, 22, 14) },
				AuraHard = true, AuraSpeed = 0, AuraRotation = 45, AuraThickness = 3 } },
		-- glass: see-through frosted surfaces over a blurred world, soft rounded type and drifting bokeh
		Glass = { Accent = Color3.fromRGB(170, 215, 255), Background = Color3.fromRGB(22, 26, 36), Group = Color3.fromRGB(30, 36, 50), GroupBorder = Color3.fromRGB(60, 70, 92), Control = Color3.fromRGB(38, 45, 62), ControlHover = Color3.fromRGB(52, 60, 80), Border = Color3.fromRGB(110, 125, 155), Outline = Color3.fromRGB(70, 82, 108), Text = Color3.fromRGB(245, 248, 255), Label = Color3.fromRGB(220, 228, 242), TextDim = Color3.fromRGB(160, 172, 195), TextMuted = Color3.fromRGB(122, 134, 158),
			Style = { Radius = 1.6, Glow = 1, Font = "Nunito", TextScale = 1.04, Particles = "Bokeh", ParticleColor = Color3.fromRGB(180, 210, 255), SurfaceTransparency = 0.35, Blur = 18, InnerLine = Color3.fromRGB(255, 255, 255),
				TopLine = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 215, 255) }, AccentGradient = { Color3.fromRGB(220, 240, 255), Color3.fromRGB(140, 190, 255) } } },
		-- hologram: a cyan light projection. Corner brackets lock on as it opens, a scan line sweeps every page, the image
		-- tears for an instant now and then, a projector beam glows underneath and clicks ripple out as hexagons
		Hologram = { Accent = Color3.fromRGB(90, 225, 255), Background = Color3.fromRGB(5, 13, 18), Group = Color3.fromRGB(8, 20, 27), GroupBorder = Color3.fromRGB(20, 52, 64), Control = Color3.fromRGB(12, 30, 39), ControlHover = Color3.fromRGB(18, 44, 56), Border = Color3.fromRGB(40, 120, 145), Outline = Color3.fromRGB(26, 70, 86), Text = Color3.fromRGB(215, 248, 255), Label = Color3.fromRGB(176, 230, 242), TextDim = Color3.fromRGB(110, 170, 188), TextMuted = Color3.fromRGB(80, 130, 146),
			Style = { Radius = 0.5, Glow = 1.7, Font = "Michroma", TextScale = 0.86, Particles = "Holo", ParticleColor = Color3.fromRGB(120, 230, 255), Scene = "Hologram",
				Tint = Color3.fromRGB(40, 200, 255), TintPlace = "Top", TintAmount = 0.12, Scanlines = true, SurfaceTransparency = 0.08,
				TopLine = { Color3.fromRGB(200, 250, 255), Color3.fromRGB(90, 225, 255) }, InnerLine = Color3.fromRGB(90, 225, 255),
				Aura = { Color3.fromRGB(90, 225, 255), Color3.fromRGB(30, 110, 150), Color3.fromRGB(160, 245, 255), Color3.fromRGB(30, 110, 150), Color3.fromRGB(90, 225, 255) },
				AuraSpeed = 0.07, AuraThickness = 1.3, AccentGradient = { Color3.fromRGB(170, 248, 255), Color3.fromRGB(60, 170, 255) } } },
		-- circuit: the window is a chip on a board. Copper traces run out from pins along its edges, current pulses race
		-- along them, pins near the pointer warm up and every click fires a burst down the nearest traces
		Circuit = { Accent = Color3.fromRGB(255, 172, 64), Background = Color3.fromRGB(11, 12, 14), Group = Color3.fromRGB(16, 17, 20), GroupBorder = Color3.fromRGB(32, 31, 33), Control = Color3.fromRGB(23, 24, 28), ControlHover = Color3.fromRGB(33, 34, 39), Border = Color3.fromRGB(92, 70, 44), Outline = Color3.fromRGB(46, 42, 38), Text = Color3.fromRGB(242, 234, 220), Label = Color3.fromRGB(216, 207, 192), TextDim = Color3.fromRGB(150, 142, 128), TextMuted = Color3.fromRGB(112, 106, 96),
			Style = { Radius = 0.35, Glow = 1.25, Font = "Ubuntu", TextScale = 1, Particles = "Static", ParticleColor = Color3.fromRGB(255, 200, 120), Scene = "Circuit",
				TraceColor = Color3.fromRGB(150, 104, 58), EnergyColor = Color3.fromRGB(255, 196, 110),
				Tint = Color3.fromRGB(255, 150, 40), TintPlace = "Top", TintAmount = 0.07, InnerLine = Color3.fromRGB(120, 88, 50),
				TopLine = { Color3.fromRGB(255, 220, 150), Color3.fromRGB(255, 140, 40) }, AccentGradient = { Color3.fromRGB(255, 210, 120), Color3.fromRGB(255, 128, 40) } } },
		-- serotonin: a crisp classic cheat-menu look. Square corners, a hairline teal outline inside a dark teal frame,
		-- teal light falling from the top edge, flat dark slate panels, a plain sans and white text. No particles.
		Serotonin = { Accent = Color3.fromRGB(94, 213, 213), Background = Color3.fromRGB(17, 21, 27), Group = Color3.fromRGB(19, 25, 31), GroupBorder = Color3.fromRGB(46, 52, 61), Control = Color3.fromRGB(32, 38, 48), ControlHover = Color3.fromRGB(41, 48, 60), Border = Color3.fromRGB(46, 52, 61), Outline = Color3.fromRGB(46, 52, 61), Text = Color3.fromRGB(255, 255, 255), Label = Color3.fromRGB(232, 236, 240), TextDim = Color3.fromRGB(185, 185, 185), TextMuted = Color3.fromRGB(132, 138, 146),
			TabActive = Color3.fromRGB(24, 28, 36), Toggle = Color3.fromRGB(94, 213, 213), AccentText = Color3.fromRGB(94, 213, 213),
			Style = { Radius = 0, Glow = 0.85, Font = "Arial", TextScale = 1.08, Particles = "None",
				Tint = Color3.fromRGB(94, 213, 213), TintPlace = "Top", TintAmount = 0.07,
				TopLine = { Color3.fromRGB(94, 213, 213), Color3.fromRGB(94, 213, 213) },
				Aura = { Color3.fromRGB(94, 213, 213), Color3.fromRGB(94, 213, 213) }, AuraSpeed = 0, AuraThickness = 1,
				InnerLine = Color3.fromRGB(0, 52, 56),
				AccentGradient = { Color3.fromRGB(150, 240, 240), Color3.fromRGB(70, 180, 186) } } },
	},
}
env.TingUIInstances[InstanceId] = TingUI
env.TingUI = TingUI

local Connections, Themed, Refreshers, Keybinds, FontObjs, Gradients = {}, {}, {}, {}, {}, {}

------------------------------------------------------------------------------
-- Signals + events (connect from your own code: TingUI.Events.ThemeChanged:Connect(fn))
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
					if not ok then warn("[TingUI] event handler error: " .. tostring(err)) end
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
TingUI.Signal = NewSignal
TingUI.Events = {
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
			warn("[TingUI] error in " .. tostring(label) .. ": " .. tostring(err))
			if TingUI.NotifyErrors and not TingUI.Unloaded and TingUI.Notify then
				pcall(function()
					TingUI:Notify({ Title = "Script error", Content = tostring(label) .. ": " .. FirstLine(err), Type = "Error", Duration = 9,
						Details = tostring(err), Copy = tostring(label) .. "\n" .. tostring(err) })
				end)
			end
		end
	end)
end
TingUI.SafeCall = SafeCall
local Gui, Overlay, OpenPopup

-- Where the pointer is, in TingUI's own GUI coordinates (the space AbsolutePosition uses). GetMouseLocation counts
-- from the very top of the screen; TingUI's ScreenGui ignores the top-bar inset, so normally the two agree. When they
-- don't (IgnoreGuiInset changed, an executor container, a custom Parent), effects used to land a bar's height above
-- or below the cursor. Every press on a small TingUI control re-learns the exact correction.
local Pointer = { Service = Service("GuiService"), Shift = nil }
function Pointer.Inset()
	local ok, inset = pcall(function() return Pointer.Service:GetGuiInset() end)
	return (ok and typeof(inset) == "Vector2") and inset or Vector2.new(0, 0)
end
function Pointer.Gui()
	local m = UIS:GetMouseLocation()
	if Pointer.Shift then return m + Pointer.Shift end
	if Gui and not Gui.IgnoreGuiInset then return m - Pointer.Inset() end
	return m
end
function Pointer.Calibrate(frame, input)
	if not input or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	local ap, sz = frame.AbsolutePosition, frame.AbsoluteSize
	-- only frames shorter than the inset give a single answer
	local inset = Pointer.Inset()
	if sz.Y < 4 or sz.Y >= math.max(inset.Y, 30) then return end
	local m = UIS:GetMouseLocation()
	local function inside(d)
		local v = m + d
		return v.X >= ap.X - 1 and v.X <= ap.X + sz.X + 1 and v.Y >= ap.Y - 1 and v.Y <= ap.Y + sz.Y + 1
	end
	if Pointer.Shift and inside(Pointer.Shift) then return end
	for _, d in ipairs({ Vector2.new(0, 0), -inset, inset }) do
		if inside(d) then Pointer.Shift = d return end
	end
end
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
	if name == "Inter" then return TingUI._interAsset end
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
	if base then obj.TextSize = math.max(6, math.floor(base * (TingUI._textScale or 1) * (obj:GetAttribute("TSK") or 1) + 0.5)) end
	local fam = TingUI._fontFamily
	if fam then
		local ok = pcall(function() obj.FontFace = Font.new(fam, WeightEnum[weight]) end)
		if ok then return end
	end
	obj.Font = GothamByWeight[weight]
end

local FontToken = 0
-- fade (seconds, optional): text dips, the font swaps at the bottom of the dip, text rises again
function TingUI:SetFont(name, fade)
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
	-- Text rises back to its *resting* transparency (0, or the TTRest attribute), never to whatever value it had
	-- mid-animation: reading the live value here is what used to leave dropdown values and tab names blank after
	-- a theme switch (they were caught halfway through their own fade-in and restored to invisible).
	local items = {}
	for _, e in ipairs(FontObjs) do
		local o = e[1]
		if o.Parent and o:IsDescendantOf(Gui) and not o:GetAttribute("NoDip") then
			local t0 = o:GetAttribute("TTRest") or 0
			table.insert(items, { o, t0 })
			TweenService:Create(o, dip, { TextTransparency = math.min(1, t0 + 0.9) }):Play()
		end
	end
	task.delay(half, function()
		if mine ~= FontToken or TingUI.Unloaded then return end
		Swap()
		for _, it in ipairs(items) do
			if it[1].Parent then TweenService:Create(it[1], rise, { TextTransparency = it[2] }):Play() end
		end
	end)
end

local INTER_URL = "https://raw.githubusercontent.com/rsms/inter/v3.19/docs/font-files/Inter-"
function TingUI:_LoadInter()
	if not (writefile and readfile and isfile and isfolder and makefolder and getcustomasset) then return false end
	local ok = pcall(function()
		if not isfolder(self.CacheFolder) then makefolder(self.CacheFolder) end
		local dir = self.CacheFolder .. "/fonts"
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
		obj.TextColor3 = TingUI.Theme.Label
		if class ~= "TextBox" then obj.BackgroundTransparency = 1 end
		if class == "TextButton" then
			obj.AutoButtonColor = false
			obj.Text = ""
		end
	end
	if obj:IsA("GuiObject") then obj.BorderSizePixel = 0
	elseif class == "UIScale" or class == "UIAspectRatioConstraint" then obj:SetAttribute("TingUI", true) end
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
			obj[prop] = TingUI.Theme[key]
			table.insert(Themed, { obj, prop, key })
		end
	end
	if isText then
		if not (theme and theme.TextColor3) then
			local c = obj.TextColor3
			for _, key in ipairs({ "Label", "Text", "TextDim", "TextMuted" }) do
				if c == TingUI.Theme[key] then
					table.insert(Themed, { obj, "TextColor3", key })
					break
				end
			end
		end
		local w = EnumToWeight[obj.Font] or "SemiBold"
		table.insert(FontObjs, { obj, w })
		obj:SetAttribute("TS", obj.TextSize)
		if TingUI._fontFamily or (TingUI._textScale or 1) ~= 1 then ApplyFont(obj, w) end
	end
	for _, c in ipairs(children or {}) do c.Parent = obj end
	if parent then obj.Parent = parent end
	return obj
end

local function Corner(r)
	r = r or 4
	local c = New("UICorner", { CornerRadius = UDim.new(0, math.floor(r * TingUI.Style.Radius + 0.5)) })
	c:SetAttribute("R", r)
	return c
end
local function CornerFixed(r) return New("UICorner", { CornerRadius = UDim.new(0, r or 4) }) end

local function UpdateGradient(g)
	local T = TingUI.Theme
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
		local k = TingUI.Style.Glow or 1
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
	local acc = TingUI.Theme.Accent
	local to = TingUI.Style
	local from = StyleBlend and StyleBlend.From or to
	local a = StyleBlend and StyleBlend.A or 1
	local function ends(st)
		if st.AccentCycle then
			local h = (os.clock() * (st.CycleSpeed or 0.07)) % 1
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

-- Theme textures (nebula, stars, brick, lamp light, ...): high-res PNGs downloaded on first use, cached on disk.
-- Style.Texture = { {Image = "nebula", Transparency = 0.55, Drift = 0.03, Zoom = 1, Pulse = 0.1, Color = Color3}, ... }
-- Image may be a built-in name (assets/textures/<name>.png) or any rbxassetid:// / rbxasset:// / getcustomasset id.
local TextureImages = {}
TingUI.TextureAssets = TextureImages
if type(LoadOptions.Textures) == "table" then for k, v in pairs(LoadOptions.Textures) do TextureImages[k] = v end end
local RequestTexture = function() end -- replaced by the loader at the end of the file
local function TextureImage(name)
	if type(name) ~= "string" then return "" end
	if name:find("^rbx") or name:find("^http") then return name end
	if TextureImages[name] then return TextureImages[name] end
	RequestTexture(name)
	-- a cached file can load straight away
	return TextureImages[name] or ""
end

-- Surfaces: windows, panels and the dock take the theme's tint gradient, top light, scanlines, aura border and inner line.
local Surfaces = {}
-- theme scenes (animated artwork around windows); filled in by the scene block further down
local Scenes = { Kinds = {} }

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
	local base = TingUI.Theme.Background
	local to = TingUI.Style
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
			local edge = TingUI.Theme.Border:Lerp(Color3.new(1, 1, 1), 0.1)
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

	-- texture layers: each image fades by how much of it the old and new theme use, so themes crossfade their art
	local want = {}
	for _, pair in ipairs({ { from, 1 - a }, { to, a } }) do
		for _, L in ipairs(pair[1].Texture or {}) do
			local key = tostring(L.Image) .. ":" .. tostring(L.Mode or "Fill")
			local w = want[key] or { P = 0 }
			w.P = w.P + pair[2]
			if pair[2] > 0 or not w.Cfg then w.Cfg = L end
			want[key] = w
		end
	end
	e.Tex = e.Tex or {}
	for key, w in pairs(want) do
		local layer = e.Tex[key]
		if not layer and w.P > 0.01 then
			local lamp = w.Cfg.Mode == "Lamp"
			layer = { Key = key, Phase = math.random() * 6.28, NextFlicker = 0, OffUntil = 0 }
			layer.Label = New("ImageLabel", {
				Name = "TingUITexture", BackgroundTransparency = 1, ImageTransparency = 1, ZIndex = 0, ScaleType = Enum.ScaleType.Stretch,
				AnchorPoint = lamp and Vector2.new(0.5, 0) or Vector2.new(0, 0),
				Position = lamp and UDim2.new(0.5, 0, 0, 0) or UDim2.new(0, 0, 0, 0),
				Size = lamp and UDim2.fromScale(0.95, 0.9) or UDim2.fromScale(1, 1), Parent = e.Frame,
			}, (not lamp) and { Corner(e.Radius) } or nil)
			e.Tex[key] = layer
		end
		if layer then
			layer.Cfg, layer.P = w.Cfg, math.clamp(w.P, 0, 1)
			local img = TextureImage(w.Cfg.Image)
			if layer.Label.Image ~= img then layer.Label.Image = img end
			layer.Label.ImageColor3 = w.Cfg.Color or Color3.new(1, 1, 1)
			layer.Label.Visible = layer.P > 0.01 and img ~= ""
		end
	end
	for key, layer in pairs(e.Tex) do
		if not want[key] then layer.P = 0 layer.Label.Visible = false end
	end

	-- glitch: chromatic copies of the title, made once, shown only during a glitch burst
	if (to.Glitch or from.Glitch) and not e.Glitch then
		e.Glitch = { Bars = {}, Next = os.clock() + 1.5, Until = 0, Step = 0 }
		for i = 1, 4 do
			e.Glitch.Bars[i] = New("Frame", { BorderSizePixel = 0, BackgroundTransparency = 1, Visible = false, ZIndex = 40, Parent = e.Frame })
		end
	end

	if Scenes.Sync and (from.Scene or to.Scene or e.Scenes) then Scenes.Sync(e, from, to, a) end
end

-- per-frame motion for texture layers: slow drift (a smooth back-and-forth pan over the image, so it never jumps),
-- gentle breathing, and the faulty street-lamp flicker
local TexFX = {}
function TexFX.Drift(label, cfg, t, phase)
	local abs = label.AbsoluteSize
	if not abs or abs.X < 2 or abs.Y < 2 then return end
	local ts = cfg.Size or 1024
	local zoom = cfg.Zoom or 1
	local rw, rh = abs.X * zoom, abs.Y * zoom
	local k = math.min(1, ts / rw, ts / rh)
	rw, rh = rw * k, rh * k
	local sp = cfg.Drift or 0.02
	local ax, ay = (ts - rw) / 2, (ts - rh) / 2
	label.ImageRectSize = Vector2.new(math.floor(rw), math.floor(rh))
	label.ImageRectOffset = Vector2.new(math.floor(ax + ax * math.sin(t * sp + phase)), math.floor(ay + ay * math.sin(t * sp * 0.77 + phase * 1.3)))
end
function TexFX.Flicker(layer, t)
	-- mostly steady with a slow hum; every few seconds it stutters off and back on like a dying sodium lamp
	if t >= layer.NextFlicker then
		layer.NextFlicker = t + 2.5 + math.random() * 5
		layer.OffUntil = t + 0.05 + math.random() * 0.14
		layer.Second = math.random() < 0.45 and (layer.OffUntil + 0.07 + math.random() * 0.08) or nil
	end
	if t < layer.OffUntil then return 0.18 + math.random() * 0.2 end
	if layer.Second and t >= layer.Second then
		if t < layer.Second + 0.06 then return 0.3 end
		layer.Second = nil
	end
	return 0.9 + 0.1 * math.sin(t * 9 + layer.Phase) * math.sin(t * 2.3)
end
TexFX.GlitchColors = { Color3.new(1, 1, 1), Color3.fromRGB(255, 40, 70), Color3.fromRGB(40, 220, 255), Color3.fromRGB(230, 230, 230) }
function TexFX.Glitch(e, t)
	local G = e.Glitch
	local on = TingUI.Style.Glitch and e.Frame.Visible
	local active = on and t < G.Until
	if on and not active and t >= G.Next then
		G.Until = t + 0.16 + math.random() * 0.22
		G.Next = G.Until + 2.5 + math.random() * 5.5
		G.Step = 0
		active = true
	end
	if not active then
		if G.Shown then
			G.Shown = false
			for _, b in ipairs(G.Bars) do b.Visible = false end
			for _, g in ipairs(G.Ghosts or {}) do g.Visible = false end
		end
		return
	end
	if t < G.Step then return end
	G.Step = t + 0.045
	G.Shown = true
	if e.Title and not G.Ghosts then
		-- red and cyan copies of the title that split away from it for a moment (chromatic aberration)
		G.Ghosts = {}
		for i, c in ipairs({ Color3.fromRGB(255, 40, 70), Color3.fromRGB(40, 220, 255) }) do
			local g = Instance.new("TextLabel")
			g.BackgroundTransparency = 1
			g.Size = UDim2.fromScale(1, 1)
			g.TextColor3 = c
			g.TextTransparency = 1
			g.Visible = false
			g.Name = "TingUIGlitch" .. i
			g.Parent = e.Title
			G.Ghosts[i] = g
		end
	end
	local abs = e.Frame.AbsoluteSize
	local h = (abs and abs.Y > 0) and abs.Y / ((TingUI.Scale > 0) and TingUI.Scale or 1) or 400
	for _, b in ipairs(G.Bars) do
		if math.random() < 0.7 then
			b.Visible = true
			b.BackgroundColor3 = TexFX.GlitchColors[math.random(#TexFX.GlitchColors)]
			b.BackgroundTransparency = 0.72 + math.random() * 0.2
			local w = 0.25 + math.random() * 0.75
			b.Size = UDim2.new(w, 0, 0, math.random(1, 7))
			b.Position = UDim2.new(math.random() * (1 - w), 0, 0, math.random(0, math.max(0, math.floor(h) - 7)))
		else
			b.Visible = false
		end
	end
	if e.Title and G.Ghosts then
		for i, g in ipairs(G.Ghosts) do
			g.Text = e.Title.Text
			g.TextSize = e.Title.TextSize
			pcall(function() g.FontFace = e.Title.FontFace end)
			g.TextXAlignment = e.Title.TextXAlignment
			g.Position = UDim2.fromOffset((i == 1 and -1 or 1) * math.random(1, 3), math.random(-1, 1))
			g.TextTransparency = 0.35 + math.random() * 0.3
			g.Visible = true
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
	if TingUI.ReducedMotion then return end
	local t = os.clock()
	for _, e in ipairs(Surfaces) do
		if e.AuraOn and (e.AuraSpeed or 0) > 0 and e.Frame.Visible then
			e.StrokeGrad.Rotation = (t * e.AuraSpeed * 360) % 360
		end
		if e.Tex and e.Frame.Visible then
			for _, layer in pairs(e.Tex) do
				if layer.P > 0.01 and layer.Label.Visible then
					local cfg = layer.Cfg
					if cfg.Mode ~= "Lamp" then TexFX.Drift(layer.Label, cfg, t, layer.Phase) end
					local f = 1
					if cfg.Flicker then f = TexFX.Flicker(layer, t) end
					if cfg.Pulse then f = f * (1 - cfg.Pulse * (0.5 + 0.5 * math.sin(t * 0.9 + layer.Phase))) end
					layer.Label.ImageTransparency = 1 - (1 - (cfg.Transparency or 0.5)) * layer.P * f
				end
			end
		end
		if e.Glitch then TexFX.Glitch(e, t) end
	end
	-- cycling themes (AccentCycle): the accent gradient slowly cycles through the spectrum
	if TingUI.Style.AccentCycle and t - (TingUI._cycleT or 0) > 0.05 then
		TingUI._cycleT = t
		for _, e in ipairs(AccentFills) do if e.Frame.Parent then PaintAccent(e) end end
	end
end)

------------------------------------------------------------------------------
-- Scenes: living artwork a theme draws in and around each window (Style.Scene), and how it answers the player:
-- clicks, tab switches and the window opening. Built from plain frames (no assets, so it works everywhere),
-- paused while the window is hidden, frozen by TingUI.ReducedMotion, crossfaded during theme blends and destroyed
-- once no theme uses it. A scene that errors is switched off with one warning instead of breaking the frame loop.
--
-- TingUI:RegisterScene(name, def), def = {
--   Build(S)                  make frames under S.Root (behind content) or S.Top (over content, clipped to the window)
--   Paint(S)                  optional: recolour from TingUI.Theme / TingUI.Style (called on every theme change)
--   Update(S, dt, t)          every frame while visible. S.W / S.H = window size, S.Mouse = pointer in window pixels
--                             (or nil), S.P = 0..1 presence, S.Fade(tr) = tr blended by presence, S.Still = reduced motion
--   Feedback(S, kind, x, y)   kind = "Click" | "Tab" | "Open"; x, y in window pixels
-- }
------------------------------------------------------------------------------
do
local Kinds = Scenes.Kinds
local GuiService = Service("GuiService")
local atan = math.atan2 or function(y, x) return math.atan(y, x) end
local Warned = {}

local function BackOut(x)
	local c1 = 1.70158
	return 1 + (c1 + 1) * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

-- a straight line from (x1, y1) to (x2, y2), in offset pixels inside parent
local function Seg(parent, x1, y1, x2, y2, th)
	local dx, dy = x2 - x1, y2 - y1
	return New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
		Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + th, th), Rotation = math.deg(atan(dy, dx)),
		BackgroundTransparency = 1, Parent = parent,
	})
end
local function Dot(parent, size, color)
	return New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size), BackgroundColor3 = color or Color3.new(1, 1, 1),
		BackgroundTransparency = 1, Parent = parent,
	}, { CornerFixed(999) })
end
local function Mono(parent, size, alignRight)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Code
	l.TextSize = size
	l.TextTransparency = 1
	l.Text = ""
	l.TextXAlignment = alignRight and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function WindowSize(e)
	local s = e.Frame.Size
	return math.max(s.X.Offset, 1), math.max(s.Y.Offset, 1)
end

local function Fail(S, err)
	S.Broken = true
	pcall(function() S.Root.Visible = false S.Top.Visible = false end)
	if not Warned[S.Name] then
		Warned[S.Name] = true
		warn("[TingUI] scene '" .. S.Name .. "' stopped: " .. FirstLine(err))
	end
end

local function Run(S, fn, ...)
	if S.Broken or type(fn) ~= "function" then return end
	local ok, err = pcall(fn, S, ...)
	if not ok then Fail(S, err) end
end

local function Destroy(e, name)
	local S = e.Scenes[name]
	e.Scenes[name] = nil
	if S then pcall(function() S.Root:Destroy() S.Top:Destroy() end) end
end

local function BuildScene(e, name)
	local S = { Name = name, Def = Kinds[name], Surface = e, P = 0, T = 0, Rng = Random.new(#name * 7919 + 17) }
	S.Root = New("Frame", { Name = "TingUIScene", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0, Parent = e.Frame })
	S.Top = New("Frame", {
		Name = "TingUISceneTop", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40, ClipsDescendants = true, Parent = e.Frame,
	})
	S.W, S.H = WindowSize(e)
	S.Fade = function(tr) return 1 - (1 - math.clamp(tr, 0, 1)) * S.P end
	e.Scenes[name] = S
	Run(S, S.Def.Build)
	return S
end

function Scenes.Sync(e, from, to, a)
	local want = {}
	if from.Scene then want[from.Scene] = (want[from.Scene] or 0) + (1 - a) end
	if to.Scene then want[to.Scene] = (want[to.Scene] or 0) + a end
	e.Scenes = e.Scenes or {}
	for name, p in pairs(want) do
		local S = e.Scenes[name]
		if not S and p > 0.01 and Kinds[name] then
			S = BuildScene(e, name)
			-- arriving with a theme switch plays the scene's opening, the same as opening the window
			if e.Frame.Visible then Run(S, S.Def.Feedback, "Open", S.W / 2, S.H / 2) end
		end
		if S then
			S.P = math.clamp(p, 0, 1)
			Run(S, S.Def.Paint)
		end
	end
	for name, S in pairs(e.Scenes) do
		if not want[name] or want[name] <= 0.01 then
			S.P = 0
			if not StyleBlend then Destroy(e, name) end
		end
	end
end

local function Each(fn)
	for _, e in ipairs(Surfaces) do
		if e.Scenes and e.Frame.Parent then
			for _, S in pairs(e.Scenes) do
				if not S.Broken then fn(e, S) end
			end
		end
	end
end

Connect(RunService.RenderStepped, function(dt)
	local still = TingUI.ReducedMotion
	local mouse = Pointer.Gui()
	Each(function(e, S)
		if S.P <= 0.001 or not e.Frame.Visible then return end
		S.W, S.H = WindowSize(e)
		local abs = e.Frame.AbsolutePosition
		local k = e.Frame.AbsoluteSize.X / S.W
		if k <= 0 then k = 1 end
		local mx, my = (mouse.X - abs.X) / k, (mouse.Y - abs.Y) / k
		S.Mouse = (mx > -260 and mx < S.W + 260 and my > -260 and my < S.H + 260) and Vector2.new(mx, my) or nil
		S.Still = still
		local step = still and 0 or dt
		S.T = S.T + step
		Run(S, S.Def.Update, step, S.T)
	end)
end)

local function Feedback(frame, kind, screen)
	if TingUI.ReducedMotion then return end
	for _, e in ipairs(Surfaces) do
		if e.Scenes and e.Frame == frame and e.Frame.Visible then
			local W = WindowSize(e)
			local abs = e.Frame.AbsolutePosition
			local k = e.Frame.AbsoluteSize.X / W
			if k <= 0 then k = 1 end
			for _, S in pairs(e.Scenes) do
				if not S.Broken and S.P > 0.2 then
					local x, y = S.W / 2, S.H / 2
					if screen then x, y = (screen.X - abs.X) / k, (screen.Y - abs.Y) / k end
					Run(S, S.Def.Feedback, kind, x, y)
				end
			end
		end
	end
end

Connect(UIS.InputBegan, function(input)
	local touch = input.UserInputType == Enum.UserInputType.Touch
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and not touch then return end
	local pos = Pointer.Gui()
	if touch then
		pos = Vector2.new(input.Position.X, input.Position.Y) + (Gui.IgnoreGuiInset and Pointer.Inset() or Vector2.new(0, 0))
	end
	for _, e in ipairs(Surfaces) do
		if e.Scenes and e.Frame.Visible and next(e.Scenes) then
			local p, s = e.Frame.AbsolutePosition, e.Frame.AbsoluteSize
			if pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y then Feedback(e.Frame, "Click", pos) end
		end
	end
end)
TingUI.Events.TabChanged:Connect(function(_, W) if W and W.Frame then Feedback(W.Frame, "Tab") end end)
TingUI.Events.VisibilityChanged:Connect(function(v, W) if v and W and W.Frame then Feedback(W.Frame, "Open") end end)

function TingUI:RegisterScene(name, def)
	assert(type(name) == "string" and type(def) == "table" and type(def.Build) == "function",
		"RegisterScene(name, {Build = fn, Update = fn, Feedback = fn, Paint = fn})")
	Kinds[name] = def
	for _, e in ipairs(Surfaces) do if e.Scenes and e.Scenes[name] then Destroy(e, name) end end
	for _, e in ipairs(Surfaces) do StyleSurface(e) end
end
TingUI.SceneKinds = Kinds

-- TingUI.ReducedMotion: scenes and particles hold still, glitches, lightning and flicker stop. Colours and themes still work.
function TingUI:SetReducedMotion(v)
	self.ReducedMotion = v and true or false
	local opt = self.Options.TingUI_ReducedMotion
	if opt and opt.Value ~= self.ReducedMotion then opt:Set(self.ReducedMotion, true) end
	Each(function(e, S)
		if self.ReducedMotion then S.Top.Visible = false else S.Top.Visible = true end
	end)
end

--------------------------------------------------------------------------
-- Hologram: a projection. Corner brackets lock on when it opens, a scan line sweeps each page, the image tears
-- for a moment now and then, a projector beam glows underneath, and clicks ripple out as hexagons.
--------------------------------------------------------------------------
Kinds.Hologram = {
	Build = function(S)
		S.Acc = {}
		local function A(obj) table.insert(S.Acc, obj) return obj end
		S.Brackets = {}
		for _, c in ipairs({ { 0, 0, 1, 1 }, { 1, 0, -1, 1 }, { 0, 1, 1, -1 }, { 1, 1, -1, -1 } }) do
			local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), Parent = S.Root })
			local anchor = Vector2.new(c[3] > 0 and 0 or 1, c[4] > 0 and 0 or 1)
			local parts = {
				A(New("Frame", { AnchorPoint = anchor, Size = UDim2.fromOffset(20, 2), BackgroundTransparency = 1, Parent = holder })),
				A(New("Frame", { AnchorPoint = anchor, Size = UDim2.fromOffset(2, 20), BackgroundTransparency = 1, Parent = holder })),
				A(New("Frame", { AnchorPoint = anchor, Position = UDim2.fromOffset(c[3] * 5, c[4] * 5), Size = UDim2.fromOffset(3, 3),
					BackgroundTransparency = 1, Parent = holder })),
			}
			table.insert(S.Brackets, { Holder = holder, C = c, Parts = parts })
		end
		-- the projector: a cone of light narrowing to a lens below the window
		S.Beam = {}
		local depth = 92
		for i, f in ipairs({ 0.8, 0.62, 0.46, 0.3, 0.14 }) do
			S.Beam[i] = A(New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.new(f, 0, 0, math.floor(depth * (1 - f) + 8)),
				BackgroundTransparency = 1, Parent = S.Root,
			}, { New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }) }))
		end
		S.LensGlow = A(New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, depth + 6),
			Size = UDim2.fromOffset(130, 14), BackgroundTransparency = 1, Parent = S.Root }, { CornerFixed(7) }))
		S.Lens = A(New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, depth + 6),
			Size = UDim2.fromOffset(52, 3), BackgroundTransparency = 1, Parent = S.Root }, { CornerFixed(2) }))
		-- telemetry printed along the bottom edge
		S.ReadL = A(Mono(S.Root, 10))
		S.ReadL.Position = UDim2.new(0, 2, 1, 9)
		S.ReadL.Size = UDim2.fromOffset(240, 12)
		S.ReadR = A(Mono(S.Root, 10, true))
		S.ReadR.AnchorPoint = Vector2.new(1, 0)
		S.ReadR.Position = UDim2.new(1, -2, 1, 9)
		S.ReadR.Size = UDim2.fromOffset(240, 12)
		-- scan sweep and image tears sit over the content
		S.Sweep = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), Visible = false, Parent = S.Top })
		S.SweepLine = A(New("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 1, Parent = S.Sweep }))
		S.SweepTrail = A(New("Frame", { AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, Parent = S.Sweep },
			{ New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }) }))
		S.Tears = {}
		for i = 1, 3 do S.Tears[i] = A(New("Frame", { BackgroundTransparency = 1, Parent = S.Top })) end
		S.LockT, S.NextSweep, S.NextTear, S.TearUntil, S.NextFlick, S.FlickUntil, S.NextRead = -9, 0.7, 3, 0, 2, 0, 0
	end,
	Paint = function(S)
		local acc = TingUI.Theme.Accent
		for _, o in ipairs(S.Acc) do
			if o:IsA("TextLabel") then o.TextColor3 = acc else o.BackgroundColor3 = acc end
		end
		S.SweepLine.BackgroundColor3 = acc:Lerp(Color3.new(1, 1, 1), 0.5)
		S.Lens.BackgroundColor3 = acc:Lerp(Color3.new(1, 1, 1), 0.6)
	end,
	Update = function(S, dt, t)
		local F, rng = S.Fade, S.Rng
		local lock = math.clamp((t - S.LockT) / 0.5, 0, 1)
		local D = 7 + 1.2 * math.sin(t * 2.1) + 30 * (1 - BackOut(lock))
		for _, b in ipairs(S.Brackets) do
			local c = b.C
			b.Holder.Position = UDim2.new(c[1], -c[3] * D, c[2], -c[4] * D)
			local near = 0
			if S.Mouse then
				local dx, dy = S.Mouse.X - c[1] * S.W, S.Mouse.Y - c[2] * S.H
				near = math.clamp(1 - math.sqrt(dx * dx + dy * dy) / 240, 0, 1)
			end
			local tr = 0.4 - 0.32 * near - (1 - lock) * 0.3
			for i, part in ipairs(b.Parts) do part.BackgroundTransparency = F(tr + (i == 3 and 0.25 or 0)) end
		end
		-- the projection flickers now and then
		local flick = 1
		if not S.Still then
			if t >= S.NextFlick then
				S.NextFlick = t + 2.5 + rng:NextNumber() * 5
				S.FlickUntil = t + 0.06 + rng:NextNumber() * 0.1
			end
			if t < S.FlickUntil then flick = 0.35 + rng:NextNumber() * 0.4 end
		end
		for i, strip in ipairs(S.Beam) do strip.BackgroundTransparency = F(1 - (0.07 + 0.02 * math.sin(t * 3 + i)) * flick) end
		S.Lens.BackgroundTransparency = F(1 - 0.9 * flick)
		S.LensGlow.BackgroundTransparency = F(1 - (0.18 + 0.05 * math.sin(t * 5)) * flick)
		if t >= S.NextRead and not S.Still then
			S.NextRead = t + 0.24
			S.ReadL.Text = string.format("HOLO//LINK  0x%04X  SIG %02d%%", rng:NextInteger(0, 65535), rng:NextInteger(94, 99))
			S.ReadR.Text = string.format("%s PROJECTING  %03d.%02d", (math.floor(t * 2) % 2 == 0) and "[*]" or "[ ]", rng:NextInteger(0, 999), rng:NextInteger(0, 99))
		end
		S.ReadL.TextTransparency = F(1 - 0.5 * flick)
		S.ReadR.TextTransparency = F(1 - 0.5 * flick)
		-- scan sweep
		if S.Still then S.Sweep.Visible = false S.SweepT = nil
		else
			if not S.SweepT and t >= S.NextSweep then S.SweepT = t end
			if S.SweepT then
				local k = (t - S.SweepT) / 1.15
				if k >= 1 then
					S.SweepT, S.NextSweep, S.Sweep.Visible = nil, t + 4 + rng:NextNumber() * 3, false
				else
					local ease = k * k * (3 - 2 * k)
					S.Sweep.Visible = true
					S.Sweep.Position = UDim2.fromOffset(0, 6 + ease * (S.H - 12))
					local fade = math.sin(k * math.pi)
					S.SweepLine.BackgroundTransparency = F(1 - 0.6 * fade)
					S.SweepTrail.BackgroundTransparency = F(1 - 0.11 * fade)
				end
			end
		end
		-- image tears
		if not S.Still and t >= S.NextTear then
			S.NextTear = t + 3 + rng:NextNumber() * 5
			S.TearUntil = t + 0.13
		end
		local tearing = not S.Still and t < S.TearUntil
		for _, bar in ipairs(S.Tears) do
			if tearing and rng:NextNumber() < 0.6 then
				local w = 0.2 + rng:NextNumber() * 0.6
				bar.Size = UDim2.new(w, 0, 0, rng:NextInteger(1, 2))
				bar.Position = UDim2.new(rng:NextNumber() * (1 - w), 0, 0, rng:NextInteger(8, math.max(9, math.floor(S.H) - 8)))
				bar.BackgroundTransparency = F(0.55 + rng:NextNumber() * 0.3)
			else
				bar.BackgroundTransparency = 1
			end
		end
	end,
	Feedback = function(S, kind, x, y)
		if kind == "Open" then S.LockT, S.NextSweep, S.SweepT = S.T, S.T + 0.3, nil return end
		if kind == "Tab" then S.NextSweep, S.SweepT = S.T, nil return end
		if kind ~= "Click" then return end
		local acc = TingUI.Theme.Accent
		for ring = 1, 2 do
			local hex = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(6, 6),
				BackgroundTransparency = 1, Rotation = ring * 15, Parent = S.Top })
			local segs = {}
			for i = 0, 5 do
				local a1, a2 = math.rad(60 * i + 30), math.rad(60 * i + 90)
				local x1, y1 = 0.5 + 0.5 * math.cos(a1), 0.5 + 0.5 * math.sin(a1)
				local x2, y2 = 0.5 + 0.5 * math.cos(a2), 0.5 + 0.5 * math.sin(a2)
				segs[i + 1] = New("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((x1 + x2) / 2, (y1 + y2) / 2), Size = UDim2.new(0.5, 1, 0, 1),
					Rotation = math.deg(atan(y2 - y1, x2 - x1)), BackgroundColor3 = acc, BackgroundTransparency = ring == 1 and 0.1 or 0.45, Parent = hex,
				})
			end
			local size = ring == 1 and 78 or 46
			local delay = (ring - 1) * 0.06
			task.delay(delay, function()
				if not hex.Parent then return end
				TweenService:Create(hex, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
					{ Size = UDim2.fromOffset(size, size), Rotation = hex.Rotation + 30 }):Play()
				for _, s in ipairs(segs) do
					TweenService:Create(s, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
				end
			end)
			task.delay(0.65 + delay, function() hex:Destroy() end)
		end
		local flash = Dot(S.Top, 10, acc:Lerp(Color3.new(1, 1, 1), 0.5))
		flash.Position = UDim2.fromOffset(x, y)
		flash.BackgroundTransparency = 0.3
		TweenService:Create(flash, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(2, 2), BackgroundTransparency = 1 }):Play()
		task.delay(0.3, function() flash:Destroy() end)
	end,
}

--------------------------------------------------------------------------
-- Circuit: the window is a chip seated on a board. Copper traces run out from pins along its edges, current pulses
-- race along them, pins near the pointer warm up, and every click fires a burst down the nearest traces.
--------------------------------------------------------------------------
local function TraceAt(tr, d)
	for i, l in ipairs(tr.Len) do
		if d <= l or i == #tr.Len then
			local a, b = tr.Pts[i], tr.Pts[i + 1]
			local k = l > 0 and math.clamp(d / l, 0, 1) or 0
			return a + (b - a) * k, i
		end
		d = d - l
	end
	return tr.Pts[1], 1
end
local function PadPos(S, pad)
	local n = pad.Side
	if n == "Top" then return pad.F * S.W, 0 elseif n == "Bottom" then return pad.F * S.W, S.H
	elseif n == "Left" then return 0, pad.F * S.H end
	return S.W, pad.F * S.H
end
local function Launch(S, tr, dir)
	for _, p in ipairs(S.Pulses) do
		if not p.Trace then
			p.Trace, p.Dir, p.Speed = tr, dir, 230 + S.Rng:NextNumber() * 110
			p.D = dir > 0 and 0 or tr.Total
			if dir > 0 then tr.Pad.Flash = 1 end
			return true
		end
	end
	return false
end

Kinds.Circuit = {
	Build = function(S)
		local rng = S.Rng
		S.Pads, S.Traces, S.Pulses, S.Queue = {}, {}, {}, {}
		local W, H = math.max(S.W, 240), math.max(S.H, 240)
		local OUT = { Top = Vector2.new(0, -1), Bottom = Vector2.new(0, 1), Left = Vector2.new(-1, 0), Right = Vector2.new(1, 0) }
		for _, side in ipairs({ { "Top", W }, { "Right", H }, { "Bottom", W }, { "Left", H } }) do
			local name, n = side[1], math.floor(side[2] / 30)
			local o = OUT[name]
			for i = 1, n do
				local f = i / (n + 1)
				if name == "Bottom" or name == "Left" then f = 1 - f end -- clockwise order, for the chase light
				local pos = (name == "Top" and UDim2.new(f, 0, 0, 0)) or (name == "Bottom" and UDim2.new(f, 0, 1, 0))
					or (name == "Left" and UDim2.new(0, 0, f, 0)) or UDim2.new(1, 0, f, 0)
				local pad = New("Frame", {
					AnchorPoint = Vector2.new(o.X < 0 and 1 or (o.X > 0 and 0 or 0.5), o.Y < 0 and 1 or (o.Y > 0 and 0 or 0.5)),
					Position = pos + UDim2.fromOffset(o.X * 2, o.Y * 2), Size = o.Y ~= 0 and UDim2.fromOffset(4, 7) or UDim2.fromOffset(7, 4),
					BackgroundTransparency = 1, Parent = S.Root,
				}, { CornerFixed(1) })
				table.insert(S.Pads, { Frame = pad, Side = name, F = f, Pos = pos, Flash = 0 })
			end
		end
		for _, pad in ipairs(S.Pads) do
			if rng:NextNumber() < 0.42 and #S.Traces < 26 then
				local o = OUT[pad.Side]
				local sgn = rng:NextNumber() < 0.5 and -1 or 1
				local perp = Vector2.new(o.Y ~= 0 and sgn or 0, o.X ~= 0 and sgn or 0)
				local p0 = o * 9
				local p1 = p0 + o * rng:NextInteger(8, 44)
				local d = rng:NextInteger(12, 38)
				local p2 = p1 + o * d + perp * d
				local p3 = p2 + o * rng:NextInteger(18, 110)
				local pts = { p0, p1, p2, p3 }
				if rng:NextNumber() < 0.5 then table.insert(pts, p3 + perp * rng:NextInteger(20, 90)) end
				local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), Position = pad.Pos, Parent = S.Root })
				local tr = { Pad = pad, Holder = holder, Pts = pts, Segs = {}, Heat = {}, Len = {}, Total = 0, Phase = rng:NextNumber() * 6.28, ViaFlash = 0 }
				for i = 1, #pts - 1 do
					local a, b = pts[i], pts[i + 1]
					tr.Segs[i] = Seg(holder, a.X, a.Y, b.X, b.Y, 1.5)
					tr.Heat[i] = 0
					tr.Len[i] = (b - a).Magnitude
					tr.Total = tr.Total + tr.Len[i]
				end
				local last = pts[#pts]
				tr.Via = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(last.X, last.Y), Size = UDim2.fromOffset(7, 7),
					BackgroundTransparency = 1, Parent = holder }, { CornerFixed(4) })
				tr.ViaRing = New("UIStroke", { Thickness = 1.5, Transparency = 1, Parent = tr.Via })
				pad.Trace = tr
				table.insert(S.Traces, tr)
			end
		end
		for i = 1, 16 do
			S.Pulses[i] = { Glow = Dot(S.Root, 15), Head = Dot(S.Root, 4) }
		end
		-- chip markings: pin 1 and a part number
		S.Pin1 = Dot(S.Root, 5)
		S.Pin1.Position = UDim2.fromOffset(-13, -13)
		S.Mark = Mono(S.Root, 9, true)
		S.Mark.AnchorPoint = Vector2.new(1, 0)
		S.Mark.Position = UDim2.new(1, -4, 1, 12)
		S.Mark.Size = UDim2.fromOffset(220, 11)
		S.Mark.Text = "TINGUI  LX-" .. tostring(math.floor(W)) .. "  REV 6"
		S.Solder = {}
		S.NextPulse = 0.3
	end,
	Paint = function(S)
		local st, T = TingUI.Style, TingUI.Theme
		S.Copper = st.TraceColor or T.Border
		S.Energy = st.EnergyColor or T.Accent
		for _, tr in ipairs(S.Traces) do
			for _, seg in ipairs(tr.Segs) do seg.BackgroundColor3 = S.Copper end
			tr.ViaRing.Color = S.Copper
		end
		for _, p in ipairs(S.Pulses) do
			p.Glow.BackgroundColor3 = S.Energy
			p.Head.BackgroundColor3 = S.Energy:Lerp(Color3.new(1, 1, 1), 0.6)
		end
		S.Pin1.BackgroundColor3 = S.Copper
		S.Mark.TextColor3 = S.Copper
	end,
	Update = function(S, dt, t)
		local F, rng = S.Fade, S.Rng
		if not S.Still then
			if t >= S.NextPulse and #S.Traces > 0 then
				S.NextPulse = t + 0.18 + rng:NextNumber() * 0.4
				Launch(S, S.Traces[rng:NextInteger(1, #S.Traces)], rng:NextNumber() < 0.6 and -1 or 1)
			end
			for i = #S.Queue, 1, -1 do
				local q = S.Queue[i]
				if t >= q.At then
					table.remove(S.Queue, i)
					if q.Trace then Launch(S, q.Trace, q.Dir) end
					if q.Pad then q.Pad.Flash = math.max(q.Pad.Flash, q.Amount or 1) end
				end
			end
		end
		-- pulses
		for _, p in ipairs(S.Pulses) do
			local tr = p.Trace
			if tr and not S.Still then
				p.D = p.D + p.Dir * p.Speed * dt
				if p.D < 0 or p.D > tr.Total then
					if p.Dir < 0 then tr.Pad.Flash = 1 else tr.ViaFlash = 1 end
					p.Trace = nil
				else
					local pt, seg = TraceAt(tr, p.D)
					tr.Heat[seg] = 1
					local pos = tr.Pad.Pos + UDim2.fromOffset(pt.X, pt.Y)
					p.Head.Position, p.Glow.Position = pos, pos
				end
			end
			local on = p.Trace ~= nil and not S.Still
			p.Head.BackgroundTransparency = on and F(0.05) or 1
			p.Glow.BackgroundTransparency = on and F(0.72) or 1
		end
		-- traces shimmer with a slow current and glow where a pulse just ran
		local decay = math.min(1, dt * 3.2)
		for _, tr in ipairs(S.Traces) do
			for i, seg in ipairs(tr.Segs) do
				local h = tr.Heat[i]
				seg.BackgroundTransparency = F(0.56 + 0.1 * math.sin(t * 1.7 + tr.Phase + i * 0.6) - h * 0.42)
				seg.BackgroundColor3 = h > 0.02 and S.Copper:Lerp(S.Energy, h * 0.8) or S.Copper
				tr.Heat[i] = h * (1 - decay)
			end
			tr.ViaRing.Transparency = F(0.45 - tr.ViaFlash * 0.4)
			tr.ViaRing.Color = tr.ViaFlash > 0.02 and S.Copper:Lerp(S.Energy, tr.ViaFlash) or S.Copper
			tr.ViaFlash = tr.ViaFlash * (1 - decay)
		end
		-- pins: brighter with a trace, warmer near the pointer, flashing when current arrives
		for _, pad in ipairs(S.Pads) do
			local near = 0
			if S.Mouse then
				local px, py = PadPos(S, pad)
				local dx, dy = S.Mouse.X - px, S.Mouse.Y - py
				near = math.clamp(1 - math.sqrt(dx * dx + dy * dy) / 90, 0, 1)
			end
			local glow = math.max(pad.Flash, near * 0.7)
			pad.Frame.BackgroundTransparency = F((pad.Trace and 0.35 or 0.62) - glow * 0.35)
			pad.Frame.BackgroundColor3 = glow > 0.02 and S.Copper:Lerp(S.Energy, glow) or S.Copper
			pad.Flash = pad.Flash * (1 - decay)
		end
		S.Pin1.BackgroundTransparency = F(0.35)
		S.Mark.TextTransparency = F(0.45)
	end,
	Feedback = function(S, kind, x, y)
		if kind == "Click" then
			-- burst down the traces whose pins are nearest the click
			local list = {}
			for _, tr in ipairs(S.Traces) do
				local px, py = PadPos(S, tr.Pad)
				table.insert(list, { tr, (px - x) ^ 2 + (py - y) ^ 2 })
			end
			table.sort(list, function(a, b) return a[2] < b[2] end)
			for i = 1, math.min(4, #list) do table.insert(S.Queue, { At = S.T + (i - 1) * 0.045, Trace = list[i][1], Dir = 1 }) end
			-- a square solder flash where you clicked
			local sq = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(6, 6),
				Rotation = 45, BackgroundTransparency = 1, Parent = S.Top })
			local st = New("UIStroke", { Thickness = 1.5, Color = S.Energy or TingUI.Theme.Accent, Transparency = 0.1, Parent = sq })
			TweenService:Create(sq, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(34, 34), Rotation = 135 }):Play()
			TweenService:Create(st, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
			task.delay(0.45, function() sq:Destroy() end)
		elseif kind == "Tab" or kind == "Open" then
			-- boot: a chase light runs round the pins, then current pours out along every trace
			local n = #S.Pads
			for i, pad in ipairs(S.Pads) do table.insert(S.Queue, { At = S.T + (i / math.max(n, 1)) * 0.55, Pad = pad }) end
			for i, tr in ipairs(S.Traces) do
				table.insert(S.Queue, { At = S.T + 0.1 + (i / math.max(#S.Traces, 1)) * 0.5, Trace = tr, Dir = 1 })
			end
		end
	end,
}

--------------------------------------------------------------------------
-- Ocean: the window floats in water. Two layers of waves roll along its bottom edge (the front one capped with
-- foam) and swell toward the pointer when it comes near; caustic light shimmers across the header. Switching to the
-- theme (or opening the window) sends a tide washing up over the whole window and draining away, a tab switch rolls
-- a swell through, and a click drops ripples and a few bubbles where you clicked.
--------------------------------------------------------------------------
local function Smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local OCEAN_COL = 8
local function OceanColumns(S)
	for _, list in ipairs({ S.Back or {}, S.Front or {}, S.Crest or {} }) do
		for _, f in ipairs(list) do f:Destroy() end
	end
	S.Back, S.Front, S.Crest = {}, {}, {}
	local n = math.ceil(S.W / OCEAN_COL) + 1
	for i = 1, n do
		local x = (i - 1) * OCEAN_COL
		S.Back[i] = New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, x, 1, 0), Size = UDim2.fromOffset(OCEAN_COL + 1, 0),
			BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, Parent = S.Top })
		S.Front[i] = New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, x, 1, 0), Size = UDim2.fromOffset(OCEAN_COL + 1, 0),
			BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2, Parent = S.Top })
		S.Crest[i] = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, x, 1, 0), Size = UDim2.fromOffset(OCEAN_COL + 1, 2),
			BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3, Parent = S.Top })
	end
	S.ColsFor = S.W
	if S.Water then
		for i = 1, n do
			S.Back[i].BackgroundColor3 = S.Deep
			S.Front[i].BackgroundColor3 = S.Water
			S.Crest[i].BackgroundColor3 = S.Foam
		end
	end
end
local function OceanBubble(S, x, y, rise, size, delay)
	task.delay(delay or 0, function()
		if not S.Top.Parent then return end
		local b = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1, ZIndex = 4, Parent = S.Top }, { CornerFixed(999) })
		local rim = New("UIStroke", { Color = S.Foam or Color3.new(1, 1, 1), Thickness = 1, Transparency = S.Fade(0.25), Parent = b })
		local hi = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.32, 0.3), Size = UDim2.fromOffset(math.max(1, size * 0.3), math.max(1, size * 0.3)),
			BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = S.Fade(0.3), Parent = b }, { CornerFixed(999) })
		local life = 0.55 + rise / 220
		TweenService:Create(b, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.fromOffset(x + (math.random() - 0.5) * 16, y - rise) }):Play()
		task.delay(life, function()
			if not b.Parent then return end
			-- pop: the bubble snaps open into a ring and is gone
			TweenService:Create(b, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(size * 2.2, size * 2.2) }):Play()
			TweenService:Create(rim, TweenInfo.new(0.14), { Transparency = 1 }):Play()
			TweenService:Create(hi, TweenInfo.new(0.1), { BackgroundTransparency = 1 }):Play()
			task.delay(0.16, function() b:Destroy() end)
		end)
	end)
end
Kinds.Ocean = {
	Build = function(S)
		S.Tide, S.TideT, S.Swell, S.SwellT = 0, nil, 0, nil
		OceanColumns(S)
		S.Caustics = {}
		for i = 1, 7 do
			local c = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = S.Root }, { CornerFixed(999),
				New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }) })
			S.Caustics[i] = { Frame = c, X = S.Rng:NextNumber(), Y = S.Rng:NextNumber(), W = S.Rng:NextInteger(60, 150), Ph = S.Rng:NextNumber() * 6.28,
				Sp = 0.15 + S.Rng:NextNumber() * 0.25 }
		end
	end,
	Paint = function(S)
		local st, T = TingUI.Style, TingUI.Theme
		S.Water = st.WaterColor or T.Accent
		S.Foam = st.FoamColor or T.Text
		S.Deep = S.Water:Lerp(T.Background, 0.45)
		for i = 1, #(S.Front or {}) do
			S.Back[i].BackgroundColor3 = S.Deep
			S.Front[i].BackgroundColor3 = S.Water
			S.Crest[i].BackgroundColor3 = S.Foam
		end
		for _, c in ipairs(S.Caustics or {}) do c.Frame.BackgroundColor3 = S.Foam:Lerp(S.Water, 0.4) end
	end,
	Update = function(S, dt, t)
		local F = S.Fade
		if S.ColsFor ~= S.W then OceanColumns(S) Kinds.Ocean.Paint(S) end
		-- the tide that washes over the window on a theme switch: up fast, a beat at the top, then draining away
		if S.TideT then
			S.TideT = S.TideT + dt
			local k = S.TideT
			if k < 0.55 then S.Tide = 1.12 * (1 - (1 - k / 0.55) ^ 3)
			elseif k < 0.68 then S.Tide = 1.12
			elseif k < 1.6 then S.Tide = 1.12 * (1 - Smooth((k - 0.68) / 0.92))
			else S.Tide, S.TideT = 0, nil end
			if S.TideT and k > 0.7 and not S.TideBubbles then
				S.TideBubbles = true
				for i = 1, 16 do
					OceanBubble(S, S.Rng:NextNumber() * S.W, S.H * (0.35 + S.Rng:NextNumber() * 0.6), 40 + S.Rng:NextNumber() * 120, S.Rng:NextInteger(3, 9), i * 0.03)
				end
			end
		end
		if S.SwellT then
			S.SwellT = S.SwellT + dt
			S.Swell = math.max(0, 1 - S.SwellT / 0.9) * math.sin(math.min(S.SwellT / 0.9, 1) * math.pi) * 1.6
			if S.SwellT > 0.9 then S.SwellT, S.Swell = nil, 0 end
		end
		local W, H = S.W, S.H
		local tide = S.Tide * H
		local mx, near = 0, 0
		if S.Mouse and S.Mouse.X > -40 and S.Mouse.X < W + 40 then
			mx = S.Mouse.X
			near = math.clamp(1 - (H - S.Mouse.Y) / 110, 0, 1) * (S.Mouse.Y < H + 60 and 1 or 0)
		end
		local amp = 4 * (1 + S.Swell)
		local flood = math.clamp(S.Tide / 0.3, 0, 1)
		for i, col in ipairs(S.Front) do
			local x = (i - 1) * OCEAN_COL + OCEAN_COL / 2
			local bump = near > 0 and 11 * near * math.exp(-((x - mx) / 46) ^ 2) or 0
			local hf = 10 + tide + amp * (math.sin(x * 0.034 - t * 1.7) * 0.6 + math.sin(x * 0.012 + t * 0.85) * 0.4) + bump + S.Swell * 6
			local hb = 15 + tide * 1.03 + amp * 1.2 * (math.sin(x * 0.022 + t * 1.1 + 1.3) * 0.7 + math.sin(x * 0.05 - t * 0.6) * 0.3) + bump * 0.6 + S.Swell * 8
			hf, hb = math.max(0, hf), math.max(0, hb)
			col.Size = UDim2.fromOffset(OCEAN_COL + 1, hf)
			S.Back[i].Size = UDim2.fromOffset(OCEAN_COL + 1, hb)
			S.Crest[i].Position = UDim2.new(0, (i - 1) * OCEAN_COL, 1, -hf)
			-- more see-through while it floods the window, so the UI stays readable under the water
			col.BackgroundTransparency = F(0.76 + flood * 0.08)
			S.Back[i].BackgroundTransparency = F(0.86 + flood * 0.05)
			S.Crest[i].BackgroundTransparency = F(0.42 + 0.25 * (0.5 + 0.5 * math.sin(x * 0.09 + t * 2.2)))
		end
		-- caustic light across the header
		for _, c in ipairs(S.Caustics) do
			local cx = (c.X + math.sin(t * c.Sp + c.Ph) * 0.08) * W
			local cy = 10 + c.Y * 70 + math.sin(t * c.Sp * 1.3 + c.Ph) * 8
			local w = c.W * (0.8 + 0.2 * math.sin(t * 0.7 + c.Ph))
			c.Frame.Position = UDim2.fromOffset(cx, cy)
			c.Frame.Size = UDim2.fromOffset(w, w * 0.32)
			c.Frame.Rotation = math.sin(t * 0.3 + c.Ph) * 18
			c.Frame.BackgroundTransparency = F(0.9 + 0.06 * math.sin(t * 1.4 + c.Ph * 2))
		end
	end,
	Feedback = function(S, kind, x, y)
		if kind == "Open" then
			S.TideT, S.TideBubbles = 0, false
		elseif kind == "Tab" then
			S.SwellT = 0
		elseif kind == "Click" then
			-- ripples spread out (flattened, like on a surface) and a few bubbles escape upward
			for i = 0, 2 do
				task.delay(i * 0.09, function()
					if not S.Top.Parent then return end
					local r = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(6, 4),
						BackgroundTransparency = 1, ZIndex = 5, Parent = S.Top }, { CornerFixed(999) })
					local st = New("UIStroke", { Color = S.Foam or Color3.new(1, 1, 1), Thickness = 1.5 - i * 0.3, Transparency = S.Fade(0.2 + i * 0.15), Parent = r })
					TweenService:Create(r, TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(84 - i * 14, 44 - i * 7) }):Play()
					TweenService:Create(st, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
					task.delay(0.72, function() r:Destroy() end)
				end)
			end
			for i = 1, 4 do OceanBubble(S, x + (math.random() - 0.5) * 18, y, 26 + math.random() * 40, math.random(3, 7), 0.05 + i * 0.06) end
		end
	end,
}

end

local Scales = {}
local function RegisterScale(parent)
	local sc = New("UIScale", { Scale = TingUI.Scale, Parent = parent })
	table.insert(Scales, sc)
	return sc
end

function TingUI:SetScale(n)
	n = math.clamp(n, 0.6, 1.6)
	self.Scale = n
	for i = #Scales, 1, -1 do
		local sc = Scales[i]
		if sc.Parent then sc.Scale = n else table.remove(Scales, i) end
	end
end

-- keeps UI toggles in sync when a setting is changed from code / dock
local function SyncOption(flag, v)
	local o = TingUI.Options[flag]
	if o and o.Value ~= v then o:Set(v, true) end
end

-- High-res icons: 96px PNGs drawn as vectors (assets/icons in the repo), tinted by the theme through ImageColor3.
-- They are downloaded once and cached in <Folder>/icons, then loaded with getcustomasset. Until they're ready (or where
-- the executor can't load files, e.g. Studio) every icon falls back to the vector version drawn from frames below.
-- Studio / your own uploads: pass Icons = {window = "rbxassetid://...", ...} as a load option, or set TingUI.IconAssets.
local ICON_NAMES = { "window", "scan", "keyboard", "command", "user", "bell", "check", "cross", "warn", "info", "discord",
	"gear", "snow", "list", "heart", "chevron", "search", "eye", "sparkle", "lock", "palette" }
local ICON_VERSION = "v1"
local IconImages = {}
TingUI.IconAssets = IconImages
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
		if not ok then warn("[TingUI] icon '" .. tostring(kind) .. "' failed: " .. tostring(err)) end
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
	local m = Pointer.Gui()
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
			Pointer.Calibrate(frame, i)
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
-- snapKey (optional): "Dock" / "Hotkeys" / "Watermark". When TingUI.SnapBack allows it, the target glides
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
			local sb = TingUI.SnapBack
			if snapKey and sb.Enabled and sb[snapKey] then
				token = token + 1
				local mine = token
				task.delay(sb.Delay, function()
					if mine ~= token or dragging or TingUI.Unloaded then return end
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
function TingUI:ResetHudPositions()
	for target, home in pairs(SnapHomes) do
		if target.Parent then
			TweenService:Create(target, TweenInfo.new(0.75, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = home }):Play()
		end
	end
end

-- make the current spots the new home positions
function TingUI:SetHudHome()
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
-- Retired themes: a script that asks for one at load (Theme = "Candy", Configure({Theme = ...})) gets the closest theme
-- still shipped instead of a warning. Saved configs naming one keep the current theme, as before. Your own
-- RegisterTheme of the same name always wins. Add your own with TingUI.PresetAliases.Old = "New".
TingUI.PresetAliases = {
	Candy = "Rose", Abyss = "Ocean", Criminality = "Storm", MLG = "Lavender",
	Synthwave = "Cosmos", Noir = "Mono", Haunted = "Royal", Parchment = "Lavender", Emerald = "Lavender", Prism = "Hologram",
}
local function PresetName(l) return (tostring(l):gsub(" %(Default%)$", "")) end
local function PresetAlias(n)
	n = PresetName(n)
	local alias = TingUI.PresetAliases[n]
	if not TingUI.Presets[n] and type(alias) == "string" and TingUI.Presets[alias] then return alias end
	return n
end
TingUI.PresetLabel = PresetLabel

function TingUI:ApplyPreset(name)
	name = PresetName(name)
	local p = self.Presets[name]
	if not p then return end
	self.Preset = name
	local colors = {}
	for k, v in pairs(p) do if k ~= "Style" then colors[k] = v end end
	self:SetTheme(colors, self.ThemeTransition)
	self:SetStyle(p.Style or {}, self.ThemeTransition)
	SyncOption("TingUI_Preset", PresetLabel(name))
end

local ThemeToken = 0
local function ApplyThemeNow()
	local T = TingUI.Theme
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
function TingUI:SetTheme(t, fade)
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
	-- settle pass: hover / press tweens that were started mid-blend aim at in-between colours and can finish after
	-- the blend does. Once everything has come to rest, every bound colour is written once more from the final theme.
	local function Settle(after)
		task.delay(after, function()
			if mine == ThemeToken and not TingUI.Unloaded and not TingUI._themeTarget then ApplyThemeNow() end
		end)
	end
	if fade <= 0 or #Themed > 9000 then
		self._themeTarget = nil
		for k, v in pairs(N) do T[k] = v end
		ApplyThemeNow()
		Settle(0.35)
		return
	end
	self._themeTarget = N
	local before = {}
	for k, v in pairs(T) do before[k] = v end
	task.spawn(function()
		local steps = math.max(2, math.floor(fade * 30))
		for i = 1, steps do
			if mine ~= ThemeToken or TingUI.Unloaded then return end
			local a = i / steps
			a = 1 - (1 - a) * (1 - a)
			for k, v in pairs(N) do
				local b = before[k]
				if i < steps and typeof(v) == "Color3" and typeof(b) == "Color3" then T[k] = b:Lerp(v, a) else T[k] = v end
			end
			ApplyThemeNow()
			if i < steps then task.wait(fade / steps) end
		end
		if mine == ThemeToken then
			TingUI._themeTarget = nil
			Settle(0.35)
		end
	end)
end

------------------------------------------------------------------------------
-- Root GUI, popups, tooltip
------------------------------------------------------------------------------

Gui = Instance.new("ScreenGui")
Gui.Name = LoadOptions.Name or (InstanceId == "default" and "TingUI" or ("TingUI_" .. InstanceId))
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = LoadOptions.DisplayOrder or 10000
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- pinned so the UI measures and lays out the same in every game, device and executor: no safe-area insets or
-- notch clipping shifting it, and no auto-translation changing text widths
Gui.AutoLocalize = false
pcall(function() Gui.ScreenInsets = Enum.ScreenInsets.None end)
pcall(function() Gui.ClipToDeviceSafeArea = false end)
pcall(function() Gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None end)
-- Parent: your own Instance if given, else gethui() / CoreGui on executors, else the player's PlayerGui (normal games)
function TingUI:SetParent(parent)
	local ok = false
	if typeof(parent) == "Instance" then ok = pcall(function() Gui.Parent = parent end) end
	if (not ok or not Gui.Parent) and gethui then ok = pcall(function() Gui.Parent = gethui() end) end
	if (not ok or not Gui.Parent) and getgenv then ok = pcall(function() Gui.Parent = Service("CoreGui") end) end
	if not ok or not Gui.Parent then Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
	return Gui.Parent
end
if syn and syn.protect_gui then pcall(syn.protect_gui, Gui) end
TingUI:SetParent(LoadOptions.Parent)

-- Screen size in GUI pixels. A ScreenGui that was parented a moment ago can still report 0 x 0 (common when a game's
-- LocalScript requires TingUI right away), which used to squash new windows to their minimum size.
function TingUI:_Viewport()
	local vp = Gui.AbsoluteSize
	if vp.X >= 50 and vp.Y >= 50 then return vp end
	local cam = workspace.CurrentCamera
	if cam and cam.ViewportSize.X >= 50 then return cam.ViewportSize end
	return Vector2.new(1280, 720)
end

-- Scale guard: some games run "auto-scale" scripts that drop a UIScale or UIAspectRatioConstraint into every GUI they
-- find. Inside TingUI that resizes everything, differently in every game. Foreign ones are removed (ScaleGuard = false
-- allows them); TingUI's own scale is TingUI.Scale / SetScale only.
TingUI.ScaleGuard = LoadOptions.ScaleGuard ~= false
Connect(Gui.DescendantAdded, function(d)
	if not TingUI.ScaleGuard or d:GetAttribute("TingUI") then return end
	if d:IsA("UIScale") or d:IsA("UIAspectRatioConstraint") then
		task.defer(function()
			if d.Parent and not d:GetAttribute("TingUI") and TingUI.ScaleGuard then
				if not TingUI._scaleGuardWarned then
					TingUI._scaleGuardWarned = true
					warn("[TingUI] removed a " .. d.ClassName .. " another script put inside TingUI (" .. d:GetFullName() .. ") so the UI keeps its size. Load with ScaleGuard = false to allow it.")
				end
				d:Destroy()
			end
		end)
	end
end)

-- windows stay reachable when the screen changes size (window resized, phone rotated); their size never changes
Connect(Gui:GetPropertyChangedSignal("AbsoluteSize"), function()
	local vp = TingUI:_Viewport()
	for _, w in ipairs(TingUI.Windows) do
		local f = w.Frame
		if f and f.Parent then
			local p, s = f.AbsolutePosition, f.AbsoluteSize
			local dx = (p.X + s.X < 80) and (80 - p.X - s.X) or ((p.X > vp.X - 80) and (vp.X - 80 - p.X) or 0)
			local dy = (p.Y < 0) and -p.Y or ((p.Y > vp.Y - 40) and (vp.Y - 40 - p.Y) or 0)
			if dx ~= 0 or dy ~= 0 then f.Position = f.Position + UDim2.fromOffset(dx, dy) end
		end
	end
end)

Overlay = New("Frame", {
	Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = Gui,
})

TingUI.Gui = Gui

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
local HideHintNow -- set once the hint card exists
local function ShowPopup(frame, trigger, onClose)
	ClosePopup()
	if HideHintNow then HideHintNow() end
	local sc = frame:FindFirstChildOfClass("UIScale")
	if not sc then sc = New("UIScale", { Parent = frame }) end
	sc.Scale = TingUI.Scale
	local full = frame.Size
	local vp = TingUI:_Viewport()
	local w, h = full.X.Offset * TingUI.Scale, full.Y.Offset * TingUI.Scale
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

-- Fader: fades a whole Frame tree like a CanvasGroup would, but leaves text rendered natively.
-- CanvasGroups rasterise their contents to a texture, which makes text soft (worse with UI scale or half-pixel
-- positions), so hints, notifications and dialogs use this instead. At rest (Alpha = 0) it lets go of the tree
-- completely, so elements can change their own transparency freely. Mark an object with the attribute NoFade
-- when it animates its own transparency.
local Fader
do
local FADE_PROPS = {
	TextLabel = { "BackgroundTransparency", "TextTransparency" }, TextButton = { "BackgroundTransparency", "TextTransparency" },
	TextBox = { "BackgroundTransparency", "TextTransparency" }, ImageLabel = { "BackgroundTransparency", "ImageTransparency" },
	ImageButton = { "BackgroundTransparency", "ImageTransparency" }, Frame = { "BackgroundTransparency" },
	ScrollingFrame = { "BackgroundTransparency" }, UIStroke = { "Transparency" },
}
function Fader(root)
	local F = { Alpha = 0, Root = root }
	local bases
	local value = Instance.new("NumberValue")
	local function Capture()
		bases = {}
		local function add(o)
			local props = FADE_PROPS[o.ClassName]
			if props and not o:GetAttribute("NoFade") then
				for _, prop in ipairs(props) do table.insert(bases, { o, prop, o[prop] }) end
			end
		end
		add(root)
		for _, d in ipairs(root:GetDescendants()) do add(d) end
	end
	function F:Set(a)
		a = math.clamp(a, 0, 1)
		F.Alpha = a
		if a > 0.001 and not bases then Capture() end
		if not bases then return end
		for _, b in ipairs(bases) do
			if b[1].Parent then b[1][b[2]] = 1 - (1 - b[3]) * (1 - a) end
		end
		if a <= 0.001 then bases = nil end
	end
	-- re-read resting values (call after rebuilding content while hidden)
	function F:Recapture()
		if bases then
			local a = F.Alpha
			F:Set(0)
			F:Set(a)
		end
	end
	Connect(value:GetPropertyChangedSignal("Value"), function() F:Set(value.Value) end)
	function F:Tween(time, goal, style, dir)
		value.Value = F.Alpha
		local tw = TweenService:Create(value, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), { Value = goal })
		tw:Play()
		return tw
	end
	function F:Hide() F:Set(1) value.Value = 1 end
	return F
end
end
TingUI.Fader = Fader

-- Hover explanations: a card that fades and lifts in after a short rest, glides between elements,
-- and fades out when the mouse leaves. Used by Description = "..." on any element, tooltips, dock buttons and chips.
local Hint = { Token = 0 }
local HintCard = New("Frame", {
	Name = "TingUIHint", Visible = false, Size = UDim2.fromOffset(240, 0), AutomaticSize = Enum.AutomaticSize.Y,
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
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = 13, Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 303, LayoutOrder = 1, TextColor3 = TingUI.Theme.Text, Parent = HintBody,
})
-- body text uses the brighter Label colour at 12px so it reads cleanly on every theme
local HintText = New("TextLabel", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = 12, Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 303, LayoutOrder = 2, TextColor3 = TingUI.Theme.Label, LineHeight = 1.08, Parent = HintBody,
})
local HintFade = Fader(HintCard)
HintFade:Hide()

local function HintMeasure(title, body)
	local w, h = 0, 0
	pcall(function()
		local b = TextService:GetTextSize(body, 12, Enum.Font.GothamMedium, Vector2.new(224, 10000))
		w, h = b.X, b.Y * 1.08
		if title and title ~= "" then
			local t = TextService:GetTextSize(title, 13, Enum.Font.GothamBold, Vector2.new(224, 10000))
			w = math.max(w, t.X)
			h = h + t.Y + 3
		end
	end)
	if not w or w <= 0 then w, h = 224, 40 end
	w = math.clamp(math.ceil(w) + 30, 110, 256)
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
	local vp = TingUI:_Viewport()
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

-- true while a dropdown / picker popup is open and the anchor isn't inside it: hints wait until it closes
local function PopupBlocks(anchor)
	return OpenPopup ~= nil and OpenPopup.Frame ~= nil and not anchor:IsDescendantOf(OpenPopup.Frame)
end
local function ShowHint(anchor, title, body)
	if not TingUI.Hints or type(body) ~= "string" or body == "" then return end
	if PopupBlocks(anchor) then return end
	Hint.Token = Hint.Token + 1
	local mine = Hint.Token
	local gliding = HintCard.Visible and HintFade.Alpha < 0.6
	task.delay(gliding and 0.04 or TingUI.HintDelay, function()
		if mine ~= Hint.Token or TingUI.Unloaded or not anchor.Parent then return end
		if PopupBlocks(anchor) then return end
		HintTitle.Text = title or ""
		HintTitle.Visible = title ~= nil and title ~= ""
		HintText.Text = body
		local w, h = HintMeasure(title, body)
		HintCard.Size = UDim2.fromOffset(w, 0)
		local x, y, side, cy = HintSpot(anchor, w, h)
		x, y = math.floor(x + 0.5), math.floor(y + 0.5)
		-- the accent strip sits on the side facing the element, level with it, like a pointer
		local stripY = math.clamp(cy - y - 9, 6, math.max(6, h - 24))
		local stripGoal = { Position = side == "left" and UDim2.new(1, -2, 0, stripY) or UDim2.fromOffset(0, stripY) }
		HintStrip.Size = UDim2.fromOffset(2, 18)
		if gliding then
			TweenService:Create(HintCard, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{ Position = UDim2.fromOffset(x, y) }):Play()
			HintFade:Tween(0.22, 0, Enum.EasingStyle.Quint)
			TweenService:Create(HintStrip, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), stripGoal):Play()
			TweenService:Create(HintScale, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		else
			HintStrip.Position = stripGoal.Position
			local dx = side == "left" and 8 or (side == "right" and -8 or 0)
			HintCard.Position = UDim2.fromOffset(x + dx, side == "below" and y + 7 or y)
			HintScale.Scale = 0.95
			HintFade:Hide()
			HintCard.Visible = true
			TweenService:Create(HintCard, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{ Position = UDim2.fromOffset(x, y) }):Play()
			HintFade:Tween(0.24, 0, Enum.EasingStyle.Quint)
			TweenService:Create(HintScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)
end

local function HideHint(now)
	Hint.Token = Hint.Token + 1
	local mine = Hint.Token
	task.delay(now == true and 0 or 0.07, function()
		if mine ~= Hint.Token then return end
		HintFade:Tween(0.15, 1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(HintScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.97 }):Play()
		task.delay(0.16, function() if mine == Hint.Token then HintCard.Visible = false end end)
	end)
end
HideHintNow = function() HideHint(true) end
TingUI.ShowHint, TingUI.HideHint = function(_, anchor, title, body) ShowHint(anchor, title, body) end, function() HideHint() end

-- title / body may be strings or functions (read each time the hint opens)
local function AttachHint(inst, title, body)
	Connect(inst.MouseEnter, function()
		local t = type(title) == "function" and title() or title
		local b = type(body) == "function" and body() or body
		ShowHint(inst, t, b)
	end)
	Connect(inst.MouseLeave, function() HideHint() end)
	Connect(inst.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			Pointer.Calibrate(inst, i)
			HideHint()
		end
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
		TingUI.Options[self.Flag] = nil
		TingUI.Flags[self.Flag] = nil
	end
	if self.Row then self.Row:Destroy() end
end

local function Register(opt, flag)
	if not flag then return end
	opt.Flag = flag
	TingUI.Options[flag] = opt
	TingUI.Flags[flag] = opt.Value
end

local function Fire(opt, ...)
	local label = tostring(opt.Type) .. " '" .. tostring(opt._text or opt.Flag or opt.Name or "?") .. "'"
	if opt.Flag then
		TingUI.Flags[opt.Flag] = opt.Value
		TingUI.Events.FlagChanged:Fire(opt.Flag, opt.Value)
	end
	if opt.Callback then SafeCall(label, opt.Callback, ...) end
	for _, cb in ipairs(opt.Listeners) do SafeCall(label, cb, ...) end
end

-- everything searchable from the command palette
TingUI._Catalog = {}
TingUI._Panels = {}
TingUI._presetDropdowns = {}
local function CatalogAdd(group, opt, name)
	if not name then return end
	opt._text = opt._text or name
	table.insert(TingUI._Catalog, { Opt = opt, Name = name, Path = group._path or "", Tab = group._tab, Group = group })
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
	-- task-specific kinds, each with its own animated glyph
	Download = { Key = "Info", Icon = "download", Shape = "circle" },
	Upload = { Key = "Info", Icon = "upload", Shape = "circle" },
	Message = { Key = "Accent", Icon = "message", Shape = "square" },
	Friend = { Key = "Success", Icon = "user", Shape = "circle" },
	Achievement = { Key = "Caution", Icon = "sparkle", Shape = "diamond" },
	Security = { Key = "Error", Icon = "lock", Shape = "square" },
	Update = { Key = "Accent", Icon = "gear", Shape = "circle" },
	Heart = { Key = "Error", Icon = "heart", Shape = "circle" },
}
TingUI.NotifyTypes = {}
for k in pairs(NOTIFY_KINDS) do table.insert(TingUI.NotifyTypes, k) end
table.sort(TingUI.NotifyTypes)
local NotifyCount = 0
local LiveNotifs = {}
local NOTIFY_POS = { TopRight = { 1, 0 }, BottomRight = { 1, 1 }, TopLeft = { 0, 0 }, BottomLeft = { 0, 1 } }
TingUI.NotifyPositions = { "TopRight", "BottomRight", "TopLeft", "BottomLeft" }
TingUI.NotificationHistory = {}

local function Spinner(parent, color)
	return New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(14, 14), Parent = parent }, {
		CornerFixed(7),
		New("UIStroke", { Thickness = 2, Color = color }, {
			New("UIGradient", { Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(0.52, 1), NumberSequenceKeypoint.new(1, 1) }) }),
		}),
	})
end

-- glyphs that aren't icons: an arrow dropping into a tray (download / upload) and a chat bubble with typing dots
local NotifyKit = {}
function NotifyKit.ArrowGlyph(parent, size, color, up)
	local g = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), ClipsDescendants = true, Parent = parent })
	local arrow = New("Frame", { Name = "Arrow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = g })
	local th = math.max(2, math.floor(size / 7))
	New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, up and size * 0.3 or size * 0.08), Size = UDim2.fromOffset(th, size * 0.52),
		BackgroundColor3 = color, Parent = arrow }, { CornerFixed(th) })
	for _, s in ipairs({ -1, 1 }) do
		New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, s * size * 0.12, 0, up and size * 0.3 or size * 0.55),
			Size = UDim2.fromOffset(size * 0.36, th), Rotation = (up and -1 or 1) * s * 45, BackgroundColor3 = color, Parent = arrow }, { CornerFixed(th) })
	end
	-- the tray it drops into (or lifts out of)
	New("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -size * 0.04), Size = UDim2.fromOffset(size * 0.8, th),
		BackgroundColor3 = color, Parent = g }, { CornerFixed(th) })
	return g
end
function NotifyKit.BubbleGlyph(parent, size, color)
	local g = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Parent = parent })
	local body = New("Frame", { Position = UDim2.fromOffset(0, size * 0.1), Size = UDim2.fromOffset(size, size * 0.66), BackgroundColor3 = color, Parent = g },
		{ CornerFixed(math.floor(size * 0.24)) })
	New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(size * 0.3, size * 0.78), Size = UDim2.fromOffset(size * 0.24, size * 0.24),
		Rotation = 45, BackgroundColor3 = color, Parent = g }, { CornerFixed(1) })
	for i = 1, 3 do
		New("Frame", { Name = "Dot" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new((i * 0.25), 0, 0.5, 0),
			Size = UDim2.fromOffset(math.max(2, size * 0.14), math.max(2, size * 0.14)), BackgroundColor3 = TingUI.Theme.Background, Parent = body }, { CornerFixed(999) })
	end
	return g
end

-- A coloured status badge: circle (success / info), diamond (warning) or rounded square (error), with a centred glyph.
-- Distinct shapes as well as colours, so the type reads at a glance.
local function StatusBadge(parent, kind, size)
	size = size or 26
	local T = TingUI.Theme
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
	local gs = math.floor(size * 0.6 + 0.5)
	if kind.Icon == "spinner" then
		glyph = Spinner(holder, color)
	elseif kind.Icon == "download" or kind.Icon == "upload" then
		glyph = NotifyKit.ArrowGlyph(holder, gs, color, kind.Icon == "upload")
	elseif kind.Icon == "message" then
		glyph = NotifyKit.BubbleGlyph(holder, gs, color)
	else
		glyph = Icon(kind.Icon, holder, gs, kind.Key)
	end
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.ZIndex = plate.ZIndex + 1
	return holder, plate, glyph, color
end
TingUI.StatusBadge = StatusBadge

function TingUI:SetNotifyPosition(pos)
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
	SyncOption("TingUI_NotifyPos", pos)
end

-- a "Clear all" pill that appears under the stack once three or more cards are showing
NotifyKit.ClearPill = New("TextButton", {
	Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Text = "Clear all", TextSize = 11, LayoutOrder = 1e9,
	BackgroundTransparency = 1, Visible = false, Parent = NotifHolder, Theme = { BackgroundColor3 = "Control", TextColor3 = "TextDim" },
}, { Corner(11), Pad(10, 0, 10, 0), Stroke("Outline") })
function NotifyKit.UpdateClearPill()
	local ClearPill = NotifyKit.ClearPill
	local n = 0
	for _, h in ipairs(LiveNotifs) do if not h.Closed then n = n + 1 end end
	local show = n >= 3
	if show and not ClearPill.Visible then
		ClearPill.Visible = true
		ClearPill.BackgroundTransparency = 1
		ClearPill.TextTransparency = 1
		Tween(ClearPill, 0.2, { BackgroundTransparency = 0.1, TextTransparency = 0 })
	elseif not show then
		ClearPill.Visible = false
	end
	ClearPill.Text = "Clear all (" .. n .. ")"
end
Connect(NotifyKit.ClearPill.MouseButton1Click, function() TingUI:ClearNotifications() end)
Connect(NotifyKit.ClearPill.MouseEnter, function() Tween(NotifyKit.ClearPill, 0.1, { TextColor3 = TingUI.Theme.Text }) end)
Connect(NotifyKit.ClearPill.MouseLeave, function() Tween(NotifyKit.ClearPill, 0.1, { TextColor3 = TingUI.Theme.TextDim }) end)

-- every notification that is still on screen (handles: :Update, :Dismiss, :SetProgress, :Pin, ...)
-- the pointer in TingUI's GUI coordinates (what AbsolutePosition uses), corrected for the top-bar inset
function TingUI:GetPointer() return Pointer.Gui() end

function TingUI:GetNotifications()
	local out = {}
	for _, h in ipairs(LiveNotifs) do if not h.Closed then table.insert(out, h) end end
	return out
end
function TingUI:ClearNotifications()
	for _, h in ipairs(self:GetNotifications()) do h:Dismiss() end
end

function NotifyKit.HistoryAdd(o)
	local hist = TingUI.NotificationHistory
	table.insert(hist, 1, { Title = o.Title, Content = o.Content and tostring(o.Content):gsub("<[^>]+>", "") or nil, Type = o.Type,
		Source = o.Source, Time = os.time(), Clock = os.clock() })
	while #hist > 60 do table.remove(hist) end
	TingUI._unread = (TingUI._unread or 0) + 1
	if TingUI._RefreshCenter then pcall(TingUI._RefreshCenter) end
end

-- o: string, or {
--   Title, Content, Type (Success | Warning | Error | Info | Loading | Download | Upload | Message | Friend |
--   Achievement | Security | Update | Heart), Duration (seconds; math.huge = stays), Progress (countdown bar, bool),
--   Actions = {{Text = "Undo", Callback = fn, Style = "Primary" | "Danger", Close = false}, ...}
--   Value = 0-1                       a progress bar with a percentage (move it with handle:SetProgress)
--   Undo = fn, OnCommit = fn          an Undo button that counts down; OnCommit runs if the card closes without Undo
--   Copy = "text" | true              a Copy button (true copies Content); it flips to "Copied" and stays open
--   Details = "long text"             a "Details" toggle that unfolds a scrollable monospace box (stack traces, logs)
--   Input = {Placeholder, Button = "Send", Callback = fn(text)}   reply right from the card
--   Image = "rbxassetid://..."        a picture instead of the badge (an avatar, an item)
--   Callback = fn(handle)             runs when the card itself is clicked (it then closes)
--   Persistent = true                 never times out (it can still be closed, swiped or cleared)
--   Group = "key" | false             cards with the same key (default: same title, text and type) merge into one
--                                     card with a x2, x3 counter instead of stacking up
--   Sound = "rbxassetid://..."        plays once when it appears
--   Source = "My Hub"                 a small tag above the title (the Shell sets it for you)
-- }
-- Returns a handle: :Update({...}) morphs it in place (Loading -> Success), :SetProgress(v, text), :SetTitle(t),
-- :SetContent(t), :Pin(bool), :Dismiss(). handle.Count is how many times it was merged.
-- Hover pauses the countdown and shows pin / close buttons; drag it sideways to fling it away; click to dismiss.
-- fromShell is internal: another TingUI script's card shown in this script's stack (see the Shell further down).
function NotifyKit.NoopHandle()
	local H = { Closed = true, Count = 1 }
	for _, m in ipairs({ "Update", "Dismiss", "SetProgress", "SetTitle", "SetContent", "Pin" }) do H[m] = function() return H end end
	return H
end
function TingUI:Notify(o, duration, fromShell)
	if type(o) == "string" then o = { Content = o, Duration = duration } end
	o = o or {}
	if self.Unloaded or (not fromShell and not self.ShowNotifications) then return NotifyKit.NoopHandle() end
	if not fromShell then
		self.Events.Notified:Fire(o)
		NotifyKit.HistoryAdd(o)
		-- in a Shell, every script's cards share the host's stack, tagged with the script that sent them
		local routed, tag
		if self._ShellNotify then routed, tag = self:_ShellNotify(o) end
		if routed then
			-- a host on an older version may not have every method
			for k, v in pairs(NotifyKit.NoopHandle()) do if routed[k] == nil and type(v) == "function" then routed[k] = v end end
			return routed
		end
		if tag and o.Source == nil then
			o = table.clone(o)
			o.Source = tag
		end
	end

	-- same notification again: bump the existing card's counter instead of stacking a copy
	local groupKey = o.Group
	if groupKey == nil and o.Type ~= "Loading" and not o.Input and not o.Undo and o.Value == nil then
		groupKey = tostring(o.Title) .. "\0" .. tostring(o.Content) .. "\0" .. tostring(o.Type) .. "\0" .. tostring(o.Source)
	end
	if groupKey then
		for _, h in ipairs(LiveNotifs) do
			if not h.Closed and h._group == groupKey then
				h:_Bump(o)
				return h
			end
		end
	end

	local H = { Closed = false, Count = 1, _group = groupKey, Options = o }
	local conns = {}
	local function Hook(signal, fn)
		local c = signal:Connect(fn)
		table.insert(conns, c)
		return c
	end

	local side = NOTIFY_POS[self.NotifyPosition] or NOTIFY_POS.TopRight
	local offX = side[1] == 1 and 320 or -320
	NotifyCount = NotifyCount + 1
	local holder = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(290, 0), LayoutOrder = NotifyCount, Parent = NotifHolder,
	})
	local card = New("Frame", {
		Size = UDim2.fromOffset(280, 34), Position = UDim2.fromOffset(offX, 0), ClipsDescendants = true,
		Parent = holder, Theme = { BackgroundColor3 = "Background" },
	}, { Corner(9) })
	H.Frame = card
	-- border drawn 1px inside so the canvas can't clip it
	local border = New("Frame", { Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), BackgroundTransparency = 1, ZIndex = 8, Parent = card },
		{ Corner(8) })
	local borderStroke = Stroke("Outline")
	borderStroke.Parent = border
	local hit = New("TextButton", { Name = "Hit", Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = card })
	local body = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 3, Parent = card,
	}, { Pad(12, 9, 12, 10), New("UISizeConstraint", { MinSize = Vector2.new(0, 34) }),
		List(11, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	local bar = New("Frame", { Size = UDim2.new(0, 3, 1, -12), Position = UDim2.fromOffset(0, 6), BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false, ZIndex = 4, Parent = card }, { CornerFixed(2) })
	local wash = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = card }, { Corner(9) })
	New("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.84), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 1) }), Parent = wash })
	-- the sheen stays clear of the rounded corners (a plain Frame clips square)
	local shine = New("Frame", {
		Size = UDim2.new(0.45, 0, 1, -18), Position = UDim2.new(-0.6, 0, 0, 9), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 6, Parent = card,
	}, { New("UIGradient", { Rotation = 18, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.88), NumberSequenceKeypoint.new(1, 1) }) }) })
	local track = New("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 9, 1, -1), Size = UDim2.new(1, -18, 0, 2), Visible = false, ZIndex = 5,
		Parent = card, Theme = { BackgroundColor3 = "Outline" },
	}, { CornerFixed(1) })
	local fill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5, Parent = track }, { CornerFixed(1) })
	-- bright head on the countdown bar
	local head = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(10, 2),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.2, ZIndex = 6, Parent = fill }, { CornerFixed(1) })

	-- hover tools: merge counter, pin and close (top right)
	local tools = New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 9, Parent = card },
		{ List(3, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
	local countPill = New("TextLabel", { Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, Text = "x2", TextSize = 10,
		Font = Enum.Font.GothamBold, Visible = false, LayoutOrder = 1, ZIndex = 9, Parent = tools,
		Theme = { BackgroundColor3 = "Control", TextColor3 = "Text" }, BackgroundTransparency = 0 }, { Corner(8), Pad(6, 0, 6, 0) })
	local countScale = New("UIScale", { Scale = 1, Parent = countPill })
	local function ToolButton(order, tip)
		local b = New("TextButton", { Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 9, Parent = tools,
			Theme = { BackgroundColor3 = "ControlHover" } }, { Corner(5) })
		b:SetAttribute("NoFade", true)
		AttachTooltip(b, tip)
		return b
	end
	local pinBtn = ToolButton(2, "Keep open")
	local pinHead = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(7, 7),
		ZIndex = 10, Parent = pinBtn, Theme = { BackgroundColor3 = "TextDim" } }, { CornerFixed(4) })
	local pinNeedle = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(2, 5), Rotation = 30,
		ZIndex = 10, Parent = pinBtn, Theme = { BackgroundColor3 = "TextDim" } }, { CornerFixed(1) })
	local closeBtn = ToolButton(3, "Dismiss")
	for _, r in ipairs({ 45, -45 }) do
		New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(9, 1.6), Rotation = r,
			ZIndex = 10, Parent = closeBtn, Theme = { BackgroundColor3 = "TextDim" } }, { CornerFixed(1) })
	end
	local fade = Fader(card)
	bar:SetAttribute("NoFade", true)

	local kind, color, dur, remaining, hovered, focused, pinned = nil, nil, 4, 4, false, false, false
	local anim = { t = 0 }
	local glyph, plate, iconFrame, spin, ring
	local valueFill, valueLabel, valueBar
	local undoBtn, undone = nil, false
	local conn

	local function Fit()
		local h = math.max(34, body.AbsoluteSize.Y)
		card.Size = UDim2.fromOffset(280, h)
		if not H.Closed then Tween(holder, 0.25, { Size = UDim2.fromOffset(290, h + 6) }) end
	end
	Hook(body:GetPropertyChangedSignal("AbsoluteSize"), Fit)

	local function ShowTools(v)
		local a = (v or pinned) and 0 or 1
		for _, b in ipairs({ pinBtn, closeBtn }) do
			for _, d in ipairs(b:GetChildren()) do
				if d:IsA("Frame") then Tween(d, 0.15, { BackgroundTransparency = (b == pinBtn and pinned and not v) and 0 or a }) end
			end
		end
	end

	local function Close(fling)
		if H.Closed then return end
		H.Closed = true
		if conn then conn:Disconnect() end
		for _, c in ipairs(conns) do c:Disconnect() end
		for i, n in ipairs(LiveNotifs) do if n == H then table.remove(LiveNotifs, i) break end end
		NotifyKit.UpdateClearPill()
		if o.Undo and not undone and o.OnCommit then SafeCall("notification '" .. tostring(o.Title) .. "' OnCommit", o.OnCommit) end
		local goalX = fling or offX
		TweenService:Create(card, TweenInfo.new(fling and 0.22 or 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
			{ Position = UDim2.fromOffset(goalX, 0) }):Play()
		fade:Tween(fling and 0.22 or 0.3, 1, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.24, function()
			if holder.Parent then Tween(holder, 0.24, { Size = UDim2.fromOffset(290, 0) }) end
		end)
		task.delay(0.55, function() holder:Destroy() end)
	end

	-- one small button in the card's action row
	local function ActionButton(row, order, text, style, onClick)
		local T = TingUI.Theme
		local base = kind and color or T.Accent
		local primary = style == "Primary"
		local danger = style == "Danger"
		local tone = danger and T.Error or base
		local b = New("TextButton", {
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), Text = tostring(text), TextSize = 11,
			BackgroundTransparency = 0, LayoutOrder = order, ZIndex = 7, TextColor3 = primary and T.Background or tone,
			BackgroundColor3 = primary and tone or tone:Lerp(T.Background, 0.82), Parent = row,
		}, { Corner(6), Pad(9, 0, 9, 0), New("UIStroke", { Color = tone:Lerp(T.Background, primary and 0.2 or 0.5), Thickness = 1 }) })
		local rest = b.BackgroundColor3
		Connect(b.MouseEnter, function() Tween(b, 0.1, { BackgroundColor3 = primary and tone:Lerp(Color3.new(1, 1, 1), 0.15) or tone:Lerp(T.Background, 0.66) }) end)
		Connect(b.MouseLeave, function() Tween(b, 0.1, { BackgroundColor3 = rest }) end)
		Connect(b.MouseButton1Down, function() Tween(b, 0.06, { Size = UDim2.fromOffset(0, 19) }) end)
		Connect(b.MouseButton1Up, function() Tween(b, 0.1, { Size = UDim2.fromOffset(0, 20) }) end)
		Connect(b.MouseButton1Click, function() onClick(b) end)
		return b
	end

	local function Build(opts)
		for _, c in ipairs(body:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
		spin, ring, glyph, plate, valueFill, valueLabel, valueBar, undoBtn = nil, nil, nil, nil, nil, nil, nil, nil
		kind = NOTIFY_KINDS[opts.Type or ""]
		local T = TingUI.Theme
		color = kind and T[kind.Key] or T.Label

		-- icon: a picture, or the type's badge
		if type(opts.Image) == "string" and opts.Image ~= "" then
			iconFrame = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(32, 32), LayoutOrder = 1, Parent = body })
			glyph = New("ImageLabel", { Size = UDim2.fromScale(1, 1), Image = opts.Image, BackgroundTransparency = 0, Parent = iconFrame,
				Theme = { BackgroundColor3 = "Control" } }, { CornerFixed(9), New("UIStroke", { Color = (kind and color or T.Outline), Thickness = 1, Transparency = 0.3 }) })
			if kind and kind.Icon ~= "spinner" then
				-- the type badge sits inside the picture's bottom-right corner, ringed in the card colour so it
				-- reads as a corner badge (it used to hang half outside the picture and look misplaced)
				local mini, miniPlate, miniGlyph = StatusBadge(iconFrame, kind, 16)
				mini.AnchorPoint = Vector2.new(0.5, 0.5)
				mini.Position = UDim2.new(1, -3, 1, -3)
				mini.ZIndex = 6
				miniPlate.ZIndex = 6
				miniGlyph.ZIndex = 7
				for _, d in ipairs(miniGlyph:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex = 7 end end
				local plateRing = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(19, 19),
					ZIndex = 5, Parent = mini, Theme = { BackgroundColor3 = "Background" } }, { CornerFixed(10) })
				plateRing.ZIndex = 5
			end
		elseif kind then
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
			ring:SetAttribute("NoFade", true)
			ring:FindFirstChildOfClass("UIStroke"):SetAttribute("NoFade", true)
			TweenService:Create(ring, TweenInfo.new(0.75, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(52, 52) }):Play()
			TweenService:Create(ring:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
		else
			iconFrame = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(16, 16), LayoutOrder = 1, Parent = body })
			glyph = Icon("bell", iconFrame, 16, "Label")
		end
		local iconW = iconFrame.Size.X.Offset

		-- text
		local text = New("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, -(iconW + 11), 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2, Parent = body,
		}, { List(2), Pad(0, 0, 34, 0) })
		if type(opts.Source) == "string" and opts.Source ~= "" then
			New("TextLabel", {
				Size = UDim2.new(1, 0, 0, 13), Text = opts.Source:upper(), TextSize = 10, Font = Enum.Font.GothamBold,
				TextColor3 = T.TextMuted, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = 0, Parent = text,
			})
		end
		if opts.Title then
			H._titleLabel = New("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Text = tostring(opts.Title),
				TextColor3 = kind and color or T.Text, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = text,
			})
		end
		if opts.Content then
			H._contentLabel = New("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(opts.Content), TextWrapped = true, RichText = true,
				TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, TextSize = 12,
				Font = opts.Title and Enum.Font.GothamMedium or Enum.Font.GothamSemibold,
				TextColor3 = T.Label, Parent = text,
			})
		end

		-- determinate progress (downloads, uploads, anything with a percentage)
		if type(opts.Value) == "number" then
			local vrow = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 3, Parent = text }, { Pad(0, 5, 0, 0) })
			valueBar = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 2), Size = UDim2.new(1, -38, 0, 4),
				Parent = vrow, Theme = { BackgroundColor3 = "Outline" } }, { CornerFixed(2) })
			valueFill = New("Frame", { Size = UDim2.fromScale(math.clamp(opts.Value, 0, 1), 1), BackgroundColor3 = kind and color or T.Accent, Parent = valueBar },
				{ CornerFixed(2) })
			-- a soft highlight that slides along the filled part
			New("Frame", { Name = "Sweep", Size = UDim2.fromScale(0.35, 1), Position = UDim2.fromScale(-0.4, 0), BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.5, Parent = valueFill }, { New("UIGradient", { Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 1) }) }) })
			valueFill.ClipsDescendants = true
			valueLabel = New("TextLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 2), Size = UDim2.fromOffset(34, 14),
				Text = math.floor(math.clamp(opts.Value, 0, 1) * 100 + 0.5) .. "%", TextSize = 11, Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.Label, Parent = vrow })
		end

		-- reply box
		if type(opts.Input) == "table" then
			local irow = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 4, Parent = text }, { Pad(0, 6, 0, 0) })
			local box = New("TextBox", { Size = UDim2.new(1, -58, 0, 24), Text = "", PlaceholderText = tostring(opts.Input.Placeholder or "Type a reply..."),
				ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, Font = Enum.Font.GothamMedium, ZIndex = 7, Parent = irow,
				Theme = { BackgroundColor3 = "Control", TextColor3 = "Text", PlaceholderColor3 = "TextMuted" } }, { Corner(6), Pad(8, 0, 8, 0), Stroke("Outline") })
			local function Send()
				local v = box.Text
				if v == "" then return end
				SafeCall("notification input", opts.Input.Callback, v, H)
				if opts.Input.Close ~= false then Close() else box.Text = "" end
			end
			local send = ActionButton(irow, 2, opts.Input.Button or "Send", "Primary", Send)
			send.AnchorPoint = Vector2.new(1, 0)
			send.Position = UDim2.new(1, 0, 0, 2)
			Connect(box.Focused, function() focused = true end)
			Connect(box.FocusLost, function(enter)
				focused = false
				if enter then Send() end
			end)
		end

		-- buttons: your actions, plus Copy / Undo / Details when asked for
		local acts = {}
		if type(opts.Undo) == "function" then table.insert(acts, { Kind = "Undo" }) end
		if opts.Copy then table.insert(acts, { Kind = "Copy" }) end
		if type(opts.Details) == "string" and opts.Details ~= "" then table.insert(acts, { Kind = "Details" }) end
		if type(opts.Actions) == "table" then for _, a in ipairs(opts.Actions) do table.insert(acts, a) end end
		local detailsBox
		if #acts > 0 then
			local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 5, Parent = text },
				{ Pad(0, 6, 0, 0), List(6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
			for i, act in ipairs(acts) do
				if act.Kind == "Undo" then
					undoBtn = ActionButton(row, i, "Undo", "Primary", function()
						undone = true
						SafeCall("notification '" .. tostring(opts.Title) .. "' Undo", opts.Undo)
						Close()
					end)
				elseif act.Kind == "Copy" then
					ActionButton(row, i, "Copy", nil, function(b)
						local what = opts.Copy == true and tostring(opts.Content or opts.Title or "") or tostring(opts.Copy)
						local ok = TingUI:Clipboard((what:gsub("<[^>]+>", "")))
						b.Text = ok and "Copied" or "Can't copy here"
						Tween(b, 0.15, { TextColor3 = ok and TingUI.Theme.Success or TingUI.Theme.Error })
						task.delay(1.4, function() if b.Parent then b.Text = "Copy" Tween(b, 0.2, { TextColor3 = kind and color or TingUI.Theme.Accent }) end end)
					end)
				elseif act.Kind == "Details" then
					ActionButton(row, i, "Details", nil, function(b)
						if detailsBox then
							local open = not detailsBox.Visible
							detailsBox.Visible = open
							b.Text = open and "Hide details" or "Details"
							-- reading the details holds the card open
							if open then pinned = true ShowTools(hovered) end
						end
					end)
				else
					ActionButton(row, i, act.Text or "OK", act.Style, function()
						SafeCall("notification action '" .. tostring(act.Text) .. "'", act.Callback, H)
						if act.Close ~= false then Close() end
					end)
				end
			end
		end
		if type(opts.Details) == "string" and opts.Details ~= "" then
			detailsBox = New("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 6, Visible = false,
				BackgroundTransparency = 0, ScrollBarThickness = 2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 7,
				Parent = text, Theme = { BackgroundColor3 = "Group", ScrollBarImageColor3 = "AccentBorder" } },
				{ Corner(6), Stroke("Outline"), New("UISizeConstraint", { MaxSize = Vector2.new(math.huge, 130) }) })
			New("TextLabel", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = opts.Details, TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Code, TextSize = 11, ZIndex = 7,
				TextColor3 = T.TextDim, Parent = detailsBox }, { Pad(7, 6, 7, 6) })
		end

		-- accent bar, colour wash and countdown only for typed notifications
		bar.Visible = kind ~= nil
		bar.BackgroundColor3 = color
		wash.BackgroundTransparency = kind and 0 or 1
		wash.BackgroundColor3 = color
		local loading = kind and kind.Icon == "spinner"
		local stays = opts.Persistent == true or opts.Sticky == true or type(opts.Input) == "table"
		dur = opts.Duration or ((loading or stays) and math.huge or (opts.Undo and 6 or (kind and 4.5 or 4)))
		if stays then dur = math.huge end
		remaining = dur
		track.Visible = (opts.Progress ~= false) and (kind ~= nil or opts.Progress == true) and dur ~= math.huge
		fill.BackgroundColor3 = color
		head.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.5)
		fill.Size = UDim2.fromScale(1, 1)
		borderStroke.Color = kind and color:Lerp(T.Background, 0.55) or T.Outline

		-- entrance: every type has its own motion
		anim.t = 0
		-- a picture keeps its place: the type motions (drop-ins, spins) move the glyph to the badge centre, which would
		-- shove a picture half out of its frame, so a picture just pops in as a whole
		local picture = type(opts.Image) == "string" and opts.Image ~= ""
		anim.kind = (picture and "image") or (kind and kind.Icon) or "bell"
		anim.rays = nil
		local sc = New("UIScale", { Scale = 0.3, Parent = picture and iconFrame or glyph })
		TweenService:Create(sc, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		local k = anim.kind
		if k == "check" then
			glyph.Rotation = -35
			TweenService:Create(glyph, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
		elseif k == "cross" then
			glyph.Rotation = 90
			TweenService:Create(glyph, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
		elseif k == "info" or k == "user" then
			glyph.Position = UDim2.new(0.5, 0, 0.5, k == "user" and 10 or -9)
			TweenService:Create(glyph, TweenInfo.new(0.6, k == "user" and Enum.EasingStyle.Back or Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
				{ Position = UDim2.fromScale(0.5, 0.5) }):Play()
		elseif k == "sparkle" then
			glyph.Rotation = -180
			TweenService:Create(glyph, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
		end
		-- success and achievements throw out a ring of sparks from the badge
		if (k == "check" or k == "sparkle") and iconFrame then
			local n = k == "sparkle" and 10 or 6
			for i = 1, n do
				local ang = (i / n) * math.pi * 2
				local spark = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(k == "sparkle" and 6 or 3, k == "sparkle" and 2 or 3), Rotation = math.deg(ang),
					BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35), ZIndex = 4, Parent = iconFrame }, { CornerFixed(2) })
				spark:SetAttribute("NoFade", true)
				local dist = k == "sparkle" and 24 or 19
				TweenService:Create(spark, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
					Position = UDim2.new(0.5, math.cos(ang) * dist, 0.5, math.sin(ang) * dist), BackgroundTransparency = 1 }):Play()
				task.delay(0.6, function() spark:Destroy() end)
			end
		end
		shine.Position = UDim2.new(-0.6, 0, 0, 9)
		TweenService:Create(shine, TweenInfo.new(k == "sparkle" and 1.3 or 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Position = UDim2.new(1.2, 0, 0, 9) }):Play()
		if k == "sparkle" then
			-- achievements get a second, slower golden sweep
			task.delay(0.9, function()
				if shine.Parent and not H.Closed then
					shine.Position = UDim2.new(-0.6, 0, 0, 9)
					TweenService:Create(shine, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Position = UDim2.new(1.2, 0, 0, 9) }):Play()
				end
			end)
		end
		Fit()
	end

	function H:Update(o2)
		if self.Closed then return self end
		for k, v in pairs(o2 or {}) do o[k] = v end
		if o2 and o2.Type == nil then o.Type = nil end
		Build(o)
		fade:Recapture()
		return self
	end
	function H:Dismiss() Close() return self end
	function H:SetTitle(t)
		o.Title = t
		if self._titleLabel and self._titleLabel.Parent then self._titleLabel.Text = tostring(t) else self:Update({ Title = t, Type = o.Type }) end
		return self
	end
	function H:SetContent(t)
		o.Content = t
		if self._contentLabel and self._contentLabel.Parent then self._contentLabel.Text = tostring(t) else self:Update({ Content = t, Type = o.Type }) end
		return self
	end
	-- v = 0-1. Passing text updates the content line too (e.g. "12.4 / 30 MB").
	function H:SetProgress(v, txt)
		if self.Closed then return self end
		v = math.clamp(tonumber(v) or 0, 0, 1)
		if not valueFill then o.Value = v self:Update({ Value = v, Type = o.Type }) end
		o.Value = v
		if valueFill then
			Tween(valueFill, 0.25, { Size = UDim2.fromScale(v, 1) })
			valueLabel.Text = math.floor(v * 100 + 0.5) .. "%"
		end
		if txt then self:SetContent(txt) end
		return self
	end
	function H:Pin(v)
		pinned = v ~= false
		ShowTools(hovered)
		return self
	end
	function H:_Bump(o2)
		self.Count = self.Count + 1
		countPill.Text = "x" .. self.Count
		countPill.Visible = true
		countScale.Scale = 1.5
		TweenService:Create(countScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		remaining = dur
		anim.t = 0
		-- a nudge so you notice it came again
		card.Position = UDim2.fromOffset(side[1] == 1 and -10 or 10, 0)
		Tween(card, 0.3, { Position = UDim2.fromOffset(0, 0) })
		if ring then
			local st = ring:FindFirstChildOfClass("UIStroke")
			ring.Size = UDim2.fromOffset(26, 26)
			st.Transparency = 0.25
			TweenService:Create(ring, TweenInfo.new(0.75, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(52, 52) }):Play()
			TweenService:Create(st, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
		end
	end

	Hook(card.MouseEnter, function()
		hovered = true
		ShowTools(true)
		if not H._dragging then Tween(card, 0.18, { Position = UDim2.fromOffset(side[1] == 1 and -5 or 5, 0) }) end
	end)
	Hook(card.MouseLeave, function()
		hovered = false
		ShowTools(false)
		if not H.Closed and not H._dragging then Tween(card, 0.18, { Position = UDim2.fromOffset(0, 0) }) end
	end)
	Hook(pinBtn.MouseButton1Click, function()
		pinned = not pinned
		ShowTools(true)
		local T = TingUI.Theme
		for _, d in ipairs({ pinHead, pinNeedle }) do Tween(d, 0.15, { BackgroundColor3 = pinned and T.Accent or T.TextDim }) end
	end)
	Hook(closeBtn.MouseButton1Click, function() Close() end)

	-- swipe: drag the card sideways and let go past the line to fling it away
	local dragStart, dragged = nil, false
	Hook(hit.InputBegan, function(i)
		if IsPress(i) then dragStart, dragged = UIS:GetMouseLocation().X, false end
	end)
	Hook(UIS.InputChanged, function(i)
		if dragStart and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local dx = UIS:GetMouseLocation().X - dragStart
			if math.abs(dx) > 6 then
				dragged = true
				H._dragging = true
				card.Position = UDim2.fromOffset(dx, 0)
				fade:Set(math.clamp((math.abs(dx) - 30) / 160, 0, 0.7))
			end
		end
	end)
	Hook(UIS.InputEnded, function(i)
		if dragStart and IsPress(i) then
			local dx = UIS:GetMouseLocation().X - dragStart
			dragStart = nil
			H._dragging = false
			if dragged then
				if math.abs(dx) > 70 then
					Close(dx > 0 and 340 or -340)
				else
					Tween(card, 0.25, { Position = UDim2.fromOffset(0, 0) })
					fade:Tween(0.2, 0)
				end
			end
		end
	end)
	Hook(hit.MouseButton1Click, function()
		if dragged then dragged = false return end
		if type(o.Callback) == "function" then SafeCall("notification '" .. tostring(o.Title) .. "' Callback", o.Callback, H) end
		Close()
	end)

	conn = RunService.RenderStepped:Connect(function(dt)
		if H.Closed then return end
		anim.t = anim.t + dt
		local t, at = os.clock(), anim.t
		if spin then spin.Rotation = (spin.Rotation + dt * 380) % 360 end
		if kind then
			-- the accent bar breathes; warnings and errors breathe harder
			local k = (kind.Key == "Caution" or kind.Key == "Error") and 0.4 or 0.2
			bar.BackgroundTransparency = 1 - (1 - k * (0.5 + 0.5 * math.sin(t * 4.5))) * (1 - fade.Alpha)
		end
		local k = anim.kind
		if k == "warn" and glyph and at < 1.1 then
			-- the exclamation mark wobbles, settling over a second
			glyph.Rotation = math.sin(at * 22) * 16 * (1 - at / 1.1)
		elseif k == "bell" and glyph and at < 1.2 then
			-- the bell rings
			glyph.Rotation = math.sin(at * 26) * 20 * (1 - at / 1.2)
		elseif k == "cross" and at < 0.5 then
			-- errors shake the whole card
			card.Position = UDim2.fromOffset(math.sin(at * 70) * 7 * (1 - at / 0.5), 0)
		elseif k == "lock" and glyph and at < 0.7 then
			glyph.Rotation = math.sin(at * 34) * 12 * (1 - at / 0.7)
		elseif k == "gear" and glyph then
			-- the gear spins up and coasts to a stop
			glyph.Rotation = 360 * (1 - (1 - math.min(at / 1.6, 1)) ^ 3)
		elseif k == "heart" and glyph and at < 1.2 then
			-- two heartbeats
			local beat = math.max(0, math.sin(at * 2 * math.pi * 1.7)) ^ 4 * (1 - at / 1.2)
			glyph.Size = UDim2.fromOffset(16 * (1 + beat * 0.35), 16 * (1 + beat * 0.35))
		elseif (k == "download" or k == "upload") and glyph then
			-- the arrow keeps dropping into the tray (or lifting out of it) while the transfer runs
			local arrow = glyph:FindFirstChild("Arrow")
			local busy = o.Value == nil or o.Value < 1
			if arrow then
				local c = busy and ((at * 1.3) % 1) or 0
				local off = (k == "download" and 1 or -1) * (c < 0.7 and (c / 0.7) * 9 or -9 + (c - 0.7) / 0.3 * 9)
				arrow.Position = UDim2.fromOffset(0, busy and off or 0)
			end
		elseif k == "message" and glyph then
			-- someone's typing: the dots bounce for a moment, then settle
			for i = 1, 3 do
				local d = glyph:FindFirstChild("Dot" .. i, true)
				if d then
					local y = at < 1.6 and math.max(0, math.sin(at * 9 - i * 0.9)) * -2.5 or 0
					d.Position = UDim2.new(i * 0.25, 0, 0.5, y)
				end
			end
		end
		if valueFill then
			local sweep = valueFill:FindFirstChild("Sweep")
			if sweep and (o.Value or 0) < 1 then sweep.Position = UDim2.fromScale(((t * 0.8) % 1.6) - 0.4, 0) end
		end
		if undoBtn and remaining ~= math.huge then undoBtn.Text = "Undo  " .. math.max(0, math.ceil(remaining)) end
		if not hovered and not focused and not pinned and not H._dragging and remaining ~= math.huge then
			remaining = remaining - dt
			fill.Size = UDim2.fromScale(math.clamp(remaining / dur, 0, 1), 1)
			if remaining <= 0 then Close() end
		end
	end)
	table.insert(Connections, conn)

	Build(o)
	ShowTools(false)
	-- slide in from the screen edge with a little overshoot
	card.Position = UDim2.fromOffset(offX, 0)
	fade:Hide()
	TweenService:Create(card, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, 0) }):Play()
	fade:Tween(0.3, 0)
	if type(o.Sound) == "string" and o.Sound ~= "" then
		pcall(function()
			local snd = Instance.new("Sound")
			snd.SoundId = o.Sound
			snd.Volume = 0.5
			snd.Parent = Gui
			snd:Play()
			task.delay(6, function() snd:Destroy() end)
		end)
	end

	table.insert(LiveNotifs, H)
	if #LiveNotifs > 6 then
		-- make room by closing the oldest card that isn't pinned or waiting on you
		for _, old in ipairs(LiveNotifs) do
			if old ~= H and not old.Closed and not old._busy then old:Dismiss() break end
		end
	end
	H._busy = o.Input ~= nil or o.Type == "Loading"
	NotifyKit.UpdateClearPill()
	return H
end

-- Notification center: the last 60 notifications this script showed, newest first, with type, source and age.
-- TingUI:OpenNotificationCenter() / :ToggleNotificationCenter(); also a dock button (Dock = {..., "notifications"}).
local function Ago(clock)
	local s = math.max(0, os.clock() - clock)
	if s < 10 then return "now" elseif s < 60 then return math.floor(s) .. "s" elseif s < 3600 then return math.floor(s / 60) .. "m" end
	return math.floor(s / 3600) .. "h"
end
function TingUI:_BuildNotificationCenter()
	local P = self:CreatePanel({ Title = "Notifications", Subtitle = "Everything this script told you", Width = 320,
		Position = UDim2.new(1, -350, 0, 64), Visible = false, HeaderIcon = { Icon = "cross", Tooltip = "Clear history", Callback = function()
			table.clear(TingUI.NotificationHistory)
			TingUI._unread = 0
			TingUI._RefreshCenter()
		end } })
	P.Name = "Notifications"
	local list = New("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1, ScrollBarThickness = 2, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = P._container, Theme = { ScrollBarImageColor3 = "AccentBorder" } }, { List(6) })
	local empty = New("TextLabel", { Size = UDim2.new(1, 0, 0, 40), Text = "Nothing yet. Notifications you get show up here.", TextWrapped = true,
		TextSize = 12, Font = Enum.Font.GothamMedium, LayoutOrder = 1, Parent = P._container, Theme = { TextColor3 = "TextMuted" } })
	local function Refresh()
		if not P.Frame.Parent then return end
		for _, c in ipairs(list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
		local hist = TingUI.NotificationHistory
		empty.Visible = #hist == 0
		list.Visible = #hist > 0
		local T = TingUI.Theme
		for i, e in ipairs(hist) do
			local row = New("Frame", { Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, Parent = list,
				Theme = { BackgroundColor3 = "Group" } }, { Corner(7), Stroke("GroupBorder"), Pad(9, 7, 9, 8),
				List(9, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
			local kind = NOTIFY_KINDS[e.Type or ""]
			if kind then
				local b = StatusBadge(row, kind, 18)
				b.LayoutOrder = 1
			else
				local f = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(18, 18), LayoutOrder = 1, Parent = row })
				Icon("bell", f, 14, "TextDim")
			end
			local col = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -27, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = row }, { List(1) })
			local top = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 15), LayoutOrder = 1, Parent = col })
			New("TextLabel", { Size = UDim2.new(1, -34, 1, 0), Text = tostring(e.Title or e.Content or "Notification"), TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, TextColor3 = kind and T[kind.Key] or T.Text, Parent = top })
			New("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(32, 15), Text = Ago(e.Clock),
				TextXAlignment = Enum.TextXAlignment.Right, TextSize = 10, Font = Enum.Font.GothamMedium, TextColor3 = T.TextMuted, Parent = top })
			if e.Title and e.Content then
				New("TextLabel", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(e.Content), TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left, TextSize = 11, Font = Enum.Font.GothamMedium, TextColor3 = T.Label, LayoutOrder = 2, Parent = col })
			end
			if e.Source then
				New("TextLabel", { Size = UDim2.new(1, 0, 0, 12), Text = tostring(e.Source):upper(), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 9,
					Font = Enum.Font.GothamBold, TextColor3 = T.TextMuted, LayoutOrder = 3, Parent = col })
			end
		end
		task.defer(function()
			if list.Parent then list.Size = UDim2.new(1, 0, 0, math.min(list.AbsoluteCanvasSize.Y / math.max(TingUI.Scale, 0.1) + 2, 340)) end
		end)
	end
	TingUI._RefreshCenter = function() if P.Frame.Visible then Refresh() end end
	Connect(P.Frame:GetPropertyChangedSignal("Visible"), function()
		if P.Frame.Visible then TingUI._unread = 0 Refresh() end
	end)
	task.spawn(function()
		while P.Frame.Parent and not TingUI.Unloaded do
			task.wait(15)
			if P.Frame.Visible then Refresh() end
		end
	end)
	self._center = P
	return P
end
function TingUI:OpenNotificationCenter(show)
	if not self._center or not self._center.Frame.Parent then self:_BuildNotificationCenter() end
	self._center:SetVisible(show ~= false)
	return self._center
end
function TingUI:ToggleNotificationCenter()
	local open = self._center and self._center.Frame.Parent and self._center.Frame.Visible
	return self:OpenNotificationCenter(not open)
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
	TextColor3 = TingUI.Theme.Text, Parent = Watermark,
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
	local T = TingUI.Theme
	local c = T.Accent:Lerp(T.Background, 0.11)
	HotkeyTitleLabel.TextColor3 = c
	HotkeyDivider.BackgroundColor3 = T.Accent:Lerp(T.Background, 0.27)
	RecolorIcon(HotkeyIcon, c)
end
StyleHotkeys()
table.insert(Refreshers, StyleHotkeys)

function TingUI:_UpdateHotkeys()
	for _, c in ipairs(HotkeyList:GetChildren()) do
		if c:IsA("TextLabel") then c:Destroy() end
	end
	local n = 0
	for i = #Keybinds, 1, -1 do
		if not Keybinds[i].Chip:IsDescendantOf(Gui) then table.remove(Keybinds, i) end
	end
	-- in a Shell, the host lists every script's hotkeys in one panel
	if self._Shell and self._Shell.Role == "member" then
		HotkeyFrame.Visible = false
		local host = self._Shell.Host
		if host and not host.Unloaded then pcall(host._UpdateHotkeys, host) end
		return
	end
	local sections = { { Entries = self:_ShellKeybinds() } }
	if self._Shell and self._Shell.Role == "host" then
		sections[1].Title = self:_ShellName()
		for _, m in ipairs(self:_ShellOthers()) do
			local ok, list = pcall(m._ShellKeybinds, m)
			if ok and type(list) == "table" and #list > 0 then
				local okName, name = pcall(m._ShellName, m)
				table.insert(sections, { Title = okName and tostring(name) or "Script", Entries = list })
			end
		end
		if #sections == 1 then sections[1].Title = nil end
	end
	local order = 0
	for _, sec in ipairs(sections) do
		if sec.Title and #sec.Entries > 0 then
			order = order + 1
			New("TextLabel", {
				Size = UDim2.fromOffset(0, 15), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order, TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left, Parent = HotkeyList, Font = Enum.Font.GothamBold,
				TextColor3 = self.Theme.TextDim, Text = tostring(sec.Title):upper(),
			})
		end
		for _, e in ipairs(sec.Entries) do
			n = n + 1
			order = order + 1
			New("TextLabel", {
				Size = UDim2.fromOffset(0, 15), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order,
				TextXAlignment = Enum.TextXAlignment.Left, Parent = HotkeyList,
				Font = Enum.Font.GothamMedium, TextColor3 = self.Theme.Label:Lerp(self.Theme.Background, e.Active and 0.08 or 0.12),
				Text = string.format("[%s] %s - %s", tostring(e.Key), tostring(e.Name), e.Active and "Active" or "Inactive"),
			})
		end
	end
	HotkeyFrame.Visible = self.ShowHotkeys and n > 0
end

-- the hotkey list's entries as plain data (the Shell host reads other scripts' lists through this)
function TingUI:_ShellKeybinds()
	local out = {}
	for _, K in ipairs(Keybinds) do
		if (K.Value or K.Mode == "Always") and K.Mode ~= "Press" and not K.Hidden and K.Chip:IsDescendantOf(Gui) then
			table.insert(out, { Key = K.Value and KeyName(K.Value):upper() or "?", Name = K.Name, Active = K:IsActive() == true })
		end
	end
	return out
end

-- every key a keybind is set to (KeyCode names), for the Shell's menu-key referee
function TingUI:_ShellBoundKeys()
	local out = {}
	for _, K in ipairs(Keybinds) do
		local v = K.Value
		if typeof(v) == "EnumItem" and v.EnumType == Enum.KeyCode and K.Flag ~= "TingUI_MenuKey" and K.Chip:IsDescendantOf(Gui) then
			out[v.Name] = K.Name or "a keybind"
		end
	end
	return out
end

function TingUI:SetHotkeysVisible(v)
	self.ShowHotkeys = v
	SyncOption("TingUI_Hotkeys", v)
	self:_UpdateHotkeys()
	self:_UpdateDock()
end

function TingUI:SetWatermarkVisible(v)
	self.ShowWatermark = v
	Watermark.Visible = v and not (self._Shell and self._Shell.Role == "member")
	SyncOption("TingUI_Watermark", v)
	self:_UpdateDock()
end

function TingUI:SetWatermark(text)
	WatermarkOverride = text
end

function TingUI:SetWatermarkTitle(text)
	WatermarkTitle = text
end

-- custom logo for the watermark, e.g. "rbxassetid://123"; pass nil for the default logo
function TingUI:SetIcon(id)
	local has = id ~= nil and id ~= ""
	self._iconId = has and id or nil
	WatermarkImage.Image = has and id or ""
	WatermarkImage.Visible = has
	WatermarkLogo.Visible = not has
end

task.spawn(function()
	while not TingUI.Unloaded do
		local T = TingUI.Theme
		local ping = 0
		pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
		local function col(c, s) return string.format('<font color="#%s">%s</font>', c:ToHex(), s) end
		if WatermarkOverride then
			WatermarkLabel.Text = Esc(WatermarkOverride)
		else
			local title = WatermarkTitle or (TingUI.Windows[1] and TingUI.Windows[1].Title) or "TingUI"
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
	-- the popup lives on the overlay, so it goes when the swatch does
	pcall(function() Connect(swatch.Destroying, function() pop:Destroy() end) end)
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
	C._swatch = swatch
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
		TextSize = 11, TextColor3 = TingUI.Theme.ChipText, Text = KeyName(key), Parent = holder, LayoutOrder = 10,
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
		if self.Flag then TingUI.Flags[self.Flag] = k end
		self:_Render()
		if not silent then
			for _, fn in ipairs(self.KeyListeners) do task.spawn(fn, k) end
		end
		TingUI:_UpdateHotkeys()
	end
	K.Set = K.SetKey

	function K:SetMode(m)
		if m == "Toggle" or m == "Hold" or m == "Press" then self.Mode = m end
		TingUI:_UpdateHotkeys()
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
		TingUI:_UpdateHotkeys()
	end

	Connect(chip.MouseButton1Click, function()
		TingUI._binding = K
		chip.Text = "..."
	end)
	Connect(chip.MouseButton2Click, function()
		if K.Mode == "Press" or K.Mode == "Always" then return end
		K.Mode = (K.Mode == "Toggle") and "Hold" or "Toggle"
		TingUI:Notify({ Content = (K.Name or "Keybind") .. ": " .. K.Mode .. " mode", Duration = 2 })
		TingUI:_UpdateHotkeys()
	end)

	table.insert(Keybinds, K)
	Register(K, o.Flag)
	if o.ChangedCallback then K:OnKeyChanged(o.ChangedCallback) end
	if K.Owner then owner._kb = K end
	TingUI:_UpdateHotkeys()
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
	local T = TingUI.Theme
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
		TextColor3 = o.Dim and TingUI.Theme.TextDim or TingUI.Theme.Label, Parent = holder,
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
		local TH = TingUI.Theme
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
		if self._kb then TingUI:_UpdateHotkeys() end
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
		Tween(valueLabel, 0.12, { TextColor3 = TingUI.Theme.AccentText })
	end)
	Connect(valueLabel.FocusLost, function()
		local n = tonumber((valueLabel.Text:gsub("[^%d%.%-]", "")))
		Tween(valueLabel, 0.12, { TextColor3 = TingUI.Theme.Label })
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

-- WCAG contrast ratio between two colours (1 = identical, 21 = black on white)
local function Contrast(a, b)
	local function ch(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
	local function Luma(c) return 0.2126 * ch(c.R) + 0.7152 * ch(c.G) + 0.0722 * ch(c.B) end
	local la, lb = Luma(a), Luma(b)
	if la < lb then la, lb = lb, la end
	return (la + 0.05) / (lb + 0.05)
end
TingUI.Contrast = Contrast

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
	Connect(box.MouseEnter, function() if not isOpen then Tween(stroke, 0.1, { Color = TingUI.Theme.Border }) end end)
	Connect(box.MouseLeave, function() if not isOpen then Tween(stroke, 0.1, { Color = TingUI.Theme.Outline }) end end)
	local function SetOpen(v)
		isOpen = v
		TweenService:Create(chevron, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = v and 180 or 0 }):Play()
		Tween(stroke, 0.15, { Color = v and TingUI.Theme.AccentBorder or TingUI.Theme.Outline })
	end

	local pop = New("Frame", {
		Visible = false, Size = UDim2.fromOffset(200, 100), Parent = Overlay, Theme = { BackgroundColor3 = "Background" },
	}, { Corner(7), Stroke("Border") })
	pcall(function() Connect(row.Destroying, function() pop:Destroy() end) end)
	local scroll = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 2, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = pop, Theme = { ScrollBarImageColor3 = "Accent" },
	}, { Pad(4), List(2) })
	-- long lists get a search box at the top (or force it with Search = true)
	local search
	local function WantsSearch() return o.Search == true or (o.Search ~= false and #D.Values > 8) end
	search = New("TextBox", {
		Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 26), BackgroundTransparency = 1, Text = "",
		PlaceholderText = "Search...", PlaceholderColor3 = TingUI.Theme.TextMuted, Theme = { PlaceholderColor3 = "TextMuted" }, ClearTextOnFocus = false, Visible = false,
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
		local T = TingUI.Theme
		local on = IsSelected(it.Value)
		-- picked rows: whichever of the accent text or plain text reads better on the selected fill
		local onText = Contrast(T.AccentText, T.TabActive) >= 4.5 and T.AccentText
			or (Contrast(T.Text, T.TabActive) >= Contrast(T.AccentText, T.TabActive) and T.Text or T.AccentText)
		local goals = {
			{ it.Sel, { BackgroundTransparency = on and 0 or 1 } },
			{ it.Hover, { BackgroundTransparency = (it.Hovered and not on) and 0 or 1 } },
			{ it.Bar, { Size = UDim2.fromOffset(2, on and 14 or (it.Hovered and 7 or 0)), BackgroundTransparency = on and 0 or (it.Hovered and 0.35 or 1) } },
			{ it.Label, { Position = UDim2.fromOffset(it.Hovered and 15 or 11, 0),
				TextColor3 = on and onText or (it.Hovered and T.Text or T.Label) } },
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
		valueText.TextColor3 = (txt == "--") and TingUI.Theme.TextDim or TingUI.Theme.Label
		for _, it in pairs(items) do PaintItem(it, instant) end
	end
	table.insert(Refreshers, function() Render(true) end)
	local function PopupSize()
		local s2 = WantsSearch()
		search.Visible = s2
		scroll.Position = UDim2.fromOffset(0, s2 and 32 or 0)
		scroll.Size = UDim2.new(1, 0, 1, s2 and -32 or 0)
		pop.Size = UDim2.fromOffset(math.max(box.AbsoluteSize.X / TingUI.Scale, 120), math.min(#D.Values * 26 + 8, 184) + (s2 and 32 or 0))
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
				it.Sel.BackgroundColor3 = TingUI.Theme.Accent:Lerp(TingUI.Theme.Background, 0.55)
				it.Sel.BackgroundTransparency = 0
				TweenService:Create(it.Sel, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = TingUI.Theme.TabActive }):Play()
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
		PlaceholderText = o.Placeholder or "", PlaceholderColor3 = TingUI.Theme.TextDim, Theme = { PlaceholderColor3 = "TextDim" }, ClearTextOnFocus = false,
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
	Connect(box.Focused, function() Tween(stroke, 0.1, { Color = TingUI.Theme.AccentBorder }) end)
	Connect(box.FocusLost, function()
		Tween(stroke, 0.1, { Color = TingUI.Theme.Outline })
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
		Connect(b.MouseEnter, function() Tween(b, 0.1, { BackgroundColor3 = TingUI.Theme.ControlHover }) end)
		Connect(b.MouseLeave, function() Tween(b, 0.1, { BackgroundColor3 = TingUI.Theme.Control }) end)
		local function Press()
			if opts.Confirm then
				local c = {}
				for k, v in pairs(opts.Confirm) do c[k] = v end
				c.Callback = function(ok) if ok and opts.Callback then SafeCall("Button '" .. tostring(opts.Text or "Button") .. "'", opts.Callback) end end
				TingUI:Confirm(c)
				return
			end
			if opts.DoubleClick and not confirming then
				confirming = true
				b.Text = "Click again to confirm"
				b.TextColor3 = TingUI.Theme.Warning
				task.delay(2.5, function()
					if confirming then
						confirming = false
						b.Text = original
						b.TextColor3 = TingUI.Theme.Label
					end
				end)
				return
			end
			if confirming then
				confirming = false
				b.Text = original
				b.TextColor3 = TingUI.Theme.Label
			end
			b.BackgroundColor3 = TingUI.Theme.TabActive
			Tween(b, 0.25, { BackgroundColor3 = TingUI.Theme.ControlHover })
			-- press ripple
			local rip = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6),
				BackgroundColor3 = TingUI.Theme.Accent, BackgroundTransparency = 0.7, ZIndex = b.ZIndex, Parent = b,
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
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = TingUI.Theme.Text, LayoutOrder = 1, Parent = card,
	})
	local body = New("TextLabel", {
		Text = o.Content or "", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, RichText = true,
		TextSize = 11, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = TingUI.Theme.TextDim,
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
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = TingUI.Theme.TextDim, Font = Enum.Font.GothamMedium, Parent = row,
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
		local sz = row.AbsoluteSize / TingUI.Scale
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
			c.Stroke.Color = on and TingUI.Theme.AccentBorder or TingUI.Theme.Outline
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
					Text = item.Name, TextSize = 10, TextColor3 = TingUI.Theme.TextDim, Parent = b,
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
		Text = text, TextColor3 = TingUI.Theme.Label, LayoutOrder = order, Parent = parent,
		Theme = { BackgroundColor3 = "TabActive" },
	}, { Corner(6), Pad(9, 0, 9, 0) })
end

-- Measured from the reference: fill = colour 80% toward the background, border = 50%, text = the colour.
local function Pill(parent, text, color, order, height, textSize, bg)
	bg = bg or TingUI.Theme.Background
	return New("TextLabel", {
		Text = text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, height or 21), TextSize = textSize or 12,
		TextColor3 = color, BackgroundTransparency = 0, BackgroundColor3 = color:Lerp(bg, 0.78),
		LayoutOrder = order or 0, Parent = parent,
	}, { Corner(11), Pad(11, 0, 11, 0), New("UIStroke", { Color = color:Lerp(bg, 0.45), Thickness = 1 }) })
end

-- Free-floating draggable panel. Options: Title, Subtitle, Width, Height (0 = grows with content), Position,
-- HeaderIcon = {Icon, Tooltip, Callback}, Dock = {Icon, Tooltip, Order} (adds a dock button that shows/hides it)
function TingUI:CreatePanel(o)
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
		Text = o.Title or "Panel", Size = UDim2.new(1, -30, 1, 0), TextSize = 13, TextColor3 = TingUI.Theme.Text,
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
		Connect(hb.MouseEnter, function() RecolorIcon(ic, TingUI.Theme.Label) end)
		Connect(hb.MouseLeave, function() RecolorIcon(ic, TingUI.Theme.TextDim) end)
		Connect(hb.MouseButton1Click, function()
			if o.HeaderIcon.Callback then task.spawn(o.HeaderIcon.Callback) end
		end)
	end
	if o.Subtitle then
		New("TextLabel", {
			Text = o.Subtitle, Size = UDim2.new(1, 0, 0, 15), TextSize = 11, TextColor3 = TingUI.Theme.TextDim,
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
				pscale.Scale = TingUI.Scale * 0.94
				TweenService:Create(pscale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = TingUI.Scale }):Play()
			end
			frame.Visible = true
			Front()
		elseif frame.Visible then
			if pscale then
				TweenService:Create(pscale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = TingUI.Scale * 0.94 }):Play()
				task.delay(0.16, function()
					if mine == PToken then frame.Visible = false pscale.Scale = TingUI.Scale TingUI:_UpdateDock() end
				end)
			else
				frame.Visible = false
			end
		end
		TingUI:_UpdateDock()
	end
	function P:Toggle() self:SetVisible(not frame.Visible) end
	function P:Destroy()
		ClosePopup()
		frame:Destroy()
		for i, q in ipairs(TingUI._Panels) do if q == P then table.remove(TingUI._Panels, i) break end end
		TingUI:_UpdateDock()
	end
	P.Name = o.Title or "Panel"
	table.insert(TingUI._Panels, P)
	if o.Visible == false then frame.Visible = false end
	if o.Dock then
		TingUI:AddDockButton({
			Icon = o.Dock.Icon or "window", Tooltip = o.Dock.Tooltip or o.Title, Order = o.Dock.Order or 20,
			Callback = function() P:Toggle() end, Active = function() return frame.Visible end,
		})
	end
	return P
end

local function BuildCreditCard(container, e)
	local color = e.RoleColor or TingUI.Theme.Accent
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
		TextSize = 13, TextColor3 = TingUI.Theme.Text, LayoutOrder = 1, Parent = line,
	})
	if e.Role then Pill(line, e.Role:upper(), color, 2, 20, 10, TingUI.Theme.Group) end
	if e.Description then
		New("TextLabel", {
			Text = e.Description, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 11,
			TextColor3 = TingUI.Theme.TextMuted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
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

function TingUI:CreateCredits(o)
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
function TingUI:Confirm(o)
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
	local card = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 14), Size = UDim2.fromOffset(410, 0),
		AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 71, Parent = Gui,
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
			TextColor3 = T.Label, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
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
	local fade = Fader(card)
	fade:Hide()
	Tween(dim, 0.18, { BackgroundTransparency = 0.45 })
	Tween(card, 0.2, { Position = UDim2.new(0.5, 0, 0.5, 0) })
	fade:Tween(0.2, 0)
	Tween(scale, 0.2, { Scale = 1 })

	local function Close(accepted)
		if done then return end
		done = true
		if keyConn then keyConn:Disconnect() end
		Tween(dim, 0.15, { BackgroundTransparency = 1 })
		fade:Tween(0.15, 1)
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
	Connect(cancelBtn.MouseEnter, function() Tween(cancelBtn, 0.1, { BackgroundColor3 = TingUI.Theme.ControlHover }) end)
	Connect(cancelBtn.MouseLeave, function() Tween(cancelBtn, 0.1, { BackgroundColor3 = TingUI.Theme.Control }) end)
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
function TingUI:CreateKeySystem(o)
	o = o or {}
	local header
	if o.DiscordLink or o.HeaderIcon then
		header = o.HeaderIcon or {
			Icon = "discord", Tooltip = "Copy Discord invite",
			Callback = function()
				if setclipboard then setclipboard(o.DiscordLink) end
				TingUI:Notify({ Content = "Discord invite copied.", Type = "Info" })
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
			TingUI:Notify({ Title = "Key System", Content = "Key accepted.", Type = "Success" })
			P:Destroy()
			if o.OnSuccess then task.spawn(o.OnSuccess, input.Value) end
		else
			TingUI:Notify({ Title = "Key System", Content = (ok and msg) or "Invalid key.", Type = "Danger" })
		end
	end
	P:AddButton({
		Text = "Get Key",
		Callback = function()
			if o.GetKey then
				task.spawn(o.GetKey)
			elseif o.GetKeyLink and setclipboard then
				setclipboard(o.GetKeyLink)
				TingUI:Notify({ Content = "Link copied to clipboard.", Type = "Info" })
			end
		end,
	}):AddSubButton({ Text = "Submit", Callback = Submit })
	return P
end

------------------------------------------------------------------------------
-- Config system
------------------------------------------------------------------------------

-- Configs go through a storage adapter: { Read(key) -> string?, Write(key, string), Delete(key), List(folder) -> {keys} }.
-- Keys look like "<Folder>/<name>.json". Executor file functions are used when they exist; anywhere else (Studio, a
-- published game) configs live in memory for the session. Plug in your own (DataStore through a RemoteFunction, ...)
-- with the Storage load option or TingUI:SetStorage(adapter). Adapter functions may yield and may error.
do
	local function HasFiles()
		return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
			and type(isfolder) == "function" and type(makefolder) == "function" and type(listfiles) == "function"
	end
	local function EnsureFolders(key)
		local path = ""
		for part in key:gmatch("([^/]+)/") do
			path = path == "" and part or (path .. "/" .. part)
			if not isfolder(path) then makefolder(path) end
		end
	end
	TingUI.FileStorage = {
		Name = "Files", Persistent = true,
		Read = function(key) if isfile(key) then return readfile(key) end end,
		Write = function(key, data) EnsureFolders(key) writefile(key, data) end,
		Delete = function(key)
			if type(delfile) ~= "function" then error("delfile is not supported", 0) end
			delfile(key)
		end,
		List = function(folder)
			if not isfolder(folder) then return {} end
			return listfiles(folder)
		end,
	}
	local mem = {}
	TingUI.MemoryStorage = {
		Name = "Memory", Persistent = false,
		Read = function(key) return mem[key] end,
		Write = function(key, data) mem[key] = data end,
		Delete = function(key) mem[key] = nil end,
		List = function(folder)
			local out = {}
			for k in pairs(mem) do
				if k:sub(1, #folder + 1) == folder .. "/" and not k:find("/", #folder + 2, true) then table.insert(out, k) end
			end
			return out
		end,
	}
	TingUI.Storage = HasFiles() and TingUI.FileStorage or TingUI.MemoryStorage
end

function TingUI:SetStorage(adapter)
	assert(type(adapter) == "table" and type(adapter.Read) == "function" and type(adapter.Write) == "function"
		and type(adapter.List) == "function", "SetStorage({ Read = fn, Write = fn, List = fn, Delete = fn })")
	self.Storage = adapter
end

-- true when configs survive leaving the game (files or your own adapter), false for the in-memory fallback
local function CanFile() return TingUI.Storage.Persistent ~= false end

local function StorageCall(method, ...)
	local fn = TingUI.Storage[method]
	if type(fn) ~= "function" then return false, "this storage has no " .. method end
	local ok, res = pcall(fn, ...)
	if not ok then return false, FirstLine(res) end
	return true, res
end

function TingUI:_Serialize()
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

function TingUI:_Apply(data)
	if type(data) ~= "table" then return end
	-- configs saved before the rename used Lumen_ for the built-in settings
	for k, v in pairs(table.clone(data)) do
		if type(k) == "string" and k:sub(1, 6) == "Lumen_" and data["TingUI_" .. k:sub(7)] == nil then data["TingUI_" .. k:sub(7)] = v end
	end
	if type(data.TingUI_Preset) == "table" then
		-- a config can name one of your saved themes; a theme that no longer exists (removed in an update) leaves
		-- the current one in place
		if not self.Presets[PresetName(data.TingUI_Preset.v)] and self._LoadSavedThemes then pcall(self._LoadSavedThemes, self, true) end
		if self.Options.TingUI_Preset and self.Presets[PresetName(data.TingUI_Preset.v)] then
			local fade = self.ThemeTransition
			self.ThemeTransition = 0
			pcall(function() self.Options.TingUI_Preset:Set(PresetLabel(PresetName(data.TingUI_Preset.v))) end)
			self.ThemeTransition = fade
		end
		local rest = {}
		for k, v in pairs(data) do if k ~= "TingUI_Preset" then rest[k] = v end end
		data = rest
	end
	for flag, d in pairs(data) do
		local o = self.Options[flag]
		if o and type(d) == "table" and o.Type == d.t then
			pcall(function()
				if d.t == "Keybind" then
					if d.mode then o:SetMode(d.mode) end
					if d.k and d.e then o:SetKey(Enum[d.e][d.k]) else o:SetKey(nil) end
				else
					o:Set(d.v)
				end
			end)
		end
	end
end

local function CfgPath(name) return TingUI.Folder .. "/" .. name .. ".json" end

-- the whole config as a JSON string, and back: handy for share codes or your own saving
function TingUI:ExportConfig() return HttpService:JSONEncode(self:_Serialize()) end
function TingUI:ImportConfig(json)
	local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
	if not ok or type(data) ~= "table" then return false, "That isn't a TingUI config" end
	self:_Apply(data)
	return true
end

-- Before v0.0.6 every script kept its configs in "Lumen/". The first time a script that uses the default folder looks
-- for configs, copy them into its own folder so nothing goes missing. The old files are left where they are.
do
	local DefaultFolder = TingUI.Folder
	function TingUI:_MigrateConfigs()
		if self._migrated then return end
		self._migrated = true
		if LoadOptions.Folder ~= nil or self.Folder ~= DefaultFolder or self.Storage ~= self.FileStorage then return end
		pcall(function()
			if not isfolder("Lumen") then return end
			for _, p in ipairs(self.Storage.List(self.Folder)) do
				if tostring(p):match("%.json$") then return end
			end
			for _, p in ipairs(listfiles("Lumen")) do
				local n = tostring(p):match("([^/\\]+)$")
				if n and (n:match("%.json$") or n == "autoload.txt") then self.Storage.Write(self.Folder .. "/" .. n, readfile(p)) end
			end
		end)
	end
end

function TingUI:ListConfigs()
	local out = {}
	self:_MigrateConfigs()
	local ok, list = StorageCall("List", self.Folder)
	if not ok or type(list) ~= "table" then return out end
	for _, p in ipairs(list) do
		local n = tostring(p):match("([^/\\]+)%.json$")
		if n then table.insert(out, n) end
	end
	table.sort(out)
	return out
end

function TingUI:SaveConfig(name)
	if not name or name:gsub("%s", "") == "" then return false, "Enter a config name first" end
	if name:find("[/\\]") then return false, "Config names can't contain / or \\" end
	return StorageCall("Write", CfgPath(name), self:ExportConfig())
end

function TingUI:LoadConfig(name)
	self:_MigrateConfigs()
	local ok, json = StorageCall("Read", CfgPath(name))
	if not ok or type(json) ~= "string" then return false, "Could not read config" end
	return self:ImportConfig(json)
end

function TingUI:DeleteConfig(name)
	return StorageCall("Delete", CfgPath(name))
end

function TingUI:SetAutoload(name)
	return (StorageCall("Write", self.Folder .. "/autoload.txt", name or ""))
end

function TingUI:GetAutoload()
	self:_MigrateConfigs()
	local ok, v = StorageCall("Read", self.Folder .. "/autoload.txt")
	if ok and type(v) == "string" and v ~= "" then return v end
end

function TingUI:LoadAutoload()
	local n = self:GetAutoload()
	if n then
		local card = self:Notify({ Title = "Config", Content = "Autoloading '" .. n .. "'...", Type = "Loading" })
		local ok, err = self:LoadConfig(n)
		task.delay(0.35, function()
			card:Update({ Title = "Config", Content = ok and ("Autoloaded '" .. n .. "'.") or tostring(err or "Could not read config"), Type = ok and "Success" or "Danger", Duration = 4 })
		end)
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
-- Style.BackdropTexture = {Image, Transparency, Drift, Zoom}: art across the whole screen behind the windows
local BackdropArt = New("ImageLabel", {
	Name = "BackdropArt", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ImageTransparency = 1, Visible = false,
	ScaleType = Enum.ScaleType.Stretch, ZIndex = 0, Parent = BackdropFrame,
})
local ArtState = { P = 0, Cfg = nil }
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
	local to = TingUI.Style
	local from = StyleBlend and StyleBlend.From or to
	local a = StyleBlend and StyleBlend.A or 1
	local p = (from.Vignette and 1 or 0) * (1 - a) + (to.Vignette and 1 or 0) * a
	for _, fr in ipairs(Vignette) do fr.BackgroundTransparency = 1 - p end
	-- backdrop art: fades in/out with the theme (a different image swaps at the midpoint of the blend)
	local ft, tt = from.BackdropTexture, to.BackdropTexture
	if ft and tt and ft.Image ~= tt.Image then
		ArtState.Cfg, ArtState.P = (a < 0.5) and ft or tt, math.abs(a * 2 - 1)
	else
		ArtState.Cfg = tt or ft
		ArtState.P = (ft and 1 or 0) * (1 - a) + (tt and 1 or 0) * a
	end
	local img = ArtState.Cfg and TextureImage(ArtState.Cfg.Image) or ""
	if BackdropArt.Image ~= img then BackdropArt.Image = img end
	BackdropArt.Visible = ArtState.P > 0.01 and img ~= ""
end

local function AnyWindowVisible()
	for _, w in ipairs(TingUI.Windows) do
		if w.Visible then return true end
	end
	return false
end

-- the backdrop (dim, blur, particles) fades in when a window opens and out when the last one closes
function TingUI:_UpdateSnow()
	-- in a Shell only one script draws the dim, blur and particles: the first one (in load order) with a window open
	local any = AnyWindowVisible() and not (self._ShellBackdropBlocked and self:_ShellBackdropBlocked())
	Snow.ShowTarget = any and 1 or 0
	if any and (Snow.Enabled or Backdrop.Dim > 0 or TingUI.Style.BackdropTexture) then BackdropFrame.Visible = true end
	TweenService:Create(DimFrame, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ BackgroundTransparency = any and (1 - math.clamp(Backdrop.Dim, 0, 1)) or 1 }):Play()
	local target = any and math.max(Backdrop.Blur, TingUI.Style.Blur or 0) or 0
	if target > 0 and not BlurEffect then
		pcall(function()
			BlurEffect = Instance.new("BlurEffect")
			BlurEffect.Size = 0
			BlurEffect.Parent = Lighting
		end)
	end
	if BlurEffect then Tween(BlurEffect, 0.35, { Size = target }) end
	self:_UpdateDock()
	if self._ShellCascade then self:_ShellCascade() end
end

------------------------------------------------------------------------------
-- Particle kinds. Each has Build(f, color) (create f.Frame, set f.Base = resting transparency)
-- and Update(f, dt, t, speed) (move it; may return a transparency). Register your own with TingUI:RegisterParticles.
------------------------------------------------------------------------------

local KINDS = {}
do -- particle kinds (helpers stay local to this block)
local GLYPH_CHARS = { "0", "1", "0", "1", "A", "F", "7", "3", "#", "*" }
local CONFETTI = { Color3.fromRGB(255, 128, 190), Color3.fromRGB(130, 255, 210), Color3.fromRGB(255, 220, 120), Color3.fromRGB(150, 170, 255), Color3.fromRGB(255, 160, 110) }
local function Dot(parent, size, color, tr)
	return New("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = color, BackgroundTransparency = tr, Parent = parent }, { CornerFixed(size) })
end
local function Fall(f, dt, sp, dir)
	f.Y = f.Y + f.Speed * sp * dt * (dir or 1)
	if f.Y > 1.05 then f.Y = -0.05 f.X = math.random() elseif f.Y < -0.05 then f.Y = 1.05 f.X = math.random() end
end

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
-- ocean: no two bubbles alike. Fizzing strings of tiny beads, glassy bubbles with a coloured rim and a highlight that
-- wobble as they rise, big lazy ones that squash and stretch, and little clusters drifting together. They pop at a
-- random depth, at the surface, or when the pointer touches them: a ring snaps outward and droplets spray off.
local BUBBLE_TYPES = { "Fizz", "Fizz", "Glass", "Glass", "Glass", "Glass", "Big", "Cluster" }
local function BubbleBody(f, parent, c, pos, size, scaled)
	local white = Color3.new(1, 1, 1)
	local b = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos or UDim2.fromScale(0.5, 0.5),
		Size = scaled and UDim2.fromScale(1, 1) or UDim2.fromOffset(size, size), BackgroundColor3 = white, Parent = parent }, { CornerFixed(999) })
	-- glassy body: light at the top, the water's colour underneath
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(c:Lerp(white, 0.55), c:Lerp(Color3.new(0, 0, 0), 0.15)), Parent = b })
	local rim = New("UIStroke", { Color = c:Lerp(white, 0.3), Thickness = size >= 20 and 1.5 or 1, Parent = b })
	local hi = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.32, 0.28), Rotation = -35,
		Size = UDim2.fromScale(0.36, 0.2), BackgroundColor3 = white, Parent = b }, { CornerFixed(999) })
	table.insert(f.Extra, { b, "BackgroundTransparency", size >= 20 and 0.88 or 0.84 })
	table.insert(f.Extra, { rim, "Transparency", 0.25 + math.random() * 0.25 })
	table.insert(f.Extra, { hi, "BackgroundTransparency", 0.2 })
	if size >= 11 then
		local hi2 = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.7, 0.74), Size = UDim2.fromScale(0.12, 0.12),
			BackgroundColor3 = white, Parent = b }, { CornerFixed(999) })
		table.insert(f.Extra, { hi2, "BackgroundTransparency", 0.5 })
	end
	return b
end
local function BubbleRespawn(f, first)
	f.X = math.random()
	f.Y = first and math.random() or (1.04 + math.random() * 0.12)
	-- most rise all the way and burst at the surface; some burst on the way up
	if f.Type == "Fizz" then f.PopAt = 0.25 + math.random() * 0.6
	else f.PopAt = (math.random() < 0.55) and (0.08 + math.random() * 0.55) or -0.04 end
	if first and f.PopAt > f.Y then f.PopAt = -0.04 end
	f.Speed = f.BaseSpeed * (0.8 + math.random() * 0.45)
	f.Pop, f.Vis = nil, first and 1 or 0
end
local function BubblePop(f)
	f.Pop = 0
	if f.Type == "Fizz" or not f.Frame.Parent then return end
	local a = f.LastAlpha or 1
	local pos = f.Frame.Position
	local c = f.Color:Lerp(Color3.new(1, 1, 1), 0.45)
	local size = f.Size
	local ring = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(size * 0.8, size * 0.8),
		BackgroundTransparency = 1, Parent = f.Frame.Parent }, { CornerFixed(999) })
	local rs = New("UIStroke", { Color = c, Thickness = size >= 20 and 2 or 1.5, Transparency = 1 - 0.75 * a, Parent = ring })
	TweenService:Create(ring, TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(size * 2.3, size * 2.3) }):Play()
	TweenService:Create(rs, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	local n = size >= 20 and 8 or (f.Type == "Cluster" and 5 or 6)
	for i = 1, n do
		local ang = (i / n) * math.pi * 2 + math.random() * 0.5
		local dist = size * (0.8 + math.random() * 0.9)
		local d = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(2, 2), BackgroundColor3 = c,
			BackgroundTransparency = 1 - 0.7 * a, Parent = f.Frame.Parent }, { CornerFixed(999) })
		TweenService:Create(d, TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = pos + UDim2.fromOffset(math.cos(ang) * dist, math.sin(ang) * dist + 4), BackgroundTransparency = 1 }):Play()
		task.delay(0.36, function() d:Destroy() end)
	end
	task.delay(0.3, function() ring:Destroy() end)
end
KINDS.Bubbles = {
	Build = function(f, c, p)
		f.Type = BUBBLE_TYPES[math.random(#BUBBLE_TYPES)]
		f.Color = c
		f.Container = true
		f.Base = 0
		f.Extra = {}
		local size = (f.Type == "Fizz" and math.random(2, 4)) or (f.Type == "Glass" and math.random(8, 17)) or (f.Type == "Big" and math.random(20, 34)) or 18
		f.Size = size
		f.BaseSpeed = (f.Type == "Fizz" and 0.11) or (f.Type == "Big" and 0.03) or 0.05
		f.Frame = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Parent = p })
		f.Scale = New("UIScale", { Scale = 1, Parent = f.Frame })
		if f.Type == "Fizz" then
			-- a string of beads, smallest at the bottom
			for i = 0, 2 do
				local s2 = math.max(1, size - i)
				local bead = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, i * (size + 3)),
					Size = UDim2.fromOffset(s2, s2), BackgroundColor3 = c:Lerp(Color3.new(1, 1, 1), 0.5), Parent = f.Frame }, { CornerFixed(999) })
				table.insert(f.Extra, { bead, "BackgroundTransparency", 0.3 + i * 0.2 })
			end
		elseif f.Type == "Cluster" then
			BubbleBody(f, f.Frame, c, UDim2.fromOffset(6, 7), 10)
			BubbleBody(f, f.Frame, c, UDim2.fromOffset(15, 4), 6)
			BubbleBody(f, f.Frame, c, UDim2.fromOffset(13, 14), 7)
		else
			BubbleBody(f, f.Frame, c, nil, size, true)
		end
		BubbleRespawn(f, true)
	end,
	Update = function(f, dt, t, sp)
		if f.Pop then
			f.Pop = f.Pop + dt
			f.Vis = math.max(0, 1 - f.Pop / 0.08)
			f.Scale.Scale = 1 + f.Pop * 4
			if f.Pop > 0.12 then
				f.Scale.Scale = 1
				BubbleRespawn(f, false)
			end
			return 0
		end
		f.Vis = math.min(1, (f.Vis or 1) + dt * 2)
		f.Y = f.Y - f.Speed * sp * dt
		local sway
		if f.Type == "Fizz" then sway = math.sin(t * 7 + f.Phase) * 0.002
		elseif f.Type == "Big" then sway = math.sin(t * 0.8 + f.Phase) * 0.022
		else sway = math.sin(t * f.Sway * 1.6 + f.Phase) * 0.012 end
		f.Frame.Position = UDim2.fromScale(f.X + sway, f.Y)
		-- big and glassy bubbles squash and stretch as they rise
		if f.Type == "Big" or f.Type == "Glass" then
			local w = math.sin(t * (f.Type == "Big" and 3.1 or 4.6) + f.Phase) * (f.Type == "Big" and 0.09 or 0.05)
			f.Frame.Size = UDim2.fromOffset(f.Size * (1 + w), f.Size * (1 - w))
		end
		local pop = f.Y <= f.PopAt
		if not pop and f.Type ~= "Fizz" and f.Vis > 0.6 then
			local m = Pointer.Gui()
			local ap, as = f.Frame.AbsolutePosition, f.Frame.AbsoluteSize
			local cx, cy = ap.X + as.X / 2, ap.Y + as.Y / 2
			local r = as.X / 2 + 6
			if (m.X - cx) ^ 2 + (m.Y - cy) ^ 2 < r * r then pop = true end
		end
		if pop then BubblePop(f) end
		return 0
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
-- hologram: data motes drifting up through the projection, flickering like a weak signal
KINDS.Holo = {
	Build = function(f, c, p)
		f.Speed = 0.012 + math.random() * 0.025
		f.Base = 0.35 + math.random() * 0.4
		if math.random() < 0.3 then
			f.Frame = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7), BackgroundTransparency = 1, Parent = p })
			local a = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = c, Parent = f.Frame })
			local b = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = c, Parent = f.Frame })
			f.NoSelf = true
			f.Extra = { { a, "BackgroundTransparency" }, { b, "BackgroundTransparency" } }
		else
			local size = math.random(1, 3)
			f.Frame = New("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = c, BackgroundTransparency = f.Base, Parent = p })
		end
	end,
	Update = function(f, dt, t, sp)
		Fall(f, dt, sp, -1)
		f.Frame.Position = UDim2.fromScale(f.X, f.Y)
		if math.sin(t * 1.3 + f.Phase * 7) > 0.985 then return 1 end
		return f.Base + 0.2 * math.sin(t * 8 + f.Phase)
	end,
}
-- circuit: tiny electric arcs that crackle for an instant somewhere on screen, then jump elsewhere
local ARC_ATAN = math.atan2 or function(y, x) return math.atan(y, x) end
KINDS.Static = {
	Build = function(f, c, p)
		f.Base = 1
		f.Next = math.random() * 5
		f.On = -1
		f.Frame = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1,
			Rotation = math.random(0, 359), Position = UDim2.fromScale(f.X, f.Y), Parent = p })
		f.NoSelf = true
		f.Extra = {}
		local x, y = 1, 13
		for i = 1, 3 do
			local nx, ny = x + 8, 13 + (i % 2 == 1 and -1 or 1) * math.random(3, 8)
			local dx, dy = nx - x, ny - y
			local seg = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((x + nx) / 2, (y + ny) / 2),
				Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + 1, 1), Rotation = math.deg(ARC_ATAN(dy, dx)),
				BackgroundColor3 = c:Lerp(Color3.new(1, 1, 1), 0.4), Parent = f.Frame })
			table.insert(f.Extra, { seg, "BackgroundTransparency" })
			x, y = nx, ny
		end
	end,
	Update = function(f, dt, t)
		if dt > 0 and t >= f.Next then
			f.Next = t + 1.5 + math.random() * 5
			f.On = t
			f.X, f.Y = math.random(), math.random()
			f.Frame.Position = UDim2.fromScale(f.X, f.Y)
			f.Frame.Rotation = math.random(0, 359)
		end
		local k = t - f.On
		if k >= 0 and k < 0.07 then return 0.05 end
		if k >= 0.11 and k < 0.16 then return 0.35 end
		return 1
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
		local col = (math.random() < 0.5) and c or ((TingUI.Style.Aura and TingUI.Style.Aura[1]) or c)
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
-- glass: real lens bokeh. Discs sit at different focus depths: near ones are big, soft and nearly all glow; far ones
-- are small and crisp with a bright rim and a faint chromatic fringe; some take the hexagon of a camera aperture.
-- Each drifts at its own depth, breathes slowly in and out of focus, and now and then a glint streaks across the glass.
local BOKEH_LIGHTS = { Color3.fromRGB(255, 244, 228), Color3.fromRGB(255, 210, 180), Color3.fromRGB(180, 230, 255),
	Color3.fromRGB(214, 196, 255), Color3.fromRGB(190, 255, 226), Color3.fromRGB(255, 226, 240) }
KINDS.Bokeh = {
	Build = function(f, c, p)
		local depth = math.random()                         -- 0 far / crisp ... 1 near / soft
		local size = math.floor(16 + depth ^ 1.4 * 92)
		f.Depth, f.Size = depth, size
		f.Speed = 0.003 + (1 - depth) * 0.004 + depth * 0.006
		f.Pulse = 0.15 + math.random() * 0.35
		f.Container = true
		f.Base = 0.3
		f.Extra = {}
		local col = c:Lerp(BOKEH_LIGHTS[math.random(#BOKEH_LIGHTS)], 0.55)
		f.Frame = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Parent = p })
		f.Scale = New("UIScale", { Scale = 1, Parent = f.Frame })
		local soft = depth
		local hex = math.random() < 0.22 and depth < 0.75
		local function Shape(parent, scale, color, base, stroke)
			local shape
			if hex then
				-- a hexagon from three rounded bars at 60 degrees
				shape = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(scale, scale),
					BackgroundTransparency = 1, Parent = parent })
				for _, r in ipairs({ 0, 60, 120 }) do
					local bar = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 0.577),
						Rotation = r, BackgroundColor3 = color, Parent = shape }, { CornerFixed(2) })
					table.insert(f.Extra, { bar, "BackgroundTransparency", 1 - (1 - base) / 2.2 })
				end
			else
				shape = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(scale, scale),
					BackgroundColor3 = color, Parent = parent }, { CornerFixed(999) })
				table.insert(f.Extra, { shape, "BackgroundTransparency", base })
				if stroke then
					local st = New("UIStroke", { Color = stroke, Thickness = 1, Parent = shape })
					table.insert(f.Extra, { st, "Transparency", 0.35 + soft * 0.5 })
				end
			end
			return shape
		end
		-- halo, body, then the bright onion-ring edge that makes it read as a lens highlight
		Shape(f.Frame, 1.32, col, 0.965)
		local fringeColor = Color3.fromHSV((select(1, col:ToHSV()) + 0.5) % 1, 0.45, 1)
		if not hex and depth < 0.6 then Shape(f.Frame, 1.06, fringeColor, 1, fringeColor) end
		Shape(f.Frame, 1, col, 0.86 + soft * 0.06, not hex and col:Lerp(Color3.new(1, 1, 1), 0.4) or nil)
		Shape(f.Frame, 0.55, col:Lerp(Color3.new(1, 1, 1), 0.3), 0.93)
		f.Frame.Position = UDim2.fromScale(f.X, f.Y)
	end,
	Update = function(f, dt, t, sp)
		f.X = (f.X + math.sin(t * 0.18 + f.Phase) * f.Speed * 0.6 * sp * dt + 0.0015 * (f.Depth - 0.5) * sp * dt) % 1
		f.Y = f.Y - f.Speed * sp * dt
		if f.Y < -0.12 then f.Y = 1.12 f.X = math.random() end
		f.Frame.Position = UDim2.fromScale(f.X, f.Y)
		-- breathing focus: grows softer and dimmer, then sharpens again
		local focus = 0.5 + 0.5 * math.sin(t * f.Pulse + f.Phase)
		f.Scale.Scale = 0.92 + focus * 0.16
		return 0.15 + focus * 0.35
	end,
	Layer = function(layer, dt, t, sp, color)
		layer.NextGlint = layer.NextGlint or (t + 3)
		if t >= layer.NextGlint then
			layer.NextGlint = t + 6 + math.random() * 7
			local vis = layer.Alpha * Snow.Show
			local streak = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.2, 0.2 + math.random() * 0.5),
				Size = UDim2.new(0.5, 0, 0, math.random(40, 90)), Rotation = -24, BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1 - vis * 0.9, Parent = layer.Folder }, {
				New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.86), NumberSequenceKeypoint.new(1, 1) }) }) })
			TweenService:Create(streak, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Position = UDim2.fromScale(1.25, streak.Position.Y.Scale - 0.2) }):Play()
			task.delay(1.65, function() streak:Destroy() end)
		end
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

-- cosmos: a deep star field in parallax (near stars drift faster), colour temperatures from blue-white to amber,
-- bright stars with diffraction spikes, shooting stars with glowing heads and the occasional slow comet
do
local STAR_TEMPS = { Color3.fromRGB(170, 195, 255), Color3.fromRGB(215, 225, 255), Color3.new(1, 1, 1), Color3.fromRGB(255, 240, 210), Color3.fromRGB(255, 214, 170) }
local function Fade(inst, time, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function Streak(layer, color, o)
	-- a glowing head with a tapered tail, flying along `ang` degrees
	local vis = layer.Alpha * Snow.Show
	local holder = New("Frame", { AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1, Size = UDim2.fromOffset(o.Len, o.Width + 4),
		Rotation = o.Ang, Position = UDim2.fromScale(o.X, o.Y), Parent = layer.Folder })
	local tail = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, o.Width),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1 - vis, Parent = holder }, {
		CornerFixed(o.Width), New("UIGradient", { Color = ColorSequence.new(o.TailColor or color, Color3.new(1, 1, 1)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.7, 0.55), NumberSequenceKeypoint.new(1, 0) }) }) })
	local head = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(o.Head, o.Head),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1 - vis, Parent = holder }, { CornerFixed(o.Head) })
	local glow = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(o.Head * 3, o.Head * 3),
		BackgroundColor3 = o.TailColor or color, BackgroundTransparency = 1 - vis * 0.25, Parent = holder }, { CornerFixed(o.Head * 3) })
	local r = math.rad(o.Ang)
	Fade(holder, o.Time, { Position = UDim2.fromScale(o.X + math.cos(r) * o.Dist * 0.56, o.Y + math.sin(r) * o.Dist) }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	for _, part in ipairs({ tail, head, glow }) do Fade(part, o.Time, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
	task.delay(o.Time + 0.05, function() holder:Destroy() end)
end
KINDS.Galaxy = {
	Build = function(f, c, p)
		f.Depth = math.random() ^ 2
		f.Pulse = 0.5 + math.random() * 2.2
		f.VX = -(0.002 + f.Depth * 0.011)
		local col = STAR_TEMPS[math.random(#STAR_TEMPS)]:Lerp(c, 0.2)
		if math.random() < 0.09 then
			local len = math.random(9, 17)
			f.Bright = true
			f.NoSelf = true
			f.Base = 0.1
			f.Frame = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Size = UDim2.fromOffset(len, len), Parent = p })
			local core = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(3, 3),
				BackgroundColor3 = Color3.new(1, 1, 1), Parent = f.Frame }, { CornerFixed(2) })
			local spikes = {}
			for i, rot in ipairs({ 0, 90 }) do
				spikes[i] = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 1),
					Rotation = rot, BackgroundColor3 = col, Parent = f.Frame }, { New("UIGradient", { Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }) })
			end
			local halo = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(7, 7),
				BackgroundColor3 = col, Parent = f.Frame }, { CornerFixed(4) })
			f.Extra = { { core, "BackgroundTransparency" }, { spikes[1], "BackgroundTransparency" }, { spikes[2], "BackgroundTransparency" }, { halo, "BackgroundTransparency", 0.7 } }
		else
			local size = 1 + math.floor(f.Depth * 2.2 + math.random() * 0.7)
			f.Base = 0.3
			f.Frame = Dot(p, size, col, 0.3)
		end
		f.Frame.Position = UDim2.fromScale(f.X, f.Y)
	end,
	Update = function(f, dt, t, sp)
		f.X = f.X + f.VX * sp * dt
		if f.X < -0.02 then f.X, f.Y = 1.02, math.random() end
		f.Frame.Position = UDim2.fromScale(f.X, f.Y)
		local tw = 0.5 + 0.5 * math.sin(t * f.Pulse * sp + f.Phase)
		if f.Bright then
			f.Frame.Rotation = math.sin(t * 0.35 + f.Phase) * 8
			return 0.05 + 0.45 * tw
		end
		return 0.12 + (0.75 - f.Depth * 0.35) * tw
	end,
	Layer = function(layer, dt, t, sp, color)
		layer.NextShot = layer.NextShot or (t + 1.2)
		layer.NextComet = layer.NextComet or (t + 7 + math.random() * 6)
		if t >= layer.NextShot then
			layer.NextShot = t + 1.8 + math.random() * 4.2
			Streak(layer, color, { X = math.random() * 0.75, Y = math.random() * 0.45, Ang = 18 + math.random() * 30, Len = math.random(110, 190),
				Width = 2, Head = 3, Dist = 0.32 + math.random() * 0.15, Time = 0.75 + math.random() * 0.35, TailColor = Color3.fromRGB(150, 180, 255) })
		end
		if t >= layer.NextComet then
			layer.NextComet = t + 16 + math.random() * 12
			Streak(layer, color, { X = math.random() * 0.3, Y = 0.1 + math.random() * 0.3, Ang = 6 + math.random() * 12, Len = math.random(220, 320),
				Width = 4, Head = 5, Dist = 0.8, Time = 4.5 + math.random() * 1.5, TailColor = Color3.fromRGB(120, 230, 255) })
		end
	end,
}


end

end

local BUILTIN_KINDS = { "Snow", "Bubbles", "Petals", "Embers", "Fireflies", "Stars", "Glyphs", "Rain", "Confetti", "Sparkles", "Starfield", "Crystals", "Neon",
	"Drafting", "FilmGrain", "Sparks", "Bokeh", "Bats", "Leaves", "Galaxy", "Holo", "Static" }
TingUI.ParticleKinds = { "Theme" }
for _, k in ipairs(BUILTIN_KINDS) do table.insert(TingUI.ParticleKinds, k) end
TingUI._particleDropdowns = {}

local function CurrentKind()
	if Snow.Kind == "Theme" then
		if TingUI.Style.Particles == false then return "None" end
		return TingUI.Style.Particles or "Snow"
	end
	return Snow.Kind
end

local function ApplyFlake(f, tr, alpha)
	-- f.Vis (0-1) lets a kind fade one particle on its own (a bubble popping); f.LastAlpha is the layer's fade
	f.LastAlpha = alpha
	if f.Vis then alpha = alpha * f.Vis end
	local final = 1 - (1 - math.clamp(tr, 0, 1)) * alpha
	if f.Container then
		-- a see-through holder: each part keeps its own resting transparency, dimmed further by the returned value
		for _, x in ipairs(f.Extra) do
			x[1][x[2]] = 1 - (1 - (x[3] or 0)) * (1 - math.clamp(tr, 0, 1)) * alpha
		end
		return
	end
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
	-- a theme with Particles = "None" (or false) shows none; the old ones fade out
	if kind == "None" or kind == false then return end
	local def = KINDS[kind]
	if not def then kind, def = "Snow", KINDS.Snow end
	local color = (Snow.Kind == "Theme" and TingUI.Style.ParticleColor) or Color3.new(1, 1, 1)
	if Snow.Kind ~= "Theme" then
		color = ({ Bubbles = Color3.fromRGB(140, 205, 255), Petals = Color3.fromRGB(242, 150, 186), Embers = Color3.fromRGB(255, 150, 70),
			Fireflies = Color3.fromRGB(180, 255, 150), Glyphs = Color3.fromRGB(205, 205, 205), Rain = Color3.fromRGB(170, 200, 240),
			Sparkles = Color3.fromRGB(255, 214, 120), Crystals = Color3.fromRGB(215, 240, 255),
			Neon = Color3.fromRGB(0, 229, 255), Drafting = Color3.fromRGB(210, 230, 255), FilmGrain = Color3.fromRGB(230, 230, 230),
			Sparks = Color3.fromRGB(255, 210, 90), Bokeh = Color3.fromRGB(180, 210, 255), Bats = Color3.fromRGB(130, 90, 170),
			Leaves = Color3.fromRGB(200, 110, 50), Galaxy = Color3.fromRGB(225, 228, 255),
			Holo = Color3.fromRGB(120, 230, 255), Static = Color3.fromRGB(255, 200, 120) })[kind] or color
	end
	local L = { Kind = kind, Def = def, Color = color, Flakes = {}, Alpha = 0, Target = 1,
		Folder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = BackdropFrame }) }
	for i = 1, Snow.Count do
		local f = { X = math.random(), Y = math.random(), Phase = math.random() * 6.28, Sway = 0.4 + math.random() * 0.8, Speed = 0.05, Base = 0.3 }
		local ok, err = pcall(def.Build, f, color, L.Folder)
		if not ok then
			warn("[TingUI] particle '" .. kind .. "' failed to build: " .. tostring(err))
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

function TingUI:_RefreshParticles()
	if Snow.Enabled then BuildFlakes() end
end

-- opts (all optional): Count, Speed, Dim, Kind
function TingUI:SetSnow(enabled, opts)
	if opts then
		if opts.Count then Snow.Count = math.floor(opts.Count) end
		if opts.Speed then Snow.Speed = opts.Speed end
		if opts.Dim then Backdrop.Dim = opts.Dim end
		if opts.Kind then Snow.Kind = opts.Kind end
	end
	Snow.Enabled = enabled and true or false
	BuildFlakes()
	SyncOption("TingUI_Snow", Snow.Enabled)
	self:_UpdateSnow()
end
TingUI.SetParticlesEnabled = TingUI.SetSnow

function TingUI:SetSnowOptions(opts)
	if opts.Kind then Snow.Kind = opts.Kind end
	if opts.Count then Snow.Count = math.floor(opts.Count) end
	if opts.Speed then Snow.Speed = opts.Speed end
	if (opts.Kind or opts.Count) and Snow.Enabled then BuildFlakes() end
end

-- "Theme" follows the active theme; or any name in TingUI.ParticleKinds
function TingUI:SetParticles(kind)
	self:SetSnowOptions({ Kind = kind })
	SyncOption("TingUI_Particles", kind)
end

-- Add your own particle style. def = { Build = function(f, color, parent) ... end, Update = function(f, dt, t, speed) ... end }
-- Build must set f.Frame (a GuiObject) and may set f.Base (resting transparency). f.X / f.Y (0-1), f.Phase, f.Sway are pre-filled.
-- Update moves it and may return a transparency (0-1). Fading in/out and the theme crossfade are handled for you.
function TingUI:RegisterParticles(name, def)
	assert(type(name) == "string" and type(def) == "table" and type(def.Build) == "function", "RegisterParticles(name, {Build = fn, Update = fn})")
	KINDS[name] = def
	if not table.find(self.ParticleKinds, name) then table.insert(self.ParticleKinds, name) end
	for _, d in ipairs(self._particleDropdowns) do pcall(function() d:SetValues(self.ParticleKinds, true) end) end
end

-- opts: Dim (0-1 darkness of the backdrop), Blur (0-40 world blur)
function TingUI:SetBackdrop(opts)
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
	local still = TingUI.ReducedMotion
	Snow.Time = Snow.Time + (still and 0 or dt)
	local t, sp = Snow.Time, Snow.Speed
	-- whole-backdrop fade with the windows
	local rate = dt / 0.35
	if Snow.Show < Snow.ShowTarget then Snow.Show = math.min(Snow.ShowTarget, Snow.Show + rate)
	elseif Snow.Show > Snow.ShowTarget then Snow.Show = math.max(Snow.ShowTarget, Snow.Show - rate) end
	if Snow.Show <= 0 and Snow.ShowTarget == 0 then
		BackdropFrame.Visible = false
		return
	end
	if BackdropArt.Visible and ArtState.Cfg then
		TexFX.Drift(BackdropArt, ArtState.Cfg, t, 0.7)
		BackdropArt.ImageTransparency = 1 - (1 - (ArtState.Cfg.Transparency or 0.85)) * ArtState.P * Snow.Show
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
				local ok, tr = pcall(L.Def.Update, f, still and 0 or dt, t, sp)
				ApplyFlake(f, (ok and tr) or f.Base, alpha)
			end
			if L.Def.Layer and not still then pcall(L.Def.Layer, L, dt, t, sp, L.Color) end
			if not still and L.Kind == "Rain" and L.Target == 1 and TingUI.Style.Lightning and t >= Snow.NextBolt then
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
--   InnerLine = Color3 (thin second border), AccentGradient = {c1, c2} (toggles, sliders, progress bars), Lightning (bool),
--   Grid + GridColor, Vignette, SurfaceTransparency, Blur, AccentCycle + CycleSpeed, AuraHard, AuraRotation,
--   Texture = { {Image, Transparency, Drift, Zoom, Pulse, Color, Mode = "Fill" | "Lamp", Flicker}, ... } (art inside windows),
--   BackdropTexture = {Image, Transparency, Drift, Zoom} (art across the screen), Glitch (bool: title + screen glitches),
--   Scene = "Hologram" | "Circuit" | "Ocean" | your own (animated artwork around windows that reacts to clicks; see Scenes),
--   scene colours: TraceColor + EnergyColor (Circuit), WaterColor + FoamColor (Ocean)
-- fade (seconds): corners, glow, fonts, surfaces and particles all blend instead of switching.
------------------------------------------------------------------------------

local StyleToken = 0
function TingUI:SetStyle(st, fade)
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
				if mine ~= StyleToken or TingUI.Unloaded then return end
				local a = i / steps
				StyleBlend.A = a * a * (3 - 2 * a)
				if i == steps then StyleBlend = nil end
				Paint()
				if i < steps then task.wait(fade / steps) end
			end
			task.delay(0.35, function() if mine == StyleToken and not TingUI.Unloaded then Paint() end end)
		end)
	else
		StyleBlend = nil
		Paint()
	end
	-- particles only rebuild (with a crossfade) when the style changes what they look like, so editing other keys
	-- live (the Theme Studio's sliders) never restarts them
	local oldAura, newAura = type(old.Aura) == "table" and old.Aura[1] or nil, type(new.Aura) == "table" and new.Aura[1] or nil
	if old.Particles ~= new.Particles or old.ParticleColor ~= new.ParticleColor or oldAura ~= newAura then self:_RefreshParticles() end
	if (new.Blur or 0) ~= (old.Blur or 0) then self:_UpdateSnow() end
	self.Events.StyleChanged:Fire(new)
end

-- faint diagonal text tiled over the whole screen (anti-leak watermark). Pass nil to remove.
local ScreenWM
function TingUI:SetScreenWatermark(text)
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
			ScreenWM:GetChildren()[#ScreenWM:GetChildren()]:SetAttribute("TTRest", 0.94)
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
		AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 6, Parent = Gui,
		Visible = TingUI.ShowDock and not (TingUI._Shell and TingUI._Shell.Role == "member"),
		Theme = { BackgroundColor3 = "Background" },
	}, { Corner(11), Stroke(nil, true), Pad(7, 7, 7, 7),
		List(6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	RegisterSurface(Dock, "Dock", 11)
	MakeDraggable(Dock, Dock, nil, "Dock")
	SnapHomes[Dock] = Dock.Position
	return Dock
end

-- active buttons get the lighter plate and an accent icon; inactive ones are a plain light-grey icon (as in the reference)
function TingUI:_UpdateDock()
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
			if e.Letter then e.Letter.TextColor3 = c end
			if e.Dot then
				e.Dot.BackgroundColor3 = on and T.Success or T.TextMuted
				e.Dot.BackgroundTransparency = on and 0 or 0.35
			end
		end
	end
end
table.insert(Refreshers, function() TingUI:_UpdateDock() end)

-- o: Icon ("window","scan","keyboard","command","user" are the traced reference icons; also "bell","gear","snow","list","discord"
-- or an rbxassetid), Tooltip, Name, Callback, Active (function -> bool), Order, Visible
function TingUI:AddDockButton(o)
	o = o or {}
	local dock = EnsureDock()
	local ic = o.Icon or "window"
	local b = New("TextButton", {
		Size = UDim2.fromOffset(31, 30), BackgroundTransparency = 1, LayoutOrder = o.Order or 50, Visible = o.Visible ~= false,
		Parent = dock, Theme = { BackgroundColor3 = "TabActive" },
	}, { Corner(8) })
	local entry = { Button = b, Active = o.Active, Name = o.Name or o.Tooltip or ic, Callback = o.Callback, BuiltIn = o._builtIn == true }
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
			b.BackgroundColor3 = TingUI.Theme.ControlHover
			Tween(b, 0.1, { BackgroundTransparency = 0.35 })
		end
	end)
	Connect(b.MouseLeave, function() TingUI:_UpdateDock() end)
	Connect(b.MouseButton1Click, function()
		if o.Callback then task.spawn(o.Callback) end
		TingUI:_UpdateDock()
	end)
	TingUI:_UpdateDock()
	return b
end

function TingUI:SetDockVisible(v)
	self.ShowDock = v
	if Dock then Dock.Visible = v and not (self._Shell and self._Shell.Role == "member") end
	SyncOption("TingUI_Dock", v)
end

-- show / hide a single dock button by its name (tooltip text)
function TingUI:SetDockButtonVisible(name, v)
	for _, e in ipairs(DockButtons) do
		if e.Name == name then e.Button.Visible = v end
	end
end

function TingUI:GetDockButtons()
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
	local cat = TingUI._Catalog
	for i = #cat, 1, -1 do
		local e = cat[i]
		if not (e.Opt.Row and e.Opt.Row.Parent) then
			table.remove(cat, i)
		end
	end
	-- a Shell host searches every script: its own settings are tagged with its name, the others come from _ShellCatalog
	local hosting = TingUI._Shell and TingUI._Shell.Role == "host"
	local own = hosting and TingUI:_ShellName() or nil
	for _, e in ipairs(cat) do
		local sc = PaletteScore(q, e.Name .. " " .. e.Path .. (own and (" " .. own) or ""))
		if sc then table.insert(out, { Entry = e, Score = sc }) end
	end
	if hosting then
		for _, m in ipairs(TingUI:_ShellOthers()) do
			local ok, list = pcall(m._ShellCatalog, m, q)
			if ok and type(list) == "table" then
				for _, e in ipairs(list) do
					if type(e) == "table" and type(e.Name) == "string" then
						e.Foreign = true
						table.insert(out, { Entry = e, Score = tonumber(e.Score) or 1 })
					end
				end
			end
		end
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

-- what picking a search result does: toggles flip, buttons press, anything else is shown and highlighted in its window
local function PaletteJump(e)
	local opt = e.Opt
	if opt.Disabled then return end
	if opt.Type == "Toggle" then
		opt:Set(not opt.Value)
	elseif opt.Type == "Button" then
		if opt.Press then opt.Press() end
	else
		local tab = e.Tab
		if tab and tab.Window then
			tab.Window:SetVisible(true)
			tab.Window:SelectTab(tab)
			task.delay(0.15, function()
				if e.Group and e.Group._activate then e.Group._activate() end
				task.delay(0.12, function() TingUI:_Spotlight(opt.Row, tab.Page) end)
			end)
		end
	end
end

local function PaletteActivate(e)
	if e.Foreign then
		-- another script's setting: it runs in that script
		if e.IsToggle then
			pcall(e.Activate)
			PaletteRefresh()
		else
			TingUI:ClosePalette()
			pcall(e.Activate)
		end
		return
	end
	if e.Opt.Disabled then return end
	if e.Opt.Type == "Toggle" then
		PaletteJump(e)
		PaletteRefresh()
	else
		TingUI:ClosePalette()
		PaletteJump(e)
	end
end

-- this script's settings as plain data for the Shell host's palette. Activate runs here, in this script.
function TingUI:_ShellCatalog(q)
	local out = {}
	local src = self:_ShellName()
	local cat = self._Catalog
	for i = #cat, 1, -1 do
		if not (cat[i].Opt.Row and cat[i].Opt.Row.Parent) then table.remove(cat, i) end
	end
	for _, e in ipairs(cat) do
		local sc = PaletteScore(tostring(q or ""), e.Name .. " " .. e.Path .. " " .. src)
		if sc then
			table.insert(out, { Name = e.Name, Path = e.Path, Source = src, Score = sc, ValueText = FormatValue(e.Opt),
				IsToggle = e.Opt.Type == "Toggle", Activate = function() PaletteJump(e) end })
		end
	end
	return out
end

-- scroll an element into view and pulse a highlight around it
function TingUI:_Spotlight(row, page)
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
		local src = e.Foreign and e.Source or (TingUI._Shell and TingUI._Shell.Role == "host" and TingUI:_ShellName()) or nil
		if src then
			New("TextLabel", {
				Text = tostring(src), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), TextSize = 10,
				Font = Enum.Font.GothamBold, TextColor3 = TingUI.Theme.AccentText, LayoutOrder = 0, Parent = left,
				BackgroundTransparency = 0, BackgroundColor3 = TingUI.Theme.TabActive,
			}, { Corner(5), Pad(6, 0, 6, 0) })
		end
		New("TextLabel", {
			Text = e.Name, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30),
			TextColor3 = TingUI.Theme.Text, LayoutOrder = 1, Parent = left,
		})
		New("TextLabel", {
			Text = e.Path, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), TextSize = 11,
			TextColor3 = TingUI.Theme.TextDim, Font = Enum.Font.GothamMedium, LayoutOrder = 2, Parent = left,
		})
		New("TextLabel", {
			Text = e.Foreign and tostring(e.ValueText or "...") or FormatValue(e.Opt), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(110, 30), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamMedium,
			TextColor3 = TingUI.Theme.Label, Parent = row,
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
		TextColor3 = TingUI.Theme.TextDim, Parent = head,
	})
	PaletteInput = New("TextBox", {
		Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -46, 1, 0), BackgroundTransparency = 1, Text = "",
		PlaceholderText = "Search options...", PlaceholderColor3 = TingUI.Theme.TextMuted, Theme = { PlaceholderColor3 = "TextMuted" }, ClearTextOnFocus = false,
		TextSize = 13, TextColor3 = TingUI.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = head,
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
	Connect(PaletteDim.MouseButton1Click, function() TingUI:ClosePalette() end)
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

function TingUI:OpenPalette()
	-- in a Shell the host's palette searches every script, so members open that one
	local host = self._ShellHostFor and self:_ShellHostFor()
	if host then return host:OpenPalette() end
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

function TingUI:ClosePalette()
	local host = self._ShellHostFor and self:_ShellHostFor()
	if host and not Palette.Open then return host:ClosePalette() end
	if not Palette.Open then return end
	Palette.Open = false
	PaletteDim.Visible = false
	PaletteFrame.Visible = false
	pcall(function() PaletteInput:ReleaseFocus() end)
	self:_UpdateDock()
end

function TingUI:TogglePalette()
	local host = self._ShellHostFor and self:_ShellHostFor()
	if host then return host:TogglePalette() end
	if Palette.Open then self:ClosePalette() else self:OpenPalette() end
end

-- called from the global input handler while the palette is open; returns true when the key was used
function TingUI:_PaletteKey(kc)
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
function TingUI:_InitDock(W, which)
	if self._dockInit then return end
	self._dockInit = true
	local want = {}
	for _, k in ipairs(which or { "menu", "hotkeys", "palette" }) do want[k] = true end
	if want.snow then want.particles = true end
	local function Live()
		if W.Destroyed then return TingUI.Windows[1] end
		return W
	end
	self:AddDockButton({ Icon = "window", Tooltip = "Toggle menu", Order = 1, Visible = want.menu ~= nil, _builtIn = true,
		Callback = function() local w = Live() if w then w:Toggle() end end,
		Active = function() local w = Live() return w ~= nil and w.Visible end })
	self:AddDockButton({ Icon = "keyboard", Tooltip = "Hotkey list", Order = 30, Visible = want.hotkeys ~= nil, _builtIn = true,
		Callback = function() TingUI:SetHotkeysVisible(not TingUI.ShowHotkeys) end, Active = function() return TingUI.ShowHotkeys end })
	self:AddDockButton({ Icon = "snow", Tooltip = "Particles", Order = 34, Visible = want.particles ~= nil, _builtIn = true,
		Callback = function() TingUI:SetSnow(not Snow.Enabled) end, Active = function() return Snow.Enabled end })
	self:AddDockButton({ Icon = "bell", Tooltip = "Notifications", Order = 36, Visible = (want.notifications or want.inbox) ~= nil, _builtIn = true,
		Callback = function() TingUI:ToggleNotificationCenter() end,
		Active = function() return TingUI._center ~= nil and TingUI._center.Frame.Parent ~= nil and TingUI._center.Frame.Visible end })
	self:AddDockButton({ Icon = "command", Tooltip = "Command palette (Ctrl+K)", Order = 40, Visible = want.palette ~= nil, _builtIn = true,
		Callback = function() TingUI:TogglePalette() end, Active = function() return Palette.Open end })
end

------------------------------------------------------------------------------
-- TingUI Shell: every TingUI script in the game shares one desktop
------------------------------------------------------------------------------
-- Scripts find each other through getgenv().TingUIInstances, the registry every TingUI joins. The first script that
-- has a dock (in load order) hosts: its dock grows a taskbar button for every other script, and its notification
-- stack, command palette and hotkey list carry every script's. It also notices two scripts fighting over a key.
-- The other scripts hide their own dock, watermark and hotkey list, and only one script dims and blurs the screen at
-- a time. Everything that crosses between scripts is plain data behind pcall, so an older TingUI or a broken script
-- is simply left out. Load with Shell = false to stay out of it, or Shell = {Name = "My Hub", Icon = "rbxassetid://..."}.
-- (Built inside a function: Build's register budget is nearly spent, and a function gets a fresh one.)
do local function Setup()
	local opt = LoadOptions.Shell
	-- load order survives re-running a script, so the same script keeps hosting while you iterate on it
	env.TingUIShellOrder = type(env.TingUIShellOrder) == "table" and env.TingUIShellOrder or {}
	local order = env.TingUIShellOrder
	if type(order[InstanceId]) ~= "number" then
		env.TingUIShellSeq = (tonumber(env.TingUIShellSeq) or 0) + 1
		order[InstanceId] = env.TingUIShellSeq
	end
	local S = {
		Protocol = 1, Seq = order[InstanceId], Role = "solo", Host = nil, Enabled = opt ~= false,
		Name = type(opt) == "table" and type(opt.Name) == "string" and opt.Name or nil,
		Icon = type(opt) == "table" and type(opt.Icon) == "string" and opt.Icon or nil,
		Warned = {},
	}
	TingUI._Shell = S

	-- every live TingUI that speaks this protocol, in load order
	local function Members()
		local list = {}
		local reg = env.TingUIInstances
		if type(reg) ~= "table" then return list end
		for _, inst in pairs(reg) do
			local s = type(inst) == "table" and rawget(inst, "_Shell")
			if type(s) == "table" and s.Protocol == 1 and s.Enabled and not rawget(inst, "Unloaded") then table.insert(list, inst) end
		end
		table.sort(list, function(a, b)
			local sa, sb = tonumber(a._Shell.Seq) or 0, tonumber(b._Shell.Seq) or 0
			if sa ~= sb then return sa < sb end
			return tostring(a.Id) < tostring(b.Id)
		end)
		return list
	end

	local function Info(m)
		local okN, name = pcall(m._ShellName, m)
		local okI, icon = pcall(m._ShellIcon, m)
		return { Id = tostring(m.Id), Name = okN and tostring(name) or tostring(m.Id), Icon = okI and icon or nil, Version = tostring(m.Version or "?") }
	end

	local function PrettyKey(name) return (tostring(name):gsub("(%l)(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2")) end

	local function Initials(name)
		local words = {}
		for w in tostring(name):gmatch("%w+") do table.insert(words, w) end
		if #words >= 2 then return (words[1]:sub(1, 1) .. words[2]:sub(1, 1)):upper() end
		local w = words[1] or "?"
		return w:sub(1, 1):upper() .. w:sub(2, 2):lower()
	end

	local function IsImage(s)
		return type(s) == "string" and (s:find("^rbxasset") or s:find("^rbxthumb") or s:find("^https?://")) ~= nil
	end

	function TingUI:_ShellName()
		return tostring(S.Name or (self.Windows[1] and self.Windows[1].Title) or self.Id)
	end
	function TingUI:_ShellIcon() return S.Icon or self._iconId end
	function TingUI:_ShellCanHost() return Dock ~= nil and #self.Windows > 0 and not self.Unloaded end
	function TingUI:_ShellAnyVisible() return AnyWindowVisible() end

	function TingUI:_ShellOthers()
		local out = {}
		for _, m in ipairs(Members()) do
			if m ~= self then table.insert(out, m) end
		end
		return out
	end

	function TingUI:_ShellHostFor()
		local h = S.Role == "member" and S.Host or nil
		if h and not h.Unloaded then return h end
		return nil
	end

	-- a member's card goes to the host's stack (and the host's handle comes back); the host tags its own cards
	function TingUI:_ShellNotify(o)
		local host = self:_ShellHostFor()
		if host then
			local copy = table.clone(o)
			if copy.Source == nil then copy.Source = self:_ShellName() end
			local ok, h = pcall(host.Notify, host, copy, nil, true)
			if ok and type(h) == "table" then return h end
			return nil
		end
		if S.Role == "host" then return nil, self:_ShellName() end
		return nil
	end

	-- only one script draws the backdrop: the first one in load order that has a window open
	function TingUI:_ShellBackdropBlocked()
		if S.Role == "solo" then return false end
		for _, m in ipairs(Members()) do
			if m == self then return false end
			local ok, vis = pcall(m._ShellAnyVisible, m)
			if ok and vis then return true end
		end
		return false
	end

	-- when this script's windows open or close, the others re-check who draws the backdrop and the host's taskbar dots
	function TingUI:_ShellCascade()
		if env.TingUIShellCascading or S.Role == "solo" then return end
		env.TingUIShellCascading = true
		for _, m in ipairs(Members()) do
			if m ~= self then pcall(m._UpdateSnow, m) end
		end
		env.TingUIShellCascading = false
	end

	-- the taskbar button's left click: hide this script's open windows, or bring back the ones it hid
	function TingUI:_ShellToggle(show)
		if show == nil then show = not AnyWindowVisible() end
		if not show then
			S.Remember = {}
			for _, w in ipairs(self.Windows) do
				if w.Visible then
					table.insert(S.Remember, w)
					w:SetVisible(false)
				end
			end
		else
			local list = {}
			for _, w in ipairs(S.Remember or {}) do
				if table.find(self.Windows, w) then table.insert(list, w) end
			end
			if #list == 0 and self.Windows[1] then list = { self.Windows[1] } end
			for _, w in ipairs(list) do w:SetVisible(true) end
		end
	end

	-- this script's own dock buttons (panels, links, ...) so the host can offer them while this dock is hidden
	function TingUI:_ShellDockActions()
		local out = {}
		for _, e in ipairs(DockButtons) do
			if not e.BuiltIn and not e.Shell and type(e.Callback) == "function" and e.Button.Parent and e.Button.Visible then
				table.insert(out, { Name = tostring(e.Name), Run = e.Callback })
			end
		end
		return out
	end

	function TingUI:_ShellMenuKeys()
		local out = {}
		for i, w in ipairs(self.Windows) do
			local k = w.MenuKey
			if typeof(k) == "EnumItem" and k.EnumType == Enum.KeyCode then table.insert(out, { Key = k.Name, Index = i }) end
		end
		return out
	end

	function TingUI:_ShellSetMenuKey(index, keyName)
		local w = self.Windows[index]
		local ok, key = pcall(function() return Enum.KeyCode[keyName] end)
		if not (w and ok and key) then return false end
		w:SetMenuKey(key)
		-- the config tab's chip follows, so the new key is what gets saved
		local chip = self.Options.TingUI_MenuKey
		if chip and chip._window == w then pcall(chip.SetKey, chip, key, true) end
		return true
	end

	-- a theme sent from another script (TingUI.Shell:ApplyThemeToAll); the same built-in theme is used by name
	function TingUI:_ShellAdoptTheme(code)
		return self:ImportTheme(code, { Save = false })
	end

	local function CloseOwnPalette()
		if Palette.Open and PaletteFrame then
			Palette.Open = false
			PaletteDim.Visible = false
			PaletteFrame.Visible = false
		end
	end

	function TingUI:_ShellApplyRole()
		local member = S.Role == "member"
		if Dock then Dock.Visible = self.ShowDock and not member end
		Watermark.Visible = self.ShowWatermark and not member
		if member then CloseOwnPalette() end
		if S.Role ~= "host" then self:_ShellClearTaskbar() end
		self:_UpdateHotkeys()
		self:_UpdateSnow()
	end

	-- taskbar: a divider, then one button per other script (its icon, or its initials) with a dot that lights while
	-- one of its windows is open
	local Taskbar = { Items = {} }
	function TingUI:_ShellClearTaskbar()
		for _, e in ipairs(Taskbar.Items) do pcall(function() e.Button:Destroy() end) end
		Taskbar.Items = {}
		if Taskbar.Divider then
			Taskbar.Divider:Destroy()
			Taskbar.Divider = nil
		end
	end

	function TingUI:_ShellBuildTaskbar(members)
		self:_ShellClearTaskbar()
		if not Dock then return end
		local others = {}
		for _, m in ipairs(members) do
			if m ~= self then table.insert(others, m) end
		end
		if #others == 0 then return end
		Taskbar.Divider = New("Frame", {
			Size = UDim2.fromOffset(1, 18), LayoutOrder = 900, BackgroundTransparency = 0.2, Parent = Dock, Theme = { BackgroundColor3 = "Outline" },
		})
		for i, m in ipairs(others) do
			local info = Info(m)
			local b = New("TextButton", {
				Size = UDim2.fromOffset(31, 30), BackgroundTransparency = 1, LayoutOrder = 900 + i, Parent = Dock,
				Theme = { BackgroundColor3 = "TabActive" },
			}, { Corner(8) })
			local entry = { Button = b, Name = "Script: " .. info.Name, Shell = m,
				Active = function()
					local ok, v = pcall(m._ShellAnyVisible, m)
					return ok and v == true
				end }
			local icon = info.Icon
			if IsImage(icon) then
				entry.Image = New("ImageLabel", {
					BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(17, 17), Image = icon, Parent = b,
				})
			elseif type(icon) == "string" and (CustomIcons[icon] or table.find(ICON_NAMES, icon)) then
				entry.Icon = Icon(icon, b, 18)
				entry.Icon.AnchorPoint = Vector2.new(0.5, 0.5)
				entry.Icon.Position = UDim2.fromScale(0.5, 0.5)
			else
				entry.Letter = New("TextLabel", {
					Text = Initials(info.Name), Size = UDim2.fromScale(1, 1), TextSize = 12, Font = Enum.Font.GothamBold, Parent = b,
				})
			end
			entry.Dot = New("Frame", {
				AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4), Size = UDim2.fromOffset(5, 5), ZIndex = 2, Parent = b,
			}, { CornerFixed(3) })
			AttachHint(b, info.Name, "Click to show or hide it. Right-click for more.")
			Connect(b.MouseEnter, function()
				if not entry.Active() then
					b.BackgroundColor3 = TingUI.Theme.ControlHover
					Tween(b, 0.1, { BackgroundTransparency = 0.35 })
				end
			end)
			Connect(b.MouseLeave, function() TingUI:_UpdateDock() end)
			Connect(b.MouseButton1Click, function()
				pcall(m._ShellToggle, m)
				TingUI:_UpdateDock()
			end)
			Connect(b.MouseButton2Click, function() TingUI:_ShellMenu(m, b) end)
			table.insert(DockButtons, entry)
			table.insert(Taskbar.Items, entry)
		end
		self:_UpdateDock()
	end

	-- right-click menu on a taskbar button
	function TingUI:_ShellMenu(m, anchor)
		local info = Info(m)
		local okV, vis = pcall(m._ShellAnyVisible, m)
		local items = { { Text = (okV and vis) and "Hide" or "Show", Run = function()
			pcall(m._ShellToggle, m)
			TingUI:_UpdateDock()
		end } }
		local okA, extra = pcall(m._ShellDockActions, m)
		if okA and type(extra) == "table" then
			for _, a in ipairs(extra) do
				if type(a.Name) == "string" and type(a.Run) == "function" then table.insert(items, { Text = a.Name, Run = a.Run }) end
			end
		end
		table.insert(items, { Text = "Use my theme", Run = function()
			if TingUI.Shell:ApplyThemeTo(m) then
				TingUI:Notify({ Title = "Theme", Content = info.Name .. " now uses " .. tostring(TingUI.Preset) .. ".", Type = "Success" })
			end
		end })
		table.insert(items, { Text = "Unload", Danger = true, Run = function()
			TingUI:Confirm({
				Title = "Unload " .. info.Name .. "?", Type = "Danger", Confirm = "Unload",
				Text = "This removes its whole interface until you run it again.",
				OnConfirm = function() pcall(m.Unload, m) end,
			})
		end })
		local pop = New("Frame", {
			Visible = false, Size = UDim2.fromOffset(190, 8 + #items * 28), Parent = Overlay, Theme = { BackgroundColor3 = "Background" },
		}, { Corner(7), Stroke("Border") })
		local list = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = pop }, { Pad(4), List(2) })
		for i, it in ipairs(items) do
			local row = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 26), Text = it.Text, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i,
				Font = Enum.Font.GothamMedium, BackgroundTransparency = 1, Parent = list, Theme = { BackgroundColor3 = "ControlHover" },
				TextColor3 = it.Danger and TingUI.Theme.Error or TingUI.Theme.Label,
			}, { Corner(5), Pad(10, 0, 10, 0) })
			Connect(row.MouseEnter, function() Tween(row, 0.1, { BackgroundTransparency = 0 }) end)
			Connect(row.MouseLeave, function() Tween(row, 0.1, { BackgroundTransparency = 1 }) end)
			Connect(row.MouseButton1Click, function()
				ClosePopup()
				SafeCall("shell menu '" .. it.Text .. "'", it.Run)
			end)
		end
		ShowPopup(pop, anchor, function() task.delay(0.3, function() pop:Destroy() end) end)
		return pop
	end

	-- two scripts on one menu key both toggle when it's pressed. The host spots it once and offers the later script a
	-- free key; it also spots a menu key that is another script's keybind.
	local SPARE_KEYS = { "RightControl", "Insert", "End", "Home", "PageUp", "PageDown", "RightAlt", "F6", "F7", "F8", "F9", "F10" }
	function TingUI:_ShellReferee(members)
		local menu, bound, names = {}, {}, {}
		for _, m in ipairs(members) do
			local okN, n = pcall(m._ShellName, m)
			names[m] = okN and tostring(n) or tostring(m.Id)
			local okK, keys = pcall(m._ShellMenuKeys, m)
			if okK and type(keys) == "table" then
				for _, k in ipairs(keys) do
					menu[k.Key] = menu[k.Key] or {}
					table.insert(menu[k.Key], { Inst = m, Index = k.Index })
				end
			end
			local okB, b = pcall(m._ShellBoundKeys, m)
			bound[m] = (okB and type(b) == "table") and b or {}
		end
		local function Spare()
			for _, k in ipairs(SPARE_KEYS) do
				local used = menu[k] ~= nil
				for _, b in pairs(bound) do if b[k] then used = true end end
				if not used then return k end
			end
			return nil
		end
		local function Warn(keyName, owner, text)
			local sig = keyName .. "|" .. tostring(owner.Inst.Id) .. "|" .. tostring(owner.Index) .. "|" .. text
			if S.Warned[sig] then return end
			S.Warned[sig] = true
			local who, spare = names[owner.Inst], Spare()
			self:Notify({ Title = "Menu key clash", Content = text, Type = "Warning", Duration = 14,
				Actions = spare and {
					{ Text = "Move " .. who .. " to " .. PrettyKey(spare), Callback = function()
						local ok, done = pcall(owner.Inst._ShellSetMenuKey, owner.Inst, owner.Index, spare)
						if ok and done then
							TingUI:Notify({ Title = "Menu key", Content = who .. " now opens with " .. PrettyKey(spare) .. ".", Type = "Success" })
						end
					end },
					{ Text = "Leave it" },
				} or nil })
		end
		for keyName, owners in pairs(menu) do
			local first = owners[1]
			for j = 2, #owners do
				local o = owners[j]
				if o.Inst ~= first.Inst then
					Warn(keyName, o, names[first.Inst] .. " and " .. names[o.Inst] .. " both open with " .. PrettyKey(keyName) .. ".")
					break
				end
			end
			for _, o in ipairs(owners) do
				for m, b in pairs(bound) do
					if m ~= o.Inst and b[keyName] then
						Warn(keyName, o, PrettyKey(keyName) .. " opens " .. names[o.Inst] .. " and also triggers '" .. tostring(b[keyName]) .. "' in " .. names[m] .. ".")
					end
				end
			end
		end
	end

	-- the heartbeat: work out this script's role, and keep the taskbar, hotkey list and backdrop in step with who's here
	function TingUI:_ShellTick()
		if self.Unloaded then return end
		local members = Members()
		local host
		if table.find(members, self) and #members > 1 then
			for _, m in ipairs(members) do
				local ok, can = pcall(m._ShellCanHost, m)
				if ok and can then
					host = m
					break
				end
			end
		end
		local role = host == nil and "solo" or (host == self and "host" or "member")
		if role ~= S.Role or (role == "member" and host ~= S.Host) then
			S.Role, S.Host = role, role == "member" and host or nil
			S.Sig = nil
			self:_ShellApplyRole()
			self.Shell.Events.RoleChanged:Fire(role)
		end
		local ids, parts = {}, {}
		for _, m in ipairs(members) do
			if m ~= self then
				local i = Info(m)
				ids[i.Id] = i
				table.insert(parts, i.Id .. "=" .. i.Name .. "=" .. tostring(i.Icon))
			end
		end
		local sig = role .. "|" .. table.concat(parts, "|")
		if sig ~= S.Sig then
			for id, i in pairs(ids) do
				if not S.Known[id] then self.Shell.Events.Joined:Fire(i) end
			end
			for id, i in pairs(S.Known) do
				if not ids[id] then self.Shell.Events.Left:Fire(i) end
			end
			S.Known, S.Sig = ids, sig
			if role == "host" then self:_ShellBuildTaskbar(members) else self:_ShellClearTaskbar() end
			self:_UpdateHotkeys()
			self:_UpdateSnow()
		end
		if role == "host" then self:_ShellReferee(members) end
	end

	function TingUI:_ShellNudgeAll()
		for _, m in ipairs(Members()) do
			if m ~= self then pcall(m._ShellTick, m) end
		end
	end

	-- scripts already running when this one loaded aren't "joined"
	S.Known = {}
	for _, m in ipairs(Members()) do
		if m ~= TingUI then S.Known[tostring(m.Id)] = Info(m) end
	end

	-- the public side: TingUI.Shell
	local Shell = { Events = { Joined = NewSignal(), Left = NewSignal(), RoleChanged = NewSignal() } }
	TingUI.Shell = Shell
	function Shell:Role() return S.Role end
	function Shell:IsHost() return S.Role == "host" end
	function Shell:IsEnabled() return S.Enabled end
	-- every script in the Shell, in load order: { Id, Name, Icon, Version, Open, Host, Self }
	function Shell:List()
		local out = {}
		local host = S.Role == "host" and TingUI or S.Host
		for _, m in ipairs(Members()) do
			local i = Info(m)
			local ok, vis = pcall(m._ShellAnyVisible, m)
			i.Open = ok and vis == true
			i.Host = m == host
			i.Self = m == TingUI
			table.insert(out, i)
		end
		return out
	end
	function Shell:Host()
		for _, i in ipairs(self:List()) do
			if i.Host then return i end
		end
		return nil
	end
	local function Refresh()
		S.Sig = nil
		pcall(TingUI._ShellTick, TingUI)
		TingUI:_ShellNudgeAll()
	end
	function Shell:SetEnabled(v)
		S.Enabled = v ~= false
		Refresh()
	end
	function Shell:SetName(name)
		S.Name = name ~= nil and tostring(name) or nil
		Refresh()
	end
	function Shell:SetIcon(icon)
		S.Icon = type(icon) == "string" and icon or nil
		Refresh()
	end
	-- give one script this script's current look: an entry from List(), its Id, or the instance itself
	function Shell:ApplyThemeTo(m)
		if type(m) == "string" or (type(m) == "table" and rawget(m, "_Shell") == nil and m.Id ~= nil) then
			local id = type(m) == "string" and m or tostring(m.Id)
			m = nil
			for _, x in ipairs(Members()) do
				if tostring(x.Id) == id then m = x break end
			end
		end
		if type(m) ~= "table" then return false end
		if m == TingUI then return true end
		local okC, code = pcall(TingUI.ExportTheme, TingUI)
		if not okC or type(code) ~= "string" then return false end
		local ok, res = pcall(m._ShellAdoptTheme, m, code)
		return ok and res ~= nil
	end
	-- this script's look (or the theme you name, applied here too) in every script; returns how many took it
	function Shell:ApplyThemeToAll(name)
		if name ~= nil then
			if not TingUI.Presets[PresetName(name)] then return 0, "There's no theme called '" .. tostring(name) .. "'" end
			TingUI:ApplyPreset(name)
		end
		local n = 0
		for _, m in ipairs(Members()) do
			if m ~= TingUI and self:ApplyThemeTo(m) then n = n + 1 end
		end
		return n
	end

	task.spawn(function()
		while not TingUI.Unloaded do
			task.wait(0.4)
			if TingUI.Unloaded then break end
			local ok, err = pcall(TingUI._ShellTick, TingUI)
			if not ok and not S.Failed then
				S.Failed = true
				warn("[TingUI] shell tick failed: " .. tostring(err))
			end
		end
	end)
end Setup() end

------------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------------

local function PillSpec(v, default)
	if type(v) == "string" then return { Text = v, Color = default } end
	if type(v) == "table" then return { Text = v.Text, Color = v.Color or default } end
end

function TingUI:CreateWindow(o)
	o = o or {}
	local W = {
		Tabs = {}, Title = o.Title or "TingUI", Id = o.Id or "MainWindow", Visible = true,
		MenuKey = o.MenuKey or Enum.KeyCode.RightShift,
	}
	if o.MenuKey == false then W.MenuKey = nil end -- no key: shown and hidden from code, the dock or its close button
	local vp = self:_Viewport()
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
	local surface = RegisterSurface(main, "Window", 10)
	W.Frame = main

	local header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), Parent = main })
	local titleRow = New("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(0.7, 0, 1, 0), Parent = header,
	}, { List(10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local titleLabel = New("TextLabel", {
		Text = W.Title, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), TextSize = 13,
		TextColor3 = self.Theme.Text, LayoutOrder = 1, Parent = titleRow,
	})
	surface.Title = titleLabel
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
	-- Closable = true: a small x in the header that hides the window
	if o.Closable then
		local close = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1, ZIndex = 3, Parent = header, Theme = { BackgroundColor3 = "ControlHover" },
		}, { Corner(6) })
		for _, r in ipairs({ 45, -45 }) do
			New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(11, 1.6), Rotation = r,
				ZIndex = 4, Parent = close, Theme = { BackgroundColor3 = "TextDim" },
			}, { CornerFixed(1) })
		end
		AttachTooltip(close, "Close")
		Connect(close.MouseEnter, function() Tween(close, 0.1, { BackgroundTransparency = 0.2 }) end)
		Connect(close.MouseLeave, function() Tween(close, 0.1, { BackgroundTransparency = 1 }) end)
		Connect(close.MouseButton1Click, function() W:SetVisible(false) end)
		subtitle.Position = UDim2.new(1, -44, 0, 0)
	end
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

	-- Tabs always fit. A theme with a wide font (or a narrow window, or many tabs) used to push the last tabs past the
	-- edge. Now the padding tightens first, then the gap, then the labels shrink a little (never below 84%), and only
	-- if that still isn't enough does the bar scroll: the active tab is slid into view and soft fades mark the edges.
	local fadeL = New("Frame", { Size = UDim2.new(0, 22, 1, 0), Position = tabbar.Position, BackgroundTransparency = 1, Visible = false,
		ZIndex = 3, Parent = main, Theme = { BackgroundColor3 = "Background" } },
		{ New("UIGradient", { Transparency = NumberSequence.new(0, 1) }) })
	local fadeR = New("Frame", { AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0, 22, 1, 0), Position = UDim2.new(1, -17, 0, 49),
		BackgroundTransparency = 1, Visible = false, ZIndex = 3, Parent = main, Theme = { BackgroundColor3 = "Background" } },
		{ New("UIGradient", { Transparency = NumberSequence.new(1, 0) }) })
	fadeL.Size = UDim2.fromOffset(22, 28)
	fadeR.Size = UDim2.fromOffset(22, 28)
	local tabLayout = tabbar:FindFirstChildOfClass("UIListLayout")
	local fitQueued, fitting = false, false
	local function TabEdges()
		local scrolls = tabbar.AbsoluteCanvasSize.X > tabbar.AbsoluteSize.X + 1
		local x = tabbar.CanvasPosition.X
		local maxX = math.max(0, tabbar.AbsoluteCanvasSize.X - tabbar.AbsoluteSize.X)
		fadeL.Visible = scrolls and x > 1
		fadeR.Visible = scrolls and x < maxX - 1
		fadeL.BackgroundTransparency = 0
		fadeR.BackgroundTransparency = 0
	end
	function W:_FitTabs()
		if fitting then return end
		fitting = true
		local sc = (W._scale and W._scale.Scale) or TingUI.Scale
		if sc <= 0 then sc = 1 end
		local avail = tabbar.AbsoluteSize.X / sc
		local list = {}
		for _, t in ipairs(W.Tabs) do if t.Button.Parent and t.Button.Visible then table.insert(list, t) end end
		local n = #list
		if n > 0 and avail > 20 then
			-- every label's full-size width (a shrunk label's width scales back up by its shrink factor)
			local texts = 0
			for _, t in ipairs(list) do
				local b = t.Button
				local tb = b.TextBounds
				local w = (tb and tb.X > 0) and (tb.X / sc) or (#tostring(b.Text) * 7)
				texts = texts + w / (b:GetAttribute("TSK") or 1)
			end
			local gap = 5
			local pad = math.floor(math.clamp((avail - texts - gap * (n - 1)) / (2 * n), 4, 11))
			local need = texts + pad * 2 * n + gap * (n - 1)
			if need > avail then
				gap = 2
				need = texts + pad * 2 * n + gap * (n - 1)
			end
			local k = 1
			if need > avail then
				k = math.clamp((avail - pad * 2 * n - gap * (n - 1)) / math.max(texts, 1), 0.84, 1)
			end
			for _, t in ipairs(list) do
				local b = t.Button
				local p2 = b:FindFirstChildOfClass("UIPadding")
				if p2 and p2.PaddingLeft.Offset ~= pad then
					p2.PaddingLeft = UDim.new(0, pad)
					p2.PaddingRight = UDim.new(0, pad)
				end
				if math.abs((b:GetAttribute("TSK") or 1) - k) > 0.01 then
					b:SetAttribute("TSK", k < 0.995 and k or nil)
					ApplyFont(b, "SemiBold")
				end
			end
			if tabLayout and tabLayout.Padding.Offset ~= gap then tabLayout.Padding = UDim.new(0, gap) end
		end
		fitting = false
		task.defer(function()
			TabEdges()
			if W._ScrollTabIntoView then W._ScrollTabIntoView(true) end
		end)
	end
	local function QueueFit()
		if fitQueued then return end
		fitQueued = true
		task.defer(function()
			fitQueued = false
			if not TingUI.Unloaded then W:_FitTabs() end
		end)
	end
	W._QueueFitTabs = QueueFit
	Connect(tabbar:GetPropertyChangedSignal("AbsoluteSize"), QueueFit)
	Connect(tabbar:GetPropertyChangedSignal("CanvasPosition"), TabEdges)
	Connect(tabbar:GetPropertyChangedSignal("AbsoluteCanvasSize"), TabEdges)
	table.insert(Refreshers, QueueFit)
	-- keep the active tab fully visible when the bar has to scroll
	function W._ScrollTabIntoView(instant)
		local t = W.Active
		if not t or not t.Button.Parent then return end
		if tabbar.AbsoluteCanvasSize.X <= tabbar.AbsoluteSize.X + 1 then
			if tabbar.CanvasPosition.X ~= 0 then tabbar.CanvasPosition = Vector2.new(0, 0) end
			return
		end
		local sc = (W._scale and W._scale.Scale) or TingUI.Scale
		if sc <= 0 then sc = 1 end
		local b = t.Button
		local left = (b.AbsolutePosition.X - tabbar.AbsolutePosition.X) / sc
		local right = left + b.AbsoluteSize.X / sc
		local view = tabbar.AbsoluteSize.X / sc
		local x = tabbar.CanvasPosition.X
		local goal = x
		if left < 24 then goal = x + left - 24 elseif right > view - 24 then goal = x + right - view + 24 end
		local maxX = math.max(0, (tabbar.AbsoluteCanvasSize.X - tabbar.AbsoluteSize.X) / sc)
		goal = math.clamp(goal, 0, maxX)
		if math.abs(goal - x) < 0.5 then return end
		if instant then
			tabbar.CanvasPosition = Vector2.new(goal, 0)
		else
			TweenService:Create(tabbar, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { CanvasPosition = Vector2.new(goal, 0) }):Play()
		end
	end

	local function Ghost(t)
		if not t or t == W.Active or not t.Button.Parent then
			Tween(ghost, 0.18, { BackgroundTransparency = 1 })
			return
		end
		local sc = (W._scale and W._scale.Scale) or TingUI.Scale
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
		New("Frame", { Size = UDim2.fromOffset(8, 1), Position = UDim2.new(1, -9, 1, -3), Rotation = -45, BackgroundTransparency = 0.3, Theme = { BackgroundColor3 = "TextMuted" } }),
		New("Frame", { Size = UDim2.fromOffset(4, 1), Position = UDim2.new(1, -6, 1, -3), Rotation = -45, BackgroundTransparency = 0.3, Theme = { BackgroundColor3 = "TextMuted" } }),
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
				local d = (UIS:GetMouseLocation() - startMouse) / TingUI.Scale
				local base = startSize / TingUI.Scale
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

	-- The pill always heads for wherever the active tab is *right now*. Tab widths change when a theme swaps the
	-- font, so a glide aimed at the old spot is re-aimed instead of finishing in the wrong place, and a watchdog
	-- below catches anything else (window scaling, tabs shown/hidden mid-glide) so it can never stay stuck.
	local indGoal = nil
	local function IndicatorGoal()
		local t = W.Active
		if not t or t.Hidden or not t.Button.Parent then return nil end
		local sc = (W._scale and W._scale.Scale) or TingUI.Scale
		if sc <= 0 then return nil end
		local b = t.Button
		local x = math.floor((b.AbsolutePosition.X - indHolder.AbsolutePosition.X) / sc + 0.5)
		local w = math.floor(b.AbsoluteSize.X / sc + 0.5)
		if w <= 0 then return nil end
		return x, w
	end
	local function Glide(x, w, time)
		if indTween then indTween:Cancel() end
		indGoal = { x, w }
		indTween = TweenService:Create(ind, TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(w, 28), BackgroundTransparency = 0 })
		local mine = indTween
		indTween.Completed:Connect(function() if indTween == mine then indTween = nil end end)
		indTween:Play()
		task.delay(time + 0.05, function() if indTween == mine then indTween = nil end end)
	end
	local function MoveIndicator(instant)
		local x, w = IndicatorGoal()
		if not x then
			if indTween then indTween:Cancel() indTween = nil end
			indGoal = nil
			Tween(ind, 0.15, { BackgroundTransparency = 1 })
			return
		end
		if instant then
			if indTween then
				-- mid-glide: re-aim at the new spot instead of ignoring the change
				if not indGoal or math.abs(indGoal[1] - x) > 0.5 or math.abs(indGoal[2] - w) > 0.5 then Glide(x, w, 0.22) end
				return
			end
			indGoal = { x, w }
			ind.Position, ind.Size, ind.BackgroundTransparency = UDim2.fromOffset(x, 0), UDim2.fromOffset(w, 28), 0
		elseif not (indTween and indGoal and indGoal[1] == x and indGoal[2] == w) then
			Glide(x, w, 0.34)
		end
	end
	W._MoveIndicator = MoveIndicator
	W._Indicator = ind
	-- watchdog: a few times a second, make sure the resting pill sits exactly on the active tab
	do
		local acc = 0
		Connect(RunService.Heartbeat, function(dt)
			acc = acc + dt
			if acc < 0.15 then return end
			acc = 0
			if indTween or not main.Visible or TingUI.Unloaded then return end
			local x, w = IndicatorGoal()
			if not x then return end
			local p, z = ind.Position.X.Offset, ind.Size.X.Offset
			if math.abs(p - x) > 0.5 or math.abs(z - w) > 0.5 or ind.BackgroundTransparency > 0.01 then Glide(x, w, 0.25) end
		end)
	end
	Connect(tabbar:GetPropertyChangedSignal("CanvasPosition"), function() MoveIndicator(true) end)

	function W:_StyleTabs(skipPages, instant)
		for _, t in ipairs(self.Tabs) do
			local on = (t == self.Active) and not t.Hidden
			if not skipPages then t.Page.Visible = on end
			t.Button.BackgroundTransparency = 1
			local c = on and TingUI.Theme.AccentText or TingUI.Theme.TextDim
			if instant then t.Button.TextColor3 = c else Tween(t.Button, 0.18, { TextColor3 = c }) end
		end
		MoveIndicator(instant == true)
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
		if self._ScrollTabIntoView then self._ScrollTabIntoView(false) end
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
		TingUI.Events.TabChanged:Fire(t.Name, W)
	end

	-- next / previous visible tab (Ctrl+Tab and Ctrl+Shift+Tab call these)
	function W:CycleTab(step)
		local list = {}
		for _, x in ipairs(self.Tabs) do if not x.Hidden then table.insert(list, x) end end
		if #list == 0 then return end
		local cur = table.find(list, self.Active) or 1
		self:SelectTab(list[((cur - 1 + step) % #list) + 1])
	end
	table.insert(Refreshers, function() W:_StyleTabs(true, true) end)

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
				sc.Scale = TingUI.Scale * 0.94
				TweenService:Create(sc, TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = TingUI.Scale }):Play()
			end
			task.delay(0.36, function() if mine == VisToken then MoveIndicator(true) end end)
		else
			ClosePopup()
			HideHint()
			if sc then
				TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = TingUI.Scale * 0.94 }):Play()
				task.delay(0.17, function()
					if mine == VisToken and not self.Visible then
						main.Visible = false
						sc.Scale = TingUI.Scale
					end
				end)
			else
				main.Visible = false
			end
		end
		TingUI:_UpdateSnow()
		TingUI.Events.VisibilityChanged:Fire(v, W)
	end
	function W:Toggle() self:SetVisible(not self.Visible) end
	function W:Destroy()
		self.Destroyed = true
		ClosePopup()
		main:Destroy()
		for i, w in ipairs(TingUI.Windows) do if w == self then table.remove(TingUI.Windows, i) break end end
		TingUI:_UpdateSnow()
		TingUI:_SinkMenuKeys()
	end
	-- change the key that shows and hides this window (a KeyCode or a mouse UserInputType)
	function W:SetMenuKey(k)
		self.MenuKey = k
		TingUI:_SinkMenuKeys()
	end

	function W:AddTab(name)
		local T = { Name = name, Window = W, _flip = false, Boxes = {}, Sections = {}, Fill = o.Fill ~= false }
		T.Button = New("TextButton", {
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), BackgroundTransparency = 1,
			Text = name, TextColor3 = TingUI.Theme.TextDim, LayoutOrder = #W.Tabs + 1, Parent = tabbar,
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

		-- a group or tabbox removed from the page; the settings inside leave Options and Flags with it
		local function DropBox(frame)
			for i, b in ipairs(T.Boxes) do if b.Frame == frame then table.remove(T.Boxes, i) break end end
			for i, sec in ipairs(T.Sections) do if sec.Frame == frame then table.remove(T.Sections, i) break end end
			for flag, opt in pairs(TingUI.Options) do
				local inst = type(opt) == "table" and (rawget(opt, "Row") or rawget(opt, "Chip") or rawget(opt, "_swatch"))
				if inst and (inst == frame or inst:IsDescendantOf(frame)) then
					TingUI.Options[flag] = nil
					TingUI.Flags[flag] = nil
				end
			end
			frame:Destroy()
			Relayout()
			TingUI:_UpdateHotkeys()
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
				Frame = frame,
			})
			function g:Destroy() DropBox(frame) end
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
				local sc = (W._scale and W._scale.Scale) or TingUI.Scale
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
					Tween(sub.Button, 0.15, { TextColor3 = on and TingUI.Theme.AccentText or TingUI.Theme.Label })
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
					Tween(x.Button, 0.15, { TextColor3 = (x == active) and TingUI.Theme.AccentText or TingUI.Theme.Label })
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
				Frame = frame,
			})
			function Box:Destroy() DropBox(frame) end
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
			local color = wo.Type and TingUI.Theme[wo.Type] or TingUI.Theme.Text
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
				Text = wo.Text or "", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 12,
				Theme = { TextColor3 = "Label" }, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
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
			W._QueueFitTabs()
			T.Page:Destroy()
			if W.Active == T then
				W.Active = nil
				for _, t in ipairs(W.Tabs) do
					if not t.Hidden then W:SelectTab(t) break end
				end
			end
		end

		Connect(T.Button.MouseButton1Click, function() W:SelectTab(T) end)
		Connect(T.Button.InputBegan, function(i) Pointer.Calibrate(T.Button, i) end)
		Connect(T.Button.MouseEnter, function()
			if W.Active ~= T then Tween(T.Button, 0.12, { TextColor3 = TingUI.Theme.Label }) end
			Ghost(T)
		end)
		Connect(T.Button.MouseLeave, function()
			if W.Active ~= T then Tween(T.Button, 0.12, { TextColor3 = TingUI.Theme.TextDim }) end
			Ghost(nil)
		end)
		Connect(T.Button:GetPropertyChangedSignal("AbsoluteSize"), function() if W.Active == T then MoveIndicator(true) end end)
		Connect(T.Button:GetPropertyChangedSignal("TextBounds"), W._QueueFitTabs)
		Connect(T.Button:GetPropertyChangedSignal("Visible"), W._QueueFitTabs)
		W._QueueFitTabs()
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
		local menuChip = menu:AddLabel({ Text = "Menu keybind", Description = "The key that shows and hides the whole menu. Click the chip, then press a new key." }):AddKeybind({
			Default = self.MenuKey, Mode = "Press", Flag = "TingUI_MenuKey", ShowInList = false,
			ChangedCallback = function(k) if k then W:SetMenuKey(k) end end,
		})
		menuChip._window = W
		menu:AddToggle({ Text = "Show dock", Default = TingUI.ShowDock, Flag = "TingUI_Dock",
			Description = "The icon bar at the top of the screen. It stays visible when the menu is hidden, so you can reopen the menu with a click.",
			Callback = function(v) TingUI:SetDockVisible(v) end })
		menu:AddToggle({ Text = "Show watermark", Default = TingUI.ShowWatermark, Flag = "TingUI_Watermark",
			Description = "The bar in the top-left corner showing the script name, your username, FPS and ping.",
			Callback = function(v) TingUI:SetWatermarkVisible(v) end })
		menu:AddToggle({ Text = "Show hotkey list", Default = TingUI.ShowHotkeys, Flag = "TingUI_Hotkeys",
			Description = "A small panel listing every keybind and whether it is currently active.",
			Callback = function(v) TingUI:SetHotkeysVisible(v) end })
		menu:AddToggle({ Text = "Notifications", Default = TingUI.ShowNotifications, Flag = "TingUI_Notifs",
			Description = "Turns every pop-up message on or off. Errors are still printed to the console.",
			Callback = function(v) TingUI.ShowNotifications = v end })
		menu:AddDropdown({ Text = "Notification position", Values = TingUI.NotifyPositions, Default = TingUI.NotifyPosition, Flag = "TingUI_NotifyPos",
			Description = "Which corner of the screen messages slide in from.",
			Callback = function(v) if v then TingUI:SetNotifyPosition(v) end end })
		menu:AddToggle({ Text = "Hover explanations", Default = TingUI.Hints, Flag = "TingUI_Hints",
			Description = "Shows a short explanation, like this one, when you rest the mouse on a setting.",
			Callback = function(v) TingUI.Hints = v if not v then HideHint() end end })
		menu:AddToggle({ Text = "Script error alerts", Default = TingUI.NotifyErrors, Flag = "TingUI_NotifyErrors",
			Description = "If a feature's code crashes, show a red notification with the error instead of failing silently. Errors are always printed to the console.",
			Callback = function(v) TingUI.NotifyErrors = v end })
		menu:AddSlider({ Text = "UI scale", Min = 0.7, Max = 1.4, Default = TingUI.Scale, Increment = 0.05, Suffix = "x",
			Description = "Makes the menu, panels and pop-ups bigger or smaller. Handy on small screens or 4K monitors.",
			Flag = "TingUI_Scale", Callback = function(v) TingUI:SetScale(v) end })
		TingUI._fontDropdown = menu:AddDropdown({ Text = "Font", Values = TingUI.FontNames,
			Default = TingUI.FontName,
			Description = "The typeface used everywhere. Themes pick one automatically; choose here to override it.",
			Callback = function(v)
				if v == "Inter" and not TingUI._interAsset then
					TingUI:Notify({ Title = "Font", Content = "Inter needs file support in your executor. Using Gotham.", Type = "Warning" })
				end
				if v then TingUI:SetFont(v, 0.35) end
			end })
		menu:AddInput({ Text = "Screen watermark", Placeholder = "text tiled over the screen (empty = off)",
			Description = "Faint text tiled over the whole screen, e.g. your name, to discourage reposted screenshots.",
			Callback = function(v) TingUI:SetScreenWatermark(v) end })
		menu:AddDivider()
		menu:AddButton({ Text = "Unload", Description = "Removes the interface and stops everything it was doing.",
			Confirm = { Title = "Unload TingUI?", Text = "This removes the whole interface until you run the script again.", Type = "Danger", Confirm = "Unload" },
			Callback = function() TingUI:Unload() end })

		local fx = tab:AddGroup("Effects", "Left")
		fx:AddToggle({ Text = "Reduce motion", Default = TingUI.ReducedMotion, Flag = "TingUI_ReducedMotion",
			Description = "Holds theme scenes and particles still and turns off flicker, glitches and lightning flashes. Colours and themes stay the same.",
			Callback = function(v) if v ~= TingUI.ReducedMotion then TingUI:SetReducedMotion(v) end end })
		fx:AddToggle({ Text = "Particles", Default = Snow.Enabled, Flag = "TingUI_Snow",
			Description = "Animated shapes drifting behind the menu while it is open.",
			Callback = function(v) TingUI:SetSnow(v) end })
		table.insert(TingUI._particleDropdowns, fx:AddDropdown({ Text = "Particle style", Values = TingUI.ParticleKinds, Default = Snow.Kind, Flag = "TingUI_Particles",
			Description = "\"Theme\" uses whatever the current theme ships with. Pick another to mix and match; switching crossfades.",
			Callback = function(v) if v then TingUI:SetSnowOptions({ Kind = v }) end end }))
		fx:AddSlider({ Text = "Amount", Min = 10, Max = 200, Default = Snow.Count, Flag = "TingUI_SnowCount",
			Description = "How many particles are on screen. Lower it if your frame rate drops.",
			Callback = function(v) TingUI:SetSnowOptions({ Count = v }) end })
		fx:AddSlider({ Text = "Speed", Min = 0.2, Max = 3, Default = Snow.Speed, Increment = 0.1, Suffix = "x",
			Description = "How fast particles move and twinkle.",
			Flag = "TingUI_SnowSpeed", Callback = function(v) TingUI:SetSnowOptions({ Speed = v }) end })
		fx:AddSlider({ Text = "Backdrop dim", Min = 0, Max = 90, Default = math.floor(Backdrop.Dim * 100), Suffix = "%",
			Description = "How much the game behind the menu is darkened while the menu is open.",
			Flag = "TingUI_Dim", Callback = function(v) TingUI:SetBackdrop({ Dim = v / 100 }) end })
		fx:AddSlider({ Text = "Backdrop blur", Min = 0, Max = 40, Default = Backdrop.Blur,
			Description = "How much the game behind the menu is blurred while the menu is open. 0 turns it off.",
			Flag = "TingUI_Blur", Callback = function(v) TingUI:SetBackdrop({ Blur = v }) end })

		-- HUD pieces glide back to their spot after you drag them
		local hud = tab:AddGroup("HUD Positions", "Left")
		local sb = TingUI.SnapBack
		hud:AddToggle({ Text = "Return to place after dragging", Default = sb.Enabled, Flag = "TingUI_Snap",
			Description = "After you drag the dock or hotkey list somewhere, it glides back to its spot after a few seconds.",
			Callback = function(v) sb.Enabled = v end })
		hud:AddSlider({ Text = "Return after", Min = 1, Max = 30, Default = sb.Delay, Suffix = "s", Flag = "TingUI_SnapDelay",
			Description = "How many seconds a moved panel waits before gliding back.",
			Callback = function(v) sb.Delay = v end })
		hud:AddToggle({ Text = "Dock", Default = sb.Dock, Flag = "TingUI_SnapDock", Description = "Whether the dock glides back after you move it.",
			Callback = function(v) sb.Dock = v end })
		hud:AddToggle({ Text = "Hotkey list", Default = sb.Hotkeys, Flag = "TingUI_SnapHotkeys", Description = "Whether the hotkey list glides back after you move it.",
			Callback = function(v) sb.Hotkeys = v end })
		hud:AddToggle({ Text = "Watermark", Default = sb.Watermark, Flag = "TingUI_SnapWatermark", Description = "Whether the watermark glides back after you move it.",
			Callback = function(v) sb.Watermark = v end })
		hud:AddButton({ Text = "Return now", Description = "Glide every moved panel back to its home spot right away.", Callback = function() TingUI:ResetHudPositions() end })
			:AddSubButton({ Text = "Set as home", Callback = function()
				TingUI:SetHudHome()
				TingUI:Notify({ Title = "HUD", Content = "Current positions saved as home.", Type = "Success" })
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
			for _, pnl in ipairs(TingUI._Panels) do
				maps.Extras["Panel: " .. pnl.Name] = { Get = function() return pnl.Frame.Visible end, Set = function(v) pnl:SetVisible(v) end }
			end
			for _, e in ipairs(TingUI:GetDockButtons()) do
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
			local T = TingUI._themeTarget or TingUI.Theme
			for k, pk in pairs(pickers) do pk:Set(T[k], true) end
		end
		-- the Theme Studio and share codes change colours too; these pickers follow
		TingUI._pickerSyncers = TingUI._pickerSyncers or {}
		table.insert(TingUI._pickerSyncers, SyncPickers)
		local names = {}
		for n in pairs(TingUI.Presets) do table.insert(names, PresetLabel(n)) end
		table.sort(names, function(x, y)
			if x == "Lavender (Default)" then return true elseif y == "Lavender (Default)" then return false end
			return x < y
		end)
		local DESCRIPTIONS = {
			Lavender = "The reference look: soft lilac, snow.",
			Ocean = "The window floats in water: rolling waves that rise toward your cursor, caustic light, a tide that washes over on switching, click ripples, and bubbles that pop at depth, at the surface or when you touch them.",
			Rose = "Extra round and glowy, drifting petals.",
			Sunset = "Warm glow from below, rising embers.",
			Mono = "Sharp corners, no glow, monospace, scanlines, glyph rain.",
			Frost = "Pale ice, thin rounded type, a frosted double border, spinning ice crystals.",
			Royal = "Midnight navy and gold, serif type, a gilded double border, glinting sparkles.",
			Cosmos = "Deep space: drifting nebula clouds over a parallax star layer, a turning aurora border, twinkling stars, shooting stars and comets.",
			Storm = "Slate and steel, condensed type, slanted rain and distant lightning.",
			Blueprint = "Drafting paper: navy blue, a white grid, a ruled double border, handwritten labels, drafting marks.",
			Hazard = "Industrial yellow and black, a striped warning-tape border, square corners.",
			Serotonin = "A crisp classic cheat-menu look: square corners, a hairline teal outline in a dark teal frame, teal light from the top, plain type. No particles.",
			Glass = "See-through frosted surfaces over a blurred world, soft rounded type, real lens bokeh drifting at different depths with a glint now and then.",
			Hologram = "A cyan light projection: brackets lock on as it opens, a scan line sweeps each page, the image tears now and then, clicks ripple out as hexagons, a projector beam glows underneath.",
			Circuit = "The window is a chip on a circuit board: copper traces run from its pins, current races along them, pins warm up under your cursor and every click fires a burst down the nearest traces.",
		}
		local desc
		local presetDrop = th:AddDropdown({ Text = "Preset", Values = names, Default = PresetLabel(TingUI.Preset), Flag = "TingUI_Preset",
			Description = "A complete look: colours, corner shape, glow, font, window lighting and particles.",
			Callback = function(v)
				if v then
					TingUI:ApplyPreset(v)
					SyncPickers()
					if desc then desc:SetText(DESCRIPTIONS[PresetName(v)] or "") end
				end
			end })
		table.insert(TingUI._presetDropdowns, presetDrop)
		desc = th:AddLabel(DESCRIPTIONS[TingUI.Preset] or "", { Dim = true })
		TingUI._presetDescriptions = DESCRIPTIONS
		-- your saved themes (Theme Studio, ImportTheme) join the list
		pcall(TingUI._LoadSavedThemes, TingUI)
		th:AddSlider({ Text = "Theme fade", Min = 0, Max = 1.5, Default = TingUI.ThemeTransition, Increment = 0.05, Suffix = "s",
			Description = "How long switching themes takes. Colours, corners, glow, fonts and particles all blend over this time. 0 makes theme changes instant.",
			Flag = "TingUI_ThemeFade", Callback = function(v) TingUI.ThemeTransition = v end })
		for _, entry in ipairs({ { "Accent", "Accent" }, { "Background", "Window" }, { "Group", "Panels" },
			{ "Control", "Controls" }, { "Outline", "Outlines" }, { "Border", "Borders" },
			{ "Text", "Text" }, { "Label", "Labels" }, { "TextDim", "Dim text" } }) do
			local key, label = entry[1], entry[2]
			pickers[key] = th:AddLabel(label):AddColorPicker({
				Default = TingUI.Theme[key], Flag = "TingUI_Theme_" .. key,
				Title = label, Description = "Fine-tune one colour of the current theme. Picking a preset resets it.",
				Callback = function(c) TingUI:SetTheme({ [key] = c }) end,
			})
		end
		th:AddButton({ Text = "Reset theme", Description = "Go back to the default Lavender look.", Callback = function()
			TingUI:ApplyPreset("Lavender")
			SyncPickers()
			if desc then desc:SetText(DESCRIPTIONS.Lavender) end
		end })
		th:AddButton({ Text = "Open Theme Studio", Description = "Edit every part of the theme live, check that text stays readable, and save it or share it as a code.",
			Callback = function() TingUI:OpenThemeStudio() end })
			:AddSubButton({ Text = "Use in every script", Description = "Gives every other TingUI script running right now this look.", Callback = function()
				local n = TingUI.Shell:ApplyThemeToAll()
				TingUI:Notify({ Title = "Theme", Content = n > 0 and ("Applied to " .. n .. (n == 1 and " other script." or " other scripts.")) or "No other TingUI scripts are running.",
					Type = n > 0 and "Success" or "Info" })
			end })

		local tests = tab:AddGroup("Tests", "Right")
		tests:AddButton({ Text = "Success", Callback = function()
			TingUI:Notify({ Title = "Success", Content = "Settings applied and saved.", Type = "Success" })
		end }):AddSubButton({ Text = "Warning", Callback = function()
			TingUI:Notify({ Title = "Warning", Content = "This feature can be unstable in some games.", Type = "Warning" })
		end })
		tests:AddButton({ Text = "Error", Callback = function()
			TingUI:Notify({ Title = "Error", Content = "Couldn't reach the server. Try again in a moment.", Type = "Error" })
		end }):AddSubButton({ Text = "Info", Callback = function()
			TingUI:Notify({ Title = "Info", Content = "Press Ctrl+K to search every option.", Type = "Info" })
		end })
		tests:AddButton({ Text = "Loading -> Done", Callback = function()
			local n = TingUI:Notify({ Title = "Loading", Content = "Fetching your config...", Type = "Loading" })
			task.delay(2, function() n:Update({ Title = "Done", Content = "Config loaded.", Type = "Success" }) end)
		end }):AddSubButton({ Text = "Plain", Callback = function() TingUI:Notify("test notif") end })
		tests:AddButton({ Text = "Download", Description = "A download with a live progress bar; the arrow keeps dropping into the tray until it's done.", Callback = function()
			local n = TingUI:Notify({ Title = "Downloading", Content = "assets.pak  0 / 24 MB", Type = "Download", Value = 0 })
			task.spawn(function()
				for i = 1, 24 do
					task.wait(0.12)
					if n.Closed then return end
					n:SetProgress(i / 24, string.format("assets.pak  %d / 24 MB", i))
				end
				n:Update({ Title = "Downloaded", Content = "assets.pak is ready.", Type = "Success", Value = 1, Duration = 4 })
			end)
		end }):AddSubButton({ Text = "Undo", Description = "Something that can be taken back for a few seconds.", Callback = function()
			TingUI:Notify({ Title = "Config deleted", Content = "\"pvp\" was removed.", Type = "Warning",
				Undo = function() TingUI:Notify({ Content = "Restored \"pvp\".", Type = "Success" }) end,
				OnCommit = function() end })
		end })
		tests:AddButton({ Text = "Message", Description = "A message you can answer right from the card.", Callback = function()
			TingUI:Notify({ Title = "builderman", Content = "gg, want to run it back?", Type = "Message",
				Input = { Placeholder = "Reply...", Button = "Send", Callback = function(text) TingUI:Notify({ Title = "Sent", Content = text, Type = "Success" }) end } })
		end }):AddSubButton({ Text = "Achievement", Description = "A gold card with a spin-in star, sparks and a double shine.", Callback = function()
			TingUI:Notify({ Title = "Achievement unlocked", Content = "Opened every tab.", Type = "Achievement", Duration = 6 })
		end })
		tests:AddButton({ Text = "Details + copy", Description = "An error with the full details tucked away and a copy button.", Callback = function()
			TingUI:Notify({ Title = "Request failed", Content = "The server answered 503.", Type = "Error", Duration = 10,
				Details = "POST /api/v1/sync\nstatus: 503 Service Unavailable\nretry-after: 30\nrequest-id: 7f3c-91aa-02de", Copy = "request-id: 7f3c-91aa-02de" })
		end }):AddSubButton({ Text = "Merge x3", Description = "The same notification three times becomes one card with a counter.", Callback = function()
			for i = 1, 3 do task.delay((i - 1) * 0.35, function() TingUI:Notify({ Title = "Player joined", Content = "The server is filling up.", Type = "Friend" }) end) end
		end })
		tests:AddButton({ Text = "More kinds", Description = "Security, Update, Heart and Upload, each with its own animation.", Callback = function()
			TingUI:Notify({ Title = "New login", Content = "Your account was used on a new device.", Type = "Security", Actions = { { Text = "It was me", Style = "Primary" }, { Text = "Secure it", Style = "Danger" } } })
			task.delay(0.25, function() TingUI:Notify({ Title = "Update ready", Content = "Restart to apply.", Type = "Update" }) end)
			task.delay(0.5, function() TingUI:Notify({ Title = "Liked", Content = "Someone liked your build.", Type = "Heart" }) end)
			task.delay(0.75, function() TingUI:Notify({ Title = "Uploading", Content = "Saving your config to the cloud...", Type = "Upload", Value = 0.4 }) end)
		end }):AddSubButton({ Text = "History", Description = "Every notification so far, newest first.", Callback = function()
			TingUI:OpenNotificationCenter()
		end })
		tests:AddButton({ Text = "With actions", Description = "A notification with buttons inside it.", Callback = function()
			TingUI:Notify({ Title = "Config changed", Content = "You switched to a new theme.", Type = "Info", Duration = 8,
				Actions = {
					{ Text = "Undo", Callback = function() TingUI:ApplyPreset("Lavender") end },
					{ Text = "Keep", Callback = function() end },
				} })
		end }):AddSubButton({ Text = "Script error", Description = "Shows what happens when a feature's code crashes.", Callback = function()
			error("this is a test error")
		end })
		tests:AddButton({ Text = "Test confirmation", Callback = function()
			TingUI:Confirm({
				Title = "Run the confirmation test?", Type = "Warning", Confirm = "Confirm", Hold = 1,
				Text = "This is how confirmations look. Hold the button for a second to confirm, or press Esc to cancel.",
				Callback = function(ok)
					TingUI:Notify({ Title = ok and "Confirmed" or "Cancelled", Content = ok and "You held it. Nicely done." or "Nothing happened.",
						Type = ok and "Success" or "Info" })
				end,
			})
		end })

		local cfg = tab:AddGroup("Configs", "Right")
		local nameInput = cfg:AddInput({ Text = "Config name", Placeholder = "my-config", Realtime = true })
		local list = cfg:AddDropdown({ Text = "Saved configs", Values = TingUI:ListConfigs() })
		local autoLabel = cfg:AddLabel("Autoload: " .. (TingUI:GetAutoload() or "none"), { Dim = true })

		local function Refresh()
			list:SetValues(TingUI:ListConfigs())
			autoLabel:SetText("Autoload: " .. (TingUI:GetAutoload() or "none"))
		end
		local function Result(ok, err, good)
			TingUI:Notify({ Title = "Config", Content = ok and good or tostring(err), Type = ok and "Success" or "Danger" })
		end

		-- one card per action: it spins while the file is written or read, then turns into the result
		local function Progress(busy, ok, err, good)
			local card = TingUI:Notify({ Title = "Config", Content = busy, Type = "Loading" })
			task.delay(0.35, function()
				card:Update({ Title = "Config", Content = ok and good or tostring(err), Type = ok and "Success" or "Danger", Duration = 4 })
			end)
		end

		cfg:AddButton({ Text = "Create / Save", Callback = function()
			local n = nameInput.Value
			if n == "" then n = list.Value or "" end
			local ok, err = TingUI:SaveConfig(n)
			if n:gsub("%s", "") == "" then Result(ok, err) else Progress("Saving '" .. n .. "'...", ok, err, "Saved '" .. n .. "'.") end
			Refresh()
		end }):AddSubButton({ Text = "Load", Callback = function()
			if not list.Value then return Result(false, "Select a config first") end
			local n = list.Value
			local ok, err = TingUI:LoadConfig(n)
			Progress("Loading '" .. n .. "'...", ok, err, "Loaded '" .. n .. "'.")
			SyncPickers()
		end })
		cfg:AddButton({ Text = "Set autoload", Callback = function()
			if not list.Value then return Result(false, "Select a config first") end
			local n = list.Value
			local ok = TingUI:SetAutoload(n) ~= false
			Progress("Setting '" .. n .. "' as autoload...", ok, "Autoload could not be saved.", "'" .. n .. "' will load automatically.")
			Refresh()
		end }):AddSubButton({ Text = "Delete", Callback = function()
			if not list.Value then return Result(false, "Select a config first") end
			local n = list.Value
			TingUI:Confirm({
				Title = "Delete '" .. n .. "'?", Type = "Danger", Confirm = "Delete",
				Text = "The saved config is removed. This cannot be undone.",
				OnConfirm = function()
					local ok, err = TingUI:DeleteConfig(n)
					Result(ok, err, "Deleted '" .. n .. "'.")
					Refresh()
				end,
			})
		end })
		if not CanFile() then
			cfg:AddLabel("Configs are kept in memory here, so they reset when you leave.", { Dim = true })
		end
		if copts and copts.Credits then
			local cr = tab:AddGroup("Credits", "Right")
			cr:AddCredits(copts.Credits)
		end
		return tab
	end

	table.insert(TingUI.Windows, W)
	W.SinkMenuKey = o.SinkMenuKey ~= false
	TingUI:_SinkMenuKeys()
	if o.Dock ~= false then TingUI:_InitDock(W, type(o.Dock) == "table" and o.Dock or nil) end

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
	-- join the Shell now rather than on its next beat, so a member's dock never flashes up
	pcall(self._ShellTick, self)
	self:_ShellNudgeAll()
	return W
end

------------------------------------------------------------------------------
-- Global input
------------------------------------------------------------------------------

Connect(UIS.InputBegan, function(input, gp)
	-- binding a key
	if TingUI._binding then
		local K = TingUI._binding
		if input.UserInputType == Enum.UserInputType.Keyboard then
			TingUI._binding = nil
			K:SetKey(input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode or nil)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
			TingUI._binding = nil
			K:SetKey(input.UserInputType)
		elseif IsPress(input) then
			TingUI._binding = nil
			K:_Render()
		end
		return
	end


	-- command palette: Escape / arrows while open, Ctrl+K to toggle
	if TingUI:_PaletteKey(input.KeyCode) then return end
	if TingUI.Shortcuts and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.K
		and (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then
		-- a Shell member leaves Ctrl+K to the host (which hears it too), unless the host turned its shortcuts off
		local host = TingUI:_ShellHostFor()
		if not host then
			TingUI:TogglePalette()
		elseif host.Shortcuts == false then
			pcall(host.TogglePalette, host)
		end
		return
	end

	if UIS:GetFocusedTextBox() then return end
	if TingUI.Shortcuts and input.KeyCode == Enum.KeyCode.Tab and (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then
		for _, w in ipairs(TingUI.Windows) do
			if w.Visible then
				w:CycleTab((UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)) and -1 or 1)
				return
			end
		end
	end
	local mouseBtn = input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3
	if mouseBtn and gp then return end

	for _, w in ipairs(TingUI.Windows) do
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

-- Menu keys never reach the game. Roblox's shift lock (and anything else bound through ContextActionService) listens
-- to LeftShift and RightShift too, so toggling the menu with a shift key used to flip shift lock as well. A
-- high-priority action on the menu keys sinks them before the game sees them; the menu still toggles normally.
-- Opt out per window with CreateWindow({SinkMenuKey = false}).
function TingUI:_SinkMenuKeys()
	local CAS = Service("ContextActionService")
	local name = "TingUIMenuKeySink_" .. self.Id
	pcall(function() CAS:UnbindAction(name) end)
	if self.Unloaded then return end
	local keys, seen = {}, {}
	for _, w in ipairs(self.Windows) do
		local k = w.MenuKey
		if w.SinkMenuKey ~= false and typeof(k) == "EnumItem" and k.EnumType == Enum.KeyCode and not seen[k] then
			seen[k] = true
			table.insert(keys, k)
		end
	end
	if #keys == 0 then return end
	pcall(function()
		CAS:BindActionAtPriority(name, function() return Enum.ContextActionResult.Sink end, false,
			Enum.ContextActionPriority.High.Value + 100, table.unpack(keys))
	end)
end

function TingUI:Unload()
	if self.Unloaded then return end
	-- handlers run synchronously here so your clean-up (restoring lighting, camera, etc.) happens before the UI goes away
	for _, h in ipairs(self.Events.Unloading._h) do
		if h.Connected then
			local ok, err = pcall(h.Fn)
			if not ok then warn("[TingUI] Unloading handler error: " .. tostring(err)) end
		end
	end
	if self.OnUnload then pcall(self.OnUnload) end
	self.Unloaded = true
	self:_SinkMenuKeys()
	for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
	if BlurEffect then pcall(function() BlurEffect:Destroy() end) end
	Gui:Destroy()
	if env.TingUIInstances and env.TingUIInstances[self.Id] == self then env.TingUIInstances[self.Id] = nil end
	if env.TingUI == self then env.TingUI = nil end
	-- the rest of the Shell re-arranges itself straight away (a new host takes over the taskbar if this was it)
	if self._ShellNudgeAll then pcall(self._ShellNudgeAll, self) end
end

------------------------------------------------------------------------------
-- Integration API: flags, HTTP, clipboard, and extending the library from your own script
------------------------------------------------------------------------------

function TingUI:GetFlag(flag) return self.Flags[flag] end

-- sets an option by flag (updates its control and fires its callback); unknown flags are just stored
function TingUI:SetFlag(flag, value)
	local o = self.Options[flag]
	if o and o.Set then o:Set(value) else self.Flags[flag] = value self.Events.FlagChanged:Fire(flag, value) end
end

function TingUI:OnFlagChanged(flag, fn)
	return self.Events.FlagChanged:Connect(function(f, v) if f == flag then fn(v) end end)
end

-- HTTP through whichever request function the executor provides (request, http_request, syn.request, ...).
-- opts: {Url, Method = "GET", Headers = {}, Body = string}. Returns the response table, or nil + error.
-- What this environment can do, worked out once at load. Scripts can adapt to it (warn that configs won't save, skip a
-- feature the executor lacks), and it's the first thing to paste into a bug report.
do
	local function has(f) return type(f) == "function" end
	local name, version
	if has(identifyexecutor) then
		pcall(function() name, version = identifyexecutor() end)
	elseif has(getexecutorname) then
		pcall(function() name = getexecutorname() end)
	end
	TingUI.Environment = {
		Executor = type(name) == "string" and name or nil,
		ExecutorVersion = version ~= nil and tostring(version) or nil,
		Files = has(writefile) and has(readfile) and has(isfile) and has(isfolder) and has(makefolder) and has(listfiles),
		CustomAssets = has(getcustomasset),
		Clipboard = has(setclipboard) or has(toclipboard) or has(set_clipboard),
		Http = has(request) or has(http_request) or (type(syn) == "table" and has(syn.request))
			or (type(http) == "table" and has(http.request)) or (type(fluxus) == "table" and has(fluxus.request)),
		HiddenGui = has(gethui),
		Studio = RunService:IsStudio(),
		Version = "0.0.8",
	}
end

function TingUI:Request(opts)
	local fn = (type(request) == "function" and request) or (type(http_request) == "function" and http_request)
		or (syn and type(syn.request) == "function" and syn.request) or (http and type(http.request) == "function" and http.request)
		or (fluxus and type(fluxus.request) == "function" and fluxus.request)
	if not fn then return nil, "this executor has no HTTP request function" end
	local ok, res = pcall(fn, opts)
	if not ok then return nil, tostring(res) end
	return res
end

-- copy text to the clipboard; returns true when the executor supports it
function TingUI:Clipboard(text)
	local fn = (type(setclipboard) == "function" and setclipboard) or (type(toclipboard) == "function" and toclipboard)
		or (type(set_clipboard) == "function" and set_clipboard)
	if not fn then return false end
	return (pcall(fn, tostring(text)))
end

-- Add your own element type. builder(group, options, api) builds it inside group and returns an object.
-- After TingUI:RegisterElement("Stepper", fn) every group has group:AddStepper({...}).
function TingUI:RegisterElement(name, builder)
	assert(type(name) == "string" and type(builder) == "function", "RegisterElement(name, function(group, options, api) ... end)")
	Elements["Add" .. name] = function(group, o) return builder(group, o or {}, self.API) end
end

-- Add your own theme. def = colour keys (Accent, Background, ...) plus an optional Style table. It appears in the config dropdown.
function TingUI:RegisterTheme(name, def, description)
	assert(type(name) == "string" and type(def) == "table", "RegisterTheme(name, {Accent = ..., Style = {...}})")
	self.Presets[name] = def
	if description and self._presetDescriptions then self._presetDescriptions[name] = description end
	self:_RefreshPresetLists()
end

------------------------------------------------------------------------------
-- Theme share codes and saved themes
------------------------------------------------------------------------------
-- A share code is "TUI1:" followed by base64 of a small JSON document: {v = 1, n = name, d = description,
-- c = {Accent = "rrggbb", ...}, s = {Radius = 1.2, ...}}. Codes are data only. Every key is checked against a list
-- of known keys with types and ranges; particles, scenes and fonts must already exist here; images must be built-in
-- texture names or rbxassetid:// ids; and nothing in a code is ever run. That makes codes from strangers safe to paste.
do local function Setup()
	local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local Rev = {}
	for i = 1, 64 do Rev[B64:byte(i)] = i - 1 end
	local function Encode64(str)
		local out = {}
		for i = 1, #str, 3 do
			local a, b, c = str:byte(i, i + 2)
			local n = a * 65536 + (b or 0) * 256 + (c or 0)
			local i1, i2, i3, i4 = math.floor(n / 262144) % 64, math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64
			out[#out + 1] = B64:sub(i1 + 1, i1 + 1) .. B64:sub(i2 + 1, i2 + 1)
				.. (b and B64:sub(i3 + 1, i3 + 1) or "=") .. (c and B64:sub(i4 + 1, i4 + 1) or "=")
		end
		return table.concat(out)
	end
	local function Decode64(str)
		str = str:gsub("[^%w%+/=]", "")
		if #str == 0 or #str % 4 ~= 0 then return nil end
		local out = {}
		for i = 1, #str, 4 do
			local a, b, c, d = str:byte(i, i + 3)
			local va, vb = Rev[a], Rev[b]
			local vc, vd = c == 61 and 0 or Rev[c], d == 61 and 0 or Rev[d]
			if not (va and vb and vc and vd) then return nil end
			local n = va * 262144 + vb * 4096 + vc * 64 + vd
			out[#out + 1] = string.char(math.floor(n / 65536) % 256)
			if c ~= 61 then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
			if d ~= 61 then out[#out + 1] = string.char(n % 256) end
		end
		return table.concat(out)
	end

	-- JSON with sorted keys, so the same theme always gives the same code
	local function Json(v)
		local t = type(v)
		if t == "string" then
			return '"' .. (v:gsub('[%c"\\]', function(ch)
				if ch == '"' then return '\\"' elseif ch == "\\" then return "\\\\" end
				return string.format("\\u%04x", ch:byte())
			end)) .. '"'
		elseif t == "number" then
			if v ~= v or v == math.huge or v == -math.huge then return "0" end
			if v == math.floor(v) and math.abs(v) < 1e9 then return string.format("%d", v) end
			return (string.format("%.4f", v):gsub("0+$", ""):gsub("%.$", ""))
		elseif t == "boolean" then
			return v and "true" or "false"
		elseif t == "table" then
			local parts = {}
			if #v > 0 then
				for _, x in ipairs(v) do parts[#parts + 1] = Json(x) end
				return "[" .. table.concat(parts, ",") .. "]"
			end
			local keys = {}
			for k in pairs(v) do keys[#keys + 1] = tostring(k) end
			table.sort(keys)
			for _, k in ipairs(keys) do parts[#parts + 1] = Json(k) .. ":" .. Json(v[k]) end
			return "{" .. table.concat(parts, ",") .. "}"
		end
		return "null"
	end

	local function Hex(c) return c:ToHex():lower() end
	local function FromHex(s)
		local h = type(s) == "string" and s:match("^#?(%x%x%x%x%x%x)$")
		if not h then return nil end
		return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16))
	end
	local function CleanText(s, max)
		if type(s) ~= "string" then return "" end
		s = s:gsub("[%c<>]", ""):gsub("^%s+", ""):gsub("%s+$", "")
		return s:sub(1, max)
	end
	local function CleanName(s)
		local n = CleanText(s, 32)
		return n ~= "" and n or "Imported theme"
	end
	TingUI._CleanThemeName = CleanName

	-- what a code may carry
	local THEME_KEYS = {}
	for k in pairs(TingUI.Theme) do THEME_KEYS[k] = true end
	local BASE = { "Accent", "Background", "Group", "GroupBorder", "Control", "ControlHover", "Border", "Outline", "Text", "Label", "TextDim", "TextMuted" }
	local STATUS = {}
	for _, k in ipairs({ "Success", "Warning", "Danger", "Info", "Caution", "Error" }) do STATUS[k] = TingUI.Theme[k] end
	local BuiltIn = {}
	for n in pairs(TingUI.Presets) do BuiltIn[n] = true end
	TingUI._builtInThemes = BuiltIn

	local NUM, BOOL, COLOR, COLORS, ENUM, FONT, PARTICLES, SCENE, LAYERS, LAYER, FREE = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
	local STYLE = {
		Radius = { NUM, 0, 4 }, Glow = { NUM, 0, 3 }, TextScale = { NUM, 0.7, 1.4 }, Font = { FONT },
		Particles = { PARTICLES }, ParticleColor = { COLOR }, Tint = { COLOR }, TintAmount = { NUM, 0, 1 },
		TintPlace = { ENUM, { Top = true, Bottom = true, Aurora = true } }, TopLine = { COLORS, 2 }, Scanlines = { BOOL },
		Aura = { COLORS, 12 }, AuraSpeed = { NUM, 0, 3 }, AuraThickness = { NUM, 0, 6 }, AuraHard = { BOOL },
		AuraRotation = { NUM, -360, 360 }, InnerLine = { COLOR }, AccentGradient = { COLORS, 2 }, AccentCycle = { BOOL },
		CycleSpeed = { NUM, 0, 3 }, Lightning = { BOOL }, Grid = { BOOL }, GridColor = { COLOR }, Vignette = { BOOL },
		SurfaceTransparency = { NUM, 0, 0.9 }, Blur = { NUM, 0, 40 }, Glitch = { BOOL }, Texture = { LAYERS, 4 },
		BackdropTexture = { LAYER }, Scene = { SCENE },
	}
	local LAYER_KEYS = {
		Transparency = { NUM, 0, 1 }, Drift = { NUM, -1, 1 }, Zoom = { NUM, 0.05, 10 }, Pulse = { NUM, 0, 1 },
		Color = { COLOR }, Mode = { ENUM, { Fill = true, Lamp = true } }, Flicker = { BOOL },
	}
	-- keys a custom scene reads (FireflyColor, GlowColors, Density, ...): colours, colour lists, numbers, true/false
	local function Spec(k)
		if STYLE[k] then return STYLE[k] end
		if type(k) ~= "string" or #k > 32 or not k:match("^%u%w*$") then return nil end
		if k:match("Colors$") then return { COLORS, 12 } end
		if k:match("Color$") then return { COLOR } end
		return { FREE }
	end
	local function ValidFont(v)
		if type(v) ~= "string" or #v > 40 or not v:match("^%a%w*$") then return false end
		if v == "Inter" or v == "Gotham" or v == "Mono" then return true end
		local ok, e = pcall(function() return Enum.Font[v] end)
		return ok and e ~= nil
	end
	local function ValidImage(v)
		return type(v) == "string" and (v:match("^rbxassetid://%d+$") ~= nil or (#v <= 24 and v:match("^%a[%w_]*$") ~= nil))
	end

	-- Lua value -> code data
	local Out
	local function OutLayer(l)
		if type(l) ~= "table" or not ValidImage(l.Image) then return nil end
		local d = { Image = l.Image }
		for k, sp in pairs(LAYER_KEYS) do
			if l[k] ~= nil then d[k] = Out(sp, l[k]) end
		end
		return d
	end
	function Out(sp, v)
		local kind = sp[1]
		if kind == COLOR then return typeof(v) == "Color3" and Hex(v) or nil end
		if kind == COLORS then
			if type(v) ~= "table" then return nil end
			local list = {}
			for i, c in ipairs(v) do
				if i > sp[2] or typeof(c) ~= "Color3" then break end
				list[i] = Hex(c)
			end
			return #list > 0 and list or nil
		end
		if kind == LAYER then return OutLayer(v) end
		if kind == LAYERS then
			if type(v) ~= "table" then return nil end
			local list = {}
			for _, l in ipairs(v) do
				local d = #list < sp[2] and OutLayer(l)
				if d then list[#list + 1] = d end
			end
			return #list > 0 and list or nil
		end
		if kind == NUM then return type(v) == "number" and v or nil end
		if kind == BOOL then return v == true or nil end
		if kind == FREE then return (type(v) == "number" or type(v) == "boolean") and v or nil end
		return type(v) == "string" and v or nil
	end

	-- code data -> Lua value, or nil when it doesn't belong
	local In
	local function InLayer(d)
		if type(d) ~= "table" or not ValidImage(d.Image) then return nil end
		local l = { Image = d.Image }
		for k, sp in pairs(LAYER_KEYS) do
			if d[k] ~= nil then l[k] = In(sp, d[k]) end
		end
		return l
	end
	function In(sp, v)
		local kind = sp[1]
		if kind == NUM then
			local n = type(v) == "number" and v or nil
			if not n or n ~= n then return nil end
			return math.clamp(n, sp[2], sp[3])
		elseif kind == FREE then
			if type(v) == "boolean" then return v end
			if type(v) == "number" and v == v then return math.clamp(v, -10000, 10000) end
			return nil
		elseif kind == BOOL then
			return v == true or nil
		elseif kind == COLOR then
			return FromHex(v)
		elseif kind == COLORS then
			if type(v) ~= "table" or #v == 0 then return nil end
			local list = {}
			for i = 1, math.min(#v, sp[2]) do
				local c = FromHex(v[i])
				if not c then return nil end
				list[i] = c
			end
			return list
		elseif kind == ENUM then
			return (type(v) == "string" and sp[2][v]) and v or nil
		elseif kind == FONT then
			return ValidFont(v) and v or nil
		elseif kind == PARTICLES then
			return (type(v) == "string" and v ~= "Theme" and (v == "None" or table.find(TingUI.ParticleKinds, v))) and v or nil
		elseif kind == SCENE then
			return (type(v) == "string" and TingUI.SceneKinds[v] ~= nil) and v or nil
		elseif kind == LAYER then
			return InLayer(v)
		elseif kind == LAYERS then
			if type(v) ~= "table" then return nil end
			local list = {}
			for _, d in ipairs(v) do
				local l = #list < sp[2] and InLayer(d)
				if l then list[#list + 1] = l end
			end
			return #list > 0 and list or nil
		end
		return nil
	end

	-- the colours SetTheme works out by itself; a code only carries them when they were changed by hand
	local function Derived(c)
		local d = {}
		for k, v in pairs(STATUS) do d[k] = v end
		if c.Accent and c.Background then
			d.AccentText = c.Accent:Lerp(Color3.new(1, 1, 1), 0.02)
			d.AccentBorder = c.Accent:Lerp(c.Background, 0.36)
			d.Toggle = c.Accent:Lerp(c.Background, 0.64)
			d.TabActive = c.Accent:Lerp(c.Background, 0.79)
		end
		if c.Control and c.Background then d.Chip = c.Control:Lerp(c.Background, 0.08) end
		if c.TextDim and c.Label then d.ChipText = c.TextDim:Lerp(c.Label, 0.4) end
		return d
	end

	-- full = a complete live palette (the current look), otherwise a preset definition (only the keys it sets)
	local function Data(colors, style, full)
		local c = {}
		if full then
			for _, k in ipairs(BASE) do
				if typeof(colors[k]) == "Color3" then c[k] = Hex(colors[k]) end
			end
			for k, v in pairs(Derived(colors)) do
				if typeof(colors[k]) == "Color3" and Hex(colors[k]) ~= Hex(v) then c[k] = Hex(colors[k]) end
			end
		else
			for k, v in pairs(colors) do
				if THEME_KEYS[k] and typeof(v) == "Color3" then c[k] = Hex(v) end
			end
		end
		-- the same defaults SetStyle fills in, so a preset and the look it produces export identically
		local st = { Radius = 1, Glow = 1, TextScale = 1, Particles = "Snow", ParticleColor = Color3.new(1, 1, 1) }
		for k, v in pairs(style or {}) do st[k] = v end
		local s = {}
		for k, v in pairs(st) do
			local sp = Spec(k)
			if sp then
				local o = Out(sp, v)
				if o ~= nil then s[k] = o end
			end
		end
		return c, s
	end
	local function Fingerprint(colors, style)
		local c, s = Data(colors, style, false)
		return Json({ c = c, s = s })
	end

	-- the current look (no argument), or a theme by name. meta = {Name, Description} labels the code.
	function TingUI:ExportTheme(preset, meta)
		if type(preset) == "table" then preset, meta = nil, preset end
		meta = type(meta) == "table" and meta or {}
		local c, s, name
		if preset ~= nil then
			name = PresetName(preset)
			local p = self.Presets[name]
			if not p then return nil, "There's no theme called '" .. tostring(preset) .. "'" end
			c, s = Data(p, p.Style, false)
		else
			name = self.Preset
			c, s = Data(self._themeTarget or self.Theme, self.Style, true)
		end
		local doc = { v = 1, n = CleanName(meta.Name or name), c = c, s = s }
		local desc = meta.Description
		if desc == nil and not BuiltIn[name] and self._presetDescriptions then desc = self._presetDescriptions[name] end
		desc = CleanText(desc, 120)
		if desc ~= "" then doc.d = desc end
		return "TUI1:" .. Encode64(Json(doc))
	end

	-- read a code without installing it: {Name, Description, Colors, Style, Dropped = {keys that were left out}}
	function TingUI:DecodeTheme(code)
		if type(code) ~= "string" then return nil, "That isn't a theme code" end
		code = code:gsub("%s", "")
		if #code > 12000 then return nil, "That code is too long to be a theme" end
		local body = code:match("^TUI1:(.+)$")
		if not body then return nil, "That isn't a TingUI theme code (they start with TUI1:)" end
		local json = Decode64(body)
		if not json then return nil, "That code is damaged. Copy it again." end
		local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
		if not ok or type(data) ~= "table" then return nil, "That code is damaged. Copy it again." end
		if data.v ~= 1 then return nil, "That code is from a newer TingUI. Update TingUI to use it." end
		local t = { Name = CleanName(data.n), Description = CleanText(data.d, 120), Colors = {}, Style = {}, Dropped = {} }
		local n = 0
		for k, v in pairs(type(data.c) == "table" and data.c or {}) do
			n = n + 1
			local col = THEME_KEYS[k] and n <= 40 and FromHex(v)
			if col then t.Colors[k] = col else table.insert(t.Dropped, tostring(k)) end
		end
		n = 0
		for k, v in pairs(type(data.s) == "table" and data.s or {}) do
			n = n + 1
			local sp = n <= 64 and Spec(k) or nil
			local val = nil
			if sp then val = In(sp, v) end
			if val ~= nil then t.Style[k] = val else table.insert(t.Dropped, tostring(k)) end
		end
		table.sort(t.Dropped)
		return t
	end

	local function Def(t)
		local def = {}
		for k, v in pairs(t.Colors) do def[k] = v end
		def.Style = t.Style
		return def
	end

	function TingUI:_RefreshPresetLists()
		local names = {}
		for n in pairs(self.Presets) do table.insert(names, PresetLabel(n)) end
		table.sort(names, function(x, y)
			if x == "Lavender (Default)" then return true elseif y == "Lavender (Default)" then return false end
			return x < y
		end)
		for _, d in ipairs(self._presetDropdowns) do pcall(function() d:SetValues(names, true) end) end
		for _, fn in ipairs(self._themeListeners or {}) do pcall(fn, names) end
		return names
	end

	-- install a code: it's checked, registered as a theme, saved with your themes and applied.
	-- opts: a name, or {Name, Save = true, Apply = true}. Returns the theme's name, or nil and a message.
	-- A code for an untouched built-in theme just uses that theme; an edited one is installed as "<name> (custom)".
	local Saved, Loaded = {}, false
	local function ThemeDir() return tostring(TingUI.ThemeFolder) end
	local function FileName(name) return (tostring(name):gsub("[^%w%-_ %(%)]", "_")) end
	function TingUI:ImportTheme(code, opts)
		if type(opts) == "string" then opts = { Name = opts } end
		opts = type(opts) == "table" and opts or {}
		local t, err = self:DecodeTheme(code)
		if not t then return nil, err end
		local name = opts.Name ~= nil and CleanName(opts.Name) or t.Name
		local def = Def(t)
		if BuiltIn[name] and self.Presets[name] then
			if Fingerprint(def, def.Style) == Fingerprint(self.Presets[name], self.Presets[name].Style) then
				if opts.Apply ~= false then self:ApplyPreset(name) end
				return name
			end
			name = name .. " (custom)"
		end
		self:RegisterTheme(name, def, t.Description ~= "" and t.Description or nil)
		local saveErr
		if opts.Save ~= false then
			local ok, e = self:SaveTheme(name)
			if not ok then saveErr = e end
		end
		if opts.Apply ~= false then self:ApplyPreset(name) end
		return name, saveErr
	end

	-- your themes live in <ThemeFolder>/<name>.tui (TingUI/themes, shared by every script), through the same storage as configs
	function TingUI:SaveTheme(name)
		name = PresetName(tostring(name or ""))
		if not self.Presets[name] then return false, "There's no theme called '" .. name .. "'" end
		if BuiltIn[name] then return false, name .. " is built in, so it's always there. Save a copy under a new name." end
		local key = ThemeDir() .. "/" .. FileName(name) .. ".tui"
		local ok, err = StorageCall("Write", key, self:ExportTheme(name))
		if not ok then return false, err end
		Saved[name] = key
		return true
	end

	function TingUI:_LoadSavedThemes(force)
		if Loaded and not force then return end
		Loaded = true
		local ok, list = StorageCall("List", ThemeDir())
		if not ok or type(list) ~= "table" then return end
		for _, p in ipairs(list) do
			local file = tostring(p):match("([^/\\]+)%.tui$")
			if file then
				local key = ThemeDir() .. "/" .. file .. ".tui"
				local okR, code = StorageCall("Read", key)
				local t = okR and type(code) == "string" and self:DecodeTheme(code)
				if t and not BuiltIn[t.Name] then
					if not self.Presets[t.Name] then self:RegisterTheme(t.Name, Def(t), t.Description ~= "" and t.Description or nil) end
					Saved[t.Name] = key
				end
			end
		end
	end

	function TingUI:ListSavedThemes()
		self:_LoadSavedThemes(true)
		local out = {}
		for n in pairs(Saved) do table.insert(out, n) end
		table.sort(out)
		return out
	end

	function TingUI:DeleteTheme(name)
		name = PresetName(tostring(name or ""))
		if BuiltIn[name] then return false, "Built-in themes can't be deleted" end
		self:_LoadSavedThemes()
		local ok, err = StorageCall("Delete", Saved[name] or (ThemeDir() .. "/" .. FileName(name) .. ".tui"))
		if not ok then return false, err end
		Saved[name] = nil
		-- the theme in use stays until you pick another
		if self.Presets[name] and name ~= self.Preset then
			self.Presets[name] = nil
			self:_RefreshPresetLists()
		end
		return true
	end

	-- fg moved toward white or black (whichever reads better on bg) until it reaches the contrast ratio
	function TingUI.Readable(fg, bg, ratio)
		ratio = ratio or 4.5
		if Contrast(fg, bg) >= ratio then return fg end
		local white, black = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
		local toward = Contrast(white, bg) >= Contrast(black, bg) and white or black
		for i = 1, 20 do
			local c = fg:Lerp(toward, i / 20)
			if Contrast(c, bg) >= ratio then return c end
		end
		return toward
	end
end Setup() end

-- Add your own icon. draw(frame, size, colorKey, helpers): helpers.Seg(x1, y1, x2, y2, thickness) and helpers.Dot(x, y, d)
-- draw in a 16x16 grid. Works everywhere icons do (groups, dock buttons, panel headers).
function TingUI:RegisterIcon(name, draw)
	assert(type(name) == "string" and type(draw) == "function", "RegisterIcon(name, function(frame, size, colorKey, helpers) ... end)")
	CustomIcons[name] = draw
end

-- Building blocks for custom elements, so they match the theme and work with flags, configs, hints and the palette.
TingUI.Elements = Elements
TingUI.API = {
	New = New, Corner = Corner, Stroke = Stroke, Pad = Pad, List = List, Row = Row, Tween = Tween, Glow = Glow, Icon = Icon,
	NewOption = NewOpt, Register = Register, Fire = Fire, Connect = Connect, Describe = AttachHint, Catalog = CatalogAdd,
	AccentOverlay = AccentOverlay, SafeCall = SafeCall, Theme = TingUI.Theme, Gui = Gui, Overlay = Overlay,
	ShowPopup = ShowPopup, ClosePopup = ClosePopup, Dragger = Dragger,
}

------------------------------------------------------------------------------
-- Theme Studio: edit every part of the theme live, check readability, save and share it
------------------------------------------------------------------------------
-- The studio is an ordinary TingUI window, so it previews every edit on itself as well as on your own windows.
-- It edits a draft (the twelve base colours, the status colours and the whole style) and pushes it to SetTheme and
-- SetStyle a few times a second while you drag. A theme change from anywhere else reloads the draft.
TingUI.FontNames = { "Inter", "Gotham", "Mono", "Michroma", "Jura", "Merriweather", "FredokaOne", "Arcade", "TitilliumWeb", "Oswald", "Ubuntu",
	"Nunito", "SourceSans", "PatrickHand", "SpecialElite", "Sarpanch", "Creepster", "Fondamento", "RobotoCondensed", "Cartoon", "JosefinSans", "Arial" }
do local function Setup()
	local BASE = { "Accent", "Background", "Group", "GroupBorder", "Control", "ControlHover", "Border", "Outline", "Text", "Label", "TextDim", "TextMuted" }
	local STATUS = { "Success", "Warning", "Danger", "Info", "Caution", "Error" }
	local St = { Sync = {} }
	TingUI._Studio = St

	local function Copy(v)
		if type(v) ~= "table" or getmetatable(v) ~= nil then return v end
		local o = {}
		for k, x in pairs(v) do o[k] = Copy(x) end
		return o
	end

	-- the draft starts as whatever is on screen
	local function Load()
		local T = TingUI._themeTarget or TingUI.Theme
		local c = {}
		for _, k in ipairs(BASE) do c[k] = T[k] end
		for _, k in ipairs(STATUS) do c[k] = T[k] end
		St.Draft = { Colors = c, Style = Copy(TingUI.Style) }
		if TingUI.Style.Texture or TingUI.Style.BackdropTexture then
			St.Textures = { Texture = Copy(TingUI.Style.Texture), BackdropTexture = Copy(TingUI.Style.BackdropTexture) }
		end
	end

	local function Resync()
		St.Syncing = true
		for _, fn in ipairs(St.Sync) do pcall(fn) end
		St.Syncing = false
		if St.RefreshChecks then St.RefreshChecks() end
	end

	local function Flush()
		St.Pending = false
		if TingUI.Unloaded or not St.Draft or not (St.DirtyC or St.DirtyS) then return end
		St.Applying = true
		if St.DirtyC then pcall(TingUI.SetTheme, TingUI, table.clone(St.Draft.Colors), 0) end
		if St.DirtyS then pcall(TingUI.SetStyle, TingUI, Copy(St.Draft.Style), 0) end
		St.Applying = false
		St.DirtyC, St.DirtyS = false, false
		for _, fn in ipairs(TingUI._pickerSyncers or {}) do pcall(fn) end
		if St.RefreshChecks then St.RefreshChecks() end
	end
	-- edits land a moment later, so dragging a slider or a colour costs a handful of repaints, not one per pixel
	local function Push(colors, style)
		St.DirtyC = St.DirtyC or colors
		St.DirtyS = St.DirtyS or style
		if St.Pending then return end
		St.Pending = true
		task.delay(0.08, function() if St.Pending then Flush() end end)
	end
	St.Push, St.Load, St.Resync = Push, Load, Resync

	local function External()
		if St.Applying or not St.Window or St.ReloadPending then return end
		St.ReloadPending = true
		task.delay(0.05, function()
			St.ReloadPending = false
			if St.Applying or TingUI.Unloaded or not St.Window then return end
			Load()
			Resync()
			if St.OnExternal then St.OnExternal() end
		end)
	end
	TingUI.Events.ThemeChanged:Connect(External)
	TingUI.Events.StyleChanged:Connect(External)

	local function Sync(fn) table.insert(St.Sync, fn) end
	local function Quiet(fn) return function(...) if not St.Syncing then fn(...) end end end

	-- controls, each bound to one part of the draft
	local function ThemeColor(g, key, label, desc)
		local l = g:AddLabel({ Text = label, Description = desc })
		local pk = l:AddColorPicker({ Default = St.Draft.Colors[key], Title = label, Callback = Quiet(function(c)
			St.Draft.Colors[key] = c
			Push(true, false)
		end) })
		Sync(function() if St.Draft.Colors[key] then pk:Set(St.Draft.Colors[key], true) end end)
		return l
	end
	local function StyleColor(g, key, label, desc, fallback)
		local l = g:AddLabel({ Text = label, Description = desc })
		local pk = l:AddColorPicker({ Default = St.Draft.Style[key] or fallback(), Title = label, Callback = Quiet(function(c)
			St.Draft.Style[key] = c
			Push(false, true)
		end) })
		Sync(function() pk:Set(St.Draft.Style[key] or fallback(), true) end)
		return l
	end
	local function Slider(g, key, text, min, max, inc, def, desc, suffix)
		local function Now() return math.clamp(tonumber(St.Draft.Style[key]) or def, min, max) end
		local s = g:AddSlider({ Text = text, Min = min, Max = max, Increment = inc, Suffix = suffix, Description = desc, Default = Now(),
			Callback = Quiet(function(v)
				St.Draft.Style[key] = v
				Push(false, true)
			end) })
		Sync(function() s:Set(Now(), true) end)
		return s
	end
	local function Flag(g, key, text, desc, after)
		local t = g:AddToggle({ Text = text, Description = desc, Default = St.Draft.Style[key] == true, Callback = Quiet(function(v)
			St.Draft.Style[key] = v or nil
			if after then after(v) end
			Push(false, true)
		end) })
		Sync(function() t:Set(St.Draft.Style[key] == true, true) end)
		return t
	end
	-- on/off plus a colour: the style key holds the colour while it's on (Tint, InnerLine, TraceColor, ...)
	local function ColorFlag(g, key, text, desc, fallback, flagKey)
		local last = St.Draft.Style[key] or fallback()
		local function IsOn() if flagKey then return St.Draft.Style[flagKey] == true end return St.Draft.Style[key] ~= nil end
		local t
		t = g:AddToggle({ Text = text, Description = desc, Default = IsOn(), Callback = Quiet(function(v)
			if flagKey then
				St.Draft.Style[flagKey] = v or nil
				St.Draft.Style[key] = last
			else
				St.Draft.Style[key] = v and last or nil
			end
			Push(false, true)
		end) })
		local pk = t:AddColorPicker({ Default = last, Title = text, Callback = Quiet(function(c)
			last = c
			St.Draft.Style[key] = c
			if flagKey then St.Draft.Style[flagKey] = true end
			t:Set(true, true)
			Push(false, true)
		end) })
		Sync(function()
			local v = St.Draft.Style[key]
			last = typeof(v) == "Color3" and v or fallback()
			pk:Set(last, true)
			t:Set(IsOn(), true)
		end)
		return t
	end
	-- on/off plus n colours (TopLine, AccentGradient, Aura, JellyColors); loop repeats the first so a turning border is seamless
	local function ColorList(g, key, text, desc, n, loop, fallback)
		local cols = {}
		local function Read()
			local v = St.Draft.Style[key]
			local src = type(v) == "table" and v or fallback()
			for i = 1, n do cols[i] = typeof(src[i]) == "Color3" and src[i] or cols[i] or src[1] or Color3.new(1, 1, 1) end
		end
		local function Write()
			local list = {}
			for i = 1, n do list[i] = cols[i] end
			if loop then list[n + 1] = cols[1] end
			St.Draft.Style[key] = list
		end
		Read()
		local t
		t = g:AddToggle({ Text = text, Description = desc, Default = St.Draft.Style[key] ~= nil, Callback = Quiet(function(v)
			if v then Write() else St.Draft.Style[key] = nil end
			Push(false, true)
		end) })
		local pks = {}
		for i = 1, n do
			pks[i] = t:AddColorPicker({ Default = cols[i], Title = text .. " " .. i, Callback = Quiet(function(c)
				cols[i] = c
				Write()
				t:Set(true, true)
				Push(false, true)
			end) })
		end
		Sync(function()
			Read()
			for i = 1, n do pks[i]:Set(cols[i], true) end
			t:Set(St.Draft.Style[key] ~= nil, true)
		end)
		return t
	end
	local function Choice(g, key, text, values, def, desc, after)
		local d = g:AddDropdown({ Text = text, Values = values, Default = St.Draft.Style[key] or def, Description = desc, Callback = Quiet(function(v)
			if v == nil then return end
			St.Draft.Style[key] = v
			if after then after(v) end
			Push(false, true)
		end) })
		Sync(function() d:Set(St.Draft.Style[key] or def, true) end)
		return d
	end

	local function Draft(k) return function() return St.Draft.Colors[k] end end
	local CHECKS = {
		{ "Text", "Background", 4.5, "Text on the window" },
		{ "Label", "Group", 4.5, "Labels on panels" },
		{ "Text", "Control", 4.5, "Text on controls" },
		{ "TextDim", "Group", 3, "Dim text on panels" },
		{ "Accent", "Background", 3, "Accent on the window" },
	}

	local function Build(W)
		-- Colours
		local colours = W:AddTab("Colours")
		local surf = colours:AddGroup({ Title = "Surfaces", Side = "Left", Icon = "window" })
		ThemeColor(surf, "Background", "Window", "The window and every floating panel behind their content.")
		ThemeColor(surf, "Group", "Panels", "The boxes that hold settings.")
		ThemeColor(surf, "GroupBorder", "Panel borders", "The thin line around each box.")
		ThemeColor(surf, "Control", "Controls", "Buttons, inputs and other controls.")
		ThemeColor(surf, "ControlHover", "Controls under the mouse", "A control while the mouse is on it.")
		ThemeColor(surf, "Outline", "Outlines", "Lines around inputs, dropdowns and chips.")
		ThemeColor(surf, "Border", "Borders", "The window's outer border and stronger lines.")
		local status = colours:AddGroup({ Title = "Status colours", Side = "Left" })
		for _, k in ipairs(STATUS) do ThemeColor(status, k, k, "Notifications, badges and warnings of this kind.") end

		local text = colours:AddGroup({ Title = "Text and accent", Side = "Right", Icon = "palette" })
		ThemeColor(text, "Accent", "Accent", "Toggles, sliders, the active tab and highlights. The darker accent shades follow it.")
		ThemeColor(text, "Text", "Text", "Titles and the most important text.")
		ThemeColor(text, "Label", "Labels", "Setting names and most body text.")
		ThemeColor(text, "TextDim", "Dim text", "Inactive tabs, hints and secondary text.")
		ThemeColor(text, "TextMuted", "Faint text", "Placeholders, footers and the faintest text.")

		local read = colours:AddGroup({ Title = "Readability", Side = "Right", Icon = "eye" })
		read:AddLabel("How easy text is to read on its background (contrast ratio). 4.5 to 1 or more reads well; dim text and accents need 3 to 1.", { Dim = true })
		local rows = {}
		for i in ipairs(CHECKS) do rows[i] = read:AddLabel("") end
		St.RefreshChecks = function()
			local T = TingUI.Theme
			for i, c in ipairs(CHECKS) do
				local fg, bg = St.Draft.Colors[c[1]], St.Draft.Colors[c[2]]
				if fg and bg then
					local r = Contrast(fg, bg)
					rows[i]:SetText(string.format("%s: %.1f to 1%s", c[4], r, r >= c[3] and "" or "  (hard to read)"))
					rows[i]:SetColor(r >= c[3] and T.Success or T.Caution)
				end
			end
		end
		read:AddButton({ Text = "Fix contrast", Description = "Moves each colour that fails toward white or black, only as far as it needs to read well.", Callback = function()
			local changed = false
			for _ = 1, 3 do
				local any = false
				for _, c in ipairs(CHECKS) do
					local fg, bg = St.Draft.Colors[c[1]], St.Draft.Colors[c[2]]
					if fg and bg and Contrast(fg, bg) < c[3] then
						St.Draft.Colors[c[1]] = TingUI.Readable(fg, bg, c[3])
						any, changed = true, true
					end
				end
				if not any then break end
			end
			if changed then
				Resync()
				Push(true, false)
				TingUI:Notify({ Title = "Theme Studio", Content = "Contrast fixed. Every check passes now.", Type = "Success" })
			else
				TingUI:Notify({ Title = "Theme Studio", Content = "Everything already reads well.", Type = "Info" })
			end
		end })

		-- Shape
		local shapeTab = W:AddTab("Shape")
		local shape = shapeTab:AddGroup({ Title = "Shape and type", Side = "Left" })
		Slider(shape, "Radius", "Corner roundness", 0, 3, 0.05, 1, "1 is the reference shape, 0 is square, 3 is very round.", "x")
		Slider(shape, "Glow", "Glow", 0, 3, 0.05, 1, "How strongly accents and the active tab glow. 0 turns glow off.", "x")
		Slider(shape, "TextScale", "Text size", 0.8, 1.3, 0.01, 1, "Scales all text. Some fonts read better a little larger or smaller.", "x")
		Choice(shape, "Font", "Font", TingUI.FontNames, TingUI.FontName, "The typeface for the whole UI.")
		Slider(shape, "SurfaceTransparency", "See-through surfaces", 0, 0.8, 0.05, 0, "How much of the game shows through windows and panels. Pairs well with world blur.")
		local borders = shapeTab:AddGroup({ Title = "Borders and light", Side = "Right" })
		ColorList(borders, "Aura", "Turning border", "A gradient border that slowly turns around the window.", 3, true,
			function() return { St.Draft.Colors.Accent, St.Draft.Colors.Border, St.Draft.Colors.Accent } end)
		Slider(borders, "AuraSpeed", "Border speed", 0, 1, 0.01, 0.1, "How fast the turning border turns. 0 holds it still.")
		Slider(borders, "AuraThickness", "Border thickness", 0.5, 4, 0.1, 1, "How thick the turning border is.")
		Flag(borders, "AuraHard", "Hard colour bands", "Sharp stripes instead of a smooth gradient (like Hazard's warning tape).")
		ColorFlag(borders, "InnerLine", "Inner line", "A second, thin border just inside the first.", Draft("Accent"))
		ColorList(borders, "TopLine", "Top light", "A light along the window's top edge that leaks a soft glow downward.", 2, false,
			function() return { St.Draft.Colors.Text, St.Draft.Colors.Accent } end)

		-- Light
		local lightTab = W:AddTab("Light")
		local light = lightTab:AddGroup({ Title = "Window light", Side = "Left" })
		ColorFlag(light, "Tint", "Tint", "Coloured light that washes over the window from one side.", Draft("Accent"))
		Choice(light, "TintPlace", "Tint comes from", { "Top", "Bottom", "Aurora" }, "Top", "Where the tint sits. Aurora drifts across the window.")
		Slider(light, "TintAmount", "Tint strength", 0, 0.5, 0.01, 0.15, "How strong the tint is.")
		Slider(light, "Blur", "World blur", 0, 40, 1, 0, "Blurs the game behind the UI while a window is open.")
		local fx = lightTab:AddGroup({ Title = "Effects", Side = "Right" })
		Flag(fx, "Scanlines", "Scanlines", "Fine CRT-style lines over the window.")
		ColorFlag(fx, "GridColor", "Drafting grid", "A grid over the window, like Blueprint.", Draft("Text"), "Grid")
		Flag(fx, "Vignette", "Dark screen edges", "Darkens the edges of the screen while a window is open.")
		Flag(fx, "Lightning", "Distant lightning", "Flashes now and then behind the UI. Reduced motion turns it off.")
		Flag(fx, "Glitch", "Glitches", "The title and screen glitch for a moment now and then. Reduced motion turns it off.")
		local accent = lightTab:AddGroup({ Title = "Accent", Side = "Right" })
		ColorList(accent, "AccentGradient", "Accent gradient", "Toggles, sliders and progress bars fill with a gradient instead of one colour.", 2, false,
			function() return { St.Draft.Colors.Accent, St.Draft.Colors.Accent:Lerp(St.Draft.Colors.Background, 0.4) } end)
		Flag(accent, "AccentCycle", "Rainbow accent", "The accent slowly cycles through every colour.")
		Slider(accent, "CycleSpeed", "Rainbow speed", 0, 1, 0.01, 0.1, "How fast the rainbow accent cycles.")

		-- Motion
		local motionTab = W:AddTab("Motion")
		local parts = motionTab:AddGroup({ Title = "Particles", Side = "Left" })
		local showParts = parts:AddToggle({ Text = "Show particles", Default = Snow.Enabled,
			Description = "Particles drift behind the UI while a window is open. This is the same switch as in the config tab.",
			Callback = Quiet(function(v) TingUI:SetSnow(v) end) })
		Sync(function() showParts:Set(Snow.Enabled, true) end)
		local kinds = { "None" }
		for _, k in ipairs(TingUI.ParticleKinds) do if k ~= "Theme" then table.insert(kinds, k) end end
		Choice(parts, "Particles", "Particle style", kinds, "Snow", "The particles this theme brings.", function()
			-- the config tab can pin a particle style over the theme's; editing the theme's means showing it
			if Snow.Kind ~= "Theme" then TingUI:SetParticles("Theme") end
		end)
		StyleColor(parts, "ParticleColor", "Particle colour", "The particles' colour.", function() return Color3.new(1, 1, 1) end)
		if St.Textures then
			local tex = motionTab:AddGroup({ Title = "Painted textures", Side = "Left" })
			local tt = tex:AddToggle({ Text = "Textures", Default = St.Draft.Style.Texture ~= nil or St.Draft.Style.BackdropTexture ~= nil,
				Description = "The painted art this theme started with. Share codes carry it when its images are built in or uploaded to Roblox.",
				Callback = Quiet(function(v)
					St.Draft.Style.Texture = v and Copy(St.Textures.Texture) or nil
					St.Draft.Style.BackdropTexture = v and Copy(St.Textures.BackdropTexture) or nil
					Push(false, true)
				end) })
			Sync(function() tt:Set(St.Draft.Style.Texture ~= nil or St.Draft.Style.BackdropTexture ~= nil, true) end)
		end

		local scene = motionTab:AddGroup({ Title = "Scene", Side = "Right" })
		local sceneRows = { Circuit = {}, Ocean = {}, Hologram = {}, Other = {} }
		local function ShowSceneRows()
			local cur = St.Draft.Style.Scene
			local which = cur == nil and "" or (sceneRows[cur] and cur or "Other")
			for k, list in pairs(sceneRows) do
				for _, r in ipairs(list) do r:SetVisible(k == which) end
			end
		end
		local names = { "None" }
		for k in pairs(TingUI.SceneKinds) do table.insert(names, k) end
		table.sort(names, function(a, b) if a == "None" then return true elseif b == "None" then return false end return a < b end)
		local sceneDrop = scene:AddDropdown({ Text = "Scene", Values = names, Default = St.Draft.Style.Scene or "None",
			Description = "Living artwork in and around the window that answers clicks, tab switches and opening.",
			Callback = Quiet(function(v)
				if v == nil then return end
				St.Draft.Style.Scene = v ~= "None" and v or nil
				ShowSceneRows()
				Push(false, true)
			end) })
		Sync(function()
			sceneDrop:Set(St.Draft.Style.Scene or "None", true)
			ShowSceneRows()
		end)
		table.insert(sceneRows.Circuit, ColorFlag(scene, "TraceColor", "Copper traces", "The traces' colour. Off uses the border colour.", Draft("Border")))
		table.insert(sceneRows.Circuit, ColorFlag(scene, "EnergyColor", "Current", "The pulses racing along the traces. Off uses the accent.", Draft("Accent")))
		table.insert(sceneRows.Ocean, ColorFlag(scene, "WaterColor", "Water", "The waves along the bottom and the tide that sweeps over on a theme switch. Off uses the accent.", Draft("Accent")))
		table.insert(sceneRows.Ocean, ColorFlag(scene, "FoamColor", "Foam", "The bright crest on each wave, the ripples and the caustic light. Off uses the text colour.", Draft("Text")))
		table.insert(sceneRows.Hologram, scene:AddLabel("Hologram draws in the accent colour.", { Dim = true }))
		table.insert(sceneRows.Other, scene:AddLabel("This scene reads its own style keys. Set them in code; share codes carry their colours and numbers.", { Dim = true }))
		ShowSceneRows()

		-- Share
		local shareTab = W:AddTab("Share")
		local share = shareTab:AddGroup({ Title = "Save and share", Side = "Left", Icon = "heart" })
		local function DefaultName()
			local p = TingUI.Preset
			if TingUI._builtInThemes[p] then return p .. " remix" end
			return p
		end
		local nameIn = share:AddInput({ Text = "Theme name", Default = DefaultName(), Placeholder = "My theme", MaxLength = 32 })
		local descIn = share:AddInput({ Text = "Description", Placeholder = "One line about it (optional)", MaxLength = 120 })
		local codeBox
		local mineDrop
		local function RefreshMine()
			if mineDrop then pcall(function() mineDrop:SetValues(TingUI:ListSavedThemes(), true) end) end
		end
		share:AddButton({ Text = "Save to my themes", Description = "Adds it to the Preset list and keeps it with your configs.", Callback = function()
			Flush()
			local name = TingUI._CleanThemeName(nameIn.Value)
			if TingUI._builtInThemes[name] then
				return TingUI:Notify({ Title = "Theme Studio", Content = name .. " is a built-in theme. Give yours its own name.", Type = "Warning" })
			end
			local def = {}
			for k, v in pairs(St.Draft.Colors) do def[k] = v end
			def.Style = Copy(St.Draft.Style)
			TingUI:RegisterTheme(name, def, descIn.Value ~= "" and descIn.Value or nil)
			local ok, err = TingUI:SaveTheme(name)
			local fade = TingUI.ThemeTransition
			TingUI.ThemeTransition = 0
			St.Applying = true
			pcall(TingUI.ApplyPreset, TingUI, name)
			St.Applying = false
			TingUI.ThemeTransition = fade
			nameIn:Set(name, true)
			RefreshMine()
			if not ok then
				TingUI:Notify({ Title = "Theme Studio", Content = "'" .. name .. "' is in the Preset list until you leave, but it couldn't be saved: " .. tostring(err), Type = "Warning", Duration = 7 })
			elseif not CanFile() then
				TingUI:Notify({ Title = "Theme Studio", Content = "Saved '" .. name .. "' for this session. This game keeps themes in memory.", Type = "Success" })
			else
				TingUI:Notify({ Title = "Theme Studio", Content = "Saved '" .. name .. "'. It's in the Preset list now.", Type = "Success" })
			end
		end }):AddSubButton({ Text = "Copy share code", Description = "A short code anyone can paste to install this theme.", Callback = function()
			Flush()
			local code = TingUI:ExportTheme({ Name = TingUI._CleanThemeName(nameIn.Value), Description = descIn.Value })
			codeBox:Set(code, true)
			if TingUI:Clipboard(code) then
				TingUI:Notify({ Title = "Share code copied", Content = "Anyone can paste it into their Theme Studio, or call TingUI:ImportTheme(code).", Type = "Success" })
			else
				TingUI:Notify({ Title = "Share code", Content = "Copying isn't supported here, so the code is in the Share code box. Copy it from there.", Type = "Info", Duration = 6 })
			end
		end })
		codeBox = share:AddInput({ Text = "Share code", Placeholder = "Paste a TUI1: code here",
			Description = "Codes only hold colours and settings, never code, so they're safe to paste from anyone." })
		share:AddButton({ Text = "Install code", Description = "Checks the code, adds the theme to your list, saves it and switches to it.", Callback = function()
			local name, err = TingUI:ImportTheme(codeBox.Value)
			if not name then
				return TingUI:Notify({ Title = "Theme Studio", Content = tostring(err), Type = "Error" })
			end
			nameIn:Set(name, true)
			RefreshMine()
			TingUI:Notify({ Title = "Theme installed", Content = "'" .. name .. "'" .. (err and (" is in your list until you leave. It couldn't be saved: " .. tostring(err)) or " is in your list and in use."),
				Type = err and "Warning" or "Success" })
		end })

		local mine = shareTab:AddGroup({ Title = "My themes", Side = "Right", Icon = "list" })
		mineDrop = mine:AddDropdown({ Text = "Saved themes", Values = TingUI:ListSavedThemes(), Description = "Themes you saved or installed." })
		mine:AddButton({ Text = "Use", Callback = function()
			if not mineDrop.Value then return end
			TingUI:ApplyPreset(mineDrop.Value)
			nameIn:Set(mineDrop.Value, true)
		end }):AddSubButton({ Text = "Delete", Callback = function()
			local n = mineDrop.Value
			if not n then return end
			TingUI:Confirm({ Title = "Delete '" .. n .. "'?", Type = "Danger", Confirm = "Delete", Text = "The saved theme is removed. This cannot be undone.",
				OnConfirm = function()
					local ok, err = TingUI:DeleteTheme(n)
					RefreshMine()
					TingUI:Notify({ Title = "Theme Studio", Content = ok and ("Deleted '" .. n .. "'.") or tostring(err), Type = ok and "Success" or "Error" })
				end })
		end })
		local startDrop = mine:AddDropdown({ Text = "Start from", Values = TingUI:_RefreshPresetLists(), Default = PresetLabel(TingUI.Preset),
			Description = "Load any theme into the studio and change it from there.",
			Callback = Quiet(function(v)
				if not v then return end
				TingUI:ApplyPreset(v)
				nameIn:Set(TingUI._builtInThemes[PresetName(v)] and (PresetName(v) .. " remix") or PresetName(v), true)
			end) })
		St.OnExternal = function() startDrop:Set(PresetLabel(TingUI.Preset), true) end
		TingUI._themeListeners = TingUI._themeListeners or {}
		table.insert(TingUI._themeListeners, function(names) startDrop:SetValues(names, true) end)
		mine:AddButton({ Text = "Revert", Description = "Back to the look you had when you opened the studio.", Callback = function()
			local snap = St.Snapshot
			if not snap then return end
			TingUI:SetTheme(table.clone(snap.Colors), TingUI.ThemeTransition)
			TingUI:SetStyle(Copy(snap.Style), TingUI.ThemeTransition)
			TingUI.Preset = snap.Preset
			SyncOption("TingUI_Preset", PresetLabel(snap.Preset))
		end })
		mine:AddButton({ Text = "Use in every script", Description = "Gives every other TingUI script running right now this look.", Callback = function()
			Flush()
			local n = TingUI.Shell:ApplyThemeToAll()
			TingUI:Notify({ Title = "Theme", Content = n > 0 and ("Applied to " .. n .. (n == 1 and " other script." or " other scripts.")) or "No other TingUI scripts are running.",
				Type = n > 0 and "Success" or "Info" })
		end })
	end

	-- opens (or brings back) the studio; returns its window
	function TingUI:OpenThemeStudio()
		if St.Window and St.Window.Frame.Parent then
			St.Window:SetVisible(true)
			return St.Window
		end
		Load()
		local T = self._themeTarget or self.Theme
		St.Snapshot = { Preset = self.Preset, Colors = table.clone(T), Style = Copy(self.Style) }
		St.Sync = {}
		-- beside the first window when there's room, otherwise centred
		local pos
		local first = self.Windows[1] and self.Windows[1].Frame
		if first and first.Parent and first.Visible then
			local vp, sc = self:_Viewport(), math.max(self.Scale, 0.01)
			local p, s = first.AbsolutePosition, first.AbsoluteSize
			if p.X + s.X + 16 + 600 * sc <= vp.X then pos = UDim2.fromOffset(p.X + s.X + 16, math.max(12, p.Y)) end
		end
		local W = self:CreateWindow({ Title = "Theme Studio", Subtitle = "edits show live", Id = "ThemeStudio", Size = Vector2.new(600, 640),
			Position = pos, Dock = false, MobileButton = false, Fill = false, Closable = true, MenuKey = false,
			Footer = "Save or share it from the Share tab" })
		St.Window = W
		Build(W)
		if Dock and not St.DockButton then
			St.DockButton = self:AddDockButton({ Icon = "palette", Tooltip = "Theme Studio", Order = 36,
				Callback = function()
					if St.Window and St.Window.Frame.Parent then St.Window:Toggle() else TingUI:OpenThemeStudio() end
				end,
				Active = function() return St.Window ~= nil and St.Window.Visible end })
		end
		Resync()
		return W
	end

	function TingUI:CloseThemeStudio()
		if St.Window then St.Window:SetVisible(false) end
	end
end Setup() end

------------------------------------------------------------------------------
-- Layouts: a whole window from one table, changed in place, and live reload
------------------------------------------------------------------------------
-- TingUI:Mount(layout, handlers) builds a window from a plain table (Lua, or JSON text). ui:Update(newLayout) moves it
-- to a new version of that table: only what changed is rebuilt, and every value, keybind and the open tab are kept.
-- TingUI:Watch(source, fn) re-reads a file, a StringValue or a function and hands each new version to fn, and
-- TingUI:MountFile(source, handlers) puts the two together: save the file and the window follows.
do local function Setup()
	local KINDS = {
		Toggle = true, Slider = true, Dropdown = true, Input = true, Button = true, Label = true, Paragraph = true,
		Divider = true, Progress = true, ColorPicker = true, Keybind = true,
	}
	-- element fields that never need a rebuild: patched in place, read when called, or only used when first made
	local LIVE = { Default = true, Callback = true, Action = true, Description = true, Disabled = true, Visible = true, Key = true }
	local NOT_OPTS = { Type = true, Key = true, Action = true, Callback = true, Keybind = true, ColorPicker = true, Sub = true, Visible = true }
	-- window fields: Title, Subtitle, Footer, MenuKey and Icon are patched, the ones in REBUILD remake the window, and the
	-- rest (Position, Snow, Backdrop, ...) only count when it's first made
	local REBUILD = { "Size", "Tag", "Version", "Dock", "Closable", "Fill", "Id", "ConfigTab", "MobileButton" }
	local Mounted = {}
	Mounted.__index = Mounted

	local function Fail(where, msg) error(where .. " " .. msg, 0) end

	-- a stable text for any value, so two versions of a spec compare by content
	local function Dump(v, skip)
		local t = typeof(v)
		if t == "table" then
			local keys = {}
			for k in pairs(v) do
				if not (skip and skip[k]) then table.insert(keys, k) end
			end
			table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
			local parts = {}
			for _, k in ipairs(keys) do table.insert(parts, tostring(k) .. "=" .. Dump(v[k], skip)) end
			return "{" .. table.concat(parts, ",") .. "}"
		elseif t == "function" then
			return "fn"
		elseif t == "string" then
			return string.format("%q", v)
		end
		return t .. ":" .. tostring(v)
	end

	-- JSON can't hold Color3s or KeyCodes: "#rrggbb" and key names stand in for them
	local function Hex(v)
		if type(v) ~= "string" then return v end
		local h = v:match("^#(%x%x%x%x%x%x)$")
		if not h then return v end
		return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16))
	end
	local function ColorFields(o)
		for k, v in pairs(o) do
			if type(k) == "string" and k:match("Color$") then o[k] = Hex(v) end
		end
		return o
	end
	local function KeyCode(v, where)
		if v == nil or v == false or typeof(v) == "EnumItem" then return v end
		local ok, k = pcall(function() return Enum.KeyCode[v] end)
		if not (ok and k) then Fail(where, "has an unknown key '" .. tostring(v) .. "' (a KeyCode name like \"RightShift\")") end
		return k
	end
	local function Vec(v, where)
		if v == nil or typeof(v) == "Vector2" then return v end
		if type(v) == "table" then
			local x, y = tonumber(v[1] or v.X), tonumber(v[2] or v.Y)
			if x and y then return Vector2.new(x, y) end
		end
		Fail(where, "should be a size like {560, 640}")
	end
	local function Pos(v, where)
		if v == nil or typeof(v) == "UDim2" then return v end
		if type(v) == "table" then
			if #v == 2 then return UDim2.fromOffset(tonumber(v[1]) or 0, tonumber(v[2]) or 0) end
			if #v == 4 then return UDim2.new(tonumber(v[1]) or 0, tonumber(v[2]) or 0, tonumber(v[3]) or 0, tonumber(v[4]) or 0) end
		end
		Fail(where, "should be a position like {40, 40} (pixels) or {0.5, -280, 0.5, -320} (scale, offset)")
	end

	local function Distance(a, b)
		a, b = a:lower(), b:lower()
		local prev = {}
		for j = 0, #b do prev[j] = j end
		for i = 1, #a do
			local cur = { [0] = i }
			for j = 1, #b do
				cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a:sub(i, i) == b:sub(j, j) and 0 or 1))
			end
			prev = cur
		end
		return prev[#b]
	end
	-- the element types there are: the built-ins, and every TingUI:RegisterElement
	local function Kinds()
		local out = {}
		for k in pairs(KINDS) do out[k] = true end
		for k, v in pairs(Elements) do
			if type(k) == "string" and k:sub(1, 3) == "Add" and type(v) == "function" then out[k:sub(4)] = true end
		end
		return out
	end
	local function KindName(t, kinds)
		if type(t) ~= "string" then return nil end
		if kinds[t] then return t end
		for k in pairs(kinds) do
			if k:lower() == t:lower() then return k end
		end
		return nil
	end
	local function Suggest(t, kinds)
		if type(t) ~= "string" then return nil end
		local best, bd = nil, math.max(2, math.floor(#t / 3))
		for k in pairs(kinds) do
			local d = Distance(t, k)
			if d <= bd then best, bd = k, d end
		end
		return best
	end

	-- the tables in a list's array part (so {"Main", {group}, {group}} works as well as {Name = "Main", Groups = {...}})
	local function Items(t, field)
		if t[field] ~= nil then
			if type(t[field]) ~= "table" then return nil end
			return t[field]
		end
		local out = {}
		for _, v in ipairs(t) do
			if type(v) == "table" then table.insert(out, v) end
		end
		return out
	end

	local function NormAddon(v, kind, where)
		if v == nil then return nil end
		if type(v) ~= "table" or getmetatable(v) ~= nil then v = { Default = v } end
		local o = {}
		for k, x in pairs(v) do
			if type(k) == "string" and k ~= "Action" and k ~= "Callback" then o[k] = x end
		end
		if kind == "ColorPicker" then
			o.Default = Hex(o.Default)
			if o.Default ~= nil and typeof(o.Default) ~= "Color3" then Fail(where, "has a colour that isn't \"#rrggbb\"") end
		elseif o.Default ~= nil then
			o.Default = KeyCode(o.Default, where)
		end
		return { Opts = ColorFields(o), Action = v.Action, Callback = v.Callback, Flag = o.Flag }
	end

	local function NormElement(e, i, where, keys, kinds)
		if type(e) == "string" then e = { e } end
		if type(e) ~= "table" then Fail(where, "should be a table like {\"Toggle\", \"Fly\", Flag = \"Fly\"}") end
		local t = e[1] or e.Type
		local kind = KindName(t, kinds)
		if not kind then
			local s = Suggest(t, kinds)
			Fail(where, (t == nil and "has no type (put it first: {\"Toggle\", ...})" or ("has an unknown type '" .. tostring(t) .. "'"))
				.. (s and (" - did you mean " .. s .. "?") or ""))
		end
		local text = e[2]
		if text == nil then text = e.Text end
		if kind == "Paragraph" and text == nil then text = e.Title end
		local n = { Kind = kind, Action = e.Action, Callback = e.Callback, Visible = e.Visible }
		local o = {}
		for k, v in pairs(e) do
			if type(k) == "string" and not NOT_OPTS[k] then o[k] = v end
		end
		ColorFields(o)
		if kind == "Paragraph" then
			o.Title, o.Text = text, nil
			if o.Content == nil then o.Content = e[3] end
		elseif text ~= nil then
			o.Text = tostring(text)
		end
		if kind == "Dropdown" and o.Values ~= nil and type(o.Values) ~= "table" then Fail(where, "has Values that aren't a list") end
		if kind == "Slider" and (o.Min ~= nil and type(o.Min) ~= "number" or o.Max ~= nil and type(o.Max) ~= "number") then
			Fail(where, "has a Min or Max that isn't a number")
		end
		-- a ColorPicker or Keybind element is a label carrying that addon; its options go to the addon
		if kind == "ColorPicker" or kind == "Keybind" then
			local a = {}
			for k, v in pairs(o) do
				if k ~= "Text" and k ~= "Description" then a[k] = v end
			end
			a.Action, a.Callback = e.Action, e.Callback
			n.Main = NormAddon(a, kind, where)
			o = { Text = o.Text, Description = o.Description }
		end
		n.Opts = o
		n.Keybind = NormAddon(e.Keybind, "Keybind", where .. " (Keybind)")
		n.ColorPicker = NormAddon(e.ColorPicker, "ColorPicker", where .. " (ColorPicker)")
		if e.Sub ~= nil then
			if kind ~= "Button" or type(e.Sub) ~= "table" then Fail(where, "has Sub, which is a list of extra buttons on a Button") end
			n.Sub = {}
			for si, sb in ipairs(e.Sub) do
				if type(sb) == "string" then sb = { sb } end
				if type(sb) ~= "table" then Fail(where, "Sub[" .. si .. "] should be {\"Text\", Action = \"...\"}") end
				n.Sub[si] = { Text = tostring(sb[1] or sb.Text or "Button"), Action = sb.Action, Callback = sb.Callback, Description = sb.Description }
			end
		end
		n.Flag = o.Flag or (n.Main and n.Main.Flag)
		if n.Flag ~= nil and type(n.Flag) ~= "string" then Fail(where, "has a Flag that isn't text") end
		n.Key = tostring(e.Key or n.Flag or (kind .. ":" .. tostring(text or ("#" .. i))))
		if keys[n.Key] then
			Fail(where, "has the same key as another element in its group ('" .. n.Key .. "'): give one of them a Key or a Flag")
		end
		keys[n.Key] = true
		-- what makes two versions "the same element"; everything in LIVE is applied without a rebuild
		local sigOpts = table.clone(o)
		if kind == "Dropdown" then sigOpts.Values = nil end
		n.Sig = kind .. Dump(sigOpts, LIVE) .. Dump({ n.Main and n.Main.Opts, n.Keybind and n.Keybind.Opts, n.ColorPicker and n.ColorPicker.Opts, n.Sub }, LIVE)
		return n
	end

	local function NormElements(list, where, kinds, flags)
		local out, keys = {}, {}
		for i, e in ipairs(list) do
			local n = NormElement(e, i, where .. " > Elements[" .. i .. "]", keys, kinds)
			for _, f in ipairs({ n.Flag, n.Keybind and n.Keybind.Flag, n.ColorPicker and n.ColorPicker.Flag }) do
				if flags[f] then Fail(where .. " > Elements[" .. i .. "]", "uses the Flag '" .. f .. "', which " .. flags[f] .. " already uses") end
				flags[f] = where .. " > Elements[" .. i .. "]"
			end
			out[i] = n
		end
		return out
	end

	local function Normalize(layout)
		if type(layout) == "string" then
			local ok, v = pcall(HttpService.JSONDecode, HttpService, layout)
			if not ok then error("the layout text isn't valid JSON (" .. tostring(v):gsub("^.-:%d+: ", "") .. ")", 0) end
			layout = v
		end
		if type(layout) ~= "table" then error("a layout is a table like {Title = \"My Hub\", Tabs = {...}}", 0) end
		local kinds, flags = Kinds(), {}
		local win = {}
		for k, v in pairs(layout) do
			if type(k) == "string" and k ~= "Tabs" then win[k] = v end
		end
		win.Size = Vec(win.Size, "Size")
		win.Position = Pos(win.Position, "Position")
		win.MenuKey = KeyCode(win.MenuKey, "MenuKey")
		for _, k in ipairs({ "Tag", "Version" }) do
			if type(win[k]) == "table" then win[k] = ColorFields(table.clone(win[k])) end
		end
		local ct = win.ConfigTab
		if ct ~= nil and ct ~= false and ct ~= true and type(ct) ~= "string" and type(ct) ~= "table" then
			error("ConfigTab is true, a tab name, or {Name = \"Settings\", Credits = {...}}", 0)
		end
		local n = { Window = win, Tabs = {}, ConfigTab = (ct ~= nil and ct ~= false) and ct or nil }
		local rebuild = {}
		for _, k in ipairs(REBUILD) do rebuild[k] = win[k] end
		n.WinSig = Dump(rebuild)
		local tabs = layout.Tabs
		if tabs == nil then tabs = {} end
		if type(tabs) ~= "table" then error("Tabs should be a list of tabs", 0) end
		local tabKeys = {}
		for ti, t in ipairs(tabs) do
			local where = "Tabs[" .. ti .. "]"
			if type(t) ~= "table" then Fail(where, "should be a table like {Name = \"Main\", Groups = {...}}") end
			local name = t.Name or (type(t[1]) == "string" and t[1]) or nil
			if type(name) ~= "string" or name == "" then Fail(where, "needs a Name") end
			where = where .. " '" .. name .. "'"
			local tn = { Name = name, Key = tostring(t.Key or name), Fill = t.Fill, Groups = {}, ByKey = {} }
			if tabKeys[tn.Key] then Fail(where, "has the same name as another tab: give one of them a Key") end
			tabKeys[tn.Key] = true
			local groups = Items(t, "Groups")
			if not groups then Fail(where, "has Groups that aren't a list") end
			for gi, g in ipairs(groups) do
				local gw = where .. " > Groups[" .. gi .. "]"
				if type(g) ~= "table" then Fail(gw, "should be a table like {Title = \"Movement\", Elements = {...}}") end
				local title = g.Title or (type(g[1]) == "string" and g[1]) or nil
				if title ~= nil then gw = gw .. " '" .. tostring(title) .. "'" end
				local side = g.Side
				if side == 1 then side = "Left" elseif side == 2 then side = "Right" end
				if side == nil then side = (gi % 2 == 1) and "Left" or "Right" end
				if side ~= "Left" and side ~= "Right" then Fail(gw, "has Side '" .. tostring(side) .. "' (Left or Right)") end
				local gn = { Title = title and tostring(title) or nil, Icon = g.Icon, Side = side, Key = tostring(g.Key or title or ("#" .. gi)) }
				if tn.ByKey[gn.Key] then Fail(gw, "has the same title as another group in this tab: give one of them a Key") end
				if g.Tabs ~= nil then
					-- a tabbox: {Tabs = {{Name = "A", Elements = {...}}, ...}}
					if type(g.Tabs) ~= "table" then Fail(gw, "has Tabs that aren't a list") end
					gn.Box = {}
					local names = {}
					for si, sub in ipairs(g.Tabs) do
						local sw = gw .. " > Tabs[" .. si .. "]"
						if type(sub) ~= "table" then Fail(sw, "should be a table like {Name = \"Aim\", Elements = {...}}") end
						local sname = sub.Name or (type(sub[1]) == "string" and sub[1]) or nil
						if type(sname) ~= "string" then Fail(sw, "needs a Name") end
						if names[sname] then Fail(sw, "has the same name as another tab in this tabbox") end
						names[sname] = true
						local els = Items(sub, "Elements")
						if not els then Fail(sw, "has Elements that aren't a list") end
						gn.Box[si] = { Name = sname, Elements = NormElements(els, sw .. " '" .. sname .. "'", kinds, flags) }
					end
					local list = {}
					for _, sub in ipairs(gn.Box) do table.insert(list, sub.Name) end
					gn.Sig = Dump({ "Tabbox", side, list })
				else
					local els = Items(g, "Elements")
					if not els then Fail(gw, "has Elements that aren't a list") end
					gn.Elements = NormElements(els, gw, kinds, flags)
					gn.Sig = Dump({ "Group", gn.Title, gn.Icon, side })
				end
				tn.ByKey[gn.Key] = gn
				tn.Groups[gi] = gn
			end
			n.Tabs[ti] = tn
		end
		return n
	end

	-- callbacks are looked up when they run, so a new version of a function (or a handler added later) just works
	local function Handler(ui, part)
		if type(part.Callback) == "function" then return part.Callback end
		local h = ui.Handlers
		local fn = (part.Action ~= nil and h[part.Action]) or (part.Action == nil and part.Flag ~= nil and h[part.Flag]) or nil
		if type(fn) == "function" then return fn end
		if part.Action ~= nil and not ui.Warned[part.Action] then
			ui.Warned[part.Action] = true
			warn("[TingUI] layout: nothing handles the action '" .. tostring(part.Action) .. "' (pass it in the handlers table, or ui:On(name, fn))")
		end
		return nil
	end
	local function Runner(ui, rec, pick)
		return function(...)
			local part = pick(rec.Spec)
			local fn = part and Handler(ui, part)
			if fn then return fn(...) end
		end
	end

	local function SaveKey(rec, part, suffix)
		if part and part.Flag then return "flag:" .. part.Flag end
		return "path:" .. rec.Path .. (suffix or "")
	end
	local function Remember(ui, rec)
		local function Keep(obj, key, specMode)
			if type(obj) ~= "table" then return end
			local v = obj.Value
			if type(v) == "table" and getmetatable(v) == nil then v = table.clone(v) end
			ui.Saved[key] = { Has = true, Value = v, Mode = obj.Mode, SpecMode = specMode }
		end
		local s = rec.Spec
		Keep(rec.Main, SaveKey(rec, s.Main or s, ""), s.Main and s.Main.Opts.Mode)
		for _, name in ipairs({ "Keybind", "ColorPicker" }) do
			if rec[name] then Keep(rec[name], SaveKey(rec, s[name], "#" .. name), s[name] and s[name].Opts.Mode) end
		end
	end
	local function Restore(ui, obj, key, part)
		local s = ui.Saved[key]
		if not (s and s.Has and type(obj) == "table") then return end
		if obj.Type == "Keybind" then
			pcall(obj.SetKey, obj, s.Value, true)
			-- a mode switched by right-click stays, unless the layout itself now asks for a different one
			if s.Mode and s.SpecMode == (part and part.Opts.Mode) then obj.Mode = s.Mode end
		elseif type(obj.Set) == "function" and s.Value ~= nil then
			pcall(obj.Set, obj, s.Value, true)
		end
		if obj.Flag then TingUI.Flags[obj.Flag] = obj.Value end
	end

	local function Forget(obj)
		if type(obj) == "table" and obj.Flag and TingUI.Options[obj.Flag] == obj then
			TingUI.Options[obj.Flag] = nil
			TingUI.Flags[obj.Flag] = nil
		end
	end
	local function Drop(ui, rec)
		Remember(ui, rec)
		Forget(rec.Keybind)
		Forget(rec.ColorPicker)
		if rec.Main ~= rec.Obj then Forget(rec.Main) end
		local obj = rec.Obj
		if type(obj) == "table" and type(obj.Destroy) == "function" then
			pcall(obj.Destroy, obj)
		elseif type(obj) == "table" and typeof(obj.Row) == "Instance" then
			obj.Row:Destroy()
		end
	end

	local function Create(ui, group, e, path)
		local rec = { Spec = e, Path = path }
		local o = table.clone(e.Opts)
		local kind = e.Kind
		local obj
		if kind == "Divider" then
			obj = group:AddDivider()
		elseif kind == "Label" or kind == "ColorPicker" or kind == "Keybind" then
			obj = group:AddLabel(o)
		else
			o.Callback = Runner(ui, rec, function(s) return s end)
			local make = group["Add" .. kind]
			if type(make) ~= "function" then error("there's no element type '" .. kind .. "' any more", 0) end
			obj = make(group, o)
		end
		rec.Obj, rec.Main = obj, obj
		if type(obj) == "table" then
			rec.Row = typeof(obj.Row) == "Instance" and obj.Row or nil
			if e.Main then
				local a = table.clone(e.Main.Opts)
				a.Callback = Runner(ui, rec, function(s) return s.Main end)
				rec.Main = kind == "Keybind" and obj:AddKeybind(a) or obj:AddColorPicker(a)
			end
			if e.Keybind and obj._addons then
				local a = table.clone(e.Keybind.Opts)
				a.Callback = Runner(ui, rec, function(s) return s.Keybind end)
				rec.Keybind = obj:AddKeybind(a)
			end
			if e.ColorPicker and obj._addons then
				local a = table.clone(e.ColorPicker.Opts)
				a.Callback = Runner(ui, rec, function(s) return s.ColorPicker end)
				rec.ColorPicker = obj:AddColorPicker(a)
			end
			if e.Sub and type(obj.AddSubButton) == "function" then
				for i, sb in ipairs(e.Sub) do
					obj:AddSubButton({ Text = sb.Text, Description = sb.Description,
						Callback = Runner(ui, rec, function(s) return s.Sub and s.Sub[i] end) })
				end
			end
			Restore(ui, rec.Main, SaveKey(rec, e.Main or e, ""), e.Main)
			if rec.Keybind then Restore(ui, rec.Keybind, SaveKey(rec, e.Keybind, "#Keybind"), e.Keybind) end
			if rec.ColorPicker then Restore(ui, rec.ColorPicker, SaveKey(rec, e.ColorPicker, "#ColorPicker"), e.ColorPicker) end
			if e.Visible == false and type(obj.SetVisible) == "function" then obj:SetVisible(false) end
		end
		return rec
	end

	-- same element, newer spec: apply what can change without a rebuild
	local function Patch(rec, e)
		local old = rec.Spec
		rec.Spec = e
		local obj, main = rec.Obj, rec.Main
		if type(obj) ~= "table" then return end
		if e.Opts.Description ~= old.Opts.Description and type(obj.SetDescription) == "function" then
			if e.Opts.Description ~= nil then obj:SetDescription(e.Opts.Description) else obj.Description = nil end
		end
		if (e.Opts.Disabled == true) ~= (old.Opts.Disabled == true) and type(main) == "table" and type(main.SetDisabled) == "function" then
			main:SetDisabled(e.Opts.Disabled == true)
		end
		if (e.Visible ~= false) ~= (old.Visible ~= false) and type(obj.SetVisible) == "function" then obj:SetVisible(e.Visible ~= false) end
		if e.Kind == "Dropdown" and e.Opts.Values and Dump(e.Opts.Values) ~= Dump(old.Opts.Values) and type(main.SetValues) == "function" then
			main:SetValues(e.Opts.Values, true)
		end
	end

	-- one list of elements into one container (a group, or one tab of a tabbox)
	local function Fill(ui, c, list, stats, dropped)
		local seen = {}
		for i, e in ipairs(list) do
			seen[e.Key] = true
			local rec = c.Recs[e.Key]
			if rec then
				Patch(rec, e)
				stats.Kept = stats.Kept + 1
			else
				local path = c.Path .. "/" .. e.Key
				rec = Create(ui, c.Group, e, path)
				c.Recs[e.Key] = rec
				if dropped[path] then stats.Changed = stats.Changed + 1 dropped[path] = nil else stats.Added = stats.Added + 1 end
			end
			if rec.Row then rec.Row.LayoutOrder = i end
			if e.Flag and rec.Main then ui.Elements[e.Flag] = rec.Main end
			if e.Key ~= e.Flag then ui.Elements[e.Key] = rec.Main end
		end
	end

	local function DropContainer(ui, c, dropped)
		for key, rec in pairs(c.Recs) do
			Drop(ui, rec)
			dropped[rec.Path] = true
			c.Recs[key] = nil
		end
	end
	local function DropGroup(ui, gr, dropped)
		for _, c in ipairs(gr.Containers) do DropContainer(ui, c, dropped) end
		pcall(gr.Object.Destroy, gr.Object)
	end
	local function DropTab(ui, tr, dropped)
		for key, gr in pairs(tr.Groups) do
			DropGroup(ui, gr, dropped)
			tr.Groups[key] = nil
		end
		pcall(tr.T.Destroy, tr.T)
	end

	local function MakeGroup(tab, g, path)
		local gr = { Sig = g.Sig, Containers = {} }
		if g.Box then
			local box = tab:AddTabbox(g.Side)
			gr.Object, gr.Frame = box, box.Frame
			for si, sub in ipairs(g.Box) do
				gr.Containers[si] = { Group = box:AddTab(sub.Name), Recs = {}, Path = path .. "/" .. sub.Name }
			end
		else
			local grp = tab:AddGroup({ Title = g.Title, Icon = g.Icon, Side = g.Side })
			gr.Object, gr.Frame = grp, grp.Frame
			gr.Containers[1] = { Group = grp, Recs = {}, Path = path }
		end
		return gr
	end

	local function MakeWindow(ui, n, old)
		local o = table.clone(n.Window)
		o.ConfigTab = nil
		if old and old.Frame then o.Position = old.Frame.Position end
		local W = TingUI:CreateWindow(o)
		local ct = n.ConfigTab
		if ct then
			local name = type(ct) == "string" and ct or (type(ct) == "table" and ct.Name) or "Config"
			ui.ConfigTab = W:AddConfigTab(name, type(ct) == "table" and ct or nil)
		else
			ui.ConfigTab = nil
		end
		if old and old.Visible == false then W:SetVisible(false) end
		return W
	end

	local function Reconcile(ui, n)
		local stats = { Added = 0, Removed = 0, Changed = 0, Kept = 0 }
		local dropped = {}
		local W = ui.Window
		local activeKey
		local onConfig = W ~= nil and ui.ConfigTab ~= nil and W.Active == ui.ConfigTab
		for key, tr in pairs(ui.Tabs) do
			if W and W.Active == tr.T then activeKey = key end
		end
		-- the window itself: patched, or remade when something only CreateWindow reads has changed
		if W and n.WinSig ~= ui.WinSig then
			for _, tr in pairs(ui.Tabs) do
				for _, gr in pairs(tr.Groups) do
					for _, c in ipairs(gr.Containers) do DropContainer(ui, c, dropped) end
				end
			end
			ui.Tabs = {}
			local old = W
			W = MakeWindow(ui, n, old)
			old:Destroy()
			stats.Window = "rebuilt"
		elseif not W then
			W = MakeWindow(ui, n, nil)
			stats.Window = "created"
		else
			local was, now = ui.Layout.Window, n.Window
			if now.Title ~= was.Title then W:SetTitle(now.Title or "TingUI") end
			if now.Subtitle ~= was.Subtitle then W:SetSubtitle(now.Subtitle or "") end
			if now.Footer ~= was.Footer and type(W.SetFooter) == "function" then W:SetFooter(now.Footer or "") end
			if now.MenuKey ~= was.MenuKey then
				local k = now.MenuKey
				if k == nil then k = Enum.KeyCode.RightShift elseif k == false then k = nil end
				W:SetMenuKey(k)
				local chip = TingUI.Options.TingUI_MenuKey
				if chip and chip._window == W and k then pcall(chip.SetKey, chip, k, true) end
			end
			if now.Icon ~= was.Icon and now.Icon ~= nil then TingUI:SetIcon(now.Icon) end
		end
		ui.Window, ui.WinSig = W, n.WinSig
		W.Layout = ui

		-- pass 1: take away whatever is gone or has changed shape (values are remembered first)
		local wantTabs = {}
		for _, t in ipairs(n.Tabs) do wantTabs[t.Key] = t end
		for key, tr in pairs(ui.Tabs) do
			local t = wantTabs[key]
			if not t or t.Name ~= tr.Name then
				DropTab(ui, tr, dropped)
				ui.Tabs[key] = nil
			else
				for gkey, gr in pairs(tr.Groups) do
					local g = t.ByKey[gkey]
					if not g or g.Sig ~= gr.Sig then
						DropGroup(ui, gr, dropped)
						tr.Groups[gkey] = nil
					else
						for ci, c in ipairs(gr.Containers) do
							local want = {}
							for _, e in ipairs(g.Box and g.Box[ci].Elements or g.Elements) do want[e.Key] = e end
							for ekey, rec in pairs(c.Recs) do
								local e = want[ekey]
								if not e or e.Sig ~= rec.Spec.Sig then
									Drop(ui, rec)
									dropped[rec.Path] = true
									c.Recs[ekey] = nil
								end
							end
						end
					end
				end
			end
		end

		-- pass 2: make what's new, patch what stayed, and put everything in the layout's order
		ui.Elements = {}
		for ti, t in ipairs(n.Tabs) do
			local tr = ui.Tabs[t.Key]
			if not tr then
				tr = { Name = t.Name, T = W:AddTab(t.Name), Groups = {} }
				ui.Tabs[t.Key] = tr
			end
			tr.Order = ti
			if t.Fill ~= nil then tr.T.Fill = t.Fill ~= false end
			for gi, g in ipairs(t.Groups) do
				local gr = tr.Groups[g.Key]
				if not gr then
					gr = MakeGroup(tr.T, g, t.Key .. "/" .. g.Key)
					tr.Groups[g.Key] = gr
				end
				if gr.Frame then gr.Frame.LayoutOrder = gi end
				for ci, c in ipairs(gr.Containers) do
					Fill(ui, c, g.Box and g.Box[ci].Elements or g.Elements, stats, dropped)
				end
			end
			if tr.T._Relayout then tr.T._Relayout() end
		end
		for _ in pairs(dropped) do stats.Removed = stats.Removed + 1 end

		-- tab order: the layout's tabs, then any added from code, then the config tab
		local managed, order = {}, {}
		for _, t in ipairs(n.Tabs) do
			local T = ui.Tabs[t.Key].T
			managed[T] = true
			table.insert(order, T)
		end
		for _, T in ipairs(W.Tabs) do
			if not managed[T] and T ~= ui.ConfigTab then table.insert(order, T) end
		end
		if ui.ConfigTab and table.find(W.Tabs, ui.ConfigTab) then table.insert(order, ui.ConfigTab) end
		table.clear(W.Tabs)
		for i, T in ipairs(order) do
			W.Tabs[i] = T
			T.Button.LayoutOrder = i
		end
		-- the tab you had open stays open; a new window opens on the layout's first tab
		local keep = activeKey and ui.Tabs[activeKey]
		if onConfig and ui.ConfigTab then
			if W.Active ~= ui.ConfigTab then W:SelectTab(ui.ConfigTab) end
		elseif keep then
			if W.Active ~= keep.T then W:SelectTab(keep.T) end
		elseif n.Tabs[1] and (stats.Window or not W.Active or not table.find(W.Tabs, W.Active)) then
			W:SelectTab(ui.Tabs[n.Tabs[1].Key].T)
		end
		W:_StyleTabs(true, true)
		TingUI:_UpdateHotkeys()
		return stats
	end

	local function NewMounted(handlers)
		return setmetatable({
			Handlers = type(handlers) == "table" and handlers or {}, Elements = {}, Saved = {}, Tabs = {}, Warned = {},
			Updated = NewSignal(), Version = 0,
		}, Mounted)
	end

	-- move the window to a new version of its layout. Returns true and what changed, or false and why (nothing changes then).
	function Mounted:Update(layout)
		if self.Destroyed then return false, "this layout was destroyed" end
		if TingUI.Unloaded then return false, "TingUI was unloaded" end
		local ok, n = pcall(Normalize, layout)
		if not ok then return false, tostring(n) end
		local okR, stats = pcall(Reconcile, self, n)
		if not okR then return false, "couldn't apply the layout: " .. tostring(stats) end
		self.Layout = n
		self.Version = self.Version + 1
		self.Updated:Fire(stats)
		return true, stats
	end
	-- the element made for a Flag or Key
	function Mounted:Get(key) return self.Elements[key] end
	-- what an Action (or a Flag) runs; replaces any earlier one
	function Mounted:On(name, fn)
		self.Handlers[name] = fn
		self.Warned[name] = nil
		return self
	end
	function Mounted:Destroy()
		if self.Destroyed then return end
		self.Destroyed = true
		if self.Watcher then self.Watcher:Stop() end
		local dropped = {}
		for _, tr in pairs(self.Tabs) do
			for _, gr in pairs(tr.Groups) do
				for _, c in ipairs(gr.Containers) do DropContainer(self, c, dropped) end
			end
		end
		self.Tabs = {}
		if self.Window then self.Window:Destroy() end
		self.Window = nil
	end

	function TingUI:Mount(layout, handlers)
		local ui = NewMounted(handlers)
		local ok, err = ui:Update(layout)
		if not ok then error("[TingUI] Mount: " .. tostring(err), 2) end
		return ui
	end

	-- Watch(source, fn, opts): source is a file path (executors), a StringValue or a function returning text or a table.
	-- Each new version is parsed (JSON, or Lua that returns a table) and passed to fn; fn may return false, "why".
	-- opts: Interval (seconds, default 0.5), Raw (pass the text as is), Immediate (default true), Notify (default true),
	-- OnError(msg). Returns {Stop, Check, LastError, Version}.
	function TingUI:Watch(source, callback, opts)
		assert(type(callback) == "function", "Watch(source, function(layout) ... end, opts)")
		opts = type(opts) == "table" and opts or {}
		local interval = math.max(tonumber(opts.Interval) or 0.5, 0.1)
		local w = { Version = 0, Stopped = false, LastError = nil }
		local last, reported
		local conn

		local function Read()
			if type(source) == "function" then return source() end
			if typeof(source) == "Instance" then
				if source:IsA("StringValue") then return source.Value end
				if source:IsA("ModuleScript") then
					error("a ModuleScript's code can't be read while the game runs: put the layout in a StringValue, a file or a function", 0)
				end
				error("can't read a " .. source.ClassName .. ": use a StringValue, a file path or a function", 0)
			end
			if type(source) == "string" then
				if type(readfile) ~= "function" or type(isfile) ~= "function" then
					error("this environment can't read files (no readfile): use a StringValue or a function", 0)
				end
				if not isfile(source) then return nil end
				return readfile(source)
			end
			error("Watch needs a file path, a StringValue or a function", 0)
		end
		local function Parse(text)
			if type(text) == "table" or opts.Raw then return text end
			if type(text) ~= "string" then error("the source gave " .. typeof(text) .. " instead of text", 0) end
			local body = text:match("^%s*(.-)%s*$")
			if body == "" then error("the file is empty", 0) end
			local head = body:sub(1, 1)
			if head == "{" or head == "[" then
				local ok, v = pcall(HttpService.JSONDecode, HttpService, body)
				if ok then return v end
			end
			local load = loadstring
			if type(load) ~= "function" then
				error("this environment can't run Lua text (no loadstring): write the layout as JSON", 0)
			end
			-- a bare table ({...}) or a chunk that returns one; the chunk gets TingUI as ...
			local chunk, err = load("return " .. body, "=layout")
			if not chunk then
				local c2, err2 = load(body, "=layout")
				if not c2 then error("syntax error: " .. tostring(head == "{" and err or err2):gsub("^.-:(%d+):", "line %1:"), 0) end
				chunk = c2
			end
			local ok, v = pcall(chunk, TingUI)
			if not ok then error("the layout code errored: " .. tostring(v):gsub("^.-:(%d+):", "line %1:"), 0) end
			if v == nil then error("the layout code didn't return a table", 0) end
			return v
		end
		local function Report(msg)
			msg = tostring(msg)
			w.LastError = msg
			if msg ~= reported then
				reported = msg
				warn("[TingUI] live reload: " .. msg)
				if opts.Notify ~= false then
					pcall(function() TingUI:Notify({ Title = "Layout not applied", Content = msg, Type = "Warning", Duration = 8 }) end)
				end
				if type(opts.OnError) == "function" then task.spawn(opts.OnError, msg) end
			end
			return false
		end
		local busy = false
		local function Check(force)
			if w.Stopped or TingUI.Unloaded or busy then return false end
			busy = true
			local function Run()
				local okR, text = pcall(Read)
				if not okR then return Report(text) end
				if text == nil then
					if type(source) == "string" then return Report("can't find " .. source .. " (yet)") end
					return false
				end
				local sig = type(text) == "string" and text or Dump(text)
				if sig == last and not force then return false end
				last = sig
				local okP, value = pcall(Parse, text)
				if not okP then return Report(value) end
				local okC, res, why = pcall(callback, value)
				if not okC then return Report(res) end
				if res == false then return Report(why or "the layout was refused") end
				w.LastError, reported = nil, nil
				w.Version = w.Version + 1
				return true
			end
			local res = Run()
			busy = false
			return res
		end
		function w:Check() return Check(true) end
		function w:Stop()
			self.Stopped = true
			if conn then conn:Disconnect() conn = nil end
		end
		if typeof(source) == "Instance" and source:IsA("StringValue") then
			conn = source:GetPropertyChangedSignal("Value"):Connect(function() Check() end)
		end
		task.spawn(function()
			if opts.Immediate ~= false then Check() end
			while not w.Stopped and not TingUI.Unloaded do
				task.wait(interval)
				if w.Stopped or TingUI.Unloaded then break end
				Check()
			end
			w:Stop()
		end)
		return w
	end

	local function Summary(stats)
		if stats.Window == "rebuilt" then return "Window rebuilt" end
		local parts = {}
		if stats.Changed > 0 then table.insert(parts, stats.Changed .. " changed") end
		if stats.Added > 0 then table.insert(parts, stats.Added .. " added") end
		if stats.Removed > 0 then table.insert(parts, stats.Removed .. " removed") end
		return #parts > 0 and table.concat(parts, ", ") or "Up to date"
	end
	TingUI._LayoutSummary = Summary

	-- Mount a layout from a file (or StringValue, or function) and keep it in step with every save.
	-- The window appears with the first version that works; a broken save keeps the last good one and says why.
	function TingUI:MountFile(source, handlers, opts)
		opts = type(opts) == "table" and opts or {}
		local ui = NewMounted(handlers)
		ui.Watcher = self:Watch(source, function(layout)
			local had = ui.Window ~= nil
			local ok, stats = ui:Update(layout)
			if not ok then return false, stats end
			if opts.Notify ~= false then
				if had then
					TingUI:Notify({ Title = "Live reload", Content = Summary(stats), Type = "Success", Duration = 2.5 })
				elseif type(source) == "string" then
					TingUI:Notify({ Title = "Live reload", Content = "Watching " .. source .. ". Save it and the window follows.", Duration = 3 })
				end
			end
			return true
		end, opts)
		return ui
	end
end Setup() end

-- Change load options after loading (any time, also before the first window). Unknown keys are ignored.
-- Id, Reuse, NoInter, NoImages, AssetBase and TextureBase only matter at load time: use TingUI.new for those.
function TingUI:Configure(o, initial)
	assert(type(o) == "table", "Configure({ Theme = ..., Parent = ..., ... })")
	if o.Parent ~= nil and not initial then self:SetParent(o.Parent) end
	if o.DisplayOrder then Gui.DisplayOrder = o.DisplayOrder end
	if o.Name and not initial then Gui.Name = tostring(o.Name) end
	if o.Folder then self.Folder = tostring(o.Folder) end
	if o.ThemeFolder then self.ThemeFolder = tostring(o.ThemeFolder) end
	if o.Storage then self:SetStorage(o.Storage) end
	if o.Hints ~= nil then self.Hints = o.Hints ~= false end
	if o.NotifyErrors ~= nil then self.NotifyErrors = o.NotifyErrors ~= false end
	if o.Shortcuts ~= nil then self.Shortcuts = o.Shortcuts ~= false end
	if o.ReducedMotion ~= nil and not initial then self:SetReducedMotion(o.ReducedMotion) end
	if type(o.Icons) == "table" and not initial then for k, v in pairs(o.Icons) do IconImages[k] = v end end
	if type(o.Textures) == "table" and not initial then
		for k, v in pairs(o.Textures) do TextureImages[k] = v end
		for _, fn in ipairs(Refreshers) do pcall(fn) end
	end
	if o.Scale and not initial then pcall(function() self:SetScale(o.Scale) end) end
	if o.Theme then
		-- one of your saved themes (Theme Studio, ImportTheme) works here too
		if not self.Presets[o.Theme] and self._LoadSavedThemes then pcall(self._LoadSavedThemes, self, true) end
		if not self.Presets[o.Theme] and self.Presets[PresetAlias(o.Theme)] then o = table.clone(o) o.Theme = PresetAlias(o.Theme) end
		if self.Presets[o.Theme] then
			local fade = self.ThemeTransition
			if initial then self.ThemeTransition = 0 end
			pcall(function() self:ApplyPreset(o.Theme) end)
			self.ThemeTransition = fade
		else
			warn("[TingUI] unknown theme '" .. tostring(o.Theme) .. "'")
		end
	end
	if o.Font then pcall(function() self:SetFont(o.Font) end) end
	if o.NotifyPosition then pcall(function() self:SetNotifyPosition(o.NotifyPosition) end) end
	return self
end

-- A new, independent instance with its own options, GUI, flags and configs. Without an Id it gets a unique one,
-- so it never replaces this instance.
function TingUI.new(o)
	o = type(o) == "table" and table.clone(o) or {}
	if o.Id == nil then
		InstanceCount = InstanceCount + 1
		o.Id = "instance" .. InstanceCount
	end
	return Build(o)
end

TingUI:Configure(LoadOptions, true)

do -- image loading (icons + theme textures)
-- High-res icons: fetched once (GitHub, then the jsDelivr mirror), cached on disk, then swapped in with a fade
local ICON_BASES = {
	"https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/assets/icons/",
	"https://cdn.jsdelivr.net/gh/Irakli17/Ui-Library-Test@main/assets/icons/",
}
-- your own host (a fork, a CDN) is tried first
if type(LoadOptions.AssetBase) == "string" then table.insert(ICON_BASES, 1, LoadOptions.AssetBase) end
function TingUI:_LoadIcons()
	if not (writefile and readfile and isfile and isfolder and makefolder and getcustomasset) then return false end
	local dir = self.CacheFolder .. "/icons"
	local ok = pcall(function()
		if not isfolder(self.CacheFolder) then makefolder(self.CacheFolder) end
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
	task.spawn(function() TingUI:_LoadIcons() end)
end

-- Theme textures load on demand (only when a theme that uses them is shown), from assets/textures/ next to the icons.
do
local TEXTURE_VERSION = "v1"
local TEXTURE_BASES = {}
for _, b in ipairs(ICON_BASES) do
	local tb = b:gsub("icons/?$", "textures/")
	if tb ~= b then table.insert(TEXTURE_BASES, tb) end
end
if type(LoadOptions.TextureBase) == "string" then table.insert(TEXTURE_BASES, 1, LoadOptions.TextureBase) end
local TextureState = {}
RequestTexture = function(name)
	if TextureState[name] or LoadOptions.NoImages or TingUI.Unloaded then return end
	if not (writefile and readfile and isfile and isfolder and makefolder and getcustomasset) then TextureState[name] = "off" return end
	TextureState[name] = "loading"
	-- deferred so the caller finishes first (a cached file loads without yielding)
	task.defer(function()
		local ok = pcall(function()
			local dir = TingUI.CacheFolder .. "/textures"
			if not isfolder(TingUI.CacheFolder) then makefolder(TingUI.CacheFolder) end
			if not isfolder(dir) then makefolder(dir) end
			dir = dir .. "/" .. TEXTURE_VERSION
			if not isfolder(dir) then makefolder(dir) end
			local path = dir .. "/" .. name .. ".png"
			if not isfile(path) then
				for _, base in ipairs(TEXTURE_BASES) do
					local okGet, data = pcall(function() return game:HttpGet(base .. name .. ".png") end)
					if okGet and type(data) == "string" and data:sub(1, 4) == "\137PNG" then
						writefile(path, data)
						break
					end
				end
			end
			if isfile(path) then TextureImages[name] = getcustomasset(path) end
		end)
		TextureState[name] = (ok and TextureImages[name]) and "done" or "failed"
		if TextureImages[name] and not TingUI.Unloaded then
			for _, fn in ipairs(Refreshers) do pcall(fn) end
			pcall(StyleVignette)
		end
	end)
end
end
end

-- Inter font: downloaded once into the TingUI folder (needs writefile + getcustomasset), otherwise Gotham stays.
if not LoadOptions.NoInter then
	task.spawn(function()
		if TingUI:_LoadInter() and not TingUI.Unloaded and TingUI.FontName == "Inter" then TingUI:SetFont("Inter", 0.4) end
	end)
end

return TingUI
end -- Build

-- Required as a ModuleScript: options come from the ModuleScript's attributes (set them in Studio's Properties panel,
-- e.g. Theme = "Ocean", Id = "MyGame", NotifyPosition = "BottomRight"). Loadstring passes them as the chunk argument.
if select("#", ...) == 0 and typeof(script) == "Instance" and script:IsA("ModuleScript") then
	local attrs = script:GetAttributes()
	return Build(next(attrs) ~= nil and attrs or nil)
end
return Build(...)
