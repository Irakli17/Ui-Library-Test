--!nonstrict
--[[
	Vantage 1.0.0 · Core/Theme
	------------------------------------------------------------------
	The design system.

	Themes are *seeded*, not hand-painted. You give Vantage a single
	accent colour and a mode, and every surface, border, state colour
	and foreground is derived with real colour maths: hue-consistent
	neutrals, contrast-checked foregrounds, and state variants that
	actually look like states. That is why a theme built with
	`Theme.fromSeed("#12B981")` looks like it was designed, and why
	nothing here ships a blue-by-default palette.

	Token names are stable API. Components read them through
	`Theme.current()`, which is mutated in place so long-lived
	references never go stale.
]]

local Util = require(script.Parent.Util)
local Signal = require(script.Parent.Signal)

local Theme = {}

--[[ Schema --------------------------------------------------------- ]]

--- Colour tokens, in the order they appear in the docs token table.
Theme.colorTokens = {
	-- Surfaces, from furthest back to nearest.
	"canvas",
	"surface",
	"surfaceAlt",
	"sunken",
	"elevated",
	"raised",
	"overlay",
	"scrim",
	-- Lines.
	"borderSubtle",
	"border",
	"borderStrong",
	-- Content.
	"text",
	"textMuted",
	"textDim",
	"textInverted",
	-- Accent.
	"accent",
	"accentHover",
	"accentPressed",
	"accentMuted",
	"accentSurface",
	"accentBorder",
	"onAccent",
	-- Semantic.
	"success",
	"successSurface",
	"onSuccess",
	"warning",
	"warningSurface",
	"onWarning",
	"danger",
	"dangerSurface",
	"onDanger",
	"info",
	"infoSurface",
	"onInfo",
	-- Interaction states.
	"hover",
	"pressed",
	"selected",
	"focusRing",
	"trackOff",
	"trackOn",
	"knob",
	"skeleton",
	"skeletonHighlight",
	"shadow",
	"glass", -- used by Scrim/Backdrop layers
}

--- Numeric tokens.
Theme.numberTokens = {
	"radiusXs", "radiusSm", "radiusMd", "radiusLg", "radiusXl", "radiusPill",
	"borderWidth", "focusWidth",
	"space1", "space2", "space3", "space4", "space5", "space6", "space7", "space8",
	"controlSm", "controlMd", "controlLg",
	"fontSizeXs", "fontSizeSm", "fontSizeMd", "fontSizeLg", "fontSizeXl", "fontSizeDisplay",
	"lineHeight", "letterWide",
}

--- Tokens that carry an opacity alongside their colour. Kept separate
--- because Roblox's Color3 has no alpha channel.
Theme.opacityTokens = {
	"scrimTransparency",
	"shadowTransparency",
	"hoverTransparency",
	"disabledTransparency",
	"hairlineTransparency",
}

Theme.tokens = Theme.colorTokens

--- Every token key, in documentation order.
Theme.allTokens = {}
for _, list in ipairs({ Theme.colorTokens, Theme.numberTokens, Theme.opacityTokens }) do
	for _, key in ipairs(list) do
		table.insert(Theme.allTokens, key)
	end
end

--- True when both values are numbers or both are Color3 — i.e. when
--- a token can be interpolated during a theme morph.
local function interpolable(a: any, b: any): boolean
	local kind = typeof(b)
	return (kind == "Color3" and typeof(a) == "Color3")
		or (kind == "number" and type(a) == "number")
end

--[[ Derivation ----------------------------------------------------- ]]

local function hsv(h: number, s: number, v: number): any
	return Color3.fromHSV((h % 1 + 1) % 1, Util.clamp01(s), Util.clamp01(v))
end

--- Semantic seeds. Slightly desaturated with the accent hue so they
--- belong to the same family as the rest of the palette.
local SEMANTIC = {
	success = { h = 0.42, s = 0.62, v = 0.88 },
	warning = { h = 0.10, s = 0.80, v = 0.95 },
	danger = { h = 0.99, s = 0.72, v = 0.96 },
	info = { h = 0.63, s = 0.72, v = 0.99 },
}

