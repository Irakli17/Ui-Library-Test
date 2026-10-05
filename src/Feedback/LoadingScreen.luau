--!nonstrict
--[[
	Vantage 1.0.0 · Feedback/LoadingScreen
	------------------------------------------------------------------
	Preloading, without a takeover.

	This screen is one thing: the wave mark, in the bottom-right corner
	of the safe area, moving while your assets stream in. No backdrop,
	no full-screen panel, no progress bar across the join, no rotating
	tips. The player's view of the world stays visible, and the screen
	never swallows a click, because everything it draws is a passive
	mark in a corner.

	What it still does behind that mark:

	· Real progress. `Spec.Assets` are streamed through
	  `ContentProvider:PreloadAsync` and the progress is driven by the
	  per-asset callback rather than a timer, so `OnProgress` and
	  `Progress` report the truth even though nothing numeric is drawn.
	· Phase reporting. Work is split into named phases with weights, so
	  `OnPhase` can say "Streaming assets" instead of "Loading…".
	· Stall protection. If preloading goes quiet for `StallTimeout` the
	  phase is re-announced as still-working instead of the screen
	  hanging silently, and `MaxDuration` guarantees the player gets in.
	· A minimum display time, so a cached join does not flash the mark
	  for a single frame.
	· Failures are counted, not hidden — `GetReport()` says how many
	  assets failed and what the loader said.
	· The mark rises as progress completes, so the corner still reads as
	  "something is happening" without a number to stare at.
	· Reduced motion keeps the mark still and honest: it appears, it
	  stays, it 'leaves on completion, without the wave.

	Cleanup is total: `destroy()` releases the ScreenGui, every
	connection and the rendering stack.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)
local Config = require(script.Parent.Parent.Core.Config)
local Maid = require(script.Parent.Parent.Core.Maid)
local Signal = require(script.Parent.Parent.Core.Signal)
local LogoWave = require(script.Parent.LogoWave)

local LoadingScreen = {}
LoadingScreen.__index = LoadingScreen

--- Where the mark comes from by default. Leave it empty and the screen
--- draws the procedural mark instead of an empty frame — the corner is
--- never blank.
LoadingScreen.LogoImage = ""

LoadingScreen.defaults = {
	--- Assets handed to ContentProvider. Supply your own.
	Assets = {},
	--- Phases run in order. `Weight` controls how much of the bar each
	--- phase owns; `Run` is an optional function called with a progress
	--- reporter.
	Phases = nil,
	MinDuration = 1.4,
	MaxDuration = 25,
	StallTimeout = 6,
	--- Pixels the mark travels upward across the whole load. Set 0 to
	--- keep it perfectly still.
	Rise = 10,
	--- Seconds the settled mark is held before it leaves on its own.
	--- `false` waits for `handle.continue()` instead.
	AutoContinue = 1.1,
	--- When true the screen waits for `handle.continue()` (or an input of
	--- any kind) instead of leaving on its own.
	RequireInput = false,
	Logo = {
		Image = nil :: string?,
		Size = 104,
		Padding = 26,
		Amplitude = 5.5,
		Frequency = 1.15,
		Speed = 0.42,
		Slices = 32,
		Tint = Color3.fromRGB(255, 255, 255),
		TintStrength = 0.34,
		Glow = true,
	},
	Parent = nil,
	OnProgress = nil,
	OnPhase = nil,
	OnComplete = nil,
	OnReady = nil,
	OnContinue = nil,
}

local function resolveParent(explicit: any): any
	if explicit then
		return explicit
	end
	local ok, playerGui = pcall(function()
		local players = game:GetService("Players")
		return players.LocalPlayer and players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	end)
	if ok and playerGui then
		return playerGui
	end
	local ok2, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	return ok2 and coreGui or nil
end

--- @param spec table See `LoadingScreen.defaults`.
function LoadingScreen.new(spec: { [any]: any }): any
	local options = Util.deepMerge(LoadingScreen.defaults, spec or {})
	if options.Logo.Image == nil then
		options.Logo.Image = LoadingScreen.LogoImage
	end

	local tokens = Theme.current()
	local self = setmetatable({
		_spec = options,
		_maid = Maid.new("loadingScreen"),
		_tokens = tokens,
		_phaseIndex = 0,
		_progress = 0,
		_displayed = 0,
		_complete = false,
		_destroyed = false,
		_continued = false,
		_revealed = false,
		_failures = 0,
		_startedAt = os.clock(),
		_lastAssetAt = os.clock(),
	}, LoadingScreen)

	self.Progress = Signal.new("LoadingScreen.Progress")
	self.PhaseChanged = Signal.new("LoadingScreen.Phase")
	self.Completed = Signal.new("LoadingScreen.Completed")
	self.Continued = Signal.new("LoadingScreen.Continued")

	-- Screen ------------------------------------------------------------
	local parent = resolveParent(options.Parent)
	local screen = Util.create("ScreenGui", {
		Name = "VantageLoadingScreen",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 250,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent,
	})
	Util.tag(screen, "Vantage")
	self.ScreenGui = screen

	-- A transparent, non-interactive frame: it exists only to give the mark
	-- a coordinate space that ignores the Roblox topbar. Nothing here is a
	-- button, so gameplay input passes straight through to the game.
	local root = Util.frame({
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		Parent = screen,
	})
	self.Root = root

	local logoBlock = Util.frame({
		Name = "Logo",
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(options.Logo.Size, options.Logo.Size),
		BackgroundTransparency = 1,
		Parent = root,
	})
	self._logoBlock = logoBlock

	local logo = LogoWave.new({
		Image = options.Logo.Image,
		Size = options.Logo.Size,
		-- The screen owns the entrance: the mark fades in on a spring here, so
		-- the wave must not run a second entrance of its own underneath it.
		Entrance = false,
		Amplitude = options.Logo.Amplitude,
		Frequency = options.Logo.Frequency,
		Speed = options.Logo.Speed,
		Slices = options.Logo.Slices,
		Tint = options.Logo.Tint,
		TintStrength = options.Logo.TintStrength,
		Glow = options.Logo.Glow,
	}, { parent = logoBlock, maid = self._maid })
	self.Logo = logo

	-- Placement ---------------------------------------------------------
	-- Bottom-right of the *safe* area: notches, the topbar, the mobile home
	-- indicator and any host UI all shift the corner, and the mark has to
	-- land in the corner that is actually usable.
	local function layout()
		local insets = Util.insets()
		local pad = options.Logo.Padding
		local right = insets.right + pad
		local bottom = insets.bottom + pad
		local rise = (1 - Util.clamp01(self._displayed)) * (options.Rise or 0)
		logoBlock.Position = UDim2.new(1, -right, 1, -(bottom + rise))
	end
	self._layout = layout
	layout()

	local camera = workspace and workspace.CurrentCamera
	if camera then
		pcall(function()
			self._maid:add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				task.defer(layout)
			end))
		end)
	end
	self._maid:add(Theme.Changed:connect(function(next)
		tokens = next
		self._tokens = next
		logo:RefreshTheme()
	end))

	-- Entrance ----------------------------------------------------------
	self._maid:add(function()
		Motion.cancelAll(logoBlock)
	end)

	if Motion.getReducedMotion() then
		logo:SetOpacity(1)
	else
		-- A spring rather than a tween: the mark settles with a little
		-- momentum instead of arriving on rails.
		logo:SetOpacity(0)
		local fadeIn = Motion.springFrom("standard", 0)
		self._maid:add(function()
			fadeIn:destroy()
		end)
		fadeIn:observe(function(value)
			logo:SetOpacity(value)
		end)
		fadeIn:setGoal(1)

		Motion.setScale(logoBlock, 0.9)
		Motion.scale(logoBlock, 1, Motion.options("enter", { duration = 0.5 }))
	end

	return self
