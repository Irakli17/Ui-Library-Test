--!nonstrict
--[[
	Vantage 1.0.0 · Core/Util
	------------------------------------------------------------------
	Every low-level helper the rest of the library leans on: instance
	factories, colour maths, typography, safe-area maths, fuzzy search
	and number formatting. Nothing here has UI opinions — that lives in
	Theme and the components.
]]

local Util = {}

--[[ Numbers -------------------------------------------------------- ]]

function Util.clamp(value: number, min: number, max: number): number
	if value < min then
		return min
	elseif value > max then
		return max
	end
	return value
end

function Util.clamp01(value: number): number
	return Util.clamp(value, 0, 1)
end

function Util.lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

--- Maps `value` from [inMin, inMax] onto [outMin, outMax].
function Util.map(value: number, inMin: number, inMax: number, outMin: number, outMax: number): number
	if inMax == inMin then
		return outMin
	end
	return outMin + (value - inMin) / (inMax - inMin) * (outMax - outMin)
end

function Util.inverseLerp(a: number, b: number, value: number): number
	if a == b then
		return 0
	end
	return Util.clamp01((value - a) / (b - a))
end

--- Rounds to `places` decimal places without float noise.
function Util.round(value: number, places: number?): number
	local factor = 10 ^ (places or 0)
	return math.floor(value * factor + 0.5) / factor
end

--- Snaps to a step, guarding against zero/negative steps.
function Util.snap(value: number, step: number?): number
	if not step or step <= 0 then
		return value
	end
	return math.floor(value / step + 0.5) * step
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