--- A semantic colour: success, warning, danger, info.
---
--- The hues are fixed, on purpose. Blending the accent hue into them
--- (which this used to do, at 15%) turned `danger` magenta on the amber
--- house theme — a destructive button that no longer looks destructive.
--- Semantics have to survive every theme, so the theme is expressed
--- through saturation and value, and never through hue.
local function semanticColor(name: string, mode: string): any
	local base = SEMANTIC[name]
	if mode == "light" then
		return hsv(base.h, base.s * 0.92, base.v * 0.62)
	end
	return hsv(base.h, base.s, base.v)
end

--- Expands a theme definition into a complete token table.
---
--- @param definition { seed: string|Color3, mode: "dark"|"light", accent?: any, overrides?: {} }
function Theme.derive(definition: { [any]: any }): { [any]: any }
	local mode = definition.mode or "dark"
	local dark = mode == "dark"

	local accent = definition.accent
	if not accent then
		if typeof(definition.seed) == "Color3" then
			accent = definition.seed
		else
			accent = (Util.hexToColor(definition.seed or "#F0A93B"))
		end
	end

	local hue = select(1, Color3.toHSV(accent))
	local tokens = {}

	-- Surfaces ------------------------------------------------------
	if dark then
		tokens.canvas = hsv(hue, 0.11, 0.040)
		tokens.surface = hsv(hue, 0.10, 0.066)
		tokens.surfaceAlt = hsv(hue, 0.095, 0.083)
		tokens.sunken = hsv(hue, 0.12, 0.030)
		tokens.elevated = hsv(hue, 0.09, 0.104)
		tokens.raised = hsv(hue, 0.085, 0.128)
		tokens.overlay = hsv(hue, 0.075, 0.160)
		tokens.borderSubtle = hsv(hue, 0.09, 0.118)
		tokens.border = hsv(hue, 0.10, 0.172)
		tokens.borderStrong = hsv(hue, 0.11, 0.255)
		tokens.text = hsv(hue, 0.055, 0.965)
		tokens.textMuted = hsv(hue, 0.075, 0.640)
		tokens.textDim = hsv(hue, 0.09, 0.415)
		tokens.textInverted = hsv(hue, 0.10, 0.055)
		tokens.hover = hsv(hue, 0.10, 0.145)
		tokens.pressed = hsv(hue, 0.11, 0.205)
		tokens.trackOff = hsv(hue, 0.09, 0.200)
		tokens.knob = hsv(hue, 0.03, 0.975)
		tokens.skeleton = hsv(hue, 0.09, 0.125)
		tokens.skeletonHighlight = hsv(hue, 0.07, 0.185)
		tokens.shadow = Color3.fromRGB(0, 0, 0)
		tokens.scrim = hsv(hue, 0.30, 0.028)
		tokens.glass = hsv(hue, 0.14, 0.072)
	else
		tokens.canvas = hsv(hue, 0.035, 0.955)
		tokens.surface = hsv(hue, 0.012, 1.000)
		tokens.surfaceAlt = hsv(hue, 0.030, 0.975)
		tokens.sunken = hsv(hue, 0.045, 0.930)
		tokens.elevated = hsv(hue, 0.010, 1.000)
		tokens.raised = hsv(hue, 0.020, 0.990)
		tokens.overlay = hsv(hue, 0.045, 0.935)
		tokens.borderSubtle = hsv(hue, 0.045, 0.935)
		tokens.border = hsv(hue, 0.065, 0.870)
		tokens.borderStrong = hsv(hue, 0.085, 0.755)
		tokens.text = hsv(hue, 0.180, 0.135)
		tokens.textMuted = hsv(hue, 0.115, 0.400)
		tokens.textDim = hsv(hue, 0.085, 0.585)
		tokens.textInverted = hsv(hue, 0.02, 0.995)
		tokens.hover = hsv(hue, 0.055, 0.930)
		tokens.pressed = hsv(hue, 0.075, 0.880)
		tokens.trackOff = hsv(hue, 0.070, 0.855)
		tokens.knob = hsv(hue, 0.01, 1.000)
		tokens.skeleton = hsv(hue, 0.040, 0.905)
		tokens.skeletonHighlight = hsv(hue, 0.020, 0.960)
		tokens.shadow = hsv(hue, 0.35, 0.180)
		tokens.scrim = hsv(hue, 0.20, 0.180)
		tokens.glass = hsv(hue, 0.02, 1.000)
		-- Ensure accent is legible as a fill against light surfaces.
		accent = Util.darken(accent, 0.22)
	end

	tokens.scrimTransparency = dark and 0.42 or 0.34
	tokens.shadowTransparency = dark and 0.55 or 0.82
	tokens.hoverTransparency = 0.0
	tokens.disabledTransparency = 0.45
	tokens.hairlineTransparency = dark and 0.35 or 0.55

	-- Accent family -------------------------------------------------
	tokens.accent = accent
	if dark then
		tokens.accentHover = Util.lighten(accent, 0.14)
		tokens.accentPressed = Util.darken(accent, 0.16)
	else
		tokens.accentHover = Util.darken(accent, 0.08)
		tokens.accentPressed = Util.darken(accent, 0.20)
	end
	tokens.onAccent = Util.contrastText(accent, tokens.textInverted, tokens.knob)
	tokens.accentMuted = Util.mixColor(accent, tokens.surface, dark and 0.45 or 0.55)
	tokens.accentSurface = Util.mixColor(accent, tokens.surface, dark and 0.84 or 0.90)
	tokens.accentBorder = Util.mixColor(accent, tokens.surface, dark and 0.62 or 0.70)
	tokens.selected = Util.mixColor(accent, tokens.surface, dark and 0.80 or 0.88)
	tokens.focusRing = Util.lighten(accent, dark and 0.05 or 0.0)
	tokens.trackOn = accent

	-- Semantic family ----------------------------------------------
	for _, name in ipairs({ "success", "warning", "danger", "info" }) do
		local base = semanticColor(name, mode)
		tokens[name] = base
		tokens[name .. "Surface"] = Util.mixColor(base, tokens.surface, dark and 0.86 or 0.90)
		tokens["on" .. name:sub(1, 1):upper() .. name:sub(2)] =
			Util.contrastText(base, tokens.textInverted, tokens.knob)
	end

	-- Metrics ------------------------------------------------------
	tokens.radiusXs = 5
	tokens.radiusSm = 8
	tokens.radiusMd = 12
	tokens.radiusLg = 16
	tokens.radiusXl = 20
	tokens.radiusPill = 999
	tokens.borderWidth = 1
	tokens.focusWidth = 2
	tokens.space1 = 4
	tokens.space2 = 8
	tokens.space3 = 12
	tokens.space4 = 16
	tokens.space5 = 20
	tokens.space6 = 24
	tokens.space7 = 32
	tokens.space8 = 40
	tokens.controlSm = 28
	tokens.controlMd = 34
	tokens.controlLg = 42
	-- Type scale, tuned for the reference client at 1.0 scale: body text has
	-- to be comfortably readable before any scaling is applied, not after.
	tokens.fontSizeXs = 11
	tokens.fontSizeSm = 12
	tokens.fontSizeMd = 14
	tokens.fontSizeLg = 16
	tokens.fontSizeXl = 20
	tokens.fontSizeDisplay = 28
	tokens.lineHeight = 1.35
	tokens.letterWide = 0

	if definition.overrides then
		for key, value in pairs(definition.overrides) do
			tokens[key] = value
		end
	end

	return tokens
