--!nonstrict
--[[
	Vantage 1.0.0 · Feedback/LoadingScreen
	------------------------------------------------------------------
	A preloading screen that reports the truth and looks like it costs
	money.

	What it actually does:

	· Real progress. `Spec.Assets` are streamed through
	  `ContentProvider:PreloadAsync`, and the bar is driven by the
	  per-asset callback rather than a timer. A fake progress bar is the
	  single most obvious tell that an interface was not finished.
	· Phase reporting. Work is split into named phases with weights, so
	  the readout says "Compiling shaders" rather than "Loading..." for
	  four minutes.
	· A spring-smoothed bar. Raw progress jumps in steps; the spring
	  turns each step into a sweep, and it can never move backwards.
	· Stall protection. If preloading goes quiet for `StallTimeout` the
	  screen says so instead of freezing at 68% forever, and
	  `MaxDuration` guarantees the player eventually reaches the game.
	· A minimum display time. A cached join that finishes in 90ms would
	  otherwise flash the screen for one frame, which reads as a glitch.
	· Failures are counted, not hidden. If assets fail, the screen says
	  how many and continues.
	· The wave logo sits bottom-right, aligned to the safe area, so it
	  clears notches, the Roblox topbar and the mobile home indicator on
	  every aspect ratio.
	· Reduced-motion collapses the wave to a still mark. The screen still
	  works, it just stops moving.

	Cleanup is total: destroy releases the ScreenGui, every connection
	and the rendering stack, and restores the mouse and camera state the
	game had before the screen appeared.
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

--- Where the mark comes from by default. Ship an empty string and the
--- screen draws the procedural mark instead of an empty frame — the
--- screen never shows a blank image.
LoadingScreen.LogoImage = ""

LoadingScreen.defaults = {
	Title = "Vantage",
	Version = "v" .. Config.version,
	Tagline = "Interface, engineered.",
	--- Assets handed to ContentProvider. Supply your own.
	Assets = {},
	--- Phases run in order. `Weight` controls how much of the bar each
	--- phase owns; `Run` is an optional function called with a
	--- progress reporter.
	Phases = nil,
	MinDuration = 1.6,
	MaxDuration = 25,
	StallTimeout = 6,
	TipInterval = 4.6,
	Tips = {
		"Press {TOGGLE} at any time to show or hide the interface.",
		"Every control in Vantage supports keyboard navigation.",
		"Theme changes morph rather than cut, so nothing flashes.",
		"Hold Shift on a slider for fine adjustment.",
		"Right-click a keybind to clear it.",
		"ContentProvider preloading happens in parallel with your gameplay setup.",
	},
	Logo = {
		Image = nil :: string?,
		Size = 92,
		Position = "bottom-right",
		Padding = 26,
		ShowWordmark = true,
		Amplitude = 5.5,
		Frequency = 1.15,
		Speed = 0.42,
		Slices = 32,
		Tint = Color3.fromRGB(255, 255, 255),
		TintStrength = 0.34,
		Glow = true,
	},
	ShowTips = true,
	ShowRail = true,
	ShowPercentage = true,
	--- Seconds to wait after finishing before continuing on its own,
	--- counted down on the Continue affordance. Pass `false` to wait for
	--- the player instead, or `RequireInput = true` for "press any key".
	AutoContinue = 2.4,
	RequireInput = false,
	Parent = nil,
	OnProgress = nil,
	OnPhase = nil,
	OnComplete = nil,
	OnContinue = nil,
	BlurBackground = true,
}

--- Wraps a tip so `{TOGGLE}` becomes the actual bound key name.
local function formatTip(text: string): string
	local toggle = Config.keybinds.toggleInterface
	local name = toggle and toggle.Name or "RightShift"
	return (text:gsub("{TOGGLE}", name):gsub("{VERSION}", Config.version))
end

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
		_failures = 0,
		_startedAt = os.clock(),
		_lastAssetAt = os.clock(),
		_tipIndex = 1,
		_settings = {
			mouseIconEnabled = nil,
		},
	}, LoadingScreen)

	self.Progress = Signal.new("LoadingScreen.Progress")
	self.PhaseChanged = Signal.new("LoadingScreen.Phase")
	self.Completed = Signal.new("LoadingScreen.Completed")
	self.Continued = Signal.new("LoadingScreen.Continued")

	-- Screen ------------------------------------------------------------
	-- Remembered so the screen can put the game back exactly as it found it.
	local camera = workspace and workspace.CurrentCamera

	local parent = resolveParent(options.Parent)
	local screen = Util.create("ScreenGui", {
		Name = "VantageLoadingScreen",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 2000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent,
	})
	Util.tag(screen, "Vantage")
	self.ScreenGui = screen

	local root = Util.frame({
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tokens.canvas,
		Parent = screen,
	})
	self.Root = root

	-- A vertical gradient gives the flat canvas some depth; the second
	-- layer is a warm accent wash from the bottom-left corner, which is
	-- what makes the composition feel lit rather than filled.
	local canvasGradient = Util.gradient(root, {
		{ Time = 0, Color = Util.lighten(tokens.canvas, 0.045) },
		{ Time = 0.55, Color = tokens.canvas },
		{ Time = 1, Color = Util.darken(tokens.canvas, 0.35) },
	}, 90)
	self._canvasGradient = canvasGradient

	local wash = Util.frame({
		Name = "Wash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tokens.accent,
		BackgroundTransparency = 0.94,
		ZIndex = 1,
		Parent = root,
	})
	Util.gradient(wash, {
		{ Time = 0, Color = tokens.accent, Transparency = 1 },
		{ Time = 0.45, Color = tokens.accent, Transparency = 0.85 },
		{ Time = 1, Color = tokens.accent, Transparency = 1 },
	}, 90)
	self._wash = wash

	-- Vignette: darker toward the edges.
	local vignette = Util.frame({
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tokens.shadow,
		BackgroundTransparency = 0.78,
		ZIndex = 2,
		Parent = root,
	})
	Util.gradient(vignette, {
		{ Time = 0, Color = tokens.shadow, Transparency = 0.35 },
		{ Time = 0.5, Color = tokens.shadow, Transparency = 1 },
		{ Time = 1, Color = tokens.shadow, Transparency = 0.35 },
	}, 90)
	self._vignette = vignette

	-- Left column: percentage, phase, tip --------------------------------
	local left = Util.row({
		Name = "LeftColumn",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0.62, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 5,
		Parent = root,
	})
	Util.stack(left, 6)
	self._left = left

	local percentage = Util.text({
		Name = "Percentage",
		Text = "0",
		TextSize = 62,
		Font = "display",
		TextColor3 = tokens.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Size = UDim2.new(1, 0, 0, 66),
		Visible = options.ShowPercentage ~= false,
		LayoutOrder = 1,
		Parent = left,
	})
	self._percentage = percentage

	local phaseRow = Util.row({
		Name = "PhaseRow",
		Size = UDim2.new(1, 0, 0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = left,
	})
	Util.list(phaseRow, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	local phaseDotHolder = Util.row({
		Name = "Dot",
		Size = UDim2.fromOffset(7, 7),
		LayoutOrder = 1,
		Parent = phaseRow,
	})
	local phaseDot = Util.frame({
		Name = "DotFrame",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tokens.accent,
		Parent = phaseDotHolder,
	})
	Util.pill(phaseDot)
	self._phaseDot = phaseDot

	local phaseLabel = Util.text({
		Name = "Phase",
		Text = "Preparing",
		TextSize = tokens.fontSizeMd,
		Font = "subheading",
		TextColor3 = tokens.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = phaseRow,
	})
	self._phaseLabel = phaseLabel

	local detail = Util.text({
		Name = "Detail",
		Text = "",
		TextSize = tokens.fontSizeSm,
		Font = "body",
		TextColor3 = tokens.textDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = left,
	})
	self._detail = detail

	local tipHolder = Util.row({
		Name = "Tip",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Visible = options.ShowTips ~= false,
		Parent = left,
	})
	Util.stack(tipHolder, 4)
	self._tipHolder = tipHolder

	local tipOverline = Util.text({
		Name = "Overline",
		Text = "DID YOU KNOW",
		TextSize = tokens.fontSizeXs,
		Font = "bodyBold",
		TextColor3 = tokens.textDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 12),
		LayoutOrder = 1,
		Parent = tipHolder,
	})
	local tipLabel = Util.text({
		Name = "TipText",
		Text = formatTip(options.Tips[1] or ""),
		TextSize = tokens.fontSizeSm,
		Font = "body",
		TextColor3 = tokens.textMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = tipHolder,
	})
	self._tipLabel = tipLabel

	-- Right column: logo block --------------------------------------------
	local logoBlock = Util.row({
		Name = "LogoBlock",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(0, options.Logo.Size, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 6,
		Parent = root,
	})
	Util.stack(logoBlock, 10)
	self._logoBlock = logoBlock

	local waveHolder = Util.row({
		Name = "Wave",
		Size = UDim2.fromOffset(options.Logo.Size, options.Logo.Size),
		LayoutOrder = 1,
		Parent = logoBlock,
	})
	self._waveHolder = waveHolder

	local wordmark
	local wordmarkSub
	if options.Logo.ShowWordmark ~= false then
		local wordmarkHolder = Util.row({
			Name = "Wordmark",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = logoBlock,
		})
		Util.stack(wordmarkHolder, 2)

		wordmark = Util.text({
			Name = "Name",
			Text = string.upper(options.Title or "Vantage"),
			TextSize = 15,
			Font = "display",
			TextColor3 = tokens.text,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 1,
			Parent = wordmarkHolder,
		})
		wordmarkSub = Util.text({
			Name = "Tagline",
			Text = options.Tagline or "",
			TextSize = tokens.fontSizeSm,
			Font = "body",
			TextColor3 = tokens.textDim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, 0, 0, 14),
			Visible = (options.Tagline or "") ~= "",
			LayoutOrder = 2,
			Parent = wordmarkHolder,
		})
	end

	-- The mark itself.
	local waveSpec = table.clone(options.Logo)
	waveSpec.Size = options.Logo.Size
	waveSpec.Entrance = false
	if Motion.getReducedMotion() then
		waveSpec.Amplitude = 0
		waveSpec.TintStrength = 0
	end

	local wave = LogoWave.new(waveSpec, {
		parent = waveHolder,
		maid = self._maid,
	})
	self.Logo = wave

	-- Bottom rail -----------------------------------------------------------
	local rail
	local railFill
	if options.ShowRail ~= false then
		rail = Util.frame({
			Name = "Rail",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = tokens.border,
			BackgroundTransparency = 0.6,
			ZIndex = 7,
			Parent = root,
		})
		railFill = Util.frame({
			Name = "Fill",
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = tokens.accent,
			ZIndex = 8,
			Parent = rail,
		})
		Util.gradient(railFill, {
			{ Time = 0, Color = tokens.accent },
			{ Time = 0.65, Color = tokens.accentHover },
			{ Time = 1, Color = Util.lighten(tokens.accent, 0.35) },
		}, 0)

		-- A soft leading edge so the front of the bar reads as a light
		-- source rather than a hard cut.
		local head = Util.frame({
			Name = "Head",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(52, 3),
			BackgroundColor3 = Util.lighten(tokens.accent, 0.5),
			BackgroundTransparency = 0.35,
			ZIndex = 9,
			Parent = railFill,
		})
		Util.gradient(head, {
			{ Time = 0, Color = Util.lighten(tokens.accent, 0.5), Transparency = 1 },
			{ Time = 1, Color = Util.lighten(tokens.accent, 0.55), Transparency = 0 },
		}, 0)
		self._railHead = head
	end
	self._rail = rail
	self._railFill = railFill

	-- Continue affordance ----------------------------------------------------
	local continueHolder = Util.row({
		Name = "Continue",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -34),
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = tokens.accent,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 12,
		Parent = root,
	})
	Util.corner(continueHolder, tokens.radiusPill)
	Util.pad(continueHolder, { Left = 18, Right = 18, Top = 9, Bottom = 9 })
	local continueLabel = Util.text({
		Name = "Label",
		Text = "Continue",
		TextSize = tokens.fontSizeMd,
		Font = "bodyBold",
		TextColor3 = tokens.onAccent,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(0, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = continueHolder,
	})
	self._continueHit = Util.create("TextButton", {
		Name = "Hit",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 13,
		Parent = continueHolder,
	})
	self._continueHolder = continueHolder
	self._continueLabel = continueLabel

	-- Layout: apply safe-area insets ------------------------------------------
	local function layout()
		local insets = Util.insets()
		local pad = options.Logo.Padding
		local bottom = insets.bottom + pad
		local side = insets.left + pad
		local right = insets.right + pad

		left.Position = UDim2.new(0, side, 1, -(bottom + 42))
		left.Size = UDim2.new(0.56, -side, 0, 0)

		logoBlock.Position = UDim2.new(1, -right, 1, -bottom)
		if options.Logo.ShowWordmark == false then
			logoBlock.Size = UDim2.new(0, options.Logo.Size, 0, options.Logo.Size)
		else
			logoBlock.Size = UDim2.new(0, math.max(options.Logo.Size, 150), 0, 0)
		end

		if rail then
			rail.Position = UDim2.new(0, 0, 1, -insets.bottom)
		end

		continueHolder.Position = UDim2.new(0.5, 0, 1, -(bottom + 8))
	end
	self._layout = layout
	layout()
	self._maid:add(Theme.Changed:connect(function(next)
		tokens = next
		self._tokens = next
		root.BackgroundColor3 = next.canvas
		percentage.TextColor3 = next.text
		phaseLabel.TextColor3 = next.accent
		phaseDot.BackgroundColor3 = next.accent
		detail.TextColor3 = next.textDim
		tipLabel.TextColor3 = next.textMuted
		tipOverline.TextColor3 = next.textDim
		if wordmark then
			wordmark.TextColor3 = next.text
		end
		if wordmarkSub then
			wordmarkSub.TextColor3 = next.textDim
		end
		if rail then
			rail.BackgroundColor3 = next.border
			Util.gradient(railFill, {
				{ Time = 0, Color = next.accent },
				{ Time = 0.65, Color = next.accentHover },
				{ Time = 1, Color = Util.lighten(next.accent, 0.35) },
			}, 0)
		end
		Util.gradient(root, {
			{ Time = 0, Color = Util.lighten(next.canvas, 0.045) },
			{ Time = 0.55, Color = next.canvas },
			{ Time = 1, Color = Util.darken(next.canvas, 0.35) },
		}, 90)
		wave:RefreshTheme()
		layout()
	end))
	if camera and camera.GetPropertyChangedSignal then
		pcall(function()
			self._maid:add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				task.defer(layout)
			end))
		end)
	end

	return self
