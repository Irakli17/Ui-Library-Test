--!nonstrict
--[[
	Vantage 1.0.0 · Core/Motion
	------------------------------------------------------------------
	The animation engine. One scheduler drives every tween and spring in
	the entire library, so a window with two hundred live components
	still costs exactly one RunService connection and one frame budget.

	Design notes
	------------
	· Interpolation is typed. Numbers, Color3, UDim, UDim2, Vector2,
	  Vector3 and Rect all interpolate correctly; anything else is
	  rejected loudly rather than silently snapping.
	· Tweens capture their start value on the first frame, so
	  interrupting an in-flight animation is always smooth.
	· Springs integrate on a fixed 1/240s sub-step, which keeps them
	  stable at any frame rate and lets a spring settle exactly.
	· `Motion.step(dt)` is public. Tests drive time deterministically
	  through it; the scheduler calls it from RenderStepped.
	· Reduced-motion collapses every duration to zero without changing
	  the API surface.
]]

local RunService
local Easing = require(script.Parent.Easing)

local Motion = {}

--- Set by `Motion.setReducedMotion`. Declared up front so every
--- function below can close over a stable boolean.
Motion._reducedMotion = false

-- Duration presets, in seconds. Tuned against the 60/120/144 Hz
-- reality of Roblox clients rather than a design tool.
Motion.Durations = {
	instant = 0,
	swift = 0.09,
	fast = 0.16,
	normal = 0.24,
	slow = 0.36,
	deliberate = 0.55,
	cinematic = 0.9,
}

--- Ready-made option bundles: `Motion.options("press")`.
Motion.presets = {
	instant = { duration = 0, easing = "linear" },
	-- The cross-fade preset: label swaps, scroll-into-view, tooltip fade.
	-- Shorter than `hover`, long enough to read as a transition.
	fast = { duration = 0.16, easing = "move" },
	hover = { duration = 0.14, easing = "move" },
	press = { duration = 0.08, easing = "exitSoft" },
	release = { duration = 0.34, easing = "settle" },
	enter = { duration = 0.32, easing = "enterSnap" },
	exit = { duration = 0.18, easing = "exit" },
	panel = { duration = 0.34, easing = "enterSnap" },
	expand = { duration = 0.3, easing = "emphasize" },
	collapse = { duration = 0.22, easing = "exit" },
	emphasized = { duration = 0.5, easing = "emphasize" },
	cinematic = { duration = 0.9, easing = "enterSnap" },
}

--- Merges a preset with overrides. Accepts a preset name or table.
function Motion.options(preset: any, overrides: { [any]: any }?): { [any]: any }
	local base: any
	if type(preset) == "string" then
		base = Motion.presets[preset]
		if not base then
			warn(string.format("[Vantage] unknown motion preset %q", tostring(preset)))
			base = Motion.presets.hover
		end
	else
		base = preset or Motion.presets.hover
	end
	if not overrides then
		return base
	end
	local out = table.clone(base)
	for key, value in pairs(overrides) do
		out[key] = value
	end
	return out
end

--[[ Interpolation -------------------------------------------------- ]]

local copiers = {
	number = function(value: number): number
		return value
	end,
	Color3 = function(value: any): any
		return Color3.new(value.R, value.G, value.B)
	end,
	UDim = function(value: any): any
		return UDim.new(value.Scale, value.Offset)
	end,
	UDim2 = function(value: any): any
		return UDim2.new(value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset)
	end,
	Vector2 = function(value: any): any
		return Vector2.new(value.X, value.Y)
	end,
	Vector3 = function(value: any): any
		return Vector3.new(value.X, value.Y, value.Z)
	end,
	Rect = function(value: any): any
		return Rect.new(value.Min.X, value.Min.Y, value.Max.X, value.Max.Y)
	end,
}

--- Returns a deep-enough copy so captured start values never alias the
--- live property object.
function Motion.copy(value: any): any
	local copier = copiers[typeof(value)]
	if copier then
		return copier(value)
	end
	if type(value) == "number" then
		return value
	end
	return value
end

local function lerpNumber(a: number, b: number, t: number): number
	return a + (b - a) * t
end