end

--[[ Built-in themes ------------------------------------------------ ]]

--- Deliberately not a blue product. Obsidian leads with amber on warm
--- charcoal; Frost exists for teams that need azure, but it is one of
--- ten, not the house style.
Theme.builtins = {
	obsidian = {
		label = "Obsidian",
		description = "Amber on warm charcoal. The house theme.",
		mode = "dark",
		seed = "#F0A93B",
		category = "Signature",
	},
	graphite = {
		label = "Graphite",
		description = "Neutral studio grey with a steel accent. Zero hue bias.",
		mode = "dark",
		seed = "#B6BCC8",
		category = "Signature",
	},
	porcelain = {
		label = "Porcelain",
		description = "Light, low-glare, print-inspired. Accent darkened for AAA contrast.",
		mode = "light",
		seed = "#E0A030",
		category = "Light",
	},
	sakura = {
		label = "Sakura",
		description = "Light rose with a warm neutral base.",
		mode = "light",
		seed = "#EE6FA6",
		category = "Light",
	},
	ember = {
		label = "Ember",
		description = "Burnt orange on soot. High energy, warm shadows.",
		mode = "dark",
		seed = "#FF6B3D",
		category = "Vivid",
	},
	verdant = {
		label = "Verdant",
		description = "Emerald over deep forest neutral.",
		mode = "dark",
		seed = "#34D399",
		category = "Vivid",
	},
	amethyst = {
		label = "Amethyst",
		description = "Violet with a soft magenta lean.",
		mode = "dark",
		seed = "#A78BFA",
		category = "Vivid",
	},
	rosewood = {
		label = "Rosewood",
		description = "Deep rose on oxblood neutrals.",
		mode = "dark",
		seed = "#FB7185",
		category = "Vivid",
	},
	midnight = {
		label = "Midnight",
		description = "Indigo-neutral with a cool accent.",
		mode = "dark",
		seed = "#7C8CFF",
		category = "Vivid",
	},
	frost = {
		label = "Frost",
		description = "Azure on slate, for teams that want the blue.",
		mode = "dark",
		seed = "#4DA3FF",
		category = "Vivid",
	},
}