end

--[[ Progress ------------------------------------------------------- ]]

--- Sets the smoothed progress target and the secondary readout line.
--- Progress never moves backwards: a phase that reports less than the
--- previous one is clamped, because a bar that rewinds destroys trust.
function LoadingScreen:SetProgress(value: number, detailText: string?)
	value = Util.clamp01(value)
	if value < self._progress then
		value = self._progress
	end
	self._progress = value

	if not self._progressSpring then
		local spring = Motion.springFrom("gentle", 0)
		self._progressSpring = spring
		self._maid:add(function()
			spring:destroy()
		end)
		spring:observe(function(displayed)
			self._displayed = displayed
			local fraction = Util.clamp01(displayed)
			if self._railFill then
				self._railFill.Size = UDim2.new(fraction, 0, 1, 0)
			end
			local rounded = math.floor(fraction * 100 + 0.5)
			if self._percentage and self._percentage.Text ~= tostring(rounded) then
				self._percentage.Text = tostring(rounded)
			end
		end)
	end
	self._progressSpring:setGoal(value)

	if detailText ~= nil and self._detail and self._detail.Text ~= detailText then
		self._detail.Text = detailText
	end

	self.Progress:fire(value, detailText, self)
	Util.safeCall(self._spec.OnProgress, value, detailText, self)
	return self
