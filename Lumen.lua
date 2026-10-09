--!nocheck
--!nolint
--[[
	Lumen UI Library  v0.0.1-stable
	Single file, no dependencies, loadstring-ready.

	local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Lumen.lua"))()

	See DOCS.md for the full API and Example.lua for a complete demo.
	Set getgenv().LumenNoInter = true before loading to skip the one-time Inter font download.
]]

local env = (getgenv and getgenv()) or _G
if env.LumenUI and type(env.LumenUI.Unload) == "function" then
	pcall(function() env.LumenUI:Unload() end)
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

local Lumen = {
	Version = "v0.0.1-stable",
	Flags = {},
	Options = {},
	Windows = {},
	Folder = "Lumen",
	Unloaded = false,
	ShowWatermark = true,
	ShowHotkeys = true,
	ShowNotifications = true,
	ShowDock = true,
	Scale = 1,
	FontName = "Inter",
	ThemeTransition = 0.3,          -- seconds colours blend when the theme changes (0 = instant)
	Preset = "Lavender",
	-- the non-colour half of a theme: shape, glow, font, particles, surface tint
	Style = { Radius = 1, Glow = 1, Font = "Inter", Particles = "Snow", ParticleColor = Color3.new(1, 1, 1) },
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
	},
}
env.LumenUI = Lumen

local Connections, Themed, Refreshers, Keybinds, FontObjs, Gradients = {}, {}, {}, {}, {}, {}
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

local function ApplyFont(obj, weight)
	if Lumen.FontName == "Mono" then
		obj.Font = Enum.Font.RobotoMono
		return
	end
	local asset = Lumen._fontAsset
	if asset then
		local ok = pcall(function() obj.FontFace = Font.new(asset, WeightEnum[weight]) end)
		if ok then return end
	end
	obj.Font = GothamByWeight[weight]
end

function Lumen:SetFont(name)
	self.FontName = name
	self._fontAsset = (name == "Inter") and self._interAsset or nil
	if self._fontDropdown then self._fontDropdown:Set(name, true) end
	for i = #FontObjs, 1, -1 do
		local e = FontObjs[i]
		if e[1].Parent == nil then table.remove(FontObjs, i) else ApplyFont(e[1], e[2]) end
	end
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
		if Lumen._fontAsset or Lumen.FontName == "Mono" then ApplyFont(obj, w) end
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
	function G:Set(mult)
		self.mult = mult
		local k = Lumen.Style.Glow or 1
		for i, st in ipairs(self.rings) do st.Transparency = 1 - math.min(1, GLOW_ALPHA[i] * mult * k) end
	end
	G:Set(1)
	function G:SetColor(c)
		for _, st in ipairs(self.rings) do st.Color = c end
	end
	return G
end

-- Surfaces: windows, panels and the dock take the theme's tint gradient, top light and scanlines.
local Surfaces = {}
local function StyleSurface(e)
	if not e.Frame.Parent then return end
	local st, T = Lumen.Style, Lumen.Theme
	local base = T.Background
	local tint = st.Tint
	local amt = (st.TintAmount or 0.15) * (e.Kind == "Window" and 1 or 0.75)
	local seq
	if tint then
		local tc = base:Lerp(tint, amt)
		local place = st.TintPlace or "Top"
		if place == "Bottom" then
			seq = ColorSequence.new({ ColorSequenceKeypoint.new(0, base), ColorSequenceKeypoint.new(0.5, base), ColorSequenceKeypoint.new(1, tc) })
		elseif place == "Aurora" then
			seq = ColorSequence.new({ ColorSequenceKeypoint.new(0, base:Lerp(tint, amt * 0.5)), ColorSequenceKeypoint.new(0.1, tc),
				ColorSequenceKeypoint.new(0.32, base), ColorSequenceKeypoint.new(1, base) })
		else
			seq = ColorSequence.new({ ColorSequenceKeypoint.new(0, tc), ColorSequenceKeypoint.new(0.45, base), ColorSequenceKeypoint.new(1, base) })
		end
	else
		seq = ColorSequence.new(base)
	end
	e.Frame.BackgroundColor3 = Color3.new(1, 1, 1)
	e.Gradient.Color = seq
	if e.Line then
		local tl = st.TopLine
		e.Line.Visible = tl ~= nil
		e.Leak.Visible = tl ~= nil
		if tl then
			local cs = ColorSequence.new(tl[1], tl[2] or tl[1])
			e.LineGrad.Color = cs
			e.LeakGrad.Color = cs
		end
	end
	if e.Kind == "Window" then
		if st.Scanlines and not e.Scan then
			e.Scan = New("Frame", {
				BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 0, Parent = e.Frame,
			})
			for y = 0, 900, 3 do
				New("Frame", {
					Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0.972, ZIndex = 0, Parent = e.Scan,
				})
			end
		end
		if e.Scan then e.Scan.Visible = st.Scanlines == true end
	end
end

local function RegisterSurface(frame, kind)
	local e = { Frame = frame, Kind = kind, Gradient = New("UIGradient", { Rotation = 90, Parent = frame }) }
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

