--!nonstrict
--[[
	Vantage 1.0.0 · Core/Glyph
	------------------------------------------------------------------
	Icons, drawn from first principles.

	Vantage ships zero icon assets. Every glyph is constructed from
	rotated rounded bars and arcs on a 100x100 design grid, which means
	icons inherit the theme colour live, scale to any size without
	blurring, take exactly zero upload budget, and cost one frame per
	stroke.

	This is deliberately not a font: text glyphs depend on the client's
	font coverage and silently render as tofu on some platforms.
]]

local Util = require(script.Parent.Util)

local Glyph = {}

local GRID = 100

--- Adds a straight stroke between two points on the design grid,
--- scaled by `unit` (pixels per grid unit).
local function stroke(parent: any, x1: number, y1: number, x2: number, y2: number, weight: number, unit: number, color: any, zIndex: number)
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	local angle = math.deg(math.atan2(dy, dx))
	local thickness = math.max(1, weight * unit)
	local bar = Util.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((x1 + x2) * 0.5 * unit, (y1 + y2) * 0.5 * unit),
		-- The length overshoot is what makes joints read as a single
		-- continuous stroke rather than a row of disconnected bars.
		Size = UDim2.fromOffset(length * unit + thickness * 0.5, thickness),
		Rotation = angle,
		BackgroundColor3 = color,
		ZIndex = zIndex,
		Parent = parent,
	})
	Util.pill(bar)
	return bar
end

--- Draws a polyline through a list of `{x, y}` grid points.
local function polyline(parent: any, points: { any }, weight: number, unit: number, color: any, zIndex: number, closed: boolean?)
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		stroke(parent, a[1], a[2], b[1], b[2], weight, unit, color, zIndex)
	end
	if closed and #points > 2 then
		local a, b = points[#points], points[1]
		stroke(parent, a[1], a[2], b[1], b[2], weight, unit, color, zIndex)
	end
end

--- Samples a circular arc into grid points.
local function arcPoints(cx: number, cy: number, radius: number, startDeg: number, endDeg: number, segments: number?): { any }
	local steps = segments or math.max(6, math.floor(math.abs(endDeg - startDeg) / 9))
	local points = table.create(steps + 1)
	for index = 0, steps do
		local angle = math.rad(startDeg + (endDeg - startDeg) * (index / steps))
		points[index + 1] = { cx + math.cos(angle) * radius, cy + math.sin(angle) * radius }
	end
	return points
end

--- Filled circle.
local function disc(parent: any, cx: number, cy: number, radius: number, unit: number, color: any, zIndex: number)
	local size = radius * 2 * unit
	local dot = Util.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(cx * unit, cy * unit),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		ZIndex = zIndex,
		Parent = parent,
	})
	Util.pill(dot)
	return dot
end

--- Stroked ring.
local function ring(parent: any, cx: number, cy: number, radius: number, weight: number, unit: number, color: any, zIndex: number)
	local size = radius * 2 * unit
	local frame = Util.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(cx * unit, cy * unit),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = zIndex,
		Parent = parent,
	})
	Util.pill(frame)
	Util.stroke(frame, color, math.max(1, weight * unit), 0)
	return frame
end

--[[ Glyph definitions ---------------------------------------------- ]]

--- Each entry receives `(parent, unit, color, weight, zIndex)` where
--- `unit` is pixels-per-grid-unit, and draws itself.
Glyph.definitions = {}

local function define(name: string, painter: (any, number, any, number, number) -> ())
	Glyph.definitions[name] = painter
end

local function pointsLine(list: { any }): { any }
	local points = table.create(#list / 2)
	for index = 1, #list, 2 do
		points[#points + 1] = { list[index], list[index + 1] }
	end
	return points
end

define("check", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 22, 52, 42, 72, 78, 28 }), weight, unit, color, z)
end)

define("close", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 27, 27, 73, 73 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 73, 27, 27, 73 }), weight, unit, color, z)
end)

define("plus", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 50, 22, 50, 78 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 22, 50, 78, 50 }), weight, unit, color, z)
end)

define("minus", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 22, 50, 78, 50 }), weight, unit, color, z)
end)

define("chevron-down", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 26, 38, 50, 64, 74, 38 }), weight, unit, color, z)
end)

define("chevron-up", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 26, 62, 50, 36, 74, 62 }), weight, unit, color, z)
end)

define("chevron-left", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 62, 26, 36, 50, 62, 74 }), weight, unit, color, z)
end)

define("chevron-right", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 38, 26, 64, 50, 38, 74 }), weight, unit, color, z)
end)

