--!nonstrict
--[[
	Vantage 1.0.0 · Feedback/LogoMark
	------------------------------------------------------------------
	The Vantage mark, drawn from frames.

	Why this exists: a loading screen that shows a blank square because
	an asset ID was not set is worse than no loading screen at all. This
	module reproduces the mark with primitives — tilted squircle body,
	cut-out centre, orbital ring, orbital swoosh and two four-point
	sparkles — so the default experience is never empty. Set
	`LoadingScreen.Logo.Image` to your uploaded asset and the real image
	takes over, slice-for-slice identical.

	Every part is tagged with its vertical band (`part.band`, 0 = top),
	which is what lets `LogoWave` push the mark through a travelling wave
	without slicing it into forty copies.

	The palette here is the mark's own blue. Vantage's *interface* is
	amber and charcoal; the mark keeps its identity. That separation is
	deliberate and worth keeping.
]]

local Util = require(script.Parent.Parent.Core.Util)

local LogoMark = {}

--- The mark's own colours. Deliberately not theme tokens: a brand mark
--- should not change colour when the user picks a different accent.
LogoMark.palette = {
	core = Color3.fromRGB(255, 255, 255),
	coreMid = Color3.fromRGB(214, 231, 255),
	coreDeep = Color3.fromRGB(43, 106, 255),
	coreEdge = Color3.fromRGB(14, 74, 222),
	orbit = Color3.fromRGB(56, 150, 255),
	orbitBright = Color3.fromRGB(120, 197, 255),
	sparkle = Color3.fromRGB(168, 214, 255),
	cut = Color3.fromRGB(6, 8, 14),
}

local function ring(parent: any, size: number, position: any, thickness: number, color: any, transparency: number, zIndex: number, rotation: number?)
	local frame = Util.frame({
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromScale(size, size),
		BackgroundTransparency = 1,
		Rotation = rotation or 0,
		ZIndex = zIndex,
		Parent = parent,
	})
	Util.pill(frame)
	local stroke = Util.stroke(frame, color, thickness, transparency)
	return frame, stroke
end

local function bar(parent: any, scaleX: number, scaleY: number, position: any, rotation: number, color: any, transparency: number, zIndex: number)
	local frame = Util.frame({
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromScale(scaleX, scaleY),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		Rotation = rotation,
		ZIndex = zIndex,
		Parent = parent,
	})
	Util.pill(frame)
	return frame
end