Theme.registry = {}

for name, definition in pairs(Theme.builtins) do
	Theme.registry[name] = definition
end

--- Registers a custom theme. `definition` accepts the same shape as
--- `Theme.derive`, plus optional `label`/`description`/`category`.
function Theme.register(name: string, definition: { [any]: any })
	local entry = table.clone(definition)
	entry.name = name
	Theme.registry[name] = entry
	return entry
end

--- All registered themes as `{ name, label, description, mode, category, swatch }`.
function Theme.list(): { any }
	local out = {}
	for name, definition in pairs(Theme.registry) do
		local tokens = Theme.derive(definition)
		table.insert(out, {
			name = name,
			label = definition.label or Util.titleCase(name),
			description = definition.description or "",
			mode = definition.mode or "dark",
			category = definition.category or "Custom",
			seed = definition.seed,
			swatch = { tokens.canvas, tokens.surface, tokens.accent, tokens.text },
		})
	end
	table.sort(out, function(a, b)
		if a.category == b.category then
			return a.label < b.label
		end
		return a.category < b.category
	end)
	return out
end

--- Builds a complete theme from one accent colour.
--- @param seed string|Color3
--- @param mode "dark"|"light"|nil
function Theme.fromSeed(seed: string, mode: string?, overrides: { [any]: any }?): { [any]: any }
	return Theme.derive({
		seed = seed,
		mode = mode or "dark",
		overrides = overrides,
	})
end

--[[ Active state --------------------------------------------------- ]]

--- The live token table. Mutated in place — never replaced — so any
--- component holding a reference always sees current values.
local active = {}
local activeName = "obsidian"
local activeMode = "dark"
local activeDefinition = Theme.builtins.obsidian

Theme.Changed = Signal.new("Theme.Changed")
--- Fires once per transition frame with `(tokens, progress)`.
Theme.Transitioning = Signal.new("Theme.Transitioning")

--- Returns the live token table.
function Theme.current(): { [any]: any }
	return active
end

--- Name of the currently applied theme.
function Theme.name(): string
	return activeName
end

--- "dark" | "light".
function Theme.mode(): string
	return activeMode
end

--- Definition table of the active theme.
function Theme.definition(): { [any]: any }
	return activeDefinition
end

--- Reads a single token.
function Theme.get(key: string): any
	return active[key]
