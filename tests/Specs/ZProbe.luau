-- Temporary probe: what does the scheduler look like when it breaks?
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function dump(value, depth)
	depth = depth or 0
	local parts = {}
	for key, entry in pairs(value) do
		if type(entry) == "table" and depth < 1 then
			table.insert(parts, tostring(key) .. "=" .. dump(entry, depth + 1))
		else
			table.insert(parts, tostring(key) .. "=" .. tostring(entry))
		end
	end
	return "{" .. table.concat(parts, ", ") .. "}"
end

describe("probe", function()
	it("runs the loading screen with an instrumented scheduler", function()
		local original = Vantage.Motion.step
		local failures = 0
		Vantage.Motion.step = function(dt)
			local ok, err = pcall(original, dt)
			if not ok then
				failures += 1
				if failures <= 2 then
					print("STEP ERROR: " .. tostring(err))
					print("stats: " .. dump(Vantage.Motion.stats()))
				end
				return false
			end
			return true
		end

		local handle = Vantage.LoadingScreen.Run({
			Assets = { "rbxassetid://1234567890" },
			MinDuration = 0.4,
			MaxDuration = 5,
			AutoContinue = 0.5,
			Logo = { Image = "rbxassetid://987654321" },
		})
		Mock.advance(6)
		Vantage.Motion.step = original

		print("probe: step failures = " .. tostring(failures) .. " complete=" .. tostring(handle.screen:IsComplete()))
		handle:destroy()
		expect(true):toBeTruthy()
	end)
end)
