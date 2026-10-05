--[[
	Vantage · tests/Mock/prelude.luau
	==================================================================
	A headless Roblox runtime.

	The bundle is normal Luau that expects `Instance`, `Color3`, `task`
	and friends to exist as globals. This prelude defines them, so the
	real library — not a stub of it — can be executed and asserted on
	without Studio.

	Three things make it more than a stub:

	· Property assignment is real. `GetPropertyChangedSignal` fires,
	  `AbsoluteSize`/`AbsolutePosition` are derived from `Size` against a
	  virtual viewport, and parenting is tracked. Components that measure
	  themselves therefore actually measure.
	· It has a deterministic scheduler. `task.delay` and `task.wait`
	  resolve through a virtual clock advanced by `Mock.advance(dt, step)`,
	  which also drives `Motion.step`. A 25-second loading screen can be
	  tested in milliseconds, in exactly reproducible order.
	· It records. Every construction, every warn, every signal connected
	  is counted so specs can assert on behaviour rather than on
	  snapshots.

	This file is concatenated *before* the bundle by tools/test.mjs, so
	its top-level assignments become the globals the library sees.
]]

--[[ Types ---------------------------------------------------------- ]]

local function class(name, fields)
	local mt = { __typename = name }
	mt.__index = mt
	mt.__tostring = function(self)
		local parts = {}
		for _, field in ipairs(fields or {}) do
			parts[#parts + 1] = tostring(field) .. "=" .. tostring(self[field])
		end
		return string.format("%s(%s)", name, table.concat(parts, ", "))
	end
	return mt
end

local Color3MT = class("Color3", { "R", "G", "B" })
Color3 = {}

function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3MT)
end

function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end

function Color3.fromHSV(h, s, v)
	if s == 0 then
		return Color3.new(v, v, v)
	end
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local index = i % 6
	if index == 0 then
		return Color3.new(v, t, p)
	elseif index == 1 then
		return Color3.new(q, v, p)
	elseif index == 2 then
		return Color3.new(p, v, t)
	elseif index == 3 then
		return Color3.new(p, q, v)
	elseif index == 4 then
		return Color3.new(t, p, v)
	end
	return Color3.new(v, p, q)
end

function Color3.toHSV(color)
	local r, g, b = color.R, color.G, color.B
	local max = math.max(r, g, b)
	local min = math.min(r, g, b)
	local delta = max - min
	local h = 0
	if delta > 0 then
		if max == r then
			h = ((g - b) / delta) % 6
		elseif max == g then
			h = (b - r) / delta + 2
		else
			h = (r - g) / delta + 4
		end
		h /= 6
	end
	local s = max == 0 and 0 or delta / max
	return h, s, max
end

function Color3.fromHex(hex)
	local cleaned = hex:gsub("#", "")
	local r = tonumber(cleaned:sub(1, 2), 16) or 0
	local g = tonumber(cleaned:sub(3, 4), 16) or 0
	local b = tonumber(cleaned:sub(5, 6), 16) or 0
	return Color3.fromRGB(r, g, b)
end

function Color3.Lerp(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local UDimMT = class("UDim", { "Scale", "Offset" })
UDim = {}
function UDim.new(scale, offset)
	return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UDimMT)
end

local UDim2MT = {
	__typename = "UDim2",
	__index = function(self, key)
		if key == "Width" then
			return self.X
		elseif key == "Height" then
			return self.Y
		end
		return UDim2MT[key]
	end,
	__tostring = function(self)
		return string.format("{%s, %s}, {%s, %s}", self.X.Scale, self.X.Offset, self.Y.Scale, self.Y.Offset)
	end,
}
UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
	return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UDim2MT)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x or 0, 0, y or 0)
end
function UDim2.fromScale(x, y)
	return UDim2.new(x or 0, 0, y or 0, 0)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x or 0, 0, y or 0)
end

local Vector2MT = class("Vector2", { "X", "Y" })
Vector2 = {}
function Vector2.new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, Vector2MT)
end
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)
function Vector2MT.__add(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end
function Vector2MT.__sub(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end
function Vector2MT.__mul(a, b)
	if type(b) == "number" then
		return Vector2.new(a.X * b, a.Y * b)
	end
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end
function Vector2MT.__eq(a, b)
	return a.X == b.X and a.Y == b.Y
end

local Vector3MT = class("Vector3", { "X", "Y", "Z" })
Vector3 = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3MT)
end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)

local RectMT = class("Rect", { "Min", "Max" })
Rect = {}
function Rect.new(minX, minY, maxX, maxY)
	return setmetatable({ Min = Vector2.new(minX, minY), Max = Vector2.new(maxX, maxY) }, RectMT)
end

local CFrameMT = class("CFrame", {})
CFrame = {}
function CFrame.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, CFrameMT)
end
CFrame.identity = CFrame.new(0, 0, 0)

--[[ Sequences ------------------------------------------------------ ]]

-- The rules below are the engine's own, measured on a live client instead of
-- assumed. Both sequences accept a scalar (or two), or an array of keypoints:
--
--   ColorSequence.new(color) / (colorA, colorB) / ({ keypoint, keypoint })
--   NumberSequence.new(value) / (valueA, valueB) / ({ keypoint, keypoint })
--
-- and the array form is strict: at least two entries, every entry a real
-- keypoint, times ordered, the first at exactly 0 and the last at exactly 1.
-- There is no (colors, times) overload -- parallel arrays throw
-- `expected 'ColorSequenceKeypoint' at index 1`, and that is the call the old,
-- lenient mock waved through while it killed every load method on the real
-- client. Extra arguments after the first table are ignored by the engine, and
-- are ignored here, so the mock stays honest in both directions.

