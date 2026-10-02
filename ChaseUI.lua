--[[
	ChaseUI  |  v1.0.0
	An original, lightweight, executor-ready UI library for Roblox.

	Author : built for private / owned Roblox testing
	Design : black by default, fully re-themeable at runtime
	Loader : loadstring(game:HttpGet("<raw-url>/ChaseUI.lua"))()

	Features:
		- Window / Tabs / Sections
		- Button, Toggle, Slider, Dropdown (single + multi),
		  Input, Keybind, ColorPicker, Label, Paragraph, Divider
		- Toast notifications
		- Optional key system
		- Config save / load (flags) via writefile/readfile
		- Mobile + touch support (drag + floating toggle)
		- Smooth tween animations, hover states, full cleanup

	This file is a standalone client-side module. It returns the
	ChaseUI table so it can be used directly or via loadstring.
--]]

local ChaseUI = {}
ChaseUI.__index = ChaseUI
ChaseUI.Version = "1.0.0"

-- // ============================ Services ============================ //
-- cloneref keeps references safe on executors that sandbox the datamodel.
local cloneref = cloneref or function(o) return o end
local gethui = gethui

local function getService(name)
	return cloneref(game:GetService(name))
end

local Players            = getService("Players")
local UserInputService   = getService("UserInputService")
local RunService         = getService("RunService")
local TweenService       = getService("TweenService")
local HttpService        = getService("HttpService")
local CoreGui            = getService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- // ===================== Executor compatibility ===================== //
-- All optional globals are resolved safely so the library degrades
-- gracefully on executors that lack a given function.
local function getexec(name) local ok, v = pcall(function() return (getgenv and getgenv()[name]) or rawget(getfenv(0), name) end) return ok and v or nil end

local protect_gui = (syn and syn.protect_gui)
	or protectgui
	or (getexec("protect_gui"))
local function Protect(gui)
	pcall(function()
		if protect_gui then protect_gui(gui) end
		if gethui then gui.Parent = gethui() end
	end)
end

-- File system wrappers (config). Guarded so nothing errors when absent.
local hasFS = (writefile and readfile and isfile) and true or false
local function safeMakeFolder(path)
	if makefolder and isfolder and not isfolder(path) then
		pcall(makefolder, path)
	end
end
local function safeWrite(path, data) if writefile then pcall(writefile, path, data) end end
local function safeRead(path) if isfile and readfile and isfile(path) then local ok, d = pcall(readfile, path) if ok then return d end end return nil end
local function safeIsFile(path) return isfile and isfile(path) or false end

-- // ============================ Theme ============================ //
-- Black by default. Every colour below can be overridden per-window
-- via the Theme table, or globally with ChaseUI:SetTheme{...}.
local DefaultTheme = {
	Accent        = Color3.fromRGB(99, 102, 241),  -- the one "colour" the user tweaks
	AccentText    = Color3.fromRGB(255, 255, 255),
	Background    = Color3.fromRGB(14, 14, 16),
	Topbar        = Color3.fromRGB(10, 10, 12),
	Sidebar       = Color3.fromRGB(11, 11, 13),
	Element       = Color3.fromRGB(24, 24, 28),
	ElementHover  = Color3.fromRGB(34, 34, 40),
	ElementBorder = Color3.fromRGB(40, 40, 48),
	Divider       = Color3.fromRGB(32, 32, 38),
	Text          = Color3.fromRGB(236, 236, 240),
	SubText       = Color3.fromRGB(142, 142, 154),
	Notification  = Color3.fromRGB(18, 18, 22),
}

-- // ============================ State ============================ //
ChaseUI.Flags   = {}        -- flag -> element api (for config + Get/Set)
ChaseUI.Windows = {}        -- all open windows
ChaseUI.Theme   = table.clone(DefaultTheme)
ChaseUI._themed = {}        -- {instance, property, themeKey} for live retheme
ChaseUI._connections = {}   -- global connections for :Destroy()

-- // ========================= UI utilities ========================= //
local function Create(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end

-- Register an instance property to follow a theme key so SetTheme is live.
local function Themed(inst, property, themeKey, theme)
	inst[property] = (theme or ChaseUI.Theme)[themeKey]
	table.insert(ChaseUI._themed, {inst = inst, prop = property, key = themeKey, theme = theme})
	return inst
end

local function Tween(inst, info, goal)
	local t = TweenService:Create(inst, info, goal)
	t:Play()
	return t
end
local QUICK = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SMOOTH = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function Corner(radius, parent)
	return Create("UICorner", {CornerRadius = UDim.new(0, radius or 6), Parent = parent})
end
local function Stroke(parent, color, thickness, transparency)
	return Create("UIStroke", {
		Color = color or ChaseUI.Theme.ElementBorder,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end
local function Padding(parent, all)
	return Create("UIPadding", {
		PaddingTop = UDim.new(0, all), PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all), PaddingRight = UDim.new(0, all),
		Parent = parent,
	})
end

-- Track connections so a window / the library can disconnect everything.
local function track(bucket, conn)
	table.insert(bucket, conn)
	return conn
end

-- Toggle the nearest ancestor ScrollingFrame so a value drag on mobile
-- doesn't double as a page scroll gesture.
local function setAncestorScroll(inst, enabled)
	local p = inst and inst.Parent
	while p do
		if p:IsA("ScrollingFrame") then p.ScrollingEnabled = enabled return end
		p = p.Parent
	end
end

-- Dragging that works for both mouse and touch (mobile executors).
local function MakeDraggable(handle, target, bucket)
	target = target or handle
	local dragging, dragStart, startPos = false, nil, nil
	track(bucket, handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
			local changed
			changed = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					if changed then changed:Disconnect() end
				end
			end)
		end
	end))
	track(bucket, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			target.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end))
end

-- Root ScreenGui, parented to the safest available container.
local function buildRoot(name)
	local gui = Create("ScreenGui", {
		Name = name or ("ChaseUI_" .. HttpService:GenerateGUID(false):sub(1, 6)),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = 999999,
	})
	local parented = false
	-- Prefer gethui / protected container, then CoreGui, then PlayerGui.
	pcall(function() if gethui then gui.Parent = gethui() parented = true end end)
	if not parented then pcall(function() Protect(gui) gui.Parent = CoreGui parented = true end) end
	if not parented then pcall(function() gui.Parent = LocalPlayer:WaitForChild("PlayerGui") parented = true end) end
	return gui
end