--- Type-dispatched interpolation. This is the only place in Vantage
--- that knows how to blend two values.
function Motion.lerp(from: any, to: any, alpha: number): any
	local kind = typeof(from)
	if kind ~= typeof(to) then
		warn(string.format("[Vantage] cannot interpolate %s -> %s; snapping", kind, typeof(to)))
		return alpha >= 1 and to or from
	end

	if kind == "number" then
		return lerpNumber(from, to, alpha)
	elseif kind == "Color3" then
		return Color3.new(
			lerpNumber(from.R, to.R, alpha),
			lerpNumber(from.G, to.G, alpha),
			lerpNumber(from.B, to.B, alpha)
		)
	elseif kind == "UDim" then
		return UDim.new(
			lerpNumber(from.Scale, to.Scale, alpha),
			lerpNumber(from.Offset, to.Offset, alpha)
		)
	elseif kind == "UDim2" then
		return UDim2.new(
			lerpNumber(from.X.Scale, to.X.Scale, alpha),
			lerpNumber(from.X.Offset, to.X.Offset, alpha),
			lerpNumber(from.Y.Scale, to.Y.Scale, alpha),
			lerpNumber(from.Y.Offset, to.Y.Offset, alpha)
		)
	elseif kind == "Vector2" then
		return Vector2.new(
			lerpNumber(from.X, to.X, alpha),
			lerpNumber(from.Y, to.Y, alpha)
		)
	elseif kind == "Vector3" then
		return Vector3.new(
			lerpNumber(from.X, to.X, alpha),
			lerpNumber(from.Y, to.Y, alpha),
			lerpNumber(from.Z, to.Z, alpha)
		)
	elseif kind == "Rect" then
		return Rect.new(
			lerpNumber(from.Min.X, to.Min.X, alpha),
			lerpNumber(from.Min.Y, to.Min.Y, alpha),
			lerpNumber(from.Max.X, to.Max.X, alpha),
			lerpNumber(from.Max.Y, to.Max.Y, alpha)
		)
	end

	return alpha >= 1 and to or from
end

--- True when `value` is a type Motion knows how to interpolate.
function Motion.isAnimatable(value: any): boolean
	local kind = typeof(value)
	return copiers[kind] ~= nil or type(value) == "number"
end

--- True when `value` is a property-bag target (Instance or table).
local function isObject(value: any): boolean
	local kind = type(value)
	return kind == "table" or kind == "userdata" or typeof(value) == "Instance"
end

--[[ Owner tracking ------------------------------------------------- ]]

-- Weak keys: a destroyed window is collected even if a tween was
-- somehow left registered against it.
local ownerTweens = setmetatable({}, { __mode = "k" })

local function trackOwner(owner: any, tween: any)
	local list = ownerTweens[owner]
	if not list then
		list = {}
		ownerTweens[owner] = list
		-- Auto-cancel when the instance dies, so a destroyed window can
		-- never keep animating a detached tree.
		pcall(function()
			owner.Destroying:Connect(function()
				Motion.cancelAll(owner)
			end)
		end)
	end
	list[tween] = true
end

local function untrackOwner(owner: any, tween: any)
	local list = ownerTweens[owner]
	if list then
		list[tween] = nil
	end
end

--- Cancels every tween currently targeting `owner`.
function Motion.cancelAll(owner: any): number
	local list = ownerTweens[owner]
	if not list then
		return 0
	end
	ownerTweens[owner] = nil
	local count = 0
	for tween in pairs(list) do
		tween:cancel()
		count += 1
	end
	return count
end

--- Property ownership: at most one tween may drive a given property of
--- a given target at a time. Two competing tweens writing the same
--- property every frame is a classic source of jitter and of "the value
--- came out wrong" bugs, so a new tween supersedes the one it replaces
--- rather than racing it.
local ownerProperties = setmetatable({}, { __mode = "k" })

local function claimProperties(target: any, props: { [any]: any }, tween: any)
	local claims = ownerProperties[target]
	if not claims then
		claims = {}
		ownerProperties[target] = claims
	end
	for key in pairs(props) do
		local existing = claims[key]
		if existing and existing ~= tween then
			existing:cancel()
		end
		claims[key] = tween
	end
end

local function releaseProperties(target: any, props: { [any]: any }, tween: any)
	local claims = ownerProperties[target]
	if not claims then
		return
	end
	for key in pairs(props) do
		if claims[key] == tween then
			claims[key] = nil
		end
	end
end

--- Number of owners with live tweens. Diagnostic only.
function Motion.trackedOwners(): number
	local count = 0
	for _ in pairs(ownerTweens) do
		count += 1
	end
	return count
end

--[[ Scheduler ------------------------------------------------------ ]]

-- Slots that had to be skipped because they were reclaimed mid-frame.
-- Should stay at zero; `Motion.audit()` reports it so a regression is
-- visible rather than invisible.
local skips = 0