local ColorSequenceKeypointMT = class("ColorSequenceKeypoint", { "Time", "Value" })
ColorSequenceKeypoint = {}
function ColorSequenceKeypoint.new(t, value)
	if type(t) ~= "number" then
		error("invalid argument #1 to 'new' (number expected)", 2)
	end
	if type(value) ~= "table" or getmetatable(value) ~= Color3MT then
		error("could not parse arg #2 to ColorSequenceKeypoint.new(), Color3 expected.", 2)
	end
	return setmetatable({ Time = t, Value = value }, ColorSequenceKeypointMT)
end

local NumberSequenceKeypointMT = class("NumberSequenceKeypoint", { "Time", "Value", "Envelope" })
NumberSequenceKeypoint = {}
function NumberSequenceKeypoint.new(t, value, envelope)
	if type(t) ~= "number" then
		error("invalid argument #1 to 'new' (number expected)", 2)
	end
	if type(value) ~= "number" then
		error("could not parse arg #2 to NumberSequenceKeypoint.new(), number expected.", 2)
	end
	return setmetatable({ Time = t, Value = value, Envelope = envelope or 0 }, NumberSequenceKeypointMT)
end

--- Validates a keypoint array the way the engine does, and returns a copy.
local function keypointArray(value, keypointMT, keypointName, sequenceName)
	if type(value) ~= "table" then
		error("table expected.", 2)
	end
	local points = {}
	for index, keypoint in ipairs(value) do
		if type(keypoint) ~= "table" or getmetatable(keypoint) ~= keypointMT then
			error(string.format("%s.new(): expected '%s' at index %d.", sequenceName, keypointName, index), 2)
		end
		points[index] = keypoint
	end
	if #points < 2 then
		error(string.format("%s.new(): requires at least 2 keypoints", sequenceName), 2)
	end
	for index = 2, #points do
		if points[index].Time < points[index - 1].Time then
			error(string.format("%s.new(): all keypoints must be ordered by time", sequenceName), 2)
		end
	end
	if points[1].Time ~= 0 then
		error(string.format("%s must start at time=0.0", sequenceName), 2)
	end
	if points[#points].Time ~= 1 then
		error(string.format("%s must end at time=1.0", sequenceName), 2)
	end
	return points
end

local ColorSequenceMT = class("ColorSequence", { "Keypoints" })
ColorSequence = {}
function ColorSequence.new(a, b)
	if type(a) == "table" and getmetatable(a) == Color3MT then
		local second = b ~= nil and getmetatable(b) == Color3MT and b or a
		return setmetatable({
			Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, second) },
		}, ColorSequenceMT)
	end
	return setmetatable(
		{ Keypoints = keypointArray(a, ColorSequenceKeypointMT, "ColorSequenceKeypoint", "ColorSequence") },
		ColorSequenceMT
	)
end

local NumberSequenceMT = class("NumberSequence", { "Keypoints" })
NumberSequence = {}
function NumberSequence.new(a, b)
	if type(a) == "number" then
		local second = type(b) == "number" and b or a
		return setmetatable({
			Keypoints = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, second) },
		}, NumberSequenceMT)
	end
	return setmetatable(
		{ Keypoints = keypointArray(a, NumberSequenceKeypointMT, "NumberSequenceKeypoint", "NumberSequence") },
		NumberSequenceMT
	)
end

--[[ Enums ---------------------------------------------------------- ]]

local enumItemCache = {}

-- Roblox really does define an item called `Name` (Enum.SortOrder.Name),
-- which would otherwise clobber the enum's own name string. The enum name
-- therefore lives on `_name`, and every read of it goes through
-- `enumTypeName` so a clobbered `Name` can never reach a comparison or a
-- concatenation.
local function enumTypeName(enumType)
	if type(enumType) ~= "table" then
		return "Unknown"
	end
	local name = rawget(enumType, "_name")
	if type(name) ~= "string" then
		name = rawget(enumType, "Name")
	end
	return type(name) == "string" and name or "Unknown"
end

local EnumItemType = {
	__typename = "EnumItem",
	__tostring = function(self)
		return "Enum." .. enumTypeName(rawget(self, "EnumType")) .. "." .. tostring(rawget(self, "Name"))
	end,
}

function EnumItemType.__eq(a, b)
	-- Identity first: comparing an item with itself must never walk into the
	-- metatable chain, which is what an enum full of self-similar items
	-- (SortOrder.Name) would otherwise do.
	if rawequal(a, b) then
		return true
	end
	return enumTypeName(rawget(a, "EnumType")) == enumTypeName(rawget(b, "EnumType"))
		and rawget(a, "Name") == rawget(b, "Name")
end

local EnumType = {}
EnumType.__index = function(self, key)
	local enumName = enumTypeName(self)
	local item = enumItemCache[enumName .. "." .. key]
	if not item then
		item = setmetatable({
			Name = key,
			Value = #enumItemCache,
			EnumType = self,
		}, EnumItemType)
		enumItemCache[enumName .. "." .. key] = item
	end
	return item
end

local EnumItemsMT = {
	__index = function(self, key)
		return getmetatable(self)._enum[key]
	end,
	__len = function(self)
		local count = 0
		for _ in pairs(getmetatable(self)._enum) do
			count += 1
		end
		return count
	end,
}
local EnumItemsType = {
	__newindex = function(self, key, value)
		rawset(self, key, value)
	end,
}

