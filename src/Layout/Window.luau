--!nonstrict
--[[
	Vantage 1.0.0 · Layout/Window
	------------------------------------------------------------------
	The shell everything else lives inside.

	Deliberate choices worth knowing about:

	· No logo anywhere in the interface. The wordmark in the title bar is
	  text, and Vantage's mark is reserved for the loading screen where it
	  belongs. A UI library that stamps its logo on your product is a UI
	  library you cannot ship.
	· The window is dragged from the title bar and resized from the
	  bottom-right corner, both with pointer capture, so a drag that
	  leaves the window still tracks. Position is clamped to the viewport
	  on every frame, including during resize.
	· A UI scale is applied to the whole tree rather than per-component,
	  so a 4K display gets proportionally sensible text without every
	  component needing to know the viewport exists.
	· Mobile gets a full-bleed layout with a bottom navigation bar
	  instead of a squeezed desktop window.
	· The status bar reports live FPS, ping, memory and the number of
	  running animations — the instrumentation you want when a UI starts
	  to feel heavy, without opening a profiler.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)
local Config = require(script.Parent.Parent.Core.Config)
local Signal = require(script.Parent.Parent.Core.Signal)
local Maid = require(script.Parent.Parent.Core.Maid)
local Glyph = require(script.Parent.Parent.Core.Glyph)
local Elements = require(script.Parent.Elements)
local Tab = require(script.Parent.Tab)

local Window = {}
Window.__index = Window

local TITLE_HEIGHT = 40
local STATUS_HEIGHT = 24
local SIDEBAR_WIDTH = 168

--- Resolves the container a window should mount into.
local function resolveParent(explicit: any): any
	if explicit then
		return explicit
	end
	local ok, playerGui = pcall(function()
		local players = game:GetService("Players")
		return players.LocalPlayer and players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	end)
	if ok and playerGui then
		return playerGui
	end
	local ok2, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok2 and coreGui then
		return coreGui
	end
	-- Headless / test environment: a detached container still works.
	return nil
end

--- Public spec keys are capitalised — that is what the documentation, the
--- quick-start and every other library use — while the internal config
--- table is camel-case. The aliases below fold one into the other, so
--- `Name = "My Game"` and `name = "My Game"` both do the same thing.
local SPEC_ALIASES = {
	Name = "name",
	Subtitle = "subtitle",
	Theme = "theme",
	Size = "size",
	Position = "position",
	Anchor = "anchor",
	MinSize = "minSize",
	MaxSize = "maxSize",
	Resizable = "resizable",
	Draggable = "draggable",
	Sidebar = "sidebar",
	SidebarWidth = "sidebarWidth",
	StatusBar = "statusBar",
	StatusBarHeight = "statusBarHeight",
	TitleBarHeight = "titleBarHeight",
	ToggleKey = "toggleKey",
	CloseKey = "closeKey",
	UIScale = "uiScale",
	Scale = "uiScale",
	Version = "version",
}

--- Returns a copy of `spec` in which every capitalised alias has been
--- written to its canonical key. Existing canonical keys win, so passing
--- both forms is harmless.
local function canonicalSpec(spec: { [any]: any }): { [any]: any }
	local out = table.clone(spec)
	for public, internal in pairs(SPEC_ALIASES) do
		if out[internal] == nil and out[public] ~= nil then
			out[internal] = out[public]
		end
	end
	-- `Backdrop` is read as-is, but accept the lowercase spelling too.
	if out.Backdrop == nil and out.backdrop ~= nil then
		out.Backdrop = out.backdrop
	end
	return out
end

--- @param spec { Name?, Subtitle?, Theme?, Size?, Position?, Anchor?, MinSize?, MaxSize?, Resizable?, Draggable?, Sidebar?, StatusBar?, Backdrop?, UIScale?, ToggleKey?, CloseKey?, Parent?, OnClose?, Compact? }
function Window.new(spec: { [any]: any }): any
	local defaults = Config.defaults
	local config = Util.deepMerge(defaults, canonicalSpec(spec or {}))
	local tokens = Theme.current()

	if spec and spec.Theme then
		Theme.apply(spec.Theme, { name = spec.Theme })
		tokens = Theme.current()
	end

	local self = setmetatable({
		_spec = config,
		_maid = Maid.new("window"),
		_tabs = {},
		_tabOrder = {},
		_tokens = tokens,
		_themeName = spec and spec.Theme or Theme.name(),
		_minimized = false,
		_maximized = false,
		_hidden = false,
		_tabIndex = 1,
		_statusTick = 0,
		_fpsBuffer = {},
		_fpsIndex = 0,
	}, Window)

	-- Serialised geometry is restored before the first paint.
	self._tabIndicatorVisible = false

	self.Closed = Signal.new("Window.Closed")
	self.Minimized = Signal.new("Window.Minimized")
	self.TabChanged = Signal.new("Window.TabChanged")
	self.ThemeChanged = Signal.new("Window.ThemeChanged")

	-- ScreenGui ---------------------------------------------------------
	local parent = resolveParent(config.Parent)
	local screen = Util.create("ScreenGui", {
		Name = "Vantage",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = config.DisplayOrder or 100,
		Enabled = true,
		Parent = parent,
	})
	Util.tag(screen, "Vantage")
	self.ScreenGui = screen

	-- Root ---------------------------------------------------------------
	local root = Util.frame({
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	Util.list(root, {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	})
	self.Root = root

	-- Scrim --------------------------------------------------------------
	local scrim = Util.frame({
		Name = "Scrim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tokens.scrim,
		BackgroundTransparency = config.Backdrop and 0.35 or 1,
		Visible = config.Backdrop == true,
		ZIndex = 1,
		Parent = root,
	})
	self.Scrim = scrim

	-- Shell ---------------------------------------------------------------
	local shellHolder = Util.frame({
		Name = "ShellHolder",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = root,
	})
	Util.list(shellHolder, {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self.ShellHolder = shellHolder

	local minSize = Vector2.new(config.minSize.X, config.minSize.Y)

	local shell = Util.frame({
		Name = "Shell",
		AnchorPoint = config.anchor or Vector2.new(0.5, 0.5),
		Position = config.position or UDim2.fromScale(0.5, 0.5),
		Size = config.size or UDim2.fromOffset(680, 440),
		BackgroundColor3 = tokens.surface,
		BackgroundTransparency = 0.02,
		ClipsDescendants = false,
		ZIndex = 2,
		Parent = shellHolder,
	})
	Util.corner(shell, tokens.radiusXl)
	Util.stroke(shell, tokens.border, 1, 0.25)
	Util.tag(shell, "Vantage")
	self.Shell = shell

	-- Shadow: three stacked rounded rects behind the shell, offset down.
	local shadow = Util.frame({
		Name = "Shadow",
		AnchorPoint = config.anchor or Vector2.new(0.5, 0.5),
		Position = UDim2.new(
			(config.position or UDim2.fromScale(0.5, 0.5)).X.Scale,
			(config.position or UDim2.fromScale(0.5, 0.5)).X.Offset,
			(config.position or UDim2.fromScale(0.5, 0.5)).Y.Scale,
			(config.position or UDim2.fromScale(0.5, 0.5)).Y.Offset + 10
		),
		Size = config.size or UDim2.fromOffset(680, 440),
		BackgroundColor3 = tokens.shadow,
		BackgroundTransparency = 0.72,
		ZIndex = 1,
		Parent = shellHolder,
	})
	Util.corner(shadow, tokens.radiusXl + 6)
	self.Shadow = shadow

	-- Inner layout --------------------------------------------------------
	local inner = Util.frame({
		Name = "Inner",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = shell,
	})
	Util.corner(inner, tokens.radiusXl)
	Util.list(inner, {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	})
	self.Inner = inner

	-- Title bar -----------------------------------------------------------
	local titleBar = Util.frame({
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, config.titleBarHeight or TITLE_HEIGHT),
		BackgroundColor3 = tokens.surface,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = inner,
	})
	Util.corner(titleBar, tokens.radiusXl)
	Util.pad(titleBar, { Left = 14, Right = 8 })
	self.TitleBar = titleBar

	Util.list(titleBar, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	-- The wordmark is text, never the logo asset.
	local markGlyphHolder = Util.row({
		Name = "Mark",
		Size = UDim2.fromOffset(18, 18),
		LayoutOrder = 1,
		Parent = titleBar,
	})
	local markGlyph = Glyph.draw(markGlyphHolder, "ring", {
		size = 16,
		color = tokens.accent,
		weight = 9,
		zIndex = 4,
		position = UDim2.fromOffset(1, 1),
	})
	self._markGlyph = markGlyph

	local titleBlock = Util.row({
		Name = "TitleBlock",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = titleBar,
	})
	Util.list(titleBlock, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	local title = Util.text({
		Name = "Title",
		Text = config.name or Config.name,
		TextSize = tokens.fontSizeMd,
		Font = "subheading",
		TextColor3 = tokens.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		Parent = titleBlock,
	})
	self.Title = title

	local subtitle = Util.text({
		Name = "Subtitle",
		Text = config.subtitle or "",
		TextSize = tokens.fontSizeSm,
		Font = "body",
		TextColor3 = tokens.textDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Visible = config.subtitle ~= nil,
		Parent = titleBlock,
	})
	self.Subtitle = subtitle

	local versionBadgeHolder = Util.row({
		Name = "Version",
		Size = UDim2.new(0, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 3,
		Parent = titleBlock,
	})
	local versionBadge = Elements.badge({
		Text = config.version or ("v" .. Config.version),
		Tone = "accent",
	}, { parent = versionBadgeHolder, maid = self._maid })
	self._versionBadge = versionBadge

	-- Drag surface: sits under the controls so they stay clickable.
	local dragSurface = Util.create("TextButton", {
		Name = "DragSurface",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -132, 1, 0),
		ZIndex = 2,
		Parent = titleBar,
	})
	self._dragSurface = dragSurface

	-- Window controls ------------------------------------------------------
	local controls = Util.row({
		Name = "Controls",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 3,
		Parent = titleBar,
	})
	Util.list(controls, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	})
	self._controls = controls

	local function controlButton(order: number, glyphName: string, tone: string, callback: () -> ()): any
		local holder = Util.frame({
			Name = "Control_" .. glyphName,
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = tokens.hover,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = controls,
		})
		Util.corner(holder, tokens.radiusSm)
		local glyph = Glyph.draw(holder, glyphName, {
			size = 11,
			color = tokens.textDim,
			weight = 12,
			zIndex = 6,
		})
		if glyph then
			glyph.AnchorPoint = Vector2.new(0.5, 0.5)
			glyph.Position = UDim2.fromScale(0.5, 0.5)
		end
		local hit = Util.create("TextButton", {
			Name = "Hit",
			Text = "",
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 7,
			Parent = holder,
		})
		hit.MouseEnter:Connect(function()
			Motion.tween(holder, { BackgroundTransparency = 0 }, Motion.options("hover"))
			if glyph then
				Glyph.setColor(glyph, tokens[tone])
			end
		end)
		hit.MouseLeave:Connect(function()
			Motion.tween(holder, { BackgroundTransparency = 1 }, Motion.options("hover"))
			if glyph then
				Glyph.setColor(glyph, tokens.textDim)
			end
		end)
		hit.Activated:Connect(callback)
		return { holder = holder, glyph = glyph, hit = hit }
	end

	self._minimizeControl = controlButton(1, "minus", "text", function()
		self:Minimize(not self._minimized)
	end)
	self._maximizeControl = controlButton(2, "layout", "text", function()
		self:Maximize(not self._maximized)
	end)
	self._closeControl = controlButton(3, "close", "danger", function()
		self:Close()
	end)

	-- Body: sidebar + content ------------------------------------------------
	local body = Util.frame({
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -(config.titleBarHeight or TITLE_HEIGHT) - (config.statusBarHeight or STATUS_HEIGHT)),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = inner,
	})
	Util.list(body, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	})
	self.Body = body

	local sidebar = Util.row({
		Name = "Sidebar",
		Size = UDim2.new(0, config.sidebarWidth or SIDEBAR_WIDTH, 1, 0),
		LayoutOrder = 1,
		Visible = config.sidebar ~= false,
		Parent = body,
	})
	Util.stack(sidebar, 2)
	Util.pad(sidebar, { Left = 10, Right = 6, Top = 2, Bottom = 10 })
	self.Sidebar = sidebar

	self._sidebarSearch = nil
	local sidebarSearchHolder = Util.row({
		Name = "Search",
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = 0,
		Visible = false,
		Parent = sidebar,
	})
	local sidebarSearchShell = Util.frame({
		Name = "Shell",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tokens.sunken,
		Parent = sidebarSearchHolder,
	})
	Util.corner(sidebarSearchShell, tokens.radiusSm)
	Util.pad(sidebarSearchShell, { Left = 24, Right = 8 })
	local sidebarSearchGlyphHolder = Util.row({
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 7, 0.5, 0),
		Size = UDim2.fromOffset(11, 11),
		ZIndex = 4,
		Parent = sidebarSearchShell,
	})
	Glyph.draw(sidebarSearchGlyphHolder, "search", {
		size = 11,
		color = tokens.textDim,
		weight = 12,
		zIndex = 4,
	})
	local sidebarSearch = Util.create("TextBox", {
		Name = "Box",
		Text = "",
		PlaceholderText = "Filter",
		PlaceholderColor3 = tokens.textDim,
		TextSize = tokens.fontSizeSm,
		Font = Enum.Font.Gotham,
		TextColor3 = tokens.text,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = sidebarSearchShell,
	})
	Util.applyFont(sidebarSearch, "body")
	self._sidebarSearch = sidebarSearch

	local tabList = Util.row({
		Name = "TabList",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = sidebar,
	})
	Util.stack(tabList, 2)
	self._tabList = tabList

	-- The active-tab indicator slides between rows.
	local tabIndicator = Util.frame({
		Name = "Indicator",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = tokens.selected,
		Visible = false,
		ZIndex = 1,
		Parent = sidebar,
	})
	Util.corner(tabIndicator, tokens.radiusMd)
	Util.stroke(tabIndicator, tokens.accentBorder, 1, 0.7)
	self._tabIndicator = tabIndicator

	local sidebarFooter = Util.row({
		Name = "SidebarFooter",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 99,
		Parent = sidebar,
	})
	Util.stack(sidebarFooter, 4)
	self._sidebarFooter = sidebarFooter

	local contentHolder = Util.row({
		Name = "Content",
		Size = UDim2.new(1, -(config.sidebarWidth or SIDEBAR_WIDTH), 1, 0),
		LayoutOrder = 2,
		Parent = body,
	})
	self.ContentHolder = contentHolder

	-- Status bar ---------------------------------------------------------------
	local statusBar
	local statusItems = {}
	if config.statusBar ~= false then
		statusBar = Util.frame({
			Name = "StatusBar",
			Size = UDim2.new(1, 0, 0, config.statusBarHeight or STATUS_HEIGHT),
			BackgroundColor3 = tokens.canvas,
			BackgroundTransparency = 0.55,
			LayoutOrder = 3,
			Parent = inner,
		})
		Util.corner(statusBar, tokens.radiusXl)
		Util.pad(statusBar, { Left = 14, Right = 14 })
		Util.stroke(statusBar, tokens.borderSubtle, 1, 0.6)
		self.StatusBar = statusBar

		local left = Util.row({
			Name = "Left",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = statusBar,
		})
		Util.list(left, {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 14),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
		local right = Util.row({
			Name = "Right",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = statusBar,
		})
		Util.list(right, {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 14),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})

		local order = { left = 0, right = 0 }
		local function addStatus(side: string, label: string, initial: string, tone: string?): any
			order[side] += 1
			return Elements.stat({
				Label = label,
				Value = initial,
				Tone = tone,
				LayoutOrder = order[side],
			}, { parent = side == "left" and left or right, maid = self._maid })
		end

		statusItems.tab = addStatus("left", "VIEW", "—")
		statusItems.motion = addStatus("left", "MOTION", "0")
		statusItems.fps = addStatus("right", "FPS", "60", "success")
		statusItems.ping = addStatus("right", "PING", "—")
		statusItems.memory = addStatus("right", "MEM", "—")
		self.StatusItems = statusItems
	end

	-- Resize handle ------------------------------------------------------------
	local resizeHandle
	if config.resizable ~= false then
		resizeHandle = Util.create("TextButton", {
			Name = "ResizeHandle",
			Text = "",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(20, 20),
			ZIndex = 9,
			Parent = shell,
		})
		local gripHolder = Util.row({
			Name = "Grip",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(9, 9),
			ZIndex = 9,
			Parent = shell,
		})
		local grip = Glyph.draw(gripHolder, "chevron-right", {
			size = 9,
			color = tokens.textDim,
			weight = 14,
			zIndex = 9,
			transparency = 0.45,
		})
		if grip then
			-- Rotate a chevron 45 degrees into the classic corner grip.
			gripHolder.Rotation = 45
		end
		self._resizeHandle = resizeHandle
		self._grip = gripHolder
	end

	-- Overlay hosts -------------------------------------------------------------
	local overlayLayer = Util.frame({
		Name = "OverlayLayer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 400,
		Parent = root,
	})
	self.OverlayLayer = overlayLayer

	local notifyLayer = Util.frame({
		Name = "NotifyLayer",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(320, 0),
		BackgroundTransparency = 1,
		ZIndex = 600,
		Parent = root,
	})
	Util.list(notifyLayer, {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	})
	self.NotifyLayer = notifyLayer

	local tooltipLayer = Util.frame({
		Name = "TooltipLayer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 700,
		Parent = root,
	})
	self.TooltipLayer = tooltipLayer

	-- One shared tooltip for the whole window. Components attach to it
	-- through their context, so every `Tooltip = "…"` in the interface
	-- behaves identically and there is exactly one tooltip alive at a time.
	local Tooltip = require(script.Parent.Parent.Overlay.Tooltip)
	self.Tooltip = Tooltip.new({ layer = tooltipLayer, delay = config.tooltipDelay })
	self._maid:add(self.Tooltip)

	-- UI scale ----------------------------------------------------------------
	local uiScale = Util.create("UIScale", {
		Name = "VantageScale",
		Scale = 1,
		Parent = root,
	})
	self.UIScale = uiScale

	local function applyScale()
		local width = Util.viewport().X
		local raw
		if config.uiScale then
			raw = config.uiScale
		elseif width < 620 then
			raw = 0.86
		elseif width < 1000 then
			raw = 0.94
		else
			raw = Util.uiScale(1920)
		end
		uiScale.Scale = raw
	end
	applyScale()

	local camera = workspace and workspace.CurrentCamera
	if camera then
		pcall(function()
			self._maid:add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				applyScale()
			end))
		end)
	end
	self._maid:add(Theme.Changed:connect(function(next)
		self._tokens = next
		applyScale()
		-- Keep the shell inside the viewport after a metric change.
		task.defer(function()
			self._clampToViewport()
		end)
	end))

	-- Dragging ------------------------------------------------------------------
	local dragging = false
	local dragStart
	local dragOrigin
	local dragConnection
	local dragEndConnection

	local function clampPosition(position: UDim2): UDim2
		local viewport = Util.viewport()
		local size = shell.AbsoluteSize
		local anchor = shell.AnchorPoint
		local x = position.X.Scale * viewport.X + position.X.Offset
		local y = position.Y.Scale * viewport.Y + position.Y.Offset
		local left = x - size.X * anchor.X
		local top = y - size.Y * anchor.Y
		-- Always leave a comfortable strip on screen so the window can
		-- never be dragged out of reach.
		local minLeft = -size.X + 120
		local maxLeft = viewport.X - 60
		local minTop = 0
		local maxTop = viewport.Y - 40
		local clampedLeft = Util.clamp(left, minLeft, math.max(minLeft, maxLeft))
		local clampedTop = Util.clamp(top, minTop, math.max(minTop, maxTop))
		return UDim2.fromOffset(
			clampedLeft + size.X * anchor.X,
			clampedTop + size.Y * anchor.Y
		)
	end

	self._clampToViewport = function()
		if self._maximized then
			return
		end
		local clamped = clampPosition(shell.Position)
		if clamped ~= shell.Position then
			shell.Position = clamped
			shadow.Position = UDim2.new(clamped.X.Scale, clamped.X.Offset, clamped.Y.Scale, clamped.Y.Offset + 10)
		end
	end

	local function beginDrag(inputX: number, inputY: number)
		if config.draggable == false or self._maximized then
			return
		end
		dragging = true
		dragStart = Vector2.new(inputX, inputY)
		dragOrigin = Vector2.new(shell.AbsolutePosition.X, shell.AbsolutePosition.Y)
		Motion.tween(shell, {
			BackgroundTransparency = 0.05,
		}, Motion.options("hover"))
		if self._grip then
			Glyph.setTransparency(self._grip, 0.15)
		end
	end

	local function updateDrag(inputX: number, inputY: number)
		if not dragging then
			return
		end
		local delta = Vector2.new(inputX - dragStart.X, inputY - dragStart.Y)
		local viewport = Util.viewport()
		local size = shell.AbsoluteSize
		local anchor = shell.AnchorPoint
		local targetLeft = dragOrigin.X + delta.X
		local targetTop = dragOrigin.Y + delta.Y
		targetLeft = Util.clamp(targetLeft, -size.X + 120, viewport.X - 60)
		targetTop = Util.clamp(targetTop, 0, viewport.Y - 40)
		local position = UDim2.fromOffset(targetLeft + size.X * anchor.X, targetTop + size.Y * anchor.Y)
		shell.Position = position
		shadow.Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + 10)
	end

	local function endDrag()
		if not dragging then
			return
		end
		dragging = false
		Motion.tween(shell, { BackgroundTransparency = 0.02 }, Motion.options("hover"))
		if dragConnection then
			dragConnection:Disconnect()
			dragConnection = nil
		end
		if dragEndConnection then
			dragEndConnection:Disconnect()
			dragEndConnection = nil
		end
		self:_persist()
	end

	local UserInputService = game:GetService("UserInputService")

	dragSurface.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		beginDrag(input.Position.X, input.Position.Y)

		if input.UserInputType == Enum.UserInputType.Touch then
			dragConnection = UserInputService.TouchMoved:Connect(function(moveInput)
				updateDrag(moveInput.Position.X, moveInput.Position.Y)
			end)
			dragEndConnection = UserInputService.TouchEnded:Connect(endDrag)
		else
			dragConnection = UserInputService.InputChanged:Connect(function(changed)
				if changed.UserInputType == Enum.UserInputType.MouseMovement then
					updateDrag(changed.Position.X, changed.Position.Y)
				end
			end)
			dragEndConnection = UserInputService.InputEnded:Connect(function(changed)
				if changed.UserInputType == Enum.UserInputType.MouseButton1 then
					endDrag()
				end
			end)
		end
	end)

	-- Double-click the title bar to maximise, the way every desktop OS
	-- does. Tracked with a timestamp rather than a GUI double-click
	-- event so it works identically for touch.
	local lastTitleClick = 0
	dragSurface.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now - lastTitleClick < 0.32 then
			lastTitleClick = 0
			self:Maximize(not self._maximized)
		else
			lastTitleClick = now
		end
	end)

	-- Resizing --------------------------------------------------------------------
	if resizeHandle then
		local resizing = false
		local resizeStart
		local resizeOrigin
		local resizeMove
		local resizeEnd

		local function beginResize(x: number, y: number)
			if self._maximized then
				return
			end
			resizing = true
			resizeStart = Vector2.new(x, y)
			resizeOrigin = shell.AbsoluteSize
			if self._grip then
				Glyph.setTransparency(self._grip, 0)
			end
		end

		local function updateResize(x: number, y: number)
			if not resizing then
				return
			end
			local viewport = Util.viewport()
			local delta = Vector2.new(x - resizeStart.X, y - resizeStart.Y)
			local size = Vector2.new(
				Util.clamp(resizeOrigin.X + delta.X, minSize.X, math.min(config.maxSize and config.maxSize.X or viewport.X, viewport.X - 40)),
				Util.clamp(resizeOrigin.Y + delta.Y, minSize.Y, math.min(config.maxSize and config.maxSize.Y or viewport.Y, viewport.Y - 40))
			)
			shell.Size = UDim2.fromOffset(size.X, size.Y)
			shadow.Size = UDim2.fromOffset(size.X, size.Y)
		end

		local function endResize()
			if not resizing then
				return
			end
			resizing = false
			if self._grip then
				Glyph.setTransparency(self._grip, 0.45)
			end
			if resizeMove then
				resizeMove:Disconnect()
				resizeMove = nil
			end
			if resizeEnd then
				resizeEnd:Disconnect()
				resizeEnd = nil
			end
			self:_persist()
		end

		resizeHandle.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			beginResize(input.Position.X, input.Position.Y)
			if input.UserInputType == Enum.UserInputType.Touch then
				resizeMove = UserInputService.TouchMoved:Connect(function(moveInput)
					updateResize(moveInput.Position.X, moveInput.Position.Y)
				end)
				resizeEnd = UserInputService.TouchEnded:Connect(endResize)
			else
				resizeMove = UserInputService.InputChanged:Connect(function(changed)
					if changed.UserInputType == Enum.UserInputType.MouseMovement then
						updateResize(changed.Position.X, changed.Position.Y)
					end
				end)
				resizeEnd = UserInputService.InputEnded:Connect(function(changed)
					if changed.UserInputType == Enum.UserInputType.MouseButton1 then
						endResize()
					end
				end)
			end
		end)
	end

	-- Entrance ----------------------------------------------------------------------
	self._maid:add(function()
		Motion.cancelAll(shell)
	end)

	self:_playEntrance()

	-- Hotkeys -----------------------------------------------------------------------
	local toggleKey = config.toggleKey
	if toggleKey == nil then
		toggleKey = Config.keybinds.toggleInterface
	end

	self._maid:add(UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if toggleKey and input.KeyCode == toggleKey then
			self:Toggle()
			return
		end
		if config.closeKey and input.KeyCode == config.closeKey then
			self:Hide()
		end
	end))

	-- Restore persisted geometry ---------------------------------------------------
	self:_restore()

	self._ready = true
	return self