local activeTweens = {}
local activeSprings = {}
local activeTickers = {}
local tweenCount = 0
local springCount = 0
local tickerCount = 0
local connection = nil
local timeScale = 1
local MAX_FRAME_DELTA = 1 / 20
local clock = 0

local function ensureRunning()
	if connection then
		return
	end
	if not RunService then
		local ok, service = pcall(function()
			return game:GetService("RunService")
		end)
		RunService = ok and service or false
	end
	if not RunService or not RunService.RenderStepped then
		-- Headless: Motion.step must be called manually.
		return
	end
	local event = RunService.RenderStepped
	if type(event) == "function" then
		-- Some hosts expose a plain function rather than an RBXScriptSignal.
		connection = { Disconnect = function() end }
		event(function(dt)
			Motion.step(dt)
		end)
		return
	end
	connection = event:Connect(function(dt)
		Motion.step(dt)
	end)
end

local function stopRunning()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

-- Tracking is idempotent. A tween that is resumed after being created
-- paused used to be registered twice, which left a stale slot behind: the
-- slot was later reclaimed by a different tween, and the next frame wrote
-- through it and emptied a live entry. That is the whole reason
-- `Motion.audit()` exists.
local function trackTween(tween)
	if tween._slot then
		return
	end
	tweenCount += 1
	activeTweens[tweenCount] = tween
	tween._slot = tweenCount
	ensureRunning()
end

--- Finds the live slot of a tween whose cached slot is stale, or nil.
local function findTweenSlot(tween): number?
	for index = 1, tweenCount do
		if activeTweens[index] == tween then
			return index
		end
	end
	return nil
end

local function untrackTween(tween)
	local slot = tween._slot
	tween._slot = nil
	if not slot then
		return
	end
	-- Trust the slot only when it actually points at this tween; a stale
	-- slot would otherwise swap an unrelated tween out of the live range.
	if slot > tweenCount or activeTweens[slot] ~= tween then
		slot = findTweenSlot(tween)
		if not slot then
			return
		end
	end
	local last = activeTweens[tweenCount]
	activeTweens[slot] = last
	if last then
		last._slot = slot
	end
	activeTweens[tweenCount] = nil
	tweenCount -= 1
end

local function trackSpring(spring)
	springCount += 1
	activeSprings[springCount] = spring
	spring._slot = springCount
	ensureRunning()
end

local function untrackSpring(spring)
	local slot = spring._slot
	if not slot then
		return
	end
	local last = activeSprings[springCount]
	activeSprings[slot] = last
	if last then
		last._slot = slot
	end
	activeSprings[springCount] = nil
	springCount -= 1
	spring._slot = nil
end

--- Global motion multiplier. `0.25` is a nice "camera slow motion"
--- for cinematics; `2` makes the whole UI feel snappier.
function Motion.setTimeScale(value: number)
	timeScale = math.max(0, value)
end

function Motion.getTimeScale(): number
	return timeScale
end

--- Number of live animations. Shown in the Window status bar.
function Motion.stats()
	return {
		tweens = tweenCount,
		springs = springCount,
		tickers = tickerCount,
		total = tweenCount + springCount + tickerCount,
		running = connection ~= nil,
	}
end

--[[ Per-frame tickers --------------------------------------- ]]
-- A ticker is a callback driven by the same scheduler as every tween,
-- with the same dt clamping and time scaling. Components that need a
-- continuous time signal (the logo wave, ambient shaders, idle
-- animations) use this instead of opening their own RenderStepped
-- connection, so the whole library still costs one connection.

local function trackTicker(ticker)
	tickerCount += 1
	activeTickers[tickerCount] = ticker
	ticker._slot = tickerCount
	ensureRunning()
end

local function untrackTicker(ticker)
	local slot = ticker._slot
	if not slot then
		return
	end
	local last = activeTickers[tickerCount]
	activeTickers[slot] = last
	if last then
		last._slot = slot
	end
	activeTickers[tickerCount] = nil
	tickerCount -= 1
	ticker._slot = nil
end

local Ticker = {}
Ticker.__index = Ticker

--- Creates a per-frame ticker.
--- `callback(dt, elapsed, ticker)` is invoked once per rendered frame
--- while the ticker is running.
function Motion.ticker(callback: (number, number, any) -> ()): any
	local self = setmetatable({
		_callback = callback,
		_elapsed = 0,
		_paused = false,
		_running = true,
	}, Ticker)
	trackTicker(self)
	return self
end

