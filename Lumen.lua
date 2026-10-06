--!nocheck
--!nolint
--[[
	Lumen UI Library  v2.0.0
	Single file, no dependencies, loadstring-ready.

	local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Lumen.lua"))()

	See DOCS.md for the full API and Example.lua for a complete demo.
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

local Lumen = {
	Version = "v2.0.0",
	Flags = {},
	Options = {},
	Windows = {},
	Folder = "Lumen",
	Unloaded = false,
	ShowWatermark = true,
	ShowHotkeys = true,
	Theme = {
		Background = Color3.fromRGB(13, 13, 17),
		Group = Color3.fromRGB(19, 19, 25),
		Control = Color3.fromRGB(27, 27, 35),
		ControlHover = Color3.fromRGB(37, 37, 48),
		Border = Color3.fromRGB(38, 38, 50),
		Text = Color3.fromRGB(236, 236, 242),
		TextDim = Color3.fromRGB(140, 140, 156),
		Accent = Color3.fromRGB(134, 120, 222),
		AccentText = Color3.fromRGB(192, 183, 246),
		Success = Color3.fromRGB(96, 205, 140),
		Warning = Color3.fromRGB(240, 170, 70),
		Danger = Color3.fromRGB(232, 92, 104),
		Info = Color3.fromRGB(100, 160, 240),
	},
}
env.LumenUI = Lumen

local Connections, Themed, Refreshers, Keybinds = {}, {}, {}, {}
local Gui, Overlay, OpenPopup
local ZCounter = 10
local Elements = {}

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

local function New(class, props, children)
	local obj = Instance.new(class)
	if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
		obj.Font = Enum.Font.GothamMedium
		obj.TextSize = 12
		obj.TextColor3 = Lumen.Theme.Text
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
	for _, c in ipairs(children or {}) do c.Parent = obj end
	if parent then obj.Parent = parent end
	return obj
end

local function Corner(r) return New("UICorner", { CornerRadius = UDim.new(0, r or 4) }) end

local function Stroke(key)
	return New("UIStroke", {
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Theme = { Color = key or "Border" },
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

function Lumen:SetTheme(t)
	for k, v in pairs(t) do self.Theme[k] = v end
	if t.Accent and not t.AccentText then
		self.Theme.AccentText = t.Accent:Lerp(Color3.new(1, 1, 1), 0.4)
	end
	for i = #Themed, 1, -1 do
		local e = Themed[i]
		if e[1].Parent == nil then
			table.remove(Themed, i)
		else
			pcall(function() e[1][e[2]] = self.Theme[e[3]] end)
		end
	end
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
	local vp = Gui.AbsoluteSize
	local w, h = frame.Size.X.Offset, frame.Size.Y.Offset
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
	ZIndex = 200, Parent = Gui, Theme = { BackgroundColor3 = "Group" },
}, { Corner(4), Stroke("Border"), Pad(8, 5, 8, 5) })
local TooltipLabel = New("TextLabel", {
	AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), TextSize = 11,
	Parent = TooltipFrame,
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

-- addon holder (keybind chip / color swatches / tooltip chip, right aligned in a row)
local function MakeAddonHolder(row)
	return New("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, Parent = row,
	}, { List(4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
end

------------------------------------------------------------------------------
-- Notifications, watermark, hotkey list
------------------------------------------------------------------------------

local NotifHolder = New("Frame", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.fromOffset(260, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 100, Parent = Gui,
}, { List(6, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right) })

function Lumen:Notify(o, duration)
	if type(o) == "string" then o = { Content = o, Duration = duration } end
	local color = self.Theme[o.Type or "Accent"] or self.Theme.Accent
	local dur = o.Duration or 4
	local card = New("CanvasGroup", {
		Size = UDim2.fromOffset(250, 0), AutomaticSize = Enum.AutomaticSize.Y,
		GroupTransparency = 1, Parent = NotifHolder, Theme = { BackgroundColor3 = "Group" },
	}, { Corner(6), Stroke("Border"), List(0) })
	local body = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1, Parent = card,
	}, { Pad(12, 9, 12, 9), List(2) })
	if o.Title then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 16), Text = o.Title, Font = Enum.Font.GothamBold,
			TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = body,
		})
	end
	if o.Content then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = o.Content,
			TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2,
			TextColor3 = o.Title and self.Theme.TextDim or self.Theme.Text, Parent = body,
		})
	end
	local track = New("Frame", {
		Size = UDim2.new(1, 0, 0, 2), LayoutOrder = 2, Parent = card, Theme = { BackgroundColor3 = "Border" },
	})
	local fill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, Parent = track })
	Tween(card, 0.2, { GroupTransparency = 0 })
	Tween(fill, dur, { Size = UDim2.new(0, 0, 1, 0) }).Completed:Connect(function()
		Tween(card, 0.25, { GroupTransparency = 1 }).Completed:Connect(function() card:Destroy() end)
	end)