Enum = setmetatable({}, {
	__index = function(self, name)
		local existing = rawget(self, name)
		if existing then
			return existing
		end
		local enum = setmetatable({}, EnumType)
		enum._name = name
		enum.Name = name
		rawset(self, name, enum)
		return enum
	end,
})

-- Pre-register the enum members the library actually references, so
-- values are stable and comparable.
local function makeItem(enumName, itemName)
	local enum = Enum[enumName]
	local item = setmetatable({
		Name = itemName,
		Value = 0,
		EnumType = enum,
	}, EnumItemType)
	-- `rawset` because the item named "Name" shadows the enum's own `Name`
	-- field, exactly as it does on Roblox; `_name` keeps the type name safe.
	rawset(enum, itemName, item)
	return item
end

for _, spec in ipairs({
	{ "KeyCode", "RightShift LeftControl LeftShift LeftAlt RightControl RightShift RightAlt Escape Return KeypadEnter Backspace Tab Up Down Left Right Home End PageUp PageDown K Unknown" },
	{ "UserInputType", "MouseButton1 MouseButton2 MouseButton3 MouseMovement MouseWheel Touch Keyboard Gamepad1 Focus None" },
	{ "Font", "Gotham GothamMedium GothamBold GothamBlack RobotoMono SourceSans SourceSansBold Arial ArialBold Code Fantasy Legacy SciFi" },
	{ "AutomaticSize", "None X Y XY" },
	{ "TextXAlignment", "Left Center Right" },
	{ "TextYAlignment", "Top Center Bottom" },
	{ "TextTruncate", "None AtEnd" },
	{ "FillDirection", "Horizontal Vertical" },
	{ "SortOrder", "LayoutOrder Name" },
	{ "HorizontalAlignment", "Left Center Right" },
	{ "VerticalAlignment", "Top Center Bottom" },
	{ "ApplyStrokeMode", "Border Contextual" },
	{ "LineJoinMode", "Round Miter Bevel" },
	{ "ScaleType", "Stretch Slice Tile Fit Crop" },
	{ "ZIndexBehavior", "Global Sibling" },
	{ "ScrollingDirection", "X Y XY" },
	{ "ElasticBehavior", "Never WhenScrollable Always" },
	{ "AssetFetchStatus", "None Success Loading Failed TimedOut" },
	{ "UIFlexMode", "None Grow Shrink Fill Custom" },
	{ "HumanoidRigType", "R6 R15" },
	{ "RunContext", "Legacy Client Server Plugin" },
	{ "StudioStyleGuideColor", "MainText" },
}) do
	for item in spec[2]:gmatch("%S+") do
		makeItem(spec[1], item)
	end
end

--[[ Font ------------------------------------------------------------ ]]

Font = {}
function Font.new(family, weight, style)
	return { Family = family, Weight = weight, Style = style, __fontFace = true }
end
function Font.fromEnum(enum)
	return { Enum = enum, Weight = enum and enum.Name or "Regular", __fontFace = true }
end
function Font.fromName(name)
	return { Family = name, __fontFace = true }
end

--[[ Signals -------------------------------------------------------- ]]

local ConnectionMT = {
	__typename = "RBXScriptConnection",
	__index = {
		Disconnect = function(self)
			if not self._connected then
				return
			end
			self._connected = false
			local list = self._list
			local index = table.find(list, self)
			if index then
				table.remove(list, index)
			end
		end,
		disconnect = function(self)
			self:Disconnect()
		end,
	},
}

local SignalMT = {
	__index = {
		Connect = function(self, callback)
			local connection = setmetatable({
				_connected = true,
				_list = self._handlers,
				_callback = callback,
				Connected = true,
			}, ConnectionMT)
			table.insert(self._handlers, connection)
			return connection
		end,
		connect = function(self, callback)
			return self:Connect(callback)
		end,
		Once = function(self, callback)
			local connection
			connection = self:Connect(function(...)
				connection:Disconnect()
				callback(...)
			end)
			return connection
		end,
		Wait = function(self)
			return nil
		end,
		Fire = function(self, ...)
			for _, connection in ipairs(table.clone(self._handlers)) do
				if connection._connected then
					connection._callback(...)
				end
			end
		end,
	},
}

local function newSignal(name)
	return setmetatable({ Name = name, _handlers = {} }, SignalMT)
end

--[[ Scheduler ------------------------------------------------------- ]]

local virtualTime = 0
local pending = {} -- { at = number, co = thread, label = string }
local scheduled = 0

task = {}