-- Icons traced pixel-for-pixel from the reference UI: alpha runs {x, y, width, alpha/16}. They recolour like any other icon.
local PIXEL_ICONS = {
	dock_window = { w = 27, h = 25, ox = 2, oy = 3, runs = {{5,4,1,3},{6,4,16,5},{22,4,1,3},{4,5,1,2},{5,5,1,12},{6,5,16,16},{22,5,1,12},{23,5,1,2},{4,6,1,2},{5,6,1,15},{6,6,16,16},{22,6,1,15},{23,6,1,2},{4,7,1,2},{5,7,1,15},{6,7,1,14},{7,7,14,12},{21,7,1,14},{22,7,1,15},{23,7,1,2},{4,8,1,2},{5,8,1,14},{6,8,1,8},{7,8,14,3},{21,8,1,8},{22,8,1,14},{23,8,1,2},{4,9,1,2},{5,9,1,14},{6,9,1,6},{21,9,1,6},{22,9,1,14},{23,9,1,2},{4,10,1,2},{5,10,1,14},{6,10,1,6},{12,10,1,10},{13,10,6,13},{19,10,1,6},{21,10,1,6},{22,10,1,14},{23,10,1,2},{4,11,1,2},{5,11,1,14},{6,11,1,6},{12,11,2,13},{14,11,3,9},{17,11,1,10},{18,11,1,14},{19,11,1,8},{21,11,1,6},{22,11,1,14},{23,11,1,2},{4,12,1,2},{5,12,1,14},{6,12,1,6},{12,12,1,13},{13,12,1,9},{14,12,1,1},{17,12,1,4},{18,12,1,12},{19,12,1,8},{21,12,1,6},{22,12,1,14},{23,12,1,2},{4,13,1,2},{5,13,1,14},{6,13,1,6},{12,13,1,13},{13,13,1,12},{14,13,3,9},{17,13,1,10},{18,13,1,14},{19,13,1,8},{21,13,1,6},{22,13,1,14},{23,13,1,2},{4,14,1,2},{5,14,1,14},{6,14,1,6},{12,14,1,9},{13,14,5,12},{18,14,1,11},{19,14,1,5},{21,14,1,6},{22,14,1,14},{23,14,1,2},{4,15,1,2},{5,15,1,14},{6,15,1,6},{21,15,1,6},{22,15,1,14},{23,15,1,2},{4,16,1,2},{5,16,1,14},{6,16,1,6},{21,16,1,6},{22,16,1,14},{23,16,1,2},{4,17,1,2},{5,17,1,14},{6,17,1,8},{7,17,14,4},{21,17,1,8},{22,17,1,14},{23,17,1,2},{4,18,1,2},{5,18,1,12},{6,18,1,14},{7,18,14,13},{21,18,1,14},{22,18,1,12},{23,18,1,2},{5,19,1,3},{6,19,16,5},{22,19,1,3}} },
	dock_scan = { w = 27, h = 25, ox = 2, oy = 3, runs = {{5,2,1,2},{6,2,3,3},{9,2,1,2},{18,2,1,2},{19,2,3,3},{22,2,1,2},{4,3,1,2},{5,3,1,12},{6,3,1,16},{7,3,2,15},{9,3,1,12},{10,3,1,3},{17,3,1,3},{18,3,1,12},{19,3,2,15},{21,3,1,16},{22,3,1,12},{23,3,1,2},{4,4,1,3},{5,4,1,16},{6,4,1,10},{7,4,2,6},{9,4,1,5},{10,4,1,1},{17,4,1,1},{18,4,1,5},{19,4,2,6},{21,4,1,10},{22,4,1,16},{23,4,1,3},{4,5,1,3},{5,5,1,15},{6,5,1,6},{21,5,1,6},{22,5,1,15},{23,5,1,3},{4,6,1,3},{5,6,1,15},{6,6,1,6},{12,6,1,5},{13,6,2,8},{15,6,1,5},{21,6,1,6},{22,6,1,15},{23,6,1,3},{4,7,1,2},{5,7,1,12},{6,7,1,5},{11,7,1,5},{12,7,1,13},{13,7,2,14},{15,7,1,13},{16,7,1,5},{21,7,1,5},{22,7,1,12},{23,7,1,2},{5,8,1,3},{6,8,1,1},{11,8,1,11},{12,8,1,13},{13,8,2,5},{15,8,1,13},{16,8,1,11},{21,8,1,1},{22,8,1,3},{11,9,1,12},{12,9,1,11},{13,9,2,1},{15,9,2,12},{11,10,1,9},{12,10,1,15},{13,10,2,10},{15,10,1,15},{16,10,1,8},{11,11,1,1},{12,11,1,10},{13,11,2,16},{15,11,1,10},{16,11,1,1},{12,12,4,2},{9,13,1,2},{10,13,1,6},{11,13,1,11},{12,13,1,14},{13,13,2,15},{15,13,1,14},{16,13,1,11},{17,13,1,6},{18,13,1,2},{8,14,1,3},{9,14,1,12},{10,14,1,14},{11,14,1,12},{12,14,1,9},{13,14,2,7},{15,14,1,9},{16,14,1,12},{17,14,1,14},{18,14,1,12},{19,14,1,3},{5,15,1,3},{6,15,1,1},{8,15,1,8},{9,15,1,15},{10,15,1,9},{11,15,1,5},{12,15,4,4},{16,15,1,5},{17,15,1,9},{18,15,1,15},{19,15,1,8},{21,15,1,1},{22,15,1,3},{4,16,1,2},{5,16,1,12},{6,16,1,5},{8,16,1,8},{9,16,1,16},{10,16,1,14},{11,16,6,13},{17,16,1,14},{18,16,1,16},{19,16,1,8},{21,16,1,5},{22,16,1,12},{23,16,1,2},{4,17,1,3},{5,17,1,15},{6,17,1,6},{8,17,1,4},{9,17,1,8},{10,17,8,9},{18,17,1,8},{19,17,1,4},{21,17,1,6},{22,17,1,15},{23,17,1,3},{4,18,1,3},{5,18,1,15},{6,18,1,6},{21,18,1,6},{22,18,1,15},{23,18,1,3},{4,19,1,3},{5,19,1,16},{6,19,1,10},{7,19,2,6},{9,19,1,5},{10,19,1,1},{17,19,1,1},{18,19,1,5},{19,19,2,6},{21,19,1,10},{22,19,1,16},{23,19,1,3},{4,20,1,2},{5,20,1,12},{6,20,1,16},{7,20,2,15},{9,20,1,12},{10,20,1,3},{17,20,1,3},{18,20,1,12},{19,20,2,15},{21,20,1,16},{22,20,1,12},{23,20,1,2},{5,21,1,2},{6,21,3,3},{9,21,1,2},{18,21,1,2},{19,21,3,3},{22,21,1,2}} },
	dock_keyboard = { w = 27, h = 25, ox = 2, oy = 3, runs = {{5,5,1,5},{6,5,1,7},{7,5,14,8},{21,5,1,7},{22,5,1,5},{4,6,1,2},{5,6,1,13},{6,6,1,14},{7,6,14,13},{21,6,2,14},{23,6,1,2},{4,7,1,3},{5,7,1,16},{6,7,1,9},{7,7,14,4},{21,7,1,9},{22,7,1,16},{23,7,1,3},{4,8,1,3},{5,8,1,16},{6,8,1,7},{7,8,1,4},{8,8,1,6},{9,8,1,2},{10,8,1,5},{11,8,1,6},{12,8,1,1},{13,8,2,6},{15,8,1,1},{16,8,1,6},{17,8,1,5},{18,8,1,2},{19,8,1,6},{20,8,1,4},{21,8,1,7},{22,8,1,16},{23,8,1,3},{4,9,1,3},{5,9,1,16},{6,9,1,7},{7,9,1,4},{8,9,1,7},{9,9,1,2},{10,9,1,5},{11,9,1,7},{12,9,1,1},{13,9,2,6},{15,9,1,1},{16,9,2,6},{18,9,1,2},{19,9,1,7},{20,9,1,4},{21,9,1,7},{22,9,1,16},{23,9,1,3},{4,10,1,3},{5,10,1,16},{6,10,1,7},{11,10,1,1},{16,10,1,1},{21,10,1,7},{22,10,1,16},{23,10,1,3},{4,11,1,3},{5,11,1,16},{6,11,1,7},{7,11,1,4},{8,11,1,7},{9,11,1,2},{10,11,1,6},{11,11,1,7},{12,11,1,1},{13,11,2,7},{16,11,2,6},{18,11,1,2},{19,11,1,7},{20,11,1,4},{21,11,1,7},{22,11,1,16},{23,11,1,3},{4,12,1,3},{5,12,1,16},{6,12,1,7},{7,12,1,4},{8,12,1,7},{9,12,1,2},{10,12,1,5},{11,12,1,7},{12,12,1,1},{13,12,2,7},{16,12,2,6},{18,12,1,2},{19,12,1,7},{20,12,1,4},{21,12,1,7},{22,12,1,16},{23,12,1,3},{4,13,1,3},{5,13,1,16},{6,13,1,7},{10,13,8,2},{21,13,1,7},{22,13,1,16},{23,13,1,3},{4,14,1,3},{5,14,1,16},{6,14,1,6},{9,14,1,2},{10,14,1,10},{11,14,6,12},{17,14,1,10},{18,14,1,2},{21,14,1,6},{22,14,1,16},{23,14,1,3},{4,15,1,3},{5,15,1,16},{6,15,1,7},{9,15,1,2},{10,15,1,8},{11,15,6,11},{17,15,1,8},{18,15,1,2},{21,15,1,7},{22,15,1,16},{23,15,1,3},{4,16,1,3},{5,16,1,16},{6,16,1,9},{7,16,14,4},{21,16,1,9},{22,16,1,16},{23,16,1,3},{4,17,1,2},{5,17,2,14},{7,17,14,13},{21,17,1,14},{22,17,1,13},{23,17,1,2},{5,18,1,5},{6,18,1,7},{7,18,14,8},{21,18,1,7},{22,18,1,5}} },
	dock_command = { w = 27, h = 25, ox = 2, oy = 3, runs = {{7,3,1,3},{8,3,2,4},{10,3,1,2},{17,3,1,2},{18,3,2,4},{20,3,1,3},{6,4,1,5},{7,4,1,13},{8,4,1,15},{9,4,1,14},{10,4,1,9},{11,4,1,2},{16,4,1,2},{17,4,1,9},{18,4,1,14},{19,4,1,15},{20,4,1,12},{21,4,1,5},{5,5,1,3},{6,5,1,13},{7,5,1,12},{8,5,1,7},{9,5,1,9},{10,5,1,15},{11,5,1,7},{16,5,1,7},{17,5,1,15},{18,5,1,9},{19,5,1,7},{20,5,2,12},{22,5,1,3},{5,6,1,4},{6,6,1,15},{7,6,1,7},{9,6,1,2},{10,6,1,13},{11,6,1,11},{12,6,1,1},{15,6,1,2},{16,6,1,11},{17,6,1,13},{18,6,1,2},{20,6,1,7},{21,6,1,15},{22,6,1,4},{5,7,1,4},{6,7,1,14},{7,7,1,9},{8,7,1,2},{10,7,1,12},{11,7,1,11},{12,7,1,2},{15,7,1,2},{16,7,1,11},{17,7,1,12},{19,7,1,2},{20,7,1,9},{21,7,1,14},{22,7,1,4},{5,8,1,2},{6,8,1,9},{7,8,1,15},{8,8,1,13},{9,8,1,12},{10,8,2,16},{12,8,1,13},{13,8,2,12},{15,8,1,13},{16,8,2,16},{18,8,1,12},{19,8,1,13},{20,8,1,15},{21,8,1,9},{22,8,1,2},{6,9,1,2},{7,9,1,7},{8,9,2,11},{10,9,2,16},{12,9,1,12},{13,9,2,11},{15,9,1,12},{16,9,2,16},{18,9,2,11},{20,9,1,7},{21,9,1,2},{8,10,1,1},{9,10,1,2},{10,10,1,13},{11,10,1,12},{12,10,1,3},{13,10,2,2},{15,10,1,3},{16,10,1,12},{17,10,1,13},{18,10,1,2},{19,10,1,1},{10,11,1,12},{11,11,1,11},{12,11,1,2},{15,11,1,2},{16,11,1,11},{17,11,1,12},{10,12,1,12},{11,12,1,11},{12,12,1,2},{15,12,1,2},{16,12,1,11},{17,12,1,12},{8,13,1,1},{9,13,1,2},{10,13,1,13},{11,13,1,12},{12,13,1,3},{13,13,2,2},{15,13,1,3},{16,13,1,12},{17,13,1,13},{18,13,1,2},{19,13,1,1},{6,14,1,2},{7,14,1,7},{8,14,2,11},{10,14,2,16},{12,14,1,12},{13,14,2,11},{15,14,1,12},{16,14,2,16},{18,14,2,11},{20,14,1,7},{21,14,1,2},{5,15,1,2},{6,15,1,9},{7,15,1,15},{8,15,1,13},{9,15,1,12},{10,15,2,16},{12,15,1,13},{13,15,2,12},{15,15,1,13},{16,15,2,16},{18,15,1,12},{19,15,1,13},{20,15,1,15},{21,15,1,9},{22,15,1,2},{5,16,1,4},{6,16,1,14},{7,16,1,9},{8,16,1,2},{10,16,1,12},{11,16,1,11},{12,16,1,2},{15,16,1,2},{16,16,1,11},{17,16,1,12},{19,16,1,2},{20,16,1,9},{21,16,1,14},{22,16,1,4},{5,17,1,4},{6,17,1,15},{7,17,1,7},{9,17,1,2},{10,17,1,13},{11,17,1,11},{12,17,1,1},{15,17,1,1},{16,17,1,11},{17,17,1,13},{18,17,1,2},{20,17,1,7},{21,17,1,14},{22,17,1,4},{5,18,1,3},{6,18,1,12},{7,18,1,13},{8,18,1,7},{9,18,1,9},{10,18,1,15},{11,18,1,7},{16,18,1,7},{17,18,1,15},{18,18,1,9},{19,18,1,7},{20,18,2,12},{22,18,1,3},{6,19,1,5},{7,19,1,12},{8,19,1,15},{9,19,1,14},{10,19,1,9},{11,19,1,2},{16,19,1,2},{17,19,1,9},{18,19,1,14},{19,19,1,15},{20,19,1,12},{21,19,1,5},{7,20,1,3},{8,20,2,4},{10,20,1,2},{17,20,1,2},{18,20,2,4},{20,20,1,3}} },
	dock_user = { w = 27, h = 25, ox = 2, oy = 3, runs = {{12,4,1,1},{13,4,2,3},{15,4,1,1},{11,5,1,3},{12,5,1,8},{13,5,2,11},{15,5,1,8},{16,5,1,3},{10,6,1,2},{11,6,1,10},{12,6,1,15},{13,6,2,16},{15,6,1,15},{16,6,1,10},{17,6,1,2},{10,7,1,6},{11,7,1,14},{12,7,4,16},{16,7,1,14},{17,7,1,6},{10,8,1,8},{11,8,1,15},{12,8,4,16},{16,8,1,15},{17,8,1,8},{10,9,1,6},{11,9,1,14},{12,9,4,16},{16,9,1,14},{17,9,1,6},{10,10,1,2},{11,10,1,12},{12,10,1,15},{13,10,2,16},{15,10,1,15},{16,10,1,12},{17,10,1,2},{11,11,1,3},{12,11,1,10},{13,11,2,14},{15,11,1,10},{16,11,1,3},{17,12,1,1},{9,13,1,1},{10,13,1,3},{11,13,1,5},{12,13,1,7},{13,13,1,8},{14,13,1,1},{15,13,1,2},{16,13,1,10},{17,13,1,14},{18,13,1,10},{19,13,1,6},{20,13,1,11},{21,13,1,14},{22,13,1,8},{7,14,1,2},{8,14,1,6},{9,14,1,10},{10,14,1,14},{11,14,3,16},{14,14,1,5},{15,14,1,4},{16,14,6,16},{22,14,1,14},{23,14,1,2},{6,15,1,2},{7,15,1,9},{8,15,1,15},{9,15,5,16},{14,15,1,7},{15,15,1,4},{16,15,1,14},{17,15,5,16},{22,15,1,13},{23,15,1,2},{6,16,1,4},{7,16,1,14},{8,16,6,16},{14,16,1,12},{15,16,1,3},{16,16,1,7},{17,16,1,14},{18,16,3,16},{21,16,1,13},{22,16,1,6},{6,17,1,5},{7,17,7,16},{14,17,1,15},{15,17,1,9},{16,17,1,3},{17,17,1,7},{18,17,1,14},{19,17,1,16},{20,17,1,13},{21,17,1,6},{6,18,1,4},{7,18,1,13},{8,18,7,16},{15,18,1,14},{16,18,1,6},{17,18,1,2},{18,18,1,7},{19,18,1,10},{20,18,1,6},{7,19,1,4},{8,19,8,5},{16,19,1,2},{18,19,1,1},{19,19,1,2}} },
	hotkeys_kb = { w = 19, h = 13, ox = 1, oy = 1, runs = {{1,0,1,8},{2,0,15,12},{17,0,1,8},{0,1,1,4},{1,1,1,16},{2,1,1,13},{3,1,13,11},{16,1,1,13},{17,1,1,16},{18,1,1,4},{0,2,1,4},{1,2,1,16},{2,2,1,6},{16,2,1,6},{17,2,1,16},{18,2,1,4},{0,3,1,4},{1,3,1,16},{2,3,1,6},{3,3,2,8},{6,3,1,10},{7,3,1,7},{8,3,1,4},{9,3,1,9},{10,3,1,4},{11,3,1,7},{12,3,1,11},{14,3,2,8},{16,3,1,6},{17,3,1,16},{18,3,1,4},{0,4,1,4},{1,4,1,16},{2,4,1,6},{3,4,2,4},{6,4,1,6},{7,4,1,4},{9,4,1,5},{11,4,1,4},{12,4,1,6},{14,4,2,4},{16,4,1,6},{17,4,1,16},{18,4,1,4},{0,5,1,4},{1,5,1,16},{2,5,1,6},{6,5,1,3},{12,5,1,3},{16,5,1,6},{17,5,1,16},{18,5,1,4},{0,6,1,4},{1,6,1,16},{2,6,3,6},{6,6,1,8},{7,6,1,5},{9,6,1,7},{11,6,1,5},{12,6,1,9},{14,6,3,6},{17,6,1,16},{18,6,1,4},{0,7,1,4},{1,7,1,16},{2,7,1,6},{6,7,1,3},{12,7,1,4},{16,7,1,6},{17,7,1,16},{18,7,1,4},{0,8,1,4},{1,8,1,16},{2,8,1,5},{6,8,7,10},{16,8,1,5},{17,8,1,16},{18,8,1,4},{0,9,1,4},{1,9,1,16},{2,9,1,5},{5,9,1,5},{6,9,1,15},{7,9,6,16},{13,9,1,5},{16,9,1,5},{17,9,1,16},{18,9,1,4},{0,10,1,4},{1,10,1,16},{2,10,1,6},{16,10,1,6},{17,10,1,16},{18,10,1,4},{0,11,1,4},{1,11,1,16},{2,11,1,13},{3,11,13,11},{16,11,1,13},{17,11,1,16},{18,11,1,4},{1,12,1,8},{2,12,15,12},{17,12,1,8}} },
	bell = { w = 14, h = 16, ox = 2, oy = 1, runs = {{6,0,2,6},{2,1,1,7},{3,1,1,4},{5,1,1,5},{6,1,2,13},{8,1,1,5},{10,1,1,4},{11,1,1,7},{1,2,1,8},{2,2,1,10},{3,2,1,4},{4,2,1,7},{5,2,1,13},{6,2,2,15},{8,2,1,13},{9,2,1,7},{10,2,1,4},{11,2,1,10},{12,2,1,8},{1,3,1,12},{2,3,1,7},{3,3,1,8},{4,3,1,14},{5,3,1,15},{6,3,2,16},{8,3,1,15},{9,3,1,14},{10,3,1,8},{11,3,1,7},{12,3,1,12},{0,4,1,7},{1,4,1,10},{2,4,1,6},{3,4,1,13},{4,4,6,16},{10,4,1,13},{11,4,1,6},{12,4,1,10},{13,4,1,7},{0,5,1,9},{1,5,1,7},{2,5,1,8},{3,5,1,15},{4,5,6,16},{10,5,1,15},{11,5,1,8},{12,5,1,7},{13,5,1,9},{0,6,1,4},{2,6,1,8},{3,6,8,16},{11,6,1,8},{13,6,1,4},{2,7,1,8},{3,7,8,16},{11,7,1,8},{2,8,1,8},{3,8,8,16},{11,8,1,8},{2,9,1,8},{3,9,8,16},{11,9,1,8},{2,10,1,8},{3,10,8,16},{11,10,1,8},{2,11,1,9},{3,11,8,16},{11,11,1,9},{1,12,1,8},{2,12,1,12},{3,12,8,14},{11,12,1,12},{12,12,1,8},{1,13,4,4},{5,13,4,5},{9,13,4,4},{5,14,1,7},{6,14,2,14},{8,14,1,6},{6,15,2,6}} },
	group_command = { w = 14, h = 14, ox = 4, oy = 6, runs = {{1,0,1,7},{2,0,2,10},{4,0,1,6},{9,0,1,6},{10,0,2,11},{12,0,1,8},{0,1,1,7},{1,1,1,14},{2,1,1,8},{3,1,1,10},{4,1,1,12},{5,1,1,7},{8,1,1,7},{9,1,1,13},{10,1,1,10},{11,1,1,9},{12,1,1,15},{13,1,1,7},{0,2,1,11},{1,2,1,8},{4,2,1,9},{5,2,1,12},{8,2,1,12},{9,2,1,9},{12,2,1,9},{13,2,1,10},{0,3,1,11},{1,3,1,10},{4,3,1,8},{5,3,1,13},{8,3,1,13},{9,3,1,8},{12,3,2,10},{0,4,1,6},{1,4,1,13},{2,4,1,10},{3,4,1,9},{4,4,1,12},{5,4,1,15},{6,4,2,8},{8,4,1,15},{9,4,1,12},{10,4,1,9},{11,4,1,10},{12,4,1,13},{13,4,1,6},{1,5,1,8},{2,5,1,12},{3,5,1,13},{4,5,1,15},{5,5,1,16},{6,5,2,13},{8,5,1,16},{9,5,1,15},{10,5,1,13},{11,5,1,12},{12,5,1,8},{4,6,1,9},{5,6,1,13},{8,6,1,13},{9,6,1,8},{4,7,1,9},{5,7,1,13},{8,7,1,13},{9,7,1,8},{1,8,1,7},{2,8,1,12},{3,8,1,13},{4,8,1,15},{5,8,1,16},{6,8,2,13},{8,8,1,16},{9,8,1,15},{10,8,1,13},{11,8,1,12},{12,8,1,7},{0,9,1,6},{1,9,1,12},{2,9,1,9},{3,9,1,8},{4,9,1,13},{5,9,1,15},{6,9,2,9},{8,9,1,15},{9,9,1,12},{10,9,1,8},{11,9,1,9},{12,9,1,13},{13,9,1,6},{0,10,2,10},{4,10,1,9},{5,10,1,13},{8,10,1,13},{9,10,1,8},{12,10,2,10},{0,11,1,11},{1,11,1,8},{4,11,1,9},{5,11,1,12},{8,11,1,12},{9,11,1,9},{12,11,1,8},{13,11,1,10},{0,12,1,7},{1,12,1,14},{2,12,1,8},{3,12,1,10},{4,12,1,13},{5,12,1,7},{8,12,1,7},{9,12,1,13},{10,12,1,10},{11,12,1,8},{12,12,1,14},{13,12,1,7},{1,13,1,7},{2,13,2,10},{4,13,1,6},{9,13,1,6},{10,13,2,10},{12,13,1,7}} },
}

