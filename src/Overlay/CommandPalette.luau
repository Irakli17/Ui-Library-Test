--!nonstrict
--[[
	Vantage 1.0.0 · Overlay/CommandPalette
	------------------------------------------------------------------
	Ctrl+K, type, hit Enter.

	Every full-screen interface eventually has too many controls to
	hunt for. A command palette turns "find the toggle" into three
	keystrokes, and it costs the host application almost nothing: register
	a list of `{ Name, Section, Icon, Run, Keys }` and Vantage does the
	ranking, the keyboard model and the rendering.

	· Ranked with the same fuzzy scorer the dropdown search uses, so
	  behaviour is identical everywhere in the library.
	· Recently used commands float to the top of an empty query, which is
	  what makes a palette feel like it knows you.
	· Up/Down/Enter/Escape, plus Home/End. The list wraps at both ends.
	· Shortcut hints show the real bound key, not a hard-coded string.
]]

local Util = require(script.Parent.Parent.Core.Util)
local Motion = require(script.Parent.Parent.Core.Motion)
local Theme = require(script.Parent.Parent.Core.Theme)
local Config = require(script.Parent.Parent.Core.Config)
local Maid = require(script.Parent.Parent.Core.Maid)
local Signal = require(script.Parent.Parent.Core.Signal)
local Glyph = require(script.Parent.Parent.Core.Glyph)

local CommandPalette = {}
CommandPalette.__index = CommandPalette

local ROW_HEIGHT = 34
local MAX_ROWS = 8
local RECENT_LIMIT = 6