-- Destroy any ChaseUI window roots already present. Makes re-injection safe
-- even on executors without getgenv (where the global guard can't run).
local function destroyExistingWindows()
	local containers = {}
	pcall(function() if gethui then table.insert(containers, gethui()) end end)
	pcall(function() table.insert(containers, CoreGui) end)
	pcall(function() table.insert(containers, LocalPlayer:FindFirstChild("PlayerGui")) end)
	for _, c in ipairs(containers) do
		if c then
			pcall(function()
				for _, child in ipairs(c:GetChildren()) do
					if child:GetAttribute("ChaseUIWindowRoot") then child:Destroy() end
				end
			end)
		end
	end
end

-- // ========================= Theme control ========================= //
-- Live retheme: update stored colours and tween every registered property.
function ChaseUI:SetTheme(partial)
	for k, v in pairs(partial or {}) do
		if DefaultTheme[k] ~= nil then ChaseUI.Theme[k] = v end
	end
	for _, entry in ipairs(ChaseUI._themed) do
		if entry.inst and entry.inst.Parent then
			local source = entry.theme or ChaseUI.Theme
			-- windows with their own theme table are kept in sync too
			if entry.theme then entry.theme[entry.key] = ChaseUI.Theme[entry.key] end
			pcall(function()
				Tween(entry.inst, QUICK, {[entry.prop] = source[entry.key]})
			end)
		end
	end
end

-- Convenience: change only the accent colour.
function ChaseUI:SetAccent(color)
	self:SetTheme({Accent = color})
end

-- // ======================= Notifications ======================= //
local notifRoot, notifHolder
local function ensureNotifRoot()
	if notifRoot and notifRoot.Parent then return end
	notifRoot = buildRoot("ChaseUI_Notifications")
	notifHolder = Create("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -18),
		Size = UDim2.new(0, 300, 1, -36),
		BackgroundTransparency = 1,
		Parent = notifRoot,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
end

function ChaseUI:Notify(opts)
	opts = opts or {}
	ensureNotifRoot()
	local title    = tostring(opts.Title or "Notification")
	local content  = tostring(opts.Content or "")
	local duration = tonumber(opts.Duration) or 4
	local T = ChaseUI.Theme

	local card = Create("Frame", {
		Name = "Notif",
		BackgroundColor3 = T.Notification,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
		Parent = notifHolder,
	}, {
		Corner(8),
	})
	Stroke(card, T.ElementBorder, 1, 0.3)
	Create("Frame", { -- accent bar
		Name = "Bar", BackgroundColor3 = T.Accent, BorderSizePixel = 0,
		Size = UDim2.new(0, 3, 1, -12), Position = UDim2.new(0, 6, 0, 6),
		Parent = card,
	}, { Corner(3) })
	local body = Create("Frame", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0, 0),
		Size = UDim2.new(1, -28, 1, 0), AutomaticSize = Enum.AutomaticSize.Y,
		Parent = card,
	}, {
		Create("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}),
		Create("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10)}),
	})
	Create("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.GothamBold, Text = title, TextSize = 14,
		TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 1, Parent = body,
	})
	if content ~= "" then
		Create("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.Gotham,
			Text = content, TextSize = 12, TextColor3 = T.SubText,
			TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2, Parent = body,
		})
	end

	-- The holder's UIListLayout owns Position, so entrance is a fade + grow.
	card.BackgroundTransparency = 1
	Tween(card, SMOOTH, {BackgroundTransparency = 0})
	task.delay(duration, function()
		if card and card.Parent then
			Tween(card, QUICK, {BackgroundTransparency = 1})
			task.wait(0.22)
			if card then card:Destroy() end
		end
	end)
	return card
end

-- // ========================= Config system ========================= //
-- Each flagged element exposes :Set() and a .Value and registers in Flags.
-- Config files are plain JSON of {flag = value}. Colours are serialised.
local function serialize(v)
	if typeof(v) == "Color3" then
		return {__t = "Color3", r = v.R, g = v.G, b = v.B}
	elseif typeof(v) == "EnumItem" then
		return {__t = "Enum", s = tostring(v)}
	end
	return v
end
local function deserialize(v)
	if type(v) == "table" and v.__t == "Color3" then
		return Color3.new(v.r, v.g, v.b)
	elseif type(v) == "table" and v.__t == "Enum" then
		local parts = string.split(v.s, ".")
		local ok, e = pcall(function() return Enum[parts[2]][parts[3]] end)
		return ok and e or nil
	end
	return v
end

function ChaseUI:SaveConfig(path)
	if not hasFS then return false, "No file-system access on this executor" end
	local data = {}
	for flag, api in pairs(ChaseUI.Flags) do
		if api.Value ~= nil then data[flag] = serialize(api.Value) end
	end
	local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
	if not ok then return false, "encode failed" end
	local dir = path:match("^(.*)[/\\]")
	if dir and dir ~= "" then safeMakeFolder(dir) end
	safeWrite(path, encoded)
	return true
end

function ChaseUI:LoadConfig(path)
	if not hasFS or not safeIsFile(path) then return false end
	local raw = safeRead(path)
	if not raw then return false end
	local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not ok or type(data) ~= "table" then return false end
	for flag, v in pairs(data) do
		local api = ChaseUI.Flags[flag]
		if api and api.Set then pcall(api.Set, api, deserialize(v)) end
	end
	return true
end

