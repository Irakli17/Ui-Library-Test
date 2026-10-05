--[[
	Vantage · tests/Specs/Gradient.luau
	==================================================================
	`Util.gradient` is the one helper behind every gradient in the
	library: the loading canvas and its vignette, the logo's rings and
	swoosh, progress rails and sheens, caption scrims. It turns the
	library's `{ Time, Color, Transparency }` stops into the two
	sequences a `UIGradient` reads.

	That makes it the highest-leverage function in the tree, and the
	one whose failure mode is worst: a throw while building the first
	gradient of the loading screen leaves a half-painted backdrop and
	no interface at all. Which is what happened. The engine has no
	`(colors, times)` overload of `ColorSequence.new` — parallel
	arrays throw `expected 'ColorSequenceKeypoint' at index 1` — and
	every entry point went through this helper, so every load method
	died on the same line while the suite stayed green, because the
	mock accepted the overload the engine does not have.

	So these specs assert three things:
	  1. the sequences this helper builds are ones the engine accepts
	     (at least two keypoints, first at exactly 0, last at exactly
	     1, ordered, every entry a real keypoint);
	  2. awkward stop lists are normalised into that shape rather
	     than forwarded;
	  3. the mock refuses exactly what the engine refuses, so a mock
	     that drifts permissive again fails here instead of in a
	     live game.
]]

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local Util = Vantage.Util

local function host()
	return Instance.new("Frame")
end