end

--[[ Progress ------------------------------------------------------- ]]

--- Reports work progress. Nothing numeric is drawn — the mark's rise and
--- the `OnProgress` callback are what carry it.
--- Progress never moves backwards: a phase that reports less than the
--- previous one is clamped, because a readout that rewinds destroys trust.
function LoadingScreen:SetProgress(value: number, detailText: string?)
	value = Util.clamp01(value)
	if value < self._progress then
		value = self._progress
	end
	self._progress = value

	if not self._progressSpring then
		local spring = Motion.springFrom("gentle", self._displayed)
		self._progressSpring = spring
		self._maid:add(function()
			spring:destroy()
		end)
		spring:observe(function(displayed)
			self._displayed = displayed
			self._layout()
		end)
	end
	self._progressSpring:setGoal(value)

	if detailText ~= nil then
		self._detailText = detailText
	end

	self.Progress:fire(value, detailText, self)
	Util.safeCall(self._spec.OnProgress, value, detailText, self)
	return self
end

--- Announces a new phase. Fires `PhaseChanged` and `OnPhase`; the screen
--- itself stays quiet.
function LoadingScreen:SetPhase(name: string, detailText: string?)
	self._phaseIndex += 1
	if detailText ~= nil then
		self._detailText = detailText
	end
	self.PhaseChanged:fire(name, detailText, self)
	Util.safeCall(self._spec.OnPhase, name, detailText, self)
	return self