--- Compact magnitude formatting: 1234567 -> "1.23M".
function Util.compact(value: number, places: number?): string
	local sign = value < 0 and "-" or ""
	value = math.abs(value)
	if value < 1000 then
		return sign .. tostring(Util.round(value, places or 0))
	end
	local tier = math.floor(math.log(value, 1000))
	tier = math.min(tier, #SUFFIXES)
	local scaled = value / 1000 ^ tier
	local decimals = scaled < 10 and 2 or (scaled < 100 and 1 or 0)
	return sign .. string.format("%." .. decimals .. "f", scaled) .. SUFFIXES[tier + 1]
end

--- Thousands separators: 1234567 -> "1,234,567".
function Util.commas(value: number, places: number?): string
	local rounded = Util.round(value, places or 0)
	local text = string.format("%." .. (places or 0) .. "f", math.abs(rounded))
	local whole, fraction = string.match(text, "^(%d+)(%.?.*)$")
	whole = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return (rounded < 0 and "-" or "") .. whole .. (fraction or "")
end

--- "1234" -> "1,234", 42 -> "42"
function Util.count(value: number): string
	local rounded = Util.round(value, 1)
	if rounded == math.floor(rounded) then
		return Util.commas(rounded, 0)
	end
	return Util.commas(rounded, 1)
end

--- 0.5 -> "50%"
function Util.percent(fraction: number, places: number?): string
	return string.format("%." .. (places or 0) .. "f%%", fraction * 100)
end

--- Fixed-width number used for tabular readouts (FPS, ping, %).
-- Named distinctly from `Util.pad` (the UIPadding helper) on purpose:
-- a silent collision here would format a number where an instance was
-- expected, or vice versa, with no error message.
function Util.padNumber(value: number, width: number?): string
	local text = tostring(value)
	local target = width or 3
	while #text < target do
		text = " " .. text
	end
	return text
end

--- Seconds -> "1:04:09" | "4:09" | "09s"
function Util.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	elseif minutes > 0 then
		return string.format("%d:%02d", minutes, secs)
	end
	return string.format("%ds", secs)
end

--- Bytes -> "1.4 MB"
function Util.bytes(value: number): string
	local units = { "B", "KB", "MB", "GB" }
	local index = 1
	while value >= 1024 and index < #units do
		value /= 1024
		index += 1
	end
	return string.format("%.1f %s", value, units[index])
end

--- 1234 -> "1.2 s" for timings in a status bar.
function Util.millis(seconds: number): string
	if seconds < 1 then
		return string.format("%.0f ms", seconds * 1000)
	end
	return string.format("%.2f s", seconds)
end

--[[ Tables --------------------------------------------------------- ]]

--- Shallow copy.
function Util.copy(source: { [any]: any }): { [any]: any }
	local out = table.create(#source)
	for key, value in pairs(source) do
		out[key] = value
	end
	return out
end

--- Recursively merges `patch` into `target`, returning a new table.
function Util.deepMerge(target: { [any]: any }, patch: { [any]: any }?): { [any]: any }
	local out = Util.copy(target)
	if not patch then
		return out
	end
	for key, value in pairs(patch) do
		if type(value) == "table" and type(out[key]) == "table" then
			out[key] = Util.deepMerge(out[key], value)
		else
			out[key] = value
		end
	end
	return out
end

--- A compact deep copy used for theme snapshots.
function Util.deepCopy(source: any): any
	if type(source) ~= "table" then
		return source
	end
	local out = {}
	for key, value in pairs(source) do
		out[key] = Util.deepCopy(value)
	end
	return out
end

--- Filter helper: returns a new array of entries matching `predicate`.
function Util.filter(source: { any }, predicate: (any, number) -> boolean): { any }
	local out = table.create(#source)
	for index, value in ipairs(source) do
		if predicate(value, index) then
			table.insert(out, value)
		end
	end
	return out
end

--- Maps an array.
function Util.mapList(source: { any }, transform: (any, number) -> any): { any }
	local out = table.create(#source)
	for index, value in ipairs(source) do
		out[index] = transform(value, index)
	end
	return out
end

--- Redisplays a list; keeps insertion order stable and O(n).
function Util.reduce(source: { any }, reducer: (any, any) -> any, initial: any): any
	local accumulator = initial
	for _, value in ipairs(source) do
		accumulator = reducer(accumulator, value)
	end
	return accumulator
end

--[[ Colour --------------------------------------------------------- ]]

local function clampByte(value: number): number
	return math.floor(Util.clamp(value, 0, 255) + 0.5)
end

--- "#RRGGBB", "#RGB", "RRGGBBAA" -> Color3 plus its alpha as 0..1.
function Util.hexToColor(hex: string): (Color3, number)
	local cleaned = hex:gsub("#", ""):gsub("%s", "")
	if #cleaned == 3 then
		cleaned = cleaned:sub(1, 1):rep(2) .. cleaned:sub(2, 2):rep(2) .. cleaned:sub(3, 3):rep(2)
	end
	if #cleaned ~= 6 and #cleaned ~= 8 then
		warn(string.format("[Vantage] malformed hex colour %q, using magenta", hex))
		return Color3.fromRGB(255, 0, 255), 1
	end
	local r = tonumber(cleaned:sub(1, 2), 16) or 0
	local g = tonumber(cleaned:sub(3, 4), 16) or 0
	local b = tonumber(cleaned:sub(5, 6), 16) or 0
	local a = 1
	if #cleaned == 8 then
		a = (tonumber(cleaned:sub(7, 8), 16) or 255) / 255
	end
	return Color3.fromRGB(r, g, b), a
end

function Util.colorToHex(color: Color3, alpha: number?): string
	local r = clampByte(color.R * 255)
	local g = clampByte(color.G * 255)
	local b = clampByte(color.B * 255)
	if alpha then
		return string.format("#%02X%02X%02X%02X", r, g, b, clampByte(alpha * 255))
	end
	return string.format("#%02X%02X%02X", r, g, b)
end

--- Linear blend between two colours, in sRGB space.
function Util.mixColor(a: Color3, b: Color3, alpha: number): Color3
	return Color3.new(
		Util.lerp(a.R, b.R, alpha),
		Util.lerp(a.G, b.G, alpha),
		Util.lerp(a.B, b.B, alpha)
	)
end

function Util.lighten(color: Color3, amount: number): Color3
	return Util.mixColor(color, Color3.new(1, 1, 1), amount)
end

function Util.darken(color: Color3, amount: number): Color3
	return Util.mixColor(color, Color3.new(0, 0, 0), amount)
end

--- Perceptual luminance (WCAG relative luminance).
function Util.luminance(color: Color3): number
	local function channel(c: number): number
		if c <= 0.03928 then
			return c / 12.92
		end
		return ((c + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * channel(color.R) + 0.7152 * channel(color.G) + 0.0722 * channel(color.B)
end

--- WCAG contrast ratio between two colours, 1..21.
function Util.contrast(a: Color3, b: Color3): number
	local la, lb = Util.luminance(a), Util.luminance(b)
	local lighter = math.max(la, lb)
	local darker = math.min(la, lb)
	return (lighter + 0.05) / (darker + 0.05)
end

--- Picks black or white text for maximum legibility on `background`.
--- Used to derive `onAccent` so custom themes stay readable.
function Util.contrastText(background: Color3, dark: Color3?, light: Color3?): Color3
	local darkColor = dark or Color3.fromRGB(14, 12, 10)
	local lightColor = light or Color3.fromRGB(250, 250, 252)
	if Util.contrast(background, darkColor) >= Util.contrast(background, lightColor) then
		return darkColor
	end
	return lightColor
end

--- Nudges `color` until it reads clearly against `background`.
function Util.ensureContrast(color: Color3, background: Color3, target: number): Color3
	if Util.contrast(color, background) >= target then
		return color
	end
	local towardLight = Util.luminance(background) < 0.4
	for step = 1, 20 do
		local candidate = towardLight
			and Util.lighten(color, step * 0.04)
			or Util.darken(color, step * 0.04)
		if Util.contrast(candidate, background) >= target or step == 20 then
			return candidate
		end
	end
	return color
end

--[[ Text ----------------------------------------------------------- ]]

--- The font stack. Modern clients get FontFace (real weight axis);
--- older clients silently fall back to the enum, which still renders.
Util.fontStack = {
	display = Enum.Font.GothamBlack,
	heading = Enum.Font.GothamBold,
	subheading = Enum.Font.GothamMedium,
	body = Enum.Font.Gotham,
	bodyMedium = Enum.Font.GothamMedium,
	bodyBold = Enum.Font.GothamBold,
	mono = Enum.Font.RobotoMono,
}

Util.fontKeys = {
	"display", "heading", "subheading", "body", "bodyMedium", "bodyBold", "mono",
}

--- Applies a font to any text-bearing instance with a two-tier
--- strategy: enum first (always valid), then FontFace on top.
function Util.applyFont(instance: any, key: string?)
	local fontEnum = Util.fontStack[key or "body"] or Util.fontStack.body
	local ok = pcall(function()
		instance.Font = fontEnum
	end)
	if not ok and instance:IsA("TextLabel") then
		-- Some custom classes only expose FontFace.
		pcall(function()
			instance.FontFace = Font.fromEnum(fontEnum)
		end)
	end
	pcall(function()
		instance.FontFace = Font.fromEnum(fontEnum)
	end)
	return instance
end

local TextService
--- Measures rendered text. Falls back to an estimate when TextService
--- is unavailable (headless/test environments).
function Util.measureText(text: string, font: any, size: number, frameSize: any?): any
	if not TextService then
		local ok, service = pcall(function()
			return game:GetService("TextService")
		end)
		TextService = ok and service or false
	end
	if TextService and TextService.GetTextSize then
		local ok, result = pcall(function()
			return TextService:GetTextSize(
				text,
				size,
				font or Enum.Font.Gotham,
				frameSize or Vector2.new(1000000, 1000000)
			)
		end)
		if ok then
			return result
		end
	end
	-- Rough monospace-ish estimate: good enough for layout decisions.
	return Vector2.new(#text * size * 0.54, size * 1.25)
end

--- Splits a string into characters, respecting UTF-8 (for typing
--- animations and per-letter effects).
function Util.splitGraphemes(text: string): { string }
	local out = {}
	for _, code in utf8.codes(text) do
		table.insert(out, utf8.char(code))
	end
	return out
end

--- "helloWorld_thing" -> "Hello World Thing"
function Util.titleCase(text: string): string
	local spaced = text:gsub("(%l)(%u)", "%1 %2"):gsub("[_%-]+", " ")
	local out = {}
	for word in spaced:gmatch("%S+") do
		table.insert(out, word:sub(1, 1):upper() .. word:sub(2))
	end
	return table.concat(out, " ")
end

--- Wraps a table of words to a max character width.
function Util.wrapText(text: string, maxChars: number): string
	local lines, current = {}, {}
	local length = 0
	for word in text:gmatch("%S+") do
		local wordLength = #word
		if length > 0 and length + wordLength + 1 > maxChars then
			table.insert(lines, table.concat(current, " "))
			current, length = {}, 0
		end
		table.insert(current, word)
		length += wordLength + (length > 0 and 1 or 0)
	end
	if #current > 0 then
		table.insert(lines, table.concat(current, " "))
	end
	return table.concat(lines, "\n")
end

--- Escapes rich-text markup so user strings never inject tags.
function Util.escapeRichText(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

--[[ Search --------------------------------------------------------- ]]

--- Subsequence fuzzy matcher with positional scoring. Returns
--- `score, matches` where `matches` is a list of matched indices, or
--- nil when the query does not match. Used by the command palette,
--- dropdown search and the settings filter.
function Util.fuzzyMatch(query: string, target: string, previous: { number }?): (number?, { number }?)
	if query == "" then
		return 1, {}
	end
	local lowerQuery = query:lower()
	local lowerTarget = target:lower()
	if #lowerQuery > #lowerTarget then
		return nil, nil
	end

	local score = 0
	local matches = {}
	local targetIndex = 1
	local previousIndex = -1

	for queryIndex = 1, #lowerQuery do
		local char = lowerQuery:sub(queryIndex, queryIndex)
		if char == " " then
			continue
		end
		local found = lowerTarget:find(char, targetIndex, true)
		if not found then
			return nil, nil
		end

		local isWordStart = found == 1
			or lowerTarget:sub(found - 1, found - 1):match("[%s_%-%./]") ~= nil
			or target:sub(found, found):match("%u") ~= nil

		score += 10
		if isWordStart then
			score += 22
		end
		if previousIndex == found - 1 then
			score += 30
		else
			score -= math.min(found - targetIndex, 14)
		end
		if queryIndex == 1 and found == 1 then
			score += 16
		end

		previousIndex = found
		targetIndex = found + 1
		table.insert(matches, found)
	end

	-- Prefer shorter targets when the score ties (exact-ish wins).
	score -= math.floor(#target * 0.4)

	if previous then
		for index = 1, math.max(#previous, #matches) do
			if previous[index] ~= matches[index] then
				score += 6
				break
			end
		end
	end

	return score, matches
end

--[[ Instances ------------------------------------------------------ ]]

--- The single instance factory used by every component.
--- `properties` is assigned verbatim; `children` is an array.
function Util.create(className: string, properties: { [string]: any }?, children: { any }?): any
	local instance = Instance.new(className)
	local fontKey: string? = nil
	if properties then
		for key, value in pairs(properties) do
			if key ~= "Parent" and value ~= nil then
				if key == "Font" and type(value) == "string" then
					-- A `Font` in a spec is a key into the font stack, not an enum.
					-- The engine's Font property only accepts an Enum.Font, and
					-- assigning the key itself throws
					-- `Invalid value "display" for enum Font` — so the key is
					-- resolved through the stack instead of being forwarded.
					fontKey = value
				else
					instance[key] = value
				end
			end
		end
	end
	if fontKey then
		Util.applyFont(instance, fontKey)
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	if properties and properties.Parent then
		instance.Parent = properties.Parent
	end
	return instance
end

--- Shorthand for a Frame.
function Util.frame(properties: { [string]: any }?, children: { any }?): any
	local frame = Util.create("Frame", properties, children)
	frame.BorderSizePixel = 0
	if frame.BackgroundTransparency == nil then
		frame.BackgroundTransparency = 0
	end
	return frame
end

--- A fully transparent layout-only Frame.
function Util.row(properties: { [string]: any }?, children: { any }?): any
	local merged = Util.copy(properties or {})
	merged.BackgroundTransparency = merged.BackgroundTransparency or 1
	return Util.frame(merged, children)
end

--- A container that fades as a single object.
---
--- `GroupTransparency` is a `CanvasGroup` property: on a Frame the engine
--- throws `GroupTransparency is not a valid member of Frame`, which is how a
--- fade that looked fine in every offline test threw inside the loading
--- screen's worker on a real client. Anything the library fades as a group —
--- toast cards, the palette, modal panels, sections, the logo, the loading
--- column — is therefore built as a CanvasGroup rather than a Frame with a
--- property it does not have. Background stays transparent unless asked,
--- matching `Util.row`, so a swap is geometry- and colour-neutral.
function Util.group(properties: { [string]: any }?, children: { any }?): any
	local merged = Util.copy(properties or {})
	merged.BackgroundTransparency = merged.BackgroundTransparency or 1
	local group = Util.create("CanvasGroup", merged, children)
	group.BorderSizePixel = 0
	return group
end

--- Text factory with the Vantage typography defaults applied.
function Util.text(properties: { [string]: any }?, children: { any }?): any
	local merged = Util.copy(properties or {})
	merged.BackgroundTransparency = 1
	merged.TextColor3 = merged.TextColor3 or Color3.fromRGB(235, 235, 242)
	merged.TextXAlignment = merged.TextXAlignment or Enum.TextXAlignment.Left
	merged.TextYAlignment = merged.TextYAlignment or Enum.TextYAlignment.Center
	if merged.TextSize == nil then
		merged.TextSize = 13
	end
	local label = Util.create("TextLabel", merged, children)
	Util.applyFont(label, merged.Font or "body")
	label.RichText = merged.RichText or false
	return label
end

--- Image factory.
function Util.image(properties: { [string]: any }?, children: { any }?): any
	return Util.create("ImageLabel", properties, children)
end

--- Adds or reuses a UICorner.
function Util.corner(instance: any, radius: number?): any
	local corner = instance:FindFirstChildOfClass("UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.Parent = instance
	end
	corner.CornerRadius = UDim.new(0, radius or 0)
	return corner
end

--- Fully rounded corners (pill). Works for both frames and strokes.
function Util.pill(instance: any): any
	return Util.corner(instance, 999)
end

--- Adds or reuses a UIStroke.
function Util.stroke(instance: any, color: any, thickness: number?, transparency: number?): any
	local stroke = instance:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = instance
	end
	stroke.Color = color or Color3.fromRGB(60, 60, 70)
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	if stroke.LineJoinMode == nil then
		pcall(function()
			stroke.LineJoinMode = Enum.LineJoinMode.Round
		end)
	end
	return stroke
end

--- Adds or reuses a UIGradient.
---
--- `keypoints` is a list of `{ Time?, Color, Transparency? }`. Time
--- defaults to an even spread across the gradient.
---
--- The engine's keypoint arrays are strict: at least two keypoints, the first
--- at exactly time 0, the last at exactly time 1, ordered by time, every entry
--- a real keypoint. A `UIGradient` built any other way is not merely ugly —
--- `ColorSequence.new` throws, and a throw inside a screen build strands the
--- player on a half-painted backdrop, which is exactly how a single call with
--- parallel colour/time arrays took down every entry point on the live client.
--- So the times are normalised here, and every caller gets a legal sequence.
--- A single keypoint is expressed through the two-keypoint overloads, because
--- `ColorSequence.new({ keypoint })` is itself rejected (`requires at least 2
--- keypoints`).
function Util.gradient(instance: any, keypoints: { any }, rotation: number?, enabled: boolean?): any
	local gradient = instance:FindFirstChildOfClass("UIGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Parent = instance
	end

	local count = #keypoints
	if count == 0 then
		gradient.Enabled = false
		return gradient
	end

	local times = table.create(count)
	local previous = 0
	for index, keypoint in ipairs(keypoints) do
		local time = keypoint.Time
		if time == nil then
			time = count == 1 and 0 or (index - 1) / (count - 1)
		end
		time = Util.clamp01(time)
		if time < previous then
			time = previous
		end
		previous = time
		times[index] = time
	end

	if count == 1 then
		-- Flat gradient: the overloads the engine accepts for one colour.
		gradient.Color = ColorSequence.new(keypoints[1].Color or Color3.new(1, 1, 1))
		gradient.Transparency = NumberSequence.new(Util.clamp01(keypoints[1].Transparency or 0))
	else
		-- Anchor the ends, which every keypoint array has to touch exactly.
		times[1] = 0
		times[count] = 1

		local colorStops = table.create(count)
		local stops = table.create(count)
		for index = 1, count do
			colorStops[index] = ColorSequenceKeypoint.new(times[index], keypoints[index].Color or Color3.new(1, 1, 1))
			stops[index] = NumberSequenceKeypoint.new(times[index], Util.clamp01(keypoints[index].Transparency or 0))
		end

		gradient.Color = ColorSequence.new(colorStops)
		gradient.Transparency = NumberSequence.new(stops)
	end

	gradient.Rotation = rotation or 0
	gradient.Enabled = enabled ~= false
	return gradient
end

--- Adds or reuses a UIPadding.
function Util.pad(instance: any, padding: { [string]: number }): any
	local uiPadding = instance:FindFirstChildOfClass("UIPadding")
	if not uiPadding then
		uiPadding = Instance.new("UIPadding")
		uiPadding.Parent = instance
	end
	if padding.Top then
		uiPadding.PaddingTop = UDim.new(0, padding.Top)
	end
	if padding.Bottom then
		uiPadding.PaddingBottom = UDim.new(0, padding.Bottom)
	end
	if padding.Left then
		uiPadding.PaddingLeft = UDim.new(0, padding.Left)
	end
	if padding.Right then
		uiPadding.PaddingRight = UDim.new(0, padding.Right)
	end
	return uiPadding
end

--- Adds or reuses a list layout.
function Util.list(instance: any, properties: { [string]: any }?): any
	local layout = instance:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Parent = instance
	end
	if properties then
		for key, value in pairs(properties) do
			layout[key] = value
		end
	end
	return layout
end

--- Adds or reuses a UIListLayout configured as a vertical stack.
function Util.stack(instance: any, padding: number?, alignment: any?): any
	return Util.list(instance, {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding or 0),
		HorizontalAlignment = alignment or Enum.HorizontalAlignment.Left,
	})
end

--- Adds a UICorner-aware mask: clipping children to a rounded rect.
function Util.clipRounded(instance: any, radius: number): any
	instance.ClipsDescendants = true
	return Util.corner(instance, radius)
end

--- Adds a UISizeConstraint.
function Util.sizeConstraint(instance: any, min: any?, max: any?): any
	local constraint = instance:FindFirstChildOfClass("UISizeConstraint")
	if not constraint then
		constraint = Instance.new("UISizeConstraint")
		constraint.Parent = instance
	end
	if min then
		constraint.MinSize = min
	end
	if max then
		constraint.MaxSize = max
	end
	return constraint
end

--- Tags an instance for CollectionService-based tooling and for the
--- Studio plugin's "highlight all Vantage UI" command.
function Util.tag(instance: any, tagName: string)
	local ok, service = pcall(function()
		return game:GetService("CollectionService")
	end)
	if ok and service then
		pcall(function()
			service:AddTag(instance, tagName)
		end)
	end
	return instance
end

--- Names an instance with the Vantage prefix so the Explorer tree is
--- readable when the library is used inside a large project.
function Util.name(instance: any, name: string, debugLabel: string?): any
	instance.Name = debugLabel and string.format("Vantage%s_%s", name, debugLabel) or ("Vantage" .. name)
	return instance
end

--- Wraps a callback so a user error can never break an animation
--- frame or a signal dispatch.
function Util.safeCall(callback: any, ...): boolean
	if type(callback) ~= "function" then
		return false
	end
	local ok, err = xpcall(callback, function(e)
		return tostring(e) .. "\n" .. debug.traceback("", 2)
	end, ...)
	if not ok then
		warn("[Vantage] callback error: " .. tostring(err))
		return false
	end
	return true
end

--- Defers a callback to a fresh thread, safely.
function Util.defer(callback: () -> ())
	if task and task.defer then
		task.defer(Util.safeCall, callback)
	else
		coroutine.wrap(Util.safeCall)(callback)
	end
end

--- Trailing-edge debounce. Arguments are captured at call time so the
--- callback fires with the most recent payload.
function Util.debounce(callback: (...any) -> (), delay: number)
	local token = 0
	return function(...)
		token += 1
		local mine = token
		local args = table.pack(...)
		task.delay(delay, function()
			if mine == token then
				Util.safeCall(callback, table.unpack(args, 1, args.n))
			end
		end)
	end
end

--- Leading-edge throttle with a trailing flush.
function Util.throttle(callback: (...any) -> (), interval: number)
	local last = 0
	local queued = nil
	local args = nil
	return function(...)
		local now = os.clock()
		if now - last >= interval then
			last = now
			Util.safeCall(callback, ...)
		elseif not queued then
			args = table.pack(...)
			queued = true
			task.delay(interval - (now - last), function()
				queued = false
				last = os.clock()
				Util.safeCall(callback, table.unpack(args, 1, args.n))
			end)
		end
	end
end

local uidCounter = 0
--- Monotonic, collision-free id. Deterministic across runs.
function Util.uid(prefix: string?): string
	uidCounter += 1
	return string.format("%s%d", prefix or "v", uidCounter)
end

--- True when `instance` is a descendant of `ancestor`.
function Util.isDescendantOf(instance: any, ancestor: any): boolean
	local current = instance
	while current do
		if current == ancestor then
			return true
		end
		current = current.Parent
	end
	return false
end

--- Walks the tree from `root`, calling `visit` on every descendant
--- matching `className` (or all when nil). Skips nothing.
function Util.walk(root: any, className: string?, visit: (any) -> ())
	for _, child in ipairs(root:GetChildren()) do
		if not className or child:IsA(className) then
			visit(child)
		end
		Util.walk(child, className, visit)
	end
end

--[[ Viewport / safe area ------------------------------------------ ]]

local GuiService, UserInputService
Util._insetCache = nil
Util._insetCacheAt = 0

--- Returns the usable screen rect, accounting for Roblox's topbar,
--- the mobile bottom home indicator and notches.
--- @return { top: number, bottom: number, left: number, right: number }
function Util.insets()
	local now = os.clock()
	if Util._insetCache and now - Util._insetCacheAt < 1 then
		return Util._insetCache
	end

	if not GuiService then
		local ok, service = pcall(function()
			return game:GetService("GuiService")
		end)
		GuiService = ok and service or false
	end
	if not UserInputService then
		local ok, service = pcall(function()
			return game:GetService("UserInputService")
		end)
		UserInputService = ok and service or false
	end

	local top, bottom, left, right = 0, 0, 0, 0
	if GuiService and GuiService.GetGuiInset then
		local ok, inset = pcall(function()
			return GuiService:GetGuiInset()
		end)
		if ok and inset then
			top = inset.Y
			left = inset.X
		end
	end

	local touch = false
	if UserInputService and UserInputService.TouchEnabled ~= nil then
		touch = UserInputService.TouchEnabled == true
	end
	local isPhone = touch
	if isPhone then
		-- Home indicator / gesture bar clearance on phones.
		bottom = 24
		left = math.max(left, 12)
		right = math.max(right, 12)
	end

	Util._insetCache = { top = top, bottom = bottom, left = left, right = right }
	Util._insetCacheAt = now
	return Util._insetCache
end

--- Current viewport size in pixels (GUI space, not camera space).
function Util.viewport(): any
	local camera = workspace and workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		if size and size.X > 0 then
			return size
		end
	end
	return Vector2.new(1920, 1080)
end

--- Responsive breakpoint bucket for the current viewport.
--- < 600 phone · < 1000 tablet · < 1500 compact · else desktop
function Util.breakpoint(width: number?): string
	local w = width or Util.viewport().X
	if w < 600 then
		return "phone"
	elseif w < 1000 then
		return "tablet"
	elseif w < 1500 then
		return "compact"
	end
	return "desktop"
end

--- A UI scale that keeps the interface physically consistent across
--- resolutions: 1.0 at 1920x1080, smaller on laptops, larger on 4K.
function Util.uiScale(baseWidth: number?): number
	local width = Util.viewport().X
	local reference = baseWidth or 1920
	-- Damped rather than linear so ultrawide screens stay usable.
	local raw = width / reference
	return Util.clamp(0.78 + (raw - 0.78) * 0.62, 0.72, 1.35)
end

--- True when the player is on a touch-only device.
function Util.isTouch(): boolean
	if not UserInputService then
		pcall(function()
			UserInputService = game:GetService("UserInputService")
		end)
	end
	return UserInputService ~= nil
		and UserInputService ~= false
		and UserInputService.TouchEnabled == true
		and UserInputService.KeyboardEnabled == false
end

--- True when the player prefers reduced motion (falls back to the
--- library-wide Config flag).
function Util.prefersReducedMotion(): boolean
	if not UserInputService then
		pcall(function()
			UserInputService = game:GetService("UserInputService")
		end)
	end
	if UserInputService and UserInputService ~= false then
		local ok, value = pcall(function()
			return UserInputService.ReducedMotionEnabled
		end)
		if ok and value ~= nil then
			return value == true
		end
	end
	return false
end

--[[ Misc ----------------------------------------------------------- ]]

--- Structural equality for arrays of primitives (used by dirty-checks).
function Util.arrayEquals(a: { any }, b: { any }): boolean
	if #a ~= #b then
		return false
	end
	for index = 1, #a do
		if a[index] ~= b[index] then
			return false
		end
	end
	return true
end

--- Version string for logging and the status bar.
Util.version = "1.0.0"
Util.build = "stable"

return Util