end

local Fps, WatermarkOverride = 60, nil
local Watermark = New("Frame", {
	Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X,
	ZIndex = 5, Parent = Gui, Theme = { BackgroundColor3 = "Background" },
}, { Corner(6), Stroke("Border"), Pad(12, 0, 12, 0) })
local WatermarkLabel = New("TextLabel", {
	Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, RichText = true, Parent = Watermark,
})

local HotkeyFrame = New("Frame", {
	Position = UDim2.fromOffset(16, 56), Size = UDim2.fromOffset(190, 0), AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false, ZIndex = 5, Parent = Gui, Theme = { BackgroundColor3 = "Background" },
}, { Corner(6), Stroke("Border"), Pad(12, 9, 12, 9), List(5) })
New("TextLabel", {
	Size = UDim2.new(1, 0, 0, 16), Text = "Hotkeys", Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0, Parent = HotkeyFrame,
})
local HotkeyList = New("Frame", {
	BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	LayoutOrder = 1, Parent = HotkeyFrame,
}, { List(3) })

function Lumen:_UpdateHotkeys()
	for _, c in ipairs(HotkeyList:GetChildren()) do
		if c:IsA("TextLabel") then c:Destroy() end
	end
	local n = 0
	for i = #Keybinds, 1, -1 do
		if not Keybinds[i].Chip:IsDescendantOf(Gui) then table.remove(Keybinds, i) end
	end
	for _, K in ipairs(Keybinds) do
		if K.Value and K.Mode ~= "Press" and not K.Hidden then
			n = n + 1
			local active = K:IsActive()
			New("TextLabel", {
				Size = UDim2.new(1, 0, 0, 15), RichText = true, TextSize = 11, LayoutOrder = n,
				TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = self.Theme.TextDim, Parent = HotkeyList,
				Text = string.format('[%s] %s - <font color="#%s">%s</font>', Esc(KeyName(K.Value):upper()), Esc(K.Name),
					(active and self.Theme.Success or self.Theme.Danger):ToHex(), active and "Active" or "Inactive"),
			})
		end
	end
	HotkeyFrame.Visible = self.ShowHotkeys and n > 0
end

function Lumen:SetHotkeysVisible(v)
	self.ShowHotkeys = v
	self:_UpdateHotkeys()
end

function Lumen:SetWatermarkVisible(v)
	self.ShowWatermark = v
	Watermark.Visible = v
end

function Lumen:SetWatermark(text)
	WatermarkOverride = text
end

task.spawn(function()
	while not Lumen.Unloaded do
		local T = Lumen.Theme
		local ping = 0
		pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
		local function dim(s) return string.format('<font color="#%s">%s</font>', T.TextDim:ToHex(), s) end
		local function warn(s) return string.format('<font color="#%s">%s</font>', T.Warning:ToHex(), s) end
		if WatermarkOverride then
			WatermarkLabel.Text = Esc(WatermarkOverride)
		else
			local title = Lumen.Windows[1] and Lumen.Windows[1].Title or "Lumen"
			WatermarkLabel.Text = string.format("%s  %s  %s  %s  %s  %s", Esc(title), dim("|"),
				Esc(Players.LocalPlayer.Name), dim("|"), warn(Fps .. " FPS"), dim("|") .. "  " .. warn(ping .. "ms"))
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
		Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 0, BackgroundColor3 = default, Parent = holder,
	}, { Corner(4), Stroke("Border") })
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
	K.Owner = owner
	K.Active = false
	K.Hidden = o.ShowInList == false
	K.Name = o.Name or (owner and owner._text) or "Keybind"
	local key = o.Default
	if type(key) == "string" then
		local ok, v = pcall(function() return Enum.KeyCode[key] end)
		key = ok and v or nil
	end
	K.Value = key

	local chip = New("TextButton", {
		Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0,
		TextSize = 11, TextColor3 = Lumen.Theme.TextDim, Text = KeyName(key), Parent = holder,
		Theme = { BackgroundColor3 = "Control" },
	}, { Corner(4), Stroke("Border"), Pad(7, 0, 7, 0) })
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
		if K.Mode == "Press" then return end
		K.Mode = (K.Mode == "Toggle") and "Hold" or "Toggle"
		Lumen:Notify({ Content = (K.Name or "Keybind") .. ": " .. K.Mode .. " mode", Duration = 2 })
		Lumen:_UpdateHotkeys()
	end)

	table.insert(Keybinds, K)
	Register(K, o.Flag)
	if o.ChangedCallback then K:OnKeyChanged(o.ChangedCallback) end
	if owner then owner._kb = K end
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
	local chip = New("TextButton", {
		Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 0, Text = "?", TextSize = 10,
		TextColor3 = Lumen.Theme.TextDim, Parent = self._addons, LayoutOrder = 100,
		Theme = { BackgroundColor3 = "Control" },
	}, { Corner(8) })
	AttachTooltip(chip, text)
	return self