local function PixelIcon(name, parent, colorKey)
	local d = PIXEL_ICONS[name]
	if not d then return nil end
	local f = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(d.w, d.h), Parent = parent })
	for _, r in ipairs(d.runs) do
		New("Frame", {
			Position = UDim2.fromOffset(r[1], r[2]), Size = UDim2.fromOffset(r[3], 1), BackgroundTransparency = 1 - r[4] / 16,
			Parent = f, Theme = { BackgroundColor3 = colorKey or "Label" },
		})
	end
	return f
end

-- Vector icons drawn from frames: window, keyboard, command, scan, bell, user, gear, snow, list, discord
local function Icon(kind, parent, size, colorKey)
	size = size or 16
	colorKey = colorKey or "Label"
	local s = size / 16
	local f = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Parent = parent })
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
	if kind == "window" then
		Ring(1, 2, 14, 12, 3, 1.5)
		Bar(1.6, 5.2, 12.8, 1.4)
		Ring(7.2, 8.4, 5.2, 3.2, 1, 1.2)
	elseif kind == "keyboard" then
		Ring(0.6, 3, 14.8, 10, 2.5, 1.4)
		for _, x in ipairs({ 3.2, 5.9, 8.6, 11.3 }) do Bar(x, 5.4, 1.5, 1.5) Bar(x, 7.9, 1.5, 1.5) end
		Bar(4.6, 10.5, 6.8, 1.3, 0.6)
	elseif kind == "command" then
		Ring(5, 5, 6, 6, 0.5, 1.3)
		Ring(1.4, 1.4, 4.6, 4.6, 2.3, 1.3)
		Ring(10, 1.4, 4.6, 4.6, 2.3, 1.3)
		Ring(1.4, 10, 4.6, 4.6, 2.3, 1.3)
		Ring(10, 10, 4.6, 4.6, 2.3, 1.3)
	elseif kind == "scan" then
		Bar(1, 1, 4, 1.4); Bar(1, 1, 1.4, 4)
		Bar(11, 1, 4, 1.4); Bar(13.6, 1, 1.4, 4)
		Bar(1, 13.6, 4, 1.4); Bar(1, 11, 1.4, 4)
		Bar(11, 13.6, 4, 1.4); Bar(13.6, 11, 1.4, 4)
		Ring(6, 4.2, 4, 4, 2, 1.3)
		Ring(4.6, 9.4, 6.8, 3, 1.5, 1.3)
	elseif kind == "bell" then
		Bar(7.2, 1, 1.6, 1.8)
		Bar(4, 2.5, 8, 8, 4)
		Bar(3, 8, 10, 3.2, 1)
		Bar(2, 11, 12, 1.6, 1)
		Bar(6.5, 13, 3, 2, 1)
	elseif kind == "user" then
		Bar(5, 1.5, 6, 6, 3)
		Bar(2.5, 9, 11, 5.5, 3)
	elseif kind == "gear" then
		Ring(2.5, 2.5, 11, 11, 5.5, 2)
		Bar(6, 6, 4, 4, 2)
	elseif kind == "snow" then
		for _, rot in ipairs({ 0, 60, 120 }) do Bar(1, 7.2, 14, 1.6).Rotation = rot end
	elseif kind == "list" then
		Bar(2, 3.5, 12, 1.6); Bar(2, 7.2, 12, 1.6); Bar(2, 10.9, 12, 1.6)
	elseif kind == "check" then
		local a = Bar(3, 8.9, 5.4, 2, 1); a.Rotation = 45
		local b = Bar(5.4, 7.2, 9.6, 2, 1); b.Rotation = -52
	elseif kind == "cross" then
		Bar(2.5, 7, 11, 2, 1).Rotation = 45
		Bar(2.5, 7, 11, 2, 1).Rotation = -45
	elseif kind == "warn" then
		Ring(1.2, 1.2, 13.6, 13.6, 6.8, 1.6)
		Bar(7.1, 4.2, 1.8, 5.2, 0.9)
		Bar(7.1, 10.4, 1.8, 1.8, 0.9)
	elseif kind == "info" then
		Ring(1.2, 1.2, 13.6, 13.6, 6.8, 1.6)
		Bar(7.1, 7, 1.8, 5.2, 0.9)
		Bar(7.1, 4, 1.8, 1.8, 0.9)
	elseif kind == "discord" then
		Bar(2.4, 1.8, 4, 4, 2); Bar(9.6, 1.8, 4, 4, 2)
		Bar(1, 3.8, 14, 9.4, 4.7)
		Bar(4.4, 7.2, 2.2, 3, 1.1, "Background"); Bar(9.4, 7.2, 2.2, 3, 1.1, "Background")
	end
	return f
