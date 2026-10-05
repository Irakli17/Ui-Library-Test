--!nonstrict
--[[
	Vantage 1.0.0 · Layout/Elements
	------------------------------------------------------------------
	The small, non-interactive pieces a settings page is mostly made of:
	headings, paragraphs, dividers, badges, stat readouts, inline images
	and two-column rows.

	They live together because they share one thing: a single theme
	subscription each and no internal state. Anything with state belongs
	in Primitives.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)

local Elements = {}

local function makeText(spec: { [any]: any }, context: any, variant: string): any
	local tokens = Theme.current()
	local presets = {
		display = {
			textSize = "fontSizeDisplay",
			font = "display",
			color = "text",
			align = Enum.TextXAlignment.Left,
		},
		heading = {
			textSize = "fontSizeLg",
			font = "heading",
			color = "text",
			align = Enum.TextXAlignment.Left,
		},
		subheading = {
			textSize = "fontSizeMd",
			font = "subheading",
			color = "text",
			align = Enum.TextXAlignment.Left,
		},
		body = {
			textSize = "fontSizeMd",
			font = "body",
			color = "textMuted",
			align = Enum.TextXAlignment.Left,
		},
		caption = {
			textSize = "fontSizeSm",
			font = "body",
			color = "textDim",
			align = Enum.TextXAlignment.Left,
		},
		overline = {
			textSize = "fontSizeXs",
			font = "bodyBold",
			color = "textDim",
			align = Enum.TextXAlignment.Left,
		},
		code = {
			textSize = "fontSizeSm",
			font = "mono",
			color = "accent",
			align = Enum.TextXAlignment.Left,
		},
	}
	local preset = presets[variant] or presets.body

	local label = Util.text({
		Name = "Vantage" .. Util.titleCase(variant):gsub("%s", ""),
		Text = spec.Text or spec.Body or "",
		TextSize = spec.TextSize or tokens[preset.textSize],
		Font = spec.Font or preset.font,
		TextColor3 = spec.Color or tokens[spec.ColorToken or preset.color],
		TextXAlignment = spec.Align == "center" and Enum.TextXAlignment.Center
			or (spec.Align == "right" and Enum.TextXAlignment.Right or preset.align),
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = spec.Wrap ~= false,
		RichText = spec.RichText == true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = spec.LayoutOrder or 1,
		Parent = context.parent,
	})
	Util.tag(label, "Vantage")

	if variant == "overline" then
		label.Text = string.upper(label.Text)
	end

	if context.maid then
		context.maid:add(Theme.Changed:connect(function(next)
			label.TextColor3 = spec.Color or next[spec.ColorToken or preset.color]
			if not spec.TextSize then
				label.TextSize = next[preset.textSize]
			end
		end))
	end

	return label
end

--- Heading. Reads at `fontSizeLg` by default.
function Elements.heading(spec: any, context: any): any
	return makeText(spec, context, "heading")
end

--- An overline — the small all-caps label above a group.
function Elements.overline(spec: any, context: any): any
	return makeText(spec, context, "overline")
end

function Elements.body(spec: any, context: any): any
	return makeText(spec, context, "body")
end

function Elements.caption(spec: any, context: any): any
	return makeText(spec, context, "caption")
end

--- Rich paragraph with inline highlights. `spec.Segments` is a list of
--- `{ Text, Tone?, Bold? }` which is compiled into rich text, so a
--- sentence can lead with the important part without splitting into
--- separate labels.
function Elements.paragraph(spec: any, context: any): any
	local tokens = Theme.current()
	local text = spec.Text or ""
	if spec.Segments then
		local parts = {}
		for _, segment in ipairs(spec.Segments) do
			local body = Util.escapeRichText(segment.Text or "")
			if segment.Bold then
				body = "<b>" .. body .. "</b>"
			end
			if segment.Tone then
				body = string.format('<font color="#%s">%s</font>', Util.colorToHex(tokens[segment.Tone] or tokens.text), body)
			end
			table.insert(parts, body)
		end
		text = table.concat(parts)
	end

	local label = Util.text({
		Name = "VantageParagraph",
		Text = text,
		TextSize = tokens.fontSizeMd,
		Font = "body",
		TextColor3 = tokens[spec.Tone or "textMuted"],
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		RichText = spec.Segments ~= nil or spec.RichText == true,
		LineHeight = 1.15,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = spec.LayoutOrder or 1,
		Parent = context.parent,
	})
	Util.tag(label, "Vantage")

	if context.maid then
		context.maid:add(Theme.Changed:connect(function(next)
			if spec.Tone then
				label.TextColor3 = next[spec.Tone]
			end
		end))
	end
	return label
end

--- A hairline rule. `spec.Label` puts a caption in the middle.
function Elements.divider(spec: any, context: any): any
	local tokens = Theme.current()
	local root = Util.row({
		Name = "VantageDivider",
		Size = UDim2.new(1, 0, 0, spec.Label and 16 or 1),
		LayoutOrder = (spec and spec.LayoutOrder) or 1,
		Parent = context.parent,
	})
	Util.list(root, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	local line = Util.frame({
		Name = "Line",
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = tokens.border,
		BackgroundTransparency = tokens.hairlineTransparency,
		LayoutOrder = 1,
		Parent = root,
	})

	if spec.Label then
		line.Size = UDim2.new(1, -90, 0, 1)
		local label = Util.text({
			Name = "Label",
			Text = spec.Label,
			TextSize = tokens.fontSizeSm,
			Font = "bodyMedium",
			TextColor3 = tokens.textDim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, 0, 1, 0),
			LayoutOrder = 2,
			Parent = root,
		})
		if context.maid then
			context.maid:add(Theme.Changed:connect(function(next)
				line.BackgroundColor3 = next.border
				label.TextColor3 = next.textDim
			end))
		end
	end

	return root
end

--- A pill badge. `Tone` maps to a semantic token family.
function Elements.badge(spec: any, context: any): any
	local tokens = Theme.current()
	local tone = spec.Tone or "accent"
	local background = spec.Background or tokens[tone .. "Surface"]
	local foreground = spec.Color or tokens[tone]

	local pill = Util.row({
		Name = "VantageBadge",
		AnchorPoint = spec.AnchorPoint or Vector2.new(0, 0.5),
		Position = spec.Position or UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = background,
		LayoutOrder = spec.LayoutOrder or 1,
		Parent = context.parent,
	})
	Util.pill(pill)
	Util.pad(pill, { Left = 7, Right = 7 })
	if spec.Stroke then
		Util.stroke(pill, tokens[tone], 1, 0.45)
	end

	local label = Util.text({
		Name = "Text",
		Text = spec.Text or "",
		TextSize = tokens.fontSizeXs + 1,
		Font = "bodyBold",
		TextColor3 = foreground,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = pill,
	})
	Util.tag(pill, "Vantage")

	if context.maid then
		context.maid:add(Theme.Changed:connect(function(next)
			pill.BackgroundColor3 = spec.Background or next[tone .. "Surface"]
			label.TextColor3 = spec.Color or next[tone]
		end))
	end

	local object = {
		Instance = pill,
		Label = label,
	}
	function object:Set(text: string, nextTone: string?)
		label.Text = text
		if nextTone then
			tone = nextTone
			local next = Theme.current()
			pill.BackgroundColor3 = spec.Background or next[tone .. "Surface"]
			label.TextColor3 = spec.Color or next[tone]
		end
		return self
	end
	function object:destroy()
		pill:Destroy()
	end
	return object
end

--- Vertical breathing room.
function Elements.spacer(spec: any, context: any): any
	local frame = Util.row({
		Name = "VantageSpacer",
		Size = UDim2.new(1, 0, 0, (spec and spec.Size) or 8),
		LayoutOrder = (spec and spec.LayoutOrder) or 1,
		Parent = context.parent,
	})
	return frame
end

--- An inline image with the Vantage frame treatment: rounded, bordered,
--- and faded in on first paint rather than popping.
function Elements.image(spec: any, context: any): any
	local tokens = Theme.current()
	local height = spec.Height or 140
	local frame = Util.frame({
		Name = "VantageImage",
		Size = UDim2.new(spec.Width or 1, 0, 0, height),
		BackgroundColor3 = tokens.sunken,
		LayoutOrder = spec.LayoutOrder or 1,
		ClipsDescendants = true,
		Parent = context.parent,
	})
	Util.corner(frame, tokens.radiusMd)
	Util.stroke(frame, tokens.border, 1, 0.4)

	local image = Util.image({
		Name = "Image",
		Image = spec.Image or "",
		ImageTransparency = 1,
		ScaleType = spec.ScaleType or Enum.ScaleType.Crop,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = frame,
	})

	if spec.Caption then
		local caption = Util.text({
			Name = "Caption",
			Text = spec.Caption,
			TextSize = tokens.fontSizeSm,
			Font = "body",
			TextColor3 = tokens.textDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -16, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			Parent = frame,
		})
		Util.gradient(caption, {
			-- The scrim ramps to 0.6 and then holds: a keypoint array has to reach
			-- time 1, so the hold is written as its own keypoint rather than left
			-- implicit.
			{ Time = 0, Color = Color3.new(0, 0, 0), Transparency = 0.35 },
			{ Time = 0.6, Color = Color3.new(0, 0, 0), Transparency = 0.9 },
			{ Time = 1, Color = Color3.new(0, 0, 0), Transparency = 0.9 },
		}, 90)
	end

	Motion.tween(image, { ImageTransparency = spec.Transparency or 0 }, Motion.options("enter"))

	return frame
end

--- A label/value readout pair. Used in the status bar and in About pages.
function Elements.stat(spec: any, context: any): any
	local tokens = Theme.current()
	local root = Util.row({
		Name = "VantageStat",
		Size = UDim2.new(spec.Width or 0, spec.Width and 0 or 0, 0, 14),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = spec.LayoutOrder or 1,
		Parent = context.parent,
	})
	Util.list(root, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	local key = Util.text({
		Name = "Key",
		Text = spec.Label or "",
		TextSize = tokens.fontSizeXs + 1,
		Font = "bodyBold",
		TextColor3 = tokens.textDim,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		Parent = root,
	})

	local value = Util.text({
		Name = "Value",
		Text = spec.Value or "--",
		TextSize = tokens.fontSizeXs + 1,
		Font = "mono",
		TextColor3 = tokens[spec.Tone or "textMuted"],
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = root,
	})

	local object = { Instance = root, Key = key, Value = value }
	function object:Set(text: string, tone: string?)
		if value.Text == text then
			return self
		end
		value.Text = text
		if tone then
			value.TextColor3 = Theme.current()[tone]
		end
		return self
	end
	function object:destroy()
		root:Destroy()
	end
	return object
end

--- Two-column row inside a section. Columns are equal by default and
--- equalise their own heights so a row of mixed controls stays level.
function Elements.columns(spec: any, context: any): any
	local count = spec.Count or 2
	local gap = spec.Gap or 16

	local root = Util.row({
		Name = "VantageColumns",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = spec.LayoutOrder or 1,
		Parent = context.parent,
	})
	Util.list(root, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap),
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})

	local columns = {}
	for index = 1, count do
		local column = Util.row({
			Name = "Column" .. index,
			Size = UDim2.new(1 / count, -(gap * (count - 1) / count), 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
			Parent = root,
		})
		Util.stack(column, spec.RowGap or 8)
		columns[index] = column
	end

	return {
		Instance = root,
		Columns = columns,
		get = function(_, index: number)
			return columns[index] or columns[1]
		end,
		add = function(_, index: number, instance: any)
			instance.Parent = columns[index] or columns[1]
			return instance
		end,
	}
end

return Elements