end

--[[ Geometry --------------------------------------------------------- ]]

function Window:_persist()
	local persistence = Config.persistence
	if not (persistence and persistence.save) then
		return
	end
	Util.safeCall(persistence.save, "window", {
		size = { X = self.Shell.AbsoluteSize.X, Y = self.Shell.AbsoluteSize.Y },
		position = { X = self.Shell.AbsolutePosition.X, Y = self.Shell.AbsolutePosition.Y },
		tab = self._tabIndex,
		theme = self._themeName,
	})
end

function Window:_restore()
	local persistence = Config.persistence
	if not (persistence and persistence.load) then
		return
	end
	local ok, saved = pcall(persistence.load, "window")
	if not ok or type(saved) ~= "table" then
		return
	end
	if saved.size and saved.size.X and saved.size.Y then
		self.Shell.Size = UDim2.fromOffset(saved.size.X, saved.size.Y)
		self.Shadow.Size = UDim2.fromOffset(saved.size.X, saved.size.Y)
	end
	if saved.position and saved.position.X and saved.position.Y then
		-- Persisted coordinates are top-left in screen space; convert
		-- back through the shell's anchor so any anchor configuration
		-- restores to the same visual place.
		local anchor = self.Shell.AnchorPoint
		local size = self.Shell.AbsoluteSize
		self.Shell.Position = UDim2.fromOffset(
			saved.position.X + size.X * anchor.X,
			saved.position.Y + size.Y * anchor.Y
		)
		self.Shadow.Position = UDim2.new(
			self.Shell.Position.X.Scale,
			self.Shell.Position.X.Offset,
			self.Shell.Position.Y.Scale,
			self.Shell.Position.Y.Offset + 10
		)
		self:_clampToViewport()
	end