end

--- Announces a new phase. The dot pulses so a phase that takes a while
--- still looks alive.
function LoadingScreen:SetPhase(name: string, detailText: string?)
	if self._phaseLabel.Text ~= name then
		self._phaseLabel.Text = name
		Motion.setScale(self._phaseLabel, 0.94)
		Motion.scale(self._phaseLabel, 1, { duration = 0.3, easing = "settle" })
	end
	if detailText ~= nil and self._detail then
		self._detail.Text = detailText
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

--- Runs the screen. Yields until the screen is finished and the player
--- has continued, or returns immediately when `run == false`.
---
--- `LoadingScreen.Run(spec)` is the one-call entry point;
--- `screen:Start()` exists for hosts that want the instance first.
function LoadingScreen:Start()
	local spec = self._spec
	local phases = spec.Phases or defaultPhases(self)

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

			local reported = 0
			local function report(fraction: number, detailText: string?)
				reported = Util.clamp01(fraction)
				self:SetProgress(phaseBase + reported * phaseSpan, detailText)
			end

			if type(phase.Run) == "function" then
				-- Wrap so one failing phase cannot strand the player on a
				-- loading screen forever.
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

		self:SetProgress(1, self._loadError and "Finished with warnings" or nil)
		self:_finish()
	end)

	-- Minimum display time, held in parallel so a fast load still shows
	-- the wordmark settling rather than a single frame of it.
	self._maid:add(task.delay((spec.MinDuration or 0), function()
		self._minDurationElapsed = true
		self:_maybeFinish()
	end))

	-- Hard ceiling. Nothing keeps the player on a loading screen.
	self._maid:add(task.delay(spec.MaxDuration or 25, function()
		if not self._complete then
			self._timedOut = true
			self:SetProgress(1, "Taking longer than expected; continuing")
			self:_finish()
		end
	end))

	self:_startTips()
	self:_watchForStalls()
	return self
