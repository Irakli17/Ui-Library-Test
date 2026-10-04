--!nonstrict
--[[
	Vantage 1.0.0 · Layout/Tab
	------------------------------------------------------------------
	A tab is the authoring surface: it owns a scroll view, a stack of
	sections, and one factory method per component.

	The factories all funnel through `Tab:mount`, which is the only place
	that knows how a component is parented, tracked and disposed. Adding
	a new component to Vantage means writing the component and adding one
	line here — there is no per-component plumbing to keep in sync.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)
local Maid = require(script.Parent.Parent.Core.Maid)
local Signal = require(script.Parent.Parent.Core.Signal)
local Elements = require(script.Parent.Elements)
local Section = require(script.Parent.Section)

local Button = require(script.Parent.Parent.Primitives.Button)
local Toggle = require(script.Parent.Parent.Primitives.Toggle)
local Slider = require(script.Parent.Parent.Primitives.Slider)
local Dropdown = require(script.Parent.Parent.Primitives.Dropdown)
local Input = require(script.Parent.Parent.Primitives.Input)
local Keybind = require(script.Parent.Parent.Primitives.Keybind)
local Segmented = require(script.Parent.Parent.Primitives.Segmented)
local Progress = require(script.Parent.Parent.Primitives.Progress)

local Tab = {}
Tab.__index = Tab

--- @param spec { Name, Icon?, Description?, Order?, Hidden?, Badge? }
--- @param context { maid, parent, window, layer }
function Tab.new(spec: { [any]: any }, context: { [any]: any })
	local tokens = Theme.current()

	local self = setmetatable({
		_spec = spec,
		_maid = Maid.new("tab"),
		_window = context.window,
		_tokens = tokens,
		_name = spec.Name or "Tab",
		_sections = {},
		_mounted = {},
		_componentMaid = Maid.new("tabComponents"),
	}, Tab)

	self.Changed = Signal.new("Tab.Changed")

	local root = Util.row({
		Name = "VantageTabContent",
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = context.parent,
	})
	Util.tag(root, "Vantage")
	self.Instance = root

	local scroll = Util.create("ScrollingFrame", {
		Name = "Scroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = tokens.borderStrong,
		ScrollBarImageTransparency = 0.4,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ScrollingEnabled = true,
		Parent = root,
	})
	self.Scroll = scroll
	Util.pad(scroll, { Right = 4 })

	local content = Util.row({
		Name = "Content",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(0, 0),
		Parent = scroll,
	})
	Util.stack(content, 14)
	Util.pad(content, { Top = 4, Bottom = 20, Left = 0, Right = 6 })
	self.Content = content

	self._layer = context.layer or root
	self._context = context

	-- Entrance/exit ------------------------------------------------------
	self._visible = false

	if self._maid then
		self._maid:add(Theme.Changed:connect(function(next)
			tokens = next
			self._tokens = next
			scroll.ScrollBarImageColor3 = next.borderStrong
		end))
	end

	return self
end

--- Internal: mounts a component instance into the tab's lifetime.
function Tab:_mount(object: any): any
	if type(object) == "table" and object.Instance then
		table.insert(self._mounted, object)
	end
	return object
end

--- Called by the window when this tab becomes active.
function Tab:_activate(animated: boolean?)
	self._visible = true
	self.Instance.Visible = true
	if animated == false or Motion.getReducedMotion() then
		self.Instance.BackgroundTransparency = 1
		return
	end
	-- A short fade plus a small upward settle. Deliberately tiny: the
	-- content is already in the right place, it just needs to land.
	self.Instance.BackgroundTransparency = 1
	Motion.setScale(self.Content, 1)
	for index, section in ipairs(self._sections) do
		local root = section.Instance
		root.GroupTransparency = 1
		Motion.tween(root, { GroupTransparency = 0 }, {
			duration = 0.3,
			easing = "enterSnap",
			delay = math.min(index - 1, 5) * 0.035,
		})
		root.Position = UDim2.fromOffset(0, 8)
		Motion.tween(root, { Position = UDim2.fromOffset(0, 0) }, {
			duration = 0.34,
			easing = "enterSnap",
			delay = math.min(index - 1, 5) * 0.035,
		})
	end
end

function Tab:_deactivate()
	self._visible = false
	self.Instance.Visible = false
end

function Tab:IsVisible(): boolean
	return self._visible
end

function Tab:GetName(): string
	return self._name
end

--- Scrolls the tab to the top. Called automatically on activation.
function Tab:ScrollToTop()
	self.Scroll.CanvasPosition = Vector2.new(0, 0)
	return self
end

--[[ Structure ------------------------------------------------------- ]]

--- Creates a section.
--- @param spec { Name, Description?, Icon?, Collapsed?, Footer?, Badge?, BadgeTone? }
function Tab:Section(spec: { [any]: any }): any
	local sectionSpec = table.clone(spec or {})
	sectionSpec.Order = sectionSpec.Order or (#self._sections + 1)
	local section = Section.new(sectionSpec, {
		maid = self._maid,
		parent = self.Content,
		window = self._window,
		tab = self,
		layer = self._layer,
	})
	table.insert(self._sections, section)
	return section
end

--- Alias so `tab:section{...}` reads either way.
Tab.section = Tab.Section

--- Non-interactive elements, mounted directly on the tab.
function Tab:Paragraph(spec: any): any
	return self:_mount(Elements.paragraph(spec, { parent = self.Content, maid = self._maid }))
end

function Tab:Heading(spec: any): any
	return self:_mount(Elements.heading(spec, { parent = self.Content, maid = self._maid }))
end

function Tab:Overline(spec: any): any
	return self:_mount(Elements.overline(spec, { parent = self.Content, maid = self._maid }))
end

function Tab:Divider(spec: any): any
	return self:_mount(Elements.divider(spec or {}, { parent = self.Content, maid = self._maid }))
end

function Tab:Spacer(size: number?): any
	return Elements.spacer({ Size = size or 8 }, { parent = self.Content, maid = self._maid })
end

--- Inline image with the Vantage frame treatment.
function Tab:Image(spec: any): any
	return self:_mount(Elements.image(spec, { parent = self.Content, maid = self._maid }))
end

--- A two-column row. `row:get(1)` and `row:get(2)` return column frames
--- you can parent components into.
function Tab:Columns(spec: any): any
	return Elements.columns(spec or {}, { parent = self.Content, maid = self._maid })
end

--- A horizontally aligned row of buttons.
function Tab:ButtonRow(spec: { [any]: any }?): any
	local options = spec or {}
	local row = Util.row({
		Name = "VantageButtonRow",
		Size = UDim2.new(1, 0, 0, 32),
		Parent = self.Content,
	})
	Util.list(row, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, options.Gap or 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = options.Align == "right" and Enum.HorizontalAlignment.Right
			or (options.Align == "center" and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left),
	})
	local context = {
		maid = self._componentMaid,
		parent = row,
		tooltip = self._window and self._window.Tooltip or nil,
	}
	return {
		Instance = row,
		Button = function(_, buttonSpec)
			return Button.new(buttonSpec, context)
		end,
	}
end

--[[ Components ------------------------------------------------------ ]]

function Tab:Button(spec: any): any
	-- Buttons that live directly on a tab default to secondary so a page
	-- of actions does not read as a wall of accent.
	local options = table.clone(spec or {})
	if options.Variant == nil then
		options.Variant = "secondary"
	end
	options.Parent = self.Content
	return self:_mount(Button.new(options, {
		maid = self._componentMaid,
		parent = self.Content,
		tooltip = self._window and self._window.Tooltip or nil,
	}))
end

function Tab:Toggle(spec: any): any
	return self:_mount(Toggle.new(spec, {
		maid = self._componentMaid,
		parent = self.Content,
		tooltip = self._window and self._window.Tooltip or nil,
	}))
end

function Tab:Slider(spec: any): any
	return self:_mount(Slider.new(spec, {
		maid = self._componentMaid,
		parent = self.Content,
	}))
end

function Tab:Dropdown(spec: any): any
	return self:_mount(Dropdown.new(spec, {
		maid = self._componentMaid,
		parent = self.Content,
		layer = self._layer,
	}))
end

function Tab:Input(spec: any): any
	return self:_mount(Input.new(spec, {
		maid = self._componentMaid,
		parent = self.Content,
	}))
end

function Tab:Keybind(spec: any): any
	return self:_mount(Keybind.new(spec, {
		maid = self._componentMaid,
		parent = self.Content,
	}))
end

function Tab:Segmented(spec: any): any
	return self:_mount(Segmented.new(spec, {
		maid = self._componentMaid,
		parent = self.Content,
	}))
end

function Tab:Progress(spec: any): any
	return self:_mount(Progress.new(spec, {
		maid = self._componentMaid,
		parent = self.Content,
	}))
end

--- A labelled readout cluster, for "About" pages.
function Tab:Stats(stats: { any }): any
	local row = Util.row({
		Name = "VantageStats",
		Size = UDim2.new(1, 0, 0, 16),
		Parent = self.Content,
	})
	Util.list(row, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 16),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	local built = {}
	for index, entry in ipairs(stats) do
		table.insert(built, Elements.stat({
			Label = entry.Label,
			Value = entry.Value,
			Tone = entry.Tone,
			LayoutOrder = index,
		}, { parent = row, maid = self._maid }))
	end
	return { Instance = row, Items = built }
end

function Tab:destroy()
	if self.Changed then
		self.Changed:destroy()
	end
	self._componentMaid:destroy()
	self._maid:destroy()
	if self.Instance then
		Motion.cancelAll(self.Instance)
		self.Instance:Destroy()
		self.Instance = nil
	end
end

return Tab