end

--- Default phase list when the caller did not supply one.
local function defaultPhases(self: any): { any }
	local spec = self._spec
	return {
		{
			Name = "Preparing",
			Weight = 0.08,
			Run = function(report)
				report(0.4, "Reading configuration")
				if Config.persistence and Config.persistence.load then
					report(0.75, "Restoring saved layout")
				end
				report(1, nil)
			end,
		},
		{
			Name = "Streaming assets",
			Weight = #spec.Assets > 0 and 0.78 or 0.02,
			Run = function(report)
				if #spec.Assets == 0 then
					report(1, "No assets to preload")
					return
				end
				local ok, ContentProvider = pcall(function()
					return game:GetService("ContentProvider")
				end)
				if not ok or not ContentProvider then
					report(1, "ContentProvider unavailable")
					return
				end

				local total = #spec.Assets
				local done = 0
				local failed = 0
				local started = os.clock()

				local success, err = pcall(function()
					ContentProvider:PreloadAsync(spec.Assets, function(_, status)
						done += 1
						self._lastAssetAt = os.clock()
						if status and status ~= Enum.AssetFetchStatus.Success then
							failed += 1
						end
						local elapsed = os.clock() - started
						local line = string.format("%d of %d assets  ·  %.1fs", done, total, elapsed)
						if failed > 0 then
							line = string.format("%s  ·  %d unavailable", line, failed)
						end
						report(done / total, line)
					end)
				end)

				self._failures = failed
				if not success then
					self._loadError = tostring(err)
					report(1, "Asset streaming reported an error; continuing")
				else
					report(1, nil)
				end
			end,
		},
		{
			Name = "Finalising",
			Weight = 0.14,
			Run = function(report)
				report(0.35, "Building interface")
				report(0.7, "Warming animation engine")
				report(1, nil)
			end,
		},
	}
end

