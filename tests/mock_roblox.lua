--[[
	A small headless stand-in for the Roblox client API, just enough to run TingUI.lua under the plain Luau CLI.
	Instances accept any property, events are real signals, datatypes do real maths, and nothing is drawn.
	It catches load errors, nil calls and broken logic paths; it can't tell you how the UI looks.
]]

local M = {}

-- signals -----------------------------------------------------------------
local function Signal()
	local s = { _h = {} }
	function s:Connect(fn)
		local c = { Connected = true }
		function c:Disconnect() self.Connected = false end
		c.Fn = fn
		table.insert(s._h, c)
		return c
	end
	s.connect = s.Connect
	function s:Once(fn)
		local c
		c = s:Connect(function(...) c:Disconnect() fn(...) end)
		return c
	end
	function s:Fire(...)
		for _, c in ipairs(table.clone(s._h)) do
			if c.Connected then c.Fn(...) end
		end
	end
	function s:Wait() return end
	return s
end
M.Signal = Signal

-- datatypes ---------------------------------------------------------------
local Types = setmetatable({}, { __mode = "k" })
local function typeof(v)
	local t = type(v) == "table" and Types[v]
	if t then return t end
	return type(v)
end
M.typeof = typeof

local function Datatype(name, mt)
	mt.__index = mt.__index or mt
	return function(t) Types[t] = name return setmetatable(t, mt) end
end

local V2mt = {}
local MakeV2 = Datatype("Vector2", V2mt)
local Vector2 = {}
function Vector2.new(x, y) return MakeV2({ X = x or 0, Y = y or 0 }) end
local function v2(a) return type(a) == "number" and Vector2.new(a, a) or a end
V2mt.__add = function(a, b) a, b = v2(a), v2(b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
V2mt.__sub = function(a, b) a, b = v2(a), v2(b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
V2mt.__mul = function(a, b) a, b = v2(a), v2(b) return Vector2.new(a.X * b.X, a.Y * b.Y) end
V2mt.__div = function(a, b) a, b = v2(a), v2(b) return Vector2.new(a.X / b.X, a.Y / b.Y) end
V2mt.__unm = function(a) return Vector2.new(-a.X, -a.Y) end
V2mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
V2mt.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y) end
	if k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y) return m > 0 and Vector2.new(t.X / m, t.Y / m) or Vector2.new() end
	if k == "Lerp" then return function(a, b, f) return a + (b - a) * f end end
	if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y end end
	return nil
end
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)

local V3mt = {}
local MakeV3 = Datatype("Vector3", V3mt)
local Vector3 = {}
function Vector3.new(x, y, z) return MakeV3({ X = x or 0, Y = y or 0, Z = z or 0 }) end
local function v3(a) return type(a) == "number" and Vector3.new(a, a, a) or a end
V3mt.__add = function(a, b) a, b = v3(a), v3(b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3mt.__sub = function(a, b) a, b = v3(a), v3(b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3mt.__mul = function(a, b) a, b = v3(a), v3(b) return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
V3mt.__div = function(a, b) a, b = v3(a), v3(b) return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z) end
V3mt.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
V3mt.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) return m > 0 and t / m or Vector3.new() end
	if k == "Lerp" then return function(a, b, f) return a + (b - a) * f end end
	return nil
end
Vector3.zero = Vector3.new()
Vector3.one = Vector3.new(1, 1, 1)

local CFmt = {}
local MakeCF = Datatype("CFrame", CFmt)
local CFrame = {}
function CFrame.new(x, y, z)
	if typeof(x) == "Vector3" then x, y, z = x.X, x.Y, x.Z end
	return MakeCF({ Position = Vector3.new(x or 0, y or 0, z or 0) })
end
function CFrame.lookAt(p) return CFrame.new(p) end
CFrame.Angles = function() return CFrame.new() end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
CFmt.__mul = function(a, b) if typeof(b) == "Vector3" then return a.Position + b end return CFrame.new(a.Position + (b.Position or Vector3.new())) end
CFmt.__add = function(a, b) return CFrame.new(a.Position + b) end
CFmt.__index = function(t, k)
	local p = rawget(t, "Position")
	if k == "X" or k == "Y" or k == "Z" then return p[k] end
	if k == "LookVector" then return Vector3.new(0, 0, -1) end
	if k == "RightVector" then return Vector3.new(1, 0, 0) end
	if k == "UpVector" then return Vector3.new(0, 1, 0) end
	if k == "PointToObjectSpace" then return function(self, v) return v - p end end
	if k == "Inverse" then return function() return CFrame.new(-p) end end
	if k == "Lerp" then return function(a, b) return b end end
	if k == "ToEulerAnglesXYZ" then return function() return 0, 0, 0 end end
