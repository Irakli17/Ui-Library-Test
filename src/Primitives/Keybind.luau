--!nonstrict
--[[
	Vantage 1.0.0 · Primitives/Keybind
	------------------------------------------------------------------
	Click to capture, press to bind.

	· Captures keyboard, mouse buttons and gamepad buttons through one
	  path, and formats them the way players read them (Ctrl+Shift+K,
	  Mouse 2, ButtonA).
	· Escape cancels capture instead of binding Escape to everything.
	· Backspace clears the bind.
	· Modifiers are recorded in a stable order so the same combination
	  always compares equal, and conflicts across a window can be
	  detected with exact equality.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)
local Glyph = require(script.Parent.Parent.Core.Glyph)
local Signal = require(script.Parent.Parent.Core.Signal)
local Button = require(script.Parent.Button)
local Field = require(script.Parent.Parent.Layout.Field)

local Keybind = {}
Keybind.__index = Keybind

local MOUSE_NAMES = {
	[Enum.UserInputType.MouseButton1] = "Mouse 1",
	[Enum.UserInputType.MouseButton2] = "Mouse 2",
	[Enum.UserInputType.MouseButton3] = "Mouse 3",
	[Enum.UserInputType.MouseWheel] = "Wheel",
}

local MODIFIER_ORDER = {
	"LeftControl",
	"LeftShift",
	"LeftAlt",
	"RightControl",
	"RightShift",
	"RightAlt",
}

--- A bare modifier press is not a bind on its own.
function Keybind.isModifier(keyCode: any): boolean
	for _, name in ipairs(MODIFIER_ORDER) do
		if keyCode == Enum.KeyCode[name] then
			return true
		end
	end
	return false
end

--- Formats an InputObject into a stable, human-readable string.
--- Modifiers are always emitted in the same order, so the same chord
--- always produces the same string and equality comparison is safe.
function Keybind.format(input: any): string
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if Keybind.isModifier(input.KeyCode) then
			return input.KeyCode.Name
		end

		local parts = {}
		local ok, ctrl = pcall(function()
			return input:IsModifierKeyDown(Enum.KeyCode.LeftControl)
				or input:IsModifierKeyDown(Enum.KeyCode.RightControl)
		end)
		if ok and ctrl then
			table.insert(parts, "Ctrl")
		end
		local okShift, shift = pcall(function()
			return input:IsModifierKeyDown(Enum.KeyCode.LeftShift)
				or input:IsModifierKeyDown(Enum.KeyCode.RightShift)
		end)
		if okShift and shift then
			table.insert(parts, "Shift")
		end
		table.insert(parts, input.KeyCode.Name)
		return table.concat(parts, "+")
	end

	return MOUSE_NAMES[input.UserInputType] or input.UserInputType.Name
end

--- Normalises a binding into the chord string the library stores.
---
--- The documented form is a string (`"LeftShift+T"`), but an
--- `Enum.KeyCode` — and a list of them — is the natural Roblox spelling, and
--- passing one used to throw `Unable to assign property Text. string expected,
--- got EnumItem` the moment the label was written, because the enum reached
--- `Text` unchanged. Both forms are accepted now.
function Keybind.chordOf(value: any): string
	if value == nil then
		return ""
	end
	if typeof(value) == "EnumItem" then
		return value.Name
	end
	if type(value) == "table" then
		local parts = {}
		for _, entry in ipairs(value) do
			local part = Keybind.chordOf(entry)
			if part ~= "" then
				table.insert(parts, part)
			end
		end
		return table.concat(parts, "+")
	end
	return tostring(value)
end

--- @param spec { Name, Description?, Icon?, Value?: string, Callback?, Disabled?, AllowMouse?, AllowGamepad?, Tooltip? }
function Keybind.new(spec: { [any]: any }, context: { [any]: any })
	local ctx = context or {}
	local tokens = Theme.current()

	local self = setmetatable({
		_spec = spec,
		_maid = ctx.maid,
		_tokens = tokens,
		_value = Keybind.chordOf(spec.Value),
		_capturing = false,
		_enabled = spec.Disabled ~= true,
	}, Keybind)

	self.Changed = Signal.new("Keybind.Changed")

	local field = Field.new({
		Name = spec.Name,
		Description = spec.Description,
		Icon = spec.Icon or "gear",
		Disabled = spec.Disabled,
		ControlWidth = 104,
		ControlHeight = 32,
	}, { maid = ctx.maid, parent = ctx.parent })
	self.Field = field
	self.Instance = field.Instance

	local container = field.Control
	container.Size = UDim2.fromOffset(104, 32)
	container.AutomaticSize = Enum.AutomaticSize.None

	local shell = Util.frame({
		Name = "Shell",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tokens.sunken,
		Parent = container,
	})
	Util.corner(shell, tokens.radiusSm)
	local shellStroke = Util.stroke(shell, tokens.border, 1, 0.2)
	self._shell = shell
	self._shellStroke = shellStroke

	local label = Util.text({
		Name = "Key",
		Text = self._value ~= "" and self._value or "Unbound",
		TextSize = tokens.fontSizeSm,
		Font = "mono",
		TextColor3 = self._value ~= "" and tokens.text or tokens.textDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = shell,
	})
	Util.pad(shell, { Left = 20, Right = 20 })
	self.Label = label

	local clearHolder = Util.row({
		Name = "Clear",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		Visible = false,
		ZIndex = 5,
		Parent = shell,
	})
	local clearGlyph = Glyph.draw(clearHolder, "close", {
		size = 8,
		color = tokens.textDim,
		weight = 13,
		zIndex = 5,
	})
	if clearGlyph then
		clearGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
		clearGlyph.Position = UDim2.fromScale(0.5, 0.5)
	end
	self._clearHolder = clearHolder
	self._clearGlyph = clearGlyph

	local hit = Util.create("TextButton", {
		Name = "Hit",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
		Parent = shell,
	})
	self._hit = hit

	local captureConnection
	local UserInputService = game:GetService("UserInputService")

	local function stopCapture(cancelled: boolean?)
		if not self._capturing then
			return
		end
		self._capturing = false
		if captureConnection then
			captureConnection:Disconnect()
			captureConnection = nil
		end
		shell.BackgroundColor3 = tokens.sunken
		shellStroke.Color = tokens.border
		shellStroke.Transparency = 0.2
		if cancelled then
			self:setLabelText(self._value)
		end
	end
	self._stopCapture = stopCapture

	local function startCapture()
		if self._capturing or not self._enabled then
			return
		end
		self._capturing = true
		label.Text = "Press a key..."
		label.TextColor3 = tokens.textDim
		shell.BackgroundColor3 = tokens.surfaceAlt
		shellStroke.Color = tokens.accent
		shellStroke.Transparency = 0.3

		captureConnection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			-- Mouse movement and focus changes are not bindable.
			if input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Focus
			then
				return
			end
			if input.KeyCode == Enum.KeyCode.Escape then
				stopCapture(true)
				return
			end

			if input.KeyCode == Enum.KeyCode.Backspace then
				self:Set("", true)
				stopCapture()
				return
			end

			-- Ignore bare modifier presses; wait for the real key.
			if Keybind.isModifier(input.KeyCode) then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1
				and spec.AllowMouse == false
			then
				return
			end
			if input.UserInputType == Enum.UserInputType.Gamepad1
				and spec.AllowGamepad == false
			then
				return
			end

			self:Set(Keybind.format(input), true)
			stopCapture()
		end)
	end

	hit.Activated:Connect(function()
		if self._capturing then
			stopCapture(true)
		else
			startCapture()
		end
	end)

	-- Right-click clears, matching the convention players already have.
	hit.MouseButton2Click:Connect(function()
		if self._value ~= "" then
			self:Set("", true)
		end
	end)

	hit.MouseEnter:Connect(function()
		if self._value ~= "" then
			clearHolder.Visible = self._value ~= ""
		end
		if self._enabled and not self._capturing then
			Motion.tween(shell, { BackgroundColor3 = tokens.hover }, Motion.options("hover"))
			if clearGlyph then
				Glyph.setColor(clearGlyph, tokens.textMuted)
			end
		end
	end)
	hit.MouseLeave:Connect(function()
		if not self._capturing then
			clearHolder.Visible = false
			Motion.tween(shell, { BackgroundColor3 = tokens.sunken }, Motion.options("hover"))
		end
	end)

	field:onActivate(function()
		startCapture()
	end)

	if ctx.maid then
		ctx.maid:add(function()
			stopCapture(true)
		end)
		ctx.maid:add(Theme.Changed:connect(function(next)
			tokens = next
			self._tokens = next
			if not self._capturing then
				shell.BackgroundColor3 = next.sunken
				shellStroke.Color = next.border
			end
			self:setLabelText(self._value)
		end))
	end

	return self
