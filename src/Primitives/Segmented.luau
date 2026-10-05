--!nonstrict
--[[
	Vantage 1.0.0 · Primitives/Segmented
	------------------------------------------------------------------
	An iOS-style segmented control.

	The indicator is a single frame that slides between slots on a
	spring. That matters: rebuilding a highlight on each option makes
	the control flicker on fast clicks, while one moving surface reads as
	a physical part being thrown between positions.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)
local Glyph = require(script.Parent.Parent.Core.Glyph)
local Signal = require(script.Parent.Parent.Core.Signal)
local Button = require(script.Parent.Button)
local Field = require(script.Parent.Parent.Layout.Field)

local Segmented = {}
Segmented.__index = Segmented

--- @param spec { Name, Description?, Icon?, Options: {string}, Value?: string|number, Callback?, Disabled?, Tooltip? }
function Segmented.new(spec: { [any]: any }, context: { [any]: any })
	local ctx = context or {}
	local tokens = Theme.current()
	local options = spec.Options or {}
	assert(#options > 0, "[Vantage] Segmented requires at least one option")

	local self = setmetatable({
		_spec = spec,
		_maid = ctx.maid,
		_tokens = tokens,
		_options = options,
		_index = 1,
		_enabled = spec.Disabled ~= true,
	}, Segmented)

	self.Changed = Signal.new("Segmented.Changed")

	-- Resolve the initial selection.
	local initialIndex = 1
	if spec.Value ~= nil then
		for index, option in ipairs(options) do
			local label = type(option) == "table" and (option.Label or option.Value) or option
			if label == spec.Value or (type(option) == "table" and option.Value == spec.Value) then
				initialIndex = index
				break
			end
			if index == spec.Value then
				initialIndex = index
				break
			end
		end
	end
	self._index = initialIndex

	local segmentWidth = spec.SegmentWidth or 62
	local controlWidth = segmentWidth * #options
	local height = 30

	local field = Field.new({
		Name = spec.Name,
		Description = spec.Description,
		Icon = spec.Icon,
		Disabled = spec.Disabled,
		ControlWidth = controlWidth,
		ControlHeight = height,
		Align = "right",
	}, { maid = ctx.maid, parent = ctx.parent })
	self.Field = field
	self.Instance = field.Instance

	local container = field.Control
	container.Size = UDim2.fromOffset(controlWidth, height)
	container.AutomaticSize = Enum.AutomaticSize.None

	local shell = Util.frame({
		Name = "Shell",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tokens.sunken,
		Parent = container,
	})
	Util.corner(shell, tokens.radiusSm + 1)
	Util.stroke(shell, tokens.borderSubtle, 1, 0.5)
	Util.pad(shell, { Top = 3, Bottom = 3, Left = 3, Right = 3 })
	self._shell = shell

	-- The sliding indicator.
	local indicator = Util.frame({
		Name = "Indicator",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1 / #options, 1),
		BackgroundColor3 = tokens.elevated,
		ZIndex = 2,
		Parent = shell,
	})
	Util.corner(indicator, tokens.radiusSm - 1)
	Util.stroke(indicator, tokens.border, 1, 0.35)
	self._indicator = indicator

	-- Slot content.
	local slotHolder = Util.row({
		Name = "Slots",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = shell,
	})
	Util.list(slotHolder, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	self._labels = {}
	self._slots = {}
	self._icons = {}

	for index, option in ipairs(options) do
		local label = type(option) == "table" and (option.Label or option.Value or tostring(option)) or tostring(option)
		local iconName = type(option) == "table" and option.Icon or nil
		local value = type(option) == "table" and (option.Value or label) or option

		local slot = Util.row({
			Name = "Slot" .. index,
			Size = UDim2.new(1 / #options, 0, 1, 0),
			LayoutOrder = index,
			Parent = slotHolder,
		})
		Util.list(slot, {
			FillDirection = iconName and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 5),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})

		if iconName then
			local iconHolder = Util.row({
				Size = UDim2.fromOffset(12, 12),
				LayoutOrder = 1,
				Parent = slot,
			})
			local glyph = Glyph.draw(iconHolder, iconName, {
				size = 12,
				color = tokens.textDim,
				weight = 12,
				zIndex = 4,
			})
			self._icons[index] = glyph
		end

		local text = Util.text({
			Name = "Text",
			Text = label,
			TextSize = tokens.fontSizeSm,
			Font = "bodyMedium",
			TextColor3 = tokens.textDim,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.None,
			LayoutOrder = 2,
			ZIndex = 4,
			Parent = slot,
		})
		self._labels[index] = text
		self._slots[index] = { frame = slot, value = value, label = label }

		local hit = Util.create("TextButton", {
			Name = "Hit",
			Text = "",
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 6,
			Parent = slot,
		})

		hit.MouseEnter:Connect(function()
			if self._index ~= index and self._enabled then
				Motion.tween(text, { TextColor3 = tokens.text }, Motion.options("hover"))
				local glyph = self._icons[index]
				if glyph then
					Glyph.setColor(glyph, tokens.textMuted)
				end
			end
		end)
		hit.MouseLeave:Connect(function()
			if self._index ~= index then
				Motion.tween(text, { TextColor3 = tokens.textDim }, Motion.options("hover"))
				local glyph = self._icons[index]
				if glyph then
					Glyph.setColor(glyph, tokens.textDim)
				end
			end
		end)
		hit.Activated:Connect(function()
			self:Set(value, true)
		end)
	end

	local function layout(animated: boolean?)
		local index = self._index
		local target = UDim2.new((index - 1) / #options, 0, 0, 0)

		if animated == false or Motion.getReducedMotion() then
			indicator.Position = target
		else
			-- Spring, not tween: throwing the indicator across three slots
			-- should accelerate and settle, not glide linearly.
			local spring = self._spring
			if not spring then
				spring = Motion.springFrom("snappy", index - 1)
				self._spring = spring
				if ctx.maid then
					ctx.maid:add(function()
						spring:destroy()
					end)
				end
				spring:observe(function(value)
					indicator.Position = UDim2.new((value) / #options, 0, 0, 0)
				end)
			end
			spring:setGoal(index - 1)
		end

		for slotIndex, label in ipairs(self._labels) do
			local active = slotIndex == index
			local color = active and tokens.text or tokens.textDim
			if self._enabled then
				Motion.tween(label, { TextColor3 = color, TextTransparency = 0 }, Motion.options("hover"))
			end
			local glyph = self._icons[slotIndex]
			if glyph then
				Glyph.setColor(glyph, active and tokens.accent or tokens.textDim)
			end
		end
	end

	self._layout = layout

	if ctx.maid then
		ctx.maid:add(Theme.Changed:connect(function(next)
			tokens = next
			self._tokens = next
			shell.BackgroundColor3 = next.sunken
			indicator.BackgroundColor3 = next.elevated
			local indicatorStroke = indicator:FindFirstChildOfClass("UIStroke")
			if indicatorStroke then
				indicatorStroke.Color = next.border
			end
			for slotIndex, label in ipairs(self._labels) do
				label.TextColor3 = slotIndex == self._index and next.text or next.textDim
			end
		end))
	end

	layout(false)
	task.defer(function()
		layout(false)
	end)

	return self
end

--- Selects an option by value or 1-based index.
function Segmented:Set(value: any, fromUser: boolean?)
	local index = value
	if type(value) == "string" then
		for position, slot in ipairs(self._slots) do
			if slot.value == value or slot.label == value then
				index = position
				break
			end
		end
	end
	if type(index) ~= "number" or not self._slots[index] then
		return self
	end
	if self._index == index and not fromUser then
		return self
	end
	self._index = index
	self._layout(true)
	if fromUser then
		Button.playCue("click")
		local slot = self._slots[index]
		self.Changed:fire(slot.value, self)
		Util.safeCall(self._spec.Callback, slot.value, self)
	end
	return self
end

function Segmented:Get(): any
	return self._slots[self._index] and self._slots[self._index].value
end

function Segmented:GetIndex(): number
	return self._index
end

function Segmented:setEnabled(enabled: boolean)
	self._enabled = enabled
	self.Field:setDisabled(not enabled)
	local target = enabled and self._tokens.text or self._tokens.textDim
	for index, label in ipairs(self._labels) do
		Motion.tween(label, {
			TextColor3 = (enabled and index == self._index) and target or self._tokens.textDim,
		}, Motion.options("hover"))
	end
	return self
end

function Segmented:destroy()
	if self.Changed then
		self.Changed:destroy()
	end
	self.Field:destroy()
end

return Segmented
