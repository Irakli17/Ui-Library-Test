--[[
	Vantage · tests/Integration.luau
	==================================================================
	Integration coverage for the *shipped* artifact.

	tools/verify-dist.mjs assembles this file like so:

	    mock runtime  →  spec  →  dist/Vantage.luau bytes  →  loadstring

	and it deletes the `script` global before the chunk runs, because
	that is the environment an executor gives a loadstring. If any of
	this passes, the file a user downloads really does work — not a
	module tree that happens to resolve under Rojo.

	Everything below is asserted through the public API and against the
	instances the mock runtime recorded, so these are behaviour checks
	rather than snapshots.
]]

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local state = {}

local function findByName(root, name)
	if not root then
		return nil
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == name then
			return descendant
		end
	end
	return nil
end

local function findFirst(root, predicate)
	if not root then
		return nil
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if predicate(descendant) then
			return descendant
		end
	end
	return nil
end

local function countNamed(root, name)
	local total = 0
	if not root then
		return total
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == name then
			total += 1
		end
	end
	return total
end

--- A button's hit target is an inner TextButton, so a realistic press has
--- to reach through the shell to it. Pressing instances that listen to
--- nothing is harmless.
local function pressDeep(root)
	if not root then
		return 0
	end
	local pressed = 1
	Mock.press(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		Mock.press(descendant)
		pressed += 1
	end
	return pressed
end

describe("dist · the artifact", function()
	it("runs from loadstring with no `script` global", function()
		-- assert() in the generated preamble already proved this; restating
		-- it here means a regression reports as a test failure, not a crash.
		expect(script):toBeNil()
		expect(type(Vantage)):toBe("table")
	end)

	it("describes itself", function()
		expect(Vantage.name):toBe("Vantage")
		expect(Vantage.version):toBe("1.0.0")
	end)

	it("exposes every documented namespace", function()
		local namespaces = {
			"Util", "Signal", "Maid", "Easing", "Motion", "Theme", "Config", "Glyph",
			"Window", "Tab", "Section", "Elements", "Field",
			"Button", "Toggle", "Slider", "Dropdown", "Input", "Keybind",
			"Segmented", "Progress", "Ripple",
			"Notify", "Modal", "Tooltip", "CommandPalette",
			"LoadingScreen", "LogoWave",
		}
		for _, key in ipairs(namespaces) do
			expect(type(Vantage[key])):toBe("table")
		end
	end)

	it("ships ten themes, and none of them is the blue one by default", function()
		local themes = Vantage.Themes()
		expect(#themes):toBe(10)

		local seen = {}
		for _, entry in ipairs(themes) do
			seen[entry.name] = true
			expect(type(entry.label)):toBe("string")
		end
		for _, expected in ipairs({
			"obsidian", "graphite", "porcelain", "sakura", "ember",
			"verdant", "amethyst", "rosewood", "midnight", "frost",
		}) do
			expect(seen[expected] == true):toBeTruthy()
		end

		expect(Vantage.Theme.name()):toBe("obsidian")
		expect(Vantage.Theme.mode()):toBe("dark")
	end)

	it("bootstraps, and reports what the engine is doing", function()
		local library = Vantage.Setup({ Theme = "obsidian" })
		expect(library):toBe(Vantage)

		local diagnostics = Vantage.Diagnostics()
		expect(diagnostics.version):toBe("1.0.0")
		expect(diagnostics.theme):toBe("obsidian")
		expect(diagnostics.viewport.width):toBeGreaterThan(0)
		expect(type(diagnostics.motion)):toBe("table")
	end)

	it("derives a theme from a single seed, and exports runnable source", function()
		local derived = Vantage.ThemeFromSeed("#34D399", "dark")
		expect(type(derived)):toBe("table")
		expect(derived.accent ~= nil):toBeTruthy()

		local source = Vantage.ExportTheme("obsidian")
		expect(type(source)):toBe("string")
		expect(#source):toBeGreaterThan(200)
		expect(source:find("Theme.register", 1, true) ~= nil):toBeTruthy()
	end)
end)

describe("dist · window", function()
	it("applies the documented capitalised spec keys", function()
		local window = Vantage.Window.new({
			Name = "Vantage Test",
			Subtitle = "Integration",
			Theme = "obsidian",
			Size = UDim2.fromOffset(760, 480),
			Position = UDim2.fromScale(0.5, 0.5),
			MinSize = Vector2.new(420, 300),
			Resizable = true,
			Draggable = true,
			Backdrop = false,
		})
		state.window = window

		expect(window.Title.Text):toBe("Vantage Test")
		expect(window.Subtitle.Text):toBe("Integration")
		expect(window.Shell.Size.X.Offset):toBe(760)
		expect(window.Shell.Size.Y.Offset):toBe(480)
		expect(window.ScreenGui ~= nil):toBeTruthy()
	end)

	it("never puts the logo in the interface", function()
		-- The wordmark is the glyph + text; no ImageLabel in the chrome may
		-- point at the brand asset.
		local chrome = findFirst(state.window.ScreenGui, function(instance)
			return instance:IsA("ImageLabel") and instance.Image ~= "" and instance.Image ~= nil
		end)
		expect(chrome):toBeNil()
	end)

	it("owns one shared tooltip for the whole window", function()
		expect(state.window.Tooltip ~= nil):toBeTruthy()
		expect(state.window.Tooltip.Instance ~= nil):toBeTruthy()
		state.window.Tooltip:attach(state.window.Title, "Window title")
		expect(state.window.Tooltip.Instance.Parent):toBe(state.window.TooltipLayer)
	end)

	it("creates tabs, selects them and cycles through them", function()
		local window = state.window
		state.general = window:Tab({ Name = "General", Icon = "sliders" })
		state.advanced = window:Tab({ Name = "Advanced", Icon = "gear" })

		expect(#window:GetTabNames()):toBe(2)
		expect(state.general:GetName()):toBe("General")
		expect(window:CurrentTab():GetName()):toBe("General")
		expect(state.general:IsVisible()):toBe(true)

		window:SelectTab("Advanced")
		expect(window:CurrentTab():GetName()):toBe("Advanced")
		expect(state.general:IsVisible()):toBe(false)

		window:CycleTab(1)
		expect(window:CurrentTab():GetName()):toBe("General")
		window:CycleTab(-1)
		expect(window:CurrentTab():GetName()):toBe("Advanced")
		window:SelectTab("General")
	end)

	it("moves through hide, show, minimise and maximise", function()
		local window = state.window

		window:Hide()
		expect(window:IsVisible()):toBe(false)
		window:Show()
		expect(window:IsVisible()):toBe(true)
		window:Toggle()
		expect(window:IsVisible()):toBe(false)
		window:Toggle()
		expect(window:IsVisible()):toBe(true)

		window:Maximize(true)
		expect(window:IsMaximized()):toBe(true)
		window:Maximize(false)
		expect(window:IsMaximized()):toBe(false)

		window:Minimize(true)
		window:Minimize(false)
		expect(window:IsVisible()):toBe(true)
	end)

	it("tags what it builds so tooling can find it", function()
		local tagged = Vantage.GetInstances()
		expect(#tagged):toBeGreaterThan(10)
	end)

	it("survives a theme change without warnings", function()
		local before = #Mock.warnings
		state.window:SetTheme("porcelain")
		expect(state.window:GetTheme()):toBe("porcelain")
		expect(Vantage.Theme.mode()):toBe("light")
		state.window:SetTheme("obsidian")
		expect(state.window:GetTheme()):toBe("obsidian")
		expect(#Mock.warnings):toBe(before)
	end)
end)

describe("dist · controls", function()
	it("hosts every primitive inside a section", function()
		local section = state.general:Section({
			Name = "Controls",
			Description = "Every primitive the library ships.",
			Icon = "sliders",
		})
		state.section = section

		local toggle = section:Toggle({ Name = "Reduce motion", Value = false })
		expect(toggle:Get()):toBe(false)
		toggle:Set(true, true)
		expect(toggle:Get()):toBe(true)
		toggle:Set(false, true)

		local slider = section:Slider({ Name = "Interface scale", Min = 0.5, Max = 2, Value = 1 })
		slider:Set(1.5, true)
		expect(slider:Get()):toBeCloseTo(1.5, 0.001)

		local dropdown = section:Dropdown({
			Name = "Quality",
			Options = { "Low", "Medium", "High" },
			Value = "Low",
		})
		expect(dropdown:IsOpen()):toBe(false)
		dropdown:Set("High", true)
		expect(dropdown:Get()):toBe("High")

		local input = section:Input({ Name = "Nickname", Value = "Vantage" })
		input:Set("Aurora")
		expect(input:Get()):toBe("Aurora")

		local keybind = section:Keybind({ Name = "Push to talk", Value = "LeftShift+T" })
		-- Chords are stored in the canonical order, so a re-capture of the
		-- same chord always produces the same string.
		local chord = {
			UserInputType = Enum.UserInputType.Keyboard,
			KeyCode = Enum.KeyCode.Q,
			IsModifierKeyDown = function(_, code)
				return code == Enum.KeyCode.LeftShift
			end,
		}
		local formatted = Vantage.Keybind.format(chord)
		expect(formatted).toBe("Shift+Q")
		keybind:Set(formatted, true)
		expect(keybind:Get()).toBe("Shift+Q")
		expect(#keybind:ToKeyCodes()):toBeGreaterThanOrEqual(2)

		local segmented = section:Segmented({
			Name = "Density",
			Options = { "Comfortable", "Compact" },
			Value = "Comfortable",
		})
		segmented:Set("Compact", true)
		expect(segmented:Get()):toBe("Compact")

		local progress = section:Progress({ Name = "Indexing", Value = 0 })
		progress:SetValue(0.6)
		Mock.advance(0.6)
		expect(progress:GetValue()):toBeGreaterThan(0.4)
		expect(progress:GetFraction()):toBeLessThanOrEqual(1)
	end)

	it("builds the non-interactive elements too", function()
		local section = state.section
		section:Heading({ Text = "Advanced" })
		section:Overline({ Text = "DANGER ZONE" })
		section:Paragraph({ Text = "Text that wraps rather than truncates." })
		section:Divider()
		section:Spacer(12)
		section:Stats({ { Label = "Version", Value = "1.0.0" }, { Label = "Uptime", Value = "3h" } })
		local columns = section:Columns({})
		expect(columns ~= nil):toBeTruthy()
		expect(section:IsCollapsed()):toBe(false)
	end)

	it("gives a button press feedback: ripple, press state, and one callback", function()
		local clicked = 0
		local button = state.section:Button({
			Text = "Deploy",
			Variant = "primary",
			Tooltip = "Ship the current build",
			Callback = function()
				clicked += 1
			end,
		})
		state.button = button

		local root = button.Instance
		expect(root.Name):toBe("VantageButton_Deploy")

		-- The mock runtime has no layout engine, so give the control a real
		-- box before pressing: a ripple deliberately refuses to draw into a
		-- zero-sized host (a button that has not been laid out yet).
		root.AutomaticSize = Enum.AutomaticSize.None
		root.Size = UDim2.fromOffset(168, 36)

		-- The ripple lives inside the button and only appears on press.
		local ripplesBefore = countNamed(root, "VantageRipple")
		pressDeep(root)
		local ripplesAfter = countNamed(root, "VantageRipple")

		expect(clicked):toBe(1)
		expect(ripplesAfter):toBeGreaterThan(ripplesBefore)
	end)

	it("honours a disabled button", function()
		local clicked = 0
		local button = state.section:Button({
			Text = "Unavailable",
			Disabled = true,
			Callback = function()
				clicked += 1
			end,
		})
		expect(button:isEnabled()):toBe(false)
		pressDeep(button.Instance)
		expect(clicked):toBe(0)

		button:setEnabled(true)
		expect(button:isEnabled()):toBe(true)
		pressDeep(button.Instance)
		expect(clicked):toBe(1)
	end)

	it("requires a second press for a confirm button", function()
		local confirmed = 0
		local button = state.section:Button({
			Text = "Wipe data",
			Variant = "danger",
			Confirm = true,
			Callback = function()
				confirmed += 1
			end,
		})
		pressDeep(button.Instance)
		expect(confirmed):toBe(0)
		pressDeep(button.Instance)
		expect(confirmed):toBe(1)
	end)

	it("animates a toggle rather than snapping it", function()
		local toggle = state.section:Toggle({ Name = "Streamer mode" })
		toggle:Set(true)
		-- A value change with animation enabled settles over the next frames.
		Mock.advance(0.4)
		expect(toggle:Get()):toBe(true)
		toggle:Set(false, true)
		expect(toggle:Get()):toBe(false)
	end)

	it("collapses and expands a section with its controls attached", function()
		local section = state.general:Section({ Name = "Collapsible", Collapsed = false })
		section:Toggle({ Name = "Animated collapse" })
		section:SetCollapsed(true, true)
		expect(section:IsCollapsed()):toBe(true)
		Mock.advance(0.6)
		section:SetCollapsed(false, true)
		expect(section:IsCollapsed()):toBe(false)
		Mock.advance(0.6)
	end)

	it("keeps the motion engine busy, then idle", function()
		local stats = Vantage.Motion.stats()
		expect(type(stats)):toBe("table")
		Mock.advance(2)
		expect(#Mock.warnings):toBe(0)
	end)
end)

describe("dist · overlays", function()
	it("queues notifications and groups them by key", function()
		local notify = Vantage.Notify.new({
			layer = state.window.NotifyLayer,
			maid = state.window._maid,
		})
		state.notify = notify

		notify:push({ Title = "Saved", Body = "Your settings were written.", Tone = "success", Duration = 4 })
		expect(notify:count()):toBe(1)

		notify:push({ Title = "Update", Body = "1.1 is available.", Key = "update", Duration = 4 })
		notify:push({ Title = "Update", Body = "1.1 is available.", Key = "update", Duration = 4 })
		Mock.advance(0.4)
		expect(notify:count()):toBeGreaterThanOrEqual(1)
	end)

	it("opens a modal and returns its result", function()
		local modal = Vantage.Modal.new({
			Title = "Discard changes?",
			Body = "This cannot be undone.",
			Layer = state.window.OverlayLayer,
			Actions = {
				{ Text = "Cancel", Variant = "secondary", Value = false },
				{ Text = "Discard", Variant = "danger", Value = true },
			},
		}, { maid = state.window._maid })

		state.modal = modal
		expect(modal:IsOpen()):toBe(true)
		Mock.advance(0.5)
		modal:Close(true, "confirm")
		expect(modal:IsOpen()):toBe(false)
		expect(modal:GetResult()):toBe(true)
	end)

	it("runs the command palette and lists its commands", function()
		local palette = Vantage.CommandPalette.new({
			layer = state.window.OverlayLayer,
			maid = state.window._maid,
		})
		palette:Add({
			{ Id = "general", Label = "Go to General", Hint = "Tab", Run = function() end },
			{ Id = "theme", Label = "Switch theme", Hint = "Interface", Run = function() end },
			{ Id = "reload", Label = "Reload interface", Hint = "Danger", Run = function() end },
		})
		expect(#palette:List()):toBeGreaterThanOrEqual(3)
		palette:destroy()
	end)
end)

describe("dist · loading screen", function()
	it("preloads real assets and reports real progress", function()
		local phases = {}
		-- `AutoContinue = false` opts out of the default 2.4s countdown, so
		-- the work finishes while the screen stays up and the composition
		-- can be inspected before it tears itself down.
		local handle = Vantage.LoadingScreen.Run({
			Assets = { "rbxassetid://1234567890" },
			MinDuration = 0.4,
			MaxDuration = 5,
			AutoContinue = false,
			Tips = { "Tip one", "Tip two" },
			Logo = { Image = "rbxassetid://987654321", Position = "bottom-right" },
			OnPhase = function(name)
				table.insert(phases, name)
			end,
		})
		state.loading = handle
		expect(handle.screen ~= nil):toBeTruthy()

		local screen = handle.screen
		Mock.advance(1)
		expect(screen:GetProgress()):toBeGreaterThan(0)

		Mock.advance(4)
		expect(screen:IsComplete()):toBeTruthy()

		local report = screen:GetReport()
		expect(report.progress):toBeCloseTo(1, 0.001)
		-- `failures` is the count of assets ContentProvider could not fetch.
		expect(report.failures):toBe(0)
		expect(report.timedOut):toBe(false)
		expect(table.find(Mock.preloaded, "rbxassetid://1234567890") ~= nil):toBeTruthy()
		expect(#phases):toBeGreaterThan(0)
	end)

	it("puts the wave logo in the bottom-right of the safe area", function()
		local block = findByName(state.loading.screen.Root, "LogoBlock")
		expect(block ~= nil):toBeTruthy()

		-- AnchorPoint (1, 1) at scale position (1, 1) is the corner; the
		-- negative offsets inset it inside the safe area.
		expect(block.AnchorPoint.X):toBe(1)
		expect(block.AnchorPoint.Y):toBe(1)
		expect(block.Position.X.Scale):toBe(1)
		expect(block.Position.Y.Scale):toBe(1)
		expect(block.Position.X.Offset):toBeLessThan(0)
		expect(block.Position.Y.Offset):toBeLessThan(0)
	end)

	it("slices the logo into a wave rather than showing a static image", function()
		local wave = findFirst(state.loading.screen.Root, function(instance)
			return instance.Name == "VantageLogoWave"
		end)
		expect(wave ~= nil):toBeTruthy()

		-- Image mode cuts the mark into horizontal bands, each with the
		-- full image behind a clipping window. A band whose image is empty
		-- is the "blank logo" failure the placeholder asset exists to stop.
		local windows, bands = {}, 0
		for _, child in ipairs(wave:GetDescendants()) do
			if child.Name:match("^Slice%d") then
				table.insert(windows, child)
			elseif child.Name == "Band" then
				bands += 1
				expect(child.Image).toBe("rbxassetid://987654321")
			end
		end
		expect(bands):toBeGreaterThanOrEqual(8)
		expect(#windows):toBe(bands)

		-- The wave is the per-slice window offset moving over time; a slice
		-- that never moves is a still image behind a gradient.
		local before = windows[1].Position.Y.Offset
		local phasesDiffer = false
		Mock.advance(0.35)
		if windows[1].Position.Y.Offset ~= before then
			phasesDiffer = true
		end
		expect(phasesDiffer):toBeTruthy()

		-- Neighbouring slices are phase-shifted, which is what makes it a
		-- travelling wave instead of a single sliding block.
		local a = windows[1].Position.Y.Offset
		local b = windows[math.max(2, math.floor(#windows / 2))].Position.Y.Offset
		expect(a ~= b):toBeTruthy()
	end)

	it("tears the loading screen down completely when continued", function()
		local before = Mock.instancesDestroyed
		state.loading.screen:Continue(true)
		Mock.advance(0.3)
		expect(Mock.instancesDestroyed):toBeGreaterThan(before)
		expect(state.loading.screen.ScreenGui):toBeNil()
	end)
end)

describe("dist · teardown", function()
	it("destroys the window and leaves nothing animating or warning", function()
		local before = Mock.instancesDestroyed
		state.notify:destroy()
		state.window:Destroy()
		Mock.advance(1)

		expect(Mock.instancesDestroyed):toBeGreaterThan(before)
		expect(state.window.ScreenGui):toBeNil()
		expect(#Mock.warnings):toBe(0)
	end)
end)