local function resumeThread(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		warn("[mock] task error: " .. tostring(err))
	end
end

local function enqueue(co, at, label)
	table.insert(pending, { at = at, co = co, label = label })
	scheduled += 1
	table.sort(pending, function(a, b)
		return a.at < b.at
	end)
end

function task.spawn(fnOrThread, ...)
	local co
	if type(fnOrThread) == "thread" then
		co = fnOrThread
	else
		co = coroutine.create(fnOrThread)
	end
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		warn("[mock] task.spawn error: " .. tostring(err))
	end
	return co
end

function task.defer(fn, ...)
	return task.spawn(fn, ...)
end

function task.delay(seconds, fn, ...)
	-- Captured up-front: the inner closure is not a vararg function, so
	-- it cannot forward `...` itself.
	local args = table.pack(...)
	local co = coroutine.create(function()
		if seconds > 0 then
			coroutine.yield(seconds)
		end
		fn(table.unpack(args, 1, args.n))
	end)
	local ok = coroutine.resume(co)
	if not ok then
		warn("[mock] task.delay startup error")
	end
	enqueue(co, virtualTime + (seconds or 0), "delay")
	return co
end

--- Yields for `seconds` and is resumed by `Mock.advance` on the virtual
--- clock, exactly as the real scheduler would. A yield that is never
--- enqueued is a coroutine that never runs again, which is how a loading
--- screen's progress loop silently stalls in a naive mock.
function task.wait(seconds)
	if not coroutine.isyieldable() then
		return seconds or 0
	end
	local requested = seconds or 0
	enqueue(coroutine.running(), virtualTime + requested, "wait")
	local elapsed = coroutine.yield()
	return elapsed or requested
end

function task.cancel(thread)
	for index, entry in ipairs(pending) do
		if entry.co == thread then
			table.remove(pending, index)
			return
		end
	end
end

--- Advances the virtual clock, running due tasks in timestamp order
--- and stepping the animation engine on the same timeline.
Mock = {}

Mock.viewport = Vector2.new(1440, 900)
Mock.logs = {}
Mock.instancesCreated = 0
Mock.instancesDestroyed = 0
Mock.warnings = {}

Mock.clock = function()
	return virtualTime
end

function Mock.advance(seconds, step)
	step = step or (1 / 60)
	local remaining = seconds
	while remaining > 0 do
		local delta = math.min(step, remaining)
		virtualTime += delta
		remaining -= delta

		-- Run everything that came due inside this step.
		local guard = 0
		while #pending > 0 and pending[1].at <= virtualTime and guard < 200 do
			guard += 1
			local entry = table.remove(pending, 1)
			if coroutine.status(entry.co) == "suspended" then
				local ok, err = coroutine.resume(entry.co, delta)
				if not ok then
					warn("[mock] queued task error: " .. tostring(err))
				end
			end
		end

		if Mock.motion then
			Mock.motion.step(delta)
		end
	end
	return virtualTime
end

--- Runs pending tasks until `predicate` returns true or time runs out.
function Mock.waitUntil(predicate, timeout, step)
	timeout = timeout or 5
	local waited = 0
	while waited < timeout do
		if predicate() then
			return true, waited
		end
		Mock.advance(step or (1 / 60))
		waited += (step or (1 / 60))
	end
	return false, waited
end

--[[ `script` ------------------------------------------------------ ]]

-- The bundle rewrites every `require(script.Parent.X)` into a registry
-- lookup, but it keeps the `local Core = script.Core` aliases intact.
-- Those only need to be indexable, so `script` is a self-referential
-- proxy that yields another proxy for any child name.

local scriptMT = {
	__typename = "Instance",
	__index = function(self, key)
		if key == "Parent" then
			return nil
		end
		return setmetatable({ Name = tostring(key) }, scriptMT)
	end,
}

script = setmetatable({ Name = "Vantage" }, scriptMT)

--[[ Instances ------------------------------------------------------- ]]

local CLASS_INHERITANCE = {
	Frame = { "GuiObject", "GuiBase2d", "Instance" },
	TextLabel = { "GuiObject", "GuiBase2d", "Instance" },
	TextButton = { "GuiObject", "GuiBase2d", "Instance" },
	TextBox = { "GuiObject", "GuiBase2d", "Instance" },
	ImageLabel = { "GuiObject", "GuiBase2d", "Instance" },
	ImageButton = { "GuiObject", "GuiBase2d", "Instance" },
	ScrollingFrame = { "GuiObject", "GuiBase2d", "Instance" },
	ScreenGui = { "LayerCollector", "Instance" },
	UICorner = { "UIComponent", "Instance" },
	UIStroke = { "UIComponent", "Instance" },
	UIGradient = { "UIComponent", "Instance" },
	UIPadding = { "UIComponent", "Instance" },
	UIListLayout = { "UILayout", "Instance" },
	UIGridLayout = { "UILayout", "Instance" },
	UIScale = { "UIComponent", "Instance" },
	UISizeConstraint = { "UIComponent", "Instance" },
	UITextSizeConstraint = { "UIComponent", "Instance" },
	Sound = { "Instance" },
	Folder = { "Instance" },
}

local GUI_CLASSES = {
	Frame = true, TextLabel = true, TextButton = true, TextBox = true,
	ImageLabel = true, ImageButton = true, ScrollingFrame = true,
}

local DEFAULTS = {
	Frame = {
		BackgroundColor3 = Color3.new(0.62, 0.62, 0.62), BackgroundTransparency = 0,
		Size = UDim2.fromOffset(100, 100), Position = UDim2.fromOffset(0, 0),
		AnchorPoint = Vector2.new(0, 0), BorderSizePixel = 1, Visible = true,
		ZIndex = 1, ClipsDescendants = false, Rotation = 0, LayoutOrder = 0,
		AutomaticSize = Enum.AutomaticSize.None, Active = false, Selectable = false,
		GroupTransparency = 0, BackgroundColor = Color3.new(1, 1, 1),
	},
	TextLabel = {
		Text = "", TextSize = 14, TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 0, TextStrokeTransparency = 1, RichText = false,
		TextWrapped = false, TextScaled = false, TextTruncate = Enum.TextTruncate.None,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
		LineHeight = 1, Font = Enum.Font.Gotham, BackgroundTransparency = 1,
		Visible = true, ZIndex = 1, TextEditable = false,
	},
	TextButton = { Text = "", AutoButtonColor = true, Active = true, Visible = true, ZIndex = 1, Modal = false, Selectable = true },
	TextBox = {
		Text = "", PlaceholderText = "", PlaceholderColor3 = Color3.new(0.5, 0.5, 0.5),
		TextEditable = true, ClearTextOnFocus = true, MultiLine = false,
		CursorPosition = 1, SelectionStart = -1, Visible = true, ZIndex = 1, TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
		Font = Enum.Font.Gotham,
	},
	ImageLabel = {
		Image = "", ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 0,
		ScaleType = Enum.ScaleType.Stretch, BackgroundTransparency = 1,
		Visible = true, ZIndex = 1, ResampleMode = nil,
	},
	ImageButton = { Image = "", ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 0, Visible = true, ZIndex = 1 },
	ScrollingFrame = {
		CanvasSize = UDim2.fromOffset(0, 0), CanvasPosition = Vector2.new(0, 0),
		ScrollBarThickness = 12, ScrollBarImageColor3 = Color3.new(1, 1, 1),
		ScrollBarImageTransparency = 0, AutomaticCanvasSize = Enum.AutomaticSize.None,
		ScrollingDirection = Enum.ScrollingDirection.XY, ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ScrollingEnabled = true, BackgroundTransparency = 0, Visible = true, ZIndex = 1,
		Size = UDim2.fromOffset(100, 100), Position = UDim2.fromOffset(0, 0),
	},
	ScreenGui = { Enabled = true, DisplayOrder = 0, IgnoreGuiInset = false, ResetOnSpawn = true, Visible = true },
	-- The one class with GroupTransparency. A Frame does not have the
	-- property, and the mock setter below enforces that, because a fade that
	-- silently writes it to a Frame is invisible here and fatal on the client.
	CanvasGroup = {
		GroupTransparency = 0, BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(100, 100), Position = UDim2.fromOffset(0, 0),
		AnchorPoint = Vector2.new(0, 0), Visible = true, ZIndex = 1,
		ClipsDescendants = false, AutomaticSize = Enum.AutomaticSize.None,
	},
	UICorner = { CornerRadius = UDim.new(0, 0) },
	UIStroke = { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round },
	UIGradient = { Enabled = true, Rotation = 0, Offset = Vector2.new(0, 0) },
	UIPadding = { PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 0), PaddingLeft = UDim.new(0, 0), PaddingRight = UDim.new(0, 0) },
	UIListLayout = { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0), HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top, Wraps = false },
	UIGridLayout = {},
	UIScale = { Scale = 1 },
	UISizeConstraint = { MaxSize = Vector2.new(math.huge, math.huge), MinSize = Vector2.new(0, 0) },
	Sound = { SoundId = "", Volume = 0.5, Playing = false, Looped = false },
	Folder = {},
}