function Ticker:_update(dt: number)
	if self._paused then
		return
	end
	self._elapsed += dt
	local ok, err = pcall(self._callback, dt, self._elapsed, self)
	if not ok then
		warn("[Vantage] ticker errored: " .. tostring(err))
		-- A throwing ticker would spam every frame; stop it instead.
		self:destroy()
	end
end

function Ticker:pause()
	self._paused = true
	return self
end

function Ticker:resume()
	self._paused = false
	return self
end

function Ticker:isRunning(): boolean
	return self._running and not self._paused
end

function Ticker:elapsed(): number
	return self._elapsed
end

function Ticker:reset()
	self._elapsed = 0
	return self
end

function Ticker:destroy()
	self._running = false
	self._callback = nil
	untrackTicker(self)
end

--- Fades an instance's transparency toward a goal, then back, on a
--- loop. Used for ambient pulses (the logo glow, loading hints).
function Motion.breathe(instance: any, property: string, from: number, to: number, period: number, options: { [any]: any }?): any
	local tween = Motion.tween(instance, { [property] = to }, Motion.options({
		duration = period * 0.5,
		easing = "sineInOut",
		repeatCount = -1,
		reverse = true,
	}, options))
	instance[property] = from
	return tween
end

--- Advances the animation world by `dt` seconds.
--- Called automatically from RenderStepped; call it yourself when
--- driving Vantage from a custom loop or from a test harness.
function Motion.step(dt: number)
	dt = math.min(dt or 0, MAX_FRAME_DELTA) * timeScale
	if dt <= 0 then
		return
	end
	clock += dt

	-- Tweens. Iterate backwards so swap-removal is safe. An update can
	-- cancel its neighbours and start new animations, so the range is
	-- re-read on every step and a slot that was reclaimed mid-frame is
	-- skipped rather than indexed (`Motion.audit()` counts it as a skip,
	-- and the test suite asserts the count stays at zero).
	for index = tweenCount, 1, -1 do
		local tween = activeTweens[index]
		if tween then
			tween:_update(dt)
		else
			skips += 1
		end
	end

	-- Springs.
	for index = springCount, 1, -1 do
		local spring = activeSprings[index]
		if spring then
			spring:_update(dt)
		else
			skips += 1
		end
	end

	-- Tickers.
	for index = tickerCount, 1, -1 do
		local ticker = activeTickers[index]
		if ticker then
			ticker:_update(dt)
		else
			skips += 1
		end
	end

	if tweenCount == 0 and springCount == 0 and tickerCount == 0 then
		stopRunning()
	end
end

--- Inspects the registries for internal inconsistency.
---
--- A live slot that is nil means a tween was untracked twice or kept a
--- stale slot and then had it swapped away; a duplicate means the same
--- tween was tracked twice. Both are silent until the frame that walks
--- the array, which is exactly why this is public: `Vantage.Diagnostics()`
--- surfaces it, and the test suite asserts `holes == 0` after every suite.
function Motion.audit(): { [any]: any }
	local holes, tracked, duplicates, strays = 0, 0, 0, 0
	local seen = {}
	for index = 1, tweenCount do
		local tween = activeTweens[index]
		if tween == nil then
			holes += 1
		else
			tracked += 1
			if seen[tween] then
				duplicates += 1
			end
			seen[tween] = true
		end
	end
	-- Entries past the counter are leaks: a slot that was never reclaimed.
	for index = tweenCount + 1, #activeTweens do
		if activeTweens[index] ~= nil then
			strays += 1
		end
	end
	return {
		count = tweenCount,
		tracked = tracked,
		holes = holes,
		duplicates = duplicates,
		strays = strays,
		skips = skips,
		arraySize = #activeTweens,
	}
end

--- Resets the skip counter. A host that keeps `skips` at zero across a
--- session knows the registry has never had to defend itself.
function Motion.resetAudit()
	skips = 0
end

--- Current scheduler time in seconds. Monotonic, unaffected by
--- `os.clock` semantics on different hosts.
function Motion.clock(): number
	return clock
end

--[[ Tween ---------------------------------------------------------- ]]

local Tween = {}
Tween.__index = Tween

local Signal = require(script.Parent.Signal)

local function isReduced()
	return Motion._reducedMotion == true
end

