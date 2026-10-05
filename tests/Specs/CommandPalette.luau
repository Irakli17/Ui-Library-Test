--[[
	Vantage · tests/Specs/CommandPalette.luau
	==================================================================
	The palette's documented command shape is `Add({ Label, Hint,
	Run })`. The renderer and the search index both read `Name`
	instead, so every row built from the documented API came out blank
	and the row write threw

	    Unable to assign property Text. string expected, got nil

	on a live client — invisible offline, because the mock accepted a
	nil write to a string property while the engine does not. These
	specs pin the documented field on both paths and pin the mock.

	Rows are recycled: a result set that shrinks hides the spare rows
	rather than clearing their text, so every lookup here walks the
	visible tree only.
]]

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local CommandPalette = Vantage.CommandPalette

--- Finds a label with this text inside a visible row.
local function findVisibleText(root, text)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("TextLabel") and descendant.Text == text then
			local parent = descendant.Parent
			if descendant.Visible and (parent == nil or parent.Visible ~= false) then
				return descendant
			end
		end
	end
	return nil
end

local function paletteWith(commands)
	local layer = Instance.new("Frame")
	local palette = CommandPalette.new({ layer = layer })
	palette:Add(commands)
	palette:Open()
	Mock.advance(0.4)
	return palette
end

describe("CommandPalette", function()
	it("renders the documented Label", function()
		local palette = paletteWith({
			{ Id = "settings", Label = "Open settings", Hint = "Tab", Run = function() end },
		})
		expect(findVisibleText(palette.Panel, "Open settings") ~= nil):toBeTruthy()
		palette:destroy()
	end)

	it("still accepts Name as an alias", function()
		local palette = paletteWith({
			{ Id = "legacy", Name = "Legacy command", Run = function() end },
		})
		expect(findVisibleText(palette.Panel, "Legacy command") ~= nil):toBeTruthy()
		palette:destroy()
	end)

	it("searches the same field it renders", function()
		local palette = paletteWith({
			{ Id = "settings", Label = "Open settings", Run = function() end },
			{ Id = "quit", Label = "Quit game", Run = function() end },
		})

		-- Typing goes through the box's own Text signal, so this exercises the
		-- path a player's keystrokes take.
		local box
		for _, descendant in ipairs(palette.Panel:GetDescendants()) do
			if descendant:IsA("TextBox") then
				box = descendant
			end
		end
		expect(box ~= nil):toBeTruthy()
		if not box then
			palette:destroy()
			return
		end

		box.Text = "settings"
		Mock.advance(0.2)
		expect(findVisibleText(palette.Panel, "Open settings") ~= nil):toBeTruthy()
		expect(findVisibleText(palette.Panel, "Quit game") == nil):toBeTruthy()
		palette:destroy()
	end)

	it("refuses the nil write the engine refuses", function()
		local label = Instance.new("TextLabel")
		expect(function()
			label.Text = nil
		end):toThrow()
	end)
end)
