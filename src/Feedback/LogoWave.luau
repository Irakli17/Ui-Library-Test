--!nonstrict
--[[
	Vantage 1.0.0 · Feedback/LogoWave
	------------------------------------------------------------------
	The travelling-wave filter.

	Roblox has no shader stage for ImageLabels, so a wave distortion of
	an image has to be built out of geometry. This module does exactly
	that, and does it without visible seams:

	 1. The image is cut into N horizontal slices, each a clipping Frame
	    containing its own full-height copy of the image, offset so the
	    frame shows precisely its own band.
	 2. Every frame, each slice is offset vertically by a sine whose
	    phase is a function of the slice's normalised position. That is a
	    travelling wave along the image's height.
	 3. Each slice is drawn `bleed` pixels taller than its band and its
	    content shifted to match, so neighbours always overlap even when
	    the wave separates them by more than a slice. Without the bleed
	    you get the classic one-pixel flicker line at every slice seam;
	    the bleed value is derived from the amplitude, frequency and slice
	    count rather than guessed.
	 4. A second, phase-shifted sine modulates each slice's colour and
	    transparency, producing the moving light band that makes it read
	    as a filter rather than a wobble.

	When no asset ID is configured the wave is applied to the procedural
	mark instead, by offsetting each part according to its vertical band.
	Same maths, no slicing, no blank image.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)
local LogoMark = require(script.Parent.LogoMark)

local LogoWave = {}
LogoWave.__index = LogoWave

local TWO_PI = math.pi * 2

--- Defaults tuned by eye against a 96px mark: enough amplitude to be
--- unmistakably a wave, small enough to stay legible at 40px.
LogoWave.defaults = {
	Size = 96,
	Amplitude = 5.5,
	Frequency = 1.15,
	Speed = 0.42,
	Slices = 32,
	Bleed = nil, -- derived
	Envelope = true,
	Tint = Color3.fromRGB(255, 255, 255),
	TintStrength = 0.34,
	TransparencyShine = 0.1,
	Glow = true,
	GlowPulse = 0.05,
	Entrance = true,
}

--- Vertical envelope: zero displacement at the very top and bottom of
--- the mark so it never appears to detach from its own bounding box.
local function envelopeAt(band: number): number
	return 0.36 + 0.64 * math.sin(math.pi * Util.clamp01(band))
end

--- @param spec table See `LogoWave.defaults`.
--- @param context { parent: Instance, maid?: Maid }
function LogoWave.new(spec: { [any]: any }, context: { [any]: any })
	local opts = table.clone(LogoWave.defaults)
	for key, value in pairs(spec or {}) do
		opts[key] = value
	end

	local size = opts.Size
	local imageId = opts.Image
	local hasImage = type(imageId) == "string" and imageId ~= "" and imageId ~= "rbxassetid://0"

	local slices = math.clamp(math.floor(opts.Slices or 32), 6, 64)
	if hasImage then
		-- Never let a slice be thinner than three pixels: below that the
		-- seams become impossible to hide at any bleed.
		slices = math.clamp(math.floor(size / 3), 6, slices)
	else
		slices = math.clamp(slices, 6, 24)
	end
	local sliceHeight = size / slices

	-- Derived bleed: the maximum change in displacement between two
	-- adjacent slices, plus a pixel of rounding slack.
	local phaseStep = TWO_PI * (opts.Frequency or 1) / slices
	local bleed = opts.Bleed or math.ceil((opts.Amplitude or 5) * (phaseStep + 2 / slices)) + 2
	bleed = math.max(2, bleed)

	local self = setmetatable({
		_spec = opts,
		_size = size,
		_sliceCount = slices,
		_sliceHeight = sliceHeight,
		_bleed = bleed,
		_time = 0,
		_mode = hasImage and "image" or "mark",
		_theme = Theme.current(),
		_playing = true,
		_opacity = 1,
		_maid = context.maid,
	}, LogoWave)

	local container = Util.frame({
		Name = "VantageLogoWave",
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = context.parent,
	})
	Util.tag(container, "Vantage")
	self.Instance = container

	-- Bloom ------------------------------------------------------------
	self._glowParts = {}
	if opts.Glow ~= false and hasImage then
		local glowColor = opts.GlowColor or self._theme.accent
		for index, scale in ipairs({ 1.14, 1.07, 1.03 }) do
			local halo = Util.image({
				Name = "Halo" .. index,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(scale, scale),
				Image = imageId,
				ImageColor3 = glowColor,
				ImageTransparency = 0.88 - index * 0.02,
				BackgroundTransparency = 1,
				ZIndex = 1,
				Parent = container,
			})
			table.insert(self._glowParts, { instance = halo, base = halo.ImageTransparency })
		end
	end

	-- Slices or parts ---------------------------------------------------
	self._slices = {}
	self._parts = {}

	if hasImage then
		local sliceLayer = Util.frame({
			Name = "Slices",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 4,
			Parent = container,
		})
		self._sliceLayer = sliceLayer

		for index = 1, slices do
			local band = (index - 1) / slices
			local base = (index - 1) * sliceHeight

			-- The window is taller than its band by `bleed` on both
			-- sides, and the image inside is shifted by the same amount,
			-- so the window still shows its own band plus one band of
			-- overlap on each edge.
			local window = Util.frame({
				Name = string.format("Slice%02d", index),
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, base - bleed),
				Size = UDim2.fromOffset(size, sliceHeight + bleed * 2),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				-- Later slices draw on top, so overlapping neighbours
				-- resolve in the image's own top-to-bottom order.
				ZIndex = 4 + index,
				Parent = sliceLayer,
			})

			local image = Util.image({
				Name = "Band",
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, -(base - bleed)),
				Size = UDim2.fromOffset(size, size),
				Image = imageId,
				ImageColor3 = opts.Tint,
				ImageTransparency = 0,
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Stretch,
				ZIndex = 1,
				Parent = window,
			})

			table.insert(self._slices, {
				window = window,
				image = image,
				band = band,
				baseY = base - bleed,
				phase = band * TWO_PI * (opts.Frequency or 1),
			})
		end
	else
		-- Procedural fallback: one mark, waved by part band.
		local mark = LogoMark.build(container, size, {
			Glow = opts.Glow,
			GlowColor = opts.GlowColor,
		})
		self._mark = mark
		local origin = {}
		for _, part in ipairs(mark.parts) do
			origin[part.instance] = part.instance.Position
			table.insert(self._parts, {
				instance = part.instance,
				band = part.band,
				base = part.instance.Position,
				phase = part.band * TWO_PI * (opts.Frequency or 1),
				kind = part.kind,
			})
		end
		self._partOrigins = origin
		for _, entry in ipairs(self._parts) do
			entry.instance.ZIndex = entry.instance.ZIndex + 3
		end
	end

	-- Entrance ----------------------------------------------------------
	if opts.Entrance ~= false then
		Motion.setScale(container, 0.8)
		Motion.scale(container, 1, { duration = 0.62, easing = "emphasize" })
		self._opacity = 0
	end

	self:_render(0)
	self._ticker = Motion.ticker(function(_, elapsed)
		self:_render(elapsed)
	end)

	if context.maid then
		context.maid:add(function()
			self:destroy()
		end)
	end

	return self