end

function Keybind:setLabelText(value: string)
	local bound = value ~= ""
	self.Label.Text = bound and value or "Unbound"
	self.Label.TextColor3 = self._tokens[bound and "text" or "textDim"]
end

--- Binds a value. `fromUser` fires the callback. Accepts a chord string, an
--- `Enum.KeyCode`, or a list of key codes (see `Keybind.chordOf`).
function Keybind:Set(value: any, fromUser: boolean?)
	value = Keybind.chordOf(value)
	if self._value == value and not fromUser then
		return self
	end
	local previous = self._value
	self._value = value
	self:setLabelText(value)
	if fromUser then
		Button.playCue("click")
		-- A short flash confirms the bind landed.
		local target = value ~= "" and self._tokens.accent or self._tokens.textDim
		self._shellStroke.Color = target
		Motion.tween(self._shellStroke, { Transparency = 0.7 }, Motion.options("hover"))
		Motion.setScale(self.Label, 0.86)
		Motion.scale(self.Label, 1, Motion.options("release", { easing = "settle" }))
		self.Changed:fire(value, previous, self)
		Util.safeCall(self._spec.Callback, value, previous, self)
	end
	return self
end

function Keybind:Get(): string
	return self._value
end

--- True while the control is waiting for a key press.
function Keybind:IsCapturing(): boolean
	return self._capturing
end

--- Absolute keybind path for the currently-bound value, e.g.
--- `{ Enum.KeyCode.LeftControl, Enum.KeyCode.K }`, so gameplay code can
--- compare without re-parsing the display string.
function Keybind:ToKeyCodes(): { any }
	local codes = {}
	for part in self._value:gmatch("[^+]+") do
		local trimmed = part:gsub("^%s+", ""):gsub("%s+$", "")
		local ok, code = pcall(function()
			return Enum.KeyCode[trimmed]
		end)
		if ok and code then
			table.insert(codes, code)
		end
	end
	return codes
end

function Keybind:setEnabled(enabled: boolean)
	self._enabled = enabled
	self.Field:setDisabled(not enabled)
	if not enabled then
		self:stopCapture(true)
	end
	return self
end

function Keybind:destroy()
	if self._stopCapture then
		self._stopCapture(true)
	end
	if self.Changed then
		self.Changed:destroy()
	end
	self.Field:destroy()
end

return Keybind