end

------------------------------------------------------------------------------
-- Elements
------------------------------------------------------------------------------

local function Label(parent, text, o)
	o = o or {}
	return New("TextLabel", {
		Text = text, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = o.Color or Lumen.Theme.Text,
		Font = o.Bold and Enum.Font.GothamBold or Enum.Font.GothamMedium, TextSize = o.Size or 12,
		Size = o.Size2 or UDim2.new(1, 0, 1, 0), Parent = parent,
	})
end

function Elements:AddLabel(text, o)
	if type(text) == "table" then o, text = text, text.Text end
	o = o or {}
	local L = NewOpt("Label", o)
	L._text = text
	local row = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = (self._container:GetAttribute("Order") or 0) + 1, Parent = self._container,
	}, { New("UISizeConstraint", { MinSize = Vector2.new(0, 18) }) })
	self._container:SetAttribute("Order", row.LayoutOrder)
	L.Row = row
	L._addons = MakeAddonHolder(row)
	local lbl = New("TextLabel", {
		Text = text or "", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
		RichText = true, TextXAlignment = Enum.TextXAlignment.Left,
		Font = o.Bold and Enum.Font.GothamBold or Enum.Font.GothamMedium,
		TextColor3 = o.Dim and Lumen.Theme.TextDim or Lumen.Theme.Text, Parent = row,
	})
	function L:SetText(t) lbl.Text = t; self._text = t end
	function L:SetColor(c) lbl.TextColor3 = c end
	return L
end

function Elements:AddDivider()
	local row = Row(self._container, 9)
	New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 1),
		Parent = row, Theme = { BackgroundColor3 = "Border" },
	})
	return { Row = row, SetVisible = OptBase.SetVisible }
end

function Elements:AddImage(o)
	o = o or {}
	local row = Row(self._container, o.Height or 120)
	local frame = New("Frame", {
		Size = UDim2.fromScale(1, 1), ClipsDescendants = true, Parent = row, Theme = { BackgroundColor3 = "Background" },
	}, { Corner(5), Stroke("Border") })
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
	local row = Row(self._container, 22)
	T.Row = row
	T._addons = MakeAddonHolder(row)

	local btn = New("TextButton", { Size = UDim2.new(1, 0, 1, 0), Parent = row, ZIndex = 1 })
	local box = New("Frame", {
		Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 0, 0.5, -8), ZIndex = 2, Parent = row,
		Theme = { BackgroundColor3 = "Control" },
	}, { Corner(4), Stroke("Border") })
	local fill = New("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = box,
		Theme = { BackgroundColor3 = "Accent" },
	}, { Corner(4) })
	New("TextLabel", {
		Text = T._text, Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -24, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, Parent = row,
	})
	-- addons must sit above the click area
	T._addons.ZIndex = 5

	local function Render()
		Tween(fill, 0.12, { BackgroundTransparency = T.Value and 0.1 or 1 })
	end
	function T:Set(v, silent)
		v = v and true or false
		if self.Value == v then return end
		self.Value = v
		Render()
		if not silent then Fire(self, v) end
		if self._kb then Lumen:_UpdateHotkeys() end
	end
	Connect(btn.MouseButton1Click, function() T:Set(not T.Value) end)
	Connect(btn.MouseEnter, function() Tween(box, 0.1, { BackgroundColor3 = Lumen.Theme.ControlHover }) end)
	Connect(btn.MouseLeave, function() Tween(box, 0.1, { BackgroundColor3 = Lumen.Theme.Control }) end)

	Register(T, o.Flag)
	fill.BackgroundTransparency = T.Value and 0.1 or 1
	if o.Tooltip then T:AddTooltip(o.Tooltip) end
	return T
end