end

--- The opening gesture: the shell settles in from slightly small and
--- transparent, the chrome fades in behind it, then the active tab's
--- sections stagger.
function Window:_playEntrance()
	if Motion.getReducedMotion() then
		Motion.setScale(self.Shell, 1)
		return
	end
	Motion.setScale(self.Shell, 0.94)
	Motion.scale(self.Shell, 1, { duration = 0.42, easing = "enterSnap" })
	self.Shell.BackgroundTransparency = 1
	self.Shadow.BackgroundTransparency = 1
	Motion.tween(self.Shell, { BackgroundTransparency = 0.02 }, { duration = 0.36, easing = "enterSnap" })
	Motion.tween(self.Shadow, { BackgroundTransparency = 0.72 }, { duration = 0.36, easing = "enterSnap" })
	self.Shell.Position = UDim2.new(
		self.Shell.Position.X.Scale,
		self.Shell.Position.X.Offset,
		self.Shell.Position.Y.Scale,
		self.Shell.Position.Y.Offset + 14
	)
	Motion.tween(self.Shell, {
		Position = UDim2.new(
			self.Shell.Position.X.Scale,
			self.Shell.Position.X.Offset,
			self.Shell.Position.Y.Scale,
			self.Shell.Position.Y.Offset - 14
		),
	}, { duration = 0.46, easing = "enterSnap" })
