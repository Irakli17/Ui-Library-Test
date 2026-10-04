--!nonstrict
--[[
	Vantage 1.0.0 · Primitives/Button
	------------------------------------------------------------------
	The canonical interactive surface. Every clickable thing in Vantage
	— dropdown items, tab buttons, modal actions — is either a Button or
	borrows its feedback model.

	Feedback model (all four fire together on every press):

	  1. Scale  — the content dips to 0.965 on a fast, sharp curve and
	              releases on a spring, so the release overshoots very
	              slightly. Felt more than seen.
	  2. Ripple — a circular wash from the exact pointer position.
	  3. Colour — background and border shift through the state ramp.
	  4. Sound  — a short cue, configurable and silenceable.

	Plus: full keyboard focus treatment, a confirm-to-act variant that
	catches destructive clicks before they happen, a loading state with a
	real spinning arc, and an optional shortcut hint chip.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)
local Glyph = require(script.Parent.Parent.Core.Glyph)
local Config = require(script.Parent.Parent.Core.Config)
local Signal = require(script.Parent.Parent.Core.Signal)
local Ripple = require(script.Parent.Ripple)

local Button = {}
Button.__index = Button

local VARIANTS = {
	primary = {
		background = "accent",
		backgroundHover = "accentHover",
		backgroundPressed = "accentPressed",
		foreground = "onAccent",
		border = "accentHover",
		borderStrength = 0.0,
		ripple = "onAccent",
	},
	secondary = {
		background = "elevated",
		backgroundHover = "raised",
		backgroundPressed = "overlay",
		foreground = "text",
		border = "border",
		borderStrength = 1.0,
		ripple = "accent",
	},
	subtle = {
		background = "surfaceAlt",
		backgroundHover = "hover",
		backgroundPressed = "pressed",
		foreground = "textMuted",
		border = "borderSubtle",
		borderStrength = 1.0,
		ripple = "accent",
	},
	ghost = {
		background = nil,
		backgroundHover = "hover",
		backgroundPressed = "pressed",
		foreground = "textMuted",
		foregroundHover = "text",
		border = nil,
		borderStrength = 0.0,
		ripple = "accent",
	},
	danger = {
		background = "danger",
		backgroundHover = "danger",
		backgroundPressed = "danger",
		foreground = "onDanger",
		border = "danger",
		borderStrength = 0.0,
		ripple = "onDanger",
		hoverLighten = 0.12,
		pressedDarken = 0.14,
	},
	success = {
		background = "success",
		backgroundHover = "success",
		backgroundPressed = "success",
		foreground = "onSuccess",
		border = "success",
		borderStrength = 0.0,
		ripple = "onSuccess",
		hoverLighten = 0.12,
		pressedDarken = 0.14,
	},
	link = {
		background = nil,
		backgroundHover = nil,
		backgroundPressed = nil,
		foreground = "accent",
		foregroundHover = "accentHover",
		border = nil,
		borderStrength = 0.0,
		ripple = "accent",
	},
}

local SIZES = {
	sm = { height = 26, padding = 10, fontSize = "fontSizeSm", gap = 6, iconSize = 12 },
	md = { height = 32, padding = 14, fontSize = "fontSizeMd", gap = 8, iconSize = 14 },
	lg = { height = 40, padding = 18, fontSize = "fontSizeLg", gap = 9, iconSize = 16 },
}

--- Plays a named cue from `Config.sounds` if sounds are enabled.
local function playCue(name: string)
	local sounds = Config.sounds
	if not sounds or not sounds.enabled then
		return
	end
	local id = sounds[name]
	if not id or id == "" then
		return
	end
	local ok = pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = sounds.volume or 0.35
		sound.Parent = game:GetService("SoundService")
		sound:Play()
		task.delay(3, function()
			sound:Destroy()
		end)
	end)
	return ok
end