local InstanceMethods = {}

local instanceMT = {}

instanceMT.__index = function(self, key)
	local props = rawget(self, "_props")
	if props and props[key] ~= nil then
		return props[key]
	end

	if key == "AbsoluteSize" then
		local size = props.Size or UDim2.fromOffset(100, 100)
		local parent = props.Parent
		local parentSize = Mock.viewport
		if parent and rawget(parent, "_props") and type(parent.AbsoluteSize) == "table" then
			local candidates = parent.AbsoluteSize
			if type(candidates) == "table" then
				parentSize = candidates
			end
		end
		local scale = rawget(self, "_absorbed")
		return Vector2.new(
			math.max(0, size.X.Scale * parentSize.X + size.X.Offset),
			math.max(0, size.Y.Scale * parentSize.Y + size.Y.Offset)
		)
	end

	if key == "AbsolutePosition" then
		local position = props.Position or UDim2.fromOffset(0, 0)
		local parent = props.Parent
		local origin = Vector2.new(0, 0)
		if parent and rawget(parent, "_props") then
			local parentPosition = type(parent.AbsolutePosition) == "table" and parent.AbsolutePosition or nil
			if parentPosition then
				origin = parentPosition
			end
		end
		return Vector2.new(origin.X + position.X.Offset, origin.Y + position.Y.Offset)
	end

	if key == "AbsoluteRotation" then
		return props.Rotation or 0
	end

	if key == "ClassName" then
		return rawget(self, "_className")
	end

	local method = InstanceMethods[key]
	if method then
		return method
	end

	-- Signals are created lazily and remembered.
	local signalNames = {
		"Destroying", "Changed", "AncestryChanged", "ChildAdded", "ChildRemoved",
		"InputBegan", "InputEnded", "InputChanged", "Activated", "MouseEnter",
		"MouseLeave", "MouseMoved", "MouseButton1Click", "MouseButton1Down",
		"MouseButton1Up", "MouseButton2Click", "Focused", "FocusLost",
		"SelectionGained", "SelectionLost", "TouchTap", "TouchLongPress",
	}
	for _, name in ipairs(signalNames) do
		if name == key then
			local signal = newSignal(self._className .. "." .. key)
			rawset(self, "_signals_" .. key, signal)
			return signal
		end
	end

	if key == "GetPropertyChangedSignal" then
		return function(this, property)
			local signals = rawget(this, "_propertySignals")
			if not signals then
				signals = {}
				rawset(this, "_propertySignals", signals)
			end
			if not signals[property] then
				signals[property] = newSignal("PropertyChanged:" .. property)
			end
			return signals[property]
		end
	end

	return nil
end

