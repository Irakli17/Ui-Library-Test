--!nonstrict
--[[
	Vantage 1.0.0 · Overlay/Notify
	------------------------------------------------------------------
	Toasts that behave.

	· A queue, not a pile. Past `maxVisible` notifications wait their
	  turn, so a burst of ten never covers the interface.
	· Every toast carries a visible countdown rail, so it is obvious
	  whether it is going to disappear and how soon. Hovering pauses
	  the countdown — the single most requested behaviour in every
	  notification system ever shipped.
	· Click to dismiss, or click the action to run it and dismiss.
	· Entrance is a slide plus a spring on the scale; exit is faster
	  than entrance, because leaving should never feel like a wait.
	· Grouping: posting the same `Key` again updates the existing toast
	  in place and bumps a counter instead of stacking duplicates.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)
local Glyph = require(script.Parent.Parent.Core.Glyph)
local Signal = require(script.Parent.Parent.Core.Signal)
local Maid = require(script.Parent.Parent.Core.Maid)
local Button = require(script.Parent.Parent.Primitives.Button)

local Notify = {}
Notify.__index = Notify

local TONES = {
	info = { accent = "info", icon = "info" },
	success = { accent = "success", icon = "check" },
	warning = { accent = "warning", icon = "warning" },
	danger = { accent = "danger", icon = "warning" },
	error = { accent = "danger", icon = "warning" },
	brand = { accent = "accent", icon = "sparkle" },
	default = { accent = "accent", icon = "dot" },
}

local WIDTH = 300

--- @param context { layer: Instance, maid?: Maid, maxVisible?: number }
function Notify.new(context: { [any]: any })
	local tokens = Theme.current()
	local self = setmetatable({
		_layer = context.layer,
		_maid = Maid.new("notify"),
		_tokens = tokens,
		_max = context.maxVisible or 4,
		_active = {},
		_queue = {},
		_byKey = {},
		_counter = 0,
	}, Notify)

	self.Pushed = Signal.new("Notify.Pushed")
	self.Dismissed = Signal.new("Notify.Dismissed")

	local host = Util.frame({
		Name = "VantageNotifyHost",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 600,
		Parent = context.layer,
	})
	Util.list(host, {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	})
	self.Instance = host

	if context.maid then
		context.maid:add(function()
			self:destroy()
		end)
	end

	return self
end

local function buildToast(self: any, spec: any): any
	local tokens = self._tokens
	local tone = TONES[spec.Tone or spec.Type or "default"] or TONES.default

	local toast = {}
	toast.id = spec.Id or ("toast-" .. tostring(self._counter + 1))
	toast.key = spec.Key
	toast.count = 1
	toast._spec = spec
	toast._buttons = {}

	local card = Util.frame({
		Name = "VantageToast",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = tokens.elevated,
		BackgroundTransparency = 0.02,
		ClipsDescendants = true,
		LayoutOrder = spec.Order or 1,
		Parent = self.Instance,
	})
	Util.corner(card, tokens.radiusLg)
	Util.stroke(card, tokens.border, 1, 0.3)
	Util.tag(card, "Vantage")
	toast.Instance = card

	-- Accent rail down the leading edge.
	local rail = Util.frame({
		Name = "Rail",
		Size = UDim2.new(0, 3, 1, 0),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = tokens[tone.accent],
		ZIndex = 3,
		Parent = card,
	})
	Util.corner(rail, tokens.radiusLg)
	toast._rail = rail

	local inner = Util.row({
		Name = "Inner",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(0, 0),
		Parent = card,
	})
	Util.pad(inner, { Left = 14, Right = 12, Top = 12, Bottom = 12 })
	Util.stack(inner, 6)
	toast._inner = inner

	local header = Util.row({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 1,
		Parent = inner,
	})
	Util.list(header, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	local iconHolder = Util.row({
		Name = "Icon",
		Size = UDim2.fromOffset(14, 14),
		LayoutOrder = 1,
		Parent = header,
	})
	local icon = Glyph.draw(iconHolder, spec.Icon or tone.icon, {
		size = 14,
		color = tokens[tone.accent],
		weight = 12,
		zIndex = 4,
	})
	toast._iconHolder = iconHolder
	toast._icon = icon

	local title = Util.text({
		Name = "Title",
		Text = spec.Title or spec.Name or "",
		TextSize = tokens.fontSizeMd,
		Font = "subheading",
		TextColor3 = tokens.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -60, 1, 0),
		LayoutOrder = 2,
		Parent = header,
	})
	toast._title = title

	local countLabel = Util.text({
		Name = "Count",
		Text = "",
		TextSize = tokens.fontSizeXs + 1,
		Font = "mono",
		TextColor3 = tokens[tone.accent],
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(0, 22, 1, 0),
		LayoutOrder = 3,
		Visible = false,
		Parent = header,
	})
	toast._count = countLabel

	local closeHolder = Util.frame({
		Name = "Close",
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = tokens.hover,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = header,
	})
	Util.corner(closeHolder, 4)
	local closeGlyph = Glyph.draw(closeHolder, "close", {
		size = 9,
		color = tokens.textDim,
		weight = 13,
		zIndex = 5,
	})
	toast._closeGlyph = closeGlyph
	if closeGlyph then
		closeGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
		closeGlyph.Position = UDim2.fromScale(0.5, 0.5)
	end
	local closeHit = Util.create("TextButton", {
		Name = "CloseHit",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Parent = closeHolder,
	})
	toast._closeHolder = closeHolder
	toast._closeHit = closeHit

	local body = Util.text({
		Name = "Body",
		Text = spec.Body or spec.Text or "",
		TextSize = tokens.fontSizeSm,
		Font = "body",
		TextColor3 = tokens.textMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Visible = (spec.Body or spec.Text) ~= nil,
		Parent = inner,
	})
	toast._body = body

	-- Action row.
	local actionRow = Util.row({
		Name = "Actions",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Visible = false,
		Parent = inner,
	})
	Util.list(actionRow, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	toast._actionRow = actionRow

	-- Countdown rail at the bottom edge.
	local countdownTrack = Util.frame({
		Name = "Countdown",
		Size = UDim2.new(1, 0, 0, 2),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = tokens[tone.accent],
		BackgroundTransparency = 0.82,
		ZIndex = 3,
		Parent = card,
	})
	toast._countdown = countdownTrack
	toast._countdownFill = Util.frame({
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tokens[tone.accent],
		ZIndex = 4,
		Parent = countdownTrack,
	})

	local hit = Util.create("TextButton", {
		Name = "Hit",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = card,
	})
	toast._hit = hit

	return toast
end

--- Pushes a notification.
--- @param spec { Title?, Body?, Text?, Tone?, Icon?, Duration?, Actions?: { {Text, Tone?, Callback} }, Key?, Id?, Persist?, OnClick?, Order? }
--- @return string id
function Notify:push(spec: { [any]: any }): string
	self._counter += 1
	local id = spec.Id or ("vantage-toast-" .. tostring(self._counter))

	-- Grouped update: same Key replaces the content and bumps a counter.
	if spec.Key and self._byKey[spec.Key] then
		local existing = self._byKey[spec.Key]
		existing.count += 1
		existing._body.Text = spec.Body or spec.Text or existing._body.Text
		if spec.Title then
			existing._title.Text = spec.Title
		end
		existing._count.Visible = existing.count > 1
		existing._count.Text = "x" .. tostring(existing.count)
		Motion.setScale(existing.Instance, 0.96)
		Motion.scale(existing.Instance, 1, { duration = 0.3, easing = "settle" })
		existing._remaining = spec.Duration
		return existing.id
	end

	local toast = buildToast(self, spec)
	table.insert(self._queue, toast)
	self:_pump()

	self.Pushed:fire(toast, self)
	if not spec.Silent then
		Button.playCue("notify")
	end
	return id
end

--- Internal: promotes queued toasts into the visible stack.
function Notify:_pump()
	while #self._active < self._max and #self._queue > 0 do
		local toast = table.remove(self._queue, 1)
		self:_show(toast)
	end
end

function Notify:_show(toast: any)
	table.insert(self._active, toast)
	if toast.key then
		self._byKey[toast.key] = toast
	end

	local card = toast.Instance
	local spec = toast._spec

	-- Build actions on first show: they depend on the live spec and
	-- must not be constructed for toasts that are still queued.
	if spec.Actions and #spec.Actions > 0 then
		toast._actionRow.Visible = true
		for index, action in ipairs(spec.Actions) do
			local button = Button.new({
				Text = action.Text,
				Variant = action.Tone or (index == 1 and "secondary" or "ghost"),
				Size = "sm",
				LayoutOrder = index,
				Callback = function()
					Util.safeCall(action.Callback, self)
					if action.KeepOpen ~= true then
						self:dismiss(toast)
					end
				end,
			}, { parent = toast._actionRow, maid = self._maid })
			table.insert(toast._buttons, button)
		end
	end

	local duration = spec.Duration
	if duration == nil then
		duration = spec.Persist and math.huge or 4.6
	end
	toast._duration = duration
	toast._remaining = duration
	toast._paused = false

	-- Entrance.
	card.Visible = true
	card.Position = UDim2.fromOffset(WIDTH * 0.5, 0)
	card.GroupTransparency = 1
	Motion.tween(card, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, {
		duration = 0.36,
		easing = "enterSnap",
	})
	Motion.setScale(card, 0.94)
	Motion.scale(card, 1, { duration = 0.4, easing = "settle" })
	toast._countdownFill.Size = UDim2.fromScale(1, 1)

	-- Counting down.
	if duration ~= math.huge and duration > 0 then
		toast._countdownTween = Motion.tween(toast._countdownFill, { Size = UDim2.fromScale(0, 1) }, {
			duration = duration,
			easing = "linear",
			onComplete = function()
				if not toast._paused then
					self:dismiss(toast)
				end
			end,
		})
	end

	toast._hit.Activated:Connect(function()
		if spec.OnClick then
			Util.safeCall(spec.OnClick, toast, self)
		end
		if spec.OnClickDismiss ~= false then
			self:dismiss(toast)
		end
	end)
	toast._closeHit.Activated:Connect(function()
		self:dismiss(toast)
	end)
	toast._closeHit.MouseEnter:Connect(function()
		toast._closeHolder.BackgroundTransparency = 0
		Glyph.setColor(toast._closeGlyph, self._tokens.textMuted)
	end)
	toast._closeHit.MouseLeave:Connect(function()
		toast._closeHolder.BackgroundTransparency = 1
		if toast._closeGlyph then
			Glyph.setColor(toast._closeGlyph, self._tokens.textDim)
		end
	end)
	toast._hit.MouseEnter:Connect(function()
		toast._paused = true
		if toast._countdownTween then
			toast._countdownTween:pause()
		end
	end)
	toast._hit.MouseLeave:Connect(function()
		toast._paused = false
		if toast._countdownTween then
			toast._countdownTween:resume()
		end
	end)
end

--- Dismisses a toast by handle or id.
function Notify:dismiss(target: any)
	local toast
	if type(target) == "string" then
		for _, candidate in ipairs(self._active) do
			if candidate.id == target then
				toast = candidate
				break
			end
		end
		if not toast then
			for index, candidate in ipairs(self._queue) do
				if candidate.id == target then
					table.remove(self._queue, index)
					return self
				end
			end
		end
	else
		toast = target
	end
	if not toast then
		return self
	end

	local index = table.find(self._active, toast)
	if not index then
		return self
	end
	table.remove(self._active, index)
	if toast.key then
		self._byKey[toast.key] = nil
	end
	if toast._countdownTween then
		toast._countdownTween:cancel()
	end

	local card = toast.Instance
	Motion.tween(card, { GroupTransparency = 1, Position = UDim2.fromOffset(30, 0) }, {
		duration = 0.2,
		easing = "exit",
		onComplete = function()
			card:Destroy()
		end,
	})
	Motion.scale(card, 0.96, { duration = 0.2, easing = "exit" })

	self.Dismissed:fire(toast, self)
	-- Fill the freed slot on the next frame so the exit is visible first.
	task.defer(function()
		self:_pump()
	end)
	return self
end

--- Dismisses every toast, including queued ones.
function Notify:clear()
	for _, toast in ipairs(table.clone(self._active)) do
		self:dismiss(toast)
	end
	for _, toast in ipairs(self._queue) do
		toast.Instance:Destroy()
	end
	table.clear(self._queue)
	table.clear(self._byKey)
	return self
end

function Notify:count(): number
	return #self._active
end

function Notify:destroy()
	self.Pushed:destroy()
	self.Dismissed:destroy()
	self._maid:destroy()
	if self.Instance then
		self.Instance:Destroy()
		self.Instance = nil
	end
end

return Notify