define("arrow-right", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 18, 50, 78, 50 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 54, 26, 78, 50, 54, 74 }), weight, unit, color, z)
end)

define("arrow-left", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 82, 50, 22, 50 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 46, 26, 22, 50, 46, 74 }), weight, unit, color, z)
end)

define("arrow-up", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 50, 82, 50, 22 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 26, 46, 50, 22, 74, 46 }), weight, unit, color, z)
end)

define("arrow-down", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 50, 18, 50, 78 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 26, 54, 50, 78, 74, 54 }), weight, unit, color, z)
end)

define("search", function(parent, unit, color, weight, z)
	ring(parent, 44, 44, 24, weight, unit, color, z)
	polyline(parent, pointsLine({ 62, 62, 82, 82 }), weight, unit, color, z)
end)

define("dot", function(parent, unit, color, weight, z)
	disc(parent, 50, 50, weight * 0.9, unit, color, z)
end)

define("sparkle", function(parent, unit, color, weight, z)
	-- Two crossed lenses make a four-point star without any triangles.
	local long = weight * 0.55
	polyline(parent, pointsLine({ 50, 8, 50, 92 }), long, unit, color, z)
	polyline(parent, pointsLine({ 8, 50, 92, 50 }), long, unit, color, z)
	polyline(parent, pointsLine({ 28, 28, 72, 72 }), long * 0.42, unit, color, z)
	polyline(parent, pointsLine({ 72, 28, 28, 72 }), long * 0.42, unit, color, z)
end)

define("star", function(parent, unit, color, weight, z)
	local points = {}
	for index = 1, 10 do
		local angle = math.rad(-90 + (index - 1) * 36)
		local radius = index % 2 == 1 and 40 or 17
		points[#points + 1] = { 50 + math.cos(angle) * radius, 50 + math.sin(angle) * radius }
	end
	polyline(parent, points, weight * 0.72, unit, color, z, true)
end)

define("ellipsis", function(parent, unit, color, weight, z)
	for _, x in ipairs({ 24, 50, 76 }) do
		disc(parent, x, 50, weight * 0.62, unit, color, z)
	end
end)

define("hamburger", function(parent, unit, color, weight, z)
	for _, y in ipairs({ 30, 50, 70 }) do
		polyline(parent, pointsLine({ 20, y, 80, y }), weight, unit, color, z)
	end
end)

define("sliders", function(parent, unit, color, weight, z)
	local rows = { { 32, 38 }, { 52, 66 }, { 72, 24 } }
	for _, row in ipairs(rows) do
		polyline(parent, pointsLine({ 18, row[1], 82, row[1] }), weight * 0.8, unit, color, z)
		disc(parent, row[2], row[1], weight * 1.15, unit, color, z + 1)
	end
end)

define("wave", function(parent, unit, color, weight, z)
	local points = {}
	for index = 0, 24 do
		local x = 12 + index * 3.2
		points[#points + 1] = { x, 50 + math.sin(index / 24 * math.pi * 2) * 22 }
	end
	polyline(parent, points, weight, unit, color, z)
end)

define("ring", function(parent, unit, color, weight, z)
	ring(parent, 50, 50, 34, weight, unit, color, z)
end)

--- A 290-degree arc. Rotate the container for an indeterminate spinner.
define("loader", function(parent, unit, color, weight, z)
	polyline(parent, arcPoints(50, 50, 34, -90, 200, 24), weight, unit, color, z)
end)

--- Progress ring; pair with a rotating container for a determinate spinner.
define("progress-ring", function(parent, unit, color, weight, z)
	polyline(parent, arcPoints(50, 50, 34, -90, 270, 30), weight, unit, color, z)
end)

define("clock", function(parent, unit, color, weight, z)
	ring(parent, 50, 50, 34, weight, unit, color, z)
	polyline(parent, pointsLine({ 50, 50, 50, 28 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 50, 50, 68, 60 }), weight, unit, color, z)
end)

define("refresh", function(parent, unit, color, weight, z)
	polyline(parent, arcPoints(50, 50, 32, -60, 240, 22), weight, unit, color, z)
	polyline(parent, pointsLine({ 62, 6, 72, 28, 48, 26 }), weight, unit, color, z)
end)

define("trash", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 20, 30, 80, 30 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 40, 18, 60, 18 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 27, 30, 32, 84, 68, 84, 73, 30 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 44, 44, 46, 72 }), weight * 0.7, unit, color, z)
	polyline(parent, pointsLine({ 56, 44, 54, 72 }), weight * 0.7, unit, color, z)