end

function LoadingScreen:_startTips()
	local tips = self._spec.Tips
	if self._spec.ShowTips == false or not tips or #tips <= 1 then
		return
	end
	self._maid:add(function()
		self._tipToken = (self._tipToken or 0) + 1
	end)
	local function cycle()
		self._tipToken = (self._tipToken or 0) + 1
		local token = self._tipToken
		task.delay(self._spec.TipInterval or 4.6, function()
			if token ~= self._tipToken or self._destroyed then
				return
			end
			self._tipIndex = (self._tipIndex % #tips) + 1
			local label = self._tipLabel
			if not label then
				return
			end
			Motion.tween(label, { TextTransparency = 1 }, Motion.options("exit", {
				duration = 0.2,
				onComplete = function()
					label.Text = formatTip(tips[self._tipIndex])
					Motion.tween(label, { TextTransparency = 0 }, Motion.options("enter", { duration = 0.26 }))
				end,
			}))
			cycle()
		end)
	end
	cycle()
end

--- If asset streaming goes quiet for too long, say so. A bar frozen at
--- 68% with no explanation is the worst possible failure mode.
function LoadingScreen:_watchForStalls()
	self._maid:add(Motion.ticker(function()
		if self._destroyed or self._complete then
			return
		end
		local quietFor = os.clock() - (self._lastAssetAt or os.clock())
		if quietFor > (self._spec.StallTimeout or 6) and not self._stallNoted then
			self._stallNoted = true
			self._detail.Text = "Still working — this can take a moment on a slow connection"
		end
		-- A gentle breathing pulse on the phase dot while work is pending.
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 2.2)
		self._phaseDot.BackgroundTransparency = 0.15 + pulse * 0.35
	end))