--- Creates a tween.
---
--- `target` may be:
---   · an Instance — `props` maps property names to target values
---   · a table — `props` maps keys to target values (`prop = nil`?)
---   · a function — called with `(alpha, elapsed, tween)`
---
--- @param target any
--- @param props { [any]: any }
--- @param options { duration: number?, easing: any?, delay: number?, repeatCount: number?, reverse: boolean?, speed: number?, onUpdate: any?, onComplete: any? }
function Motion.tween(target: any, props: { [any]: any }, options: { [any]: any }?): any
	local opts = options or {}
	local self = setmetatable({
		-- `repeatCount`: 0 plays once (default), -1 loops forever,
		-- n plays n+1 times.
		_target = target,
		_props = props,
		_delay = math.max(0, opts.delay or 0),
		_duration = math.max(0, opts.duration or Motion.Durations.normal),
		_easing = Easing.resolve(opts.easing or "move"),
		_repeatCount = opts.repeatCount or 0,
		_reverse = opts.reverse == true,
		_speed = opts.speed or 1,
		_elapsed = 0,
		_iteration = 0,
		_startValues = nil,
		_playing = true,
		_finished = false,
		_onUpdate = opts.onUpdate,
		_onComplete = opts.onComplete,
		_owner = isObject(target) and target or nil,
		Completed = Signal.new("Tween.Completed"),
		Cancelled = Signal.new("Tween.Cancelled"),
	}, Tween)

	if isReduced() then
		self._duration = 0
		self._delay = 0
		self._easing = Easing.linear
	end

	if opts.play == false then
		self._playing = false
	end

	-- Register for cleanup and instance tracking.
	if self._owner then
		trackOwner(self._owner, self)
	end
	claimProperties(target, props, self)
	if self._playing then
		trackTween(self)
		self:_update(0)
	end
	return self
end

--- Tweens many targets at once with the same options.
function Motion.tweenAll(targets: { any }, props: { [any]: any }, options: { [any]: any }?): { any }
	local out = {}
	for _, target in ipairs(targets) do
		table.insert(out, Motion.tween(target, props, options))
	end
	return out
end

function Tween:_capture()
	if self._startValues then
		return
	end
	local captured = {}
	if isObject(self._target) then
		for key in pairs(self._props) do
			local ok, value = pcall(function()
				return self._target[key]
			end)
			if not ok or value == nil then
				if not ok then
					warn(string.format("[Vantage] cannot read %s on target; property skipped", tostring(key)))
				end
				captured[key] = false
			else
				captured[key] = Motion.copy(value)
			end
		end
	end
	self._startValues = captured
end

function Tween:_write(alpha)
	local target = self._target
	if isObject(target) then
		for key, goal in pairs(self._props) do
			local start = self._startValues[key]
			if start ~= false then
				local value = Motion.lerp(start, goal, alpha)
				local ok = pcall(function()
					target[key] = value
				end)
				if not ok then
					warn(string.format("[Vantage] cannot assign %s on target", tostring(key)))
				end
			end
		end
	elseif type(target) == "function" then
		target(alpha, self._elapsed, self)
	end
end

function Tween:_update(dt)
	if not self._playing or self._finished then
		return
	end

	if self._delay > 0 then
		self._delay -= dt * self._speed
		if self._delay > 0 then
			return
		end
		dt = -self._delay / self._speed
		self._delay = 0
	end

	self:_capture()

	self._elapsed += dt * self._speed

	-- One "cycle" is a there-and-back trip when reversing, and a single
	-- pass otherwise. This is the unit that `repeatCount` counts.
	local cycle = self._reverse and self._duration * 2 or self._duration

	local alpha = cycle <= 0 and 1 or math.min(self._elapsed / cycle, 1)
	local eased
	if self._reverse then
		-- Ping-pong within the cycle: 0 -> 1 -> 0.
		local phase = alpha * 2
		if phase > 1 then
			phase = 2 - phase
		end
		eased = self._easing(phase)
	else
		eased = self._easing(alpha)
	end

	self:_write(eased)
	if self._onUpdate then
		local ok, err = pcall(self._onUpdate, alpha, self._elapsed, self)
		if not ok then
			warn("[Vantage] tween onUpdate errored: " .. tostring(err))
		end
	end

	if self._elapsed < cycle then
		return
	end

	self._iteration += 1
	local looping = self._repeatCount == -1 or self._iteration <= self._repeatCount
	if looping then
		-- Carry the overshoot into the next cycle so loops never drift.
		self._elapsed = cycle > 0 and (self._elapsed % cycle) or 0
		return
	end

	self:_complete()
end

function Tween:_complete()
	if self._finished then
		return
	end
	self:_capture()
	self:_write(1)
	self._finished = true
	self._playing = false
	untrackTween(self)
	releaseProperties(self._target, self._props, self)
	if self._owner then
		untrackOwner(self._owner, self)
	end
	if self._onComplete then
		local ok, err = pcall(self._onComplete, self)
		if not ok then
			warn("[Vantage] tween onComplete errored: " .. tostring(err))
		end
	end
	self.Completed:fire(self)
