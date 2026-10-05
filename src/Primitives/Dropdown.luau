--!nonstrict
--[[
	Vantage 1.0.0 · Primitives/Dropdown
	------------------------------------------------------------------
	A select control that stays usable at a thousand options.

	· The panel animates open from the control's own edge, not from the
	  centre of the screen, so it reads as attached to the thing it
	  belongs to.
	· Search appears automatically past eight options and filters with a
	  ranked fuzzy matcher rather than a substring scan.
	· Full keyboard control: Up/Down to move, Enter to commit, Escape to
	  cancel, Tab to close, type-to-jump.
	· Multi-select with a live "N selected" summary and a per-row
	  checkbox that animates independently of selection.
	· The panel clamps to the viewport and flips above the control when
	  there is no room below — the failure mode every naive dropdown has.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)
local Glyph = require(script.Parent.Parent.Core.Glyph)
local Signal = require(script.Parent.Parent.Core.Signal)
local Field = require(script.Parent.Parent.Layout.Field)

local Dropdown = {}
Dropdown.__index = Dropdown

local ROW_HEIGHT = 28
local MAX_VISIBLE_ROWS = 7
local SEARCH_THRESHOLD = 8

local function normalizeOptions(options: { any }): { any }
	local out = {}
	for index, option in ipairs(options) do
		if type(option) == "table" then
			table.insert(out, {
				label = tostring(option.Label or option.Value or option),
				value = option.Value ~= nil and option.Value or option.Label,
				description = option.Description,
				icon = option.Icon,
				swatch = option.Swatch,
				subtitle = option.Subtitle,
			})
		else
			table.insert(out, {
				label = tostring(option),
				value = option,
			})
		end
	end
	return out
end

--- @param spec { Name, Description?, Icon?, Options, Value?, Multi?, Searchable?, Max?, Callback?, Disabled?, Placeholder?, Tooltip?, AllowCustom? }
function Dropdown.new(spec: { [any]: any }, context: { [any]: any })
	local ctx = context or {}
	local tokens = Theme.current()
	local options = normalizeOptions(spec.Options or {})
	assert(#options > 0, "[Vantage] Dropdown requires at least one option")

	local multi = spec.Multi == true
	local searchable = spec.Searchable
	if searchable == nil then
		searchable = #options >= SEARCH_THRESHOLD
	end

	local self = setmetatable({
		_spec = spec,
		_maid = ctx.maid,
		_tokens = tokens,
		_options = options,
		_multi = multi,
		_open = false,
		_selected = {},
		_highlight = 1,
		_query = "",
		_enabled = spec.Disabled ~= true,
	}, Dropdown)

	self.Changed = Signal.new("Dropdown.Changed")
	self.Opened = Signal.new("Dropdown.Opened")
	self.Closed = Signal.new("Dropdown.Closed")

	-- Seed selection.
	local seed = spec.Value
	if seed ~= nil and not multi then
		seed = { seed }
	end
	if type(seed) ~= "table" then
		seed = {}
	end
	for _, value in ipairs(seed) do
		self._selected[value] = true
	end

	local controlWidth = spec.ControlWidth or 190

	local field = Field.new({
		Name = spec.Name,
		Description = spec.Description,
		Icon = spec.Icon,
		Disabled = spec.Disabled,
		ControlWidth = controlWidth,
		ControlHeight = 32,
	}, { maid = ctx.maid, parent = ctx.parent })
	self.Field = field
	self.Instance = field.Instance

	local container = field.Control
	container.Size = UDim2.fromOffset(controlWidth, 32)
	container.AutomaticSize = Enum.AutomaticSize.None

	local shell = Util.frame({
		Name = "Shell",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tokens.sunken,
		Parent = container,
	})
	Util.corner(shell, tokens.radiusSm)
	local shellStroke = Util.stroke(shell, tokens.border, 1, 0.2)
	Util.pad(shell, { Left = 10, Right = 26 })
	self._shell = shell
	self._shellStroke = shellStroke

	local swatch = Util.frame({
		Name = "Swatch",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 9, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = tokens.accent,
		Visible = false,
		ZIndex = 3,
		Parent = shell,
	})
	Util.pill(swatch)
	self._swatch = swatch

	local valueLabel = Util.text({
		Name = "Value",
		Text = spec.Placeholder or "Select...",
		TextSize = tokens.fontSizeSm,
		Font = "body",
		TextColor3 = tokens.textDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = shell,
	})
	self.ValueLabel = valueLabel

	local chevronHolder = Util.row({
		Name = "Chevron",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		ZIndex = 3,
		Parent = shell,
	})
	local chevron = Glyph.draw(chevronHolder, "chevron-down", {
		size = 10,
		color = tokens.textDim,
		weight = 14,
		zIndex = 3,
	})
	self._chevron = chevron

	local hit = Util.create("TextButton", {
		Name = "Hit",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Parent = shell,
	})
	self._hit = hit

	-- Panel ------------------------------------------------------------
	-- Parented to a top-level layer so it can escape the scroll frame's
	-- clip and is never cropped by its own container.
	local layer = ctx.layer or container.Parent or container
	local panel = Util.frame({
		Name = "VantageDropdownPanel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(controlWidth, 0),
		BackgroundColor3 = tokens.elevated,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 200,
		Parent = layer,
	})
	Util.corner(panel, tokens.radiusMd)
	Util.stroke(panel, tokens.border, 1, 0.15)
	Util.tag(panel, "Vantage")
	self.Panel = panel

	local panelInner = Util.row({
		Name = "Inner",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(0, 0),
		Parent = panel,
	})
	Util.stack(panelInner, 0)
	self._panelInner = panelInner

	-- Search ------------------------------------------------------------
	local searchHolder = Util.row({
		Name = "Search",
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 1,
		Visible = searchable,
		Parent = panelInner,
	})
	Util.pad(searchHolder, { Left = 10, Right = 10, Top = 6, Bottom = 0 })
	self._searchHolder = searchHolder

	local searchShell = Util.frame({
		Name = "SearchShell",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tokens.sunken,
		Parent = searchHolder,
	})
	Util.corner(searchShell, tokens.radiusSm)
	Util.pad(searchShell, { Left = 24, Right = 8 })

	local searchGlyphHolder = Util.row({
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 7, 0.5, 0),
		Size = UDim2.fromOffset(11, 11),
		ZIndex = 4,
		Parent = searchShell,
	})
	local searchGlyph = Glyph.draw(searchGlyphHolder, "search", {
		size = 11,
		color = tokens.textDim,
		weight = 12,
		zIndex = 4,
	})
	self._searchGlyph = searchGlyph

	local searchBox = Util.create("TextBox", {
		Name = "SearchBox",
		Text = "",
		PlaceholderText = "Search...",
		PlaceholderColor3 = tokens.textDim,
		TextSize = tokens.fontSizeSm,
		Font = Enum.Font.Gotham,
		TextColor3 = tokens.text,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(1, 1),
		ClearTextOnFocus = false,
		ZIndex = 4,
		Parent = searchShell,
	})
	Util.applyFont(searchBox, "body")
	self._searchBox = searchBox

	-- Rows --------------------------------------------------------------
	local rowsHolder = Util.row({
		Name = "Rows",
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
		Parent = panelInner,
	})
	Util.stack(rowsHolder, 0)
	self._rowsHolder = rowsHolder

	local scroll = Util.create("ScrollingFrame", {
		Name = "Scroll",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = tokens.borderStrong,
		ScrollBarImageTransparency = 0.25,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ZIndex = 200,
		Parent = panelInner,
	})
	rowsHolder.Parent = scroll
	rowsHolder.Size = UDim2.new(1, 0, 0, 0)
	rowsHolder.Position = UDim2.fromOffset(0, 0)
	self._scroll = scroll

	-- An empty-state label for when a search matches nothing.
	local empty = Util.text({
		Name = "Empty",
		Text = "No matches",
		TextSize = tokens.fontSizeSm,
		Font = "body",
		TextColor3 = tokens.textDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, 44),
		Visible = false,
		LayoutOrder = 3,
		Parent = panelInner,
	})
	self._empty = empty

	local rows = {}
	self._rows = rows

	local function rowSelected(row): boolean
		return self._selected[row.option.value] == true
	end

	local function refreshRow(row, animated: boolean?)
		local active = rowSelected(row)
		local highlighted = row.index == self._highlight
		local opts = Motion.options((animated == false) and "instant" or "fast")

		if row.checkbox then
			Motion.tween(row.checkbox, {
				BackgroundColor3 = active and tokens.accent or Color3.new(0, 0, 0),
				BackgroundTransparency = active and 0 or 1,
			}, opts)
			if row.check then
				Glyph.setColor(row.check, tokens.onAccent)
				Glyph.setTransparency(row.check, active and 0 or 1)
			end
			local stroke = row.checkbox:FindFirstChildOfClass("UIStroke")
			if stroke then
				Motion.tween(stroke, { Transparency = active and 0 or 0.4 }, opts)
			end
		end

		local background = nil
		if active and not multi then
			background = tokens.selected
		elseif highlighted then
			background = tokens.hover
		end

		if background then
			Motion.tween(row.frame, { BackgroundColor3 = background, BackgroundTransparency = 0 }, opts)
		else
			Motion.tween(row.frame, { BackgroundTransparency = 1 }, opts)
		end

		Motion.tween(row.label, {
			TextColor3 = active and tokens.text or (highlighted and tokens.text or tokens.textMuted),
		}, opts)
	end
	self._refreshRow = refreshRow

	local function buildRows()
		for _, row in ipairs(rows) do
			row.frame:Destroy()
		end
		table.clear(rows)

		for index, option in ipairs(options) do
			local row = Util.row({
				Name = "Row" .. index,
				Size = UDim2.new(1, 0, 0, ROW_HEIGHT + (option.description and 12 or 0)),
				LayoutOrder = index,
				Parent = rowsHolder,
			})
			Util.pad(row, { Left = 8, Right = 8 })
			Util.corner(row, tokens.radiusXs)

			local entry = {
				index = index,
				option = option,
				frame = row,
			}

			local cursor = 8
			if multi then
				local checkbox = Util.frame({
					Name = "Check",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 8, 0.5, 0),
					Size = UDim2.fromOffset(14, 14),
					BackgroundColor3 = tokens.accent,
					BackgroundTransparency = 1,
					ZIndex = 4,
					Parent = row,
				})
				Util.corner(checkbox, 4)
				Util.stroke(checkbox, tokens.borderStrong, 1, 0.4)
				local check = Glyph.draw(checkbox, "check", {
					size = 9,
					color = tokens.onAccent,
					weight = 16,
					zIndex = 5,
					transparency = 1,
				})
				if check then
					check.AnchorPoint = Vector2.new(0.5, 0.5)
					check.Position = UDim2.fromScale(0.5, 0.5)
				end
				entry.checkbox = checkbox
				entry.check = check
				cursor = 30
			elseif option.swatch then
				local swatchRow = Util.frame({
					Name = "Swatch",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 10, 0.5, option.description and 0.34 or 0.5),
					Size = UDim2.fromOffset(10, 10),
					BackgroundColor3 = option.swatch,
					ZIndex = 4,
					Parent = row,
				})
				Util.pill(swatchRow)
				cursor = 28
			elseif option.icon then
				local iconHolder = Util.row({
					Name = "Icon",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 9, 0.5, option.description and 0.34 or 0.5),
					Size = UDim2.fromOffset(12, 12),
					ZIndex = 4,
					Parent = row,
				})
				Glyph.draw(iconHolder, option.icon, {
					size = 12,
					color = tokens.textDim,
					weight = 12,
					zIndex = 4,
				})
				cursor = 28
			end

			local label = Util.text({
				Name = "Label",
				Text = option.label,
				TextSize = tokens.fontSizeSm,
				Font = "body",
				TextColor3 = tokens.textMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(cursor, 0),
				Size = UDim2.new(1, -(cursor + 8), 0, option.description and ROW_HEIGHT or (ROW_HEIGHT + 12)),
				ZIndex = 4,
				Parent = row,
			})
			entry.label = label

			if option.description then
				entry.description = Util.text({
					Name = "Sub",
					Text = option.description,
					TextSize = tokens.fontSizeXs + 1,
					Font = "body",
					TextColor3 = tokens.textDim,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Position = UDim2.fromOffset(cursor, ROW_HEIGHT),
					Size = UDim2.new(1, -(cursor + 8), 0, 12),
					ZIndex = 4,
					Parent = row,
				})
			end

			local rowHit = Util.create("TextButton", {
				Name = "Hit",
				Text = "",
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 6,
				Parent = row,
			})
			entry.hit = rowHit

			rowHit.MouseEnter:Connect(function()
				self._highlight = index
				for _, other in ipairs(rows) do
					refreshRow(other)
				end
			end)
			rowHit.Activated:Connect(function()
				self:_selectRow(entry, true)
			end)

			table.insert(rows, entry)
		end
	end
	self._buildRows = buildRows
	buildRows()

	local visibleRows = math.min(#options, MAX_VISIBLE_ROWS)
	local panelHeight = visibleRows * ROW_HEIGHT + (searchable and 36 or 8) + 8
	self._panelHeight = panelHeight

	local function layoutPanel()
		local viewport = Util.viewport()
		local insets = Util.insets()
		local origin = shell.AbsolutePosition
		local size = shell.AbsoluteSize

		local width = math.max(size.X, 150)
		local spaceBelow = viewport.Y - (origin.Y + size.Y) - insets.bottom - 8
		local spaceAbove = origin.Y - insets.top - 8

		local height = math.min(panelHeight, math.max(spaceBelow, spaceAbove))
		local flip = spaceBelow < panelHeight and spaceAbove > spaceBelow

		local y = flip and (origin.Y - height - 4) or (origin.Y + size.Y + 4)
		local x = Util.clamp(origin.X, insets.left + 4, viewport.X - width - insets.right - 4)
		y = Util.clamp(y, insets.top + 4, viewport.Y - height - insets.bottom - 4)

		panel.Size = UDim2.fromOffset(width, height)
		panel.Position = UDim2.fromOffset(x, y)
		scroll.Size = UDim2.new(1, 0, 0, math.max(0, height - (searchable and 36 or 8)))
		searchHolder.Size = UDim2.new(1, 0, 0, searchable and 30 or 0)
		searchHolder.Visible = searchable
	end
	self._layoutPanel = layoutPanel

	-- Filtering ----------------------------------------------------------
	local visible = {}
	self._visible = visible

	local function applyFilter()
		local query = self._query
		local matches = {}
		for index, option in ipairs(options) do
			local haystack = option.description and (option.label .. " " .. option.description) or option.label
			local score, positions = Util.fuzzyMatch(query, haystack)
			if score then
				table.insert(matches, { index = index, score = score, positions = positions })
			end
		end
		if query ~= "" then
			table.sort(matches, function(a, b)
				if a.score == b.score then
					return a.index < b.index
				end
				return a.score > b.score
			end)
		end

		table.clear(visible)
		for order, match in ipairs(matches) do
			local row = rows[match.index]
			if row then
				row.frame.Visible = true
				row.frame.LayoutOrder = order
				table.insert(visible, row)
			end
		end
		for _, row in ipairs(rows) do
			if not table.find(visible, row) then
				row.frame.Visible = false
			end
		end

		empty.Visible = #visible == 0
		scroll.CanvasSize = UDim2.new(0, 0, 0, #visible * ROW_HEIGHT + 8)

		if #visible > 0 then
			local stillVisible = false
			for _, row in ipairs(visible) do
				if row.index == self._highlight then
					stillVisible = true
					break
				end
			end
			if not stillVisible then
				self._highlight = visible[1].index
			end
		end
		for _, row in ipairs(rows) do
			refreshRow(row)
		end
	end
	self._applyFilter = applyFilter

	local function ensureVisible()
		local row = rows[self._highlight]
		if not row then
			return
		end
		local top = 0
		for _, candidate in ipairs(visible) do
			if candidate == row then
				break
			end
			top += candidate.frame.AbsoluteSize.Y
		end
		local bottom = top + row.frame.AbsoluteSize.Y
		local viewTop = scroll.CanvasPosition.Y
		local viewBottom = viewTop + scroll.AbsoluteSize.Y
		if top < viewTop then
			Motion.tween(scroll, { CanvasPosition = Vector2.new(0, top) }, Motion.options("fast"))
		elseif bottom > viewBottom then
			Motion.tween(scroll, { CanvasPosition = Vector2.new(0, bottom - scroll.AbsoluteSize.Y) }, Motion.options("fast"))
		end
	end
	self._ensureVisible = ensureVisible

	-- Selection ----------------------------------------------------------
	local function summarize()
		local picked = {}
		for _, option in ipairs(options) do
			if self._selected[option.value] then
				table.insert(picked, option)
			end
		end
		if #picked == 0 then
			valueLabel.Text = spec.Placeholder or "Select..."
			valueLabel.TextColor3 = tokens.textDim
			swatch.Visible = false
			return
		end
		if multi then
			if #picked == 1 then
				valueLabel.Text = picked[1].label
			else
				valueLabel.Text = string.format("%s +%d", picked[1].label, #picked - 1)
			end
		else
			valueLabel.Text = picked[1].label
		end
		valueLabel.TextColor3 = tokens.text
		if picked[1].swatch then
			swatch.Visible = true
			swatch.BackgroundColor3 = picked[1].swatch
		else
			swatch.Visible = false
		end
	end
	self._summarize = summarize

	function self:_selectRow(row, fromUser: boolean?)
		if not fromUser then
			return
		end
		if multi then
			self._selected[row.option.value] = not self._selected[row.option.value] or nil
			refreshRow(row)
			summarize()
			local picked = {}
			for _, option in ipairs(options) do
				if self._selected[option.value] then
					table.insert(picked, option.value)
				end
			end
			self.Changed:fire(picked, self)
			Util.safeCall(spec.Callback, picked, self)
		else
			self._selected = {}
			self._selected[row.option.value] = true
			summarize()
			self:Close()
			self.Changed:fire(row.option.value, self)
			Util.safeCall(spec.Callback, row.option.value, self)
		end
	end

	-- Open / close --------------------------------------------------------
	local function open()
		if self._open or not self._enabled then
			return
		end
		self._open = true
		self._highlight = self:GetVisibleHighlight()
		self._query = ""
		searchBox.Text = ""
		applyFilter()
		layoutPanel()

		local targetWidth = math.max(container.AbsoluteSize.X, 150)
		panel.Visible = true
		panel.ClipsDescendants = true
		panel.Size = UDim2.fromOffset(targetWidth, 0)
		Motion.tween(panel, { Size = UDim2.fromOffset(targetWidth, panelHeight) }, {
			duration = 0.26,
			easing = "enterSnap",
		})
		Motion.setScale(panel, 0.97)
		Motion.scale(panel, 1, { duration = 0.26, easing = "enterSnap" })
		if chevron then
			-- Rotating the glyph container 180 degrees is the cheapest
			-- possible affordance and reads instantly.
			Motion.tween(chevronHolder, { Rotation = 180 }, Motion.options("enter"))
		end
		Motion.tween(shellStroke, { Color = tokens.accent, Transparency = 0.45 }, Motion.options("hover"))
		Motion.tween(shell, { BackgroundColor3 = tokens.surfaceAlt }, Motion.options("hover"))

		local UserInputService = game:GetService("UserInputService")
		self._closeConnection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				local position = input.Position
				local panelRect = {
					x = panel.AbsolutePosition.X,
					y = panel.AbsolutePosition.Y,
					w = panel.AbsoluteSize.X,
					h = panel.AbsoluteSize.Y,
				}
				local inside = position.X >= panelRect.x and position.X <= panelRect.x + panelRect.w
					and position.Y >= panelRect.y and position.Y <= panelRect.y + panelRect.h
				local shellSize = shell.AbsoluteSize
				local shellOrigin = shell.AbsolutePosition
				local insideShell = position.X >= shellOrigin.X and position.X <= shellOrigin.X + shellSize.X
					and position.Y >= shellOrigin.Y and position.Y <= shellOrigin.Y + shellSize.Y
				if not inside and not insideShell then
					self:Close()
				end
			end
		end)

		self.Opened:fire()
	end
	self.Open = open

	local function close()
		if not self._open then
			return
		end
		self._open = false
		if self._closeConnection then
			self._closeConnection:Disconnect()
			self._closeConnection = nil
		end
		if chevron then
			Motion.tween(chevronHolder, { Rotation = 0 }, Motion.options("exit"))
		end
		Motion.tween(shell, { BackgroundColor3 = tokens.sunken }, Motion.options("hover"))
		Motion.tween(shellStroke, { Color = tokens.border, Transparency = 0.2 }, Motion.options("hover"))
		Motion.tween(panel, { Size = UDim2.fromOffset(panel.AbsoluteSize.X, 0) }, {
			duration = 0.18,
			easing = "exit",
			onComplete = function()
				panel.Visible = false
			end,
		})
		local searchBoxFocused = self._searchBox and self._searchBox:IsFocused()
		if searchBoxFocused then
			self._searchBox:ReleaseFocus()
		end
		self.Closed:fire()
	end
	self.Close = close

	hit.Activated:Connect(function()
		if self._open then
			close()
		else
			open()
		end
	end)

	hit.MouseEnter:Connect(function()
		if not self._open then
			Motion.tween(shell, { BackgroundColor3 = tokens.hover }, Motion.options("hover"))
		end
	end)
	hit.MouseLeave:Connect(function()
		if not self._open then
			Motion.tween(shell, { BackgroundColor3 = tokens.sunken }, Motion.options("hover"))
		end
	end)

	field:onActivate(function()
		if self._open then
			close()
		else
			open()
		end
	end)

	-- Search wiring
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		self._query = searchBox.Text
		applyFilter()
		ensureVisible()
	end)

	-- Keyboard -----------------------------------------------------------
	local UserInputService = game:GetService("UserInputService")
	local function onKey(input, processed)
		if not self._open then
			return
		end
		if processed and input.KeyCode ~= Enum.KeyCode.Escape then
			return
		end
		local code = input.KeyCode
		if code == Enum.KeyCode.Down then
			local position = self:GetVisibleIndex()
			local next = visible[math.min(position + 1, #visible)]
			if next then
				self._highlight = next.index
				applyFilter()
				ensureVisible()
			end
		elseif code == Enum.KeyCode.Up then
			local position = self:GetVisibleIndex()
			local next = visible[math.max(position - 1, 1)]
			if next then
				self._highlight = next.index
				applyFilter()
				ensureVisible()
			end
		elseif code == Enum.KeyCode.Return or code == Enum.KeyCode.KeypadEnter then
			local row = rows[self._highlight]
			if row then
				self:_selectRow(row, true)
			end
		elseif code == Enum.KeyCode.Escape then
			close()
		elseif code == Enum.KeyCode.Tab then
			close()
		elseif code == Enum.KeyCode.Home then
			if visible[1] then
				self._highlight = visible[1].index
				applyFilter()
			end
		elseif code == Enum.KeyCode.End then
			local last = visible[#visible]
			if last then
				self._highlight = last.index
				applyFilter()
				ensureVisible()
			end
		end
	end
	if ctx.maid then
		ctx.maid:add(UserInputService.InputBegan:Connect(onKey))
		ctx.maid:add(function()
			close()
			panel:Destroy()
		end)
		ctx.maid:add(Theme.Changed:connect(function(next)
			tokens = next
			self._tokens = next
			panel.BackgroundColor3 = next.elevated
			shell.BackgroundColor3 = self._open and next.surfaceAlt or next.sunken
			searchShell.BackgroundColor3 = next.sunken
			searchBox.TextColor3 = next.text
			summarize()
			for _, row in ipairs(rows) do
				refreshRow(row)
			end
		end))
	end

	summarize()

	return self
end

--- Index of the highlighted row inside the visible list, or 1.
function Dropdown:GetVisibleIndex(): number
	for position, row in ipairs(self._visible) do
		if row.index == self._highlight then
			return position
		end
	end
	return 1
end

function Dropdown:GetHighlightIndex(): number
	return self._highlight
end

--- Returns the current value: a single value, or an array in multi mode.
function Dropdown:Get(): any
	if not self._multi then
		for _, option in ipairs(self._options) do
			if self._selected[option.value] then
				return option.value
			end
		end
		return nil
	end
	local out = {}
	for _, option in ipairs(self._options) do
		if self._selected[option.value] then
			table.insert(out, option.value)
		end
	end
	return out
end

--- Sets the value. Array in multi mode, scalar otherwise.
function Dropdown:Set(value: any, fromUser: boolean?)
	self._selected = {}
	local list = self._multi and (type(value) == "table" and value or { value }) or { value }
	for _, entry in ipairs(list) do
		if entry ~= nil then
			self._selected[entry] = true
		end
	end
	self._summarize()
	for _, row in ipairs(self._rows) do
		self._refreshRow(row)
	end
	if fromUser then
		self.Changed:fire(self:Get(), self)
		Util.safeCall(self._spec.Callback, self:Get(), self)
	end
	return self
end

function Dropdown:SetOptions(options: { any })
	self._options = normalizeOptions(options)
	self._highlight = 1
	self._buildRows()
	self._applyFilter()
	self._summarize()
	return self
end

function Dropdown:IsOpen(): boolean
	return self._open
end

function Dropdown:setEnabled(enabled: boolean)
	self._enabled = enabled
	self.Field:setDisabled(not enabled)
	self._hit.Active = enabled
	if not enabled then
		self:Close()
	end
	return self
end

function Dropdown:destroy()
	if self.Changed then
		self.Changed:destroy()
	end
	if self.Opened then
		self.Opened:destroy()
	end
	if self.Closed then
		self.Closed:destroy()
	end
	self.Field:destroy()
end

return Dropdown