--- Builds the mark.
---
--- @param parent Instance
--- @param size number Pixel size of the square the mark is drawn into.
--- @param options { Glow?: boolean, GlowColor?: any, Detail?: number }
--- @return { Instance: Frame, parts: { { instance: Instance, band: number, kind: string } } }
function LogoMark.build(parent: any, size: number, options: { [any]: any }?): any
	local opts = options or {}
	local palette = LogoMark.palette
	local detail = opts.Detail or 1
	local thick = math.max(1, math.floor(size * 0.022 + 0.5))

	local container = Util.frame({
		Name = "VantageLogoMark",
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	Util.tag(container, "Vantage")

	local parts = {}
	local function track(instance: any, band: number, kind: string)
		table.insert(parts, { instance = instance, band = band, kind = kind })
		return instance
	end

	-- Soft bloom behind everything. Layered scaled copies at very low
	-- alpha: a cheap, GPU-friendly fake for a gaussian halo.
	if opts.Glow ~= false then
		local glowColor = opts.GlowColor or palette.orbit
		for index, scale in ipairs({ 1.16, 1.08, 1.03 }) do
			local halo = Util.frame({
				Name = "Halo" .. index,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(scale, scale),
				BackgroundColor3 = glowColor,
				BackgroundTransparency = 0.9 + index * 0.025,
				ZIndex = 1,
				Parent = container,
			})
			Util.corner(halo, 20)
		end
	end

	-- Orbital ring ------------------------------------------------------
	local orbitRing = ring(container, 0.9, UDim2.fromScale(0.5, 0.5), thick, palette.orbit, 0.35, 3, -18)
	Util.gradient(orbitRing, {
		{ Time = 0, Color = palette.orbitBright, Transparency = 0.15 },
		{ Time = 0.55, Color = palette.orbit, Transparency = 0.55 },
		{ Time = 1, Color = palette.orbit, Transparency = 0.92 },
	}, 120)
	track(orbitRing, 0.5, "orbit")

	-- Outer ring --------------------------------------------------------
	local outerRing = ring(container, 0.98, UDim2.fromScale(0.5, 0.5), thick, palette.orbitBright, 0.62, 2, 0)
	Util.gradient(outerRing, {
		{ Time = 0, Color = palette.orbitBright, Transparency = 0.25 },
		{ Time = 0.6, Color = palette.orbit, Transparency = 0.7 },
		{ Time = 1, Color = palette.orbit, Transparency = 1 },
	}, 0)
	track(outerRing, 0.34, "orbit")

	-- The body: a rotated squircle with a gradient that runs from a
	-- white highlight at the top-left to saturated blue at the
	-- bottom-right, exactly like the reference mark.
	local body = Util.frame({
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.485, 0.475),
		Size = UDim2.fromScale(0.56, 0.56),
		BackgroundColor3 = palette.core,
		Rotation = -12,
		ZIndex = 5,
		Parent = container,
	})
	Util.corner(body, math.floor(size * 0.075))
	Util.gradient(body, {
		{ Time = 0, Color = palette.core },
		{ Time = 0.45, Color = palette.coreMid },
		{ Time = 0.78, Color = palette.coreDeep },
		{ Time = 1, Color = palette.coreEdge },
	}, 118)
	track(body, 0.42, "body")

	-- The cut-out. Slightly smaller than the body and offset toward the
	-- centre so the blue ledge reads on the bottom-right, as in the mark.
	local cut = Util.frame({
		Name = "Cut",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.525, 0.5),
		Size = UDim2.fromScale(0.155, 0.155),
		BackgroundColor3 = palette.cut,
		Rotation = -12,
		ZIndex = 6,
		Parent = container,
	})
	Util.corner(cut, math.floor(size * 0.02))
	track(cut, 0.5, "cut")

	-- Orbital swoosh: a long rotated stadium with a gradient that fades
	-- out at both ends so it reads as a sweep rather than a bar.
	local swoosh = bar(container, 1.06, 0.075, UDim2.fromScale(0.5, 0.6), -24, palette.orbitBright, 0.15, 7)
	Util.gradient(swoosh, {
		{ Time = 0, Color = palette.orbitBright, Transparency = 1 },
		{ Time = 0.28, Color = palette.orbitBright, Transparency = 0.05 },
		{ Time = 0.62, Color = palette.orbit, Transparency = 0.2 },
		{ Time = 1, Color = palette.orbit, Transparency = 1 },
	}, 0)
	track(swoosh, 0.62, "swoosh")

	-- A thinner trailing arc, offset, for depth.
	local trail = bar(container, 0.92, 0.045, UDim2.fromScale(0.46, 0.68), -24, palette.orbitBright, 0.45, 6)
	Util.gradient(trail, {
		{ Time = 0, Color = palette.orbitBright, Transparency = 1 },
		{ Time = 0.4, Color = palette.orbit, Transparency = 0.55 },
		{ Time = 1, Color = palette.orbitBright, Transparency = 1 },
	}, 0)
	track(trail, 0.68, "swoosh")

	-- Sparkles ----------------------------------------------------------
	local function sparkle(cx: number, cy: number, span: number, rotation: number, band: number)
		local holder = Util.row({
			Name = "Sparkle",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(cx, cy),
			Size = UDim2.fromScale(span, span),
			Rotation = rotation,
			ZIndex = 8,
			Parent = container,
		})
		local arm = math.max(0.04, 0.052 * detail)
		local vertical = bar(holder, arm, 1, UDim2.fromScale(0.5, 0.5), 0, palette.sparkle, 0.08, 8)
		local horizontal = bar(holder, 1, arm, UDim2.fromScale(0.5, 0.5), 0, palette.sparkle, 0.08, 8)
		-- Short diagonals soften the four-point star into the lens shape
		-- the reference mark uses.
		bar(holder, arm * 0.5, 0.66, UDim2.fromScale(0.5, 0.5), 45, palette.sparkle, 0.42, 8)
		bar(holder, arm * 0.5, 0.66, UDim2.fromScale(0.5, 0.5), -45, palette.sparkle, 0.42, 8)
		Util.gradient(vertical, {
			{ Time = 0, Color = palette.sparkle, Transparency = 0.7 },
			{ Time = 0.5, Color = Color3.new(1, 1, 1), Transparency = 0 },
			{ Time = 1, Color = palette.sparkle, Transparency = 0.7 },
		}, 90)
		Util.gradient(horizontal, {
			{ Time = 0, Color = palette.sparkle, Transparency = 0.7 },
			{ Time = 0.5, Color = Color3.new(1, 1, 1), Transparency = 0 },
			{ Time = 1, Color = palette.sparkle, Transparency = 0.7 },
		}, 0)
		track(holder, band, "sparkle")
		return holder
	end

	sparkle(0.79, 0.19, 0.26, 0, 0.19)
	sparkle(0.24, 0.78, 0.3, 0, 0.78)
	if detail > 0.9 then
		sparkle(0.86, 0.72, 0.14, 0, 0.72)
	end

	-- Inner rim light on the body: a border stroke whose gradient makes
	-- the top-left edge catch light and the bottom-right fall away.
	local rim = Util.frame({
		Name = "Rim",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.485, 0.475),
		Size = UDim2.fromScale(0.56, 0.56),
		BackgroundTransparency = 1,
		Rotation = -12,
		ZIndex = 7,
		Parent = container,
	})
	Util.corner(rim, math.floor(size * 0.075))
	local rimStroke = Util.stroke(rim, Color3.new(1, 1, 1), 1, 0.3)
	Util.gradient(rimStroke, {
		{ Time = 0, Color = Color3.new(1, 1, 1), Transparency = 0.15 },
		{ Time = 0.5, Color = Color3.new(1, 1, 1), Transparency = 0.85 },
		{ Time = 1, Color = palette.orbitBright, Transparency = 0.6 },
	}, 118)
	track(rim, 0.42, "rim")

	return {
		Instance = container,
		parts = parts,
	}
end

return LogoMark
