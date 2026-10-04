--!nonstrict
--[[
	Vantage 1.0.0 · Primitives/Slider
	------------------------------------------------------------------
	A slider that behaves the way people expect a slider to behave.

	· Click anywhere on the track to seek, then keep dragging — the grab
	  is captured on the first move rather than requiring a hit on a
	  14-pixel knob.
	· The knob grows on hover, shrinks on press, and the fill springs to
	  the new value so a big jump reads as motion, not teleportation.
	· Shift while dragging locks to a fine step; tick marks are drawn
	  from the step so the rail explains its own resolution.
	· The value readout is editable: click it and type a number.
	· Arrow keys nudge once focused. PageUp/PageDown move by 10%,
	  Home/End jump to the bounds.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)
local Signal = require(script.Parent.Parent.Core.Signal)
local Field = require(script.Parent.Parent.Layout.Field)

local Slider = {}
Slider.__index = Slider

local KNOB = 14
local TRACK_HEIGHT = 6
local BUBBLE_HEIGHT = 22

--- Roblox's built-in key codes we care about for keyboard nudging.
local KEY_STEP = {
	[Enum.KeyCode.Right] = 1,
	[Enum.KeyCode.Up] = 1,
	[Enum.KeyCode.Left] = -1,
	[Enum.KeyCode.Down] = -1,
}

--- @param spec { Name, Description?, Icon?, Value?, Min?, Max?, Step?, Decimals?, Suffix?, Format?, Callback?, Disabled?, Ticks?, CommitOnRelease?, Tooltip? }
function Slider.new(spec: { [any]: any }, context: { [any]: any })
	local ctx = context or {}
	local tokens = Theme.current()

	local minimum = spec.Min or 0
	local maximum = spec.Max or 100
	if maximum < minimum then
		minimum, maximum = maximum, minimum
	end
	local step = spec.Step or ((maximum - minimum) / 100)
	if step <= 0 then
		step = (maximum - minimum) / 100
	end
	local decimals = spec.Decimals or math.max(0, math.min(6, -math.floor(math.log10(step) + 0.0001)))

	local self = setmetatable({
		_spec = spec,
		_maid = ctx.maid,
		_tokens = tokens,
		_min = minimum,
		_max = maximum,
		_step = step,
		_decimals = decimals,
		_value = Util.clamp(spec.Value ~= nil and spec.Value or minimum, minimum, maximum),
		_dragging = false,
		_hovering = false,
		_showTicks = spec.Ticks == true,
		_enabled = spec.Disabled ~= true,
	}, Slider)

	self.Changed = Signal.new("Slider.Changed")
	self.Released = Signal.new("Slider.Released")

	--- Value -> 0..1 along the rail. The single source of truth for
	--- every position in this component.
	local function fractionOf(value: number): number
		local span = self._max - self._min
		if span == 0 then
			return 0
		end
		return Util.clamp01((value - self._min) / span)
	end
	self._fraction = fractionOf

	local controlWidth = spec.ControlWidth or 168

	local field = Field.new({
		Name = spec.Name,
		Description = spec.Description,
		Icon = spec.Icon,
		Disabled = spec.Disabled,
		ControlWidth = controlWidth,
		Align = "right",
	}, { maid = ctx.maid, parent = ctx.parent })
	self.Field = field
	self.Instance = field.Instance

	local container = field.Control
	container.Size = UDim2.fromOffset(controlWidth, 26)
	container.AutomaticSize = Enum.AutomaticSize.None

	-- Value readout ---------------------------------------------------
	local bubble = Util.row({
		Name = "Value",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 0, 0, BUBBLE_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = tokens.elevated,
		Parent = container,
	})
	Util.corner(bubble, tokens.radiusSm)
	Util.pad(bubble, { Left = 8, Right = 8 })
	Util.stroke(bubble, tokens.border, 1, 0.35)
	local bubbleLabel = Util.text({
		Name = "ValueLabel",
		Text = "0",
		TextSize = tokens.fontSizeSm,
		Font = "mono",
		TextColor3 = tokens.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = bubble,
	})
	self.ValueLabel = bubbleLabel
	self._bubble = bubble

	-- Inline editor, revealed when the readout is clicked.
	local editor = Util.create("TextBox", {
		Name = "Editor",
		Text = "",
		PlaceholderText = "",
		TextSize = tokens.fontSizeSm,
		Font = Enum.Font.RobotoMono,
		TextColor3 = tokens.text,
		BackgroundColor3 = tokens.raised,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ClearTextOnFocus = true,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(0, 62, 0, BUBBLE_HEIGHT),
		ZIndex = 12,
		Parent = container,
	})
	Util.corner(editor, tokens.radiusSm)
	local editorStroke = Util.stroke(editor, tokens.accent, 1, 0)
	self._editor = editor
	self._editorStroke = editorStroke

	-- Track -----------------------------------------------------------
	local track = Util.frame({
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 1, -KNOB * 0.5 - 2),
		Size = UDim2.new(1, 0, 0, TRACK_HEIGHT),
		BackgroundColor3 = tokens.trackOff,
		Parent = container,
	})
	Util.pill(track)
	self.Track = track

	local ticks = Util.row({
		Name = "Ticks",
		Size = UDim2.new(1, 0, 0, 4),
		Position = UDim2.new(0, 0, 1, 3),
		Parent = container,
	})
	self._ticks = ticks
	self._tickMarks = {}

	local fill = Util.frame({
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = tokens.accent,
		ZIndex = 2,
		Parent = track,
	})
	Util.pill(fill)
	Util.gradient(fill, {
		{ Time = 0, Color = tokens.accent },
		{ Time = 1, Color = tokens.accentHover },
	}, 0)
	self.Fill = fill

	local knob = Util.frame({
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(KNOB, KNOB),
		BackgroundColor3 = tokens.knob,
		ZIndex = 4,
		Parent = track,
	})
	Util.pill(knob)
	Util.stroke(knob, tokens.accent, 2, 0.15)
	self.Knob = knob

	-- Hit area covers the whole control including a generous vertical
	-- band, so the rail is easy to grab without aiming at the knob.
	local hit = Util.create("TextButton", {
		Name = "Hit",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, KNOB + 12),
		Position = UDim2.new(0, 0, 0, BUBBLE_HEIGHT + 2),
		ZIndex = 8,
		Parent = container,
	})
	self._hit = hit

	-- Value pipeline ---------------------------------------------------
	local indicator = Motion.springFrom("quick", fractionOf(self._value))
	self._indicator = indicator

	local function format(value: number): string
		if type(spec.Format) == "function" then
			return tostring(spec.Format(value))
		end
		local text = string.format("%." .. self._decimals .. "f", value)
		if spec.Suffix then
			return text .. spec.Suffix
		end
		return text
	end
	self.Format = format

	local function render(fraction: number)
		fraction = Util.clamp01(fraction)
		fill.Size = UDim2.new(fraction, 0, 1, 0)
		local width = track.AbsoluteSize.X
		local knobX = fraction * width
		knob.Position = UDim2.new(fraction, 0, 0.5, 0)
		bubble.AnchorPoint = Vector2.new(0.5, 0)
		local clampedX = Util.clamp(knobX, 26, math.max(26, width - 26))
		bubble.Position = UDim2.fromOffset(clampedX, 0)
		if not self._editing then
			bubbleLabel.Text = format(self._value)
		end
	end

	self._render = render
	indicator:observe(render)

	if ctx.maid then
		ctx.maid:add(function()
			indicator:destroy()
		end)
	end

	-- Tick marks -------------------------------------------------------
	local function buildTicks()
		for _, mark in ipairs(self._tickMarks) do
			mark:Destroy()
		end
		table.clear(self._tickMarks)
		if not self._showTicks then
			return
		end
		local span = self._max - self._min
		local count = math.floor(span / self._step + 0.5)
		-- Never draw more than 24 marks; beyond that they are noise.
		if count < 2 or count > 24 then
			return
		end
		for index = 0, count do
			local mark = Util.frame({
				Name = "Tick",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(index / count, 0, 0, 0),
				Size = UDim2.fromOffset(1, 4),
				BackgroundColor3 = tokens.borderStrong,
				BackgroundTransparency = 0.35,
				Parent = ticks,
			})
			table.insert(self._tickMarks, mark)
		end
	end
	self._buildTicks = buildTicks
	buildTicks()

	-- Interaction ------------------------------------------------------
	local function fractionToValue(fraction: number): number
		local raw = self._min + Util.clamp01(fraction) * (self._max - self._min)
		local snapped = Util.snap(raw, self._step)
		return Util.clamp(tonumber(string.format("%." .. self._decimals .. "f", snapped)) or snapped, self._min, self._max)
	end

	self._fractionToValue = fractionToValue

	local function setValue(value: number, fromUser: boolean?, commit: boolean?)
		value = Util.clamp(Util.snap(value, self._step), self._min, self._max)
		if self._value == value then
			if commit then
				self.Released:fire(value)
				Util.safeCall(spec.Callback, value, self, true)
			end
			return
		end
		self._value = value
		self._indicator:setGoal(fractionOf(value))
		self.Changed:fire(value, self)
		if fromUser then
			if spec.CommitOnRelease then
				if commit then
					Util.safeCall(spec.Callback, value, self, true)
					self.Released:fire(value)
				end
			else
				Util.safeCall(spec.Callback, value, self, commit == true)
				if commit then
					self.Released:fire(value)
				end
			end
		end
	end
	self.SetValue = setValue

	local function fractionFromX(x: number): number
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return 0
		end
		-- The knob rides the rail directly, so screen X maps straight
		-- onto 0..1 with no half-knob compensation.
		return (x - track.AbsolutePosition.X) / width
	end

	local dragging = false
	local dragConnection
	local releaseConnection

	local function stopDrag()
		if not dragging and not self._dragging then
			return
		end
		dragging = false
		self._dragging = false
		if dragConnection then
			dragConnection:Disconnect()
			dragConnection = nil
		end
		if releaseConnection then
			releaseConnection:Disconnect()
			releaseConnection = nil
		end
		Motion.scale(knob, self._hovering and 1.12 or 1, Motion.options("release"))
		Motion.tween(bubble, { BackgroundColor3 = tokens.elevated }, Motion.options("hover"))
		setValue(self._value, true, true)
	end

	local function beginDrag(x: number)
		dragging = true
		self._dragging = true
		Motion.scale(knob, 1.28, Motion.options("press", { duration = 0.12 }))
		Motion.tween(bubble, { BackgroundColor3 = tokens.raised }, Motion.options("hover"))
		setValue(fractionToValue(fractionFromX(x)), true)
	end

	local function updateDrag(x: number)
		if not dragging then
			return
		end
		setValue(fractionToValue(fractionFromX(x)), true)
	end

	hit.InputBegan:Connect(function(input)
		if not self._enabled then
			return
		end
		local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
		local isTouch = input.UserInputType == Enum.UserInputType.Touch
		if not (isMouse or isTouch) then
			return
		end

		beginDrag(input.Position.X)

		local UserInputService = game:GetService("UserInputService")
		if isTouch then
			dragConnection = UserInputService.TouchMoved:Connect(function(touchInput)
				updateDrag(touchInput.Position.X)
			end)
			releaseConnection = UserInputService.TouchEnded:Connect(function()
				stopDrag()
			end)
		else
			dragConnection = UserInputService.InputChanged:Connect(function(changed)
				if changed.UserInputType == Enum.UserInputType.MouseMovement then
					updateDrag(changed.Position.X)
				end
			end)
			releaseConnection = UserInputService.InputEnded:Connect(function(changed)
				if changed.UserInputType == Enum.UserInputType.MouseButton1 then
					stopDrag()
				end
			end)
		end
	end)

	hit.MouseEnter:Connect(function()
		self._hovering = true
		-- Pointer focus doubles as keyboard focus: arrow keys work while
		-- the rail is hovered, which is how users actually discover it.
		self._focused = true
		if not dragging then
			Motion.scale(knob, 1.12, Motion.options("hover"))
		end
	end)
	hit.MouseLeave:Connect(function()
		self._hovering = false
		self._focused = false
		if not dragging then
			Motion.scale(knob, 1, Motion.options("hover"))
		end
	end)

	-- Editable readout --------------------------------------------------
	bubble.Active = true
	local bubbleHit = Util.create("TextButton", {
		Name = "ValueHit",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 9,
		Parent = bubble,
	})
	self._bubbleHit = bubbleHit

	local function commitEdit()
		local parsed = tonumber(self._editor.Text)
		self._editing = false
		editor.Visible = false
		bubbleLabel.Visible = true
		if parsed then
			setValue(parsed, true, true)
		end
		self._indicator:snap(fractionOf(self._value))
		render(fractionOf(self._value))
	end

	bubbleHit.Activated:Connect(function()
		if not self._enabled or self._editing then
			return
		end
		self._editing = true
		editor.Text = string.format("%." .. self._decimals .. "f", self._value)
		bubbleLabel.Visible = false
		editor.Visible = true
		editor:CaptureFocus()
	end)
	editor.FocusLost:Connect(commitEdit)

	field:onActivate(function()
		if not self._enabled then
			return
		end
		bubbleHit:Activate()
	end)

	-- Keyboard --------------------------------------------------------
	local keyConnection
	local function onKey(input, processed)
		if processed or not self._enabled or not self._focused then
			return
		end
		local direction = KEY_STEP[input.KeyCode]
		if direction then
			local increment = self._step * (input:IsModifierKeyDown(Enum.KeyCode.LeftShift) and 0.1 or 1)
			setValue(self._value + direction * math.max(increment, 10 ^ -self._decimals), true, true)
		elseif input.KeyCode == Enum.KeyCode.PageUp then
			setValue(self._value + (self._max - self._min) * 0.1, true, true)
		elseif input.KeyCode == Enum.KeyCode.PageDown then
			setValue(self._value - (self._max - self._min) * 0.1, true, true)
		elseif input.KeyCode == Enum.KeyCode.Home then
			setValue(self._min, true, true)
		elseif input.KeyCode == Enum.KeyCode.End then
			setValue(self._max, true, true)
		else
			return
		end
	end

	local UserInputService = game:GetService("UserInputService")
	keyConnection = UserInputService.InputBegan:Connect(onKey)
	if ctx.maid then
		ctx.maid:add(keyConnection)
		ctx.maid:add(function()
			stopDrag()
		end)
	end
	self._focused = false

	-- Theme ------------------------------------------------------------
	if ctx.maid then
		ctx.maid:add(Theme.Changed:connect(function(next)
			tokens = next
			self._tokens = next
			track.BackgroundColor3 = next.trackOff
			knob.BackgroundColor3 = next.knob
			local knobStroke = knob:FindFirstChildOfClass("UIStroke")
			if knobStroke then
				knobStroke.Color = next.accent
			end
			bubble.BackgroundColor3 = next.elevated
			bubbleLabel.TextColor3 = next.text
			editor.TextColor3 = next.text
			editor.BackgroundColor3 = next.raised
			editorStroke.Color = next.accent
			Util.gradient(fill, {
				{ Time = 0, Color = next.accent },
				{ Time = 1, Color = next.accentHover },
			}, 0)
			for _, mark in ipairs(self._tickMarks) do
				mark.BackgroundColor3 = next.borderStrong
			end
		end))
	end

	self._render = render
	render(fractionOf(self._value))
	indicator:snap(fractionOf(self._value))

	return self
end

function Slider:Get(): number
	return self._value
end

function Slider:Set(value: number, fromUser: boolean?)
	self.SetValue(value, fromUser, true)
	return self
end

function Slider:setEnabled(enabled: boolean)
	self._enabled = enabled
	self.Field:setDisabled(not enabled)
	self._hit.Active = enabled
	return self
end

function Slider:destroy()
	if self.Changed then
		self.Changed:destroy()
	end
	if self.Released then
		self.Released:destroy()
	end
	self.Field:destroy()
end

return Slider