end
CFrame.identity = CFrame.new()

local UDmt = {}
local MakeUD = Datatype("UDim", UDmt)
local UDim = {}
function UDim.new(s, o) return MakeUD({ Scale = s or 0, Offset = o or 0 }) end
UDmt.__add = function(a, b) return UDim.new(a.Scale + b.Scale, a.Offset + b.Offset) end
UDmt.__sub = function(a, b) return UDim.new(a.Scale - b.Scale, a.Offset - b.Offset) end
UDmt.__eq = function(a, b) return a.Scale == b.Scale and a.Offset == b.Offset end

local U2mt = {}
local MakeU2 = Datatype("UDim2", U2mt)
local UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
	if typeof(xs) == "UDim" then return MakeU2({ X = xs, Y = xo }) end
	return MakeU2({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) })
end
function UDim2.fromOffset(x, y) return UDim2.new(0, x or 0, 0, y or 0) end
function UDim2.fromScale(x, y) return UDim2.new(x or 0, 0, y or 0, 0) end
U2mt.__add = function(a, b) return UDim2.new(a.X + b.X, a.Y + b.Y) end
U2mt.__sub = function(a, b) return UDim2.new(a.X - b.X, a.Y - b.Y) end
U2mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
U2mt.__index = function(t, k)
	if k == "Width" then return rawget(t, "X") end
	if k == "Height" then return rawget(t, "Y") end
	if k == "Lerp" then return function(a, b, f)
		return UDim2.new(a.X.Scale + (b.X.Scale - a.X.Scale) * f, a.X.Offset + (b.X.Offset - a.X.Offset) * f,
			a.Y.Scale + (b.Y.Scale - a.Y.Scale) * f, a.Y.Offset + (b.Y.Offset - a.Y.Offset) * f)
	end end
end

local C3mt = {}
local MakeC3 = Datatype("Color3", C3mt)
local Color3 = {}
function Color3.new(r, g, b) return MakeC3({ R = r or 0, G = g or 0, B = b or 0 }) end
function Color3.fromRGB(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function Color3.fromHex(h)
	h = h:gsub("#", "")
	return Color3.fromRGB(tonumber(h:sub(1, 2), 16) or 0, tonumber(h:sub(3, 4), 16) or 0, tonumber(h:sub(5, 6), 16) or 0)
end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then return Color3.new(v, t, p) elseif i == 1 then return Color3.new(q, v, p) elseif i == 2 then return Color3.new(p, v, t)
	elseif i == 3 then return Color3.new(p, q, v) elseif i == 4 then return Color3.new(t, p, v) end
	return Color3.new(v, p, q)
end
function Color3.toHSV(c)
	local r, g, b = c.R, c.G, c.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then h = ((g - b) / d) % 6 elseif mx == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
		h = h / 6
	end
	return h, mx == 0 and 0 or d / mx, mx
end
C3mt.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
C3mt.__index = {
	Lerp = function(a, b, f) return Color3.new(a.R + (b.R - a.R) * f, a.G + (b.G - a.G) * f, a.B + (b.B - a.B) * f) end,
	ToHSV = function(c) return Color3.toHSV(c) end,
	ToHex = function(c) return string.format("%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end,
}

local function Plain(name, fields)
	local ctor = Datatype(name, {})
	return function(...) return ctor(fields(...)) end
end
local ColorSequenceKeypoint = { new = Plain("ColorSequenceKeypoint", function(t, c) return { Time = t, Value = c } end) }
local ColorSequence = { new = Plain("ColorSequence", function(a, b)
	if type(a) == "table" and not Types[a] then return { Keypoints = a } end
	b = b or a
	return { Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b) } }
end) }
local NumberSequenceKeypoint = { new = Plain("NumberSequenceKeypoint", function(t, v, e) return { Time = t, Value = v, Envelope = e or 0 } end) }
local NumberSequence = { new = Plain("NumberSequence", function(a, b)
	if type(a) == "table" then return { Keypoints = a } end
	b = b or a
	return { Keypoints = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) } }
end) }
local NumberRange = { new = Plain("NumberRange", function(a, b) return { Min = a, Max = b or a } end) }
local Rect = { new = Plain("Rect", function(a, b, c, d) return { Min = Vector2.new(a, b), Max = Vector2.new(c, d) } end) }
local TweenInfo = { new = Plain("TweenInfo", function(t, s, d, r, rev, delay)
	return { Time = t or 1, EasingStyle = s, EasingDirection = d, RepeatCount = r or 0, Reverses = rev or false, DelayTime = delay or 0 }
end) }

