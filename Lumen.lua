--!nocheck
--!nolint
--[[
	Lumen UI Library  v2.2.0
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
	Version = "v2.2.0",
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
	FontName = "Gotham",
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
	},
	Presets = {
		Lavender = { Accent = Color3.fromRGB(159, 150, 193), Background = Color3.fromRGB(14, 13, 17), Group = Color3.fromRGB(17, 16, 21), GroupBorder = Color3.fromRGB(25, 24, 30), Control = Color3.fromRGB(24, 23, 28), ControlHover = Color3.fromRGB(34, 33, 39), Border = Color3.fromRGB(48, 47, 58), Outline = Color3.fromRGB(38, 36, 45), Text = Color3.fromRGB(210, 209, 220), Label = Color3.fromRGB(187, 186, 195), TextDim = Color3.fromRGB(134, 133, 141), TextMuted = Color3.fromRGB(108, 107, 114) },
		Ocean = { Accent = Color3.fromRGB(110, 165, 225), Background = Color3.fromRGB(10, 14, 20), Group = Color3.fromRGB(14, 19, 27), GroupBorder = Color3.fromRGB(22, 30, 41), Control = Color3.fromRGB(20, 27, 38), ControlHover = Color3.fromRGB(29, 39, 54), Border = Color3.fromRGB(40, 54, 72), Outline = Color3.fromRGB(33, 45, 61), Text = Color3.fromRGB(210, 218, 230), Label = Color3.fromRGB(180, 190, 204), TextDim = Color3.fromRGB(122, 138, 158), TextMuted = Color3.fromRGB(96, 110, 128) },
		Rose = { Accent = Color3.fromRGB(205, 120, 150), Background = Color3.fromRGB(17, 12, 15), Group = Color3.fromRGB(22, 16, 20), GroupBorder = Color3.fromRGB(33, 24, 29), Control = Color3.fromRGB(31, 23, 28), ControlHover = Color3.fromRGB(43, 32, 39), Border = Color3.fromRGB(62, 46, 54), Outline = Color3.fromRGB(50, 37, 44), Text = Color3.fromRGB(228, 214, 220), Label = Color3.fromRGB(200, 184, 191), TextDim = Color3.fromRGB(150, 130, 140), TextMuted = Color3.fromRGB(118, 100, 109) },
		Emerald = { Accent = Color3.fromRGB(100, 190, 145), Background = Color3.fromRGB(10, 15, 13), Group = Color3.fromRGB(14, 20, 18), GroupBorder = Color3.fromRGB(22, 31, 28), Control = Color3.fromRGB(20, 28, 25), ControlHover = Color3.fromRGB(29, 40, 36), Border = Color3.fromRGB(42, 58, 52), Outline = Color3.fromRGB(34, 47, 42), Text = Color3.fromRGB(212, 226, 219), Label = Color3.fromRGB(184, 198, 191), TextDim = Color3.fromRGB(124, 144, 133), TextMuted = Color3.fromRGB(98, 114, 106) },
		Sunset = { Accent = Color3.fromRGB(215, 150, 90), Background = Color3.fromRGB(17, 13, 11), Group = Color3.fromRGB(23, 18, 15), GroupBorder = Color3.fromRGB(34, 27, 22), Control = Color3.fromRGB(32, 26, 21), ControlHover = Color3.fromRGB(44, 36, 30), Border = Color3.fromRGB(64, 52, 43), Outline = Color3.fromRGB(51, 41, 34), Text = Color3.fromRGB(230, 220, 210), Label = Color3.fromRGB(202, 191, 180), TextDim = Color3.fromRGB(152, 138, 124), TextMuted = Color3.fromRGB(120, 108, 96) },
		Mono = { Accent = Color3.fromRGB(190, 190, 196), Background = Color3.fromRGB(12, 12, 12), Group = Color3.fromRGB(17, 17, 17), GroupBorder = Color3.fromRGB(26, 26, 26), Control = Color3.fromRGB(25, 25, 25), ControlHover = Color3.fromRGB(36, 36, 36), Border = Color3.fromRGB(52, 52, 52), Outline = Color3.fromRGB(41, 41, 41), Text = Color3.fromRGB(222, 222, 222), Label = Color3.fromRGB(194, 194, 194), TextDim = Color3.fromRGB(136, 136, 136), TextMuted = Color3.fromRGB(106, 106, 106) },
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
		if Lumen._fontAsset then ApplyFont(obj, w) end
	end
	for _, c in ipairs(children or {}) do c.Parent = obj end
	if parent then obj.Parent = parent end
	return obj
end

local function Corner(r) return New("UICorner", { CornerRadius = UDim.new(0, r or 4) }) end

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
local function Glow(host, color, radius)
	local G = { rings = {}, mult = 1 }
	for i = 1, #GLOW_ALPHA do
		local props = { Thickness = 1, Transparency = 1 - GLOW_ALPHA[i], ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
		if type(color) == "string" then props.Theme = { Color = color } else props.Color = color end
		local st = New("UIStroke", props)
		New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, i * 2, 1, i * 2),
			BackgroundTransparency = 1, Parent = host,
		}, { Corner((radius or 5) + i), st })
		G.rings[i] = st
	end
	function G:Set(mult)
		self.mult = mult
		for i, st in ipairs(self.rings) do st.Transparency = 1 - GLOW_ALPHA[i] * mult end
	end
	function G:SetColor(c)
		for _, st in ipairs(self.rings) do st.Color = c end
	end
	return G