end

local function RecolorIcon(f, color)
	for _, d in ipairs(f:GetDescendants()) do
		if d:IsA("UIStroke") then
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

function Lumen:ApplyPreset(name)
	local p = self.Presets[name]
	if not p then return end
	self.Preset = name
	local colors = {}
	for k, v in pairs(p) do if k ~= "Style" then colors[k] = v end end
	self:SetTheme(colors, self.ThemeTransition)
	self:SetStyle(p.Style or {})
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
Gui.Name = "LumenUI"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 10000
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
do
	if syn and syn.protect_gui then pcall(syn.protect_gui, Gui) end
	local ok = false
	if gethui then ok = pcall(function() Gui.Parent = gethui() end) end
	if not ok or not Gui.Parent then ok = pcall(function() Gui.Parent = Service("CoreGui") end) end
	if not ok or not Gui.Parent then Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
end

Overlay = New("Frame", {
	Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = Gui,
})

local PopupCatcher = New("TextButton", {
	Name = "PopupCatcher", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 1,
	Active = true, Parent = Overlay,
})

local function ClosePopup()
	PopupCatcher.Visible = false
	if OpenPopup then
		local p = OpenPopup
		OpenPopup = nil
		p.Frame.Visible = false
		if p.OnClose then p.OnClose() end
	end
end

Connect(PopupCatcher.MouseButton1Down, function() ClosePopup() end)
Connect(PopupCatcher.MouseButton2Down, function() ClosePopup() end)

local function ShowPopup(frame, trigger, onClose)
	ClosePopup()
	local sc = frame:FindFirstChildOfClass("UIScale")
	if not sc then sc = New("UIScale", { Parent = frame }) end
	sc.Scale = Lumen.Scale
	local vp = Gui.AbsoluteSize
	local w, h = frame.Size.X.Offset * Lumen.Scale, frame.Size.Y.Offset * Lumen.Scale
	local tp, ts = trigger.AbsolutePosition, trigger.AbsoluteSize
	local x = math.clamp(tp.X, 6, math.max(6, vp.X - w - 6))
	local y = tp.Y + ts.Y + 4
	if y + h > vp.Y - 6 then y = math.max(6, tp.Y - h - 4) end
	frame.Position = UDim2.fromOffset(x, y)
	frame.ZIndex = 5
	PopupCatcher.Visible = true
	frame.Visible = true
	OpenPopup = { Frame = frame, Trigger = trigger, OnClose = onClose }
end

local TooltipFrame = New("Frame", {
	Visible = false, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0),
	ZIndex = 200, Parent = Gui, Theme = { BackgroundColor3 = "Background" },
}, { Corner(5), Stroke("Border"), Pad(9, 6, 9, 6) })
local TooltipLabel = New("TextLabel", {
	AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), TextSize = 11, Parent = TooltipFrame,
})

local function AttachTooltip(inst, text)
	Connect(inst.MouseEnter, function()
		TooltipLabel.Text = text
		local ap, sz = inst.AbsolutePosition, inst.AbsoluteSize
		local vp = Gui.AbsoluteSize
		TooltipFrame.Position = UDim2.fromOffset(math.clamp(ap.X, 6, math.max(6, vp.X - 260)), ap.Y + sz.Y + 6)
		TooltipFrame.Visible = true
	end)
	Connect(inst.MouseLeave, function() TooltipFrame.Visible = false end)
end

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
	if opt.Flag then Lumen.Flags[opt.Flag] = opt.Value end
	if opt.Callback then task.spawn(opt.Callback, ...) end
	for _, cb in ipairs(opt.Listeners) do task.spawn(cb, ...) end
end

-- everything searchable from the command palette
Lumen._Catalog = {}
Lumen._Panels = {}
local function CatalogAdd(group, opt, name)
	if not name then return end
	table.insert(Lumen._Catalog, { Opt = opt, Name = name, Path = group._path or "", Tab = group._tab })
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
	Success = { Key = "Success", Icon = "check" },
	Warning = { Key = "Caution", Icon = "warn" },
	Caution = { Key = "Caution", Icon = "warn" },
	Danger = { Key = "Error", Icon = "cross" },
	Error = { Key = "Error", Icon = "cross" },
	Info = { Key = "Info", Icon = "info" },
	Loading = { Key = "Accent", Icon = "spinner" },
}
local NotifyCount = 0
local LiveNotifs = {}

local function Spinner(parent, color)
	local f = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(14, 14), Parent = parent }, {
		CornerFixed(7),
		New("UIStroke", { Thickness = 2, Color = color }, {
			New("UIGradient", { Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(0.52, 1), NumberSequenceKeypoint.new(1, 1) }) }),
		}),
	})
	return f
end