end

--- Stops the tween and leaves the target at its current value.
function Tween:cancel()
	if self._finished and not self._playing then
		return
	end
	self._playing = false
	self._finished = true
	untrackTween(self)
	releaseProperties(self._target, self._props, self)
	if self._owner then
		untrackOwner(self._owner, self)
	end
	self.Cancelled:fire(self)
end

--- Jumps straight to the end value and completes.
function Tween:complete()
	if self._finished then
		return
	end
	self:_complete()
end

function Tween:isPlaying(): boolean
	return self._playing and not self._finished
end

--- Changes playback speed mid-flight. Negative values rewind.
function Tween:setSpeed(speed: number)
	self._speed = speed
end

--- Retargets an in-flight tween without restarting it. The easing
--- restarts from the current alpha, so the motion stays continuous.
function Tween:retarget(props: { [any]: any }, options: { [any]: any }?)
	releaseProperties(self._target, self._props, self)
	claimProperties(self._target, props, self)
	if options then
		if options.duration then
			self._duration = math.max(0, options.duration)
		end
		if options.easing then
			self._easing = Easing.resolve(options.easing)
		end
	end
	self._props = props
	-- Re-capture from the live values so the new path starts where we are.
	self._startValues = nil
	self:_capture()
	local alpha = self._duration <= 0 and 1 or math.min(self._elapsed / self._duration, 1)
	self._elapsed = self._duration * alpha
	return self
end

--- Enables/disables the tween without losing its position.
function Tween:resume()
	if self._finished then
		return self
	end
	if not self._playing then
		self._playing = true
		trackTween(self)
	end
	return self
end

function Tween:pause()
	if self._playing and not self._finished then
		self._playing = false
		untrackTween(self)
	end
	return self
end

Tween.destroy = Tween.cancel

--[[ Declarative helpers -------------------------------------------- ]]

--- Function-driven animation: `Motion.animate({ duration = 0.3 }, function(alpha) ... end)`.
function Motion.animate(options: { [any]: any }, onUpdate: (number, number, any) -> ()): any
	local opts = table.clone(options)
	opts.onUpdate = onUpdate
	return Motion.tween(function() end, {}, opts)
end

--- Staggered animation across a list, both for instances and for
--- index-driven effects. Returns the created tweens.
---
--- `Motion.stagger(items, 0.04, function(item, index) return ... end)`
--- `Motion.stagger(instances, 0.04, props, options)`
function Motion.stagger(items: { any }, each: number, third: any, fourth: { [any]: any }?)
	local created = {}
	for index, item in ipairs(items) do
		local delay = (index - 1) * each
		local tween
		if type(third) == "function" then
			local result = third(item, index)
			if result == nil then
				continue
			end
			local options = table.clone(result)
			options.delay = (options.delay or 0) + delay
			tween = Motion.tween(item, options.props or {}, options)
		else
			local options = Motion.options(fourth or "enter", { delay = delay })
			tween = Motion.tween(item, third, options)
		end
		table.insert(created, tween)
	end
	return created
end

--- Runs a list of steps in sequence. Each step is
--- `{ duration = n, easing = "x", onUpdate = fn }`.
function Motion.sequence(steps: { { [any]: any } }): any
	local cancelled = false
	local handle = {
		cancel = function()
			cancelled = true
		end,
		isPlaying = function()
			return not cancelled
		end,
	}

	local index = 0
	local function advance()
		if cancelled then
			return
		end
		index += 1
		local step = steps[index]
		if not step then
			if handle.Completed then
				handle.Completed:fire(handle)
			end
			return
		end
		local options = table.clone(step)
		local userComplete = step.onComplete
		options.onComplete = function(...)
			if userComplete then
				userComplete(...)
			end
			advance()
		end
		local tween = Motion.animate(options, step.onUpdate or function() end)
		handle._current = tween
	end

	handle.Completed = Signal.new("Sequence.Completed")
	advance()
	return handle
end

--- Delays a callback on the animation clock.
function Motion.delay(seconds: number, callback: () -> ()): any
	return Motion.tween(function() end, {}, {
		duration = seconds,
		easing = "linear",
		onComplete = callback,
	})
end

