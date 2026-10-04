--!nonstrict
--[[
	Vantage 1.0.0 · Overlay/Tooltip
	------------------------------------------------------------------
	Hover tooltips with real placement logic.

	· Appears after a short dwell so a cursor crossing a toolbar does not
	  strobe. The delay is cancelled the moment the pointer leaves.
	· Measures itself before positioning, so a tip near the top of the
	  screen flips below its anchor and one near the right edge shifts
	  left instead of being clipped. This is the part most UI libraries
	  skip and it is the part users notice.
	· One tip exists at a time across the whole application.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)
local Maid = require(script.Parent.Parent.Core.Maid)

local Tooltip = {}
Tooltip.__index = Tooltip

local DELAY = 0.42
local GAP = 8
local MAX_WIDTH = 260

--- @param spec { layer: Instance, delay?: number }
function Tooltip.new(spec: { [any]: any })
	local tokens = Theme.current()
	local self = setmetatable({
		_layer = spec.layer,
		_delay = spec.delay or DELAY,
		_maid = Maid.new("tooltip"),
		_tokens = tokens,
		_current = nil,
		_token = 0,
	}, Tooltip)

	local root = Util.row({
		Name = "VantageTooltip",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = tokens.raised,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 750,
		Parent = spec.layer,
	})
	Util.corner(root, tokens.radiusMd)
	Util.stroke(root, tokens.border, 1, 0.35)
	Util.pad(root, { Left = 10, Right = 10, Top = 7, Bottom = 7 })
	Util.stack(root, 2)
	Util.tag(root, "Vantage")
	self.Instance = root

	local title = Util.text({
		Name = "Title",
		Text = "",
		TextSize = tokens.fontSizeSm,
		Font = "subheading",
		TextColor3 = tokens.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = 1,
		Visible = false,
		Parent = root,
	})
	local body = Util.text({
		Name = "Body",
		Text = "",
		TextSize = tokens.fontSizeSm,
		Font = "body",
		TextColor3 = tokens.textMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = 2,
		Parent = root,
	})
	self.TitleLabel = title
	self.BodyLabel = body

	if self._maid then
		self._maid:add(Theme.Changed:connect(function(next)
			tokens = next
			self._tokens = next
			root.BackgroundColor3 = next.raised
			title.TextColor3 = next.text
			body.TextColor3 = next.textMuted
			local stroke = root:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = next.border
			end
		end))
	end

	self._root = root
	return self
end

local function measure(instance: any): Vector2
	local size = instance.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		return size
	end
	return Vector2.new(MAX_WIDTH, 40)
end

--- Positions the tip near `anchor` with flip and clamp behaviour.
function Tooltip:_place(anchor: any)
	local root = self._root
	local viewport = Util.viewport()
	local insets = Util.insets()
	local anchorPosition = anchor.AbsolutePosition
	local anchorSize = anchor.AbsoluteSize
	local size = measure(root)

	-- Bounded width so long bodies wrap instead of running off screen.
	local available = math.min(MAX_WIDTH, viewport.X - 24)
	root.Size = UDim2.fromOffset(math.min(size.X, available), 0)
	root.AutomaticSize = Enum.AutomaticSize.XY
	local finalSize = measure(root)

	local aboveY = anchorPosition.Y - finalSize.Y - GAP
	local belowY = anchorPosition.Y + anchorSize.Y + GAP
	local placeAbove = aboveY >= insets.top + 6
	if not placeAbove and belowY + finalSize.Y > viewport.Y - insets.bottom - 6 then
		-- Neither side fits: pick whichever has more room.
		placeAbove = (anchorPosition.Y - insets.top) > (viewport.Y - (anchorPosition.Y + anchorSize.Y) - insets.bottom)
	end

	local y = placeAbove and aboveY or belowY
	local x = anchorPosition.X + anchorSize.X * 0.5 - finalSize.X * 0.5
	x = Util.clamp(x, insets.left + 6, viewport.X - finalSize.X - insets.right - 6)
	y = Util.clamp(y, insets.top + 6, viewport.Y - finalSize.Y - insets.bottom - 6)

	root.Position = UDim2.fromOffset(x, y)
	self._placedAbove = placeAbove
	return root.Position
end

--- Attaches a tooltip to a GuiObject.
--- @return { text: (string, string?) -> (), destroy: () -> () }
function Tooltip:attach(instance: any, text: string, titleText: string?)
	if not instance or not text then
		return { text = function() end, destroy = function() end }
	end

	local handle = { _text = text, _title = titleText }

	local enter
	local leave

	local function hide()
		self._token += 1
		if self._current ~= handle then
			return
		end
		self._current = nil
		local root = self._root
		if not root.Visible then
			return
		end
		Motion.scale(root, 0.96, { duration = 0.12, easing = "exit" })
		Motion.tween(root, { BackgroundTransparency = 1 }, {
			duration = 0.12,
			easing = "exit",
			onComplete = function()
				root.Visible = false
			end,
		})
		Motion.tween(self.TitleLabel, { TextTransparency = 1 }, Motion.options("exit"))
		Motion.tween(self.BodyLabel, { TextTransparency = 1 }, Motion.options("exit"))
	end

	local function show()
		self._current = handle
		local token = self._token
		local root = self._root

		self.TitleLabel.Text = handle._title or ""
		self.TitleLabel.Visible = handle._title ~= nil and handle._title ~= ""
		self.BodyLabel.Text = handle._text

		root.Visible = true
		root.BackgroundTransparency = 1
		Motion.setScale(root, 1)
		-- Measure first, then place, then reveal. Placing before the
		-- text is set is what makes naive tooltips jump.
		root.Position = UDim2.fromOffset(-9999, -9999)
		task.defer(function()
			if token ~= self._token or self._current ~= handle then
				return
			end
			self:_place(instance)
			Motion.scale(root, 1, { duration = 0.18, easing = "enterSnap" })
			Motion.tween(root, { BackgroundTransparency = 0 }, { duration = 0.14, easing = "enterSnap" })
			Motion.tween(self.TitleLabel, { TextTransparency = 0 }, Motion.options("enter", { duration = 0.16 }))
			Motion.tween(self.BodyLabel, { TextTransparency = 0 }, Motion.options("enter", { duration = 0.2 }))
		end)
	end

	enter = instance.MouseEnter:Connect(function()
		self._token += 1
		local token = self._token
		task.delay(self._delay, function()
			if token == self._token and not self._current then
				show()
			end
		end)
	end)

	leave = instance.MouseLeave:Connect(function()
		hide()
	end)

	handle.text = function(nextText: string, nextTitle: string?)
		handle._text = nextText
		if nextTitle ~= nil then
			handle._title = nextTitle
		end
		if self._current == handle then
			self.BodyLabel.Text = nextText
			self.TitleLabel.Text = handle._title or ""
			self.TitleLabel.Visible = (handle._title or "") ~= ""
			self:_place(instance)
		end
	end

	handle.destroy = function()
		enter:Disconnect()
		leave:Disconnect()
		if self._current == handle then
			hide()
		end
	end

	return handle
end

--- Shows a free-floating tip anchored to a point. Used by the docs demos.
function Tooltip:showAt(position: Vector2, text: string, titleText: string?)
	self.TitleLabel.Text = titleText or ""
	self.TitleLabel.Visible = (titleText or "") ~= ""
	self.BodyLabel.Text = text
	self._root.Visible = true
	self._root.Position = UDim2.fromOffset(position.X, position.Y)
	Motion.tween(self._root, { BackgroundTransparency = 0 }, Motion.options("fast"))
	return self
end

function Tooltip:destroy()
	self._maid:destroy()
	if self.Instance then
		Motion.cancelAll(self.Instance)
		self.Instance:Destroy()
		self.Instance = nil
	end
end

return Tooltip