function Elements:AddSlider(o)
	o = o or {}
	local S = NewOpt("Slider", o)
	S.Min, S.Max, S.Inc, S.Suffix = o.Min or 0, o.Max or 100, o.Increment or 1, o.Suffix or ""
	S.Value = math.clamp(o.Default or S.Min, S.Min, S.Max)
	local dec = #((tostring(S.Inc):match("%.(%d+)")) or "")
	local row = Row(self._container, 36)
	S.Row = row

	New("TextLabel", {
		Text = o.Text or "Slider", Size = UDim2.new(0.6, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
	})
	local valueLabel = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.4, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Lumen.Theme.TextDim, Parent = row,
	})
	local track = New("Frame", {
		Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 4), Parent = row, Theme = { BackgroundColor3 = "Control" },
	}, { Corner(2) })
	local fill = New("Frame", {
		Size = UDim2.new(0, 0, 1, 0), Parent = track, Theme = { BackgroundColor3 = "Accent" },
	}, { Corner(2) })
	New("Frame", {
		Size = UDim2.fromOffset(9, 9), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), Parent = fill,
	}, { Corner(5) })
	local hit = New("TextButton", { Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 20), Parent = row })

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
	Render()
	return S
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
	local box = New("TextButton", {
		Position = UDim2.fromOffset(0, h - 28), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 0,
		Parent = row, Theme = { BackgroundColor3 = "Control" },
	}, { Corner(4), Stroke("Border") })
	local valueText = New("TextLabel", {
		Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -28, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = box,
	})
	New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.fromOffset(10, 28),
		Text = "v", TextSize = 10, TextColor3 = Lumen.Theme.TextDim, Parent = box,
	})

	local pop = New("Frame", {
		Visible = false, Size = UDim2.fromOffset(200, 100), Parent = Overlay, Theme = { BackgroundColor3 = "Group" },
	}, { Corner(5), Stroke("Border") })
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
		valueText.TextColor3 = (valueText.Text == "--") and Lumen.Theme.TextDim or Lumen.Theme.Text
		for v, b in pairs(items) do
			b.TextColor3 = IsSelected(v) and Lumen.Theme.AccentText or Lumen.Theme.Text
			b.BackgroundTransparency = IsSelected(v) and 0.85 or 1
		end
	end
	local function Build()
		for _, b in pairs(items) do b:Destroy() end
		items = {}
		for i, v in ipairs(D.Values) do
			local b = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 22), Text = tostring(v), TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = i, Parent = scroll, Theme = { BackgroundColor3 = "Accent" },
			}, { Corner(4), Pad(8, 0, 8, 0) })
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
		pop.Size = UDim2.fromOffset(math.max(box.AbsoluteSize.X, 120), math.min(#D.Values * 24 + 8, 176))
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
			pop.Size = UDim2.fromOffset(math.max(box.AbsoluteSize.X, 120), math.min(#D.Values * 24 + 8, 176))
			ShowPopup(pop, box)
		end
	end)

	Build()
	if o.Default ~= nil then D:Set(o.Default, true) end
	Register(D, o.Flag)
	Render()
	return D
end

function Elements:AddInput(o)
	o = type(o) == "string" and { Text = o } or o or {}
	local I = NewOpt("Input", o)
	I.Value = tostring(o.Default or "")
	local h = o.Text and 46 or 26
	local row = Row(self._container, h)
	I.Row = row
	if o.Text then
		New("TextLabel", { Text = o.Text, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	end
	local stroke = Stroke("Border")
	local box = New("TextBox", {
		Position = UDim2.fromOffset(0, h - 26), Size = UDim2.new(1, 0, 0, 26), Text = I.Value,
		PlaceholderText = o.Placeholder or "", PlaceholderColor3 = Lumen.Theme.TextDim, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, ClipsDescendants = true, Parent = row,
		Theme = { BackgroundColor3 = "Control" },
	}, { Corner(4), stroke, Pad(8, 0, 8, 0) })

	Connect(box.Focused, function() Tween(stroke, 0.1, { Color = Lumen.Theme.Accent }) end)
	Connect(box.FocusLost, function()
		Tween(stroke, 0.1, { Color = Lumen.Theme.Border })
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
	Register(I, o.Flag)
	return I
end

function Elements:AddButton(o)
	o = type(o) == "string" and { Text = o } or o or {}
	local B = NewOpt("Button", {})
	local row = Row(self._container, 26)
	B.Row = row
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row,
	})
	local buttons = {}
	local function Layout()
		local n = #buttons
		for _, b in ipairs(buttons) do
			b.Size = UDim2.new(1 / n, -(4 * (n - 1)) / n, 1, 0)
		end
	end
	local function Make(opts)
		local b = New("TextButton", {
			BackgroundTransparency = 0, Text = opts.Text or "Button", Font = Enum.Font.GothamBold,
			LayoutOrder = #buttons + 1, Parent = row, Theme = { BackgroundColor3 = "Control" },
		}, { Corner(4), Stroke("Border") })
		table.insert(buttons, b)
		Layout()
		if opts.Tooltip then AttachTooltip(b, opts.Tooltip) end
		local confirming = false
		local original = b.Text
		Connect(b.MouseEnter, function() Tween(b, 0.1, { BackgroundColor3 = Lumen.Theme.ControlHover }) end)
		Connect(b.MouseLeave, function() Tween(b, 0.1, { BackgroundColor3 = Lumen.Theme.Control }) end)
		Connect(b.MouseButton1Click, function()
			if opts.DoubleClick and not confirming then
				confirming = true
				b.Text = "Click again to confirm"
				b.TextColor3 = Lumen.Theme.Warning
				task.delay(2.5, function()
					if confirming then
						confirming = false
						b.Text = original
						b.TextColor3 = Lumen.Theme.Text
					end
				end)
				return
			end
			if confirming then
				confirming = false
				b.Text = original
				b.TextColor3 = Lumen.Theme.Text
			end
			b.BackgroundColor3 = Lumen.Theme.Accent
			Tween(b, 0.25, { BackgroundColor3 = Lumen.Theme.ControlHover })
			if opts.Callback then task.spawn(opts.Callback) end
		end)
		return b
	end
	B.Button = Make(o)
	function B:AddSubButton(o2)
		if type(o2) == "string" then o2 = { Text = o2 } end
		Make(o2 or {})
		return self
	end
	function B:SetText(t) buttons[1].Text = t end
	return B
end

------------------------------------------------------------------------------
-- Groups / tabboxes
------------------------------------------------------------------------------

local function NewGroupObject(container, frame)
	return setmetatable({ _container = container, Frame = frame }, { __index = Elements })
end

local function SubTabButton(parent, text, order)
	return New("TextButton", {
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), BackgroundTransparency = 1,
		Text = text, TextColor3 = Lumen.Theme.TextDim, LayoutOrder = order, Parent = parent,
		Theme = { BackgroundColor3 = "Accent" },
	}, { Corner(5), Pad(9, 0, 9, 0) })
end

------------------------------------------------------------------------------
-- Panels (free-floating draggable windows: credits, key system, previews...)
------------------------------------------------------------------------------

function Lumen:CreatePanel(o)
	o = o or {}
	local P = setmetatable({}, { __index = Elements })
	local autoH = (o.Height or 0) == 0
	local frame = New("Frame", {
		Position = o.Position or UDim2.new(0.5, -(o.Width or 300) / 2, 0.5, -100),
		Size = UDim2.fromOffset(o.Width or 300, o.Height or 0),
		AutomaticSize = autoH and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		Parent = Gui, Theme = { BackgroundColor3 = "Background" },
	}, { Corner(8), Stroke("Border"), Pad(14, 12, 14, 14), List(8) })
	local header = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 0, Parent = frame,
	}, { List(1) })
	New("TextLabel", {
		Text = o.Title or "Panel", Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.GothamBold, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = header,
	})
	if o.Subtitle then
		New("TextLabel", {
			Text = o.Subtitle, Size = UDim2.new(1, 0, 0, 14), TextSize = 11, TextColor3 = Lumen.Theme.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, Parent = header,
		})
	end
	local content = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1, Parent = frame,
	}, { List(7) })
	P._container, P.Frame = content, frame

	local function Front()
		ZCounter = ZCounter + 1
		frame.ZIndex = ZCounter
	end
	MakeDraggable(header, frame, Front)
	Front()

	function P:SetVisible(v) frame.Visible = v end
	function P:Destroy() ClosePopup() frame:Destroy() end
	return P