--- @param context { layer: Instance, maid?: Maid }
function CommandPalette.new(context: { [any]: any })
	local tokens = Theme.current()
	local self = setmetatable({
		_layer = context.layer,
		_maid = Maid.new("palette"),
		_tokens = tokens,
		_commands = {},
		_recent = {},
		_open = false,
		_query = "",
		_highlight = 1,
		_results = {},
		_rows = {},
	}, CommandPalette)

	self.Ran = Signal.new("CommandPalette.Ran")

	local root = Util.frame({
		Name = "VantageCommandPalette",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tokens.scrim,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 800,
		Parent = context.layer,
	})
	self.Instance = root

	local blocker = Util.create("TextButton", {
		Name = "Blocker",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = root,
	})
	blocker.Activated:Connect(function()
		self:Close()
	end)

	-- A CanvasGroup: the palette fades in and out as one object.
	local panel = Util.group({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(440, 52),
		BackgroundColor3 = tokens.elevated,
		BackgroundTransparency = 0,
		ClipsDescendants = true,
		ZIndex = 810,
		Parent = root,
	})
	Util.corner(panel, tokens.radiusLg)
	Util.stroke(panel, tokens.border, 1, 0.2)
	Util.tag(panel, "Vantage")
	self.Panel = panel

	local searchRow = Util.row({
		Name = "SearchRow",
		Size = UDim2.new(1, 0, 0, 52),
		Parent = panel,
	})
	Util.pad(searchRow, { Left = 16, Right = 14 })

	local searchIconHolder = Util.row({
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(15, 15),
		ZIndex = 4,
		Parent = panel,
	})
	Glyph.draw(searchIconHolder, "search", {
		size = 15,
		color = tokens.textDim,
		weight = 12,
		zIndex = 4,
	})

	local box = Util.create("TextBox", {
		Name = "Box",
		Text = "",
		PlaceholderText = "Type a command...",
		PlaceholderColor3 = tokens.textDim,
		TextSize = tokens.fontSizeLg,
		Font = Enum.Font.GothamMedium,
		TextColor3 = tokens.text,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromOffset(42, 0),
		ClearTextOnFocus = false,
		ZIndex = 4,
		Parent = panel,
	})
	Util.applyFont(box, "bodyMedium")
	self.SearchBox = box

	local hintHolder = Util.row({
		Name = "Hint",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 4,
		Parent = panel,
	})
	Util.pad(hintHolder, { Left = 6, Right = 6 })
	Util.corner(hintHolder, tokens.radiusXs)
	hintHolder.BackgroundColor3 = tokens.sunken
	hintHolder.BackgroundTransparency = 0.3
	Util.text({
		Name = "HintLabel",
		Text = "ESC",
		TextSize = tokens.fontSizeXs,
		Font = "mono",
		TextColor3 = tokens.textDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = hintHolder,
	})

	local listHolder = Util.row({
		Name = "List",
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.fromOffset(0, 52),
		Parent = panel,
	})
	Util.stack(listHolder, 0)
	Util.pad(listHolder, { Left = 8, Right = 8, Bottom = 8 })
	-- Named `ListHolder`, not `List`: `CommandPalette:List()` is the public
	-- accessor for the registered commands, and a field of the same name
	-- would replace it on the instance.
	self.ListHolder = listHolder

	local empty = Util.text({
		Name = "Empty",
		Text = "No matching commands",
		TextSize = tokens.fontSizeSm,
		Font = "body",
		TextColor3 = tokens.textDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, -16, 0, 40),
		Visible = false,
		Parent = listHolder,
	})
	self._empty = empty

	-- Registering ------------------------------------------------------
	--- @param commands { { Name: string, Section?: string, Icon?: string, Description?: string, Keys?: string, Run: () -> () }[] }
	function self:Register(commands)
		for _, command in ipairs(commands or {}) do
			table.insert(self._commands, command)
		end
		return self
	end

	local function buildRows()
		for _, row in ipairs(self._rows) do
			row.frame:Destroy()
		end
		table.clear(self._rows)
	end
	self._buildRows = buildRows

	-- Forward declarations: row handlers need to reach the painters that
	-- are defined after the row factory.
	local paint
	local runHighlighted

	local function ensureRows(count: number)
		while #self._rows < count do
			local index = #self._rows + 1
			local rowIndex = index
			local frame = Util.frame({
				Name = "Row" .. index,
				Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
				BackgroundColor3 = tokens.hover,
				BackgroundTransparency = 1,
				LayoutOrder = index,
				Parent = listHolder,
			})
			Util.corner(frame, tokens.radiusSm)
			Util.pad(frame, { Left = 10, Right = 10 })

			local iconHolder = Util.row({
				Name = "Icon",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 10, 0.5, 0),
				Size = UDim2.fromOffset(13, 13),
				ZIndex = 4,
				Parent = frame,
			})

			local label = Util.text({
				Name = "Label",
				Text = "",
				TextSize = tokens.fontSizeMd,
				Font = "bodyMedium",
				TextColor3 = tokens.text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(34, 0),
				Size = UDim2.new(1, -120, 1, 0),
				ZIndex = 4,
				Parent = frame,
			})

			local sectionLabel = Util.text({
				Name = "Section",
				Text = "",
				TextSize = tokens.fontSizeXs,
				Font = "bodyBold",
				TextColor3 = tokens.textDim,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Center,
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.new(1, -12, 1, 0),
				ZIndex = 4,
				Parent = frame,
			})

			local hit = Util.create("TextButton", {
				Name = "Hit",
				Text = "",
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 6,
				Parent = frame,
			})

			local entry = {
				index = rowIndex,
				frame = frame,
				iconHolder = iconHolder,
				label = label,
				section = sectionLabel,
				hit = hit,
			}

			-- Handlers are wired at creation, because rows are recycled
			-- and must not accumulate connections across searches.
			hit.MouseEnter:Connect(function()
				self._highlight = entry.index
				paint()
			end)
			hit.Activated:Connect(function()
				self._highlight = entry.index
				runHighlighted()
			end)

			table.insert(self._rows, entry)
		end
	end

	paint = function()
		for index, row in ipairs(self._rows) do
			local result = self._results[index]
			if not result then
				row.frame.Visible = false
				continue
			end
			row.frame.Visible = true
			local active = index == self._highlight
			-- `Label` is the documented field (`Add({ Label, Hint, Run })`);
			-- `Name` is accepted as an alias. Reading `Name` alone left every
			-- row blank and threw `string expected, got nil` on a live client.
			row.label.Text = result.command.Label or result.command.Name or ""
			row.section.Text = result.command.Section or ""
			Motion.tween(row.frame, {
				BackgroundTransparency = active and 0 or 1,
			}, Motion.options("hover"))
			Motion.tween(row.label, {
				TextColor3 = active and tokens.text or tokens.textMuted,
			}, Motion.options("hover"))

			for _, child in ipairs(row.iconHolder:GetChildren()) do
				child:Destroy()
			end
			Glyph.draw(row.iconHolder, result.command.Icon or "arrow-right", {
				size = 13,
				color = active and tokens.accent or tokens.textDim,
				weight = 12,
				zIndex = 4,
			})
		end
	end
	self._paint = paint

	local function search()
		local query = self._query
		local scored = {}
		if query == "" then
			-- Recent first, then everything else in registration order.
			local seen = {}
			for _, command in ipairs(self._recent) do
				table.insert(scored, { command = command, score = 1000 })
				seen[command] = true
			end
			for _, command in ipairs(self._commands) do
				if not seen[command] then
					table.insert(scored, { command = command, score = 0 })
				end
			end
		else
			for _, command in ipairs(self._commands) do
				local haystack = (command.Label or command.Name or "")
					.. (command.Section and (" " .. command.Section) or "")
					.. (command.Description and (" " .. command.Description) or "")
				local score = Util.fuzzyMatch(query, haystack)
				if score then
					table.insert(scored, { command = command, score = score })
				end
			end
			table.sort(scored, function(a, b)
				return a.score > b.score
			end)
		end

		table.clear(self._results)
		for index = 1, math.min(#scored, MAX_ROWS) do
			self._results[index] = scored[index]
		end
		self._highlight = math.clamp(self._highlight, 1, math.max(#self._results, 1))
		ensureRows(math.max(#self._results, 1))
		empty.Visible = #self._results == 0
		paint()
	end
	self._search = search

	--- Recomputes the visible list. Call after mutating command state.
	function self:Refresh()
		search()
		return self
	end

	-- Open / close -------------------------------------------------------
	local function layout()
		local rowCount = math.max(#self._results, 1)
		panel.Size = UDim2.fromOffset(440, 52 + rowCount * ROW_HEIGHT + 8)
	end
	self._layout = layout

	--- Opens the palette.
	function self:Open()
		if self._open then
			return self
		end
		self._open = true
		self._query = ""
		self._highlight = 1
		box.Text = ""
		search()
		layout()

		root.Visible = true
		panel.Size = UDim2.fromOffset(440, 52)
		panel.GroupTransparency = 1
		Motion.tween(panel, { GroupTransparency = 0 }, Motion.options("enter", { duration = 0.16 }))
		Motion.scale(panel, 0.97, { duration = 0.26, easing = "enterSnap" })
		Motion.tween(root, { BackgroundTransparency = tokens.scrimTransparency }, Motion.options("enter", { duration = 0.2 }))
		task.defer(function()
			if not self._open then
				return
			end
			layout()
			Motion.scale(panel, 1, { duration = 0.26, easing = "enterSnap" })
		end)
		box:CaptureFocus()
		return self
	end

	--- Closes the palette.
	function self:Close()
		if not self._open then
			return self
		end
		self._open = false
		if box:IsFocused() then
			box:ReleaseFocus()
		end
		Motion.tween(root, { BackgroundTransparency = 1 }, Motion.options("exit"))
		Motion.tween(panel, { GroupTransparency = 1 }, Motion.options("exit", {
			onComplete = function()
				root.Visible = false
			end,
		}))
		return self
	end

	function self:Toggle()
		if self._open then
			self:Close()
		else
			self:Open()
		end
		return self
	end

	function self:IsOpen(): boolean
		return self._open
	end

	runHighlighted = function()
		local result = self._results[self._highlight]
		if not result then
			return
		end
		local command = result.command
		-- Recents: most recent first, no duplicates, bounded.
		table.remove(self._recent, table.find(self._recent, command) or -1)
		table.insert(self._recent, 1, command)
		while #self._recent > RECENT_LIMIT do
			table.remove(self._recent)
		end

		self:Close()
		self.Ran:fire(command, self)
		Util.safeCall(command.Run, command, self)
	end

	box:GetPropertyChangedSignal("Text"):Connect(function()
		self._query = box.Text
		self._highlight = 1
		search()
		layout()
	end)

	-- Keyboard ------------------------------------------------------------
	local UserInputService = game:GetService("UserInputService")
	local modifier = Config.keybinds.commandPaletteModifier or Enum.KeyCode.LeftControl
	local key = Config.keybinds.commandPalette or Enum.KeyCode.K

	self._maid:add(UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == key and input:IsModifierKeyDown(modifier) then
			self:Toggle()
			return
		end
		if not self._open then
			return
		end
		local code = input.KeyCode
		if code == Enum.KeyCode.Down then
			self._highlight = math.min(self._highlight + 1, math.max(#self._results, 1))
			paint()
		elseif code == Enum.KeyCode.Up then
			self._highlight = math.max(self._highlight - 1, 1)
			paint()
		elseif code == Enum.KeyCode.Home then
			self._highlight = 1
			paint()
		elseif code == Enum.KeyCode.End then
			self._highlight = math.max(#self._results, 1)
			paint()
		elseif code == Enum.KeyCode.Return or code == Enum.KeyCode.KeypadEnter then
			runHighlighted()
		elseif code == Enum.KeyCode.Escape then
			self:Close()
		end
	end))

	self._maid:add(Theme.Changed:connect(function(next)
		tokens = next
		self._tokens = next
		panel.BackgroundColor3 = next.elevated
		box.TextColor3 = next.text
		box.PlaceholderColor3 = next.textDim
		empty.TextColor3 = next.textDim
		paint()
	end))

	if context.maid then
		context.maid:add(function()
			self:destroy()
		end)
	end

	return self
end

--- Registers additional commands after construction.
function CommandPalette:Add(commands: { any })
	for _, command in ipairs(commands or {}) do
		table.insert(self._commands, command)
	end
	return self
end

--- The command list, for hosts that want to render their own shortcut sheet.
function CommandPalette:List()
	return self._commands
end

function CommandPalette:destroy()
	self.Ran:destroy()
	self._maid:destroy()
	if self.Instance then
		Motion.cancelAll(self.Instance)
		self.Instance:Destroy()
		self.Instance = nil
	end
end

return CommandPalette