-- enums -------------------------------------------------------------------
local EnumItemMt = { __tostring = function(e) return "Enum." .. e.EnumType.Name .. "." .. e.Name end }
local function EnumType(name)
	local items, n = {}, 0
	local et = { Name = name }
	function et.GetEnumItems() local out = {} for _, v in pairs(items) do table.insert(out, v) end return out end
	setmetatable(et, {
		__index = function(_, k)
			if items[k] then return items[k] end
			n = n + 1
			local item = setmetatable({ Name = k, Value = n, EnumType = et }, EnumItemMt)
			Types[item] = "EnumItem"
			items[k] = item
			return item
		end,
		__tostring = function() return name end,
	})
	Types[et] = "Enum"
	return et
end
local Enum = setmetatable({}, { __index = function(t, k) local e = EnumType(k) rawset(t, k, e) return e end })
-- the few enum values whose numbers matter
for name, v in pairs({ Low = 1000, Medium = 2000, Default = 2000, High = 3000 }) do rawset(Enum.ContextActionPriority[name], "Value", v) end

local Font = {}
local FontMt = { __index = {} }
function Font.new(family, weight, style)
	local f = setmetatable({ Family = family, Weight = weight or Enum.FontWeight.Regular, Style = style or Enum.FontStyle.Normal }, FontMt)
	Types[f] = "Font"
	return f
end
function Font.fromEnum(e) return Font.new("rbxasset://fonts/families/" .. e.Name .. ".json") end
function Font.fromName(n) return Font.new("rbxasset://fonts/families/" .. n .. ".json") end
setmetatable(Font, { __index = function(_, k) return Font.fromName(k) end })

-- instances ---------------------------------------------------------------
local Defaults = {
	Visible = true, Enabled = true, Transparency = 0, BackgroundTransparency = 0, TextTransparency = 0, ImageTransparency = 0,
	TextSize = 14, Text = "", Image = "", ZIndex = 1, LayoutOrder = 0, Rotation = 0, Thickness = 1, Value = 0,
	Archivable = true, ClipsDescendants = false, Active = false, TextEditable = true, Scale = 1,
}
local VectorDefaults = { AbsoluteSize = true, AbsolutePosition = true, TextBounds = true, AbsoluteContentSize = true,
	CanvasPosition = true, AbsoluteCanvasSize = true, AbsoluteWindowSize = true, ViewportSize = true }
local EventNames = {
	Changed = true, ChildAdded = true, ChildRemoved = true, DescendantAdded = true, DescendantRemoving = true, Destroying = true,
	AncestryChanged = true, InputBegan = true, InputChanged = true, InputEnded = true, MouseEnter = true, MouseLeave = true,
	MouseMoved = true, Activated = true, MouseButton1Click = true, MouseButton1Down = true, MouseButton1Up = true,
	MouseButton2Click = true, MouseButton2Down = true, MouseButton2Up = true, FocusLost = true, Focused = true,
	MouseWheelForward = true, MouseWheelBackward = true, Completed = true, PlayerAdded = true, PlayerRemoving = true,
	CharacterAdded = true, CharacterRemoving = true, Died = true, Heartbeat = true, RenderStepped = true, Stepped = true,
	PreRender = true, PostSimulation = true, JumpRequest = true, TouchStarted = true, TouchEnded = true, TouchMoved = true,
	WindowFocused = true, WindowFocusReleased = true, LastInputTypeChanged = true, ReturnPressedFromOnScreenKeyboard = true,
	TextBoxFocused = true, TextBoxFocusReleased = true, AttributeChanged = true, Idled = true, OnClientEvent = true,
}

local AllInstances = setmetatable({}, { __mode = "k" })
local Inst = {}
local InstMt = {}

local function NewInstance(class, props)
	local self = { _class = class, _props = {}, _children = {}, _attrs = {}, _events = {}, _propSignals = {}, _attrSignals = {} }
	setmetatable(self, InstMt)
	Types[self] = "Instance"
	AllInstances[self] = true
	self._props.Name = class
	self._props.ClassName = class
	for k, v in pairs(props or {}) do self._props[k] = v end
	return self
end
M.NewInstance = NewInstance

local IsA = {
	GuiObject = { Frame = 1, TextLabel = 1, TextButton = 1, TextBox = 1, ImageLabel = 1, ImageButton = 1, ScrollingFrame = 1, ViewportFrame = 1, CanvasGroup = 1 },
	GuiButton = { TextButton = 1, ImageButton = 1 },
	GuiBase2d = { Frame = 1, TextLabel = 1, TextButton = 1, TextBox = 1, ImageLabel = 1, ImageButton = 1, ScrollingFrame = 1, ViewportFrame = 1, ScreenGui = 1, CanvasGroup = 1 },
	LayerCollector = { ScreenGui = 1, BillboardGui = 1, SurfaceGui = 1 },
	BasePart = { Part = 1, MeshPart = 1, UnionOperation = 1 },
	UIComponent = { UICorner = 1, UIStroke = 1, UIGradient = 1, UIPadding = 1, UIListLayout = 1, UIGridLayout = 1, UIScale = 1, UISizeConstraint = 1 },
	ValueBase = { NumberValue = 1, StringValue = 1, BoolValue = 1 },
	LuaSourceContainer = { ModuleScript = 1, LocalScript = 1, Script = 1 },
}