-- o: string, or {Title, Content, Type = "Success" | "Warning" | "Error" | "Info" | "Loading", Duration, Progress}
-- Returns a handle: handle:Update({...}) morphs it in place (e.g. Loading -> Success), handle:Dismiss() closes it.
-- Hovering pauses the countdown, clicking dismisses.
function Lumen:Notify(o, duration)
	if type(o) == "string" then o = { Content = o, Duration = duration } end
	local H = { Closed = false }
	function H:Update() end
	function H:Dismiss() end
	if not self.ShowNotifications then return H end

	NotifyCount = NotifyCount + 1
	local holder = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(290, 0), LayoutOrder = NotifyCount, Parent = NotifHolder,
	})
	local card = New("CanvasGroup", {
		Size = UDim2.fromOffset(280, 34), Position = UDim2.fromOffset(310, 0), GroupTransparency = 1, AnchorPoint = Vector2.new(0, 0),
		Parent = holder, Theme = { BackgroundColor3 = "Background" },
	}, { Corner(8) })
	New("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Theme = { Color = "Outline" }, Parent = card })
	local body = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 2, Parent = card,
	}, { Pad(12, 9, 12, 9), New("UISizeConstraint", { MinSize = Vector2.new(0, 34) }),
		List(10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local bar = New("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 3, Parent = card })
	local barGrad = New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.6) }), Parent = bar })
	local wash = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 1, Parent = card })
	local washGrad = New("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.86), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(1, 1) }), Parent = wash })
	local shine = New("Frame", {
		Size = UDim2.new(0.45, 0, 1, 0), Position = UDim2.new(-0.6, 0, 0, 0), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 4, Parent = card,
	}, { New("UIGradient", { Rotation = 18, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 1) }) }) })
	local track = New("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 2), Visible = false, ZIndex = 3,
		Parent = card, Theme = { BackgroundColor3 = "Outline" },
	})
	local fill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = track })

	local kind, color, dur, remaining, hovered, shakeT = nil, nil, 4, 4, false, 0
	local iconScale, spin
	local conn

	local function Fit()
		local h = math.max(34, body.AbsoluteSize.Y)
		card.Size = UDim2.fromOffset(280, h)
		if not H.Closed then Tween(holder, 0.25, { Size = UDim2.fromOffset(290, h + 6) }) end
	end
	Connect(body:GetPropertyChangedSignal("AbsoluteSize"), Fit)

	local function Build(opts)
		for _, c in ipairs(body:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
		spin = nil
		kind = NOTIFY_KINDS[opts.Type or ""]
		color = kind and Lumen.Theme[kind.Key] or Lumen.Theme.Label
		-- icon: tinted badge for typed notifications, the reference bell for plain ones
		local iconHolder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(kind and 24 or 16, kind and 24 or 16), LayoutOrder = 1, Parent = body })
		iconScale = New("UIScale", { Scale = 1, Parent = iconHolder })
		if kind then
			local badge = New("Frame", {
				Size = UDim2.fromScale(1, 1), BackgroundColor3 = color:Lerp(Lumen.Theme.Background, 0.8), Parent = iconHolder,
			}, { CornerFixed(12), New("UIStroke", { Color = color:Lerp(Lumen.Theme.Background, 0.45), Thickness = 1 }) })
			if kind.Icon == "spinner" then
				spin = Spinner(badge, color)
				spin.AnchorPoint = Vector2.new(0.5, 0.5)
				spin.Position = UDim2.fromScale(0.5, 0.5)
			else
				local ic = Icon(kind.Icon, badge, 14, kind.Key)
				ic.AnchorPoint = Vector2.new(0.5, 0.5)
				ic.Position = UDim2.fromScale(0.5, 0.5)
			end
		else
			local bell = PixelIcon("bell", iconHolder, "Label")
			bell.Position = UDim2.fromOffset(1, 0)
		end
		local text = New("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, -(kind and 34 or 26), 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2, Parent = body,
		}, { List(2) })
		if opts.Title then
			New("TextLabel", {
				Size = UDim2.new(1, 0, 0, 16), Text = opts.Title, TextColor3 = kind and color or Lumen.Theme.Text,
				TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = text,
			})
		end
		if opts.Content then
			New("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = opts.Content, TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, TextSize = opts.Title and 11 or 12,
				Font = opts.Title and Enum.Font.GothamMedium or Enum.Font.GothamSemibold,
				TextColor3 = opts.Title and Lumen.Theme.TextDim or Lumen.Theme.Label, Parent = text,
			})
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
		fill.Size = UDim2.fromScale(1, 1)
		-- entrance flourishes
		iconScale.Scale = 0.35
		Tween(iconScale, 0.5, { Scale = 1 })
		pcall(function()
			TweenService:Create(iconScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)
		shine.Position = UDim2.new(-0.6, 0, 0, 0)
		TweenService:Create(shine, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Position = UDim2.new(1.2, 0, 0, 0) }):Play()
		if kind and kind.Key == "Error" then shakeT = 0.45 end
		Fit()
	end

	local function Close()
		if H.Closed then return end
		H.Closed = true
		if conn then conn:Disconnect() end
		for i, n in ipairs(LiveNotifs) do if n == H then table.remove(LiveNotifs, i) break end end
		TweenService:Create(card, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(310, 0), GroupTransparency = 1 }):Play()
		task.delay(0.22, function()
			if holder.Parent then Tween(holder, 0.22, { Size = UDim2.fromOffset(290, 0) }) end
		end)
		task.delay(0.5, function() holder:Destroy() end)
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
		Tween(card, 0.15, { Position = UDim2.fromOffset(-4, 0) })
	end)
	Connect(card.MouseLeave, function()
		hovered = false
		if not H.Closed then Tween(card, 0.15, { Position = UDim2.fromOffset(0, 0) }) end
	end)
	Connect(card.InputBegan, function(i) if IsPress(i) then Close() end end)

	conn = RunService.RenderStepped:Connect(function(dt)
		if H.Closed then return end
		local t = os.clock()
		if spin then spin.Rotation = (spin.Rotation + dt * 360) % 360 end
		if kind then
			-- the accent bar breathes; warnings and errors breathe harder
			local k = (kind.Key == "Caution" or kind.Key == "Error") and 0.35 or 0.18
			bar.BackgroundTransparency = k * (0.5 + 0.5 * math.sin(t * 4))
		end
		if shakeT > 0 then
			shakeT = math.max(0, shakeT - dt)
			card.Position = UDim2.fromOffset(math.sin(shakeT * 70) * 7 * (shakeT / 0.45), 0)
		end
		if not hovered and remaining ~= math.huge then
			remaining = remaining - dt
			fill.Size = UDim2.fromScale(math.clamp(remaining / dur, 0, 1), 1)
			if remaining <= 0 then Close() end
		end
	end)
	table.insert(Connections, conn)

	Build(o)
	-- slide in from the right with a little overshoot
	card.Position = UDim2.fromOffset(310, 0)
	card.GroupTransparency = 1
	TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, 0) }):Play()
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
local HotkeyIcon = PixelIcon("hotkeys_kb", HotkeyTitle, "Label")
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
	if o.Tooltip then AttachTooltip(swatch, o.Tooltip) end

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
	local lbl = New("TextLabel", {
		Text = T._text, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -26, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, Parent = row,
	})

	local function Colors()
		local TH = Lumen.Theme
		if T.Disabled then
			return TH.Toggle:Lerp(TH.Background, 0.55), TH.AccentBorder:Lerp(TH.Background, 0.7), TH.TextMuted
		end
		return T.Value and TH.Accent or TH.Toggle, TH.AccentBorder, TH.Label
	end
	local function Render(instant)
		local fill, border, text = Colors()
		stroke.Color = border
		lbl.TextColor3 = text
		if instant then box.BackgroundColor3 = fill else Tween(box, 0.12, { BackgroundColor3 = fill }) end
		glow:Set(T.Disabled and 0 or 1)
	end
	T._onDisabled = function() Render() end
	table.insert(Refreshers, function() Render(true) end)

	function T:Set(v, silent)
		v = v and true or false
		if self.Value == v then return end
		self.Value = v
		Render()
		if not silent then Fire(self, v) end
		if self._kb then Lumen:_UpdateHotkeys() end
	end
	Connect(btn.MouseButton1Click, function() T:Set(not T.Value) end)
	Connect(btn.MouseEnter, function()
		if not T.Disabled then Tween(box, 0.1, { BackgroundColor3 = (Colors()):Lerp(Color3.new(1, 1, 1), 0.07) }) end
	end)
	Connect(btn.MouseLeave, function() Render() end)

	Register(T, o.Flag)
	CatalogAdd(self, T, T._text)
	Render(true)
	if o.Disabled then T:SetDisabled(true) end
	if o.Tooltip then T:AddTooltip(o.Tooltip) end
	return T
end