--- @param spec { Text?, Description?, Icon?, IconImage?, Variant?, Size?, FullWidth?, Disabled?, Loading?, Confirm?, Callback?, Tooltip?, TooltipText?, Shortcut?, Align?, LayoutOrder?, Parent? }
--- @param context { maid?, parent?, tooltip? }
function Button.new(spec: { [any]: any }, context: { [any]: any }?): any
	local ctx = context or {}
	local tokens = Theme.current()
	local sizeSpec = SIZES[spec.Size or "md"] or SIZES.md
	local variant = VARIANTS[spec.Variant or "secondary"] or VARIANTS.secondary

	local self = setmetatable({
		_spec = spec,
		_variantName = spec.Variant or "secondary",
		_variant = variant,
		_sizeName = spec.Size or "md",
		_size = sizeSpec,
		_maid = ctx.maid,
		_disabled = spec.Disabled == true,
		_loading = spec.Loading == true,
		_fullWidth = spec.FullWidth == true,
		_confirming = false,
		_hovering = false,
		_pressing = false,
		_tokens = tokens,
	}, Button)

	self.Clicked = Signal.new("Button.Clicked")

	local height = sizeSpec.height

	local root = Util.frame({
		Name = "VantageButton",
		BackgroundColor3 = variant.background and tokens[variant.background] or tokens.surface,
		BackgroundTransparency = variant.background and 0 or 1,
		Size = UDim2.new(self._fullWidth and 1 or 0, 0, 0, height),
		AutomaticSize = self._fullWidth and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
		ClipsDescendants = true,
		LayoutOrder = spec.LayoutOrder or 1,
		Parent = ctx.parent,
	})
	Util.tag(root, "Vantage")
	if spec.Text then
		root.Name = "VantageButton_" .. tostring(spec.Text)
	end
	Util.corner(root, tokens.radiusMd)
	self.Instance = root

	local stroke
	if variant.border then
		stroke = Util.stroke(root, tokens[variant.border], 1, 1 - variant.borderStrength)
	end
	self._stroke = stroke

	-- Focus ring: separate stroke so it can be shown without fighting
	-- the border, and so it renders outside the rounded clip.
	local focusRing = Util.frame({
		Name = "FocusRing",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 4, 1, 4),
		Position = UDim2.fromOffset(-2, -2),
		Visible = false,
		ZIndex = 0,
		Parent = root,
	})
	Util.corner(focusRing, tokens.radiusMd + 2)
	local focusStroke = Util.stroke(focusRing, tokens.focusRing, tokens.focusWidth, 1)
	self._focusRing = focusRing
	self._focusStroke = focusStroke

	-- Press scale lives on the content, never on the layout-carrying
	-- frame, so pressing never nudges surrounding rows.
	local content = Util.row({
		Name = "Content",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, sizeSpec.padding, 0.5, 0),
		Size = self._fullWidth and UDim2.new(1, -sizeSpec.padding * 2, 1, 0) or UDim2.new(0, 0, 1, 0),
		AutomaticSize = self._fullWidth and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
		Parent = root,
	})
	Util.list(content, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, sizeSpec.gap),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = spec.Align == "left" and Enum.HorizontalAlignment.Left
			or (spec.Align == "right" and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Center),
	})
	self.Content = content

	local iconHolder = Util.row({
		Name = "Icon",
		Size = UDim2.fromOffset(sizeSpec.iconSize, sizeSpec.iconSize),
		LayoutOrder = 1,
		Visible = false,
		Parent = content,
	})
	self._iconHolder = iconHolder

	local label = Util.text({
		Name = "Label",
		Text = spec.Text or "",
		TextSize = tokens[sizeSpec.fontSize],
		Font = "bodyMedium",
		TextColor3 = variant.foreground and tokens[variant.foreground] or tokens.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(0, 0, 0, sizeSpec.fontSize and tokens[sizeSpec.fontSize] + 4 or 18),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = content,
	})
	self.Label = label

	local shortcutHolder = Util.row({
		Name = "Shortcut",
		Size = UDim2.new(0, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 3,
		Visible = false,
		Parent = content,
	})
	self._shortcutHolder = shortcutHolder

	local shortcutLabel = Util.text({
		Name = "ShortcutLabel",
		Text = "",
		TextSize = tokens.fontSizeXs + 1,
		Font = "mono",
		TextColor3 = tokens.textDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = shortcutHolder,
	})
	Util.pad(shortcutHolder, { Left = 6, Right = 6 })
	self._shortcutLabel = shortcutLabel

	local spinnerHolder = Util.row({
		Name = "Spinner",
		Size = UDim2.fromOffset(sizeSpec.iconSize, sizeSpec.iconSize),
		LayoutOrder = 0,
		Visible = false,
		Parent = content,
	})
	self._spinnerHolder = spinnerHolder
	local spinner = Glyph.draw(spinnerHolder, "loader", {
		size = sizeSpec.iconSize,
		color = variant.foreground and tokens[variant.foreground] or tokens.text,
		weight = 12,
		zIndex = 4,
	})
	self._spinner = spinner
	if spinner then
		self._spinnerRotation = Motion.tween(spinner, { Rotation = 360 }, {
			duration = 0.9,
			easing = "linear",
			repeatCount = -1,
		})
	end

	-- Ripple layer.
	local rippleLayer = Util.row({
		Name = "Ripples",
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	rippleLayer.ZIndex = 3
	content.ZIndex = 4
	local ripple = Ripple.new(rippleLayer, {
		radius = tokens.radiusMd,
		zIndex = 3,
		color = variant.ripple and tokens[variant.ripple] or tokens.text,
		transparency = variant == VARIANTS.primary and 0.78 or 0.78,
	})
	self._ripple = ripple

	-- Confirm overlay.
	local confirmOverlay = Util.row({
		Name = "Confirm",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tokens.dangerSurface,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 6,
		Parent = root,
	})
	Util.corner(confirmOverlay, tokens.radiusMd)
	local confirmLabel = Util.text({
		Name = "ConfirmLabel",
		Text = spec.ConfirmText or "Click again to confirm",
		TextSize = tokens.fontSizeSm,
		Font = "bodyMedium",
		TextColor3 = tokens.danger,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = confirmOverlay,
	})
	self._confirmOverlay = confirmOverlay
	self._confirmLabel = confirmLabel

	-- Interaction ---------------------------------------------------
	local hit = Util.create("TextButton", {
		Name = "Hit",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
		Parent = root,
	})
	root.Active = true
	self._hit = hit

	local function resolveColor(key: string?)
		return key and tokens[key] or nil
	end

	--- Applies the full visual state. One function, called from every
	--- input handler, so the hover/press/disabled ramp can never drift.
	local function applyState(animated: boolean?)
		-- `hover` options also cover the un-hover ramp; the difference is
		-- carried by the easing, not by the duration.
		local opts = Motion.options((animated == false) and "instant" or "hover")
		local v = self._variant
		local disabled = self._disabled
		local background, foreground, border, transparency

		if disabled then
			background = resolveColor(v.background)
			foreground = tokens.textDim
			border = v.border and tokens.borderSubtle or nil
			transparency = 1 - (v.borderStrength > 0 and 0.55 or 0.38)
		elseif self._pressing and not self._confirming then
			background = resolveColor(v.backgroundPressed)
			foreground = resolveColor(v.foreground) or tokens.text
			border = resolveColor(v.border)
			transparency = 0
			if background and v.pressedDarken then
				background = Util.darken(background, v.pressedDarken)
			end
		elseif self._hovering then
			background = resolveColor(v.backgroundHover)
			foreground = resolveColor(v.foregroundHover) or resolveColor(v.foreground) or tokens.text
			border = resolveColor(v.border)
			transparency = 0
			if background and v.hoverLighten then
				background = Util.lighten(background, v.hoverLighten)
			end
		else
			background = resolveColor(v.background)
			foreground = resolveColor(v.foreground) or tokens.text
			border = resolveColor(v.border)
			transparency = 0
		end

		-- Ghost/link variants have no resting fill at all; every other
		-- variant always paints a background.
		if background == nil then
			root.BackgroundTransparency = 1
		else
			Motion.tween(root, { BackgroundColor3 = background, BackgroundTransparency = transparency }, opts)
		end

		local targetForeground = self._loading and tokens.textDim or foreground
		Motion.tween(label, { TextColor3 = targetForeground }, opts)
		if self._spinner and self._spinnerHolder.Visible then
			Glyph.setColor(self._spinner, targetForeground)
		end
		if self.Icon and self._iconHolder.Visible then
			Glyph.setColor(self.Icon, targetForeground)
		end
		Motion.tween(shortcutLabel, { TextColor3 = tokens.textDim }, opts)

		if stroke and border then
			Motion.tween(stroke, {
				Color = border,
				Transparency = disabled and 0.6 or (1 - v.borderStrength),
			}, opts)
		end
	end
	self._applyState = applyState

	-- Press feedback: sharp dip on a hard curve, springy release.
	local function pressScale(target: number)
		Motion.scale(content, target, {
			duration = target < 1 and 0.09 or 0.34,
			easing = target < 1 and "exitSoft" or "settle",
		})
	end
	Motion.setScale(content, 1)

	-- Pointer tracking: `MouseEnter`/`MouseMoved` give coordinates in the
	-- button's own space, which is exactly what the ripple needs.
	local pointerX, pointerY = nil, nil
	hit.MouseEnter:Connect(function(x, y)
		pointerX, pointerY = x, y
	end)
	hit.MouseMoved:Connect(function(x, y)
		pointerX, pointerY = x, y
	end)

	local function toLocal(inputPosition: any)
		local origin = rippleLayer.AbsolutePosition
		return inputPosition.X - origin.X, inputPosition.Y - origin.Y
	end

	hit.MouseEnter:Connect(function()
		self._hovering = true
		applyState()
	end)
	hit.MouseLeave:Connect(function()
		self._hovering = false
		self._pressing = false
		pressScale(1)
		applyState()
	end)

	hit.InputBegan:Connect(function(input)
		if self._disabled or self._loading then
			return
		end
		local isActivation = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		if not isActivation then
			return
		end

		self._pressing = true
		pressScale(0.965)

		if input.UserInputType == Enum.UserInputType.Touch then
			local x, y = toLocal(input.Position)
			ripple:burst(x, y)
		elseif pointerX then
			ripple:burst(pointerX, pointerY)
		else
			ripple:burst(nil, nil)
		end

		if not self._confirming then
			playCue("click")
		end
		applyState()
	end)

	hit.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		self._pressing = false
		pressScale(1)
		applyState()
	end)

	local function activate()
		if self._disabled or self._loading then
			return
		end

		if spec.Confirm and not self._confirming then
			self._confirming = true
			confirmOverlay.Visible = true
			confirmLabel.Text = spec.ConfirmText or "Click again to confirm"
			Motion.tween(confirmOverlay, {
				BackgroundTransparency = 0.12,
			}, Motion.options("fast", { easing = "enterSnap" }))
			Motion.tween(label, { TextTransparency = 1 }, Motion.options("fast"))
			self._confirmToken = (self._confirmToken or 0) + 1
			local token = self._confirmToken
			task.delay(spec.ConfirmTimeout or 2.2, function()
				if token == self._confirmToken and self._confirming then
					self:resetConfirm()
				end
			end)
			return
		end

		if self._confirming then
			self:resetConfirm()
		end

		self.Clicked:fire()
		Util.safeCall(spec.Callback, self)
	end

	hit.Activated:Connect(activate)

	if ctx.maid then
		ctx.maid:add(function()
			if self._spinnerRotation then
				self._spinnerRotation:cancel()
				self._spinnerRotation = nil
			end
		end)
	end

	-- Shortcut chip --------------------------------------------------
	if spec.Shortcut then
		shortcutHolder.Visible = true
		shortcutLabel.Text = tostring(spec.Shortcut)
		shortcutHolder.BackgroundColor3 = tokens.sunken
		shortcutHolder.BackgroundTransparency = 0.35
		Util.corner(shortcutHolder, tokens.radiusXs)
	end

	-- Icon -----------------------------------------------------------
	local iconName = spec.Icon
	local iconImage = spec.IconImage
	if iconName then
		iconHolder.Visible = true
		local glyph = Glyph.draw(iconHolder, iconName, {
			size = sizeSpec.iconSize,
			color = variant.foreground and tokens[variant.foreground] or tokens.text,
			weight = 12,
			zIndex = 4,
		})
		self.Icon = glyph
	elseif iconImage then
		iconHolder.Visible = true
		self.Icon = Util.image({
			Name = "IconImage",
			Image = iconImage,
			ImageColor3 = variant.foreground and tokens[variant.foreground] or tokens.text,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 4,
			Parent = iconHolder,
		})
	end

	if self._loading then
		self:setLoading(true)
	end
	applyState(false)

	-- Tooltip --------------------------------------------------------
	if (spec.Tooltip or spec.TooltipText) and ctx.tooltip then
		ctx.tooltip.attach(hit, spec.Tooltip or spec.TooltipText, spec.TooltipTitle)
	end

	-- Theme ----------------------------------------------------------
	local function onTheme(next: any)
		self._tokens = next
		local corner = root:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0, next.radiusMd)
		end
		local confirmCorner = confirmOverlay:FindFirstChildOfClass("UICorner")
		if confirmCorner then
			confirmCorner.CornerRadius = UDim.new(0, next.radiusMd)
		end
		if self._focusStroke then
			self._focusStroke.Color = next.focusRing
			self._focusStroke.Thickness = next.focusWidth
		end
		applyState(false)
	end

	if ctx.maid then
		ctx.maid:add(Theme.Changed:connect(onTheme))
	end

	return self
end

--- Clears the confirm state (called on timeout or on confirm).
function Button:resetConfirm()
	self._confirming = false
	self._confirmToken = (self._confirmToken or 0) + 1
	Motion.tween(self._confirmOverlay, { BackgroundTransparency = 1 }, Motion.options("exit", {
		onComplete = function()
			self._confirmOverlay.Visible = false
		end,
	}))
	Motion.tween(self.Label, { TextTransparency = 0 }, Motion.options("fast"))
end

--- Swaps the label. Reads as a small cross-fade rather than a snap, so
--- a button whose meaning changed is noticeable.
function Button:setText(text: string)
	if self.Label.Text == text then
		return self
	end
	local previous = self.Label.Text
	self.Label.Text = text
	if previous == "" or Motion.getReducedMotion() then
		return self
	end
	Motion.tween(self.Label, { TextTransparency = 1 }, Motion.options("exit", {
		onComplete = function()
			Motion.tween(self.Label, { TextTransparency = self._loading and 0.45 or 0 }, Motion.options("enter"))
		end,
	}))
	return self
end

function Button:getText(): string
	return self.Label.Text
end

function Button:setVariant(variant: string)
	if VARIANTS[variant] then
		self._variantName = variant
		self._variant = VARIANTS[variant]
		self._applyState()
	end
	return self
end

function Button:setEnabled(enabled: boolean)
	self._disabled = not enabled
	self._hit.Active = enabled
	self._applyState()
	return self
end

function Button:isEnabled(): boolean
	return not self._disabled
end

--- Shows the spinner and locks activation. `false` restores the label.
function Button:setLoading(loading: boolean)
	self._loading = loading
	self._spinnerHolder.Visible = loading
	if self.Icon then
		self._iconHolder.Visible = not loading
	end
	Motion.tween(self.Label, { TextTransparency = loading and 0.45 or 0 }, Motion.options("fast"))
	if loading then
		if self._spinner and self._spinnerRotation then
			self._spinnerRotation:resume()
		end
	elseif self._spinnerRotation then
		self._spinnerRotation:pause()
	end
	self._applyState()
	return self
end

function Button:setVisible(visible: boolean)
	self.Instance.Visible = visible
	return self
end

function Button:onClick(callback: () -> ())
	self.Clicked:connect(callback)
	return self
end

--- Fires the click programmatically, without pointer feedback.
function Button:invoke()
	self.Clicked:fire()
	Util.safeCall(self._spec.Callback, self)
end

function Button:flash()
	self._ripple:burst(nil, nil)
	return self
end

function Button:setTooltip(text: string)
	if self._tooltipHandle then
		self._tooltipHandle:text(text)
	end
	return self
end

function Button:destroy()
	if self._spinnerRotation then
		self._spinnerRotation:cancel()
		self._spinnerRotation = nil
	end
	if self._ripple then
		self._ripple:destroy()
	end
	if self.Clicked then
		self.Clicked:destroy()
	end
	if self.Instance then
		Motion.cancelAll(self.Instance)
		self.Instance:Destroy()
		self.Instance = nil
	end
end

Button.playCue = playCue
Button.VARIANTS = VARIANTS
Button.SIZES = SIZES

return Button