function Inst:IsA(c) return self._class == c or c == "Instance" or (IsA[c] and IsA[c][self._class] ~= nil) or false end
function Inst:GetChildren() return table.clone(self._children) end
function Inst:GetDescendants()
	local out = {}
	local function walk(i) for _, c in ipairs(i._children) do table.insert(out, c) walk(c) end end
	walk(self)
	return out
end
function Inst:FindFirstChild(name, recursive)
	for _, c in ipairs(self._children) do if c._props.Name == name then return c end end
	if recursive then for _, c in ipairs(self._children) do local f = c:FindFirstChild(name, true) if f then return f end end end
	return nil
end
function Inst:FindFirstChildOfClass(cls) for _, c in ipairs(self._children) do if c._class == cls then return c end end end
function Inst:FindFirstChildWhichIsA(cls) for _, c in ipairs(self._children) do if c:IsA(cls) then return c end end end
function Inst:FindFirstAncestorOfClass(cls) local p = self._props.Parent while p do if p._class == cls then return p end p = p._props.Parent end end
function Inst:WaitForChild(name) return self:FindFirstChild(name) or error("WaitForChild would hang: " .. tostring(name)) end
function Inst:IsDescendantOf(a) local p = self._props.Parent while p do if p == a then return true end p = p._props.Parent end return false end
function Inst:IsAncestorOf(d) return d:IsDescendantOf(self) end
function Inst:GetAttribute(k) return self._attrs[k] end
function Inst:GetAttributes() return table.clone(self._attrs) end
function Inst:SetAttribute(k, v)
	self._attrs[k] = v
	if self._attrSignals[k] then self._attrSignals[k]:Fire() end
end
function Inst:GetAttributeChangedSignal(k) self._attrSignals[k] = self._attrSignals[k] or Signal() return self._attrSignals[k] end
function Inst:GetPropertyChangedSignal(k) self._propSignals[k] = self._propSignals[k] or Signal() return self._propSignals[k] end
function Inst:ClearAllChildren() for _, c in ipairs(self:GetChildren()) do c:Destroy() end end
function Inst:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	if self._events.Destroying then self._events.Destroying:Fire() end
	for _, c in ipairs(self:GetChildren()) do c:Destroy() end
	self.Parent = nil
end
function Inst:Remove() self.Parent = nil end
function Inst:Clone()
	local c = NewInstance(self._class)
	for k, v in pairs(self._props) do if k ~= "Parent" then c._props[k] = v end end
	for k, v in pairs(self._attrs) do c._attrs[k] = v end
	for _, ch in ipairs(self._children) do ch:Clone().Parent = c end
	return c
end
function Inst:GetFullName()
	local n, p = self._props.Name, self._props.Parent
	while p and p ~= M.game do n = p._props.Name .. "." .. n p = p._props.Parent end
	return n
end
function Inst:CaptureFocus() self._focused = true end
function Inst:ReleaseFocus() self._focused = false end
function Inst:IsFocused() return self._focused == true end
function Inst:TweenSize() return true end
function Inst:TweenPosition() return true end
function Inst:TweenSizeAndPosition() return true end
function Inst:GetBoundingBox() return CFrame.new(), Vector3.new(4, 5, 1) end
function Inst:GetExtentsSize() return Vector3.new(4, 5, 1) end
function Inst:GetPivot() return CFrame.new() end
function Inst:PivotTo(cf) self._pivot = cf end
function Inst:SetPrimaryPartCFrame() end
function Inst:ScrollToTop() end
function Inst:Play() self._playing = true end
function Inst:Stop() self._playing = false end
function Inst:Pause() end
function Inst:Cancel() end
function Inst:Fire(...) if self._events.Event then self._events.Event:Fire(...) end end
function Inst:Invoke() end
function Inst:Disconnect() end
function Inst:ScreenPointToRay() return { Origin = Vector3.new(), Direction = Vector3.new(0, 0, -1) } end
function Inst:ViewportPointToRay() return { Origin = Vector3.new(), Direction = Vector3.new(0, 0, -1) } end
function Inst:WorldToViewportPoint(p) return Vector3.new(p.X, p.Y, 1), true end
function Inst:WorldToScreenPoint(p) return Vector3.new(p.X, p.Y, 1), true end
function Inst:GetPlayingAnimationTracks() return {} end
function Inst:GetChildrenOfClass() return {} end
function Inst:GetCharacterAppearanceAsync() return NewInstance("Model") end