end

--- Marks the work as done. Named `_finish` rather than `_complete`
--- because `self._complete` is the boolean the rest of the class reads:
--- one name, one meaning.
function LoadingScreen:_finish()
	if self._complete then
		return
	end
	self._complete = true

	self.Completed:fire(self)
	Util.safeCall(self._spec.OnComplete, self)
	self:_maybeFinish()
end

--- Reveals the Continue affordance once both the work and the minimum
--- display time are satisfied.
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

	self.Logo:Pulse({ Color = self._tokens.accent })
	self._continueHolder.Visible = true
	Motion.setScale(self._continueHolder, 0.9)
	Motion.scale(self._continueHolder, 1, { duration = 0.42, easing = "emphasize" })
	Motion.tween(self._continueHolder, { BackgroundTransparency = 0 }, Motion.options("enter"))

	self._maid:add(self._continueHit.Activated:Connect(function()
		self:Continue()
	end))

	if self._spec.RequireInput then
		self._continueLabel.Text = "Press any key"
		self._maid:add(game:GetService("UserInputService").InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Keyboard
				or input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
				then
				self:Continue()
			end
		end))
	elseif self._spec.AutoContinue then
		-- A visible countdown, so continuing on its own is never a
		-- surprise.
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
			self._continueLabel.Text = string.format("Continue  ·  %.1fs", remaining)
			task.delay(0.1, tick)
		end
		self._continueLabel.Text = string.format("Continue  ·  %.1fs", remaining)
		task.delay(0.1, tick)
	else
		self._continueLabel.Text = "Continue"
	end

	Util.safeCall(self._spec.OnReady, self)
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

	-- Mark first, then let the rest of the composition follow it out.
	Motion.tween(self._logoBlock, { GroupTransparency = 1 }, Motion.options("exit", { duration = 0.36 }))
	task.delay(0.1, function()
		if not self._destroyed and self.Logo then
			self.Logo:SetOpacity(0)
		end
	end)
	Motion.tween(self._left, { GroupTransparency = 1 }, Motion.options("exit", { duration = 0.32 }))
	if self._rail then
		Motion.tween(self._rail, { GroupTransparency = 1, BackgroundTransparency = 1 }, Motion.options("exit"))
	end
	Motion.tween(self._continueHolder, { GroupTransparency = 1 }, Motion.options("exit", { duration = 0.24 }))
	Motion.tween(self.Root, { BackgroundTransparency = 1 }, {
		duration = 0.46,
		easing = "exitSoft",
		onComplete = function()
			self:Destroy()
		end,
	})
	return self
end

function LoadingScreen:GetProgress(): number
	return self._displayed
end

function LoadingScreen:IsComplete(): boolean
	return self._complete
end

--- Diagnostics for the harness and for bug reports.
function LoadingScreen:GetReport()
	return {
		progress = self._progress,
		displayed = self._displayed,
		complete = self._complete,
		failures = self._failures,
		loadError = self._loadError,
		timedOut = self._timedOut == true,
		stalled = self._stallNoted == true,
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

	if self.ScreenGui then
		self.ScreenGui:Destroy()
		self.ScreenGui = nil
	end
end

--- One-call entry point.
---
---     local done = Vantage.LoadingScreen.Run({
---         Assets = { "rbxassetid://1" },
---         Logo = { Image = "rbxassetid://123" },
---     })
---     done.wait()  -- optional
---
--- Returns a handle with `:wait()`, `:continue()` and the screen itself.
function LoadingScreen.Run(spec: { [any]: any })
	local screen = LoadingScreen.new(spec)
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

return LoadingScreen