instanceMT.__newindex = function(self, key, value)
	local props = rawget(self, "_props")
	if key == "Parent" then
		local previous = props.Parent
		if previous and rawget(previous, "_children") then
			local index = table.find(previous._children, self)
			if index then
				table.remove(previous._children, index)
			end
			local removed = previous.ChildRemoved
			if removed then
				removed:Fire(self)
			end
		end
		props.Parent = value
		if value and rawget(value, "_children") then
			table.insert(value._children, self)
			local added = value.ChildAdded
			if added then
				added:Fire(self)
			end
		end
		local ancestry = rawget(self, "_signals_AncestryChanged")
		if ancestry then
			ancestry:Fire(self, value)
		end
		return
	end

	-- Enum-typed properties are checked the way the engine checks them: the
	-- value has to be an EnumItem of the enum the class declares, or the write
	-- throws `Unable to assign property Font. Invalid value "display" for enum
	-- Font`. This is where a lenient mock does its worst damage — the spec's
	-- font-stack key reached a real screen build and killed it, while every
	-- offline test stayed green. The rule is derived from the class defaults
	-- above, so it applies to every enum property the same way.
	-- GroupTransparency only exists on CanvasGroup. Assigning it to a Frame
	-- throws `GroupTransparency is not a valid member of Frame` on the live
	-- client — inside the loading screen's worker, where it took the fade with
	-- it — and the old setter accepted the write for any class.
	if key == "GroupTransparency" and rawget(self, "_className") ~= "CanvasGroup" then
		error(
			string.format("GroupTransparency is not a valid member of %s", tostring(rawget(self, "_className"))),
			2
		)
	end

	local declared = DEFAULTS[rawget(self, "_className")]
	local expected = declared and declared[key]

	-- String-typed properties (Text, Image, Name …) take a string and nothing
	-- else — not an enum, and not nil. The engine throws
	-- `Unable to assign property Text. string expected, got EnumItem` (a
	-- binding whose key reached a label) and `... got nil` (a command row
	-- whose documented field was read by the wrong name). Both are invisible
	-- on a permissive mock and fatal on a live client.
	if type(expected) == "string" and type(value) ~= "string" then
		error(
			string.format("Unable to assign property %s. string expected, got %s", key, typeof(value)),
			2
		)
	end

	if value ~= nil then
		if typeof(expected) == "EnumItem" then
			local matches = false
			if typeof(value) == "EnumItem" then
				matches = enumTypeName(rawget(value, "EnumType")) == enumTypeName(rawget(expected, "EnumType"))
			end
			if not matches then
				error(
					string.format(
						"Unable to assign property %s. Invalid value %q for enum %s",
						key,
						tostring(value),
						enumTypeName(rawget(expected, "EnumType"))
					),
					2
				)
			end
		end
	end

	local previous = props[key]
	props[key] = value
	if previous ~= value then
		local signals = rawget(self, "_propertySignals")
		if signals and signals[key] then
			signals[key]:Fire()
		end
		local changed = rawget(self, "_signals_Changed")
		if changed then
			changed:Fire(key)
		end
	end
end

instanceMT.__tostring = function(self)
	return string.format("%s(%s)", rawget(self, "_className"), rawget(self, "_props").Name)
end

InstanceMethods.Destroy = function(self)
	if rawget(self, "_destroyed") then
		return
	end
	local destroying = rawget(self, "_signals_Destroying")
	if destroying then
		destroying:Fire()
	end
	rawset(self, "_destroyed", true)
	Mock.instancesDestroyed += 1

	local children = rawget(self, "_children")
	if children then
		for _, child in ipairs(table.clone(children)) do
			child:Destroy()
		end
		table.clear(children)
	end

	local parent = rawget(self, "_props").Parent
	if parent and rawget(parent, "_children") then
		local index = table.find(parent._children, self)
		if index then
			table.remove(parent._children, index)
		end
	end
	rawget(self, "_props").Parent = nil
	rawset(self, "_destroyed", true)
end

InstanceMethods.FindFirstChild = function(self, name)
	for _, child in ipairs(rawget(self, "_children")) do
		if rawget(child, "_props").Name == name then
			return child
		end
	end
	return nil
end

InstanceMethods.FindFirstChildOfClass = function(self, className)
	for _, child in ipairs(rawget(self, "_children")) do
		if rawget(child, "_className") == className then
			return child
		end
	end
	return nil
end

InstanceMethods.FindFirstChildWhichIsA = function(self, className)
	for _, child in ipairs(rawget(self, "_children")) do
		if child:IsA(className) then
			return child
		end
	end
	return nil
end

InstanceMethods.WaitForChild = function(self, name)
	return self:FindFirstChild(name)
end

InstanceMethods.GetChildren = function(self)
	return table.clone(rawget(self, "_children"))
end

InstanceMethods.GetDescendants = function(self)
	local out = {}
	local function walk(node)
		for _, child in ipairs(rawget(node, "_children")) do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end

InstanceMethods.IsA = function(self, className)
	local own = rawget(self, "_className")
	if own == className then
		return true
	end
	for _, candidate in ipairs(CLASS_INHERITANCE[own] or {}) do
		if candidate == className then
			return true
		end
	end
	return false
end

InstanceMethods.IsDescendantOf = function(self, ancestor)
	local current = self
	while current do
		if current == ancestor then
			return true
		end
		current = rawget(current, "_props").Parent
	end
	return false
end

InstanceMethods.SetAttribute = function(self, name, value)
	local attributes = rawget(self, "_attributes")
	if not attributes then
		attributes = {}
		rawset(self, "_attributes", attributes)
	end
	attributes[name] = value
end

InstanceMethods.GetAttribute = function(self, name)
	local attributes = rawget(self, "_attributes")
	return attributes and attributes[name] or nil
end