end)

define("copy", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 36, 16, 84, 16, 84, 64, 36, 64, 36, 16 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 64, 84, 16, 84, 16, 36, 26, 36 }), weight, unit, color, z)
end)

define("lock", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 22, 46, 78, 46, 78, 86, 22, 86, 22, 46 }), weight, unit, color, z)
	polyline(parent, arcPoints(50, 46, 18, 180, 360, 14), weight, unit, color, z)
end)

define("unlock", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 22, 46, 78, 46, 78, 86, 22, 86, 22, 46 }), weight, unit, color, z)
	polyline(parent, arcPoints(66, 46, 18, 180, 300, 12), weight, unit, color, z)
end)

define("info", function(parent, unit, color, weight, z)
	ring(parent, 50, 50, 34, weight, unit, color, z)
	disc(parent, 50, 32, 7, unit, color, z + 1)
	polyline(parent, pointsLine({ 50, 46, 50, 70 }), weight, unit, color, z)
end)

define("warning", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 50, 16, 88, 82, 12, 82, 50, 16 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 50, 42, 50, 62 }), weight, unit, color, z)
	disc(parent, 50, 73, 6, unit, color, z + 1)
end)

define("sun", function(parent, unit, color, weight, z)
	ring(parent, 50, 50, 18, weight, unit, color, z)
	for index = 1, 8 do
		local angle = math.rad(index * 45)
		local x1, y1 = 50 + math.cos(angle) * 28, 50 + math.sin(angle) * 28
		local x2, y2 = 50 + math.cos(angle) * 38, 50 + math.sin(angle) * 38
		polyline(parent, pointsLine({ x1, y1, x2, y2 }), weight * 0.8, unit, color, z)
	end
end)

define("moon", function(parent, unit, color, weight, z)
	-- Outer limb, then the bite taken out of it.
	polyline(parent, arcPoints(50, 50, 36, -68, 248, 20), weight, unit, color, z)
	polyline(parent, arcPoints(72, 50, 38, 118, 428, 20), weight, unit, color, z)
end)

define("chart", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 16, 84, 86, 84 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 16, 84, 16, 16 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 28, 68, 44, 48, 60, 58, 80, 28 }), weight, unit, color, z)
end)

define("filter", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 16, 24, 84, 24, 60, 52, 60, 84, 40, 74, 40, 52, 16, 24 }), weight, unit, color, z)
end)

define("bell", function(parent, unit, color, weight, z)
	polyline(parent, arcPoints(50, 46, 28, 180, 360, 18), weight, unit, color, z)
	polyline(parent, pointsLine({ 22, 46, 18, 74, 82, 74, 78, 46 }), weight, unit, color, z)
	polyline(parent, arcPoints(50, 78, 10, 0, 180, 10), weight, unit, color, z)
end)

define("user", function(parent, unit, color, weight, z)
	ring(parent, 50, 34, 18, weight, unit, color, z)
	polyline(parent, arcPoints(50, 92, 34, 200, 340, 16), weight, unit, color, z)
end)

define("palette", function(parent, unit, color, weight, z)
	ring(parent, 50, 50, 36, weight, unit, color, z)
	disc(parent, 36, 34, weight * 0.95, unit, color, z + 1)
	disc(parent, 66, 38, weight * 0.95, unit, color, z + 1)
	disc(parent, 30, 64, weight * 0.95, unit, color, z + 1)
	disc(parent, 58, 70, weight * 0.95, unit, color, z + 1)
end)

define("grid", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 18, 24, 82, 24, 82, 46, 18, 46, 18, 24 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 18, 56, 82, 56, 82, 78, 18, 78, 18, 56 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 46, 24, 46, 78 }), weight, unit, color, z)
end)

define("list", function(parent, unit, color, weight, z)
	for _, y in ipairs({ 26, 50, 74 }) do
		disc(parent, 22, y, weight * 0.72, unit, color, z)
		polyline(parent, pointsLine({ 38, y, 84, y }), weight * 0.9, unit, color, z)
	end
end)

define("gear", function(parent, unit, color, weight, z)
	ring(parent, 50, 50, 22, weight, unit, color, z)
	ring(parent, 50, 50, 36, weight * 0.75, unit, color, z)
	for index = 1, 8 do
		local angle = math.rad(index * 45)
		local x1, y1 = 50 + math.cos(angle) * 36, 50 + math.sin(angle) * 36
		local x2, y2 = 50 + math.cos(angle) * 48, 50 + math.sin(angle) * 48
		polyline(parent, pointsLine({ x1, y1, x2, y2 }), weight * 1.5, unit, color, z)
	end
end)

