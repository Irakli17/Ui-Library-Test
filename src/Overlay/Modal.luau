--!nonstrict
--[[
	Vantage 1.0.0 · Overlay/Modal
	------------------------------------------------------------------
	A dialog that cannot be lost.

	· The backdrop scales in before the panel does, and the panel enters
	  from 96% with an emphasised curve. Two beats, not one, which is
	  what makes a dialog feel placed rather than inserted.
	· Escape dismisses, a click on the backdrop dismisses, and the
	  returned handle carries a result so callers can write
	  `modal:Result()` instead of wiring three callbacks.
	· `Dismissible = false` removes every one of those escapes, for
	  confirmations that must be answered.
	· Input is captured while a modal is open: a modal that leaks clicks
	  to the interface behind it is a bug, not a feature.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)
local Maid = require(script.Parent.Parent.Core.Maid)
local Signal = require(script.Parent.Parent.Core.Signal)
local Glyph = require(script.Parent.Parent.Core.Glyph)
local Button = require(script.Parent.Parent.Primitives.Button)

local Modal = {}
Modal.__index = Modal

local TONES = {
	info = "info",
	success = "success",
	warning = "warning",
	danger = "danger",
	prompt = "accent",
}

--- Opens a modal.
--- @param spec { Title?, Body?, Icon?, Tone?, Actions?, Dismissible?, Width?, OnResult?, Layer? }
--- @param context { layer: Instance, maid?: Maid }
function Modal.new(spec: { [any]: any }, context: { [any]: any })
	local ctx = context or {}
	local tokens = Theme.current()
	local tone = TONES[spec.Tone or "prompt"] or "accent"

	local self = setmetatable({
		_spec = spec,
		_maid = Maid.new("modal"),
		_tokens = tokens,
		_closed = false,
		_result = nil,
	}, Modal)

	self.Closed = Signal.new("Modal.Closed")
	self.Result = Signal.new("Modal.Result")

	local layer = ctx.layer or spec.Layer

	-- Backdrop -----------------------------------------------------------
	local backdrop = Util.frame({
		Name = "VantageModalBackdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tokens.scrim,
		BackgroundTransparency = 1,
		ZIndex = 500,
		Parent = layer,
	})
	self.Backdrop = backdrop

	local blocker = Util.create("TextButton", {
		Name = "Blocker",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = backdrop,
	})
	blocker.Activated:Connect(function()
		if spec.Dismissible ~= false then
			self:Close(nil, "backdrop")
		end
	end)

	-- Panel ---------------------------------------------------------------
	local width = spec.Width or 340
	local panel = Util.frame({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = tokens.elevated,
		ZIndex = 510,
		Parent = backdrop,
	})
	Util.corner(panel, tokens.radiusXl)
	Util.stroke(panel, tokens.border, 1, 0.25)
	Util.tag(panel, "Vantage")
	self.Instance = panel

	local stack = Util.row({
		Name = "Stack",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = panel,
	})
	Util.stack(stack, 0)
	Util.pad(stack, { Left = 20, Right = 20, Top = 18, Bottom = 18 })
	self.Content = stack

	local header = Util.row({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = stack,
	})
	Util.list(header, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})

	if spec.Icon ~= false then
		local iconHolder = Util.row({
			Name = "Icon",
			Size = UDim2.fromOffset(18, 18),
			LayoutOrder = 1,
			Parent = header,
		})
		local glyph = Glyph.draw(iconHolder, spec.Icon or (spec.Tone == "danger" and "warning" or "info"), {
			size = 18,
			color = tokens[tone],
			weight = 12,
			zIndex = 512,
		})
		self.Icon = glyph
	end

	local titleBlock = Util.row({
		Name = "Titles",
		Size = UDim2.new(1, -28, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = header,
	})
	Util.stack(titleBlock, 4)

	local title = Util.text({
		Name = "Title",
		Text = spec.Title or "",
		TextSize = tokens.fontSizeLg,
		Font = "heading",
		TextColor3 = tokens.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Visible = spec.Title ~= nil,
		Parent = titleBlock,
	})
	self.Title = title

	local body = Util.text({
		Name = "Body",
		Text = spec.Body or "",
		TextSize = tokens.fontSizeMd,
		Font = "body",
		TextColor3 = tokens.textMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		RichText = spec.RichText == true,
		LineHeight = 1.15,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Visible = (spec.Body or "") ~= "",
		Parent = titleBlock,
	})
	self.Body = body

	local actions = Util.row({
		Name = "Actions",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = stack,
	})
	Util.list(actions, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = spec.Align == "left" and Enum.HorizontalAlignment.Left
			or Enum.HorizontalAlignment.Right,
	})
	self.Actions = actions
	self._actionsHolder = actions

	local spacer = Util.row({
		Name = "Spacer",
		Size = UDim2.new(1, 0, 0, 14),
		LayoutOrder = 2,
		Parent = stack,
	})
	spacer.LayoutOrder = 2
	actions.LayoutOrder = 3

	-- Entrance -------------------------------------------------------------
	backdrop.BackgroundTransparency = 1
	Motion.tween(backdrop, { BackgroundTransparency = tokens.scrimTransparency }, {
		duration = 0.22,
		easing = "enterSoft",
	})
	Motion.setScale(panel, 0.96)
	Motion.scale(panel, 1, { duration = 0.38, easing = "emphasize" })
	panel.GroupTransparency = 1
	Motion.tween(panel, { GroupTransparency = 0 }, { duration = 0.2, easing = "enterSoft" })
	panel.Position = UDim2.fromScale(0.5, 0.54)
	Motion.tween(panel, { Position = UDim2.fromScale(0.5, 0.5) }, { duration = 0.4, easing = "enterSnap" })

	-- Escape ---------------------------------------------------------------
	if spec.Dismissible ~= false then
		local UserInputService = game:GetService("UserInputService")
		self._maid:add(UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.KeyCode == Enum.KeyCode.Escape then
				self:Close(nil, "escape")
			end
		end))
	end

	if ctx.maid then
		ctx.maid:add(function()
			self:Close(nil, "host")
		end)
	end

	-- Actions are built eagerly so the dialog is complete the moment it
	-- is constructed; there is no separate "open" step to forget.
	self:_buildActions()

	self._maid:add(Theme.Changed:connect(function(next)
		tokens = next
		self._tokens = next
		panel.BackgroundColor3 = next.elevated
		title.TextColor3 = next.text
		title.TextSize = next.fontSizeLg
		body.TextColor3 = next.textMuted
		if self.Icon then
			Glyph.setColor(self.Icon, next[tone])
		end
		local stroke = panel:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = next.border
		end
	end))

	return self