function Elements:AddSlider(o)
	o = o or {}
	local S = NewOpt("Slider", o)
	S.Min, S.Max, S.Inc, S.Suffix = o.Min or 0, o.Max or 100, o.Increment or 1, o.Suffix or ""
	S.Value = math.clamp(o.Default or S.Min, S.Min, S.Max)
	local dec = #((tostring(S.Inc):match("%.(%d+)")) or "")
	local row = Row(self._container, 32)
	S.Row = row

	New("TextLabel", {
		Text = o.Text or "Slider", Size = UDim2.new(0.6, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
	})
	local valueLabel = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.4, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
	})
	local track = New("Frame", {
		Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 4), Parent = row, Theme = { BackgroundColor3 = "Group" },
	}, { Corner(3), Stroke("Outline") })
	local fill = New("Frame", {
		Size = UDim2.new(0, 0, 1, 0), Parent = track, Theme = { BackgroundColor3 = "Accent" },
	}, { Corner(3) })
	local knob = New("Frame", {
		Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = fill,
	}, { CornerFixed(4) })
	Glow(knob, Color3.new(1, 1, 1), 4, true):Set(0.2)
	local hit = New("TextButton", { Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 18), Parent = row })

	local function Render()
		local a = (S.Value - S.Min) / math.max(S.Max - S.Min, 1e-9)
		fill.Size = UDim2.new(a, 0, 1, 0)
		valueLabel.Text = string.format("%." .. dec .. "f", S.Value) .. S.Suffix
	end
	function S:Set(v, silent)
		v = tonumber(v)
		if not v then return end
		v = math.clamp(S.Min + math.floor((v - S.Min) / S.Inc + 0.5) * S.Inc, S.Min, S.Max)
		v = tonumber(string.format("%." .. dec .. "f", v))
		if v == S.Value then return end
		S.Value = v
		Render()
		if not silent then Fire(S, v) end
	end
	Dragger(hit, function(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		S:Set(S.Min + a * (S.Max - S.Min))
	end)
	Register(S, o.Flag)
	CatalogAdd(self, S, o.Text or "Slider")
	Render()
	if o.Disabled then S:SetDisabled(true) end
	return S
end

local function Chevron(parent)
	local f = New("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
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
	local valueText = New("TextLabel", {
		Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -30, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Font = Enum.Font.GothamMedium, Parent = box,
	})
	Chevron(box)
	Connect(box.MouseEnter, function() Tween(stroke, 0.1, { Color = Lumen.Theme.Border }) end)
	Connect(box.MouseLeave, function() Tween(stroke, 0.1, { Color = Lumen.Theme.Outline }) end)

	local pop = New("Frame", {
		Visible = false, Size = UDim2.fromOffset(200, 100), Parent = Overlay, Theme = { BackgroundColor3 = "Background" },
	}, { Corner(7), Stroke("Border") })
	local scroll = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 2, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = pop, Theme = { ScrollBarImageColor3 = "Accent" },
	}, { Pad(4), List(2) })

	local items = {}
	local function IsSelected(v)
		if D.Multi then return D.Value[v] == true end
		return D.Value == v
	end
	local function Render()
		if D.Multi then
			local sel = {}
			for _, v in ipairs(D.Values) do if D.Value[v] then table.insert(sel, v) end end
			valueText.Text = #sel > 0 and table.concat(sel, ", ") or "--"
		else
			valueText.Text = D.Value ~= nil and tostring(D.Value) or "--"
		end
		valueText.TextColor3 = (valueText.Text == "--") and Lumen.Theme.TextDim or Lumen.Theme.Label
		for v, b in pairs(items) do
			b.TextColor3 = IsSelected(v) and Lumen.Theme.AccentText or Lumen.Theme.Label
			b.BackgroundTransparency = IsSelected(v) and 0 or 1
		end
	end
	table.insert(Refreshers, Render)
	local function PopupSize()
		pop.Size = UDim2.fromOffset(math.max(box.AbsoluteSize.X / Lumen.Scale, 120), math.min(#D.Values * 26 + 8, 184))
	end
	local function Build()
		for _, b in pairs(items) do b:Destroy() end
		items = {}
		for i, v in ipairs(D.Values) do
			local b = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 24), Text = tostring(v), TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = i, Parent = scroll, Theme = { BackgroundColor3 = "TabActive" },
			}, { Corner(5), Pad(8, 0, 8, 0) })
			items[v] = b
			Connect(b.MouseButton1Click, function()
				if D.Multi then
					local nv = {}
					for k in pairs(D.Value) do nv[k] = true end
					nv[v] = (not nv[v]) or nil
					D:Set(nv)
				else
					D:Set(v)
					ClosePopup()
				end
			end)
		end
		PopupSize()
		Render()
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
			ShowPopup(pop, box)
		end
	end)

	Build()
	if o.Default ~= nil then D:Set(o.Default, true) end
	Register(D, o.Flag)
	CatalogAdd(self, D, o.Text or "Dropdown")
	Render()
	if o.Disabled then D:SetDisabled(true) end
	return D
end

function Elements:AddInput(o)
	o = type(o) == "string" and { Text = o } or o or {}
	local I = NewOpt("Input", o)
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
	return I
end

function Elements:AddButton(o)
	o = type(o) == "string" and { Text = o } or o or {}
	local B = NewOpt("Button", {})
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
		if opts.Tooltip then AttachTooltip(b, opts.Tooltip) end
		local confirming = false
		local original = b.Text
		Connect(b.MouseEnter, function() Tween(b, 0.1, { BackgroundColor3 = Lumen.Theme.ControlHover }) end)
		Connect(b.MouseLeave, function() Tween(b, 0.1, { BackgroundColor3 = Lumen.Theme.Control }) end)
		local function Press()
			if opts.Confirm then
				local c = {}
				for k, v in pairs(opts.Confirm) do c[k] = v end
				c.Callback = function(ok) if ok and opts.Callback then opts.Callback() end end
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
			if opts.Callback then task.spawn(opts.Callback) end
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
			New("UIStroke", { Color = col, Thickness = 1, Parent = esp.Box })
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
	local function CharacterClone()
		local ch = Players.LocalPlayer and Players.LocalPlayer.Character
		if not ch then return nil end
		local ok, c = pcall(function() ch.Archivable = true return ch:Clone() end)
		return ok and c or nil
	end
	Prepare(o.Object or (o.Character and CharacterClone()) or nil)

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

	function V:SetObject(obj) Prepare(obj) end
	-- live-update the ESP preview: V:SetESP({Health = 0.4, Name = "Enemy", DistanceText = "42m"})
	function V:SetESP(t)
		if not esp then return end
		for k, v in pairs(t or {}) do esp.E[k] = v end
		if esp.Name and t and t.Name then esp.Name.Text = tostring(t.Name) end
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
	RegisterSurface(frame, "Panel")

	local function Front()
		ZCounter = ZCounter + 1
		frame.ZIndex = ZCounter
	end
	MakeDraggable(header, frame, Front)
	Front()

	function P:SetVisible(v)
		frame.Visible = v
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
		Width = o.Width or 340, Height = o.Height, Position = o.Position, Dock = o.Dock,
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
	local badge = New("Frame", {
		Size = UDim2.fromOffset(44, 44), BackgroundColor3 = color:Lerp(T.Background, 0.78), LayoutOrder = 1, Parent = top,
	}, { CornerFixed(22), New("UIStroke", { Color = color:Lerp(T.Background, 0.45), Thickness = 1 }) })
	Glow(badge, color, 22, true)
	local badgeIcon = Icon(symbol, badge, 22, key)
	badgeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	badgeIcon.Position = UDim2.fromScale(0.5, 0.5)
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
		Title = o.Title or "Key System", Width = o.Width or 440, Position = o.Position, HeaderIcon = header, Dock = o.Dock,
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
		pcall(function() self.Options.Lumen_Preset:Set(data.Lumen_Preset.v) end)
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

local Snow = { Enabled = false, Count = 70, Speed = 1, Kind = "Theme", Flakes = {}, Time = 0, Built = nil }
Lumen.ParticleKinds = { "Theme", "Snow", "Bubbles", "Petals", "Embers", "Fireflies", "Stars", "Glyphs" }
local KIND_COLORS = {
	Snow = Color3.new(1, 1, 1), Bubbles = Color3.fromRGB(140, 205, 255), Petals = Color3.fromRGB(242, 150, 186),
	Embers = Color3.fromRGB(255, 150, 70), Fireflies = Color3.fromRGB(180, 255, 150), Stars = Color3.new(1, 1, 1),
	Glyphs = Color3.fromRGB(205, 205, 205),
}
local GLYPH_CHARS = { "0", "1", "0", "1", "A", "F", "7", "3", "#", "*" }
local Backdrop = { Dim = 0.35, Blur = 0 }
local BlurEffect

local BackdropFrame = New("Frame", {
	Name = "Backdrop", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true,
	Visible = false, ZIndex = 0, Parent = Gui,
})
local DimFrame = New("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Parent = BackdropFrame,
})

local function AnyWindowVisible()
	for _, w in ipairs(Lumen.Windows) do
		if w.Visible then return true end
	end
	return false
end

function Lumen:_UpdateSnow()
	local any = AnyWindowVisible()
	BackdropFrame.Visible = any and (Snow.Enabled or Backdrop.Dim > 0)
	DimFrame.BackgroundTransparency = 1 - math.clamp(Backdrop.Dim, 0, 1)
	local target = any and Backdrop.Blur or 0
	if target > 0 and not BlurEffect then
		pcall(function()
			BlurEffect = Instance.new("BlurEffect")
			BlurEffect.Size = 0
			BlurEffect.Parent = Lighting
		end)
	end
	if BlurEffect then Tween(BlurEffect, 0.25, { Size = target }) end
	self:_UpdateDock()
end

local function CurrentKind()
	if Snow.Kind == "Theme" then return Lumen.Style.Particles or "Snow" end
	return Snow.Kind
end