end

--[[ Tabs ------------------------------------------------------------- ]]

--- Creates and registers a tab.
--- @param spec { Name, Icon?, Description?, Order?, Badge?, BadgeTone? }
function Window:Tab(spec: { [any]: any }): any
	local tabSpec = table.clone(spec or {})
	tabSpec.Order = tabSpec.Order or (#self._tabOrder + 1)

	local entry = {}

	local tab = Tab.new(tabSpec, {
		maid = self._maid,
		parent = self.ContentHolder,
		window = self,
		layer = self.Root,
	})

	-- Sidebar row ---------------------------------------------------------
	local row = Util.frame({
		Name = "Tab_" .. tostring(tabSpec.Name),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = self._tokens.hover,
		BackgroundTransparency = 1,
		LayoutOrder = tabSpec.Order,
		Parent = self._tabList,
	})
	Util.corner(row, self._tokens.radiusMd)
	Util.pad(row, { Left = 10, Right = 8 })

	local rowContent = Util.row({
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		Parent = row,
	})
	Util.list(rowContent, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 9),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	if tabSpec.Icon then
		local iconHolder = Util.row({
			Name = "Icon",
			Size = UDim2.fromOffset(14, 14),
			LayoutOrder = 1,
			Parent = rowContent,
		})
		entry.icon = Glyph.draw(iconHolder, tabSpec.Icon, {
			size = 14,
			color = self._tokens.textDim,
			weight = 12,
			zIndex = 4,
		})
	end

	local label = Util.text({
		Name = "Label",
		Text = tabSpec.Name or "Tab",
		TextSize = self._tokens.fontSizeMd,
		Font = "bodyMedium",
		TextColor3 = self._tokens.textDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -24, 1, 0),
		LayoutOrder = 2,
		Parent = rowContent,
	})
	entry.label = label

	local badgeValue = Util.text({
		Name = "Badge",
		Text = tabSpec.Badge and tostring(tabSpec.Badge) or "",
		TextSize = self._tokens.fontSizeXs + 1,
		Font = "mono",
		TextColor3 = self._tokens.accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 20, 1, 0),
		LayoutOrder = 3,
		Visible = tabSpec.Badge ~= nil,
		Parent = rowContent,
	})
	entry.badge = badgeValue

	local hit = Util.create("TextButton", {
		Name = "Hit",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Parent = row,
	})
	entry.hit = hit
	entry.row = row
	entry.tab = tab
	entry.spec = tabSpec

	hit.Activated:Connect(function()
		self:SelectTab(tab)
	end)
	hit.MouseEnter:Connect(function()
		if self._tabs[self._tabIndex] ~= entry then
			Motion.tween(row, { BackgroundTransparency = 0.55 }, Motion.options("hover"))
			Motion.tween(label, { TextColor3 = self._tokens.textMuted }, Motion.options("hover"))
			if entry.icon then
				Glyph.setColor(entry.icon, self._tokens.textMuted)
			end
		end
	end)
	hit.MouseLeave:Connect(function()
		if self._tabs[self._tabIndex] ~= entry then
			Motion.tween(row, { BackgroundTransparency = 1 }, Motion.options("hover"))
			Motion.tween(label, { TextColor3 = self._tokens.textDim }, Motion.options("hover"))
			if entry.icon then
				Glyph.setColor(entry.icon, self._tokens.textDim)
			end
		end
	end)

	-- Enter / exit animation for the row itself.
	Motion.setScale(row, 1)

	table.insert(self._tabs, entry)
	table.sort(self._tabs, function(a, b)
		return (a.spec.Order or 0) < (b.spec.Order or 0)
	end)

	entry.tab.Owner = self

	table.insert(self._tabOrder, tab)

	if #self._tabs == 1 then
		self:SelectTab(tab, { animated = false })
	end

	-- Geometry changes move the sidebar rows, so the indicator has to be
	-- re-aimed after any resize or scale change.
	task.defer(function()
		if self._tabIndex then
			self:SelectTab(self._tabIndex, { animated = false })
		end
	end)

	return tab