-- // ========================= Key system ========================= //
-- Blocking gate screen. Returns true when a valid key is entered, false
-- if the user closes it. cfg = {Title, Subtitle, Keys = {...}, Note, GetKey}
local function RunKeySystem(cfg)
	cfg = cfg or {}
	local keys = cfg.Keys or {}
	local T = ChaseUI.Theme
	local gui = buildRoot("ChaseUI_Key")

	local shade = Create("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4,
		Size = UDim2.fromScale(1, 1), Parent = gui,
	})
	local box = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 210), BackgroundColor3 = T.Background,
		Parent = gui,
	}, { Corner(10) })
	Stroke(box, T.ElementBorder, 1, 0)
	Create("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0, 16),
		Size = UDim2.new(1, -36, 0, 24), Font = Enum.Font.GothamBold,
		Text = cfg.Title or "ChaseUI — Key System", TextSize = 18, TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = box,
	})
	Create("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0, 44),
		Size = UDim2.new(1, -36, 0, 32), Font = Enum.Font.Gotham,
		Text = cfg.Subtitle or "Enter your key to continue.", TextSize = 13,
		TextColor3 = T.SubText, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Parent = box,
	})
	local input = Create("TextBox", {
		Position = UDim2.new(0, 18, 0, 92), Size = UDim2.new(1, -36, 0, 38),
		BackgroundColor3 = T.Element, Font = Enum.Font.Gotham, PlaceholderText = "Key...",
		Text = "", TextSize = 14, TextColor3 = T.Text, ClearTextOnFocus = false,
		PlaceholderColor3 = T.SubText, Parent = box,
	}, { Corner(6) })
	Stroke(input, T.ElementBorder, 1, 0)
	local status = Create("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0, 134),
		Size = UDim2.new(1, -36, 0, 16), Font = Enum.Font.Gotham,
		Text = cfg.Note or "", TextSize = 12, TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = box,
	})
	-- CHUNK_KEY
	local function mkBtn(text, xScale, xOff, wScale, wOff, accent)
		local b = Create("TextButton", {
			Position = UDim2.new(xScale, xOff, 1, -52), Size = UDim2.new(wScale, wOff, 0, 36),
			BackgroundColor3 = accent and T.Accent or T.Element, AutoButtonColor = false,
			Font = Enum.Font.GothamBold, Text = text, TextSize = 14,
			TextColor3 = accent and T.AccentText or T.Text, Parent = box,
		}, { Corner(6) })
		if not accent then Stroke(b, T.ElementBorder, 1, 0) end
		return b
	end
	local submit = mkBtn("Submit", 0, 18, 0.6, -24, true)
	local close  = mkBtn("Close", 0.6, 6, 0.4, -24, false)
	if cfg.GetKey then
		local gk = Create("TextButton", {
			BackgroundTransparency = 1, Position = UDim2.new(1, -118, 0, 18),
			Size = UDim2.new(0, 100, 0, 20), Font = Enum.Font.Gotham, Text = "Get Key →",
			TextSize = 12, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Right,
			Parent = box,
		})
		gk.MouseButton1Click:Connect(function()
			if setclipboard then pcall(setclipboard, tostring(cfg.GetKey)) end
			status.Text = "Key link copied to clipboard."
			status.TextColor3 = T.Accent
		end)
	end

	local result = nil
	local function finish(ok) result = ok end
	submit.MouseButton1Click:Connect(function()
		local entered = input.Text
		local valid = false
		for _, k in ipairs(keys) do if entered == tostring(k) then valid = true break end end
		if valid then
			status.Text = "Access granted."; status.TextColor3 = T.Accent
			finish(true)
		else
			status.Text = "Invalid key."; status.TextColor3 = Color3.fromRGB(235, 90, 90)
			input.Text = ""
			Tween(box, QUICK, {Position = UDim2.new(0.5, 8, 0.5, 0)})
			task.wait(0.06); Tween(box, QUICK, {Position = UDim2.fromScale(0.5, 0.5)})
		end
	end)
	close.MouseButton1Click:Connect(function() finish(false) end)

	box.Size = UDim2.fromOffset(340, 190)
	box.BackgroundTransparency = 1
	Tween(box, SMOOTH, {Size = UDim2.fromOffset(340, 210), BackgroundTransparency = 0})

	repeat task.wait() until result ~= nil
	Tween(shade, QUICK, {BackgroundTransparency = 1})
	Tween(box, QUICK, {BackgroundTransparency = 1, Size = UDim2.fromOffset(340, 190)})
	task.wait(0.2)
	gui:Destroy()
	return result == true
end

-- // ====================== Element builders (fwd) ====================== //
-- Populated further below; declared here so CreateWindow can capture it.
local Build = {}

-- // ======================= Null (safe) stubs ======================= //
-- Returned when a key check fails, so chained calls never error.
local function noop() end
local NullElement = setmetatable({}, {__index = function() return noop end})
local NullSection = setmetatable({}, {__index = function() return function() return NullElement end end})
local NullTab = setmetatable({}, {__index = function() return function() return NullSection end end})
local NullWindow = setmetatable({Destroyed = true}, {__index = function() return function() return NullTab end end})

