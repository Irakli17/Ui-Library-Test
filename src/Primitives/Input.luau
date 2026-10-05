--!nonstrict
--[[
	Vantage 1.0.0 · Primitives/Input
	------------------------------------------------------------------
	Text and multiline input.

	· The focus ring animates outward from the field edge rather than
	  appearing, and the border shifts to the accent at the same time —
	  two channels for one state change.
	· Validation runs on a debounce, reports through the shared Field
	  status line, and never blocks typing.
	· `ClearTextOnFocus`, character counters, prefix/suffix affixes, and
	  a submit-on-Enter hook are all first-class.
	· Numeric mode sanitises input as it is typed rather than rejecting
	  it after the fact.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)
local Glyph = require(script.Parent.Parent.Core.Glyph)
local Signal = require(script.Parent.Parent.Core.Signal)
local Field = require(script.Parent.Parent.Layout.Field)

local Input = {}
Input.__index = Input

--- Strips anything that cannot be part of a number.
local function sanitizeNumeric(text: string, allowNegative: boolean, allowDecimal: boolean): string
	local out = {}
	local seenDot = false
	for index = 1, #text do
		local char = text:sub(index, index)
		if char:match("%d") then
			table.insert(out, char)
		elseif char == "." and allowDecimal and not seenDot then
			seenDot = true
			table.insert(out, ".")
		elseif char == "-" and allowNegative and #out == 0 then
			table.insert(out, char)
		end
	end
	return table.concat(out)
end

--- @param spec { Name, Description?, Icon?, Value?, Placeholder?, Multiline?, Numeric?, MaxLength?, Prefix?, Suffix?, Callback?, Submit?, Validator?, Disabled?, ClearOnFocus?, Tooltip? }
function Input.new(spec: { [any]: any }, context: { [any]: any })
	local ctx = context or {}
	local tokens = Theme.current()

	local multiline = spec.Multiline == true

	local self = setmetatable({
		_spec = spec,
		_maid = ctx.maid,
		_tokens = tokens,
		_value = spec.Value or "",
		_focused = false,
		_enabled = spec.Disabled ~= true,
	}, Input)

	self.Changed = Signal.new("Input.Changed")
	self.Submitted = Signal.new("Input.Submitted")

	local controlWidth = spec.ControlWidth or (multiline and 260 or 190)

	local field = Field.new({
		Name = spec.Name,
		Description = spec.Description,
		Icon = spec.Icon,
		Disabled = spec.Disabled,
		ControlWidth = controlWidth,
		ControlHeight = multiline and 76 or 32,
	}, { maid = ctx.maid, parent = ctx.parent })
	self.Field = field
	self.Instance = field.Instance

	local container = field.Control
	container.Size = UDim2.fromOffset(controlWidth, multiline and 76 or 32)
	container.AutomaticSize = Enum.AutomaticSize.None

	local shell = Util.frame({
		Name = "Shell",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tokens.sunken,
		Parent = container,
	})
	Util.corner(shell, tokens.radiusSm)
	local shellStroke = Util.stroke(shell, tokens.border, 1, 0.15)
	Util.pad(shell, {
		Left = spec.Prefix and 30 or 10,
		Right = (spec.Suffix or spec.MaxLength) and 34 or 10,
		Top = multiline and 8 or 0,
		Bottom = multiline and 8 or 0,
	})
	self.Shell = shell
	self._shellStroke = shellStroke

	local box = Util.create(multiline and "TextBox" or "TextBox", {
		Name = "Box",
		Text = self._value,
		PlaceholderText = spec.Placeholder or "",
		PlaceholderColor3 = tokens.textDim,
		TextSize = tokens.fontSizeMd,
		Font = Enum.Font.Gotham,
		TextColor3 = tokens.text,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
		TextWrapped = multiline,
		MultiLine = multiline,
		ClearTextOnFocus = spec.ClearOnFocus == true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = shell,
	})
	Util.applyFont(box, "body")
	self.Box = box
	self._box = box

	if spec.MaxLength then
		box.TextEditable = true
		-- Roblox has no MaxLength property; enforce it on change.
	end

	if spec.Prefix then
		local prefix = Util.text({
			Name = "Prefix",
			Text = spec.Prefix,
			TextSize = tokens.fontSizeMd,
			Font = "body",
			TextColor3 = tokens.textDim,
			Size = UDim2.new(0, 20, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			ZIndex = 4,
			Parent = shell,
		})
		self._prefix = prefix
	end

	local suffixHolder = Util.row({
		Name = "Suffix",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, multiline and 0.5 or 0.5, 0),
		Size = UDim2.new(0, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 4,
		Parent = shell,
	})
	Util.list(suffixHolder, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	local counter = Util.text({
		Name = "Counter",
		Text = "",
		TextSize = tokens.fontSizeSm,
		Font = "mono",
		TextColor3 = tokens.textDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		Visible = spec.MaxLength ~= nil,
		Parent = suffixHolder,
	})
	self.Counter = counter

	local actionHolder = Util.row({
		Name = "Action",
		Size = UDim2.fromOffset(18, 18),
		LayoutOrder = 2,
		Visible = false,
		Parent = suffixHolder,
	})
	self._actionHolder = actionHolder
	local actionHit = Util.create("TextButton", {
		Name = "ActionHit",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		Parent = actionHolder,
	})
	local actionGlyph = Glyph.draw(actionHolder, "close", {
		size = 10,
		color = tokens.textDim,
		weight = 13,
		zIndex = 5,
	})
	if actionGlyph then
		actionGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
		actionGlyph.Position = UDim2.fromScale(0.5, 0.5)
	end
	self._actionGlyph = actionGlyph
	self._actionHit = actionHit

	-- Focus ring --------------------------------------------------------
	local ring = Util.frame({
		Name = "FocusRing",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 4, 1, 4),
		Position = UDim2.fromOffset(-2, -2),
		ZIndex = 1,
		Parent = shell,
	})
	Util.corner(ring, tokens.radiusSm + 2)
	local ringStroke = Util.stroke(ring, tokens.accent, tokens.focusWidth, 1)
	self._ring = ring
	self._ringStroke = ringStroke

	-- Behaviour ---------------------------------------------------------
	local function passesValidation(text: string)
		if type(spec.Validator) ~= "function" then
			return nil, nil
		end
		local ok, result, message = pcall(spec.Validator, text)
		if not ok then
			return false, tostring(result)
		end
		if result == false then
			return false, message or "Invalid value"
		end
		return true, message
	end

	local function updateCounter()
		if not spec.MaxLength then
			return
		end
		local length = utf8.len(box.Text) or #box.Text
		counter.Text = string.format("%d/%d", length, spec.MaxLength)
		counter.TextColor3 = length >= spec.MaxLength and tokens.warning or tokens.textDim
	end
	self._updateCounter = updateCounter

	local validating = false

	local function pushUpdate(commit: boolean?)
		local text = box.Text

		if spec.MaxLength then
			local length = utf8.len(text) or #text
			if length > spec.MaxLength then
				-- Trim from the end, respecting UTF-8.
				local kept = {}
				local count = 0
				for _, code in utf8.codes(text) do
					count += 1
					if count > spec.MaxLength then
						break
					end
					table.insert(kept, utf8.char(code))
				end
				text = table.concat(kept)
				local wasFocused = self._focused
				box.Text = text
				self._focused = wasFocused
			end
		end

		if spec.Numeric then
			local cleaned = sanitizeNumeric(text, spec.AllowNegative ~= false, spec.AllowDecimal ~= false)
			if cleaned ~= text then
				-- Preserve the caret by putting it back after the edit.
				local caret = box.CursorPosition
				box.Text = cleaned
				pcall(function()
					box.CursorPosition = math.max(1, caret - (#text - #cleaned))
				end)
				text = cleaned
			end
		end

		self._value = text
		updateCounter()

		if validating then
			return
		end
		validating = true
		task.defer(function()
			validating = false
			local ok, message = passesValidation(self._value)
			if ok == nil then
				return
			end
			if ok then
				field:setStatus("success", message)
			else
				field:setStatus("error", message)
			end
		end)

		self.Changed:fire(text, self)
		Util.safeCall(spec.Callback, text, self)
		if commit then
			self.Submitted:fire(text, self)
			Util.safeCall(spec.Submit, text, self)
		end
	end

	box:GetPropertyChangedSignal("Text"):Connect(function()
		pushUpdate(false)
	end)

	box.Focused:Connect(function()
		self._focused = true
		Motion.tween(shell, { BackgroundColor3 = tokens.surfaceAlt }, Motion.options("hover"))
		Motion.tween(shellStroke, { Color = tokens.accent, Transparency = 0.4 }, Motion.options("hover"))
		ring.Visible = true
		ringStroke.Transparency = 1
		Motion.tween(ringStroke, { Transparency = 0.35 }, Motion.options("enter", { duration = 0.22 }))
		Motion.setScale(ring, 0.97)
		Motion.scale(ring, 1, Motion.options("enter", { duration = 0.26 }))
	end)

	box.FocusLost:Connect(function(enterPressed)
		self._focused = false
		ring.Visible = false
		Motion.tween(shell, { BackgroundColor3 = tokens.sunken }, Motion.options("hover"))
		Motion.tween(shellStroke, { Color = tokens.border, Transparency = 0.15 }, Motion.options("hover"))
		if enterPressed and not multiline then
			pushUpdate(true)
		end
	end)

	-- Clear / submit action button --------------------------------------
	local function refreshAction()
		local show = self._focused and #box.Text > 0
		if self._actionHolder.Visible ~= show then
			self._actionHolder.Visible = show
			if show then
				Motion.setScale(actionHolder, 0.6)
				Motion.scale(actionHolder, 1, Motion.options("enter"))
			end
		end
	end
	box:GetPropertyChangedSignal("Text"):Connect(refreshAction)
	box.Focused:Connect(refreshAction)
	box.FocusLost:Connect(refreshAction)

	actionHit.Activated:Connect(function()
		box.Text = ""
		box:CaptureFocus()
	end)
	actionHit.MouseEnter:Connect(function()
		if self._actionGlyph then
			Glyph.setColor(self._actionGlyph, tokens.danger)
		end
	end)
	actionHit.MouseLeave:Connect(function()
		if self._actionGlyph then
			Glyph.setColor(self._actionGlyph, tokens.textDim)
		end
	end)

	field:onActivate(function()
		if not self._enabled then
			return
		end
		box:CaptureFocus()
	end)

	updateCounter()
	refreshAction()

	if ctx.maid then
		ctx.maid:add(Theme.Changed:connect(function(next)
			tokens = next
			self._tokens = next
			shell.BackgroundColor3 = self._focused and next.surfaceAlt or next.sunken
			box.TextColor3 = next.text
			box.PlaceholderColor3 = next.textDim
			ringStroke.Color = next.accent
			ringStroke.Thickness = next.focusWidth
			if self._prefix then
				self._prefix.TextColor3 = next.textDim
			end
			counter.TextColor3 = next.textDim
			updateCounter()
		end))
	end

	return self
end

function Input:Get(): string
	return self._value
end

--- Sets the value without firing validation callbacks.
function Input:Set(value: string, silent: boolean?)
	self._value = tostring(value)
	self._box.Text = self._value
	self._updateCounter()
	if not silent then
		self.Changed:fire(self._value, self)
		Util.safeCall(self._spec.Callback, self._value, self)
	end
	return self
end

function Input:Focus()
	self._box:CaptureFocus()
	return self
end

function Input:Blur()
	self._box:ReleaseFocus()
	return self
end

function Input:setEnabled(enabled: boolean)
	self._enabled = enabled
	self.Field:setDisabled(not enabled)
	self._box.TextEditable = enabled
	return self
end

function Input:setStatus(level: string?, message: string?)
	self.Field:setStatus(level, message)
	return self
end

function Input:destroy()
	if self.Changed then
		self.Changed:destroy()
	end
	if self.Submitted then
		self.Submitted:destroy()
	end
	self.Field:destroy()
end

return Input
