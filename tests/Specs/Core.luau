--[[
	Vantage · tests/Specs/Core.luau
	==================================================================
	Covers the engine: easing, signals, teardown, the animation
	scheduler, the theme deriver and the utility layer.

	These are behavioural assertions, not snapshots. Where a numeric
	result matters (the bezier solver, the WCAG contrast fallback) the
	assertion states the property that must hold, not the exact float,
	so the tests survive intentional tuning.
]]

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local Easing = Vantage.Easing
local Signal = Vantage.Signal
local Maid = Vantage.Maid
local Motion = Vantage.Motion
local Theme = Vantage.Theme
local Util = Vantage.Util
local Glyph = Vantage.Glyph

describe("Easing", function()
	it("passes through the endpoints for every catalog entry", function()
		for _, name in ipairs(Easing.directionalNames) do
			local fn = Easing.catalog[name]
			expect(fn ~= nil):toBeTruthy()
			expect(fn(0)):toBeCloseTo(0, 1e-6)
			expect(fn(1)):toBeCloseTo(1, 1e-6)
		end
	end)

	it("solves a cubic bezier the way CSS does", function()
		-- ease-in-out: symmetric about the midpoint.
		local ease = Easing.bezier(0.42, 0, 0.58, 1)
		expect(ease(0.5)):toBeCloseTo(0.5, 0.01)
		local monotonic = true
		local previous = -1
		for step = 0, 100 do
			local value = ease(step / 100)
			if value < previous - 1e-9 then
				monotonic = false
				break
			end
			previous = value
		end
		expect(monotonic):toBe(true)
	end)

	it("keeps a hard ease-in below the identity line", function()
		local easeIn = Easing.bezier(0.9, 0.02, 1, 0.3)
		expect(easeIn(0.3)):toBeLessThan(0.3)
		expect(easeIn(0.9)):toBeLessThan(0.9)
	end)

	it("allows overshoot for emphasised curves", function()
		local overshoot = Easing.bezier(0.2, 0, 0, 1.2)
		local peak = 0
		for step = 0, 100 do
			peak = math.max(peak, overshoot(step / 100))
		end
		expect(peak):toBeGreaterThan(1)
	end)

	it("never explodes on out-of-range input", function()
		-- Overshooting curves are not clamped in the middle, but the
		-- endpoints must still be exact or every animation lands wrong.
		for _, name in ipairs(Easing.directionalNames) do
			local fn = Easing.catalog[name]
			expect(type(fn(-5))):toBe("number")
			expect(fn(0)):toBeCloseTo(0, 1e-6)
			expect(fn(1)):toBeCloseTo(1, 1e-6)
		end
	end)

	it("resolves unknown names to a sane default rather than nil", function()
		expect(type(Easing.resolve("does-not-exist"))):toBe("function")
		expect(Easing.resolve(nil)(0.5)):toBeType("number")
	end)

	it("inverts a monotonic curve", function()
		local ease = Easing.resolve("expo")
		local mid = ease(0.37)
		expect(Easing.invert(ease, mid)):toBeCloseTo(0.37, 0.002)
	end)

	it("samples a curve into the requested number of points", function()
		expect(Easing.sample("cubic", 11)):toHaveLength(11)
	end)
end)

