--[[
	Vantage · tests/Specs/Motion.luau
	==================================================================
	The scheduler's registry invariants.

	A tween registry with swap-removal is only correct while every tween's
	slot is accurate. When it is not — a resumed tween that was tracked
	twice, a cancel that ran during another tween's update — the frame that
	walks the array can read an entry that no longer exists, which is a
	hard error inside an animation frame.

	These specs hammer the registry with the patterns that caused it:
	overlapping tweens on one property, paused-and-resumed tweens, cancels
	from inside `onComplete`, and `cancelAll` during a live frame.
]]

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local Motion = Vantage.Motion

local function target()
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 0
	return frame
end

describe("Motion registry", function()
	it("survives overlapping tweens on the same property", function()
		local frame = target()
		for index = 1, 60 do
			Motion.tween(frame, { BackgroundTransparency = (index % 10) / 10 }, { duration = 0.12 })
			if index % 3 == 0 then
				Motion.tween(frame, { BackgroundTransparency = 0.4 }, { duration = 0.06 })
			end
			Mock.advance(0.03)
		end
		Mock.advance(0.5)
		expect(Motion.audit().holes):toBe(0)
		expect(Motion.audit().duplicates):toBe(0)
	end)

	it("never double-tracks a tween that was created paused", function()
		local frame = target()
		local tween = Motion.tween(frame, { BackgroundTransparency = 0.5 }, { duration = 0.2, play = false })
		expect(tween:isPlaying()):toBeFalsy()

		tween:resume()
		expect(tween:isPlaying()):toBeTruthy()
		-- Resuming twice used to register the same tween in two slots, which
		-- is what left a stale slot behind for a later frame to trip over.
		tween:resume()

		Mock.advance(0.4)
		local audit = Motion.audit()
		expect(audit.count):toBe(0)
		expect(audit.holes):toBe(0)
		expect(audit.strays):toBe(0)
	end)

	it("cancels neighbours from inside onComplete without corrupting slots", function()
		local frame = target()
		local warningsBefore = #Mock.warnings
		local spawned = {}
		for index = 1, 12 do
			table.insert(spawned, Motion.tween(frame, { BackgroundTransparency = index / 20 }, {
				duration = 0.08,
				onComplete = function()
					-- Starting new work from a completion callback is the
					-- exact moment the "last slot" moves under the scheduler.
					Motion.tween(frame, { BackgroundTransparency = 0.1 }, { duration = 0.05 })
				end,
			}))
		end

		Mock.advance(0.6)
		expect(Motion.audit().holes):toBe(0)
		expect(Motion.audit().duplicates):toBe(0)
		expect(#Mock.warnings):toBe(warningsBefore)
	end)

	it("cancels a whole owner while the frame is running", function()
		local owner = target()
		for index = 1, 8 do
			Motion.tween(owner, { BackgroundTransparency = index / 12 }, { duration = 0.4 })
		end
		Motion.tween(owner, { Rotation = 45 }, {
			duration = 0.3,
			onUpdate = function()
				Motion.cancelAll(owner)
			end,
		})

		Mock.advance(0.8)
		expect(Motion.audit().holes):toBe(0)
		expect(Motion.audit().skips):toBe(0)
	end)

	it("keeps loops and reversals running without leaking slots", function()
		local frame = target()
		local loop = Motion.tween(frame, { BackgroundTransparency = 0.6 }, { duration = 0.1, repeatCount = -1 })
		local pingpong = Motion.tween(frame, { Rotation = 180 }, { duration = 0.12, reverse = true, repeatCount = 3 })

		Mock.advance(2)
		expect(loop:isPlaying()):toBeTruthy()
		expect(Motion.audit().holes):toBe(0)

		loop:cancel()
		pingpong:cancel()
		Mock.advance(0.2)
		expect(Motion.audit().count):toBe(0)
	end)

	it("reports a clean registry through Diagnostics", function()
		Motion.resetAudit()
		Mock.advance(0.1)
		local report = Motion.audit()
		expect(report.skips):toBe(0)
		expect(report.holes):toBe(0)
		expect(report.strays):toBe(0)
	end)
end)