end

--- Sets a single token on the active theme and notifies observers.
function Theme.set(key: string, value: any)
	if active[key] == value then
		return
	end
	active[key] = value
	Theme.Changed:fire(active, { [key] = value })
end

--- Sets several tokens at once, firing one notification.
function Theme.patch(values: { [string]: any })
	local changed = {}
	local didChange = false
	for key, value in pairs(values) do
		if active[key] ~= value then
			active[key] = value
			changed[key] = value
			didChange = true
		end
	end
	if didChange then
		Theme.Changed:fire(active, changed)
	end
end

--- Writes a derived theme into the live token table in place.
local function write(tokens: { [any]: any }, keys: { string }?)
	for key, value in pairs(tokens) do
		if not keys or keys[key] then
			active[key] = value
		end
	end
end

-- Seed the live table from the default theme.
write(Theme.derive(Theme.builtins.obsidian))

--- Applies a theme immediately.
--- @param target string|table Theme name, or a token table from `Theme.derive`.
function Theme.apply(target: any, options: { [any]: any }?): { [any]: any }
	local tokens
	local definition

	if type(target) == "table" then
		tokens = target
		definition = { mode = options and options.mode or activeMode, label = "Custom" }
		activeName = options and options.name or "custom"
	elseif type(target) == "string" then
		definition = Theme.registry[target]
		if not definition then
			-- Allow hex strings for one-off vibes: Theme.apply("#34D399")
			if target:match("^#?%x%x%x") then
				definition = { seed = target, mode = options and options.mode or "dark", label = "Custom" }
			else
				warn(string.format("[Vantage] unknown theme %q", target))
				return active
			end
		end
		tokens = Theme.derive(definition)
		activeName = target
	else
		warn("[Vantage] Theme.apply expects a theme name or token table")
		return active
	end

	activeDefinition = definition
	activeMode = definition.mode or "dark"

	if options and options.transition then
		return Theme.transition(tokens, type(options.transition) == "table" and options.transition or nil)
	end

	write(tokens)
	Theme.Changed:fire(active, nil)
	return active
end

local transitionHandle = nil

--- Morphs every token into `tokens` over `options.duration` seconds.
--- Colours cross-fade and metrics interpolate, so switching themes
--- reads as one continuous motion instead of a hard cut.
---
--- Local on purpose: `Theme.transition` is a thin wrapper below so the
--- library-wide `Theme.setTransitionOptions` override applies without
--- duplicating the function definition.
local function morph(tokens: { [any]: any }, options: { [any]: any }?): { [any]: any }
	local Motion = require(script.Parent.Motion)
	local opts = Motion.options("panel", options)

	if transitionHandle then
		transitionHandle:cancel()
		transitionHandle = nil
	end

	local start = {}
	local goals = {}
	local keys = {}
	for key, goal in pairs(tokens) do
		local current = active[key]
		if interpolable(current, goal) then
			start[key] = current
			goals[key] = goal
			table.insert(keys, key)
		else
			active[key] = goal
		end
	end

	local function writeFrame(alpha: number)
		local changed = {}
		for _, key in ipairs(keys) do
			local value = Motion.lerp(start[key], goals[key], alpha)
			-- Quantise colours to 8-bit so we do not fire a change for
			-- a difference no display can show.
			if typeof(value) == "Color3" then
				value = Color3.fromRGB(
					math.floor(value.R * 255 + 0.5),
					math.floor(value.G * 255 + 0.5),
					math.floor(value.B * 255 + 0.5)
				)
			end
			if active[key] ~= value then
				active[key] = value
				changed[key] = value
			end
		end
		if next(changed) then
			Theme.Changed:fire(active, changed)
		end
		Theme.Transitioning:fire(active, alpha)
	end

	local handle = Motion.tween(function() end, {}, {
		duration = opts.duration,
		easing = opts.easing,
		onUpdate = writeFrame,
		onComplete = function()
			writeFrame(1)
			transitionHandle = nil
			Theme.Changed:fire(active, nil)
		end,
	})

	transitionHandle = handle
	return active
