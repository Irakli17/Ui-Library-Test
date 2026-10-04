--!nonstrict
--[[
	Vantage 1.0.0 · Primitives/Progress
	------------------------------------------------------------------
	Determinate and indeterminate progress.

	· The fill is a gradient rather than a flat colour, so a bar sitting
	  at 4% is still legible against its own track.
	· A travelling sheen sweeps the fill on a slow loop — this is what
	  makes a bar read as "working" instead of "stuck at 12%".
	· Width changes go through a spring, so a value that jumps from 0 to
	  60 emits one confident sweep instead of teleporting.
	· Indeterminate mode runs the fill as a bounded sweep so it always
	  reads as progress, never as a scrollbar.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)

local Progress = {}
Progress.__index = Progress

local SIZES = {
	xs = 3,
	sm = 5,
	md = 8,
	lg = 12,
}

--- @param spec { Name?, Description?, Icon?, Value?, Min?, Max?, Size?, Indeterminate?, Label?, Format?, HidePercent?, Tooltip? }
--- @param context { maid?, parent?, tooltip? }
function Progress.new(spec: { [any]: any }, context: { [any]: any })
	local ctx = context or {}
	local tokens = Theme.current()

	local self = setmetatable({
		_spec = spec,
		_maid = ctx.maid,
		_tokens = tokens,
		_min = spec.Min or 0,
		_max = spec.Max or 100,
		_value = spec.Value or 0,
		_indeterminate = spec.Indeterminate == true,
	}, Progress)

	local height = SIZES[spec.Size or "sm"] or SIZES.sm

	-- Standalone container: either a bare bar or a full labelled row.
	local labelled = spec.Name ~= nil
	local root = Util.row({
		Name = "VantageProgress",
		Size = UDim2.new(1, 0, 0, labelled and 0 or height),
		AutomaticSize = labelled and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		Parent = ctx.parent,
	})
	Util.tag(root, "Vantage")
	self.Instance = root

	if labelled then
		Util.stack(root, 6)
		local header = Util.row({
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 1,
			Parent = root,
		})
		Util.list(header, {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		})

		local name = Util.text({
			Name = "Name",
			Text = spec.Name,
			TextSize = tokens.fontSizeSm,
			Font = "bodyMedium",
			TextColor3 = tokens.text,
			Size = UDim2.new(1, -56, 1, 0),
			LayoutOrder = 1,
			Parent = header,
		})
		self.NameLabel = name

		local percent = Util.text({
			Name = "Percent",
			Text = "0%",
			TextSize = tokens.fontSizeSm,
			Font = "mono",
			TextColor3 = tokens.accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(0, 48, 1, 0),
			LayoutOrder = 2,
			Visible = not spec.HidePercent,
			Parent = header,
		})
		self.PercentLabel = percent
	end

	local track = Util.frame({
		Name = "Track",
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = tokens.sunken,
		LayoutOrder = labelled and 2 or 1,
		ClipsDescendants = true,
		Parent = root,
	})
	Util.pill(track)
	Util.stroke(track, tokens.borderSubtle, 1, 0.5)
	self.Track = track

	local fill = Util.frame({
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = tokens.accent,
		Parent = track,
	})
	Util.pill(fill)
	Util.gradient(fill, {
		{ Time = 0, Color = tokens.accent },
		{ Time = 0.55, Color = tokens.accentHover },
		{ Time = 1, Color = Util.lighten(tokens.accent, 0.28) },
	}, 0)
	self.Fill = fill

	-- The sheen: a bright band that travels the fill on a loop. Clipped
	-- by the fill so it never bleeds outside the bar.
	local sheen = Util.frame({
		Name = "Sheen",
		Size = UDim2.new(0, 70, 1, 0),
		Position = UDim2.fromOffset(-70, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = fill,
	})
	Util.gradient(sheen, {
		{ Time = 0, Color = Color3.new(1, 1, 1), Transparency = 1 },
		{ Time = 0.5, Color = Color3.new(1, 1, 1), Transparency = 0.62 },
		{ Time = 1, Color = Color3.new(1, 1, 1), Transparency = 1 },
	}, 0)
	self._sheen = sheen

	local sheenTween
	local function startSheen()
		if sheenTween then
			return
		end
		sheenTween = Motion.tween(sheen, { Position = UDim2.new(1, 0, 0, 0) }, {
			duration = 1.6,
			easing = "linear",
			repeatCount = -1,
			onUpdate = function(_, _, tween)
				-- Re-aim each cycle at the current track width.
				tween._props = { Position = UDim2.new(1, track.AbsoluteSize.X, 0, 0) }
			end,
		})
	end

	-- Spring-smoothed fill width.
	local indicator = Motion.springFrom("standard", 0)
	self._indicator = indicator

	local function render(value: number)
		local span = self._max - self._min
		local fraction = span == 0 and 0 or Util.clamp01((value - self._min) / span)
		fill.Size = UDim2.new(fraction, 0, 1, 0)
		-- Hide the hairline of fill at zero so a 0% bar is perfectly clean.
		fill.Visible = fraction > 0.0005

		if self.PercentLabel then
			local text
			if type(spec.Format) == "function" then
				text = tostring(spec.Format(value, fraction))
			elseif spec.Format == "value" then
				text = tostring(math.floor(value + 0.5))
			else
				text = string.format("%d%%", math.floor(fraction * 100 + 0.5))
			end
			if self.PercentLabel.Text ~= text then
				self.PercentLabel.Text = text
			end
		end
	end

	indicator:observe(render)

	if ctx.maid then
		ctx.maid:add(function()
			indicator:destroy()
			if sheenTween then
				sheenTween:cancel()
			end
		end)
	end

	startSheen()
	self:SetValue(spec.Value or 0, true)

	-- Indeterminate sweep.
	if self._indeterminate then
		self._range = Motion.tween(fill, {
			Position = UDim2.new(1, 0, 0, 0),
		}, {
			duration = 1.4,
			easing = "quadInOut",
			repeatCount = -1,
			reverse = true,
		})
		fill.Size = UDim2.new(0.32, 0, 1, 0)
		self._sweepToken = 1
	end

	if ctx.maid then
		ctx.maid:add(Theme.Changed:connect(function(next)
			tokens = next
			self._tokens = next
			track.BackgroundColor3 = next.sunken
			Util.gradient(fill, {
				{ Time = 0, Color = next.accent },
				{ Time = 0.55, Color = next.accentHover },
				{ Time = 1, Color = Util.lighten(next.accent, 0.28) },
			}, 0)
			if self.PercentLabel then
				self.PercentLabel.TextColor3 = next.accent
			end
			if self.NameLabel then
				self.NameLabel.TextColor3 = next.text
			end
		end))
	end

	return self
end

--- Sets the value. Animates unless `instant` is set.
function Progress:SetValue(value: number, instant: boolean?)
	self._value = Util.clamp(value, self._min, self._max)
	if instant then
		self._indicator:snap(self._value)
	else
		self._indicator:setGoal(self._value)
	end
	return self
end

function Progress:GetValue(): number
	return self._value
end

--- 0..1 for the current value.
function Progress:GetFraction(): number
	local span = self._max - self._min
	return span == 0 and 0 or Util.clamp01((self._value - self._min) / span)
end

function Progress:SetIndeterminate(enabled: boolean)
	if self._indeterminate == enabled then
		return self
	end
	self._indeterminate = enabled
	if enabled then
		self.Fill.Size = UDim2.new(0.32, 0, 1, 0)
		self._range = Motion.tween(self.Fill, { Position = UDim2.new(1, 0, 0, 0) }, {
			duration = 1.4,
			easing = "quadInOut",
			repeatCount = -1,
			reverse = true,
		})
	else
		if self._range then
			self._range:cancel()
			self._range = nil
		end
		self.Fill.Position = UDim2.fromOffset(0, 0)
		self:SetValue(self._value, true)
	end
	return self
end

--- Recolours the fill, e.g. to `danger` when a task fails.
function Progress:SetTone(tokenName: string)
	local tokens = self._tokens
	local color = tokens[tokenName] or tokens.accent
	Util.gradient(self.Fill, {
		{ Time = 0, Color = color },
		{ Time = 0.55, Color = Util.lighten(color, 0.12) },
		{ Time = 1, Color = Util.lighten(color, 0.3) },
	}, 0)
	if self.PercentLabel then
		self.PercentLabel.TextColor3 = color
	end
	return self
end

function Progress:SetLabel(text: string)
	if self.NameLabel then
		self.NameLabel.Text = text
	end
	return self
end

function Progress:destroy()
	if self._range then
		self._range:cancel()
	end
	if self.Instance then
		Motion.cancelAll(self.Instance)
		self.Instance:Destroy()
		self.Instance = nil
	end
end

return Progress