-- // ========================= Window ========================= //
function ChaseUI:CreateWindow(cfg)
	cfg = cfg or {}
	-- per-window theme overrides merge into the live theme
	if cfg.Theme then self:SetTheme(cfg.Theme) end
	if cfg.Accent then self:SetAccent(cfg.Accent) end
	local T = ChaseUI.Theme

	-- optional key gate (blocking)
	if cfg.KeySystem then
		local ok = RunKeySystem(cfg.KeySystem == true and {Keys = cfg.Keys or {}} or cfg.KeySystem)
		if not ok then return NullWindow end
	end

	local Window = {Tabs = {}, _conns = {}, _open = true}
	destroyExistingWindows()
	local root = buildRoot(cfg.Name or "ChaseUI")
	pcall(function() root:SetAttribute("ChaseUIWindowRoot", true) end)
	Window.Root = root

	local size = cfg.Size or UDim2.fromOffset(580, 420)
	local main = Create("Frame", {
		Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = size,
		BackgroundColor3 = T.Background, ClipsDescendants = true, Parent = root,
	}, { Corner(10) })
	Themed(main, "BackgroundColor3", "Background")
	Stroke(main, T.ElementBorder, 1, 0)
	Window.Main = main

	-- Topbar
	local topbar = Create("Frame", {
		Name = "Topbar", BackgroundColor3 = T.Topbar, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 44), Parent = main,
	}, { Corner(10) })
	Themed(topbar, "BackgroundColor3", "Topbar")
	Create("Frame", { -- hide bottom corners of topbar
		BackgroundColor3 = T.Topbar, BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -10), Size = UDim2.new(1, 0, 0, 10), Parent = topbar,
	})
	MakeDraggable(topbar, main, Window._conns)

	-- CHUNK_WIN
	-- Title + subtitle
	Create("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 0),
		Size = UDim2.new(1, -120, 1, 0), Font = Enum.Font.GothamBold,
		Text = cfg.Title or "ChaseUI", TextSize = 16, TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = topbar,
	})

	-- Close + minimise buttons
	local function topBtn(symbol, offset)
		local b = Create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, offset, 0.5, 0),
			Size = UDim2.fromOffset(26, 26), BackgroundColor3 = T.Element,
			AutoButtonColor = false, Font = Enum.Font.GothamBold, Text = symbol,
			TextSize = 14, TextColor3 = T.SubText, Parent = topbar,
		}, { Corner(6) })
		b.MouseEnter:Connect(function() Tween(b, QUICK, {BackgroundColor3 = T.ElementHover, TextColor3 = T.Text}) end)
		b.MouseLeave:Connect(function() Tween(b, QUICK, {BackgroundColor3 = T.Element, TextColor3 = T.SubText}) end)
		return b
	end
	local closeBtn = topBtn("X", -10)
	local miniBtn  = topBtn("—", -42)

	-- Sidebar (tab buttons)
	local sidebar = Create("Frame", {
		Name = "Sidebar", BackgroundColor3 = T.Sidebar, BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 44), Size = UDim2.new(0, 148, 1, -44), Parent = main,
	})
	Themed(sidebar, "BackgroundColor3", "Sidebar")
	local tabList = Create("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 8, 0, 8),
		Size = UDim2.new(1, -16, 1, -16), ScrollBarThickness = 0, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = sidebar,
	}, {
		Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
	})
	Window.TabList = tabList

	-- Content container
	local content = Create("Frame", {
		Name = "Content", BackgroundTransparency = 1, Position = UDim2.new(0, 148, 0, 44),
		Size = UDim2.new(1, -148, 1, -44), Parent = main,
	})
	Window.Content = content
	-- CHUNK_WIN2
	-- Floating re-open button (great for mobile / after minimise)
	local floatBtn = Create("TextButton", {
		Name = "Toggle", AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = T.Accent, AutoButtonColor = false, Font = Enum.Font.GothamBold,
		Text = (cfg.ToggleIcon or "C"), TextSize = 20, TextColor3 = T.AccentText,
		Visible = false, Parent = root,
	}, { Corner(22) })
	Themed(floatBtn, "BackgroundColor3", "Accent")
	-- Track motion so a drag-release doesn't also count as a tap-to-open.
	local floatDownPos, floatMoved = nil, false
	track(Window._conns, floatBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			floatDownPos, floatMoved = input.Position, false
		end
	end))
	track(Window._conns, UserInputService.InputChanged:Connect(function(input)
		if floatDownPos and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			if (input.Position - floatDownPos).Magnitude > 6 then floatMoved = true end
		end
	end))
	MakeDraggable(floatBtn, floatBtn, Window._conns)

	function Window:SetOpen(state)
		self._open = state
		if state then
			main.Visible = true
			main.Size = UDim2.new(size.X.Scale, size.X.Offset, 0, 0)
			Tween(main, SMOOTH, {Size = size})
			floatBtn.Visible = false
		else
			Tween(main, QUICK, {Size = UDim2.new(size.X.Scale, size.X.Offset, 0, 0)})
			task.delay(0.2, function() if not self._open then main.Visible = false end end)
			floatBtn.Visible = true
		end
	end
	function Window:Toggle() self:SetOpen(not self._open) end

	closeBtn.MouseButton1Click:Connect(function() Window:Destroy() end)
	miniBtn.MouseButton1Click:Connect(function() Window:SetOpen(false) end)
	floatBtn.MouseButton1Click:Connect(function()
		if floatMoved then floatMoved = false; return end
		Window:SetOpen(true)
	end)

	-- Toggle keybind (default RightShift; mobile users use the float button)
	local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
	track(Window._conns, UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == toggleKey then Window:Toggle() end
	end))

	-- open animation
	main.Size = UDim2.new(size.X.Scale, size.X.Offset, 0, 0)
	main.BackgroundTransparency = 0
	Tween(main, SMOOTH, {Size = size})

	table.insert(ChaseUI.Windows, Window)
	-- CHUNK_WIN3
	function Window:Notify(opts) return ChaseUI:Notify(opts) end

	function Window:Destroy()
		for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
		table.clear(self._conns)
		Tween(main, QUICK, {Size = UDim2.new(size.X.Scale, size.X.Offset, 0, 0), BackgroundTransparency = 1})
		task.wait(0.2)
		pcall(function() self.Root:Destroy() end)
		for i, w in ipairs(ChaseUI.Windows) do if w == self then table.remove(ChaseUI.Windows, i) break end end
		self.Destroyed = true
	end

	function Window:SelectTab(target)
		for _, tab in ipairs(self.Tabs) do
			local active = (tab == target)
			tab.Page.Visible = active
			Tween(tab.Button, QUICK, {BackgroundColor3 = active and T.Element or T.Sidebar})
			Tween(tab.Label, QUICK, {TextColor3 = active and T.Text or T.SubText})
			Tween(tab.Indicator, QUICK, {BackgroundTransparency = active and 0 or 1})
			tab.Selected = active
		end
	end

	-- CHUNK_TAB
	-- Wires every element constructor onto a tab or section object.
	local function attachElements(obj, container)
		function obj:CreateButton(o)     return Build.Button(container, o) end
		function obj:CreateToggle(o)      return Build.Toggle(container, o) end
		function obj:CreateSlider(o)      return Build.Slider(container, o) end
		function obj:CreateDropdown(o)    return Build.Dropdown(container, o, root) end
		function obj:CreateInput(o)       return Build.Input(container, o) end
		function obj:CreateTextbox(o)     return Build.Input(container, o) end
		function obj:CreateKeybind(o)     return Build.Keybind(container, o) end
		function obj:CreateColorPicker(o) return Build.ColorPicker(container, o, root) end
		function obj:CreateLabel(o)       return Build.Label(container, o) end
		function obj:CreateParagraph(o)   return Build.Paragraph(container, o) end
		function obj:CreateDivider()      return Build.Divider(container) end
		function obj:CreateSection(title)
			local sec = Build.Section(container, title)
			local secObj = {Instance = sec.Frame}
			attachElements(secObj, sec.Holder)
			return secObj
		end
		return obj
	end

	function Window:CreateTab(name, icon)
		local idx = #self.Tabs + 1
		local btn = Create("TextButton", {
			Name = name or ("Tab" .. idx), BackgroundColor3 = T.Sidebar,
			AutoButtonColor = false, Text = "", Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = idx, Parent = self.TabList,
		}, { Corner(6) })
		local indicator = Create("Frame", {
			BackgroundColor3 = T.Accent, BorderSizePixel = 0, BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0),
			Size = UDim2.new(0, 3, 0, 16), Parent = btn,
		}, { Corner(3) })
		Themed(indicator, "BackgroundColor3", "Accent")
		local label = Create("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 0),
			Size = UDim2.new(1, -24, 1, 0), Font = Enum.Font.GothamMedium,
			Text = ((icon and (icon .. "  ")) or "") .. (name or "Tab"), TextSize = 13,
			TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = btn,
		})

		local page = Create("ScrollingFrame", {
			Name = (name or "Tab") .. "Page", BackgroundTransparency = 1, BorderSizePixel = 0,
			Position = UDim2.new(0, 8, 0, 4), Size = UDim2.new(1, -16, 1, -12),
			ScrollBarThickness = 3, ScrollBarImageColor3 = T.ElementBorder,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false, Parent = self.Content,
		}, {
			Create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
			Create("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingRight = UDim.new(0, 4)}),
		})

		local tab = {Button = btn, Label = label, Indicator = indicator, Page = page, Selected = false}
		btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)
		btn.MouseEnter:Connect(function() if not tab.Selected then Tween(btn, QUICK, {BackgroundColor3 = T.Element}) end end)
		btn.MouseLeave:Connect(function() if not tab.Selected then Tween(btn, QUICK, {BackgroundColor3 = T.Sidebar}) end end)
		attachElements(tab, page)
		table.insert(self.Tabs, tab)
		if idx == 1 then self:SelectTab(tab) end
		return tab
	end
	-- CHUNK_TAB_END
	return Window