end

--- Selects a tab by instance, name or index.
function Window:SelectTab(target: any, options: { [any]: any }?)
	local index
	if type(target) == "number" then
		index = target
	elseif type(target) == "string" then
		for position, entry in ipairs(self._tabs) do
			if entry.spec.Name == target then
				index = position
				break
			end
		end
	else
		for position, entry in ipairs(self._tabs) do
			if entry.tab == target then
				index = position
				break
			end
		end
	end

	if not index or not self._tabs[index] then
		return self
	end
	if self._tabIndex == index and self._tabs[index].tab:IsVisible() then
		self._tabs[index].tab:ScrollToTop()
		return self
	end

	local previous = self._tabs[self._tabIndex]
	if previous then
		previous.tab:_deactivate()
		Motion.tween(previous.row, { BackgroundTransparency = 1 }, Motion.options("hover"))
		Motion.tween(previous.label, { TextColor3 = self._tokens.textDim }, Motion.options("hover"))
		if previous.icon then
			Glyph.setColor(previous.icon, self._tokens.textDim)
		end
	end

	self._tabIndex = index
	local entry = self._tabs[index]
	entry.tab:_activate(options == nil or options.animated ~= false)
	Motion.tween(entry.label, { TextColor3 = self._tokens.text }, Motion.options("hover"))
	if entry.icon then
		Glyph.setColor(entry.icon, self._tokens.accent)
	end

	-- Slide the indicator to the active row. The row's top edge is
	-- expressed in the sidebar's own coordinate space so it survives
	-- window moves and UI scaling.
	local sidebarOrigin = self._tabList.AbsolutePosition.Y
	local offset = entry.row.AbsolutePosition.Y - sidebarOrigin
	self._tabIndicator.Size = UDim2.new(1, 0, 0, entry.row.AbsoluteSize.Y)

	if not self._indicatorSpring then
		local spring = Motion.springFrom("snappy", offset)
		self._indicatorSpring = spring
		self._maid:add(function()
			spring:destroy()
		end)
		spring:observe(function(value)
			self._tabIndicator.Position = UDim2.fromOffset(0, value)
		end)
	end

	if self._tabIndicatorVisible then
		self._indicatorSpring:setGoal(offset)
	else
		self._indicatorSpring:snap(offset)
		self._tabIndicatorVisible = true
	end
	self._tabIndicator.Visible = true

	if self.StatusItems and self.StatusItems.tab then
		self.StatusItems.tab:Set(entry.spec.Name or "")
	end

	self.TabChanged:fire(entry.tab, entry.spec, self)
	return self