end

function Lumen:CreateCredits(o)
	o = o or {}
	local P = self:CreatePanel({
		Title = o.Title or "CREDITS", Subtitle = o.Subtitle or "People behind this script",
		Width = o.Width or 300, Position = o.Position,
	})
	function P:AddEntry(e)
		local color = e.RoleColor or Lumen.Theme.Accent
		local card = New("Frame", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = (self._container:GetAttribute("Order") or 0) + 1, Parent = self._container,
			Theme = { BackgroundColor3 = "Group" },
		}, { Corner(5), Stroke("Border"), Pad(10, 8, 10, 8), List(4) })
		self._container:SetAttribute("Order", card.LayoutOrder)
		local line = New("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, Parent = card,
		}, { List(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
		New("TextLabel", {
			Text = e.Name or "Name", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20),
			Font = Enum.Font.GothamBold, TextSize = 13, LayoutOrder = 1, Parent = line,
		})
		if e.Role then
			New("TextLabel", {
				Text = e.Role:upper(), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16),
				TextSize = 10, TextColor3 = color, BackgroundTransparency = 0.88, BackgroundColor3 = color,
				LayoutOrder = 2, Parent = line,
			}, { Corner(8), Pad(8, 0, 8, 0), New("UIStroke", { Color = color, Transparency = 0.5 }) })
		end
		if e.Description then
			New("TextLabel", {
				Text = e.Description, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 11,
				TextColor3 = Lumen.Theme.TextDim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2, Parent = card,
			})
		end
		return card
	end
	for _, e in ipairs(o.Entries or {}) do P:AddEntry(e) end
	return P
