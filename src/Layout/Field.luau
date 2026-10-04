--!nonstrict
--[[
	Vantage 1.0.0 · Layout/Field
	------------------------------------------------------------------
	The row scaffold every settings control sits in.

	    [ icon ]  Label                       [     control    ]
	              Supporting description

	Owns the three things individual controls should never have to
	reimplement:

	· Responsive layout. Below `STACK_BREAKPOINT` the control drops onto
	  its own line instead of being crushed. This is what makes one
	  component definition work on a 400px phone and a 4K monitor.
	· Label semantics. Clicking the label activates the control, which
	  every desktop settings panel does and almost no Roblox UI does.
	· Row height. A spacer inside the label column reserves exactly the
	  space the control occupies, so `AutomaticSize.Y` on the row is
	  always correct with no manual measurement and no layout thrash.

	Layout strategy: the control is absolutely positioned, never part of
	a list layout. That removes the flex-sizing problem entirely and
	keeps the row's automatic height a pure function of the label column.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)
local Glyph = require(script.Parent.Parent.Core.Glyph)

local Field = {}
Field.__index = Field

--- Width below which the control stacks under the label.
Field.STACK_BREAKPOINT = 236
--- Horizontal gap between label column and control.
Field.GAP = 14
--- Extra vertical gap when stacked.
Field.STACK_GAP = 8

--- @param spec { Name, Description?, Icon?, Disabled?, ControlWidth?, MinHeight?, Align? }
--- @param context { maid?, parent }
function Field.new(spec: { [any]: any }, context: { [any]: any })
	local tokens = Theme.current()
	local maid = context.maid

	local self = setmetatable({
		_spec = spec,
		_maid = maid,
		_tokens = tokens,
		_stacked = false,
		_disabled = spec.Disabled == true,
	}, Field)

	local root = Util.frame({
		Name = "VantageField",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = context.parent,
	})
	Util.tag(root, "Vantage")
	self.Instance = root

	-- A floor height keeps single- and multi-line rows on the same
	-- rhythm so mixed content still aligns.
	local floor = Util.frame({
		Name = "Floor",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, spec.MinHeight or tokens.controlLg),
		Parent = root,
	})
	floor.ZIndex = 0
	self._floor = floor

	local info = Util.row({
		Name = "Info",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	})
	Util.stack(info, 2)
	local infoPadding = Util.pad(info, { Top = 0, Bottom = 0, Left = 0, Right = Field.GAP })
	info.ZIndex = 2
	self.Info = info
	self._infoPadding = infoPadding

	-- Label row: optional icon + text.
	local labelRow = Util.row({
		Name = "LabelRow",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = info,
	})
	Util.list(labelRow, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	if spec.Icon then
		local iconHolder = Util.row({
			Name = "Icon",
			Size = UDim2.fromOffset(14, 18),
			LayoutOrder = 1,
			Parent = labelRow,
		})
		local icon = Glyph.draw(iconHolder, spec.Icon, {
			size = 14,
			color = tokens.textDim,
			weight = 11,
			zIndex = 3,
			position = UDim2.fromOffset(0, 2),
		})
		self.Icon = icon
	end

	local label = Util.text({
		Name = "Label",
		Text = spec.Name or "",
		TextSize = tokens.fontSizeMd,
		Font = "bodyMedium",
		TextColor3 = spec.Disabled and tokens.textDim or tokens.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		Size = UDim2.new(0, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = 2,
		Parent = labelRow,
	})
	self.Label = label
	if spec.RichText then
		label.RichText = true
	end

	local description = Util.text({
		Name = "Description",
		Text = spec.Description or "",
		TextSize = tokens.fontSizeSm,
		Font = "body",
		TextColor3 = tokens.textDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Visible = (spec.Description ~= nil and spec.Description ~= ""),
		Parent = info,
	})
	self.Description = description

	-- Reserves the control's footprint inside the label column so the
	-- row's automatic height is always right.
	local spacer = Util.row({
		Name = "Spacer",
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 3,
		Parent = info,
	})
	self._spacer = spacer

	local status = Util.text({
		Name = "Status",
		Text = "",
		TextSize = tokens.fontSizeSm,
		Font = "body",
		TextColor3 = tokens.danger,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Visible = false,
		Parent = info,
	})
	self.Status = status

	local controlHost = Util.row({
		Name = "Control",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, spec.ControlWidth or 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Parent = root,
	})
	controlHost.ZIndex = 3
	self.Control = controlHost

	-- Label hit zone: activates the control.
	local hit = Util.create("TextButton", {
		Name = "LabelHit",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AutoButtonColor = false,
		ZIndex = 4,
		Parent = info,
	})
	self._hit = hit

	local activations = {}
	self._activations = activations

	local function measure()
		local available = root.AbsoluteSize.X
		local controlSize = controlHost.AbsoluteSize
		local stacked = available > 0 and available < Field.STACK_BREAKPOINT
		local controlWidth = controlSize.X
		local controlHeight = controlSize.Y

		if controlHeight <= 0 and controlWidth <= 0 then
			return
		end

		if stacked == self._stacked and self._controlHeight == controlHeight
			and self._controlWidth == controlWidth and available == self._measuredWidth
		then
			return
		end

		self._stacked = stacked
		self._controlHeight = controlHeight
		self._controlWidth = controlWidth
		self._measuredWidth = available

		if stacked then
			infoPadding.PaddingRight = UDim.new(0, 0)
			spacer.Size = UDim2.new(1, 0, 0, controlHeight + Field.STACK_GAP)
			controlHost.AnchorPoint = Vector2.new(0, 0)
			controlHost.Position = UDim2.new(0, 0, 0, info.AbsoluteSize.Y)
			controlHost.Size = UDim2.new(1, 0, 0, controlHeight)
		else
			infoPadding.PaddingRight = UDim.new(0, controlWidth + Field.GAP)
			spacer.Size = UDim2.new(1, 0, 0, 0)
			controlHost.AnchorPoint = Vector2.new(1, 0)
			controlHost.Position = UDim2.new(1, 0, 0, 0)
			controlHost.Size = UDim2.new(0, controlWidth, 0, controlHeight)
		end
	end

	self._measure = measure

	local function scheduleMeasure()
		-- One deferred pass per frame: a layout change usually fires
		-- several AbsoluteSize signals, and re-measuring each time would
		-- thrash the layout solver.
		if self._measureQueued then
			return
		end
		self._measureQueued = true
		task.defer(function()
			self._measureQueued = false
			measure()
		end)
	end

	if maid then
		maid:add(root:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleMeasure))
		maid:add(controlHost:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleMeasure))
		maid:add(info:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleMeasure))
		maid:add(Theme.Changed:connect(function(_, changed)
			if changed == nil or changed.controlMd ~= nil or changed.fontSizeMd ~= nil then
				scheduleMeasure()
			end
		end))
	end

	-- Hover affordance on the label.
	local hovering = false
	local function refreshLabelColor()
		local tokensNow = self._tokens
		local target
		if self._statusLevel then
			target = ({
				error = tokensNow.danger,
				warning = tokensNow.warning,
				success = tokensNow.success,
				info = tokensNow.info,
			})[self._statusLevel] or tokensNow.text
		elseif self._disabled then
			target = tokensNow.textDim
		elseif hovering then
			target = tokensNow.accentHover
		else
			target = tokensNow.text
		end
		Motion.tween(label, { TextColor3 = target }, Motion.options("hover"))
	end
	self._refreshLabelColor = refreshLabelColor

	hit.MouseEnter:Connect(function()
		hovering = true
		refreshLabelColor()
	end)
	hit.MouseLeave:Connect(function()
		hovering = false
		refreshLabelColor()
	end)
	hit.Activated:Connect(function()
		if self._disabled then
			return
		end
		for _, callback in ipairs(self._activations) do
			Util.safeCall(callback)
		end
	end)

	scheduleMeasure()
	task.delay(0.05, measure)

	return self