local function BuildFlakes()
	for _, f in ipairs(Snow.Flakes) do f.Frame:Destroy() end
	Snow.Flakes = {}
	Snow.Built = nil
	if not Snow.Enabled then return end
	local kind = CurrentKind()
	if not KIND_COLORS[kind] then kind = "Snow" end
	Snow.Built = kind
	local color = (Snow.Kind == "Theme" and Lumen.Style.ParticleColor) or KIND_COLORS[kind]
	for i = 1, Snow.Count do
		local f = { X = math.random(), Y = math.random(), Phase = math.random() * 6.28, Sway = 0.4 + math.random() * 0.8 }
		if kind == "Snow" then
			local size = math.random(4, 13)
			f.Speed = 0.03 + (size / 13) * 0.07
			f.Frame = New("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = color,
				BackgroundTransparency = 0.3 + math.random() * 0.5, Parent = BackdropFrame }, { CornerFixed(size) })
		elseif kind == "Bubbles" then
			local size = math.random(6, 20)
			f.Speed = 0.025 + (size / 20) * 0.05
			f.Frame = New("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = color, BackgroundTransparency = 0.92, Parent = BackdropFrame },
				{ CornerFixed(size), New("UIStroke", { Color = color, Thickness = 1.2, Transparency = 0.35 + math.random() * 0.4 }),
				  New("Frame", { Size = UDim2.fromOffset(math.max(2, size / 4), math.max(2, size / 4)), Position = UDim2.fromScale(0.22, 0.2),
					BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45 }, { CornerFixed(size) }) })
		elseif kind == "Petals" then
			local size = math.random(6, 12)
			f.Speed = 0.025 + math.random() * 0.03
			f.Spin = (math.random() - 0.5) * 160
			f.Rot = math.random() * 360
			f.Frame = New("Frame", { Size = UDim2.fromOffset(math.floor(size * 1.5), size), BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), math.random() * 0.3),
				BackgroundTransparency = 0.15 + math.random() * 0.4, Parent = BackdropFrame }, { CornerFixed(size) })
		elseif kind == "Embers" then
			local size = math.random(2, 5)
			f.Speed = 0.05 + math.random() * 0.07
			f.Frame = New("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = color:Lerp(Color3.fromRGB(255, 230, 150), math.random() * 0.5),
				BackgroundTransparency = 0.2, Parent = BackdropFrame }, { CornerFixed(1) })
		elseif kind == "Fireflies" then
			local size = math.random(3, 6)
			f.Pulse = 1.2 + math.random() * 2
			f.Frame = New("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = color, BackgroundTransparency = 0.2, Parent = BackdropFrame },
				{ CornerFixed(size), New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(size * 4, size * 4), BackgroundColor3 = color, BackgroundTransparency = 0.88 }, { CornerFixed(size * 2) }) })
		elseif kind == "Stars" then
			local size = math.random(1, 3)
			f.Pulse = 0.6 + math.random() * 2.2
			f.Frame = New("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = color, BackgroundTransparency = 0.3,
				Position = UDim2.fromScale(f.X, f.Y), Parent = BackdropFrame }, { CornerFixed(size) })
		elseif kind == "Glyphs" then
			f.Speed = 0.06 + math.random() * 0.1
			-- plain Instance.new so the global font switch never touches these
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromOffset(14, 16)
			t.Font = Enum.Font.RobotoMono
			t.TextSize = math.random(10, 16)
			t.TextColor3 = color
			t.TextTransparency = 0.3 + math.random() * 0.55
			t.Text = GLYPH_CHARS[math.random(#GLYPH_CHARS)]
			t.Parent = BackdropFrame
			f.Frame = t
		end
		table.insert(Snow.Flakes, f)
	end
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

-- "Theme" follows the active theme; or "Snow", "Bubbles", "Petals", "Embers", "Fireflies", "Stars", "Glyphs"
function Lumen:SetParticles(kind)
	self:SetSnowOptions({ Kind = kind })
	SyncOption("Lumen_Particles", kind)
end

-- opts: Dim (0-1 darkness of the backdrop), Blur (0-40 world blur)
function Lumen:SetBackdrop(opts)
	if opts.Dim ~= nil then Backdrop.Dim = opts.Dim end
	if opts.Blur ~= nil then Backdrop.Blur = opts.Blur end
	self:_UpdateSnow()
end

Connect(RunService.RenderStepped, function(dt)
	if not BackdropFrame.Visible or #Snow.Flakes == 0 then return end
	Snow.Time = Snow.Time + dt
	local t, sp, kind = Snow.Time, Snow.Speed, Snow.Built
	for _, f in ipairs(Snow.Flakes) do
		if kind == "Snow" then
			f.Y = f.Y + f.Speed * sp * dt
			if f.Y > 1.03 then f.Y = -0.03 f.X = math.random() end
			f.Frame.Position = UDim2.fromScale(f.X + math.sin(t * f.Sway + f.Phase) * 0.008, f.Y)
		elseif kind == "Bubbles" then
			f.Y = f.Y - f.Speed * sp * dt
			if f.Y < -0.04 then f.Y = 1.04 f.X = math.random() end
			f.Frame.Position = UDim2.fromScale(f.X + math.sin(t * f.Sway * 1.6 + f.Phase) * 0.012, f.Y)
		elseif kind == "Petals" then
			f.Y = f.Y + f.Speed * sp * dt
			f.Rot = f.Rot + f.Spin * sp * dt
			if f.Y > 1.05 then f.Y = -0.05 f.X = math.random() end
			f.Frame.Position = UDim2.fromScale(f.X + math.sin(t * f.Sway + f.Phase) * 0.035, f.Y)
			f.Frame.Rotation = f.Rot
		elseif kind == "Embers" then
			f.Y = f.Y - f.Speed * sp * dt
			if f.Y < -0.03 then f.Y = 1.03 f.X = math.random() end
			f.Frame.Position = UDim2.fromScale(f.X + math.sin(t * f.Sway * 2 + f.Phase) * 0.018, f.Y)
			f.Frame.BackgroundTransparency = math.clamp(0.1 + (1 - f.Y) * 0.75 + 0.15 * math.sin(t * 13 + f.Phase), 0, 1)
		elseif kind == "Fireflies" then
			f.X = (f.X + math.sin(t * f.Sway * 0.7 + f.Phase) * 0.018 * sp * dt) % 1
			f.Y = (f.Y + math.cos(t * f.Sway * 0.5 + f.Phase * 2) * 0.014 * sp * dt) % 1
			f.Frame.Position = UDim2.fromScale(f.X, f.Y)
			f.Frame.BackgroundTransparency = 0.15 + 0.75 * (0.5 + 0.5 * math.sin(t * f.Pulse + f.Phase))
		elseif kind == "Stars" then
			f.Frame.BackgroundTransparency = 0.15 + 0.75 * (0.5 + 0.5 * math.sin(t * f.Pulse * sp + f.Phase))
		elseif kind == "Glyphs" then
			f.Y = f.Y + f.Speed * sp * dt
			if f.Y > 1.03 then f.Y = -0.03 f.X = math.random() end
			if math.random() < dt * 1.5 then f.Frame.Text = GLYPH_CHARS[math.random(#GLYPH_CHARS)] end
			f.Frame.Position = UDim2.fromScale(f.X, f.Y)
		end
	end
end)

-- The non-colour half of a theme. Keys (all optional):
--   Radius (corner scale), Glow (glow strength, 0 = off), Font ("Inter" | "Gotham" | "Mono"),
--   Particles + ParticleColor, Tint + TintPlace ("Top" | "Bottom" | "Aurora") + TintAmount,
--   TopLine = {Color3, Color3} (light along the window's top edge), Scanlines (bool)
function Lumen:SetStyle(st)
	local new = { Radius = 1, Glow = 1, Particles = "Snow", ParticleColor = Color3.new(1, 1, 1) }
	for k, v in pairs(st or {}) do new[k] = v end
	self.Style = new
	for _, d in ipairs(Gui:GetDescendants()) do
		if d:IsA("UICorner") then
			local r = d:GetAttribute("R")
			if r then d.CornerRadius = UDim.new(0, math.floor(r * new.Radius + 0.5)) end
		end
	end
	for i = #Glows, 1, -1 do
		local g = Glows[i]
		if g.rings[1] and g.rings[1].Parent and g.rings[1].Parent.Parent then g:Set(g.mult) else table.remove(Glows, i) end
	end
	if new.Font then self:SetFont(new.Font) end
	for _, e in ipairs(Surfaces) do StyleSurface(e) end
	self:_RefreshParticles()
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
	RegisterSurface(Dock, "Dock")
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
	local px = PIXEL_ICONS["dock_" .. ic]
	if px then
		entry.Icon = PixelIcon("dock_" .. ic, b, "Label")
		entry.Icon.Position = UDim2.fromOffset(px.ox, px.oy)
	elseif ic:find("rbxasset") or ic:find("rbxthumb") then
		entry.Image = New("ImageLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(17, 17), Image = ic, Parent = b,
		})
	else
		entry.Icon = Icon(ic, b, 17)
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
		end
	end
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
	RegisterScale(main)
	RegisterSurface(main, "Window")
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

	local content = New("Frame", {
		BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(17, 87),
		Size = UDim2.new(1, -34, 1, -122), Parent = main,
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

	function W:SetTitle(t) self.Title = t; titleLabel.Text = t end
	function W:SetSubtitle(t) subtitle.Text = t end
	function W:SetFooter(t) footer.Text = t end

	function W:_StyleTabs()
		for _, t in ipairs(self.Tabs) do
			local on = (t == self.Active) and not t.Hidden
			t.Page.Visible = on
			Tween(t.Button, 0.12, {
				BackgroundTransparency = on and 0 or 1,
				TextColor3 = on and Lumen.Theme.AccentText or Lumen.Theme.TextDim,
			})
		end
	end
	function W:SelectTab(t)
		if t.Hidden then return end
		ClosePopup()
		self.Active = t
		self:_StyleTabs()
		if t._Relayout then t._Relayout() end
		if t.OnSelect then t.OnSelect() end
	end
	table.insert(Refreshers, function() W:_StyleTabs() end)

	function W:SetTabVisible(name, v)
		for _, t in ipairs(self.Tabs) do
			if t.Name == name then t:SetVisible(v) end
		end
	end

	function W:SetVisible(v)
		self.Visible = v
		main.Visible = v
		if not v then ClosePopup() TooltipFrame.Visible = false end
		Lumen:_UpdateSnow()
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
					local ic = (icon == "command" and PixelIcon("group_command", titleRow, "Label")) or Icon(icon, titleRow, 15, "Label")
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
			local bar = New("Frame", {
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0, Parent = frame,
			}, { List(3, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
			local body = New("Frame", {
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1, Parent = frame,
			})
			local Box, subs, active = { Frame = frame }, {}, nil
			local function Style()
				for _, sub in ipairs(subs) do
					local on = (sub == active)
					sub.Container.Visible = on
					Tween(sub.Button, 0.12, {
						BackgroundTransparency = on and 0 or 1,
						TextColor3 = on and Lumen.Theme.AccentText or Lumen.Theme.Label,
					})
				end
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
				Connect(sub.Button.MouseButton1Click, function()
					ClosePopup()
					active = sub
					Style()
				end)
				if not active then active = sub end
				Style()
				local g = NewGroupObject(sub.Container, frame, W.Id .. "/" .. name .. "/" .. tabName, T)
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
		table.insert(W.Tabs, T)
		if not W.Active then W:SelectTab(T) end
		return T
	end

	-- Ready-made settings tab: everything adjustable from the UI (menu, effects, layout, theme, configs)
	function W:AddConfigTab(name, copts)
		local tab = self:AddTab(name or "Config")
		tab.Fill = false

		local menu = tab:AddGroup("Menu", "Left")
		menu:AddLabel("Menu keybind"):AddKeybind({
			Default = self.MenuKey, Mode = "Press", Flag = "Lumen_MenuKey", ShowInList = false,
			ChangedCallback = function(k) if k then W.MenuKey = k end end,
		})
		menu:AddToggle({ Text = "Show dock", Default = Lumen.ShowDock, Flag = "Lumen_Dock",
			Callback = function(v) Lumen:SetDockVisible(v) end })
		menu:AddToggle({ Text = "Show watermark", Default = Lumen.ShowWatermark, Flag = "Lumen_Watermark",
			Callback = function(v) Lumen:SetWatermarkVisible(v) end })
		menu:AddToggle({ Text = "Show hotkey list", Default = Lumen.ShowHotkeys, Flag = "Lumen_Hotkeys",
			Callback = function(v) Lumen:SetHotkeysVisible(v) end })
		menu:AddToggle({ Text = "Notifications", Default = Lumen.ShowNotifications, Flag = "Lumen_Notifs",
			Callback = function(v) Lumen.ShowNotifications = v end })
		menu:AddSlider({ Text = "UI scale", Min = 0.7, Max = 1.4, Default = Lumen.Scale, Increment = 0.05, Suffix = "x",
			Flag = "Lumen_Scale", Callback = function(v) Lumen:SetScale(v) end })
		Lumen._fontDropdown = menu:AddDropdown({ Text = "Font", Values = { "Inter", "Gotham", "Mono" }, Default = Lumen.FontName,
			Callback = function(v)
				if v == "Inter" and not Lumen._interAsset then
					Lumen:Notify({ Title = "Font", Content = "Inter needs file support in your executor. Using Gotham.", Type = "Warning" })
				end
				if v then Lumen:SetFont(v) end
			end })
		menu:AddInput({ Text = "Screen watermark", Placeholder = "text tiled over the screen (empty = off)",
			Callback = function(v) Lumen:SetScreenWatermark(v) end })
		menu:AddDivider()
		menu:AddButton({ Text = "Unload",
			Confirm = { Title = "Unload Lumen?", Text = "This removes the whole interface until you run the script again.", Type = "Danger", Confirm = "Unload" },
			Callback = function() Lumen:Unload() end })

		local fx = tab:AddGroup("Effects", "Left")
		fx:AddToggle({ Text = "Particles", Default = Snow.Enabled, Flag = "Lumen_Snow",
			Callback = function(v) Lumen:SetSnow(v) end })
		fx:AddDropdown({ Text = "Particle style", Values = Lumen.ParticleKinds, Default = Snow.Kind, Flag = "Lumen_Particles",
			Callback = function(v) if v then Lumen:SetSnowOptions({ Kind = v }) end end })
		fx:AddSlider({ Text = "Amount", Min = 10, Max = 200, Default = Snow.Count, Flag = "Lumen_SnowCount",
			Callback = function(v) Lumen:SetSnowOptions({ Count = v }) end })
		fx:AddSlider({ Text = "Speed", Min = 0.2, Max = 3, Default = Snow.Speed, Increment = 0.1, Suffix = "x",
			Flag = "Lumen_SnowSpeed", Callback = function(v) Lumen:SetSnowOptions({ Speed = v }) end })
		fx:AddSlider({ Text = "Backdrop dim", Min = 0, Max = 90, Default = math.floor(Backdrop.Dim * 100), Suffix = "%",
			Flag = "Lumen_Dim", Callback = function(v) Lumen:SetBackdrop({ Dim = v / 100 }) end })
		fx:AddSlider({ Text = "Backdrop blur", Min = 0, Max = 40, Default = Backdrop.Blur,
			Flag = "Lumen_Blur", Callback = function(v) Lumen:SetBackdrop({ Blur = v }) end })

		-- HUD pieces glide back to their spot after you drag them
		local hud = tab:AddGroup("HUD Positions", "Left")
		local sb = Lumen.SnapBack
		hud:AddToggle({ Text = "Return to place after dragging", Default = sb.Enabled, Flag = "Lumen_Snap",
			Callback = function(v) sb.Enabled = v end })
		hud:AddSlider({ Text = "Return after", Min = 1, Max = 30, Default = sb.Delay, Suffix = "s", Flag = "Lumen_SnapDelay",
			Callback = function(v) sb.Delay = v end })
		hud:AddToggle({ Text = "Dock", Default = sb.Dock, Flag = "Lumen_SnapDock", Callback = function(v) sb.Dock = v end })
		hud:AddToggle({ Text = "Hotkey list", Default = sb.Hotkeys, Flag = "Lumen_SnapHotkeys", Callback = function(v) sb.Hotkeys = v end })
		hud:AddToggle({ Text = "Watermark", Default = sb.Watermark, Flag = "Lumen_SnapWatermark", Callback = function(v) sb.Watermark = v end })
		hud:AddButton({ Text = "Return now", Callback = function() Lumen:ResetHudPositions() end })
			:AddSubButton({ Text = "Set as home", Callback = function()
				Lumen:SetHudHome()
				Lumen:Notify({ Title = "HUD", Content = "Current positions saved as home.", Type = "Success" })
			end })

		-- turn tabs and sections on or off (rebuilt every time this tab is opened)
		local layout = tab:AddGroup("Layout", "Left")
		local layoutOpts = {}
		local function RefreshLayout()
			for _, op in ipairs(layoutOpts) do op:Destroy() end
			layoutOpts = {}
			local function Add(text, default, cb)
				table.insert(layoutOpts, layout:AddToggle({ Text = text, Default = default, Callback = cb }))
			end
			for _, t in ipairs(W.Tabs) do
				if t ~= tab then
					Add("Tab: " .. t.Name, not t.Hidden, function(v) t:SetVisible(v) end)
					for _, sec in ipairs(t.Sections) do
						Add("   " .. t.Name .. " / " .. sec.Get(), sec.IsVisible(), function(v) sec.Set(v) end)
					end
				end
			end
			for _, pnl in ipairs(Lumen._Panels) do
				Add("Panel: " .. pnl.Name, pnl.Frame.Visible, function(v) pnl:SetVisible(v) end)
			end
			for _, e in ipairs(Lumen:GetDockButtons()) do
				Add("Dock: " .. e.Name, e.Button.Visible, function(v) e.Button.Visible = v end)
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
		for n in pairs(Lumen.Presets) do table.insert(names, n) end
		table.sort(names)
		local DESCRIPTIONS = {
			Lavender = "The reference look: soft lilac, snow.",
			Ocean = "Rounder, deep-water glow, rising bubbles.",
			Rose = "Extra round and glowy, drifting petals.",
			Emerald = "Aurora band up top, fireflies.",
			Sunset = "Warm glow from below, rising embers.",
			Mono = "Sharp corners, no glow, monospace, scanlines, glyph rain.",
		}
		local desc
		th:AddDropdown({ Text = "Preset", Values = names, Default = Lumen.Preset, Flag = "Lumen_Preset",
			Callback = function(v)
				if v then
					Lumen:ApplyPreset(v)
					SyncPickers()
					if desc then desc:SetText(DESCRIPTIONS[v] or "") end
				end
			end })
		desc = th:AddLabel(DESCRIPTIONS[Lumen.Preset] or "", { Dim = true })
		th:AddSlider({ Text = "Theme fade", Min = 0, Max = 1, Default = Lumen.ThemeTransition, Increment = 0.05, Suffix = "s",
			Flag = "Lumen_ThemeFade", Callback = function(v) Lumen.ThemeTransition = v end })
		for _, entry in ipairs({ { "Accent", "Accent" }, { "Background", "Window" }, { "Group", "Panels" },
			{ "Control", "Controls" }, { "Outline", "Outlines" }, { "Border", "Borders" },
			{ "Text", "Text" }, { "Label", "Labels" }, { "TextDim", "Dim text" } }) do
			local key, label = entry[1], entry[2]
			pickers[key] = th:AddLabel(label):AddColorPicker({
				Default = Lumen.Theme[key], Flag = "Lumen_Theme_" .. key,
				Callback = function(c) Lumen:SetTheme({ [key] = c }) end,
			})
		end
		th:AddButton({ Text = "Reset theme", Callback = function()
			Lumen:ApplyPreset("Lavender")
			SyncPickers()
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
	self.Unloaded = true
	if self.OnUnload then pcall(self.OnUnload) end
	for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
	if BlurEffect then pcall(function() BlurEffect:Destroy() end) end
	Gui:Destroy()
	if env.LumenUI == self then env.LumenUI = nil end
end

-- Inter font: downloaded once into the Lumen folder (needs writefile + getcustomasset), otherwise Gotham stays.
if not env.LumenNoInter then
	task.spawn(function()
		if Lumen:_LoadInter() and not Lumen.Unloaded and Lumen.FontName == "Inter" then Lumen:SetFont("Inter") end
	end)
end

return Lumen