end

--- Builds the action row.
function Modal:_buildActions()
	if self._built then
		return
	end
	self._built = true
	local spec = self._spec
	local actions = spec.Actions or { { Text = "Close", Variant = "primary" } }
	for index, action in ipairs(actions) do
		Button.new({
			Text = action.Text,
			Variant = action.Variant or (index == #actions and "primary" or "secondary"),
			Size = "md",
			LayoutOrder = index,
			Callback = function()
				self:Close(action.Value ~= nil and action.Value or action.Text, "action")
			end,
		}, { parent = self._actionsHolder, maid = self._maid })
	end
end

--- Closes the modal and resolves its result.
function Modal:Close(result: any, reason: string?)
	if self._closed then
		return self
	end
	self._closed = true
	self._result = result

	self.Result:fire(result, reason, self)
	self.Closed:fire(result, reason, self)
	Util.safeCall(self._spec.OnResult, result, reason, self)

	local backdrop = self.Backdrop
	local panel = self.Instance
	Motion.tween(backdrop, { BackgroundTransparency = 1 }, { duration = 0.18, easing = "exit" })
	Motion.scale(panel or backdrop, 0.97, { duration = 0.18, easing = "exit" })
	Motion.tween(panel or backdrop, { GroupTransparency = 1 }, { duration = 0.16, easing = "exit" })
	task.delay(0.22, function()
		self:destroy()
	end)
	return self
end

--- Yields until the dialog closes, then returns its result.
function Modal:Await()
	while not self._closed do
		task.wait(0.05)
	end
	return self._result
end

--- Registers a result callback.
function Modal:onResult(callback: (any, string?) -> ())
	self.Result:connect(callback)
	return self
end

function Modal:GetResult(): any
	return self._result
end

function Modal:IsOpen(): boolean
	return not self._closed
end

function Modal:destroy()
	if self.Instance then
		Motion.cancelAll(self.Instance)
	end
	self.Closed:destroy()
	self.Result:destroy()
	self._maid:destroy()
	if self.Backdrop then
		self.Backdrop:Destroy()
		self.Backdrop = nil
		self.Instance = nil
	end
end

--- Convenience: opens a confirmation dialog and yields for the answer.
---
---     if Vantage.Modal.Confirm({ Title = "Delete?", Tone = "danger" }) then
---         -- accepted
---     end
function Modal.Confirm(spec: { [any]: any }, context: { [any]: any })
	local options = table.clone(spec or {})
	options.Actions = options.Actions or {
		{ Text = options.CancelText or "Cancel", Variant = "secondary", Value = false },
		{ Text = options.ConfirmText or "Confirm", Variant = options.Tone == "danger" and "danger" or "primary", Value = true },
	}
	return Modal.new(options, context):Await() == true
end

--- Convenience: opens an informational dialog and yields until dismissed.
function Modal.Alert(spec: { [any]: any }, context: { [any]: any })
	local options = table.clone(spec or {})
	options.Actions = options.Actions or { { Text = options.DismissText or "Got it", Variant = "primary", Value = "ok" } }
	return Modal.new(options, context):Await()
end

return Modal