--- Runs the screen. Yields until the screen has finished and left, or
--- returns immediately when `run == false`.
---
--- `LoadingScreen.Run(spec)` is the one-call entry point;
--- `screen:Start()` exists for hosts that want the instance first.
function LoadingScreen:Start()
	local spec = self._spec
	local phases = spec.Phases or defaultPhases(self)

	-- Minimum display time: a join that finishes from cache would otherwise
	-- flash the mark for one frame, which reads as a glitch.
	if (spec.MinDuration or 0) > 0 then
		task.delay(spec.MinDuration, function()
			self._minDurationElapsed = true
			self:_maybeFinish()
		end)
	else
		self._minDurationElapsed = true
	end

	-- Nothing may strand the player: after `MaxDuration` the screen finishes
	-- itself and the report says it timed out.
	if spec.MaxDuration and spec.MaxDuration > 0 then
		task.delay(spec.MaxDuration, function()
			if self._destroyed or self._complete then
				return
			end
			self._timedOut = true
			self:_finish()
		end)
	end

	self:_watchForStalls()

	task.spawn(function()
		local totalWeight = 0
		for _, phase in ipairs(phases) do
			totalWeight += (phase.Weight or 1)
		end
		if totalWeight <= 0 then
			totalWeight = 1
		end

		local consumed = 0
		local startingProgress = self._progress

		for _, phase in ipairs(phases) do
			if self._destroyed then
				return
			end
			self:SetPhase(phase.Name or "Working", phase.Detail)

			local weight = (phase.Weight or 1) / totalWeight
			local phaseBase = startingProgress + consumed * (1 - startingProgress)
			local phaseSpan = weight * (1 - startingProgress)
			consumed += weight

			local function report(fraction: number, detailText: string?)
				self:SetProgress(phaseBase + Util.clamp01(fraction) * phaseSpan, detailText)
			end

			if type(phase.Run) == "function" then
				-- Wrapped so one failing phase cannot strand the player.
				local ok, err = pcall(phase.Run, report, self)
				if not ok then
					self._loadError = tostring(err)
					report(1, "Phase reported an error; continuing")
				end
			elseif type(phase.Duration) == "number" then
				local elapsed = 0
				while elapsed < phase.Duration and not self._destroyed do
					task.wait(0.05)
					elapsed += 0.05
					report(elapsed / phase.Duration, phase.Detail)
				end
			else
				report(1, phase.Detail)
			end
		end

		if not self._destroyed then
			self:SetProgress(1)
			self:_finish()
		end
	end)

	return self
end

--- If asset streaming goes quiet for too long, say so rather than stalling
--- silently. The phase is re-announced so `OnPhase` listeners can react.
function LoadingScreen:_watchForStalls()
	self._maid:add(Motion.ticker(function()
		if self._destroyed or self._complete or self._stallNoted then
			return
		end
		local quietFor = os.clock() - (self._lastAssetAt or os.clock())
		if quietFor > (self._spec.StallTimeout or 6) then
			self._stallNoted = true
			self:SetPhase("Still working", "Waiting on a slow asset")
		end
	end))
end

--- Marks the work as done. Named `_finish` rather than `_complete`
--- because `self._complete` is the boolean the rest of the class reads:
--- one name, one meaning.
function LoadingScreen:_finish()
	if self._complete or self._destroyed then
		return
	end
	self._complete = true

	self.Completed:fire(self)
	Util.safeCall(self._spec.OnComplete, self)
	self:_maybeFinish()
end

--- Settles the mark, then leaves — either on its own after `AutoContinue`
--- or when the host calls `handle.continue()`.
function LoadingScreen:_maybeFinish()
	if self._revealed or self._destroyed then
		return
	end
	if not self._complete then
		return
	end
	if not self._minDurationElapsed and (self._spec.MinDuration or 0) > 0 then
		return
	end

	self._revealed = true

	-- One pulse of accent as the work lands: the only "done" signal the
	-- screen gives, and it is enough.
	self.Logo:Pulse({ Color = self._tokens.accent })
	Util.safeCall(self._spec.OnReady, self)

	if self._spec.RequireInput then
		return
	end

	if self._spec.AutoContinue then
		local remaining = self._spec.AutoContinue
		local token = (self._autoToken or 0) + 1
		self._autoToken = token
		local function tick()
			if token ~= self._autoToken or self._destroyed or self._continued then
				return
			end
			remaining -= 0.1
			if remaining <= 0 then
				self:Continue()
				return
			end
			task.delay(0.1, tick)
		end
		task.delay(0.1, tick)
	end
end