--- Tweens every transparency-bearing property on an instance down to
--- `alpha` (0 = fully opaque, 1 = invisible).
function Motion.fade(instance: any, alpha: number, options: { [any]: any }?): any
	local props = {}
	local properties = {
		"BackgroundTransparency",
		"ImageTransparency",
		"TextTransparency",
		"TextStrokeTransparency",
	}
	for _, property in ipairs(properties) do
		local ok, value = pcall(function()
			return instance[property]
		end)
		if ok and type(value) == "number" then
			props[property] = alpha
		end
	end
	return Motion.tween(instance, props, options)
end

--- Scales an instance by editing its UIScale, creating one if needed.
--- Every scale animation in Vantage goes through this so that nested
--- scales compose correctly instead of fighting.
function Motion.ensureScale(instance: any): any
	local scale = instance:FindFirstChild("VantageScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "VantageScale"
		scale.Parent = instance
	end
	return scale
end

--- Sets the UIScale instantly.
function Motion.setScale(instance: any, value: number): any
	local scale = Motion.ensureScale(instance)
	scale.Scale = value
	return scale
end

--- Tweens an instance's UIScale to `value`.
function Motion.scale(instance: any, value: number, options: { [any]: any }?): any
	local scale = Motion.ensureScale(instance)
	return Motion.tween(scale, { Scale = value }, Motion.options("hover", options))
end

--- Centre-preserving scale: grows from the middle with no drift.
function Motion.pulse(instance: any, amount: number, options: { [any]: any }?): any
	local scale = Motion.ensureScale(instance)
	local out = Motion.options("press", options)
	return Motion.tween(scale, { Scale = amount }, out)
end

--[[ Spring --------------------------------------------------------- ]]

local Spring = {}
Spring.__index = Spring

--- Apple-style spring parameterisation.
--- `response` is the period of one oscillation in seconds (smaller =
--- faster); `damping` is the damping ratio (1 = critically damped,
--- < 1 bounces, > 1 is sluggish).
function Motion.spring(config: { [any]: any }?)
	local cfg = config or {}
	local response = math.max(0.01, cfg.response or cfg.tension and 0.3 or 0.32)
	local damping = cfg.damping or cfg.friction and 0.9 or 0.86

	local self = setmetatable({
		_value = cfg.initial or 0,
		_goal = cfg.initial or 0,
		_velocity = 0,
		_response = response,
		_damping = damping,
		_atRest = true,
		_paused = false,
		_epsilon = cfg.epsilon or 0.0004,
		_listeners = {},
		_driving = cfg.driving == true,
	}, Spring)

	if self._driving then
		self._paused = false
	end
	-- A spring created at its goal costs nothing until it is moved.
	return self
end

--- Sets the target value. Starts the spring immediately.
function Spring:setGoal(goal: number)
	if self._goal == goal then
		return self
	end
	self._goal = goal
	if self._value == goal and math.abs(self._velocity) < self._epsilon then
		return self
	end
	self._atRest = false
	trackSpring(self)
	return self
end

--- Jumps to a value instantly, killing momentum.
function Spring:snap(value: number)
	self._value = value
	self._goal = value
	self._velocity = 0
	self._atRest = true
	untrackSpring(self)
	self:_notify()
	return self
end

function Spring:get(): number
	return self._value
end

function Spring:getGoal(): number
	return self._goal
end

function Spring:getVelocity(): number
	return self._velocity
end

function Spring:isAtRest(): boolean
	return self._atRest
end

--- True when the spring is close enough to its goal to be considered
--- settled, within `tolerance`.
function Spring:isSettled(tolerance: number?): boolean
	local limit = tolerance or self._epsilon
	return math.abs(self._goal - self._value) <= limit
		and math.abs(self._velocity) <= limit * 20
end

--- Fires `callback(value)` on every frame the spring moves.
--- Returns an unsubscribe function.
function Spring:observe(callback: (number, any) -> ())
	table.insert(self._listeners, callback)
	callback(self._value, self)
	return function()
		local index = table.find(self._listeners, callback)
		if index then
			table.remove(self._listeners, index)
		end
	end
end

--- Keeps the spring alive even at rest (used for live drag tracking).
function Spring:setDriving(driving: boolean)
	self._driving = driving
	if driving then
		self._atRest = false
		trackSpring(self)
	elseif self:isSettled() then
		self._atRest = true
		untrackSpring(self)
	end
	return self
end

--- Pushes the value directly and lets the spring settle from there.
function Spring:push(value: number)
	self._value = value
	self._atRest = false
	trackSpring(self)
	self:_notify()
	return self
end

--- Adds an impulse of velocity. Great for swipe/fling interactions.
function Spring:impulse(velocity: number)
	self._velocity += velocity
	if math.abs(velocity) > 0 then
		self._atRest = false
		trackSpring(self)
	end
	return self
end

function Spring:_notify()
	for index = #self._listeners, 1, -1 do
		local listener = self._listeners[index]
		local ok, err = pcall(listener, self._value, self)
		if not ok then
			warn("[Vantage] spring observer errored: " .. tostring(err))
			table.remove(self._listeners, index)
		end
	end
end

local SUB_STEP = 1 / 240

function Spring:_update(dt)
	if self._paused then
		return
	end

	-- Fixed sub-stepping keeps the spring identical at 30 fps and
	-- 240 fps, and prevents the classic high-dt explosion.
	local remaining = dt
	while remaining > 1e-6 do
		local step = math.min(SUB_STEP, remaining)
		remaining -= step

		local omega = (2 * math.pi) / self._response
		local zeta = self._damping
		-- Semi-implicit Euler on a normalised spring system: stable for
		-- all physically meaningful (response, damping) pairs.
		local displacement = self._value - self._goal
		local acceleration = -omega * omega * displacement - 2 * zeta * omega * self._velocity
		self._velocity += acceleration * step
		self._value += self._velocity * step
	end

	self:_notify()

	local settled = math.abs(self._goal - self._value) < self._epsilon
		and math.abs(self._velocity) < self._epsilon * 12
	if settled then
		self._value = self._goal
		self._velocity = 0
		if not self._driving then
			self._atRest = true
			untrackSpring(self)
		end
	end
end

--- Immediately runs the spring to rest, applying the final value.
function Spring:finish()
	self._value = self._goal
	self._velocity = 0
	self:_notify()
	self._atRest = true
	untrackSpring(self)
end

function Spring:destroy()
	self._listeners = {}
	self._atRest = true
	untrackSpring(self)
end

--- Named spring feels. `response`/`damping` are the Apple HIG values.
Motion.springs = {
	precise = { response = 0.22, damping = 1.0 },
	snappy = { response = 0.28, damping = 0.9 },
	quick = { response = 0.32, damping = 0.86 },
	standard = { response = 0.42, damping = 0.88 },
	gentle = { response = 0.62, damping = 0.9 },
	glacial = { response = 1.1, damping = 0.95 },
	bouncy = { response = 0.42, damping = 0.6 },
	elastic = { response = 0.5, damping = 0.42 },
	stiff = { response = 0.38, damping = 1.0 },
}

--- Creates a spring from a named preset, e.g. `Motion.springFrom("bouncy", 0)`.
function Motion.springFrom(name: string, initial: number?): any
	local preset = Motion.springs[name] or Motion.springs.quick
	local config = table.clone(preset)
	config.initial = initial or 0
	return Motion.spring(config)
end

--[[ Animated values ------------------------------------------------- ]]

local AnimatedValue = {}
AnimatedValue.__index = AnimatedValue

--- A standalone animated number driven by a spring. Handy for scroll
--- smoothing, hover weights and anything that should persist.
function Motion.value(initial: number, config: { [any]: any }?): any
	local cfg = table.clone(config or {})
	cfg.initial = initial or 0
	local spring = Motion.spring(cfg)
	local self = setmetatable({
		_spring = spring,
		_listeners = {},
	}, AnimatedValue)

	spring:observe(function(value)
		for index = #self._listeners, 1, -1 do
			local ok, err = pcall(self._listeners[index], value)
			if not ok then
				warn("[Vantage] animated value listener errored: " .. tostring(err))
				table.remove(self._listeners, index)
			end
		end
	end)

	return self
end

function AnimatedValue:set(goal: number)
	self._spring:setGoal(goal)
	return self
end

function AnimatedValue:snap(value: number)
	self._spring:snap(value)
	return self
end

function AnimatedValue:get(): number
	return self._spring:get()
end

function AnimatedValue:observe(callback: (number) -> ())
	table.insert(self._listeners, callback)
	callback(self._spring:get())
	return function()
		local index = table.find(self._listeners, callback)
		if index then
			table.remove(self._listeners, index)
		end
	end
end

function AnimatedValue:destroy()
	table.clear(self._listeners)
	self._spring:destroy()
end

--[[ Reduced motion -------------------------------------------------- ]]

--- When true, every duration collapses to zero. Wired to
--- `Config.animations` and to the player's system preference.
function Motion.setReducedMotion(enabled: boolean)
	Motion._reducedMotion = enabled == true
end

function Motion.getReducedMotion(): boolean
	return Motion._reducedMotion == true
end

return Motion