end

--- Registers a callback fired when the label is clicked.
function Field:onActivate(callback: () -> ())
	table.insert(self._activations, callback)
	return self
end

--- Adds a connection to this field's lifetime.
function Field:addConnection(connection: any)
	if self._maid then
		self._maid:add(connection)
	end
	return connection
end

--- Enables or disables the row.
function Field:setDisabled(disabled: boolean)
	if self._disabled == disabled then
		return self
	end
	self._disabled = disabled
	self._hit.Active = not disabled
	if self._refreshLabelColor then
		self._refreshLabelColor()
	end
	if self.Icon then
		Glyph.setTransparency(self.Icon, disabled and 0.5 or 0)
	end
	if self._onDisabled then
		self._onDisabled(disabled)
	end
	return self
end

function Field:isDisabled(): boolean
	return self._disabled
end

--- Replaces the description text.
function Field:setDescription(text: string?)
	local has = text ~= nil and text ~= ""
	if self.Description.Visible ~= has then
		self.Description.Visible = has
		self._measure()
	end
	self.Description.Text = text or ""
	return self
end

--- Renames the label.
function Field:setLabel(text: string)
	self.Label.Text = text
	self._measure()
	return self
end

--- Inline validation feedback. `level` is one of
--- `"error" | "warning" | "success" | "info" | nil`.
function Field:setStatus(level: string?, message: string?)
	self._statusLevel = level
	local tokens = self._tokens
	local hasMessage = message ~= nil and message ~= ""
	local colors = {
		error = tokens.danger,
		warning = tokens.warning,
		success = tokens.success,
		info = tokens.info,
	}
	self.Status.Text = message or ""
	self.Status.TextColor3 = colors[level or ""] or tokens.textMuted
	if self.Status.Visible ~= hasMessage then
		self.Status.Visible = hasMessage
		self._measure()
	end
	if self._refreshLabelColor then
		self._refreshLabelColor()
	end
	return self
end

--- Hook for subclasses that need to react to disabled state.
function Field:onDisabledChanged(callback: (boolean) -> ())
	self._onDisabled = callback
	return self
end

function Field:destroy()
	if self.Instance then
		Motion.cancelAll(self.Instance)
		self.Instance:Destroy()
		self.Instance = nil
	end
end

return Field