end

function Window:GetTab(name: string): any
	for _, entry in ipairs(self._tabs) do
		if entry.spec.Name == name then
			return entry.tab
		end
	end
	return nil
end

function Window:CurrentTab(): any
	local entry = self._tabs[self._tabIndex]
	return entry and entry.tab or nil
end

--- Shows or hides a tab at runtime.
function Window:SetTabVisible(name: string, visible: boolean)
	for _, entry in ipairs(self._tabs) do
		if entry.spec.Name == name then
			entry.row.Visible = visible
			if not visible and self._tabs[self._tabIndex] == entry then
				for position, candidate in ipairs(self._tabs) do
					if candidate.row.Visible then
						self:SelectTab(position)
						break
					end
				end
			end
		end
	end
	return self
end

--[[ Window state ----------------------------------------------------- ]]

function Window:Show(animated: boolean?)
	self._hidden = false
	self.Root.Visible = true
	if animated == false or Motion.getReducedMotion() then
		return self
	end
	self:_playEntrance()
	return self
end

function Window:Hide(animated: boolean?)
	self._hidden = true
	if animated == false or Motion.getReducedMotion() then
		self.Root.Visible = false
		return self
	end
	Motion.tween(self.Shell, { BackgroundTransparency = 1 }, Motion.options("exit"))
	Motion.scale(self.Shell, 0.97, Motion.options("exit"))
	Motion.tween(self.Shadow, { BackgroundTransparency = 1 }, Motion.options("exit"))
	task.delay(0.2, function()
		if self._hidden then
			self.Root.Visible = false
			Motion.setScale(self.Shell, 1)
		end
	end)
	return self