end

-- // ====================== Element builders (impl) ====================== //
local function elementFrame(parent, height)
	local T = ChaseUI.Theme
	local f = Create("Frame", {
		BackgroundColor3 = T.Element, Size = UDim2.new(1, 0, 0, height or 40),
		AutomaticSize = Enum.AutomaticSize.None, Parent = parent,
	}, { Corner(6) })
	Themed(f, "BackgroundColor3", "Element")
	Stroke(f, T.ElementBorder, 1, 0)
	return f
end

local function hoverable(frame)
	local T = ChaseUI.Theme
	frame.MouseEnter:Connect(function() Tween(frame, QUICK, {BackgroundColor3 = T.ElementHover}) end)
	frame.MouseLeave:Connect(function() Tween(frame, QUICK, {BackgroundColor3 = T.Element}) end)
end

local function mkLabel(parent, text, size, color, bold)
	local T = ChaseUI.Theme
	return Create("TextLabel", {
		BackgroundTransparency = 1, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		Text = text or "", TextSize = size or 13, TextColor3 = color or T.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
	})
end

-- ---- Label ----
function Build.Label(parent, o)
	o = type(o) == "table" and o or {Text = tostring(o)}
	local f = elementFrame(parent, 34)
	local lbl = mkLabel(f, o.Text or "Label", 13, nil, false)
	lbl.Position = UDim2.new(0, 12, 0, 0); lbl.Size = UDim2.new(1, -24, 1, 0)
	Themed(lbl, "TextColor3", "Text")
	local api = {Instance = f}
	function api:SetText(t) lbl.Text = tostring(t) end
	return api
end

-- ---- Paragraph ----
function Build.Paragraph(parent, o)
	o = o or {}
	local T = ChaseUI.Theme
	local f = elementFrame(parent, 10)
	f.AutomaticSize = Enum.AutomaticSize.Y
	local holder = Create("Frame", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(1, -24, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = f,
	}, {
		Create("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}),
		Create("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10)}),
	})
	local title = mkLabel(holder, o.Title or "Paragraph", 13, T.Text, true)
	title.Size = UDim2.new(1, 0, 0, 16); title.LayoutOrder = 1
	Themed(title, "TextColor3", "Text")
	local body = mkLabel(holder, o.Content or "", 12, T.SubText, false)
	body.Size = UDim2.new(1, 0, 0, 0); body.AutomaticSize = Enum.AutomaticSize.Y
	body.TextWrapped = true; body.LayoutOrder = 2
	Themed(body, "TextColor3", "SubText")
	local api = {Instance = f}
	function api:SetText(t) body.Text = tostring(t) end
	function api:SetTitle(t) title.Text = tostring(t) end
	return api
end

-- ---- Divider ----
function Build.Divider(parent)
	local T = ChaseUI.Theme
	local f = Create("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 10), Parent = parent})
	local line = Create("Frame", {
		BackgroundColor3 = T.Divider, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 1), Parent = f,
	})
	Themed(line, "BackgroundColor3", "Divider")
	return {Instance = f}
end

-- ---- Section ----
function Build.Section(parent, title)
	local T = ChaseUI.Theme
	local f = Create("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, Parent = parent,
	}, {
		Create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
	})
	local header = mkLabel(f, (title or "Section"):upper(), 11, T.SubText, true)
	header.Size = UDim2.new(1, 0, 0, 14); header.LayoutOrder = 0
	header.TextSize = 11
	Themed(header, "TextColor3", "SubText")
	local holder = Create("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = f,
	}, {
		Create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
	})
	return {Frame = f, Holder = holder, Header = header}
end

-- ---- Button ----
function Build.Button(parent, o)
	o = o or {}
	local T = ChaseUI.Theme
	local f = elementFrame(parent, 40)
	local btn = Create("TextButton", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", Parent = f,
	})
	local lbl = mkLabel(f, o.Name or o.Title or "Button", 13, T.Text, false)
	lbl.Position = UDim2.new(0, 12, 0, 0); lbl.Size = UDim2.new(1, -40, 1, 0)
	Themed(lbl, "TextColor3", "Text")
	local arrow = mkLabel(f, "›", 18, T.SubText, true)
	arrow.AnchorPoint = Vector2.new(1, 0.5); arrow.Position = UDim2.new(1, -12, 0.5, 0)
	arrow.Size = UDim2.fromOffset(12, 20); arrow.TextXAlignment = Enum.TextXAlignment.Right
	hoverable(f)
	local callback = o.Callback or function() end
	btn.MouseButton1Click:Connect(function()
		Tween(f, TweenInfo.new(0.08), {BackgroundColor3 = T.ElementBorder})
		task.delay(0.09, function() Tween(f, QUICK, {BackgroundColor3 = T.ElementHover}) end)
		task.spawn(function() local ok, err = pcall(callback) if not ok then warn("[ChaseUI] Button callback error: " .. tostring(err)) end end)
	end)
	local api = {Instance = f}
	function api:SetText(t) lbl.Text = tostring(t) end
	function api:SetCallback(fn) callback = fn or function() end end
	function api:Fire() task.spawn(callback) end
	return api
end

-- ---- Toggle ----
function Build.Toggle(parent, o)
	o = o or {}
	local T = ChaseUI.Theme
	local f = elementFrame(parent, 40)
	local btn = Create("TextButton", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", Parent = f})
	local lbl = mkLabel(f, o.Name or o.Title or "Toggle", 13, T.Text, false)
	lbl.Position = UDim2.new(0, 12, 0, 0); lbl.Size = UDim2.new(1, -70, 1, 0)
	Themed(lbl, "TextColor3", "Text")

	local track = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(40, 22), BackgroundColor3 = T.ElementBorder, Parent = f,
	}, { Corner(11) })
	local knob = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.fromRGB(235, 235, 235), Parent = track,
	}, { Corner(8) })
	hoverable(f)

	local value = o.Default == true or o.CurrentValue == true
	local callback = o.Callback or function() end
	local api = {Instance = f, Value = value, Type = "Toggle"}

	local function visual(animate)
		local info = animate and QUICK or TweenInfo.new(0)
		Tween(track, info, {BackgroundColor3 = value and T.Accent or T.ElementBorder})
		Tween(knob, info, {Position = value and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)})
	end
	function api:Set(v, skipCb)
		value = v and true or false
		self.Value = value
		visual(true)
		if not skipCb then task.spawn(function() local ok, e = pcall(callback, value) if not ok then warn("[ChaseUI] Toggle error: " .. tostring(e)) end end) end
	end
	function api:Get() return value end
	btn.MouseButton1Click:Connect(function() api:Set(not value) end)
	visual(false)

	if o.Flag then ChaseUI.Flags[o.Flag] = api end
	return api