end

--- Per-frame update. Kept allocation-free: this runs 60+ times a second
--- and must not create garbage.
function LogoWave:_render(elapsed: number)
	local opts = self._spec
	local amp = opts.Amplitude or 5
	local speed = opts.Speed or 0.42
	local tintStrength = opts.TintStrength or 0
	local shineStrength = opts.TransparencyShine or 0
	local tint = opts.Tint
	local opacity = self._opacity

	-- A slow breathing glow, independent of the wave phase.
	if #self._glowParts > 0 then
		local pulse = opts.GlowPulse or 0
		local breath = 0.5 + 0.5 * math.sin(elapsed * 1.1)
		for index, entry in ipairs(self._glowParts) do
			entry.instance.ImageTransparency = entry.base + (1 - breath) * pulse
		end
	end

	if self._mode == "image" then
		local slices = self._slices
		for index = 1, #slices do
			local slice = slices[index]
			local ramp = opts.Envelope and envelopeAt(slice.band) or 1
			local angle = elapsed * speed * TWO_PI - slice.phase
			local offset = math.sin(angle) * amp * ramp
			slice.window.Position = UDim2.fromOffset(0, slice.baseY + offset)

			if tintStrength > 0 or shineStrength > 0 then
				-- Phase-shifted by a quarter turn so the light band
				-- travels with the crest of the wave rather than behind it.
				local shine = 0.5 + 0.5 * math.sin(angle + math.pi * 0.5)
				if tintStrength > 0 then
					slice.image.ImageColor3 = Util.mixColor(
						Color3.new(1, 1, 1),
						tint,
						shine * tintStrength
					)
				end
				if shineStrength > 0 then
					slice.image.ImageTransparency = Util.clamp01(
						(1 - shine) * shineStrength + (1 - opacity)
					)
				end
			elseif opacity < 1 then
				slice.image.ImageTransparency = 1 - opacity
			end
		end
	else
		local parts = self._parts
		for index = 1, #parts do
			local part = parts[index]
			local ramp = opts.Envelope and envelopeAt(part.band) or 1
			local angle = elapsed * speed * TWO_PI - part.phase
			local offset = math.sin(angle) * amp * ramp * 0.75
			local base = part.base
			part.instance.Position = UDim2.new(
				base.X.Scale,
				base.X.Offset,
				base.Y.Scale,
				base.Y.Offset + offset
			)
		end
		if #self._glowParts == 0 and self._mark then
			-- Keep the fallback mark's own halo in sync with opacity.
			local mark = self._mark
			for _, child in ipairs(mark.Instance:GetChildren()) do
				if child.Name:sub(1, 4) == "Halo" then
					child.BackgroundTransparency = math.min(0.98, child.BackgroundTransparency + (1 - opacity) * 0.5)
				end
			end
		end
	end
