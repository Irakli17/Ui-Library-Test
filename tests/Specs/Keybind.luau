--[[
	Vantage · tests/Specs/Keybind.luau
	==================================================================
	A binding is stored — and displayed — as a chord string. The
	documented form is `"LeftShift+T"`, but an `Enum.KeyCode` is the
	natural Roblox spelling, and handing one to the control used to put
	the enum straight into `Text`:

	    Unable to assign property Text. string expected, got EnumItem

	which is a hard error on a live client and invisible offline,
	because the mock accepted any value for any property. The normaliser
	below plus the mock's string-property rule close both halves.
]]

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local Keybind = Vantage.Keybind

describe("Keybind.chordOf", function()
	it("accepts the documented chord string unchanged", function()
		expect(Keybind.chordOf("LeftShift+T")):toBe("LeftShift+T")
		expect(Keybind.chordOf("")):toBe("")
	end)

	it("accepts an Enum.KeyCode and a list of them", function()
		expect(Keybind.chordOf(Enum.KeyCode.RightShift)):toBe("RightShift")
		expect(Keybind.chordOf({ Enum.KeyCode.LeftShift, Enum.KeyCode.T })):toBe("LeftShift+T")
		expect(Keybind.chordOf({ Enum.KeyCode.LeftControl, Enum.KeyCode.LeftShift, Enum.KeyCode.K })):toBe(
			"LeftControl+LeftShift+K"
		)
	end)

	it("treats nil and empty entries as unbound", function()
		expect(Keybind.chordOf(nil)):toBe("")
		expect(Keybind.chordOf({ Enum.KeyCode.F, nil })):toBe("F")
	end)
end)

describe("Keybind control", function()
	it("renders an enum binding as its key name, never as the enum", function()
		local keybind = Keybind.new({
			Name = "Toggle key",
			Value = Enum.KeyCode.RightShift,
		}, { parent = Instance.new("Frame") })

		expect(type(keybind.Label.Text)):toBe("string")
		expect(keybind.Label.Text):toBe("RightShift")
	end)

	it("renders an unbound control with a word rather than an empty box", function()
		local keybind = Keybind.new({ Name = "Push to talk" }, { parent = Instance.new("Frame") })
		expect(keybind.Label.Text):toBe("Unbound")
	end)

	it("normalises a value set after construction", function()
		local keybind = Keybind.new({ Name = "Push to talk" }, { parent = Instance.new("Frame") })
		keybind:Set(Enum.KeyCode.G)
		expect(keybind:Get()):toBe("G")
	end)

	it("refuses the property write the engine refuses", function()
		local label = Instance.new("TextLabel")
		expect(function()
			label.Text = Enum.KeyCode.K
		end):toThrow()
	end)
end)