end

-- ---- Slider ----
function Build.Slider(parent, o)
	o = o or {}
	if o.Default == nil then o.Default = o.CurrentValue end
	local T = ChaseUI.Theme
	local min = tonumber(o.Min) or 0
	local max = tonumber(o.Max) or 100
	local inc = tonumber(o.Increment); if not inc or inc <= 0 then inc = 1 end
	local suffix = o.Suffix or ""
	local f = elementFrame(parent, 54)
	local lbl = mkLabel(f, o.Name or o.Title or "Slider", 13, T.Text, false)
	lbl.Position = UDim2.new(0, 12, 0, 8); lbl.Size = UDim2.new(1, -80, 0, 16)
	Themed(lbl, "TextColor3", "Text")
	local valLbl = mkLabel(f, "", 13, T.SubText, true)
	valLbl.AnchorPoint = Vector2.new(1, 0); valLbl.Position = UDim2.new(1, -12, 0, 8)
	valLbl.Size = UDim2.fromOffset(64, 16); valLbl.TextXAlignment = Enum.TextXAlignment.Right
	Themed(valLbl, "TextColor3", "SubText")

	local track = Create("Frame", {
		Position = UDim2.new(0, 12, 1, -18), Size = UDim2.new(1, -24, 0, 6),
		BackgroundColor3 = T.ElementBorder, Parent = f,
	}, { Corner(3) })
	local fill = Create("Frame", {
		BackgroundColor3 = T.Accent, Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, Parent = track,
	}, { Corner(3) })
	Themed(fill, "BackgroundColor3", "Accent")
	local knob = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.fromRGB(240, 240, 240), Parent = track,
	}, { Corner(7) })

	local function round(v) return math.floor((v / inc) + 0.5) * inc end
	local value = math.clamp(tonumber(o.Default) or min, min, max)
	local callback = o.Callback or function() end
	local api = {Instance = f, Value = value, Type = "Slider"}

	local function apply(v, animate, skipCb)
		v = math.clamp(round(v), min, max)
		value = v; api.Value = v
		local alpha = (max - min == 0) and 0 or (v - min) / (max - min)
		local info = animate and QUICK or TweenInfo.new(0)
		Tween(fill, info, {Size = UDim2.new(alpha, 0, 1, 0)})
		Tween(knob, info, {Position = UDim2.new(alpha, 0, 0.5, 0)})
		local disp = (inc < 1) and string.format("%.2f", v) or tostring(math.floor(v))
		valLbl.Text = disp .. suffix
		if not skipCb then task.spawn(function() local ok, e = pcall(callback, v) if not ok then warn("[ChaseUI] Slider error: " .. tostring(e)) end end) end
	end
	function api:Set(v, skipCb) apply(v, true, skipCb) end
	function api:Get() return value end

	local dragging = false
	local moveConn
	local function fromInput(px)
		local rel = (px - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		apply(min + rel * (max - min), false)
	end
	local function stopDrag()
		dragging = false
		if moveConn then moveConn:Disconnect(); moveConn = nil end
		setAncestorScroll(f, true)
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true; setAncestorScroll(f, false); fromInput(input.Position.X)
			if not moveConn then
				moveConn = UserInputService.InputChanged:Connect(function(i)
					if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
						fromInput(i.Position.X)
					end
				end)
			end
		end
	end)
	track.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then stopDrag() end
	end)
	f.Destroying:Connect(stopDrag)
	apply(value, false, true)

	if o.Flag then ChaseUI.Flags[o.Flag] = api end
	return api
end

-- ---- Input (textbox) ----
function Build.Input(parent, o)
	o = o or {}
	if o.Default == nil then o.Default = o.CurrentValue end
	local T = ChaseUI.Theme
	local f = elementFrame(parent, 40)
	local lbl = mkLabel(f, o.Name or o.Title or "Input", 13, T.Text, false)
	lbl.Position = UDim2.new(0, 12, 0, 0); lbl.Size = UDim2.new(0.45, -12, 1, 0)
	Themed(lbl, "TextColor3", "Text")

	local boxWrap = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0.5, -10, 0, 28), BackgroundColor3 = T.Background, Parent = f,
	}, { Corner(6) })
	Themed(boxWrap, "BackgroundColor3", "Background")
	Stroke(boxWrap, T.ElementBorder, 1, 0)
	local box = Create("TextBox", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -16, 1, 0),
		Font = Enum.Font.Gotham, PlaceholderText = o.Placeholder or "...", Text = tostring(o.Default or ""),
		TextSize = 13, TextColor3 = T.Text, PlaceholderColor3 = T.SubText, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = boxWrap,
	})
	Themed(box, "TextColor3", "Text")

	local callback = o.Callback or function() end
	local api = {Instance = f, Value = box.Text, Type = "Input"}
	box.FocusLost:Connect(function(enter)
		api.Value = box.Text
		if o.ClearOnFocus then box.Text = "" end
		task.spawn(function() local ok, e = pcall(callback, api.Value, enter) if not ok then warn("[ChaseUI] Input error: " .. tostring(e)) end end)
	end)
	function api:Set(v, skipCb)
		box.Text = tostring(v); api.Value = box.Text
		if not skipCb then task.spawn(callback, api.Value, false) end
	end
	function api:Get() return api.Value end

	if o.Flag then ChaseUI.Flags[o.Flag] = api end
	return api
end