end

-- Generic key prompt. `Validate(key)` is YOUR function; it should return true (or false, "message").
function Lumen:CreateKeySystem(o)
	o = o or {}
	local P = self:CreatePanel({ Title = o.Title or "Key System", Width = o.Width or 340, Position = o.Position })
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
-- Snow / backdrop effect (shown only while a window is open)
------------------------------------------------------------------------------

local Snow = { Enabled = false, Flakes = {}, Time = 0 }
local SnowFrame = New("Frame", {
	Name = "Snow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true,
	Visible = false, ZIndex = 0, Parent = Gui,
})
local SnowDim = New("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Parent = SnowFrame,
})

function Lumen:_UpdateSnow()
	local any = false
	for _, w in ipairs(self.Windows) do if w.Visible then any = true end end
	SnowFrame.Visible = Snow.Enabled and any
end

-- opts: Count (default 70), Speed (default 1), Dim (0-1 backdrop darkness, default 0.45)
function Lumen:SetSnow(enabled, opts)
	opts = opts or {}
	Snow.Enabled = enabled and true or false
	for _, f in ipairs(Snow.Flakes) do f.Frame:Destroy() end
	Snow.Flakes = {}
	if Snow.Enabled then
		Snow.Speed = opts.Speed or 1
		SnowDim.BackgroundTransparency = 1 - math.clamp(opts.Dim or 0.45, 0, 1)
		for i = 1, opts.Count or 70 do
			local size = math.random(3, 9)
			local frame = New("Frame", {
				Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.25 + math.random() * 0.5, Parent = SnowFrame,
			}, { Corner(size) })
			table.insert(Snow.Flakes, {
				Frame = frame, X = math.random(), Y = math.random(), Speed = 0.03 + (size / 9) * 0.07,
				Sway = 0.4 + math.random() * 0.8, Phase = math.random() * 6.28,
			})
		end
	end
	self:_UpdateSnow()
end

Connect(RunService.RenderStepped, function(dt)
	if not SnowFrame.Visible then return end
	Snow.Time = Snow.Time + dt
	for _, f in ipairs(Snow.Flakes) do
		f.Y = f.Y + f.Speed * Snow.Speed * dt
		if f.Y > 1.03 then f.Y = -0.03 f.X = math.random() end
		f.Frame.Position = UDim2.fromScale(f.X + math.sin(Snow.Time * f.Sway + f.Phase) * 0.008, f.Y)
	end
end)

------------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------------

local function Pill(parent, spec, order)
	return New("TextLabel", {
		Text = spec.Text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), TextSize = 11,
		TextColor3 = spec.Color, BackgroundTransparency = 0.86, BackgroundColor3 = spec.Color,
		LayoutOrder = order, Parent = parent,
	}, { Corner(9), Pad(9, 0, 9, 0), New("UIStroke", { Color = spec.Color, Transparency = 0.55 }) })
end

local function PillSpec(v, default)
	if type(v) == "string" then return { Text = v, Color = default } end
	if type(v) == "table" then return { Text = v.Text, Color = v.Color or default } end
end