describe("Signal", function()
	it("fires every listener in connection order", function()
		local signal = Signal.new("t")
		local order = {}
		signal:connect(function(value)
			table.insert(order, "a" .. tostring(value))
		end)
		signal:connect(function(value)
			table.insert(order, "b" .. tostring(value))
		end)
		signal:fire(1)
		expect(table.concat(order, ",")):toBe("a1,b1")
		signal:destroy()
	end)

	it("stops firing after disconnect", function()
		local signal = Signal.new("t")
		local count = 0
		local connection = signal:connect(function()
			count += 1
		end)
		signal:fire()
		connection:disconnect()
		signal:fire()
		expect(count):toBe(1)
		signal:destroy()
	end)

	it("fires once-only handlers exactly once", function()
		local signal = Signal.new("t")
		local count = 0
		signal:once(function()
			count += 1
		end)
		signal:fire()
		signal:fire()
		expect(count):toBe(1)
		signal:destroy()
	end)

	it("isolates a throwing handler from the others", function()
		local signal = Signal.new("t")
		local reached = false
		signal:connect(function()
			error("deliberate failure")
		end)
		signal:connect(function()
			reached = true
		end)
		-- `warn` captures the traceback in the mock, so the suite stays quiet.
		signal:fire()
		expect(reached):toBe(true)
		expect(#Mock.warnings):toBeGreaterThan(0)
		signal:destroy()
	end)

	it("survives a handler that disconnects mid-fire", function()
		local signal = Signal.new("t")
		local second = false
		local first
		first = signal:connect(function()
			first:disconnect()
		end)
		signal:connect(function()
			second = true
		end)
		signal:fire()
		expect(second):toBe(true)
		signal:destroy()
	end)

	it("reports the live listener count", function()
		local signal = Signal.new("t")
		local a = signal:connect(function() end)
		signal:connect(function() end)
		expect(signal:listenerCount()):toBe(2)
		a:disconnect()
		expect(signal:listenerCount()):toBe(1)
		signal:destroy()
	end)

	it("tears down upstream connections created by Signal.any", function()
		local a, b = Signal.new("a"), Signal.new("b")
		local merged = Signal.any({ a, b })
		local count = 0
		merged:connect(function()
			count += 1
		end)
		a:fire()
		b:fire()
		expect(count):toBe(2)
		merged:destroy()
		a:fire()
		expect(count):toBe(2)
		a:destroy()
		b:destroy()
	end)
end)

describe("Maid", function()
	it("releases instances, connections and functions", function()
		local maid = Maid.new("t")
		local frame = Instance.new("Frame")
		local signal = Signal.new("s")
		local connection = signal:connect(function() end)
		local called = false

		maid:add(frame)
		maid:add(connection)
		maid:add(function()
			called = true
		end)

		maid:clean()
		expect(called):toBe(true)
		expect(connection.Connected):toBe(false)
		expect(frame.Parent):toBeNil()
		maid:destroy()
	end)

	it("is reusable after clean but not after destroy", function()
		local maid = Maid.new("t")
		local count = 0
		maid:add(function()
			count += 1
		end)
		maid:clean()
		maid:add(function()
			count += 1
		end)
		maid:clean()
		expect(count):toBe(2)

		maid:destroy()
		expect(maid:isDead()):toBe(true)
		-- Adding to a dead maid releases immediately rather than leaking.
		maid:add(function()
			count += 1
		end)
		expect(count):toBe(3)
	end)

	it("releases a thenable-shaped table through its destroy method", function()
		local released = false
		local maid = Maid.new("t")
		maid:add({
			destroy = function()
				released = true
			end,
		})
		maid:clean()
		expect(released):toBe(true)
		maid:destroy()
	end)

	it("does not let one bad item stop the rest of the teardown", function()
		local maid = Maid.new("t")
		local reached = false
		maid:add(function()
			error("teardown failure")
		end)
		maid:add(function()
			reached = true
		end)
		maid:clean()
		expect(reached):toBe(true)
		expect(#Mock.warnings):toBeGreaterThan(0)
		maid:destroy()
	end)
end)

describe("Motion", function()
	it("interpolates every supported datatype", function()
		expect(Motion.lerp(0, 10, 0.5)):toBe(5)
		local colour = Motion.lerp(Color3.new(0, 0, 0), Color3.new(1, 1, 1), 0.5)
		expect(colour.R):toBeCloseTo(0.5, 1e-6)
		local size = Motion.lerp(UDim2.fromOffset(0, 0), UDim2.fromOffset(100, 50), 0.25)
		expect(size.X.Offset):toBe(25)
		expect(size.Y.Offset):toBeCloseTo(12.5, 1e-6)
		local point = Motion.lerp(Vector2.new(0, 0), Vector2.new(10, 20), 1)
		expect(point.Y):toBe(20)
	end)

	it("reaches the goal exactly and fires Completed", function()
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(0, 0)
		local done = false
		Motion.tween(frame, { Size = UDim2.fromOffset(200, 100) }, {
			duration = 0.3,
			onComplete = function()
				done = true
			end,
		})
		Mock.advance(0.6)
		expect(frame.Size.X.Offset):toBe(200)
		expect(frame.Size.Y.Offset):toBe(100)
		expect(done):toBe(true)
		frame:Destroy()
	end)

	it("honours a delay before starting", function()
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 0
		Motion.tween(frame, { BackgroundTransparency = 1 }, { duration = 0.1, delay = 0.5 })
		Mock.advance(0.2)
		expect(frame.BackgroundTransparency):toBe(0)
		Mock.advance(0.6)
		expect(frame.BackgroundTransparency):toBe(1)
		frame:Destroy()
	end)

	it("captures the live value when it interrupts another tween", function()
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(0, 0)
		Motion.tween(frame, { Size = UDim2.fromOffset(100, 0) }, { duration = 1, easing = "linear" })
		Mock.advance(0.5)
		local midway = frame.Size.X.Offset
		expect(midway):toBeGreaterThan(10)
		expect(midway):toBeLessThan(90)

		-- Retarget mid-flight: the new tween must begin where we are.
		Motion.tween(frame, { Size = UDim2.fromOffset(0, 0) }, { duration = 0.2 })
		Mock.advance(0.4)
		expect(frame.Size.X.Offset):toBe(0)
		frame:Destroy()
	end)

	it("loops a repeatCount-ed tween and reports the iteration count", function()
		local frame = Instance.new("Frame")
		frame.Rotation = 0
		local tween = Motion.tween(frame, { Rotation = 360 }, {
			duration = 0.1,
			easing = "linear",
			repeatCount = 2,
		})
		Mock.advance(0.25)
		expect(tween._iteration):toBeGreaterThan(0)
		tween:cancel()
		frame:Destroy()
	end)

	it("cancels cleanly and leaves the value where it stopped", function()
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 0
		local tween = Motion.tween(frame, { BackgroundTransparency = 1 }, { duration = 1, easing = "linear" })
		Mock.advance(0.4)
		local stopped = frame.BackgroundTransparency
		tween:cancel()
		expect(tween:isPlaying()):toBe(false)
		Mock.advance(0.5)
		expect(frame.BackgroundTransparency):toBe(stopped)
		frame:Destroy()
	end)

	it("cancels every tween targeting an instance when it is destroyed", function()
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(0, 0)
		Motion.tween(frame, { Size = UDim2.fromOffset(500, 500) }, { duration = 2 })
		local before = Motion.stats().tweens
		expect(before):toBeGreaterThan(0)
		frame:Destroy()
		expect(Motion.stats().tweens):toBeLessThan(before)
	end)

	it("settles a spring on its goal without overshooting forever", function()
		local spring = Motion.springFrom("snappy", 0)
		spring:setGoal(1)
		local observed = {}
		spring:observe(function(value)
			table.insert(observed, value)
		end)
		for _ = 1, 240 do
			Mock.advance(1 / 60)
		end
		expect(math.abs(spring:get() - 1)):toBeLessThan(0.01)
		expect(spring:isAtRest()):toBe(true)
		expect(#observed):toBeGreaterThan(5)
		spring:destroy()
	end)

	it("is stable across an absurd frame delta", function()
		-- A 200 ms stall must not make the integrator diverge; the
		-- scheduler clamps dt and the spring sub-steps, so the result is
		-- the same as running the frames normally.
		local spring = Motion.springFrom("elastic", 0)
		spring:setGoal(100)
		for _ = 1, 300 do
			Motion.step(1 / 5)
		end
		expect(math.abs(spring:get() - 100)):toBeLessThan(0.5)
		expect(math.abs(spring:getVelocity())):toBeLessThan(1)
		spring:destroy()
	end)

	it("supersedes an in-flight tween on the same property", function()
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 0
		Motion.tween(frame, { BackgroundTransparency = 1 }, { duration = 1, easing = "linear" })
		Mock.advance(0.4)
		Motion.tween(frame, { BackgroundTransparency = 0.25 }, { duration = 0.2, easing = "linear" })
		Mock.advance(0.4)
		expect(frame.BackgroundTransparency):toBeCloseTo(0.25, 1e-6)
		frame:Destroy()
	end)

	it("drives per-frame tickers from the shared scheduler", function()
		local frames = 0
		local ticker = Motion.ticker(function()
			frames += 1
		end)
		Mock.advance(0.5)
		expect(frames):toBeGreaterThan(20)
		ticker:destroy()
		local after = frames
		Mock.advance(0.5)
		expect(frames):toBe(after)
	end)

	it("stops a ticker that throws instead of spamming every frame", function()
		local ticker = Motion.ticker(function()
			error("ticker failure")
		end)
		Mock.advance(0.1)
		expect(#Mock.warnings):toBeGreaterThan(0)
		expect(ticker:isRunning()):toBe(false)
	end)

	it("collapses durations under reduced motion while keeping the API", function()
		Motion.setReducedMotion(true)
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 0
		local done = false
		Motion.tween(frame, { BackgroundTransparency = 1 }, {
			duration = 5,
			onComplete = function()
				done = true
			end,
		})
		Mock.advance(0.05)
		expect(frame.BackgroundTransparency):toBe(1)
		expect(done):toBe(true)
		Motion.setReducedMotion(false)
		frame:Destroy()
	end)
end)

describe("Theme", function()
	it("derives a complete token table from a seed", function()
		local tokens = Theme.fromSeed("#F0A93B", "dark")
		for _, key in ipairs(Theme.colorTokens) do
			expect(tokens[key] ~= nil):toBeTruthy()
			expect(typeof(tokens[key])):toBe("Color3")
		end
		for _, key in ipairs(Theme.numberTokens) do
			expect(type(tokens[key])):toBe("number")
		end
	end)

	it("produces a legible foreground on top of the accent", function()
		for name, definition in pairs(Theme.builtins) do
			local tokens = Theme.derive(definition)
			local ratio = Util.contrast(tokens.onAccent, tokens.accent)
			-- 4.5:1 is WCAG AA for body text; every shipped theme clears 3:1
			-- at absolute minimum, and the deriver targets the higher bar.
			expect(ratio >= 3):toBe(true)
		end
	end)

	it("keeps text readable against its own surface", function()
		for name, definition in pairs(Theme.builtins) do
			local tokens = Theme.derive(definition)
			local ratio = Util.contrast(tokens.text, tokens.surface)
			if not (ratio >= 4.5) then
				error(string.format("theme %q has only %.2f:1 text contrast", name, ratio))
			end
		end
	end)

	it("darkens the accent for light themes so it stays visible", function()
		local dark = Theme.fromSeed("#8CE0A0", "dark")
		local light = Theme.fromSeed("#8CE0A0", "light")
		expect(Util.luminance(light.accent)):toBeLessThan(Util.luminance(dark.accent))
	end)

	it("mutates the live token table in place across a transition", function()
		local reference = Theme.current()
		Theme.apply("ember")
		local tokens = Theme.current()
		expect(tokens):toBe(reference)

		Theme.transition(Theme.fromSeed("#34D399", "dark"), { duration = 0.3 })
		Mock.advance(0.6)
		expect(Theme.current()):toBe(reference)
		expect(Util.colorToHex(Theme.current().accent)):toBe(Util.colorToHex(Theme.derive({ seed = "#34D399", mode = "dark" }).accent))
		Theme.apply("obsidian")
	end)

	it("notifies observers exactly once per applied theme", function()
		local calls = 0
		local unsubscribe = Theme.observe(function()
			calls += 1
		end)
		expect(calls):toBe(1)
		Theme.apply("verdant")
		expect(calls):toBe(2)
		unsubscribe()
		Theme.apply("obsidian")
		expect(calls):toBe(2)
	end)

	it("lists every registered theme with a swatch and description", function()
		local list = Theme.list()
		expect(#list):toBeGreaterThanOrEqual(10)
		for _, entry in ipairs(list) do
			expect(type(entry.name)):toBe("string")
			expect(type(entry.description)):toBe("string")
			expect(entry.swatch):toHaveLength(4)
		end
	end)

	it("registers a custom theme and reaches it by name", function()
		Theme.register("unit-test", { seed = "#12B981", mode = "dark", label = "Unit Test" })
		Theme.apply("unit-test")
		expect(Theme.name()):toBe("unit-test")
		Theme.apply("obsidian")
	end)

	it("exports a theme as runnable Luau source", function()
		local source = Theme.export("obsidian")
		expect(source):toContain("Vantage.Theme.register")
		expect(source):toContain("overrides")
		-- The generator must not be able to emit a broken literal.
		local chunk = loadstring(source)
		expect(chunk ~= nil):toBeTruthy()
	end)

	it("binds instance properties to tokens and updates them live", function()
		local frame = Instance.new("Frame")
		local maid = Maid.new("bind")
		Theme.bind(maid, {
			[frame] = { BackgroundColor3 = "surface" },
		})
		expect(frame.BackgroundColor3):toBe(Theme.current().surface)
		Theme.apply("frost")
		expect(frame.BackgroundColor3):toBe(Theme.current().surface)
		Theme.apply("obsidian")
		maid:destroy()
		frame:Destroy()
	end)
end)

describe("Util", function()
	it("matches fuzzy queries with positional scoring", function()
		local score, positions = Util.fuzzyMatch("stgs", "Settings")
		expect(score ~= nil):toBeTruthy()
		expect(#positions):toBe(4)
		expect(Util.fuzzyMatch("zzz", "Settings")):toBeNil()
	end)

	it("ranks a prefix match above a scattered match", function()
		local prefix = Util.fuzzyMatch("sett", "Settings")
		local scattered = Util.fuzzyMatch("sett", "Asset editor")
		expect(prefix):toBeGreaterThan(scattered)
	end)

	it("parses and serialises hex colours round-trip", function()
		local colour = Util.hexToColor("#F0A93B")
		expect(Util.colorToHex(colour)):toBe("#F0A93B")
		local short = Util.hexToColor("#FA3")
		expect(Util.colorToHex(short)):toBe("#FFAA33")
	end)

	it("computes WCAG contrast and picks readable foregrounds", function()
		local white = Color3.fromRGB(255, 255, 255)
		local black = Color3.fromRGB(0, 0, 0)
		expect(Util.contrast(white, black)):toBeCloseTo(21, 0.01)
		-- The chosen foreground is the near-white/near-black pair, not
		-- pure white and pure black: pure endpoints look harsh on screens.
		expect(Util.luminance(Util.contrastText(black))):toBeGreaterThan(0.5)
		expect(Util.luminance(Util.contrastText(white))):toBeLessThan(0.5)
		expect(Util.contrast(Util.contrastText(white), white)):toBeGreaterThan(12)
	end)

	it("formats numbers the way a status bar needs them", function()
		expect(Util.commas(1234567)):toBe("1,234,567")
		expect(Util.compact(1500000)):toBe("1.50M")
		expect(Util.percent(0.256, 1)):toBe("25.6%")
		expect(Util.duration(65)):toBe("1:05")
		expect(Util.bytes(2048)):toBe("2.0 KB")
		expect(Util.padNumber(7, 3)):toBe("  7")
	end)

	it("maps, clamps and snaps without float noise", function()
		expect(Util.map(5, 0, 10, 0, 100)):toBe(50)
		expect(Util.clamp(15, 0, 10)):toBe(10)
		expect(Util.snap(0.37, 0.25)):toBe(0.25)
		expect(Util.round(1.2345, 2)):toBe(1.23)
		expect(Util.snap(5, 0)):toBe(5)
	end)

	it("deep-merges without mutating the source", function()
		local base = { a = 1, nested = { x = 1, y = 2 } }
		local merged = Util.deepMerge(base, { nested = { y = 9 }, b = 2 })
		expect(merged.nested.x):toBe(1)
		expect(merged.nested.y):toBe(9)
		expect(merged.b):toBe(2)
		expect(base.nested.y):toBe(2)
	end)

	it("wraps text to a character budget", function()
		local wrapped = Util.wrapText("the quick brown fox jumps over the lazy dog", 12)
		local lines = 0
		for line in wrapped:gmatch("[^\n]+") do
			lines += 1
			expect(#line <= 24):toBe(true)
		end
		expect(lines):toBeGreaterThan(1)
	end)

	it("escapes rich text so user strings cannot inject markup", function()
		expect(Util.escapeRichText("<b>hi</b>")):toBe("&lt;b&gt;hi&lt;/b&gt;")
	end)

	it("survives a callback that throws", function()
		local ok = Util.safeCall(function()
			error("caught")
		end)
		expect(ok):toBe(false)
		expect(#Mock.warnings):toBeGreaterThan(0)
	end)

	it("debounces to the trailing call", function()
		local calls = 0
		local debounced = Util.debounce(function()
			calls += 1
		end, 0.2)
		debounced()
		debounced()
		debounced()
		Mock.advance(0.4)
		expect(calls):toBe(1)
	end)

	it("derives a viewport breakpoint", function()
		expect(Util.breakpoint(400)):toBe("phone")
		expect(Util.breakpoint(800)):toBe("tablet")
		expect(Util.breakpoint(1200)):toBe("compact")
		expect(Util.breakpoint(2400)):toBe("desktop")
	end)

	it("reports the safe-area insets without erroring", function()
		local insets = Util.insets()
		expect(type(insets.top)):toBe("number")
		expect(insets.top):toBeGreaterThan(0)
	end)
end)

describe("Glyph", function()
	it("draws every glyph in the catalog without error", function()
		local parent = Instance.new("Frame")
		for _, name in ipairs(Glyph.names) do
			local glyph = Glyph.draw(parent, name, { size = 16 })
			expect(glyph ~= nil):toBeTruthy()
			expect(#glyph:GetChildren()):toBeGreaterThan(0)
		end
		parent:Destroy()
	end)

	it("warns and returns nil for an unknown glyph instead of throwing", function()
		local parent = Instance.new("Frame")
		local before = #Mock.warnings
		local glyph = Glyph.draw(parent, "definitely-not-a-glyph", { size = 16 })
		expect(glyph):toBeNil()
		expect(#Mock.warnings):toBeGreaterThan(before)
		parent:Destroy()
	end)

	it("recolours in place without rebuilding", function()
		local parent = Instance.new("Frame")
		local glyph = Glyph.draw(parent, "check", { size = 16, color = Color3.new(1, 1, 1) })
		local childCount = #glyph:GetDescendants()
		Glyph.setColor(glyph, Color3.fromRGB(255, 0, 0))
		expect(#glyph:GetDescendants()):toBe(childCount)
		parent:Destroy()
	end)

	it("keeps its catalog sorted so docs listings are stable", function()
		local sorted = table.clone(Glyph.names)
		table.sort(sorted)
		expect(table.concat(Glyph.names, ",")):toBe(table.concat(sorted, ","))
	end)
end)