-- ---- Keybind ----
function Build.Keybind(parent, o)
	o = o or {}
	if o.Default == nil then o.Default = o.CurrentValue end
	local T = ChaseUI.Theme
	local f = elementFrame(parent, 40)
	local lbl = mkLabel(f, o.Name or o.Title or "Keybind", 13, T.Text, false)
	lbl.Position = UDim2.new(0, 12, 0, 0); lbl.Size = UDim2.new(1, -120, 1, 0)
	Themed(lbl, "TextColor3", "Text")

	local function keyName(k) return k and tostring(k):gsub("Enum.KeyCode.", ""):gsub("Enum.UserInputType.", "") or "None" end
	local current = o.Default
	if type(current) == "string" then local ok, e = pcall(function() return Enum.KeyCode[current] end) current = ok and e or nil end

	local disp = Create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(96, 28), BackgroundColor3 = T.Background, AutoButtonColor = false,
		Font = Enum.Font.GothamMedium, Text = keyName(current), TextSize = 12, TextColor3 = T.Text, Parent = f,
	}, { Corner(6) })
	Themed(disp, "BackgroundColor3", "Background")
	Stroke(disp, T.ElementBorder, 1, 0)
	hoverable(f)

	local callback = o.Callback or function() end
	local listening = false
	local api = {Instance = f, Value = current and keyName(current) or "None", Type = "Keybind"}

	disp.MouseButton1Click:Connect(function()
		listening = true; disp.Text = "..."
		Tween(disp, QUICK, {TextColor3 = T.Accent})
	end)
	local kbConn = UserInputService.InputBegan:Connect(function(input, gpe)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape then current = nil
				else current = input.KeyCode end
				listening = false
				disp.Text = keyName(current); api.Value = disp.Text
				Tween(disp, QUICK, {TextColor3 = T.Text})
			end
			return
		end
		if gpe then return end
		if current and input.KeyCode == current then
			task.spawn(function() local ok, e = pcall(callback, current) if not ok then warn("[ChaseUI] Keybind error: " .. tostring(e)) end end)
		end
	end)
	f.Destroying:Connect(function() if kbConn then kbConn:Disconnect(); kbConn = nil end end)
	function api:Set(v)
		if type(v) == "string" then local ok, e = pcall(function() return Enum.KeyCode[v] end) current = ok and e or nil
		else current = v end
		disp.Text = keyName(current); api.Value = disp.Text
	end
	function api:Get() return current end

	if o.Flag then ChaseUI.Flags[o.Flag] = api end
	return api
end