InstanceMethods.Clone = function(self)
	return Instance.new(rawget(self, "_className"))
end

InstanceMethods.GetFullName = function(self)
	local parts = {}
	local current = self
	while current do
		table.insert(parts, 1, rawget(current, "_props").Name)
		current = rawget(current, "_props").Parent
	end
	return table.concat(parts, ".")
end

InstanceMethods.TweenSize = function() end
InstanceMethods.TweenPosition = function() end

-- GUI-only methods
local GuiMethods = {
	CaptureFocus = function(self)
		local focused = rawget(self, "_signals_Focused")
		if focused then
			focused:Fire(true)
		end
		rawset(self, "_focused", true)
	end,
	ReleaseFocus = function(self, enterPressed)
		local lost = rawget(self, "_signals_FocusLost")
		rawset(self, "_focused", false)
		if lost then
			lost:Fire(enterPressed or false)
		end
	end,
	IsFocused = function(self)
		return rawget(self, "_focused") == true
	end,
	GetMouse = function(self)
		return Vector2.new(10, 10)
	end,
}

for name, method in pairs(GuiMethods) do
	InstanceMethods[name] = method
end

Instance = {}

function Instance.new(className, parent)
	local className2 = className or "Frame"
	local props = {}
	for key, value in pairs(DEFAULTS[className2] or {}) do
		props[key] = value
	end
	props.Name = className2

	local instance = setmetatable({
		_props = props,
		_children = {},
		_className = className2,
		_signalCache = nil,
	}, instanceMT)

	Mock.instancesCreated += 1

	-- Instances start with a name equal to their class, and the mock
	-- mirrors the real default for `Name`.
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Instance.fromExisting(existing)
	return existing
end

--[[ typeof ---------------------------------------------------------- ]]

local realType = type

function typeof(value)
	local valueType = realType(value)
	if valueType == "table" then
		local mt = getmetatable(value)
		if mt == instanceMT then
			return "Instance"
		end
		if mt == ConnectionMT then
			return "RBXScriptConnection"
		end
		if mt == SignalMT then
			return "RBXScriptSignal"
		end
		if mt and mt.__typename then
			return mt.__typename
		end
		return "table"
	end
	return valueType
end