local function SetParent(self, p)
	local old = self._props.Parent
	if old == p then return end
	if old then
		for i, c in ipairs(old._children) do if c == self then table.remove(old._children, i) break end end
		if old._events.ChildRemoved then old._events.ChildRemoved:Fire(self) end
	end
	self._props.Parent = p
	if p then
		table.insert(p._children, self)
		if p._events.ChildAdded then p._events.ChildAdded:Fire(self) end
		local a = p
		while a do
			if a._events.DescendantAdded then a._events.DescendantAdded:Fire(self) end
			a = a._props.Parent
		end
	end
	if self._events.AncestryChanged then self._events.AncestryChanged:Fire(self, p) end
end

InstMt.__index = function(self, k)
	local m = Inst[k]
	if m then return m end
	local v = self._props[k]
	if v ~= nil then return v end
	if k == "Parent" then return nil end
	if EventNames[k] or k == "Event" then
		self._events[k] = self._events[k] or Signal()
		return self._events[k]
	end
	local child = self:FindFirstChild(k)
	if child then return child end
	if VectorDefaults[k] then return Vector2.new(0, 0) end
	if Defaults[k] ~= nil then return Defaults[k] end
	if k:find("Color3$") or k == "Color" then return Color3.new(1, 1, 1) end
	if k == "Size" or k == "Position" then return UDim2.new(0, 0, 0, 0) end
	if k == "CanvasSize" then return UDim2.new(0, 0, 0, 0) end
	if k == "CornerRadius" then return UDim.new(0, 0) end
	if k == "AnchorPoint" then return Vector2.new(0, 0) end
	if k == "CFrame" then return CFrame.new() end
	if k == "FontFace" then return Font.new("rbxasset://fonts/families/GothamSSm.json") end
	if k == "Font" then return Enum.Font.Gotham end
	return nil
end
InstMt.__newindex = function(self, k, v)
	if self._destroyed and k == "Parent" and v ~= nil then error("The Parent property of " .. self._props.Name .. " is locked") end
	if k == "Parent" then SetParent(self, v)
	else
		local old = self._props[k]
		self._props[k] = v
		if old ~= v then
			if self._propSignals[k] then self._propSignals[k]:Fire() end
			if self._events.Changed then self._events.Changed:Fire(k) end
		end
	end
end
InstMt.__tostring = function(self) return self._props.Name end

local Instance = {}
function Instance.new(class, parent)
	local i = NewInstance(class)
	if parent then i.Parent = parent end
	return i
end

-- scheduler ---------------------------------------------------------------
-- task.spawn runs straight away; waits/delays queue up and run when the test calls M.Step()
local Queue = {}
local Clock = 0
local function Resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		M.Errors = M.Errors or {}
		table.insert(M.Errors, tostring(err) .. "\n" .. debug.traceback(co))
	end