end

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
		}, { Corner((r or 1) * s) })
		if key then b:SetAttribute("Fixed", true) end
		return b
	end
	local function Ring(x, y, w, h, r, th)
		return New("Frame", {
			Position = UDim2.fromOffset(x * s, y * s), Size = UDim2.fromOffset(w * s, h * s),
			BackgroundTransparency = 1, Parent = f,
		}, { Corner((r or 3) * s), New("UIStroke", { Thickness = th or 1.4, Theme = { Color = colorKey } }) })
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

-- Calls cb(mouseX, mouseY) while the pointer is held down that started on `frame`.
local function Dragger(frame, cb)
	local active = false
	Connect(frame.InputBegan, function(i)
		if IsPress(i) then
			active = true
			local m = UIS:GetMouseLocation()
			cb(m.X, m.Y)
		end
	end)
	Connect(UIS.InputChanged, function(i)
		if active and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local m = UIS:GetMouseLocation()
			cb(m.X, m.Y)
		end
	end)
	Connect(UIS.InputEnded, function(i)
		if IsPress(i) then active = false end
	end)
end

local function MakeDraggable(handle, target, onStart)
	local dragging, startMouse, startPos = false, nil, nil
	Connect(handle.InputBegan, function(i)
		if IsPress(i) then
			dragging = true
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
		if IsPress(i) then dragging = false end
	end)
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
	if p then self:SetTheme(p) end
end

function Lumen:SetTheme(t)
	local T = self.Theme
	for k, v in pairs(t) do T[k] = v end
	if t.Accent or t.Background then
		if not t.AccentText then T.AccentText = T.Accent:Lerp(Color3.new(1, 1, 1), 0.02) end
		if not t.AccentBorder then T.AccentBorder = T.Accent:Lerp(T.Background, 0.36) end
		if not t.Toggle then T.Toggle = T.Accent:Lerp(T.Background, 0.64) end
		if not t.TabActive then T.TabActive = T.Accent:Lerp(T.Background, 0.79) end
	end
	if (t.Control or t.Background) and not t.Chip then T.Chip = T.Control:Lerp(T.Background, 0.08) end
	if (t.TextDim or t.Label) and not t.ChipText then T.ChipText = T.TextDim:Lerp(T.Label, 0.4) end
	if t.Control and not t.ControlHover then
		T.ControlHover = t.Control:Lerp(Color3.new(1, 1, 1), 0.07)
	end
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

