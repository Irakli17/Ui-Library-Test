--!nonstrict
--[[
	Vantage 1.0.0 · Primitives/Ripple
	------------------------------------------------------------------
	Press feedback, anchored to the exact point the pointer landed.

	Ripples are pooled and capped. Spamming a button cannot allocate an
	unbounded number of frames, and a ripple that is still fading when
	its slot is reused is not orphaned — it is finished off in place.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)

local Ripple = {}
Ripple.__index = Ripple

local MAX_POOL = 6

--- Creates a ripple host. Ripples are drawn inside `host`, which must
--- clip its descendants for the effect to read correctly.
function Ripple.new(host: any, options: { [any]: any }?)
	local self = setmetatable({
		_host = host,
		_options = options or {},
		_pool = {},
		_live = 0,
		_seed = 0,
	}, Ripple)

	host.ClipsDescendants = true
	if self._options.clip ~= false then
		Util.corner(host, self._options.radius or 8)
	end

	return self
end

local function acquire(self: any)
	for _, ripple in ipairs(self._pool) do
		if not ripple.busy then
			return ripple
		end
	end
	if #self._pool >= MAX_POOL then
		-- Recycle the oldest rather than growing the pool.
		local oldest = self._pool[1]
		table.remove(self._pool, 1)
		return oldest
	end

	local frame = Util.frame({
		Name = "VantageRipple",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 0),
		ZIndex = self._options.zIndex or 4,
		Parent = self._host,
	})
	Util.pill(frame)

	local entry = { frame = frame, busy = false, tween = nil }
	table.insert(self._pool, entry)
	return entry
end

--- Emits a ripple.
--- @param x number|nil Local X inside the host. Defaults to the centre.
--- @param y number|nil Local Y inside the host. Defaults to the centre.
function Ripple:burst(x: number?, y: number?, options: { [any]: any }?)
	local opts = self._options
	local override = options or {}

	local size = self._host.AbsoluteSize
	local width, height = size.X, size.Y
	if width <= 0 or height <= 0 then
		-- The host has not been laid out yet; skip rather than draw a
		-- zero-sized flash at the origin.
		return
	end

	local originX = x or width * 0.5
	local originY = y or height * 0.5

	-- Radius must reach the furthest corner for the ripple to cover the
	-- whole control, whatever the pointer position.
	local radius = math.max(
		math.sqrt(originX * originX + originY * originY),
		math.sqrt((width - originX) ^ 2 + originY * originY),
		math.sqrt(originX * originX + (height - originY) ^ 2),
		math.sqrt((width - originX) ^ 2 + (height - originY) ^ 2)
	)

	local entry = acquire(self)
	if entry.tween then
		entry.tween:cancel()
		entry.tween = nil
	end

	local frame = entry.frame
	entry.busy = true
	self._seed += 1
	frame.ZIndex = (opts.zIndex or 4) + (self._seed % 3)

	local color = override.color or opts.color
	if not color then
		color = require(script.Parent.Parent.Core.Theme).current().accent
	end
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = override.transparency or opts.transparency or 0.72
	frame.Position = UDim2.fromOffset(originX, originY)
	frame.Size = UDim2.fromOffset(0, 0)

	local target = radius * 2
	local duration = override.duration or opts.duration or 0.52

	entry.tween = Motion.tween(frame, {
		Size = UDim2.fromOffset(target, target),
		BackgroundTransparency = 1,
	}, {
		duration = duration,
		easing = override.easing or "exitSoft",
		onComplete = function()
			entry.busy = false
			entry.tween = nil
		end,
	})

	return entry
end

--- Emits a short "click flash" — a soft full-control bloom used when a
--- ripple would be too loud (icon buttons, list rows).
function Ripple:flash(options: { [any]: any }?)
	local opts = table.clone(self._options)
	for key, value in pairs(options or {}) do
		opts[key] = value
	end
	local size = self._host.AbsoluteSize
	return self:burst(size.X * 0.5, size.Y * 0.5, opts)
end

--- Cancels every in-flight ripple and hides the pool.
function Ripple:clear()
	for _, entry in ipairs(self._pool) do
		if entry.tween then
			entry.tween:cancel()
			entry.tween = nil
		end
		entry.busy = false
		entry.frame.BackgroundTransparency = 1
		entry.frame.Size = UDim2.fromOffset(0, 0)
	end
end

function Ripple:destroy()
	self:clear()
	for _, entry in ipairs(self._pool) do
		entry.frame:Destroy()
	end
	table.clear(self._pool)
end

return Ripple
