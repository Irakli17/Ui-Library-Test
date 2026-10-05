--!nonstrict
--[[
	Vantage 1.0.0 · Layout/Section
	------------------------------------------------------------------
	A titled, collapsible group of controls.

	Collapsing animates real height rather than toggling visibility,
	which is the difference between a panel that folds and a panel that
	blinks. The measurement happens on the frame after expansion begins,
	so opening a section full of lazily-sized controls still lands on the
	correct height on the first try.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)
local Glyph = require(script.Parent.Parent.Core.Glyph)
local Signal = require(script.Parent.Parent.Core.Signal)
local Elements = require(script.Parent.Elements)

local Section = {}
Section.__index = Section

--- @param spec { Name, Description?, Icon?, Collapsed?, Order?, Footer?, Flush? }
--- @param context { maid, parent, window, tab }
function Section.new(spec: { [any]: any }, context: { [any]: any })
	local tokens = Theme.current()

	local self = setmetatable({
		_spec = spec,
		_maid = context.maid,
		_tokens = tokens,
		_collapsed = spec.Collapsed == true,
		_expanded = not (spec.Collapsed == true),
		_maidChildren = require(script.Parent.Parent.Core.Maid).new("section"),
		_window = context.window,
		_tab = context.tab,
	}, Section)

	self.Toggled = Signal.new("Section.Toggled")

	-- A CanvasGroup, because the window fades a whole section on tab switch
	-- through the group's transparency.
	local root = Util.group({
		Name = "VantageSection",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = spec.Order or 1,
		Parent = context.parent,
	})
	Util.tag(root, "Vantage")
	self.Instance = root

	local card = Util.frame({
		Name = "Card",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = spec.Flush and tokens.surface or tokens.surfaceAlt,
		BackgroundTransparency = spec.Flush and 1 or 0,
		Parent = root,
	})
	Util.corner(card, tokens.radiusLg)
	if not spec.Flush then
		Util.stroke(card, tokens.borderSubtle, 1, 0.35)
	end
	Util.clipRounded(card, tokens.radiusLg)
	local cardStack = Util.stack(card, 0)
	cardStack.Padding = UDim.new(0, 0)
	self.Card = card

	-- Header ------------------------------------------------------------
	local header = Util.row({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, spec.Description and 52 or 42),
		LayoutOrder = 1,
		Parent = card,
	})
	Util.pad(header, { Left = 16, Right = 12, Top = 10, Bottom = 10 })
	self.Header = header

	local headerStack = Util.stack(header, 2)
	headerStack.HorizontalAlignment = Enum.HorizontalAlignment.Left

	local titleRow = Util.row({
		Name = "TitleRow",
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 1,
		Parent = header,
	})
	Util.list(titleRow, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	if spec.Icon then
		local iconHolder = Util.row({
			Name = "Icon",
			Size = UDim2.fromOffset(14, 14),
			LayoutOrder = 1,
			Parent = titleRow,
		})
		local glyph = Glyph.draw(iconHolder, spec.Icon, {
			size = 14,
			color = tokens.accent,
			weight = 12,
			zIndex = 4,
		})
		self.Icon = glyph
	end

	local title = Util.text({
		Name = "Title",
		Text = spec.Name or "Section",
		TextSize = tokens.fontSizeMd + 1,
		Font = "subheading",
		TextColor3 = tokens.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = titleRow,
	})
	self.Title = title

	self.Badge = nil
	if spec.Badge then
		local badgeHolder = Util.row({
			Name = "BadgeHolder",
			Size = UDim2.new(0, 0, 0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 3,
			Parent = titleRow,
		})
		self.Badge = Elements.badge({
			Text = spec.Badge,
			Tone = spec.BadgeTone or "accent",
		}, { parent = badgeHolder, maid = self._maid })
	end

	if spec.Description then
		local description = Util.text({
			Name = "Description",
			Text = spec.Description,
			TextSize = tokens.fontSizeSm,
			Font = "body",
			TextColor3 = tokens.textDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = header,
		})
		self.Description = description
	end

	local chevronHolder = Util.row({
		Name = "Chevron",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0, spec.Description and 26 or 21),
		Size = UDim2.fromOffset(14, 14),
		ZIndex = 5,
		Parent = header,
	})
	local chevron = Glyph.draw(chevronHolder, "chevron-down", {
		size = 14,
		color = tokens.textDim,
		weight = 12,
		zIndex = 5,
	})
	self._chevron = chevron
	self._chevronHolder = chevronHolder

	local headerHit = Util.create("TextButton", {
		Name = "HeaderHit",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Parent = header,
	})
	self._headerHit = headerHit

	-- Body --------------------------------------------------------------
	local body = Util.row({
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = card,
	})
	Util.stack(body, 2)
	Util.pad(body, { Left = 16, Right = 16, Top = 2, Bottom = 14 })
	self.Body = body
	self._body = body

	self._childrenMaid = require(script.Parent.Parent.Core.Maid).new("sectionChildren")
	local childContext = {
		maid = self._childrenMaid,
		parent = body,
		window = context.window,
		tab = context.tab,
		section = self,
		layer = context.layer or body,
	}
	self.Context = childContext

	-- Collapse ----------------------------------------------------------
	local collapseTween

	local function measureHeight(): number
		return body.AbsoluteSize.Y
	end

	local function expand(animated: boolean?)
		if self._expanded then
			return
		end
		self._expanded = true
		self._collapsed = false
		body.Visible = true
		body.ClipsDescendants = true

		if animated == false or Motion.getReducedMotion() then
			body.AutomaticSize = Enum.AutomaticSize.Y
			body.Size = UDim2.new(1, 0, 0, 0)
			body.ClipsDescendants = false
			if chevron then
				chevronHolder.Rotation = 0
			end
			return
		end

		-- Let the layout settle for one frame so the measured height is
		-- final; animating from a guessed height is what makes naive
		-- accordions jump at the end of the transition.
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.Size = UDim2.new(1, 0, 0, 0)
		Motion.setScale(body, 1)
		task.defer(function()
			if not self._expanded then
				return
			end
			local target = measureHeight()
			body.AutomaticSize = Enum.AutomaticSize.None
			body.Size = UDim2.new(1, 0, 0, 0)
			if collapseTween then
				collapseTween:cancel()
			end
			collapseTween = Motion.tween(body, { Size = UDim2.new(1, 0, 0, target) }, {
				duration = 0.3,
				easing = "enterSnap",
				onUpdate = function(alpha)
					for index, child in ipairs(body:GetChildren()) do
						if child:IsA("GuiObject") then
							child.Visible = alpha > 0.02
						end
					end
				end,
				onComplete = function()
					body.AutomaticSize = Enum.AutomaticSize.Y
					body.Size = UDim2.new(1, 0, 0, 0)
					body.ClipsDescendants = false
					for _, child in ipairs(body:GetChildren()) do
						if child:IsA("GuiObject") then
							child.Visible = true
						end
					end
				end,
			})
		end)

		if chevron then
			Motion.tween(chevronHolder, { Rotation = 0 }, Motion.options("enter"))
		end
	end

	local function collapse(animated: boolean?)
		if not self._expanded then
			return
		end
		self._expanded = false
		self._collapsed = true

		if collapseTween then
			collapseTween:cancel()
			collapseTween = nil
		end

		if animated == false or Motion.getReducedMotion() then
			body.AutomaticSize = Enum.AutomaticSize.None
			body.Size = UDim2.new(1, 0, 0, 0)
			body.Visible = false
			if chevron then
				chevronHolder.Rotation = -90
			end
			return
		end

		local current = measureHeight()
		body.AutomaticSize = Enum.AutomaticSize.None
		body.Size = UDim2.new(1, 0, 0, current)
		body.ClipsDescendants = true
		collapseTween = Motion.tween(body, { Size = UDim2.new(1, 0, 0, 0) }, {
			duration = 0.22,
			easing = "exit",
			onComplete = function()
				body.Visible = false
				body.AutomaticSize = Enum.AutomaticSize.Y
				body.Size = UDim2.new(1, 0, 0, 0)
				body.ClipsDescendants = false
				collapseTween = nil
			end,
		})

		if chevron then
			Motion.tween(chevronHolder, { Rotation = -90 }, Motion.options("exit"))
		end
	end
	self._expand = expand
	self._collapse = collapse
	self._measureHeight = measureHeight

	headerHit.Activated:Connect(function()
		self:SetCollapsed(not self._collapsed, true)
	end)
	headerHit.MouseEnter:Connect(function()
		Motion.tween(card, { BackgroundColor3 = Util.lighten(tokens.surfaceAlt, 0.02) }, Motion.options("hover"))
		Motion.tween(chevronHolder, { BackgroundTransparency = 1 }, Motion.options("hover"))
	end)
	headerHit.MouseLeave:Connect(function()
		Motion.tween(card, { BackgroundColor3 = spec.Flush and tokens.surface or tokens.surfaceAlt }, Motion.options("hover"))
	end)

	-- Footer ------------------------------------------------------------
	if spec.Footer then
		local footer = Util.row({
			Name = "Footer",
			Size = UDim2.new(1, 0, 0, 38),
			LayoutOrder = 3,
			Parent = card,
		})
		Util.pad(footer, { Left = 16, Right = 16, Top = 8, Bottom = 10 })
		Util.list(footer, {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
		self.Footer = footer
		childContext.footer = footer
	end

	if self._collapsed then
		body.Visible = false
		if chevron then
			chevronHolder.Rotation = -90
		end
	end

	if self._maid then
		self._maid:add(Theme.Changed:connect(function(next)
			tokens = next
			self._tokens = next
			card.BackgroundColor3 = spec.Flush and next.surface or next.surfaceAlt
			cardStack.Padding = UDim.new(0, 0)
			local corner = card:FindFirstChildOfClass("UICorner")
			if corner then
				corner.CornerRadius = UDim.new(0, next.radiusLg)
			end
			title.TextColor3 = next.text
			title.TextSize = next.fontSizeMd + 1
			if self.Description then
				self.Description.TextColor3 = next.textDim
				self.Description.TextSize = next.fontSizeSm
			end
			if self.Icon then
				Glyph.setColor(self.Icon, next.accent)
			end
			if chevron then
				Glyph.setColor(chevron, next.textDim)
			end
		end))
		self._maid:add(function()
			self._childrenMaid:destroy()
		end)
	end

	return self
end

--- Opens or closes the section.
function Section:SetCollapsed(collapsed: boolean, animated: boolean?)
	if self._collapsed == collapsed then
		return self
	end
	if collapsed then
		self._collapse(animated ~= false)
	else
		self._expand(animated ~= false)
	end
	if animated then
		self.Toggled:fire(collapsed, self)
	end
	return self
end

function Section:IsCollapsed(): boolean
	return self._collapsed
end

--[[ Components ----------------------------------------------------- ]]

-- A section owns its controls. The documented shape is `section:Toggle{…}`,
-- so the factory set the tab exposes is mounted here as well — parented to
-- the section body and owned by the section's own maid. Collapsing and
-- destroying therefore tear down exactly what the section built.

local Button = require(script.Parent.Parent.Primitives.Button)
local Toggle = require(script.Parent.Parent.Primitives.Toggle)
local Slider = require(script.Parent.Parent.Primitives.Slider)
local Dropdown = require(script.Parent.Parent.Primitives.Dropdown)
local Input = require(script.Parent.Parent.Primitives.Input)
local Keybind = require(script.Parent.Parent.Primitives.Keybind)
local Segmented = require(script.Parent.Parent.Primitives.Segmented)
local Progress = require(script.Parent.Parent.Primitives.Progress)

--- Internal: remembers a component so `destroy` can report what existed.
function Section:_mount(object: any): any
	if type(object) == "table" and object.Instance then
		self._mounted = self._mounted or {}
		table.insert(self._mounted, object)
	end
	return object
end

--- Context handed to every control the section builds.
function Section:_childContext(): { [any]: any }
	local window = self._window
	return {
		maid = self._childrenMaid,
		parent = self.Body,
		tooltip = window and window.Tooltip or nil,
		window = window,
		section = self,
		tab = self._tab,
		layer = self.Context and self.Context.layer or self.Body,
	}
end

function Section:Button(spec: any): any
	local options = table.clone(spec or {})
	if options.Variant == nil then
		options.Variant = "secondary"
	end
	return self:_mount(Button.new(options, self:_childContext()))
end

function Section:Toggle(spec: any): any
	return self:_mount(Toggle.new(spec, self:_childContext()))
end

function Section:Slider(spec: any): any
	return self:_mount(Slider.new(spec, self:_childContext()))
end

function Section:Dropdown(spec: any): any
	return self:_mount(Dropdown.new(spec, self:_childContext()))
end

function Section:Input(spec: any): any
	return self:_mount(Input.new(spec, self:_childContext()))
end

function Section:Keybind(spec: any): any
	return self:_mount(Keybind.new(spec, self:_childContext()))
end

function Section:Segmented(spec: any): any
	return self:_mount(Segmented.new(spec, self:_childContext()))
end

function Section:Progress(spec: any): any
	return self:_mount(Progress.new(spec, self:_childContext()))
end

--[[ Non-interactive elements ---------------------------------------- ]]

local function elementContext(self): any
	return { parent = self.Body, maid = self._childrenMaid }
end

function Section:Paragraph(spec: any): any
	return self:_mount(Elements.paragraph(spec, elementContext(self)))
end

function Section:Heading(spec: any): any
	return self:_mount(Elements.heading(spec, elementContext(self)))
end

function Section:Overline(spec: any): any
	return self:_mount(Elements.overline(spec, elementContext(self)))
end

function Section:Divider(spec: any?): any
	return self:_mount(Elements.divider(spec or {}, elementContext(self)))
end

function Section:Spacer(size: number?): any
	return Elements.spacer({ Size = size or 8 }, elementContext(self))
end

function Section:Image(spec: any): any
	return self:_mount(Elements.image(spec, elementContext(self)))
end

function Section:Columns(spec: any): any
	return Elements.columns(spec or {}, elementContext(self))
end

--- A horizontally aligned row of buttons.
function Section:ButtonRow(spec: { [any]: any }?): any
	local options = spec or {}
	local row = Util.row({
		Name = "VantageButtonRow",
		Size = UDim2.new(1, 0, 0, 32),
		Parent = self.Body,
	})
	Util.list(row, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, options.Gap or 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = options.Align == "right" and Enum.HorizontalAlignment.Right
			or (options.Align == "center" and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left),
	})
	local context = self:_childContext()
	context.parent = row
	return {
		Instance = row,
		Button = function(_, buttonSpec)
			return Button.new(buttonSpec, context)
		end,
	}
end

--- A labelled readout cluster, for "About" sections.
function Section:Stats(stats: { any }): any
	local row = Util.row({
		Name = "VantageStats",
		Size = UDim2.new(1, 0, 0, 16),
		Parent = self.Body,
	})
	Util.list(row, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 16),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	local built = {}
	for index, entry in ipairs(stats) do
		table.insert(built, Elements.stat({
			Label = entry.Label,
			Value = entry.Value,
			Tone = entry.Tone,
			LayoutOrder = index,
		}, { parent = row, maid = self._childrenMaid }))
	end
	return { Instance = row, Items = built }
end

--- Adds an already-built instance (or component) to the section body.
function Section:Add(instance: any): any
	instance.Parent = self.Body
	return instance
end

--- Re-measures the section. Call after content changed size outside of
--- the normal layout flow (for example, swapping a child's text).
function Section:Refresh()
	if not self._collapsed then
		local body = self._body
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.Size = UDim2.new(1, 0, 0, 0)
	end
	return self
end

function Section:destroy()
	if self.Toggled then
		self.Toggled:destroy()
	end
	self._childrenMaid:destroy()
	if self.Instance then
		Motion.cancelAll(self.Instance)
		self.Instance:Destroy()
		self.Instance = nil
	end
end

return Section