--- The properties the engine checks, asserted on any sequence we build.
local function expectLegal(sequence: any): { any }
	local keypoints = sequence.Keypoints
	expect(#keypoints >= 2):toBeTruthy()
	for index = 2, #keypoints do
		expect(keypoints[index].Time >= keypoints[index - 1].Time):toBeTruthy()
	end
	expect(keypoints[1].Time):toBe(0)
	expect(keypoints[#keypoints].Time):toBe(1)
	return keypoints
end

describe("Util.gradient", function()
	it("builds an engine-legal ColorSequence from keypoints with explicit times", function()
		local a, b, c = Color3.fromRGB(240, 169, 59), Color3.fromRGB(255, 255, 255), Color3.fromRGB(10, 10, 9)
		local gradient = Util.gradient(host(), {
			{ Time = 0, Color = a },
			{ Time = 0.5, Color = b },
			{ Time = 1, Color = c, Transparency = 0.25 },
		}, 90)

		local keypoints = expectLegal(gradient.Color)
		expect(#keypoints):toBe(3)
		expect(typeof(keypoints[1])):toBe("ColorSequenceKeypoint")
		expect(keypoints[2].Time):toBeCloseTo(0.5)
		expect(keypoints[1].Value.R):toBeCloseTo(a.R)
		expect(keypoints[1].Value.G):toBeCloseTo(a.G)
		expect(keypoints[2].Value.B):toBeCloseTo(b.B)
		expect(keypoints[3].Value.G):toBeCloseTo(c.G)
		expect(gradient.Rotation):toBe(90)
		expect(gradient.Enabled):toBeTruthy()
	end)

	it("builds a matching transparency NumberSequence from the same stops", function()
		local gradient = Util.gradient(host(), {
			{ Time = 0, Color = Color3.new(1, 1, 1), Transparency = 1 },
			{ Time = 0.5, Color = Color3.new(1, 1, 1), Transparency = 0.4 },
			{ Time = 1, Color = Color3.new(1, 1, 1), Transparency = 0 },
		})

		local keypoints = expectLegal(gradient.Transparency)
		expect(#keypoints):toBe(3)
		expect(typeof(keypoints[1])):toBe("NumberSequenceKeypoint")
		expect(keypoints[1].Value):toBe(1)
		expect(keypoints[2].Value):toBeCloseTo(0.4)
		expect(keypoints[3].Value):toBe(0)
	end)

	it("spreads times evenly when the stops do not name them", function()
		local gradient = Util.gradient(host(), {
			{ Color = Color3.new(0, 0, 0) },
			{ Color = Color3.new(1, 0, 0) },
			{ Color = Color3.new(0, 1, 0) },
			{ Color = Color3.new(0, 0, 1) },
		})
		local keypoints = expectLegal(gradient.Color)
		expect(keypoints[2].Time):toBeCloseTo(1 / 3)
		expect(keypoints[3].Time):toBeCloseTo(2 / 3)
	end)

	it("normalises times the engine would reject instead of forwarding them", function()
		-- Descending, out-of-range and missing times in one stop list: the
		-- engine requires 0 .. 1 and ascending, so the helper has to land
		-- inside that shape rather than raise inside a screen build.
		local gradient = Util.gradient(host(), {
			{ Time = 0.8, Color = Color3.new(1, 1, 1) },
			{ Time = 0.2, Color = Color3.new(1, 0, 0) },
			{ Color = Color3.new(0, 1, 0) },
			{ Time = 4, Color = Color3.new(0, 0, 1) },
		})

		expectLegal(gradient.Color)
		expectLegal(gradient.Transparency)
	end)

	it("expresses a single stop through the two-keypoint overloads", function()
		-- `ColorSequence.new({ keypoint })` is itself an error — the engine
		-- wants at least two — so the flat case has to use the scalar form.
		local gradient = Util.gradient(host(), {
			{ Color = Color3.fromRGB(240, 169, 59), Transparency = 0.4 },
		})

		local colors = expectLegal(gradient.Color)
		local alphas = expectLegal(gradient.Transparency)
		expect(#colors):toBe(2)
		expect(#alphas):toBe(2)
		expect(alphas[1].Value):toBeCloseTo(0.4)
		expect(alphas[2].Value):toBeCloseTo(0.4)
	end)

	it("clamps a transparency value into 0..1", function()
		local gradient = Util.gradient(host(), {
			{ Time = 0, Color = Color3.new(1, 1, 1), Transparency = -3 },
			{ Time = 1, Color = Color3.new(1, 1, 1), Transparency = 7 },
		})
		local keypoints = expectLegal(gradient.Transparency)
		expect(keypoints[1].Value):toBe(0)
		expect(keypoints[2].Value):toBe(1)
	end)

	it("disables the gradient rather than building an empty sequence", function()
		local frame = host()
		local gradient = Util.gradient(frame, {})
		expect(gradient.Enabled):toBeFalsy()
	end)

	it("reuses the gradient already on the instance instead of stacking another", function()
		local frame = host()
		local first = Util.gradient(frame, { { Time = 0, Color = Color3.new(1, 1, 1) }, { Time = 1, Color = Color3.new(0, 0, 0) } })
		local second = Util.gradient(frame, { { Time = 0, Color = Color3.new(0, 1, 0) }, { Time = 1, Color = Color3.new(0, 0, 1) } })
		expect(second):toBe(first)
		local count = 0
		for _, child in ipairs(frame:GetChildren()) do
			if child:IsA("UIGradient") then
				count += 1
			end
		end
		expect(count):toBe(1)
	end)

	describe("engine contract", function()
		it("rejects the parallel colour/time arrays that took the client down", function()
			-- The exact shape of the original bug: colours and times in two
			-- tables. The engine throws, and so must the mock, or a live
			-- failure can pass the suite again.
			expect(function()
				ColorSequence.new({ Color3.new(1, 1, 1), Color3.new(0, 0, 0) }, { 0, 1 })
			end):toThrow()
			expect(function()
				NumberSequence.new({ 0, 1 })
			end):toThrow()
		end)

		it("rejects a keypoint array with fewer than two keypoints", function()
			expect(function()
				ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)) })
			end):toThrow()
			expect(function()
				NumberSequence.new({ NumberSequenceKeypoint.new(0, 0) })
			end):toThrow()
		end)

		it("rejects a keypoint array that does not span 0 to 1", function()
			local function pair(keypoint)
				return {
					keypoint(0, 0),
					keypoint(0.6, 1),
				}
			end
			expect(function()
				ColorSequence.new(pair(ColorSequenceKeypoint.new))
			end):toThrow()
			expect(function()
				NumberSequence.new(pair(NumberSequenceKeypoint.new))
			end):toThrow()
			expect(function()
				ColorSequence.new({
					ColorSequenceKeypoint.new(0.4, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
				})
			end):toThrow()
		end)

		it("rejects keypoints that are out of order", function()
			expect(function()
				ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(0.7, Color3.new(0, 0, 0)),
					ColorSequenceKeypoint.new(0.3, Color3.new(0, 0, 0)),
					ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
				})
			end):toThrow()
		end)

		it("accepts the scalar forms the engine advertises", function()
			local single = ColorSequence.new(Color3.new(1, 1, 1))
			expect(#single.Keypoints):toBe(2)
			expect(single.Keypoints[1].Time):toBe(0)
			expect(single.Keypoints[2].Time):toBe(1)

			local doubled = NumberSequence.new(0.25)
			expect(#doubled.Keypoints):toBe(2)
			expect(doubled.Keypoints[1].Value):toBeCloseTo(0.25)
		end)
	end)
end)
