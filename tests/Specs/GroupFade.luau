--[[
	Vantage · tests/Specs/GroupFade.luau
	==================================================================
	Fading a subtree as one object needs a `CanvasGroup`: that is the
	only class with `GroupTransparency`. On a Frame the engine throws
	`GroupTransparency is not a valid member of Frame` — which is what
	happened inside the loading screen's worker on a live client, where
	it took the logo's fade and the thread with it. The same write
	appeared in tabs, the palette, modal panels and toasts, and the
	offline suite could not see any of it, because the mock accepted
	any property write on any instance.

	So these specs assert the two halves of the fix: the containers the
	library fades are CanvasGroups, and the mock refuses the write the
	engine refuses.
]]

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local Util = Vantage.Util
local Notify = Vantage.Notify

describe("Util.group", function()
	it("builds a CanvasGroup, the only class that can fade as a group", function()
		local group = Util.group({ Name = "Group" })
		expect(group.ClassName):toBe("CanvasGroup")
		expect(group.GroupTransparency):toBe(0)
		expect(group.BorderSizePixel):toBe(0)
		-- Transparent like `Util.row`, so swapping a layout container for a
		-- group cannot paint a background that was not there before.
		expect(group.BackgroundTransparency):toBe(1)
	end)

	it("keeps an explicit background", function()
		local group = Util.group({ Name = "Card", BackgroundTransparency = 0.02 })
		expect(group.BackgroundTransparency):toBeCloseTo(0.02)
	end)

	it("refuses the group fade the engine refuses", function()
		local frame = Instance.new("Frame")
		expect(function()
			frame.GroupTransparency = 1
		end):toThrow()
		expect(function()
			Instance.new("TextLabel").GroupTransparency = 0
		end):toThrow()
	end)

	it("fades a whole toast in and out through the group property", function()
		local layer = Instance.new("Frame")
		local notify = Notify.new({ layer = layer })

		local id = notify:push({ Title = "Saved", Body = "Your settings were written.", Duration = 0 })

		local card
		for _, descendant in ipairs(layer:GetDescendants()) do
			if descendant.Name == "VantageToast" then
				card = descendant
			end
		end
		expect(card ~= nil):toBeTruthy()
		expect(card.ClassName):toBe("CanvasGroup")

		-- The entrance is a tween from 1 to 0: it only lands if the property
		-- the tween writes actually exists on the instance.
		expect(card.GroupTransparency):toBe(1)
		Mock.advance(0.6)
		expect(card.GroupTransparency):toBeCloseTo(0, 0.01)

		-- And the exit fades it back out before the card is destroyed.
		notify:dismiss(id)
		Mock.advance(0.4)
		expect(card.GroupTransparency):toBeCloseTo(1, 0.01)

		notify:destroy()
	end)
end)
