--[[
    Lumen UI Library  v1.0.0
    A single-file, dependency-free Roblox UI library. No ModuleScript needed.

    Usage (executor / loadstring):
        local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOU/REPO/main/Lumen.lua"))()

    Usage (Studio LocalScript): paste this whole file at the top of your LocalScript
    and delete the final `return Lumen` line. The library is then available as `Lumen`
    (and as `_G.Lumen` for other scripts).

    See DOCS.md for the full API.
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local genv = (getgenv and getgenv()) or _G
if genv.Lumen and type(genv.Lumen) == "table" and genv.Lumen.Destroy then
	pcall(function() genv.Lumen:Destroy() end)
end

----------------------------------------------------------------------
-- Core
----------------------------------------------------------------------
local Lumen = {
	Version = "1.0.0",
	Flags = {},
	Windows = {},
	_setters = {},
	_themed = {},
	_refreshers = {},
	_conns = {},
}

local Themes = {
	Dark = {
		Background = Color3.fromRGB(22, 22, 27), Topbar = Color3.fromRGB(28, 28, 34),
		Sidebar = Color3.fromRGB(26, 26, 31), Element = Color3.fromRGB(37, 37, 45),
		ElementHover = Color3.fromRGB(48, 48, 58), Accent = Color3.fromRGB(88, 130, 255),
		Text = Color3.fromRGB(240, 240, 245), SubText = Color3.fromRGB(165, 165, 178),
		Stroke = Color3.fromRGB(58, 58, 70),
	},
	Light = {
		Background = Color3.fromRGB(240, 241, 245), Topbar = Color3.fromRGB(228, 230, 236),
		Sidebar = Color3.fromRGB(232, 234, 240), Element = Color3.fromRGB(252, 252, 254),
		ElementHover = Color3.fromRGB(236, 238, 245), Accent = Color3.fromRGB(60, 105, 235),
		Text = Color3.fromRGB(28, 28, 36), SubText = Color3.fromRGB(100, 104, 118),
		Stroke = Color3.fromRGB(205, 208, 218),
	},
	Ocean = {
		Background = Color3.fromRGB(14, 25, 38), Topbar = Color3.fromRGB(18, 33, 50),
		Sidebar = Color3.fromRGB(16, 29, 44), Element = Color3.fromRGB(24, 44, 66),
		ElementHover = Color3.fromRGB(32, 57, 84), Accent = Color3.fromRGB(0, 200, 170),
		Text = Color3.fromRGB(232, 245, 250), SubText = Color3.fromRGB(150, 180, 195),
		Stroke = Color3.fromRGB(44, 78, 108),
	},
	Rose = {
		Background = Color3.fromRGB(28, 20, 26), Topbar = Color3.fromRGB(36, 25, 33),
		Sidebar = Color3.fromRGB(32, 23, 30), Element = Color3.fromRGB(46, 33, 42),
		ElementHover = Color3.fromRGB(60, 43, 55), Accent = Color3.fromRGB(240, 90, 140),
		Text = Color3.fromRGB(250, 238, 244), SubText = Color3.fromRGB(190, 160, 175),
		Stroke = Color3.fromRGB(78, 56, 70),
	},
}
Lumen.Themes = Themes
Lumen.Theme = Themes.Dark
Lumen.ThemeName = "Dark"

local NotifyColors = {
	Info = nil, -- uses accent
	Success = Color3.fromRGB(70, 200, 120),
	Warning = Color3.fromRGB(240, 180, 60),
	Error = Color3.fromRGB(235, 80, 80),
}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function New(class, props, children)
	local o = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else o[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = o end
	if parent then o.Parent = parent end
	return o
end

local function T(inst, prop, key) -- bind a property to a theme colour
	inst[prop] = Lumen.Theme[key]
	table.insert(Lumen._themed, { inst, prop, key })
	return inst
end

local function corner(o, r) return New("UICorner", { CornerRadius = UDim.new(0, r or 6), Parent = o }) end
local function pad(o, t, r, b, l)
	return New("UIPadding", {
		PaddingTop = UDim.new(0, t or 0), PaddingRight = UDim.new(0, r or 0),
		PaddingBottom = UDim.new(0, b or 0), PaddingLeft = UDim.new(0, l or 0), Parent = o,
	})
end
local function list(o, gap)
	return New("UIListLayout", { Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = o })
end
local function tween(o, t, props)
	local tw = TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function safe(cb, ...)
	if type(cb) ~= "function" then return end
	task.spawn(function(...)
		local ok, err = pcall(cb, ...)
		if not ok then warn("[Lumen] callback error: " .. tostring(err)) end
	end, ...)
end
local function connect(sig, fn)
	local c = sig:Connect(fn)
	table.insert(Lumen._conns, c)
	return c
end
local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end
local function isMove(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end
local function viewport()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

local function getParent()
	local ok, h = pcall(function() return gethui and gethui() end)
	if ok and h then return h end
	local test = Instance.new("ScreenGui")
	local ok2 = pcall(function() test.Parent = game:GetService("CoreGui") end)
	test:Destroy()
	if ok2 then return game:GetService("CoreGui") end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

function Lumen:_gui()
	if self._screen and self._screen.Parent then return self._screen end
	local gui = New("ScreenGui", {
		Name = "Lumen_" .. HttpService:GenerateGUID(false):sub(1, 8),
		ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
	gui.Parent = getParent()
	self._screen = gui

	local holder = New("Frame", {
		Name = "Notifications", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.new(0, math.min(290, viewport().X - 24), 1, -24), BackgroundTransparency = 1, ZIndex = 50, Parent = gui,
	})
	New("UIListLayout", {
		Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Top, Parent = holder,
	})
	self._notifs = holder
	return gui
end

----------------------------------------------------------------------
-- Theme / lifecycle / notifications / config
----------------------------------------------------------------------
function Lumen:SetTheme(name)
	local th = Themes[name]
	if not th then warn("[Lumen] Unknown theme: " .. tostring(name)); return end
	self.Theme, self.ThemeName = th, name
	local alive = {}
	for _, e in ipairs(self._themed) do
		if e[1].Parent ~= nil then
			e[1][e[2]] = th[e[3]]
			table.insert(alive, e)
		end
	end
	self._themed = alive
	for _, fn in ipairs(self._refreshers) do pcall(fn) end
end

function Lumen:Destroy()
	for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
	self._conns = {}
	if self._screen then self._screen:Destroy() end
	self._screen, self.Windows, self._themed, self._refreshers = nil, {}, {}, {}
end

function Lumen:Notify(o)
	o = o or {}
	self:_gui()
	local accent = NotifyColors[o.Type or "Info"]
	local w = self._notifs.AbsoluteSize.X > 0 and self._notifs.AbsoluteSize.X or 290
	local card = New("CanvasGroup", {
		Size = UDim2.new(0, w, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, GroupTransparency = 1, BorderSizePixel = 0,
		Parent = self._notifs,
	})
	T(card, "BackgroundColor3", "Element"); corner(card, 8)
	local st = New("UIStroke", { Thickness = 1.5, Parent = card })
	if accent then st.Color = accent else T(st, "Color", "Accent") end
	local body = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = card,
	})
	pad(body, 10, 12, 10, 12); list(body, 3)
	local title = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		Text = o.Title or "Notice", Parent = body,
	})
	T(title, "TextColor3", "Text")
	if o.Content and o.Content ~= "" then
		local c = New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
			Font = Enum.Font.Gotham, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			Text = o.Content, LayoutOrder = 2, Parent = body,
		})
		T(c, "TextColor3", "SubText")
	end
	local closed = false
	local function close()
		if closed then return end
		closed = true
		tween(card, 0.25, { GroupTransparency = 1 })
		task.delay(0.3, function() card:Destroy() end)
	end
	local hit = New("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = card })
	hit.MouseButton1Click:Connect(close)
	tween(card, 0.25, { GroupTransparency = 0 })
	task.delay(o.Duration or 4, close)
	return { Close = close }
end

local function encode(v)
	if typeof(v) == "Color3" then return { __t = "c", r = v.R, g = v.G, b = v.B } end
	if typeof(v) == "EnumItem" then return { __t = "k", n = v.Name } end
	return v
end
local function decode(v)
	if type(v) == "table" and v.__t == "c" then return Color3.new(v.r, v.g, v.b) end
	if type(v) == "table" and v.__t == "k" then return Enum.KeyCode[v.n] or Enum.KeyCode.Unknown end
	return v
end

function Lumen:SaveConfig(name)
	if not (writefile and makefolder and isfolder) then return false, "File functions not supported here" end
	if not isfolder("Lumen") then makefolder("Lumen") end
	local data = {}
	for k, v in pairs(self.Flags) do data[k] = encode(v) end
	local ok, err = pcall(writefile, "Lumen/" .. name .. ".json", HttpService:JSONEncode(data))
	return ok, err
end

function Lumen:LoadConfig(name)
	if not (readfile and isfile) then return false, "File functions not supported here" end
	local path = "Lumen/" .. name .. ".json"
	if not isfile(path) then return false, "Config not found" end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
	if not ok then return false, "Config is corrupted" end
	for k, v in pairs(data) do
		if self._setters[k] then pcall(self._setters[k], decode(v)) end
	end
	return true
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
function Lumen:CreateWindow(cfg)
	cfg = cfg or {}
	local gui = self:_gui()
	local vp = viewport()
	local W = math.min(cfg.Width or 560, vp.X - 24)
	local H = math.min(cfg.Height or 390, vp.Y - 24)
	local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
	if cfg.Theme and Themes[cfg.Theme] then self:SetTheme(cfg.Theme) end

	local Window = { Tabs = {}, Active = nil, Minimized = false }
	table.insert(self.Windows, Window)

	local main = New("Frame", {
		Name = "Window", Position = UDim2.fromOffset((vp.X - W) / 2, (vp.Y - H) / 2),
		Size = UDim2.fromOffset(W, H), BorderSizePixel = 0, ClipsDescendants = true, Parent = gui,
	})
	T(main, "BackgroundColor3", "Background"); corner(main, 10)
	T(New("UIStroke", { Thickness = 1, Parent = main }), "Color", "Stroke")

	-- top bar
	local top = New("Frame", { Size = UDim2.new(1, 0, 0, 40), BorderSizePixel = 0, Parent = main })
	T(top, "BackgroundColor3", "Topbar")
	local title = New("TextLabel", {
		Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.5, -14, 1, 0), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Text = cfg.Title or "Lumen", Parent = top,
	})
	T(title, "TextColor3", "Text")
	local sub = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -88, 0, 0), Size = UDim2.new(0.4, 0, 1, 0),
		BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd, Text = cfg.Subtitle or "", Parent = top,
	})
	T(sub, "TextColor3", "SubText")

	local function topButton(txt, xOff)
		local b = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOff, 0.5, 0), Size = UDim2.fromOffset(32, 28),
			BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16, Text = txt, AutoButtonColor = false, Parent = top,
		})
		T(b, "TextColor3", "SubText"); corner(b, 6)
		b.MouseEnter:Connect(function() tween(b, 0.12, { BackgroundTransparency = 0.85 }); b.BackgroundColor3 = Lumen.Theme.Text end)
		b.MouseLeave:Connect(function() tween(b, 0.12, { BackgroundTransparency = 1 }) end)
		return b
	end
	local closeBtn = topButton("✕", -8)
	local minBtn = topButton("–", -42)

	-- body
	local body = New("Frame", { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), BackgroundTransparency = 1, Parent = main })
	local sidebar = New("Frame", { Size = UDim2.new(0, 136, 1, 0), BorderSizePixel = 0, Parent = body })
	T(sidebar, "BackgroundColor3", "Sidebar")
	local tabList = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = sidebar,
	})
	pad(tabList, 8, 8, 8, 8); list(tabList, 4)
	local content = New("Frame", { Position = UDim2.fromOffset(136, 0), Size = UDim2.new(1, -136, 1, 0), BackgroundTransparency = 1, Parent = body })

	-- dragging
	do
		local dragging, sm, sp
		top.InputBegan:Connect(function(i)
			if isPress(i) then dragging, sm, sp = true, Vector2.new(i.Position.X, i.Position.Y), main.Position end
		end)
		connect(UIS.InputChanged, function(i)
			if dragging and isMove(i) then
				local d = Vector2.new(i.Position.X, i.Position.Y) - sm
				local v = viewport()
				local x = math.clamp(sp.X.Offset + d.X, -main.AbsoluteSize.X + 80, v.X - 80)
				local y = math.clamp(sp.Y.Offset + d.Y, 0, v.Y - 40)
				main.Position = UDim2.fromOffset(x, y)
			end
		end)
		connect(UIS.InputEnded, function(i) if isPress(i) then dragging = false end end)
	end

	-- resizing
	local grip = New("TextButton", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1,
		Text = "◢", Font = Enum.Font.Gotham, TextSize = 12, AutoButtonColor = false, ZIndex = 20, Parent = body,
	})
	T(grip, "TextColor3", "SubText")
	do
		local rs, sm, ss
		grip.InputBegan:Connect(function(i)
			if isPress(i) then rs, sm, ss = true, Vector2.new(i.Position.X, i.Position.Y), main.AbsoluteSize end
		end)
		connect(UIS.InputChanged, function(i)
			if rs and isMove(i) then
				local d = Vector2.new(i.Position.X, i.Position.Y) - sm
				main.Size = UDim2.fromOffset(math.max(420, ss.X + d.X), math.max(280, ss.Y + d.Y))
			end
		end)
		connect(UIS.InputEnded, function(i) if isPress(i) then rs = false end end)
	end

	-- show / hide / minimise
	local mobileBtn
	function Window:Show() main.Visible = true end
	function Window:Hide() main.Visible = false end
	function Window:Toggle() main.Visible = not main.Visible end
	function Window:SetTitle(t) title.Text = t end
	function Window:Destroy()
		main:Destroy()
		if mobileBtn then mobileBtn:Destroy() end
	end
	local fullHeight = H
	function Window:Minimize()
		self.Minimized = not self.Minimized
		if self.Minimized then
			fullHeight = main.AbsoluteSize.Y
			body.Visible = false
			tween(main, 0.2, { Size = UDim2.fromOffset(main.AbsoluteSize.X, 40) })
			minBtn.Text = "+"
		else
			tween(main, 0.2, { Size = UDim2.fromOffset(main.AbsoluteSize.X, fullHeight) })
			task.delay(0.15, function() body.Visible = true end)
			minBtn.Text = "–"
		end
	end
	minBtn.MouseButton1Click:Connect(function() Window:Minimize() end)

	local hint = UIS.TouchEnabled and not UIS.KeyboardEnabled and "tap the ☰ button" or ("press " .. toggleKey.Name)
	closeBtn.MouseButton1Click:Connect(function()
		Window:Hide()
		Lumen:Notify({ Title = "Menu hidden", Content = "To reopen, " .. hint .. ".", Duration = 3 })
	end)
	connect(UIS.InputBegan, function(i, gp)
		if not gp and i.KeyCode == toggleKey then Window:Toggle() end
	end)

	if UIS.TouchEnabled then
		mobileBtn = New("TextButton", {
			Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(46, 46), Text = "☰", Font = Enum.Font.GothamBold,
			TextSize = 22, AutoButtonColor = false, ZIndex = 60, Parent = gui,
		})
		T(mobileBtn, "BackgroundColor3", "Accent"); mobileBtn.TextColor3 = Color3.new(1, 1, 1); corner(mobileBtn, 23)
		mobileBtn.MouseButton1Click:Connect(function() Window:Toggle() end)
	end

	if cfg.Intro ~= false then
		self:Notify({ Title = cfg.Title or "Lumen", Content = "Loaded. " .. (hint:gsub("^%l", string.upper)) .. " to hide or show the menu.", Duration = 4 })
	end

	------------------------------------------------------------------
	-- Tabs
	------------------------------------------------------------------
	function Window:SelectTab(tab)
		for _, t in ipairs(self.Tabs) do
			t.Page.Visible = (t == tab)
			t._render()
		end
		self.Active = tab
	end

	function Window:AddTab(o)
		o = type(o) == "string" and { Name = o } or (o or {})
		local Tab = { Window = self }

		local btn = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, AutoButtonColor = false, Font = Enum.Font.GothamMedium,
			TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			Text = (o.Icon and (o.Icon .. "  ") or "") .. (o.Name or "Tab"), Parent = tabList,
		})
		pad(btn, 0, 6, 0, 14); corner(btn, 6)
		local bar = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -10, 0.5, 0), Size = UDim2.fromOffset(3, 16),
			BorderSizePixel = 0, Visible = false, Parent = btn,
		})
		T(bar, "BackgroundColor3", "Accent"); corner(bar, 2)

		local page = New("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = content,
		})
		T(page, "ScrollBarImageColor3", "Accent")
		pad(page, 10, 12, 12, 10); list(page, 6)
		Tab.Page = page

		Tab._render = function()
			local active = Window.Active == Tab
			btn.BackgroundTransparency = active and 0 or 1
			btn.BackgroundColor3 = Lumen.Theme.Element
			btn.TextColor3 = active and Lumen.Theme.Text or Lumen.Theme.SubText
			bar.Visible = active
		end
		table.insert(Lumen._refreshers, Tab._render)
		btn.MouseButton1Click:Connect(function() Window:SelectTab(Tab) end)
		btn.MouseEnter:Connect(function() if Window.Active ~= Tab then btn.TextColor3 = Lumen.Theme.Text end end)
		btn.MouseLeave:Connect(function() Tab._render() end)

		table.insert(self.Tabs, Tab)
		if not self.Active then self:SelectTab(Tab) else Tab._render() end

		--------------------------------------------------------------
		-- Row helper
		--------------------------------------------------------------
		local function makeRow(opts, rightPad)
			local hasDesc = opts.Description ~= nil and opts.Description ~= ""
			local row = New("TextButton", {
				Size = UDim2.new(1, 0, 0, hasDesc and 54 or 40), AutoButtonColor = false, Text = "", BorderSizePixel = 0,
				ClipsDescendants = true, Parent = page,
			})
			T(row, "BackgroundColor3", "Element"); corner(row, 6)
			local name = New("TextLabel", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(12, hasDesc and 8 or 0),
				Size = UDim2.new(1, -(rightPad or 24) - 12, 0, hasDesc and 18 or 40), Font = Enum.Font.GothamMedium,
				TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
				Text = opts.Name or "", Parent = row,
			})
			T(name, "TextColor3", "Text")
			if hasDesc then
				local d = New("TextLabel", {
					BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -(rightPad or 24) - 12, 0, 16),
					Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd, Text = opts.Description, Parent = row,
				})
				T(d, "TextColor3", "SubText")
			end
			row.MouseEnter:Connect(function() tween(row, 0.12, { BackgroundColor3 = Lumen.Theme.ElementHover }) end)
			row.MouseLeave:Connect(function() tween(row, 0.12, { BackgroundColor3 = Lumen.Theme.Element }) end)
			return row, name
		end

		local function expandable(opts)
			local c = New("Frame", { Size = UDim2.new(1, 0, 0, 40), ClipsDescendants = true, BorderSizePixel = 0, Parent = page })
			T(c, "BackgroundColor3", "Element"); corner(c, 6)
			local header = New("TextButton", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = c })
			local name = New("TextLabel", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.5, -12, 1, 0),
				Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd, Text = opts.Name or "", Parent = header,
			})
			T(name, "TextColor3", "Text")
			return c, header
		end

		local function register(opts, obj)
			if opts.Flag then Lumen._setters[opts.Flag] = function(v) obj:Set(v) end end
		end
		local function commit(opts, v, silent)
			if opts.Flag then Lumen.Flags[opts.Flag] = v end
			if not silent then safe(opts.Callback, v) end
		end

		--------------------------------------------------------------
		-- Elements
		--------------------------------------------------------------
		function Tab:AddSection(text)
			local l = New("TextLabel", {
				Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom,
				Text = string.upper(text or "Section"), Parent = page,
			})
			T(l, "TextColor3", "Accent"); pad(l, 0, 0, 2, 4)
			return { SetText = function(_, t) l.Text = string.upper(t) end, Destroy = function() l:Destroy() end }
		end

		function Tab:AddDivider()
			local d = New("Frame", { Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, Parent = page })
			T(d, "BackgroundColor3", "Stroke")
			return { Destroy = function() d:Destroy() end }
		end

		function Tab:AddLabel(text)
			local f = New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Parent = page })
			T(f, "BackgroundColor3", "Element"); corner(f, 6); pad(f, 10, 12, 10, 12)
			local l = New("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Font = Enum.Font.Gotham,
				TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Text = text or "", Parent = f,
			})
			T(l, "TextColor3", "SubText")
			return { SetText = function(_, t) l.Text = t end, Destroy = function() f:Destroy() end }
		end

		function Tab:AddParagraph(titleText, bodyText)
			local f = New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Parent = page })
			T(f, "BackgroundColor3", "Element"); corner(f, 6); pad(f, 10, 12, 10, 12); list(f, 4)
			local a = New("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
				TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Text = titleText or "", Parent = f,
			})
			T(a, "TextColor3", "Text")
			local b = New("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Font = Enum.Font.Gotham,
				TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Text = bodyText or "", LayoutOrder = 2, Parent = f,
			})
			T(b, "TextColor3", "SubText")
			return {
				SetTitle = function(_, t) a.Text = t end, SetContent = function(_, t) b.Text = t end,
				Destroy = function() f:Destroy() end,
			}
		end

		function Tab:AddButton(o)
			o = o or {}
			local row, name = makeRow(o, 40)
			local arrow = New("TextLabel", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(20, 20),
				BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16, Text = "›", Parent = row,
			})
			T(arrow, "TextColor3", "Accent")
			local obj = {}
			row.MouseButton1Click:Connect(function()
				row.BackgroundColor3 = Lumen.Theme.Accent
				tween(row, 0.35, { BackgroundColor3 = Lumen.Theme.Element })
				safe(o.Callback)
			end)
			function obj:SetText(t) name.Text = t end
			function obj:Destroy() row:Destroy() end
			return obj
		end

		function Tab:AddToggle(o)
			o = o or {}
			local row = makeRow(o, 56)
			local sw = New("Frame", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(40, 22),
				BorderSizePixel = 0, Parent = row,
			})
			corner(sw, 11)
			local knob = New("Frame", {
				AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(16, 16),
				BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = sw,
			})
			corner(knob, 8)
			local state = false
			local obj = {}
			local function render(anim)
				local col = state and Lumen.Theme.Accent or Lumen.Theme.Stroke
				local pos = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
				if anim then tween(sw, 0.15, { BackgroundColor3 = col }); tween(knob, 0.15, { Position = pos })
				else sw.BackgroundColor3 = col; knob.Position = pos end
			end
			table.insert(Lumen._refreshers, function() render(false) end)
			function obj:Set(v, silent)
				state = v and true or false
				render(true); commit(o, state, silent)
			end
			function obj:Get() return state end
			function obj:Destroy() row:Destroy() end
			row.MouseButton1Click:Connect(function() obj:Set(not state) end)
			state = o.Default and true or false
			render(false)
			if o.Flag then Lumen.Flags[o.Flag] = state end
			register(o, obj)
			task.defer(function() if o.Default ~= nil then safe(o.Callback, state) end end)
			return obj
		end

		function Tab:AddSlider(o)
			o = o or {}
			local min, max, inc = o.Min or 0, o.Max or 100, o.Increment or 1
			if max <= min then max = min + 1 end
			if inc <= 0 then inc = 1 end
			local suffix = o.Suffix or ""
			local decimals = 0
			local d = tostring(inc):match("%.(%d+)")
			if d then decimals = #d end
			local function snap(v)
				v = math.clamp(v, min, max)
				v = math.floor((v - min) / inc + 0.5) * inc + min
				return math.clamp(tonumber(string.format("%." .. decimals .. "f", v)), min, max)
			end

			local row = New("Frame", { Size = UDim2.new(1, 0, 0, 56), BorderSizePixel = 0, Parent = page })
			T(row, "BackgroundColor3", "Element"); corner(row, 6)
			local name = New("TextLabel", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -110, 0, 20),
				Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd, Text = o.Name or "Slider", Parent = row,
			})
			T(name, "TextColor3", "Text")
			local val = New("TextLabel", {
				AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Position = UDim2.new(1, -12, 0, 6),
				Size = UDim2.fromOffset(90, 20), Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
			})
			T(val, "TextColor3", "SubText")
			local hit = New("TextButton", {
				Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 24), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = row,
			})
			local track = New("Frame", {
				AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 6), BorderSizePixel = 0, Parent = hit,
			})
			T(track, "BackgroundColor3", "Stroke"); corner(track, 3)
			local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = track })
			T(fill, "BackgroundColor3", "Accent"); corner(fill, 3)
			local knob = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(14, 14),
				BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2, Parent = track,
			})
			corner(knob, 7)

			local value = snap(o.Default or min)
			local obj = {}
			local function render()
				local a = (value - min) / (max - min)
				fill.Size = UDim2.fromScale(a, 1)
				knob.Position = UDim2.fromScale(a, 0.5)
				val.Text = tostring(value) .. suffix
			end
			function obj:Set(v, silent)
				local nv = snap(tonumber(v) or value)
				local changed = nv ~= value
				value = nv; render()
				if changed or not silent then commit(o, value, silent) end
			end
			function obj:Get() return value end
			function obj:Destroy() row:Destroy() end

			local dragging = false
			local function fromX(x)
				local w = hit.AbsoluteSize.X
				if w <= 0 then return end
				obj:Set(min + (max - min) * math.clamp((x - hit.AbsolutePosition.X) / w, 0, 1))
			end
			hit.InputBegan:Connect(function(i)
				if isPress(i) then
					dragging = true; page.ScrollingEnabled = false
					fromX(i.Position.X)
				end
			end)
			connect(UIS.InputChanged, function(i) if dragging and isMove(i) then fromX(i.Position.X) end end)
			connect(UIS.InputEnded, function(i)
				if dragging and isPress(i) then dragging = false; page.ScrollingEnabled = true end
			end)

			render()
			if o.Flag then Lumen.Flags[o.Flag] = value end
			register(o, obj)
			task.defer(function() if o.Default ~= nil then safe(o.Callback, value) end end)
			return obj
		end

		function Tab:AddDropdown(o)
			o = o or {}
			local options = o.Options or {}
			local multi = o.Multi == true
			local selected, single = {}, nil
			local open = false
			local obj = {}
			local c, header = expandable(o)
			local current = New("TextLabel", {
				BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -34, 1, 0), Font = Enum.Font.Gotham,
				TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Parent = header,
			})
			T(current, "TextColor3", "SubText")
			local arrow = New("TextLabel", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(18, 18),
				BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12, Text = "▼", Parent = header,
			})
			T(arrow, "TextColor3", "Accent")
			local lst = New("ScrollingFrame", {
				Position = UDim2.fromOffset(6, 44), Size = UDim2.new(1, -12, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
				ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = c,
			})
			T(lst, "ScrollBarImageColor3", "Accent"); list(lst, 2)
			local buttons = {}

			local function display()
				if multi then
					local names = {}
					for _, op in ipairs(options) do if selected[op] then table.insert(names, op) end end
					current.Text = #names > 0 and table.concat(names, ", ") or (o.Placeholder or "Select…")
				else
					current.Text = single or (o.Placeholder or "Select…")
				end
			end
			local function value()
				if multi then
					local r = {}
					for _, op in ipairs(options) do if selected[op] then table.insert(r, op) end end
					return r
				end
				return single
			end
			local function paint()
				for op, b in pairs(buttons) do
					local on = multi and selected[op] or (not multi and single == op)
					b.BackgroundColor3 = on and Lumen.Theme.Accent or Lumen.Theme.ElementHover
					b.TextColor3 = on and Color3.new(1, 1, 1) or Lumen.Theme.Text
				end
				display()
			end
			table.insert(Lumen._refreshers, paint)

			local function listHeight() return math.min(#options, 6) * 28 end
			local function setOpen(v)
				open = v
				tween(c, 0.18, { Size = UDim2.new(1, 0, 0, v and (50 + listHeight()) or 40) })
				lst.Size = UDim2.new(1, -12, 0, listHeight())
				tween(arrow, 0.18, { Rotation = v and 180 or 0 })
			end

			local function build()
				for _, b in pairs(buttons) do b:Destroy() end
				buttons = {}
				for idx, op in ipairs(options) do
					local b = New("TextButton", {
						Size = UDim2.new(1, -4, 0, 26), BorderSizePixel = 0, AutoButtonColor = false, Font = Enum.Font.Gotham,
						TextSize = 13, Text = tostring(op), LayoutOrder = idx, Parent = lst,
					})
					corner(b, 5)
					buttons[op] = b
					b.MouseButton1Click:Connect(function()
						if multi then selected[op] = not selected[op] or nil
						else single = op; setOpen(false) end
						paint(); commit(o, value())
					end)
				end
				paint()
				if open then setOpen(true) end
			end

			function obj:Set(v, silent)
				if multi then
					selected = {}
					for _, x in ipairs(type(v) == "table" and v or { v }) do selected[x] = true end
				else
					single = v
				end
				paint(); commit(o, value(), silent)
			end
			function obj:Get() return value() end
			function obj:Refresh(newOptions, keep)
				options = newOptions or {}
				if not keep then selected, single = {}, nil
				else
					for k in pairs(selected) do if not table.find(options, k) then selected[k] = nil end end
					if single and not table.find(options, single) then single = nil end
				end
				build(); commit(o, value(), true)
			end
			function obj:Open() setOpen(true) end
			function obj:Close() setOpen(false) end
			function obj:Destroy() c:Destroy() end
			header.MouseButton1Click:Connect(function() setOpen(not open) end)

			if multi then for _, x in ipairs(type(o.Default) == "table" and o.Default or {}) do selected[x] = true end
			else single = o.Default end
			build()
			if o.Flag then Lumen.Flags[o.Flag] = value() end
			register(o, obj)
			task.defer(function() if o.Default ~= nil then safe(o.Callback, value()) end end)
			return obj
		end

		function Tab:AddTextbox(o)
			o = o or {}
			local row = makeRow(o, 160)
			local box = New("TextBox", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(142, 26), BorderSizePixel = 0,
				Font = Enum.Font.Gotham, TextSize = 13, Text = tostring(o.Default or ""), PlaceholderText = o.Placeholder or "Type here…",
				ClearTextOnFocus = o.ClearOnFocus == true, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
			})
			T(box, "BackgroundColor3", "Background"); T(box, "TextColor3", "Text"); T(box, "PlaceholderColor3", "SubText")
			corner(box, 5); pad(box, 0, 6, 0, 6)
			local st = New("UIStroke", { Thickness = 1, Transparency = 1, Parent = box })
			T(st, "Color", "Accent")
			box.Focused:Connect(function() tween(st, 0.12, { Transparency = 0 }) end)
			local obj = {}
			local function out() return o.Numeric and (tonumber(box.Text) or 0) or box.Text end
			box.FocusLost:Connect(function(enter)
				tween(st, 0.12, { Transparency = 1 })
				if o.Numeric then
					local n = tonumber(box.Text)
					if n == nil then box.Text = "0" end
				end
				if o.OnlyOnEnter and not enter then return end
				commit(o, out())
			end)
			row.MouseButton1Click:Connect(function() box:CaptureFocus() end)
			function obj:Set(v, silent) box.Text = tostring(v); commit(o, out(), silent) end
			function obj:Get() return out() end
			function obj:Destroy() row:Destroy() end
			if o.Flag then Lumen.Flags[o.Flag] = out() end
			register(o, obj)
			return obj
		end

		function Tab:AddKeybind(o)
			o = o or {}
			local row = makeRow(o, 110)
			local btn = New("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(92, 26), BorderSizePixel = 0,
				Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = false, Parent = row,
			})
			T(btn, "BackgroundColor3", "Background"); T(btn, "TextColor3", "Text"); corner(btn, 5)
			local key = o.Default or Enum.KeyCode.Unknown
			local listening = false
			local obj = {}
			local function render()
				btn.Text = listening and "Press a key…" or (key == Enum.KeyCode.Unknown and "None" or key.Name)
			end
			function obj:Set(k, silent)
				if type(k) == "string" then k = Enum.KeyCode[k] or Enum.KeyCode.Unknown end
				key = k or Enum.KeyCode.Unknown
				listening = false; render()
				if o.Flag then Lumen.Flags[o.Flag] = key end
				if not silent and o.OnChanged then safe(o.OnChanged, key) end
			end
			function obj:Get() return key end
			function obj:Destroy() row:Destroy() end
			local function startListen()
				listening = true; render()
			end
			btn.MouseButton1Click:Connect(startListen)
			row.MouseButton1Click:Connect(startListen)
			connect(UIS.InputBegan, function(i, gp)
				if listening then
					if i.UserInputType == Enum.UserInputType.Keyboard then
						if i.KeyCode == Enum.KeyCode.Escape then listening = false; render()
						elseif i.KeyCode == Enum.KeyCode.Backspace then obj:Set(Enum.KeyCode.Unknown)
						else obj:Set(i.KeyCode) end
					end
					return
				end
				if not gp and key ~= Enum.KeyCode.Unknown and i.KeyCode == key then safe(o.Callback, key) end
			end)
			render()
			if o.Flag then Lumen.Flags[o.Flag] = key end
			register(o, obj)
			return obj
		end

		function Tab:AddColorPicker(o)
			o = o or {}
			local color = o.Default or Color3.fromRGB(255, 255, 255)
			local h, s, v = color:ToHSV()
			local open = false
			local obj = {}
			local c, header = expandable(o)
			local prev = New("Frame", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(34, 20), BorderSizePixel = 0, Parent = header,
			})
			corner(prev, 5)
			T(New("UIStroke", { Thickness = 1, Parent = prev }), "Color", "Stroke")

			local panel = New("Frame", { Position = UDim2.fromOffset(8, 46), Size = UDim2.new(1, -16, 0, 110), BackgroundTransparency = 1, Parent = c })
			local sv = New("Frame", { Size = UDim2.new(1, -32, 1, 0), BorderSizePixel = 0, Parent = panel })
			corner(sv, 5)
			local white = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = sv })
			corner(white, 5)
			New("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
			local black = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = sv })
			corner(black, 5)
			New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black })
			local svCur = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 3, Parent = sv,
			})
			corner(svCur, 6)
			New("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Parent = svCur })

			local hue = New("Frame", {
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 22, 1, 0), BorderSizePixel = 0,
				BackgroundColor3 = Color3.new(1, 1, 1), Parent = panel,
			})
			corner(hue, 5)
			New("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)), ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
					ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)), ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
					ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)), ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
				}),
				Parent = hue,
			})
			local hueCur = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 4, 0, 4), BorderSizePixel = 0,
				BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = hue,
			})
			corner(hueCur, 2)
			New("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Parent = hueCur })

			local function render(silent, fire)
				color = Color3.fromHSV(h, s, v)
				prev.BackgroundColor3 = color
				sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
				svCur.Position = UDim2.fromScale(s, 1 - v)
				hueCur.Position = UDim2.fromScale(0.5, h)
				if fire then commit(o, color, silent) end
			end
			function obj:Set(col, silent)
				if typeof(col) ~= "Color3" then return end
				h, s, v = col:ToHSV(); render(silent, true)
			end
			function obj:Get() return color end
			function obj:Destroy() c:Destroy() end

			local mode
			local function update(i)
				if mode == "sv" then
					s = math.clamp((i.Position.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
					v = 1 - math.clamp((i.Position.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
				elseif mode == "hue" then
					h = math.clamp((i.Position.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 1)
				else return end
				render(false, true)
			end
			sv.InputBegan:Connect(function(i) if isPress(i) then mode = "sv"; page.ScrollingEnabled = false; update(i) end end)
			hue.InputBegan:Connect(function(i) if isPress(i) then mode = "hue"; page.ScrollingEnabled = false; update(i) end end)
			connect(UIS.InputChanged, function(i) if mode and isMove(i) then update(i) end end)
			connect(UIS.InputEnded, function(i) if mode and isPress(i) then mode = nil; page.ScrollingEnabled = true end end)

			header.MouseButton1Click:Connect(function()
				open = not open
				tween(c, 0.18, { Size = UDim2.new(1, 0, 0, open and 166 or 40) })
			end)
			render(true, false)
			if o.Flag then Lumen.Flags[o.Flag] = color end
			register(o, obj)
			task.defer(function() if o.Default ~= nil then safe(o.Callback, color) end end)
			return obj
		end

		return Tab
	end

	return Window
end

genv.Lumen = Lumen
return Lumen