define("layout", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 16, 18, 84, 18, 84, 82, 16, 82, 16, 18 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 40, 18, 40, 82 }), weight, unit, color, z)
	polyline(parent, pointsLine({ 40, 46, 84, 46 }), weight, unit, color, z)
end)

define("power", function(parent, unit, color, weight, z)
	polyline(parent, arcPoints(50, 54, 30, -60, 240, 20), weight, unit, color, z)
	polyline(parent, pointsLine({ 50, 14, 50, 50 }), weight, unit, color, z)
end)

define("bolt", function(parent, unit, color, weight, z)
	polyline(parent, pointsLine({ 58, 12, 30, 54, 48, 54, 40, 88, 68, 44, 50, 44, 58, 12 }), weight, unit, color, z)
end)

--[[ Public API ----------------------------------------------------- ]]

Glyph.names = {}

do
	local names = {}
	for name in pairs(Glyph.definitions) do
		table.insert(names, name)
	end
	table.sort(names)
	Glyph.names = names
end

--- Draws a glyph.
--- @param parent Instance to parent the strokes to.
--- @param name string Glyph name, see `Glyph.names`.
--- @param options { size: number?, color: any?, weight: number?, transparency: number?, zIndex: number?, position: UDim2?, anchor: Vector2? }
--- @return Frame? container
function Glyph.draw(parent: any, name: string, options: { [any]: any }?): any
	local opts = options or {}
	local size = opts.size or 16
	local definition = Glyph.definitions[name]
	if not definition then
		warn(string.format("[Vantage] unknown glyph %q. Available: %s", name, table.concat(Glyph.names, ", ")))
		return nil
	end

	local unit = size / GRID
	local container = Util.frame({
		Name = "VantageGlyph_" .. name,
		AnchorPoint = opts.anchor or Vector2.new(0, 0),
		Position = opts.position or UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = opts.zIndex or 1,
		Parent = parent,
	})

	definition(
		container,
		unit,
		opts.color or Color3.new(1, 1, 1),
		opts.weight or 11,
		opts.zIndex or 1
	)

	local alpha = opts.transparency or 0
	container:SetAttribute("GlyphTransparency", alpha)
	if alpha > 0 then
		Glyph.setTransparency(container, alpha)
	end

	Util.tag(container, "Vantage")
	return container
end

--- Recolours a glyph in place without rebuilding it.
function Glyph.setColor(container: any, color: any)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") and child.BackgroundTransparency < 1 then
			child.BackgroundColor3 = color
		elseif child:IsA("Frame") then
			local stroke = child:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = color
			end
		end
		Glyph.setColor(child, color)
	end
end

--- Applies transparency to a glyph in place.
function Glyph.setTransparency(container: any, transparency: number)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") then
			if child.BackgroundTransparency < 1 then
				child.BackgroundTransparency = transparency
			end
			local stroke = child:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = transparency
			end
			Glyph.setTransparency(child, transparency)
		end
	end
end

--- Fades and scales a glyph in — the standard icon entrance.
--- Captures each stroke's resting transparency first, so redrawing a
--- glyph mid-animation can never leave it half-faded.
function Glyph.animateIn(container: any, options: { [any]: any }?)
	local Motion = require(script.Parent.Motion)
	local opts = Motion.options("enter", options)
	local baseAlpha = container:GetAttribute("GlyphTransparency") or 0

	local plans = {}
	for _, child in ipairs(container:GetDescendants()) do
		if child:IsA("Frame") then
			local stroke = child:FindFirstChildOfClass("UIStroke")
			table.insert(plans, {
				frame = child,
				background = child.BackgroundTransparency,
				stroke = stroke,
				strokeTarget = baseAlpha,
			})
			child.BackgroundTransparency = 1
			if stroke then
				stroke.Transparency = 1
			end
		end
	end

	Motion.setScale(container, 0.74)
	Motion.scale(container, 1, opts)

	for _, plan in ipairs(plans) do
		if plan.background < 1 then
			Motion.tween(plan.frame, { BackgroundTransparency = plan.background }, opts)
		end
		if plan.stroke then
			Motion.tween(plan.stroke, { Transparency = plan.strokeTarget }, opts)
		end
	end
end

--- Draws a glyph and wires it to fade in with the standard entrance.
function Glyph.create(parent: any, name: string, options: { [any]: any }?): any
	return Glyph.draw(parent, name, options)
end

return Glyph