-- ---- Dropdown (single + multi select, inline expand) ----
function Build.Dropdown(parent, o)
	o = o or {}
	if o.Default == nil then o.Default = o.CurrentValue end
	local T = ChaseUI.Theme
	local multi = o.Multi == true or o.MultiSelect == true
	local options = o.Options or {}
	local ROW, MAXH = 30, 150

	local f = elementFrame(parent, 40)
	f.ClipsDescendants = true
	local header = Create("TextButton", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Text = "", Parent = f,
	})
	local lbl = mkLabel(f, o.Name or o.Title or "Dropdown", 13, T.Text, false)
	lbl.Position = UDim2.new(0, 12, 0, 0); lbl.Size = UDim2.new(0.5, -12, 0, 40)
	Themed(lbl, "TextColor3", "Text")
	local valLbl = mkLabel(f, "", 12, T.SubText, false)
	valLbl.AnchorPoint = Vector2.new(1, 0); valLbl.Position = UDim2.new(1, -32, 0, 0)
	valLbl.Size = UDim2.new(0.5, 0, 0, 40); valLbl.TextXAlignment = Enum.TextXAlignment.Right
	valLbl.TextTruncate = Enum.TextTruncate.AtEnd
	Themed(valLbl, "TextColor3", "SubText")
	local chev = mkLabel(f, "▾", 13, T.SubText, true)
	chev.AnchorPoint = Vector2.new(1, 0); chev.Position = UDim2.new(1, -12, 0, 0)
	chev.Size = UDim2.fromOffset(14, 40); chev.TextXAlignment = Enum.TextXAlignment.Right

	local list = Create("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 6, 0, 42),
		Size = UDim2.new(1, -12, 0, 0), ScrollBarThickness = 2, ScrollBarImageColor3 = T.ElementBorder,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = f,
	}, {
		Create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}),
		Create("UIPadding", {PaddingBottom = UDim.new(0, 6)}),
	})
	hoverable(f)
	-- CHUNK_DD
	local callback = o.Callback or function() end
	local open = false
	local api = {Instance = f, Type = "Dropdown", Multi = multi}

	-- selection state
	local selectedSet = {}   -- multi
	local selectedOne = nil  -- single

	local function selectedArray()
		local t = {}
		for _, opt in ipairs(options) do if selectedSet[opt] then t[#t + 1] = opt end end
		return t
	end
	local function refreshValueLabel()
		if multi then
			local arr = selectedArray()
			api.Value = arr
			valLbl.Text = (#arr == 0) and "None" or (#arr <= 2 and table.concat(arr, ", ") or (#arr .. " selected"))
		else
			api.Value = selectedOne
			valLbl.Text = selectedOne ~= nil and tostring(selectedOne) or "None"
		end
	end

	local function fire()
		local payload = multi and selectedArray() or selectedOne
		task.spawn(function() local ok, e = pcall(callback, payload) if not ok then warn("[ChaseUI] Dropdown error: " .. tostring(e)) end end)
	end

	local function setHeight()
		local count = #options
		local contentH = count * ROW + math.max(count - 1, 0) * 4 + 6
		local shown = open and math.min(contentH, MAXH) or 0
		Tween(f, QUICK, {Size = UDim2.new(1, 0, 0, 40 + (open and (shown + 6) or 0))})
		Tween(list, QUICK, {Size = UDim2.new(1, -12, 0, shown)})
		Tween(chev, QUICK, {Rotation = open and 180 or 0})
	end

	local rowBtns = {}
	local function rebuild()
		for _, b in ipairs(rowBtns) do b:Destroy() end
		table.clear(rowBtns)
		for i, opt in ipairs(options) do
			local sel = multi and selectedSet[opt] or (selectedOne == opt)
			local b = Create("TextButton", {
				BackgroundColor3 = sel and T.Accent or T.Background, AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, ROW), LayoutOrder = i, Font = Enum.Font.Gotham,
				Text = "  " .. tostring(opt), TextSize = 12, TextColor3 = sel and T.AccentText or T.Text,
				TextXAlignment = Enum.TextXAlignment.Left, Parent = list,
			}, { Corner(5) })
			b.MouseButton1Click:Connect(function()
				if multi then
					selectedSet[opt] = not selectedSet[opt] and true or nil
				else
					selectedOne = opt
					open = false; setHeight()
				end
				refreshValueLabel(); rebuild(); fire()
			end)
			rowBtns[#rowBtns + 1] = b
		end
	end

	header.MouseButton1Click:Connect(function() open = not open; setHeight() end)

	-- defaults
	if multi then
		for _, d in ipairs(o.Default or {}) do selectedSet[d] = true end
	else
		selectedOne = o.Default
	end
	refreshValueLabel(); rebuild()

	function api:Set(v, skipCb)
		if multi then
			selectedSet = {}
			if type(v) == "table" then for _, x in ipairs(v) do selectedSet[x] = true end end
		else
			selectedOne = v
		end
		refreshValueLabel(); rebuild()
		if not skipCb then fire() end
	end
	function api:Get() return api.Value end
	function api:Refresh(newOptions, keep)
		options = newOptions or {}
		if not keep then selectedSet = {}; selectedOne = nil end
		refreshValueLabel(); rebuild(); if open then setHeight() end
	end
	function api:SetOptions(n, k) return self:Refresh(n, k) end

	if o.Flag then ChaseUI.Flags[o.Flag] = api end
	return api
end

-- ---- ColorPicker (HSV, inline expand) ----
function Build.ColorPicker(parent, o)
	o = o or {}
	if o.Default == nil then o.Default = o.CurrentValue end
	local T = ChaseUI.Theme
	local f = elementFrame(parent, 40)
	f.ClipsDescendants = true
	local header = Create("TextButton", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Text = "", Parent = f})
	local lbl = mkLabel(f, o.Name or o.Title or "Color", 13, T.Text, false)
	lbl.Position = UDim2.new(0, 12, 0, 0); lbl.Size = UDim2.new(1, -70, 0, 40)
	Themed(lbl, "TextColor3", "Text")
	local swatch = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, 20),
		Size = UDim2.fromOffset(34, 20), BackgroundColor3 = o.Default or Color3.fromRGB(255, 255, 255), Parent = f,
	}, { Corner(5) })
	Stroke(swatch, T.ElementBorder, 1, 0)

	local PANEL = 128
	-- Saturation/Value square: hue-coloured base + white (left) + black (bottom) overlays.
	local sv = Create("Frame", {
		Position = UDim2.new(0, 12, 0, 46), Size = UDim2.fromOffset(PANEL, PANEL),
		BackgroundColor3 = Color3.fromRGB(255, 0, 0), BorderSizePixel = 0, Parent = f,
	}, { Corner(5) })
	local satLayer = Create("Frame", {BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Size = UDim2.fromScale(1,1), Parent = sv}, {Corner(5)})
	Create("UIGradient", {Color = ColorSequence.new(Color3.new(1,1,1)),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)}), Parent = satLayer})
	local valLayer = Create("Frame", {BackgroundColor3 = Color3.new(0,0,0), BorderSizePixel = 0, Size = UDim2.fromScale(1,1), Parent = sv}, {Corner(5)})
	Create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.new(0,0,0)),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0)}), Parent = valLayer})
	local svCursor = Create("Frame", {AnchorPoint = Vector2.new(0.5,0.5), Size = UDim2.fromOffset(10,10),
		BackgroundColor3 = Color3.new(1,1,1), ZIndex = 5, Parent = sv}, {Corner(5)})
	Stroke(svCursor, Color3.new(0,0,0), 1, 0.2)

	local hue = Create("Frame", {Position = UDim2.new(0, 12 + PANEL + 10, 0, 46), Size = UDim2.fromOffset(16, PANEL),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = f}, {Corner(5)})
	Create("UIGradient", {Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,0,0)), ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255,255,0)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0,255,0)), ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0,255,255)),
		ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0,0,255)), ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255,0,255)),
		ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255,0,0))}), Parent = hue})
	local hueCursor = Create("Frame", {AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.new(0.5,0,0,0),
		Size = UDim2.new(1,4,0,4), BackgroundColor3 = Color3.new(1,1,1), Parent = hue}, {Corner(2)})
	Stroke(hueCursor, Color3.new(0,0,0), 1, 0.2)
	-- CHUNK_CP
	local callback = o.Callback or function() end
	local open = false
	local api = {Instance = f, Type = "ColorPicker"}
	local h, s, v = 0, 1, 1
	do
		local d = o.Default or Color3.fromRGB(255, 0, 0)
		h, s, v = Color3.toHSV(d)
	end

	local function update(skipCb)
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.new(math.clamp(s, 0, 1), 0, 1 - math.clamp(v, 0, 1), 0)
		hueCursor.Position = UDim2.new(0.5, 0, math.clamp(h, 0, 1), 0)
		local col = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = col
		svCursor.BackgroundColor3 = col
		api.Value = col
		if not skipCb then task.spawn(function() local ok, e = pcall(callback, col) if not ok then warn("[ChaseUI] ColorPicker error: " .. tostring(e)) end end) end
	end

	local function setHeight()
		Tween(f, QUICK, {Size = UDim2.new(1, 0, 0, open and (46 + PANEL + 10) or 40)})
	end
	header.MouseButton1Click:Connect(function() open = not open; setHeight() end)

	local dragSV, dragHue = false, false
	local cpMoveConn
	local function updSV(px, py)
		s = math.clamp((px - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
		v = 1 - math.clamp((py - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
		update()
	end
	local function updHue(py)
		h = math.clamp((py - hue.AbsolutePosition.Y) / math.max(hue.AbsoluteSize.Y, 1), 0, 1)
		update()
	end
	local function ensureMove()
		if cpMoveConn then return end
		cpMoveConn = UserInputService.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
				if dragSV then updSV(i.Position.X, i.Position.Y) end
				if dragHue then updHue(i.Position.Y) end
			end
		end)
	end
	local function maybeStopMove()
		if not dragSV and not dragHue then
			if cpMoveConn then cpMoveConn:Disconnect(); cpMoveConn = nil end
			setAncestorScroll(f, true)
		end
	end
	sv.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragSV = true; setAncestorScroll(f, false); ensureMove(); updSV(i.Position.X, i.Position.Y) end end)
	sv.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragSV = false; maybeStopMove() end end)
	hue.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragHue = true; setAncestorScroll(f, false); ensureMove(); updHue(i.Position.Y) end end)
	hue.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragHue = false; maybeStopMove() end end)
	f.Destroying:Connect(function() if cpMoveConn then cpMoveConn:Disconnect(); cpMoveConn = nil end end)

	function api:Set(col, skipCb) if typeof(col) == "Color3" then h, s, v = Color3.toHSV(col); update(skipCb) end end
	function api:Get() return api.Value end
	update(true)

	if o.Flag then ChaseUI.Flags[o.Flag] = api end
	return api
end

-- // ========================= Library-level API ========================= //
function ChaseUI:GetFlag(flag)
	local api = self.Flags[flag]
	return api and api.Value or nil
end

function ChaseUI:SetFlag(flag, value)
	local api = self.Flags[flag]
	if api and api.Set then api:Set(value) end
end

-- Tear down everything ChaseUI created (all windows + notifications).
function ChaseUI:Destroy()
	for _, w in ipairs(table.clone(self.Windows)) do pcall(function() w:Destroy() end) end
	if notifRoot then pcall(function() notifRoot:Destroy() end) notifRoot = nil end
	for _, c in ipairs(self._connections) do pcall(function() c:Disconnect() end) end
	table.clear(self._connections)
	table.clear(self.Flags)
	table.clear(self._themed)
end
ChaseUI.Unload = ChaseUI.Destroy

-- Guard against the script being injected twice (common on executors).
if getgenv then
	local prev = getgenv().ChaseUI
	if prev and prev.Destroy then pcall(function() prev:Destroy() end) end
	getgenv().ChaseUI = ChaseUI
end

return ChaseUI