end

function Window:Toggle()
	if self._hidden then
		self:Show()
	else
		self:Hide()
	end
	return self
end

function Window:IsVisible(): boolean
	return not self._hidden
end

--- Minimises to just the title bar. Animated, and it remembers what the
--- previous height was so restoring is exact.
function Window:Minimize(minimized: boolean)
	minimized = minimized == true
	if self._minimized == minimized then
		return self
	end
	self._minimized = minimized

	if minimized then
		self._restoreSize = self.Shell.AbsoluteSize.Y
	end

	local target = minimized and (self._spec.titleBarHeight or TITLE_HEIGHT)
		or (self._restoreSize or (self._spec.size and self._spec.size.Y.Offset) or 440)

	self.Body.Visible = not minimized
	if self.StatusBar then
		self.StatusBar.Visible = not minimized
	end
	Motion.tween(self.Shell, { Size = UDim2.new(self.Shell.Size.X.Scale, self.Shell.Size.X.Offset, 0, target) }, {
		duration = 0.34,
		easing = minimized and "exit" or "enterSnap",
	})
	Motion.tween(self.Shadow, { Size = UDim2.new(self.Shell.Size.X.Scale, self.Shell.Size.X.Offset, 0, target) }, {
		duration = 0.34,
		easing = minimized and "exit" or "enterSnap",
	})
	if self._minimizeControl and self._minimizeControl.glyph then
		Glyph.setColor(self._minimizeControl.glyph, minimized and self._tokens.accent or self._tokens.textDim)
	end
	self.Minimized:fire(minimized, self)
	return self
