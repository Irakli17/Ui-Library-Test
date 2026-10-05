--!nonstrict
--[[
	Vantage 1.0.0 · Primitives/Toggle
	------------------------------------------------------------------
	A switch driven by a real spring, not a tween.

	Why that matters: a spring carries momentum, so a fast double-tap
	reads as one continuous motion instead of two restarts, and the knob
	overshoots by a hair on release. That is the whole difference between
	a switch that feels like a product and one that feels like a property
	write.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)
local Glyph = require(script.Parent.Parent.Core.Glyph)
local Signal = require(script.Parent.Parent.Core.Signal)
local Button = require(script.Parent.Button)
local Field = require(script.Parent.Parent.Layout.Field)

local Toggle = {}
Toggle.__index = Toggle

local TRACK_WIDTH = 40
local TRACK_HEIGHT = 22
local KNOB_INSET = 3

--- @param spec { Name, Description?, Icon?, Value?, Callback?, Disabled?, Tooltip? }
--- @param context { maid?, parent?, tooltip? }
function Toggle.new(spec: { [any]: any }, context: { [any]: any })
	local ctx = context or {}
	local tokens = Theme.current()

	local self = setmetatable({
		_spec = spec,
		_maid = ctx.maid,
		_tokens = tokens,
		_value = spec.Value == true,
		_enabled = spec.Disabled ~= true,
	}, Toggle)

	self.Changed = Signal.new("Toggle.Changed")

	local field = Field.new({
		Name = spec.Name,
		Description = spec.Description,
		Icon = spec.Icon or "power",
		Disabled = spec.Disabled,
		ControlWidth = TRACK_WIDTH,
		ControlHeight = TRACK_HEIGHT,
		MinHeight = TRACK_HEIGHT + 4,
	}, { maid = ctx.maid, parent = ctx.parent })
	self.Field = field
	self.Instance = field.Instance

	-- Track ----------------------------------------------------------
	local track = Util.frame({
		Name = "Track",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(TRACK_WIDTH, TRACK_HEIGHT),
		BackgroundColor3 = self._value and tokens.trackOn or tokens.trackOff,
		Parent = field.Control,
	})
	Util.pill(track)
	track.Size = UDim2.fromOffset(TRACK_WIDTH, TRACK_HEIGHT)
	field.Control.Size = UDim2.fromOffset(TRACK_WIDTH, TRACK_HEIGHT)
	field.Control.AutomaticSize = Enum.AutomaticSize.None
	self.Track = track

	-- Inner shadow-ish rim, which is what makes the off state read as a
	-- physical track rather than a coloured rectangle.
	local rim = Util.frame({
		Name = "Rim",
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = track,
	})
	Util.pill(rim)
	Util.stroke(rim, tokens.borderStrong, 1, 0.75)
	self._rim = rim

	local knob = Util.frame({
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, KNOB_INSET, 0.5, 0),
		Size = UDim2.fromOffset(TRACK_HEIGHT - KNOB_INSET * 2, TRACK_HEIGHT - KNOB_INSET * 2),
		BackgroundColor3 = tokens.knob,
		ZIndex = 3,
		Parent = track,
	})
	Util.pill(knob)
	Util.stroke(knob, tokens.shadow, 1, 0.82)
	self.Knob = knob

	local check = Glyph.draw(knob, "check", {
		size = 9,
		color = tokens.onAccent,
		weight = 16,
		zIndex = 4,
		transparency = 1,
	})
	if check then
		check.AnchorPoint = Vector2.new(0.5, 0.5)
		check.Position = UDim2.fromScale(0.5, 0.5)
	end
	self._check = check

	-- A spring drives the knob position, so rapid toggles blend.
	local progress = Motion.springFrom("snappy", self._value and 1 or 0)
	self._progress = progress

	local knobOffsetMax = TRACK_WIDTH - (TRACK_HEIGHT - KNOB_INSET * 2) - KNOB_INSET * 2

	if ctx.maid then
		ctx.maid:add(function()
			progress:destroy()
		end)
	end

	local function onProgress(value: number)
		knob.Position = UDim2.new(0, KNOB_INSET + knobOffsetMax * value, 0.5, 0)
		-- Blend the track colour along the same curve the knob travels.
		track.BackgroundColor3 = Util.mixColor(tokens.trackOff, tokens.trackOn, Util.clamp01(value))
		if check then
			Glyph.setTransparency(check, 1 - Util.clamp01(value * 1.6 - 0.1))
		end
	end

	progress:observe(onProgress)
	onProgress(progress:get())

	-- Interaction ----------------------------------------------------
	local hit = Util.create("TextButton", {
		Name = "Hit",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 6,
		Parent = track,
	})

	local hovering = false

	local function refreshHover()
		local target = self._value and tokens.accentHover or tokens.borderStrong
		if self._value then
			target = self._value and (hovering and tokens.accentHover or tokens.trackOn) or track.BackgroundColor3
		else
			target = hovering and Util.lighten(tokens.trackOff, 0.1) or tokens.trackOff
		end
		if not self._value then
			Motion.tween(track, { BackgroundColor3 = target }, Motion.options("hover"))
		end
		Motion.scale(knob, hovering and 1.08 or 1, Motion.options("hover"))
	end

	hit.MouseEnter:Connect(function()
		hovering = true
		refreshHover()
	end)
	hit.MouseLeave:Connect(function()
		hovering = false
		refreshHover()
	end)
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			Motion.scale(knob, 0.9, Motion.options("press"))
		end
	end)
	hit.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			Motion.scale(knob, hovering and 1.08 or 1, Motion.options("release"))
		end
	end)
	hit.Activated:Connect(function()
		self:Set(not self._value, true)
	end)

	field:onActivate(function()
		self:Set(not self._value, true)
	end)

	if ctx.maid then
		ctx.maid:add(Theme.Changed:connect(function(next)
			tokens = next
			self._tokens = next
			Util.corner(track, next.radiusPill)
			rim:FindFirstChildOfClass("UIStroke").Color = next.borderStrong
			knob.BackgroundColor3 = next.knob
			if check then
				Glyph.setColor(check, next.onAccent)
			end
			onProgress(progress:get())
		end))
	end

	self._hit = hit
	self._onProgress = onProgress
	return self
end

--- Sets the value. `fromUser` marks the change as user-initiated so the
--- callback fires.
function Toggle:Set(value: boolean, fromUser: boolean?)
	value = value == true
	if self._value == value and not fromUser then
		return self
	end
	self._value = value
	self._progress:setGoal(value and 1 or 0)
	if fromUser then
		Button.playCue("toggle")
		self.Changed:fire(value)
		Util.safeCall(self._spec.Callback, value, self)
	end
	return self
end

function Toggle:Get(): boolean
	return self._value
end

function Toggle:setEnabled(enabled: boolean)
	self._enabled = enabled
	self.Field:setDisabled(not enabled)
	self._hit.Active = enabled
	return self
end

function Toggle:destroy()
	if self.Changed then
		self.Changed:destroy()
	end
	self.Field:destroy()
end

return Toggle