local function ClosePopup()
	if OpenPopup then
		local p = OpenPopup
		OpenPopup = nil
		p.Frame.Visible = false
		if p.OnClose then p.OnClose() end
	end
end

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
		TooltipFrame.Visible = true
	end)
	Connect(inst.MouseLeave, function() TooltipFrame.Visible = false end)
	Connect(inst.MouseMoved, function()
		local m = UIS:GetMouseLocation()
		TooltipFrame.Position = UDim2.fromOffset(m.X + 14, m.Y + 12)
	end)
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
	Size = UDim2.fromOffset(280, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 100, Parent = Gui,
}, { List(6, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right) })

-- o: string, or {Title, Content, Type = Success/Warning/Danger/Info, Duration, Progress}
function Lumen:Notify(o, duration)
	if type(o) == "string" then o = { Content = o, Duration = duration } end
	if not self.ShowNotifications then return end
	local key = o.Type
	if not key or not self.Theme[key] then key = "TextDim" end
	local dur = o.Duration or 4
	local card = New("CanvasGroup", {
		Size = UDim2.fromOffset(280, 0), AutomaticSize = Enum.AutomaticSize.Y, GroupTransparency = 1,
		Parent = NotifHolder, Theme = { BackgroundColor3 = "Background" },
	}, { Corner(8), Stroke("Outline"), List(0) })
	local body = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1, Parent = card,
	}, { Pad(12, 8, 12, 8), New("UISizeConstraint", { MinSize = Vector2.new(0, 32) }),
		List(10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local iconHolder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(16, 16), LayoutOrder = 1, Parent = body })
	Icon("bell", iconHolder, 16, key)
	local text = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -28, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2, Parent = body,
	}, { List(1) })
	if o.Title then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 16), Text = o.Title, TextColor3 = self.Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = text,
		})
	end
	if o.Content then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = o.Content, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, TextSize = o.Title and 11 or 12,
			TextColor3 = o.Title and self.Theme.TextDim or self.Theme.Label, Parent = text,
		})
	end
	if o.Progress then
		local track = New("Frame", {
			Size = UDim2.new(1, 0, 0, 2), LayoutOrder = 2, Parent = card, Theme = { BackgroundColor3 = "Outline" },
		})
		local fill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = self.Theme[key], Parent = track })
		Tween(fill, dur, { Size = UDim2.new(0, 0, 1, 0) })
	end
	Tween(card, 0.2, { GroupTransparency = 0 })
	task.delay(dur, function()
		if card.Parent then
			Tween(card, 0.25, { GroupTransparency = 1 }).Completed:Connect(function() card:Destroy() end)
		end
	end)
end

local Fps, WatermarkOverride, WatermarkTitle = 60, nil, nil
local Watermark = New("Frame", {
	Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X,
	ZIndex = 5, Parent = Gui, Theme = { BackgroundColor3 = "Background" },
}, { Corner(9), Stroke(nil, true), Pad(11, 0, 14, 0),
	List(9, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
MakeDraggable(Watermark, Watermark)
local WatermarkLogo = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(18, 18), LayoutOrder = 1, Parent = Watermark }, {
	New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, { Corner(9), New("UIStroke", { Thickness = 2, Theme = { Color = "AccentBorder" } }) }),
	New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), Theme = { BackgroundColor3 = "AccentText" } }, { Corner(3) }),
})
local WatermarkImage = New("ImageLabel", {
	BackgroundTransparency = 1, Size = UDim2.fromOffset(18, 18), LayoutOrder = 1, Visible = false, Parent = Watermark,
})
local WatermarkLabel = New("TextLabel", {
	Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, RichText = true, LayoutOrder = 2,
	TextColor3 = Lumen.Theme.Text, Parent = Watermark,
})