function warn(...)
	local parts = {}
	for index = 1, select("#", ...) do
		parts[#parts + 1] = tostring((select(index, ...)))
	end
	local message = table.concat(parts, " ")
	table.insert(Mock.warnings, message)
	print("[warn] " .. message)
end

--[[ Services -------------------------------------------------------- ]]

local function makeService(name, methods)
	local service = {
		Name = name,
		_className = name,
		_props = { Name = name },
		_children = {},
	}
	for key, value in pairs(methods or {}) do
		service[key] = value
	end
	return service
end

local renderStepped = newSignal("RunService.RenderStepped")
local heartbeat = newSignal("RunService.Heartbeat")
local stepped = newSignal("RunService.Stepped")
local inputBegan = newSignal("UserInputService.InputBegan")
local inputChanged = newSignal("UserInputService.InputChanged")
local inputEnded = newSignal("UserInputService.InputEnded")
local touchMoved = newSignal("UserInputService.TouchMoved")
local touchEnded = newSignal("UserInputService.TouchEnded")

local RunService = makeService("RunService", {
	RenderStepped = renderStepped,
	Heartbeat = heartbeat,
	Stepped = stepped,
	PreRender = newSignal("RunService.PreRender"),
	PreSimulation = newSignal("RunService.PreSimulation"),
	PostSimulation = newSignal("RunService.PostSimulation"),
	IsClient = function()
		return true
	end,
	IsServer = function()
		return false
	end,
	IsStudio = function()
		return false
	end,
})

local UserInputService = makeService("UserInputService", {
	InputBegan = inputBegan,
	InputChanged = inputChanged,
	InputEnded = inputEnded,
	TouchMoved = touchMoved,
	TouchEnded = touchEnded,
	TouchStarted = newSignal("UserInputService.TouchStarted"),
	TouchEnabled = false,
	KeyboardEnabled = true,
	MouseEnabled = true,
	GamepadEnabled = false,
	VREnabled = false,
	ReducedMotionEnabled = false,
	GetMouseLocation = function()
		return Vector2.new(720, 450)
	end,
	GetFocusedTextBox = function()
		return nil
	end,
	IsKeyDown = function()
		return false
	end,
	GetKeysPressed = function()
		return {}
	end,
})

local ContentProvider = makeService("ContentProvider", {
	PreloadAsync = function(_, assets, callback)
		-- Records what was requested and reports success per asset so the
		-- loading screen's real progress path is exercised.
		Mock.preloaded = Mock.preloaded or {}
		for _, asset in ipairs(assets or {}) do
			table.insert(Mock.preloaded, asset)
			if callback then
				callback(asset, Enum.AssetFetchStatus.Success)
			end
		end
	end,
	RequestQueueSize = 0,
})

local playerGui = Instance.new("Folder")
playerGui.Name = "PlayerGui"
playerGui._className = "PlayerGui"
playerGui._props.Name = "PlayerGui"

local players = makeService("Players", {
	LocalPlayer = {
		Name = "MockPlayer",
		UserId = 1,
		DisplayName = "Mock",
		FindFirstChildOfClass = function(_, className)
			if className == "PlayerGui" then
				return playerGui
			end
			return nil
		end,
		WaitForChild = function(_, name)
			return playerGui
		end,
	},
	GetPlayers = function()
		return {}
	end,
})

local collectionTags = {}

local CollectionService = makeService("CollectionService", {
	AddTag = function(_, instance, tag)
		collectionTags[tag] = collectionTags[tag] or {}
		if not table.find(collectionTags[tag], instance) then
			table.insert(collectionTags[tag], instance)
		end
	end,
	RemoveTag = function(_, instance, tag)
		local list = collectionTags[tag]
		if list then
			local index = table.find(list, instance)
			if index then
				table.remove(list, index)
			end
		end
	end,
	HasTag = function(_, instance, tag)
		local list = collectionTags[tag]
		return list ~= nil and table.find(list, instance) ~= nil
	end,
	GetTagged = function(_, tag)
		return table.clone(collectionTags[tag] or {})
	end,
})

local soundService = makeService("SoundService", {
	PlayLocalSound = function() end,
})

local guiService = makeService("GuiService", {
	GetGuiInset = function()
		return Vector2.new(0, 36), Vector2.new(0, 0)
	end,
	TopbarInset = { Top = 36, Bottom = 0, Left = 0, Right = 0 },
	SelectedCoreObject = nil,
})

local textService = makeService("TextService", {
	GetTextSize = function(_, text, size)
		return Vector2.new(#text * size * 0.55, size * 1.25)
	end,
})

local tweenService = makeService("TweenService", {
	Create = function()
		return { Play = function() end, Cancel = function() end, Completed = newSignal("Tween.Completed") }
	end,
})

local teleportService = makeService("TeleportService", {})
local starterGui = makeService("StarterGui", {
	SetCoreGuiEnabled = function() end,
	CoreGuiEnabled = function()
		return true
	end,
})
local httpService = makeService("HttpService", {
	GenerateGUID = function()
		return "00000000-0000-0000-0000-000000000000"
	end,
	JSONEncode = function()
		return "{}"
	end,
})
local replicatedStorage = makeService("ReplicatedStorage", {})
local coreGui = makeService("CoreGui", {})
local logService = makeService("LogService", {
	MessageOut = newSignal("LogService.MessageOut"),
})

local services = {
	RunService = RunService,
	UserInputService = UserInputService,
	ContentProvider = ContentProvider,
	Players = players,
	CollectionService = CollectionService,
	SoundService = soundService,
	GuiService = guiService,
	TextService = textService,
	TweenService = tweenService,
	TeleportService = teleportService,
	StarterGui = starterGui,
	HttpService = httpService,
	ReplicatedStorage = replicatedStorage,
	CoreGui = coreGui,
	LogService = logService,
}

local camera = {
	_className = "Camera",
	_props = { Name = "Camera" },
	_children = {},
	ViewportSize = Vector2.new(1440, 900),
	FieldOfView = 70,
}
setmetatable(camera, instanceMT)

workspace = {
	_className = "Workspace",
	_props = { Name = "Workspace" },
	_children = {},
	CurrentCamera = camera,
	Gravity = 196.2,
}
setmetatable(workspace, instanceMT)

game = {
	_className = "DataModel",
	_props = { Name = "game" },
	_children = {},
	GetService = function(_, name)
		if services[name] then
			return services[name]
		end
		local service = makeService(name, {})
		services[name] = service
		return service
	end,
	FindService = function(self, name)
		return self:GetService(name)
	end,
	IsLoaded = function()
		return true
	end,
	GetFullName = function()
		return "game"
	end,
	PlaceId = 0,
	JobId = "mock",
	Workspace = workspace,
}

setmetatable(game, instanceMT)

Mock.services = services
Mock.playerGui = playerGui
Mock.camera = camera
Mock.collectionTags = collectionTags
Mock.inputBegan = inputBegan
Mock.inputChanged = inputChanged
Mock.inputEnded = inputEnded
Mock.touchMoved = touchMoved
Mock.touchEnded = touchEnded
Mock.renderStepped = renderStepped

--- Fires a synthetic input, the way a real client would.
Mock.press = function(instance, userInputType, position)
	local input = {
		UserInputType = userInputType or Enum.UserInputType.MouseButton1,
		KeyCode = Enum.KeyCode.Unknown,
		Position = position or Vector3.new(100, 100, 0),
		IsModifierKeyDown = function()
			return false
		end,
	}
	local began = rawget(instance, "_signals_InputBegan")
	if began then
		began:Fire(input, false)
	end
	local ended = rawget(instance, "_signals_InputEnded")
	if ended then
		ended:Fire(input, false)
	end
	local activated = rawget(instance, "_signals_Activated")
	if activated then
		activated:Fire()
	end
	return input
end

Mock.fire = function(instance, signalName, ...)
	local signal = rawget(instance, "_signals_" .. signalName)
	if signal then
		signal:Fire(...)
	end
end

Mock.fireProperty = function(instance, property)
	local signals = rawget(instance, "_propertySignals")
	if signals and signals[property] then
		signals[property]:Fire()
	end
end

--- Counts every descendant matching a class, for structural assertions.
Mock.count = function(root, className)
	local total = 0
	for _, descendant in ipairs(root:GetDescendants()) do
		if not className or descendant:IsA(className) then
			total += 1
		end
	end
	return total
end

Mock.reset = function()
	Mock.warnings = {}
	Mock.preloaded = {}
	Mock.instancesCreated = 0
	Mock.instancesDestroyed = 0
end

print(string.format(
	"[mock] runtime ready · viewport %dx%d · %d services",
	Mock.viewport.X, Mock.viewport.Y, (function()
		local count = 0
		for _ in pairs(services) do
			count += 1
		end
		return count
	end)()
))