end

--- Subscribes to token changes. Returns an unsubscribe function.
---
--- `Theme.observe(function(tokens, changed) ... end)`
function Theme.observe(callback: (any, any) -> ())
	callback(active, nil)
	local connection = Theme.Changed:connect(callback)
	return function()
		connection:disconnect()
	end
end

--- Binds a set of instance properties to tokens. Every component uses
--- this so a theme change is a single subscription, not a rebuild.
---
--- `Theme.bind(frame, { BackgroundColor3 = "surface", ... })`
function Theme.bind(maid: any, bindings: { [any]: any }, callback: (any, any) -> ())
	-- Precompute the token set so the per-frame relevance test is a
	-- single table lookup rather than a nested scan during morphs.
	local tokensUsed = {}
	local list = {}
	for instance, properties in pairs(bindings) do
		table.insert(list, { instance = instance, properties = properties })
		for _, token in pairs(properties) do
			tokensUsed[token] = true
		end
	end

	local function apply(tokens, changed)
		local full = changed == nil or next(changed) == nil
		for _, entry in ipairs(list) do
			local relevant = full
			if not relevant then
				for _, token in pairs(entry.properties) do
					if changed[token] ~= nil then
						relevant = true
						break
					end
				end
			end
			if not relevant then
				continue
			end
			for property, token in pairs(entry.properties) do
				entry.instance[property] = tokens[token]
			end
		end
		if callback then
			callback(tokens, changed)
		end
	end

	local connection = Theme.Changed:connect(apply)
	if maid then
		maid:add(connection)
	end
	apply(active, nil)
	return connection
end

--[[ Interop -------------------------------------------------------- ]]

--- A 4-stop swatch for theme pickers.
function Theme.swatch(name: string): { any }
	local definition = Theme.registry[name]
	if not definition then
		return { Color3.new(), Color3.new(1, 1, 1) }
	end
	local tokens = Theme.derive(definition)
	return { tokens.canvas, tokens.surface, tokens.accent, tokens.text }
end

--- Serialises a theme back into Luau source, so anything you design
--- in the docs playground can be pasted straight into a project.
function Theme.export(name: string): string
	local definition = Theme.registry[name]
	if not definition then
		return "-- unknown theme: " .. tostring(name)
	end
	local tokens = Theme.derive(definition)
	local lines = {
		"-- Generated by Vantage 1.0.0",
		"local Vantage = require(path.to.Vantage)",
		"",
		"Vantage.Theme.register(\"" .. name .. "\", {",
		"	label = " .. string.format("%q", definition.label or name) .. ",",
		"	description = " .. string.format("%q", definition.description or "") .. ",",
		"	mode = \"" .. (definition.mode or "dark") .. "\",",
		"	seed = \"" .. Util.colorToHex(tokens.accent) .. "\",",
		"	category = " .. string.format("%q", definition.category or "Custom") .. ",",
		"	overrides = {",
	}
	for _, key in ipairs(Theme.colorTokens) do
		lines[#lines + 1] = string.format("		%s = Color3.fromRGB(%d, %d, %d),", key,
			math.floor(tokens[key].R * 255 + 0.5),
			math.floor(tokens[key].G * 255 + 0.5),
			math.floor(tokens[key].B * 255 + 0.5))
	end
	lines[#lines + 1] = "	},"
	lines[#lines + 1] = "})"
	return table.concat(lines, "\n")
end

--- Overrides the motion used for theme morphs. By default a morph uses
--- the `panel` preset; a slower `deliberate` morph reads beautifully on
--- a landing screen.
function Theme.setTransitionOptions(options: { [any]: any })
	Theme._transitionOptions = options
end

Theme._transitionOptions = nil

--- Morphs every token into `tokens`. Falls back to the options set by
--- `Theme.setTransitionOptions` when none are given.
function Theme.transition(tokens: { [any]: any }, options: { [any]: any }?): { [any]: any }
	return morph(tokens, options or Theme._transitionOptions)
end

return Theme