local HotkeyFrame = New("Frame", {
	Position = UDim2.fromOffset(12, 56), Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY,
	Visible = false, ZIndex = 5, Parent = Gui, Theme = { BackgroundColor3 = "Background" },
}, { Corner(9), Stroke(nil, true), Pad(14, 10, 16, 12), List(8), New("UISizeConstraint", { MinSize = Vector2.new(160, 0) }) })
MakeDraggable(HotkeyFrame, HotkeyFrame)
local HotkeyTitle = New("Frame", {
	BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 0, Parent = HotkeyFrame,
}, { List(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
local HotkeyIcon = Icon("keyboard", HotkeyTitle, 15)
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
	}, { Corner(10), Stroke("Outline") })
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
	}, { Corner(4) })
	Glow(knob, Color3.new(1, 1, 1), 4):Set(0.2)
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

	Connect(box.Focused, function() Tween(stroke, 0.1, { Color = Lumen.Theme.AccentBorder }) end)
	Connect(box.FocusLost, function()
		Tween(stroke, 0.1, { Color = Lumen.Theme.Outline })
		if not o.Realtime then Fire(I, I.Value) end
	end)
	Connect(box:GetPropertyChangedSignal("Text"), function()
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

	local function Place()
		if not model then return end
		local d = dist * zoom
		local cp = math.cos(pitch)
		cam.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(yaw) * cp * d, math.sin(pitch) * d, math.cos(yaw) * cp * d), center)
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

	Connect(vf.InputBegan, function(i)
		if IsPress(i) then
			dragging = true
			lastMouse = UIS:GetMouseLocation()
		end
	end)
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
	function P:Destroy() ClosePopup() frame:Destroy() Lumen:_UpdateDock() end
	if o.Visible == false then frame.Visible = false end
	if o.Dock then
		Lumen:AddDockButton({
			Icon = o.Dock.Icon or "window", Tooltip = o.Dock.Tooltip or o.Title, Order = o.Dock.Order or 20,
			Callback = function() P:Toggle() end, Active = function() return frame.Visible end,
		})
	end
	return P
end

function Lumen:CreateCredits(o)
	o = o or {}
	local P = self:CreatePanel({
		Title = o.Title or "CREDITS", Subtitle = o.Subtitle or "People behind this script",
		Width = o.Width or 340, Height = o.Height, Position = o.Position, Dock = o.Dock,
	})
	function P:AddEntry(e)
		local color = e.RoleColor or Lumen.Theme.Accent
		local card = New("Frame", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = (self._container:GetAttribute("Order") or 0) + 1, Parent = self._container,
			Theme = { BackgroundColor3 = "Group" },
		}, { Corner(7), Stroke("Outline"), Pad(12, 9, 12, 10), List(5) })
		self._container:SetAttribute("Order", card.LayoutOrder)
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
	for _, e in ipairs(o.Entries or {}) do P:AddEntry(e) end
	return P
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

local Snow = { Enabled = false, Count = 70, Speed = 1, Flakes = {}, Time = 0 }
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

local function BuildFlakes()
	for _, f in ipairs(Snow.Flakes) do f.Frame:Destroy() end
	Snow.Flakes = {}
	if not Snow.Enabled then return end
	for i = 1, Snow.Count do
		local size = math.random(4, 13)
		local frame = New("Frame", {
			Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.3 + math.random() * 0.5, Parent = BackdropFrame,
		}, { Corner(size) })
		table.insert(Snow.Flakes, {
			Frame = frame, X = math.random(), Y = math.random(), Speed = 0.03 + (size / 13) * 0.07,
			Sway = 0.4 + math.random() * 0.8, Phase = math.random() * 6.28,
		})
	end
end

-- opts (all optional): Count, Speed, Dim
function Lumen:SetSnow(enabled, opts)
	if opts then
		if opts.Count then Snow.Count = math.floor(opts.Count) end
		if opts.Speed then Snow.Speed = opts.Speed end
		if opts.Dim then Backdrop.Dim = opts.Dim end
	end
	Snow.Enabled = enabled and true or false
	BuildFlakes()
	SyncOption("Lumen_Snow", Snow.Enabled)
	self:_UpdateSnow()
end