end
local task = {}
function task.spawn(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	Resume(co, ...)
	return co
end
function task.defer(f, ...) table.insert(Queue, { at = Clock, co = type(f) == "thread" and f or coroutine.create(f), args = table.pack(...) }) end
function task.delay(t, f, ...) table.insert(Queue, { at = Clock + (t or 0), co = type(f) == "thread" and f or coroutine.create(f), args = table.pack(...) }) end
function task.wait(t)
	local co = coroutine.running()
	if not coroutine.isyieldable() then return 0 end
	table.insert(Queue, { at = Clock + (t or 0), co = co, args = table.pack(t or 0) })
	return coroutine.yield()
end
function task.cancel(co) for i = #Queue, 1, -1 do if Queue[i].co == co then table.remove(Queue, i) end end end
function task.synchronize() end
function task.desynchronize() end

-- advance fake time by dt, running heartbeat-style signals and anything queued that is due
function M.Step(dt, frames)
	for _ = 1, frames or 1 do
		Clock = Clock + dt
		M.RunService.Heartbeat:Fire(dt)
		M.RunService.RenderStepped:Fire(dt)
		M.RunService.PreRender:Fire(dt)
		M.RunService.Stepped:Fire(Clock, dt)
		local due = {}
		for i = #Queue, 1, -1 do
			if Queue[i].at <= Clock then table.insert(due, 1, table.remove(Queue, i)) end
		end
		for _, q in ipairs(due) do
			if coroutine.status(q.co) == "suspended" then Resume(q.co, table.unpack(q.args, 1, q.args.n)) end
		end
	end
end

-- services ----------------------------------------------------------------
local game = NewInstance("DataModel", { Name = "Game", PlaceId = 1, JobId = "test", GameId = 1, CreatorId = 1 })
M.game = game
local Services = {}
local function Service(name, extra)
	local s = NewInstance(name, { Name = name })
	for k, v in pairs(extra or {}) do s._props[k] = v end
	s.Parent = game
	Services[name] = s
	return s
end

local RunService = Service("RunService")
M.RunService = RunService
rawset(RunService, "_isServer", false)
function RunService.IsServer() return M.IsServer == true end
function RunService.IsClient() return M.IsServer ~= true end
function RunService.IsStudio() return true end
function RunService.IsRunning() return true end
function RunService.BindToRenderStep() end
function RunService.UnbindFromRenderStep() end
for _, e in ipairs({ "Heartbeat", "RenderStepped", "Stepped", "PreRender" }) do RunService._events[e] = Signal() end

local Players = Service("Players")
local PlayerGui = NewInstance("PlayerGui", { Name = "PlayerGui" })
local LocalPlayer = NewInstance("Player", { Name = "TestPlayer", DisplayName = "Tester", UserId = 1, AccountAge = 100, MembershipType = Enum.MembershipType.None })
PlayerGui.Parent = LocalPlayer
LocalPlayer.Parent = Players
Players._props.LocalPlayer = LocalPlayer
function Players.GetPlayers(self) return self:GetChildren() end
function Players.GetPlayerFromCharacter() return nil end
function Players.GetUserThumbnailAsync() return "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150", true end
function Players.GetNameFromUserIdAsync() return "TestPlayer" end
function Players.GetHumanoidDescriptionFromUserId() return NewInstance("HumanoidDescription") end
function Players.CreateHumanoidModelFromDescription() return NewInstance("Model") end
function Players.CreateHumanoidModelFromUserId() return NewInstance("Model") end
M.PlayerGui = PlayerGui
M.LocalPlayer = LocalPlayer

local UIS = Service("UserInputService", { TouchEnabled = false, KeyboardEnabled = true, MouseEnabled = true, GamepadEnabled = false,
	MouseBehavior = Enum.MouseBehavior.Default, MouseIconEnabled = true })
M.Keys = {}
function UIS.IsKeyDown(_, k) return M.Keys[k] == true end
function UIS.IsMouseButtonPressed() return false end
function UIS.GetMouseLocation() return Vector2.new(400, 300) end
function UIS.GetFocusedTextBox() return nil end
function UIS.GetLastInputType() return Enum.UserInputType.MouseButton1 end
function UIS.GetMouseDelta() return Vector2.new() end
function UIS.GetKeysPressed() return {} end
function UIS.GetStringForKeyCode(_, k) return k.Name end

local TweenService = Service("TweenService")
function TweenService.Create(_, obj, info, props)
	local tw = NewInstance("Tween")
	function tw.Play()
		for k, v in pairs(props) do obj[k] = v end
		tw._props.PlaybackState = Enum.PlaybackState.Completed
		task.defer(function() tw.Completed:Fire(Enum.PlaybackState.Completed) end)
	end
	function tw.Cancel() end
	function tw.Pause() end
	return tw
end
function TweenService.GetValue(_, a) return a end

local HttpService = Service("HttpService", { HttpEnabled = false })
local function JSONEncode(v, depth)
	depth = depth or 0
	local t = type(v)
	if t == "nil" then return "null" end
	if t == "boolean" or t == "number" then return tostring(v) end
	if t == "string" then
		return '"' .. v:gsub('[%c"\\]', function(c)
			local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" }
			return map[c] or string.format("\\u%04x", c:byte())
		end) .. '"'
	end
	if t == "table" then
		if Types[v] then error("Can't convert " .. Types[v] .. " to JSON") end
		if #v > 0 or next(v) == nil then
			local parts = {}
			for _, x in ipairs(v) do table.insert(parts, JSONEncode(x, depth + 1)) end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for k, x in pairs(v) do table.insert(parts, JSONEncode(tostring(k)) .. ":" .. JSONEncode(x, depth + 1)) end
		table.sort(parts)
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("Can't convert " .. t .. " to JSON")
end
local function JSONDecode(s)
	local pos = 1
	local function ws() pos = s:find("[^%s]", pos) or #s + 1 end
	local val
	local function str()
		local out = {}
		pos = pos + 1
		while true do
			local c = s:sub(pos, pos)
			if c == "" then error("unterminated string") end
			if c == '"' then pos = pos + 1 break end
			if c == "\\" then
				local n = s:sub(pos + 1, pos + 1)
				local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
				if n == "u" then table.insert(out, utf8.char(tonumber(s:sub(pos + 2, pos + 5), 16))) pos = pos + 6
				else table.insert(out, map[n] or n) pos = pos + 2 end
			else table.insert(out, c) pos = pos + 1 end
		end
		return table.concat(out)
	end
	function val()
		ws()
		local c = s:sub(pos, pos)
		if c == "{" then
			pos = pos + 1
			local t = {}
			ws()
			if s:sub(pos, pos) == "}" then pos = pos + 1 return t end
			while true do
				ws()
				local k = str()
				ws()
				assert(s:sub(pos, pos) == ":", "expected :")
				pos = pos + 1
				t[k] = val()
				ws()
				local d = s:sub(pos, pos)
				pos = pos + 1
				if d == "}" then return t end
				assert(d == ",", "expected ,")
			end
		elseif c == "[" then
			pos = pos + 1
			local t = {}
			ws()
			if s:sub(pos, pos) == "]" then pos = pos + 1 return t end
			while true do
				table.insert(t, val())
				ws()
				local d = s:sub(pos, pos)
				pos = pos + 1
				if d == "]" then return t end
				assert(d == ",", "expected ,")
			end
		elseif c == '"' then return str()
		elseif s:sub(pos, pos + 3) == "true" then pos = pos + 4 return true
		elseif s:sub(pos, pos + 4) == "false" then pos = pos + 5 return false
		elseif s:sub(pos, pos + 3) == "null" then pos = pos + 4 return nil
		else
			local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
			if not num or num == "" then error("Can't parse JSON at " .. pos) end
			pos = pos + #num
			return tonumber(num)
		end
	end
	return val()
end
function HttpService.JSONEncode(_, v) return JSONEncode(v) end
function HttpService.JSONDecode(_, s) return JSONDecode(s) end
local guid = 0
function HttpService.GenerateGUID(_, braces) guid = guid + 1 local g = string.format("00000000-0000-0000-0000-%012d", guid) return braces == false and g or "{" .. g .. "}" end
function HttpService.UrlEncode(_, s) return s end
function HttpService.GetAsync() error("Http requests are not enabled") end

local TextService = Service("TextService")
function TextService.GetTextSize(_, text, size) return Vector2.new(#tostring(text) * (size or 14) * 0.55, size or 14) end
function TextService.GetTextBoundsAsync(_, p) return Vector2.new(#tostring(p.Text) * (p.Size or 14) * 0.55, p.Size or 14) end

local Stats = Service("Stats")
function Stats.GetTotalMemoryUsageMb() return 512 end
Stats._props.Network = NewInstance("NetworkStats")
Stats._props.Network._props.ServerStatsItem = setmetatable({}, { __index = function() return { GetValue = function() return 50 end, GetValueString = function() return "50 ms" end } end })
local PerformanceStats = NewInstance("PerformanceStats")
Stats._props.PerformanceStats = PerformanceStats
Stats._props.DataReceiveKbps = 0
Stats._props.DataSendKbps = 0
Stats._props.HeartbeatTimeMs = 16

Service("Lighting", { ClockTime = 14, Brightness = 2, FogEnd = 100000, GlobalShadows = true, Ambient = Color3.new(0.5, 0.5, 0.5) })
local CoreGui = Service("CoreGui")
Service("StarterGui")
function Services.StarterGui.SetCore() end
function Services.StarterGui.GetCore() return nil end
Service("ReplicatedStorage")
Service("TeleportService")
Service("GuiService", { MenuIsOpen = false })
function Services.GuiService.GetGuiInset() return Vector2.new(0, 36), Vector2.new() end
Service("ContextActionService")
M.Actions = {}
function Services.ContextActionService.BindAction(_, name, fn, touch, ...) M.Actions[name] = { Fn = fn, Priority = 2000, Keys = { ... } } end
function Services.ContextActionService.BindActionAtPriority(_, name, fn, touch, priority, ...) M.Actions[name] = { Fn = fn, Priority = priority, Keys = { ... } } end
function Services.ContextActionService.UnbindAction(_, name) M.Actions[name] = nil end
-- what the game would see for a key press: the highest-priority action bound to it decides
function M.PressThroughActions(key)
	local best
	for name, a in pairs(M.Actions) do
		for _, k in ipairs(a.Keys) do
			if k == key and (not best or a.Priority > best.Priority) then best = { Name = name, Priority = a.Priority, Fn = a.Fn } end
		end
	end
	if not best then return nil end
	return best.Name, best.Fn(best.Name, Enum.UserInputState.Begin, { KeyCode = key })
end
Service("SoundService")
Service("MarketplaceService")
function Services.MarketplaceService.GetProductInfo() return { Name = "Test Place" } end
Service("TextChatService")
Service("VirtualUser")
Service("Debris")
function Services.Debris.AddItem(_, i, t) task.delay(t or 10, function() i:Destroy() end) end
Service("CollectionService")
function Services.CollectionService.GetTagged() return {} end
Service("ContentProvider")
function Services.ContentProvider.PreloadAsync() end

-- DataStores and RemoteFunctions: the "server" runs in the same process, InvokeServer calls OnServerInvoke directly
Service("DataStoreService")
M.DataStores = {}
function Services.DataStoreService.GetDataStore(_, name)
	M.DataStores[name] = M.DataStores[name] or {}
	local data = M.DataStores[name]
	return {
		GetAsync = function(_, k) if M.DataStoreDown then error("502: API Services rejected request") end return data[k] end,
		SetAsync = function(_, k, v) if M.DataStoreDown then error("502: API Services rejected request") end data[k] = v end,
	}
end
function Inst:InvokeServer(...)
	local fn = self._props.OnServerInvoke
	if not fn then error("no OnServerInvoke") end
	return fn(M.LocalPlayer, ...)
end

local workspace = Service("Workspace")
local Camera = NewInstance("Camera", { ViewportSize = Vector2.new(1280, 720), FieldOfView = 70, CFrame = CFrame.new() })
Camera.Parent = workspace
workspace._props.CurrentCamera = Camera

-- CoreGui refuses non-executor parenting, like a real LocalScript
local rawNewindex = InstMt.__newindex
InstMt.__newindex = function(self, k, v)
	if k == "Parent" and v == CoreGui and not M.ExecutorMode then
		error("The current thread cannot write 'Parent' (lacking capability Plugin)")
	end
	return rawNewindex(self, k, v)
end

function game.GetService(_, name)
	if Services[name] then return Services[name] end
	return Service(name)
end
game.FindService = game.GetService
game._props.Workspace = workspace
for name, s in pairs(Services) do game._props[name] = s end
function game.HttpGet() error("HttpGet is an executor function") end
function game.IsLoaded() return true end
game._events.Loaded = Signal()

-- globals -----------------------------------------------------------------
M.globals = {
	game = game, workspace = workspace, Workspace = workspace, Instance = Instance, Enum = Enum, Font = Font,
	Vector2 = Vector2, Vector3 = Vector3, CFrame = CFrame, UDim = UDim, UDim2 = UDim2, Color3 = Color3,
	ColorSequence = ColorSequence, ColorSequenceKeypoint = ColorSequenceKeypoint, NumberSequence = NumberSequence,
	NumberSequenceKeypoint = NumberSequenceKeypoint, NumberRange = NumberRange, Rect = Rect, TweenInfo = TweenInfo,
	task = task, typeof = typeof, tick = function() return Clock end, time = function() return Clock end,
	wait = task.wait, spawn = task.spawn, delay = task.delay, elapsedTime = function() return Clock end,
	warn = function(...) M.Warnings = M.Warnings or {} table.insert(M.Warnings, table.concat({ ... }, " ")) end,
	DateTime = { now = function() return { UnixTimestamp = 0, UnixTimestampMillis = 0, FormatLocalTime = function() return "12:00" end } end },
	Random = { new = function(seed) local r = { _s = seed or 1 }
		function r:NextNumber(a, b) a, b = a or 0, b or 1 return a + (b - a) * math.random() end
		function r:NextInteger(a, b) return math.random(a, b) end
		return r end },
	BrickColor = { new = function(n) return { Name = n, Color = Color3.new(1, 1, 1) } end },
	RaycastParams = { new = function() return {} end },
	PhysicalProperties = { new = function() return {} end },
}
M.globals.os = setmetatable({ clock = function() return Clock end, time = os.time, date = os.date }, { __index = os })
M.Services = Services
M.CoreGui = CoreGui
M.AllInstances = AllInstances
M.Queue = Queue

-- an executor's file functions, backed by a table
function M.InstallFiles(env)
	local files, folders = {}, {}
	M.Files = files
	env.writefile = function(p, d) files[p] = d end
	env.readfile = function(p) return files[p] or error("file not found: " .. p) end
	env.isfile = function(p) return files[p] ~= nil end
	env.isfolder = function(p) return folders[p] == true end
	env.makefolder = function(p) folders[p] = true end
	env.delfile = function(p) files[p] = nil end
	env.listfiles = function(dir)
		local out = {}
		for p in pairs(files) do if p:sub(1, #dir + 1) == dir .. "/" and not p:find("/", #dir + 2, true) then table.insert(out, p) end end
		return out
	end
end

return M