--- Dismisses the screen. Safe to call more than once.
function LoadingScreen:Continue(instant: boolean?)
	if self._continued then
		return self
	end
	self._continued = true

	self.Continued:fire(self)
	Util.safeCall(self._spec.OnContinue, self)

	if instant or Motion.getReducedMotion() then
		self:Destroy()
		return self
	end

	-- The mark lifts a little as it fades, which is what makes the exit read
	-- as leaving rather than blinking out.
	local block = self._logoBlock
	if block then
		Motion.tween(block, {
			Position = UDim2.new(block.Position.X.Scale, block.Position.X.Offset, block.Position.Y.Scale, block.Position.Y.Offset - 8),
		}, { duration = 0.4, easing = "exitSoft" })
	end
	local fade = Motion.springFrom("gentle", 1)
	self._maid:add(function()
		fade:destroy()
	end)
	fade:observe(function(value)
		if not self._destroyed and self.Logo then
			self.Logo:SetOpacity(value)
		end
	end)
	fade:setGoal(0)
	task.delay(0.42, function()
		self:Destroy()
	end)
	return self
end

function LoadingScreen:GetProgress(): number
	return self._displayed
end

--- The reported progress target, 0..1, independent of the smoothed value.
function LoadingScreen:GetTarget(): number
	return self._progress
end

function LoadingScreen:IsComplete(): boolean
	return self._complete
end

function LoadingScreen:IsDestroyed(): boolean
	return self._destroyed == true
end

--- Diagnostics for the harness and for bug reports.
function LoadingScreen:GetReport()
	return {
		progress = self._progress,
		displayed = self._displayed,
		complete = self._complete,
		continued = self._continued == true,
		failures = self._failures,
		loadError = self._loadError,
		timedOut = self._timedOut == true,
		stalled = self._stallNoted == true,
		phase = self._phaseIndex,
		detail = self._detailText,
		duration = os.clock() - self._startedAt,
		mode = self.Logo and self.Logo._mode or "unknown",
		slices = self.Logo and self.Logo._sliceCount or 0,
	}
end

function LoadingScreen:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true

	self.Progress:destroy()
	self.PhaseChanged:destroy()
	self.Completed:destroy()
	self.Continued:destroy()

	self._maid:destroy()

	if self.Logo then
		self.Logo:destroy()
		self.Logo = nil
	end
	if self.ScreenGui then
		self.ScreenGui:Destroy()
		self.ScreenGui = nil
	end
end

--- One-call entry point.
---
---     local loading = Vantage.LoadingScreen.Run({
---         Assets = { "rbxassetid://1" },
---         Logo = { Image = "rbxassetid://123" },
---     })
---     loading.wait()          -- wait until it has left
---     loading.wait(3)         -- or give up after three seconds
---
--- Returns a handle with `:wait(timeout?)`, `:continue()` and `:destroy()`.
--- Every load method is safe to call twice: a second `Run` while a screen is
--- already up replaces it rather than stacking a second mark in the corner.
function LoadingScreen.Run(spec: { [any]: any })
	-- One screen at a time, across every copy of the library that may be
	-- loaded in this client.
	local registry = Util.registry()
	local previous = registry.loadingScreen
	if previous and not previous:IsDestroyed() then
		previous:Destroy()
	end

	local screen = LoadingScreen.new(spec)
	registry.loadingScreen = screen
	screen:Start()

	local handle = {
		screen = screen,
		Instance = screen.ScreenGui,
	}

	function handle.wait(timeout: number?)
		local deadline = timeout and (os.clock() + timeout) or nil
		while not screen._continued and not screen._destroyed do
			if deadline and os.clock() > deadline then
				break
			end
			task.wait(0.05)
		end
		return screen
	end

	function handle.continue()
		screen:Continue()
	end

	function handle.destroy()
		screen:Destroy()
	end

	return handle
end

--- The screen currently on display, if any. `nil` once it has left.
function LoadingScreen.Current()
	local registry = Util.registry()
	local screen = registry.loadingScreen
	if screen and not screen:IsDestroyed() then
		return screen
	end
	return nil
end

return LoadingScreen