function Lumen:SetSnowOptions(opts)
	if opts.Count then
		Snow.Count = math.floor(opts.Count)
		if Snow.Enabled then BuildFlakes() end
	end
	if opts.Speed then Snow.Speed = opts.Speed end
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
	for _, f in ipairs(Snow.Flakes) do
		f.Y = f.Y + f.Speed * Snow.Speed * dt
		if f.Y > 1.03 then
			f.Y = -0.03
			f.X = math.random()
		end
		f.Frame.Position = UDim2.fromScale(f.X + math.sin(Snow.Time * f.Sway + f.Phase) * 0.008, f.Y)
	end
end)

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
	}, { Corner(10), Stroke(nil, true), Pad(10, 7, 10, 7),
		List(4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	MakeDraggable(Dock, Dock)
	return Dock
end

function Lumen:_UpdateDock()
	local T = self.Theme
	local active = T.Accent:Lerp(T.Background, 0.1)
	for i = #DockButtons, 1, -1 do
		local e = DockButtons[i]
		if e.Button.Parent == nil then
			table.remove(DockButtons, i)
		else
			local on = e.Active and e.Active() or false
			e.Button.BackgroundColor3 = T.TabActive
			Tween(e.Button, 0.12, { BackgroundTransparency = on and 0 or 1 })
			if e.Icon then RecolorIcon(e.Icon, on and active or T.Label) end
			if e.Image then e.Image.ImageColor3 = on and active or T.Label end
		end
	end
end
table.insert(Refreshers, function() Lumen:_UpdateDock() end)

-- o: Icon ("window","keyboard","command","scan","bell","user","gear","snow","list","discord" or an rbxassetid),
-- Tooltip, Callback, Active (function -> bool, highlights the button), Order
function Lumen:AddDockButton(o)
	o = o or {}
	local dock = EnsureDock()
	local b = New("TextButton", {
		Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 1, LayoutOrder = o.Order or 50, Parent = dock,
		Theme = { BackgroundColor3 = "TabActive" },
	}, { Corner(8) })
	local entry = { Button = b, Active = o.Active }
	local ic = o.Icon or "window"
	if ic:find("rbxasset") or ic:find("rbxthumb") then
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

-- `which` lists the built-in dock buttons to create (default: all of them)
function Lumen:_InitDock(W, which)
	if self._dockInit then return end
	self._dockInit = true
	local want = {}
	for _, k in ipairs(which or { "menu", "hotkeys", "watermark", "snow", "palette" }) do want[k] = true end
	if want.menu then
		self:AddDockButton({ Icon = "window", Tooltip = "Toggle menu", Order = 1,
			Callback = function() W:Toggle() end, Active = function() return W.Visible end })
	end
	if want.hotkeys then
		self:AddDockButton({ Icon = "keyboard", Tooltip = "Hotkey list", Order = 30,
			Callback = function() Lumen:SetHotkeysVisible(not Lumen.ShowHotkeys) end, Active = function() return Lumen.ShowHotkeys end })
	end
	if want.watermark then
		self:AddDockButton({ Icon = "list", Tooltip = "Watermark", Order = 32,
			Callback = function() Lumen:SetWatermarkVisible(not Lumen.ShowWatermark) end, Active = function() return Lumen.ShowWatermark end })
	end
	if want.snow then
		self:AddDockButton({ Icon = "snow", Tooltip = "Snow", Order = 34,
			Callback = function() Lumen:SetSnow(not Snow.Enabled) end, Active = function() return Snow.Enabled end })
	end
	if want.palette then
		self:AddDockButton({ Icon = "command", Tooltip = "Command palette (Ctrl+K)", Order = 40,
			Callback = function() Lumen:TogglePalette() end, Active = function() return Palette.Open end })
	end
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
				if icon then Icon(icon, titleRow, 15, "Label").LayoutOrder = 1 end
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
	function W:AddConfigTab(name)
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
		Lumen._fontDropdown = menu:AddDropdown({ Text = "Font", Values = { "Inter", "Gotham" }, Default = Lumen.FontName,
			Callback = function(v)
				if v == "Inter" and not Lumen._interAsset then
					Lumen:Notify({ Title = "Font", Content = "Inter needs file support in your executor. Using Gotham.", Type = "Warning" })
				end
				if v then Lumen:SetFont(v) end
			end })
		menu:AddInput({ Text = "Screen watermark", Placeholder = "text tiled over the screen (empty = off)",
			Callback = function(v) Lumen:SetScreenWatermark(v) end })
		menu:AddDivider()
		menu:AddButton({ Text = "Unload", DoubleClick = true, Callback = function() Lumen:Unload() end })

		local fx = tab:AddGroup("Effects", "Left")
		fx:AddToggle({ Text = "Snow", Default = Snow.Enabled, Flag = "Lumen_Snow",
			Callback = function(v) Lumen:SetSnow(v) end })
		fx:AddSlider({ Text = "Snow amount", Min = 10, Max = 200, Default = Snow.Count, Flag = "Lumen_SnowCount",
			Callback = function(v) Lumen:SetSnowOptions({ Count = v }) end })
		fx:AddSlider({ Text = "Snow speed", Min = 0.2, Max = 3, Default = Snow.Speed, Increment = 0.1, Suffix = "x",
			Flag = "Lumen_SnowSpeed", Callback = function(v) Lumen:SetSnowOptions({ Speed = v }) end })
		fx:AddSlider({ Text = "Backdrop dim", Min = 0, Max = 90, Default = math.floor(Backdrop.Dim * 100), Suffix = "%",
			Flag = "Lumen_Dim", Callback = function(v) Lumen:SetBackdrop({ Dim = v / 100 }) end })
		fx:AddSlider({ Text = "Backdrop blur", Min = 0, Max = 40, Default = Backdrop.Blur,
			Flag = "Lumen_Blur", Callback = function(v) Lumen:SetBackdrop({ Blur = v }) end })

		-- turn tabs and sections on or off (rebuilt every time this tab is opened)
		local layout = tab:AddGroup("Layout", "Left")
		local layoutOpts = {}
		local function RefreshLayout()
			for _, op in ipairs(layoutOpts) do op:Destroy() end
			layoutOpts = {}
			for _, t in ipairs(W.Tabs) do
				if t ~= tab then
					table.insert(layoutOpts, layout:AddToggle({
						Text = "Tab: " .. t.Name, Default = not t.Hidden, Callback = function(v) t:SetVisible(v) end,
					}))
					for _, sec in ipairs(t.Sections) do
						table.insert(layoutOpts, layout:AddToggle({
							Text = "   " .. t.Name .. " / " .. sec.Get(), Default = sec.IsVisible(),
							Callback = function(v) sec.Set(v) end,
						}))
					end
				end
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
		th:AddDropdown({ Text = "Preset", Values = names, Default = "Lavender",
			Callback = function(v)
				if v then
					Lumen:ApplyPreset(v)
					SyncPickers()
				end
			end })
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
		return tab
	end

	table.insert(Lumen.Windows, W)
	if o.Dock ~= false then Lumen:_InitDock(W, type(o.Dock) == "table" and o.Dock or nil) end

	-- mobile fallback when the dock is disabled
	if o.Dock == false and UIS.TouchEnabled and not UIS.KeyboardEnabled and o.MobileButton ~= false then
		local mb = New("TextButton", {
			Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 14, 0.5, -22), Text = "UI",
			BackgroundTransparency = 0, ZIndex = 20, Parent = Gui, Theme = { BackgroundColor3 = "Group" },
		}, { Corner(22), Stroke("Border") })
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

	-- click-away for popups
	if OpenPopup and IsPress(input) then
		if not MouseInside(OpenPopup.Frame) and not MouseInside(OpenPopup.Trigger) then ClosePopup() end
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
		if Lumen:_LoadInter() and not Lumen.Unloaded then Lumen:SetFont("Inter") end
	end)
end

return Lumen