function Lumen:CreateWindow(o)
	o = o or {}
	local W = { Tabs = {}, Title = o.Title or "Lumen", MenuKey = o.MenuKey or Enum.KeyCode.RightShift, Visible = true }
	local size = o.Size or Vector2.new(580, 430)
	if o.Watermark == false then self:SetWatermarkVisible(false) end
	if o.Hotkeys == false then self:SetHotkeysVisible(false) end

	local main = New("Frame", {
		Name = "Window", Size = UDim2.fromOffset(size.X, size.Y), ClipsDescendants = false,
		Position = o.Position or UDim2.new(0.5, -size.X / 2, 0.5, -size.Y / 2),
		Parent = Gui, Theme = { BackgroundColor3 = "Background" },
	}, { Corner(8), Stroke("Border") })
	W.Frame = main

	local header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), Parent = main })
	local titleRow = New("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0.72, 0, 1, 0), Parent = header,
	}, { List(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local titleLabel = New("TextLabel", {
		Text = W.Title, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), Font = Enum.Font.GothamBold,
		TextSize = 13, LayoutOrder = 1, Parent = titleRow,
	})
	local tag = PillSpec(o.Tag, self.Theme.Success)
	if tag then Pill(titleRow, tag, 2) end
	local ver = PillSpec(o.Version, self.Theme.Danger)
	if ver then Pill(titleRow, ver, 3) end
	local subtitle = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0.28, 0, 1, 0),
		Text = o.Subtitle or "", TextSize = 11, TextColor3 = self.Theme.TextDim, TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = header,
	})
	MakeDraggable(header, main)

	local tabbar = New("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 42), Size = UDim2.new(1, -20, 0, 32), BackgroundTransparency = 1,
		ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X, Parent = main,
	}, { List(4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })

	local content = New("Frame", {
		BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 1, -104), Parent = main,
	})
	local footer = New("TextLabel", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 20),
		Text = o.Footer or "", TextSize = 11, TextColor3 = self.Theme.TextDim, Parent = main,
	})

	-- resize grip
	local grip = New("TextButton", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -3), Size = UDim2.fromOffset(14, 14),
		Text = "", Parent = main,
	}, {
		New("Frame", { Size = UDim2.fromOffset(8, 1), Position = UDim2.new(1, -9, 1, -3), BackgroundColor3 = self.Theme.TextDim, Rotation = -45, BackgroundTransparency = 0.4 }),
		New("Frame", { Size = UDim2.fromOffset(4, 1), Position = UDim2.new(1, -6, 1, -3), BackgroundColor3 = self.Theme.TextDim, Rotation = -45, BackgroundTransparency = 0.4 }),
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
				local d = UIS:GetMouseLocation() - startMouse
				main.Size = UDim2.fromOffset(math.max(440, startSize.X + d.X), math.max(320, startSize.Y + d.Y))
			end
		end)
		Connect(UIS.InputEnded, function(i) if IsPress(i) then resizing = false end end)
	end

	function W:SetTitle(t) self.Title = t; titleLabel.Text = t end
	function W:SetSubtitle(t) subtitle.Text = t end
	function W:SetFooter(t) footer.Text = t end

	function W:_StyleTabs()
		for _, t in ipairs(self.Tabs) do
			local on = (t == self.Active)
			t.Page.Visible = on
			Tween(t.Button, 0.12, {
				BackgroundTransparency = on and 0.8 or 1,
				TextColor3 = on and Lumen.Theme.AccentText or Lumen.Theme.TextDim,
			})
		end
	end
	function W:SelectTab(t)
		ClosePopup()
		self.Active = t
		self:_StyleTabs()
	end
	table.insert(Refreshers, function() W:_StyleTabs() end)

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
		local T = { Name = name, Window = W, _flip = false }
		T.Button = New("TextButton", {
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), BackgroundTransparency = 1,
			Text = name, TextColor3 = Lumen.Theme.TextDim, LayoutOrder = #W.Tabs + 1, Parent = tabbar,
			Theme = { BackgroundColor3 = "Accent" },
		}, { Corner(5), Pad(13, 0, 13, 0) })
		T.Page = New("ScrollingFrame", {
			Visible = false, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 2,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = content,
			Theme = { ScrollBarImageColor3 = "Accent" },
		}, { Pad(10, 4, 10, 10), List(8) })
		local banners = New("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 0, Parent = T.Page,
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

		local function PickColumn(side)
			if side == "Right" or side == 2 then return right end
			if side == "Left" or side == 1 then return left end
			T._flip = not T._flip
			return T._flip and left or right
		end

		local function NewBox(side)
			return New("Frame", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = PickColumn(side),
				Theme = { BackgroundColor3 = "Group" },
			}, { Corner(6), Stroke("Border"), Pad(10), List(8) })
		end

		function T:AddGroup(title, side)
			local frame = NewBox(side)
			if title then
				New("TextLabel", {
					Text = title, Size = UDim2.new(1, 0, 0, 16), Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0, Parent = frame,
				})
			end
			local c = New("Frame", {
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1, Parent = frame,
			}, { List(7) })
			return NewGroupObject(c, frame)
		end

		function T:AddTabbox(side)
			local frame = NewBox(side)
			local bar = New("Frame", {
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 0, Parent = frame,
			}, { List(4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
			local body = New("Frame", {
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1, Parent = frame,
			})
			local Box, subs, active = { Frame = frame }, {}, nil
			local function Style()
				for _, s in ipairs(subs) do
					local on = (s == active)
					s.Container.Visible = on
					Tween(s.Button, 0.12, {
						BackgroundTransparency = on and 0.8 or 1,
						TextColor3 = on and Lumen.Theme.AccentText or Lumen.Theme.TextDim,
					})
				end
			end
			table.insert(Refreshers, Style)
			function Box:AddTab(name)
				local s = {}
				s.Button = SubTabButton(bar, name, #subs + 1)
				s.Container = New("Frame", {
					BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
					Visible = false, Parent = body,
				}, { Pad(0, 2, 0, 0), List(7) })
				table.insert(subs, s)
				Connect(s.Button.MouseButton1Click, function()
					ClosePopup()
					active = s
					Style()
				end)
				if not active then active = s end
				Style()
				return NewGroupObject(s.Container, frame)
			end
			return Box
		end

		function T:AddWarning(wo)
			if type(wo) == "string" then wo = { Text = wo } end
			local color = Lumen.Theme[wo.Type or "Warning"] or Lumen.Theme.Warning
			local f = New("Frame", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = #banners:GetChildren(), Parent = banners, Theme = { BackgroundColor3 = "Group" },
			}, { Corner(6), Stroke("Border"), Pad(12, 8, 12, 8), List(2) })
			local tl = wo.Title and New("TextLabel", {
				Text = wo.Title, Size = UDim2.new(1, 0, 0, 16), Font = Enum.Font.GothamBold, TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = f,
			})
			local bl = New("TextLabel", {
				Text = wo.Text or "", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 11,
				TextColor3 = Lumen.Theme.TextDim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2, Parent = f,
			})
			return {
				SetText = function(_, t) bl.Text = t end,
				SetTitle = function(_, t) if tl then tl.Text = t end end,
				SetVisible = function(_, v) f.Visible = v end,
				Destroy = function() f:Destroy() end,
			}
		end

		Connect(T.Button.MouseButton1Click, function() W:SelectTab(T) end)
		table.insert(W.Tabs, T)
		if not W.Active then W:SelectTab(T) end
		return T
	end

	-- Ready-made settings tab: menu key, accent color, HUD toggles, configs, unload
	function W:AddConfigTab(name)
		local tab = self:AddTab(name or "Config")
		local menu = tab:AddGroup("Menu", "Left")

		menu:AddLabel("Menu keybind"):AddKeybind({
			Default = self.MenuKey, Mode = "Press", Flag = "Lumen_MenuKey", ShowInList = false,
			ChangedCallback = function(k) if k then W.MenuKey = k end end,
		})
		menu:AddLabel("Accent color"):AddColorPicker({
			Default = Lumen.Theme.Accent, Flag = "Lumen_Accent",
			Callback = function(c) Lumen:SetTheme({ Accent = c }) end,
		})
		menu:AddToggle({ Text = "Show watermark", Default = Lumen.ShowWatermark, Flag = "Lumen_Watermark",
			Callback = function(v) Lumen:SetWatermarkVisible(v) end })
		menu:AddToggle({ Text = "Show hotkey list", Default = Lumen.ShowHotkeys, Flag = "Lumen_Hotkeys",
			Callback = function(v) Lumen:SetHotkeysVisible(v) end })
		menu:AddToggle({ Text = "Snow effect", Default = Snow.Enabled, Flag = "Lumen_Snow",
			Callback = function(v) Lumen:SetSnow(v) end })
		menu:AddDivider()
		menu:AddButton({ Text = "Unload", DoubleClick = true, Callback = function() Lumen:Unload() end })

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

	-- mobile toggle button
	if UIS.TouchEnabled and not UIS.KeyboardEnabled and o.MobileButton ~= false then
		local mb = New("TextButton", {
			Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 14, 0.5, -22), Text = "UI", Font = Enum.Font.GothamBold,
			BackgroundTransparency = 0, ZIndex = 20, Parent = Gui, Theme = { BackgroundColor3 = "Group" },
		}, { Corner(22), Stroke("Accent") })
		Connect(mb.MouseButton1Click, function() W:Toggle() end)
	end

	table.insert(Lumen.Windows, W)
	if o.Snow then self:SetSnow(true, type(o.Snow) == "table" and o.Snow or nil) end
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

	if UIS:GetFocusedTextBox() then return end
	local mouseBtn = input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3
	if mouseBtn and gp then return end

	for _, w in ipairs(Lumen.Windows) do
		if Matches(input, w.MenuKey) then w:Toggle() end
	end
	for _, K in ipairs(Keybinds) do
		if K.Value and Matches(input, K.Value) then
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
	Gui:Destroy()
	if env.LumenUI == self then env.LumenUI = nil end
end

return Lumen