end

--- Expands to fill the usable viewport.
function Window:Maximize(maximized: boolean)
	maximized = maximized == true
	if self._maximized == maximized then
		return self
	end
	self._maximized = maximized

	local viewport = Util.viewport()
	local insets = Util.insets()
	local duration = Motion.getReducedMotion() and 0 or 0.34

	if maximized then
		self._restoreGeometry = {
			size = self.Shell.Size,
			position = self.Shell.Position,
		}
		local width = viewport.X - insets.left - insets.right - 24
		local height = viewport.Y - insets.top - insets.bottom - 24
		local position = UDim2.fromOffset(
			insets.left + 12 + width * 0.5,
			insets.top + 12 + height * 0.5
		)
		Motion.tween(self.Shell, {
			Size = UDim2.fromOffset(width, height),
			Position = position,
		}, { duration = duration, easing = "enterSnap" })
		Motion.tween(self.Shadow, {
			Size = UDim2.fromOffset(width, height),
			Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + 10),
		}, { duration = duration, easing = "enterSnap" })
	elseif self._restoreGeometry then
		Motion.tween(self.Shell, {
			Size = self._restoreGeometry.size,
			Position = self._restoreGeometry.position,
		}, { duration = duration, easing = "enterSnap" })
		Motion.tween(self.Shadow, {
			Size = self._restoreGeometry.size,
			Position = UDim2.new(
				self._restoreGeometry.position.X.Scale,
				self._restoreGeometry.position.X.Offset,
				self._restoreGeometry.position.Y.Scale,
				self._restoreGeometry.position.Y.Offset + 10
			),
		}, { duration = duration, easing = "enterSnap" })
	end
	if self._maximizeControl and self._maximizeControl.glyph then
		Glyph.setColor(self._maximizeControl.glyph, maximized and self._tokens.accent or self._tokens.textDim)
	end
	return self
end

function Window:IsMaximized(): boolean
	return self._maximized
end

--- Animates the window away and destroys it. Always call this instead of
--- removing the ScreenGui by hand: it releases every connection the
--- window owns.
function Window:Close()
	local onClose = self._spec.onClose
	self.Closed:fire(self)
	Util.safeCall(onClose, self)

	Motion.tween(self.Shell, { BackgroundTransparency = 1 }, Motion.options("exit"))
	Motion.scale(self.Shell, 0.96, Motion.options("exit"))
	Motion.tween(self.Shadow, { BackgroundTransparency = 1 }, Motion.options("exit"))
	task.delay(0.22, function()
		self:Destroy()
	end)
end

function Window:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true

	if self.Tooltip then
		self.Tooltip:destroy()
		self.Tooltip = nil
	end

	for _, entry in ipairs(self._tabs) do
		entry.tab:destroy()
	end
	table.clear(self._tabs)

	self.Closed:destroy()
	self.Minimized:destroy()
	self.TabChanged:destroy()
	self.ThemeChanged:destroy()
	self._maid:destroy()

	if self.ScreenGui then
		self.ScreenGui:Destroy()
		self.ScreenGui = nil
	end
end

--[[ Theme ------------------------------------------------------------ ]]

--- Switches theme with a full token morph.
function Window:SetTheme(name: string, options: { [any]: any }?)
	if type(name) == "table" then
		Theme.apply(name, { transition = options or true, name = options and options.name })
	else
		Theme.apply(name, { transition = options == nil and true or options, name = name })
	end
	self._themeName = type(name) == "string" and name or "custom"
	self.ThemeChanged:fire(self._themeName, self)
	return self
end

function Window:GetTheme(): string
	return self._themeName
end

function Window:GetTabNames(): { string }
	local names = {}
	for _, entry in ipairs(self._tabs) do
		if entry.row.Visible then
			table.insert(names, entry.spec.Name)
		end
	end
	return names
end

--- Selects the next/previous visible tab cyclically. Bound to
--- Ctrl+Tab-style navigation by the host application.
function Window:CycleTab(direction: number)
	if #self._tabs == 0 then
		return self
	end
	local index = self._tabIndex
	for _ = 1, #self._tabs do
		index = ((index - 1 + direction) % #self._tabs) + 1
		if self._tabs[index] and self._tabs[index].row.Visible then
			self:SelectTab(index)
			return self
		end
	end
	return self
end

return Window