end

--- Overall opacity, 0..1. Used by the loading screen to fade the whole
--- mark in and out as one object.
function LogoWave:SetOpacity(opacity: number)
	self._opacity = Util.clamp01(opacity)
	if self._mode == "image" then
		for _, entry in ipairs(self._glowParts) do
			entry.instance.ImageTransparency = Util.clamp01(entry.base + (1 - self._opacity) * 0.6)
		end
		for _, slice in ipairs(self._slices) do
			local shine = self._spec.TransparencyShine or 0
			slice.image.ImageTransparency = Util.clamp01((1 - self._opacity) + (1 - self._opacity) * shine)
		end
	else
		self.Instance.GroupTransparency = 1 - self._opacity
	end
	return self
end

--- Live-tunes the wave. Values are clamped to stay seamless: raising the
--- amplitude recomputes the bleed so no seam can be introduced at
--- runtime.
function LogoWave:Configure(patch: { [any]: any })
	for key, value in pairs(patch) do
		self._spec[key] = value
	end
	if patch.Amplitude or patch.Frequency then
		local phaseStep = TWO_PI * (self._spec.Frequency or 1) / self._sliceCount
		self._bleed = math.max(2, math.ceil((self._spec.Amplitude or 5) * (phaseStep + 2 / self._sliceCount)) + 2)
		for index, slice in ipairs(self._slices) do
			local base = (index - 1) * self._sliceHeight
			slice.baseY = base - self._bleed
			slice.window.Size = UDim2.fromOffset(self._size, self._sliceHeight + self._bleed * 2)
			slice.image.Position = UDim2.fromOffset(0, -(base - self._bleed))
		end
	end
	return self
end

--- A single expanding ring pulse, fired when the wave has something to
--- announce (load complete). Cheap, and it reads as a "click".
function LogoWave:Pulse(options: { [any]: any }?)
	local opts = options or {}
	local ring = Util.frame({
		Name = "Pulse",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = self.Instance,
	})
	Util.pill(ring)
	local stroke = Util.stroke(ring, opts.Color or self._spec.Tint or Color3.new(1, 1, 1), 2, 0.2)
	Motion.tween(ring, { Size = UDim2.fromScale(1.9, 1.9) }, {
		duration = 0.7,
		easing = "exitSoft",
		onComplete = function()
			ring:Destroy()
		end,
	})
	Motion.tween(stroke, { Transparency = 1 }, { duration = 0.7, easing = "exitSoft" })
	return self
end

function LogoWave:Play()
	if self._ticker and not self._playing then
		self._ticker:resume()
		self._playing = true
	end
	return self
end

function LogoWave:Pause()
	if self._ticker and self._playing then
		self._ticker:pause()
		self._playing = false
	end
	return self
end

function LogoWave:IsPlaying(): boolean
	return self._playing
end

--- Recolours the glow when the theme changes. The mark's own blues are
--- never touched: a brand mark does not follow the user's accent.
function LogoWave:RefreshTheme()
	local tokens = Theme.current()
	self._theme = tokens
	if #self._glowParts > 0 then
		for _, entry in ipairs(self._glowParts) do
			entry.instance.ImageColor3 = self._spec.GlowColor or tokens.accent
		end
	end
	return self
end

function LogoWave:destroy()
	if self._ticker then
		self._ticker:destroy()
		self._ticker = nil
	end
	if self.Instance then
		Motion.cancelAll(self.Instance)
		self.Instance:Destroy()
		self.Instance = nil
	end
end

return LogoWave
