--[[
	Vantage · tests/Harness.luau
	==================================================================
	A deliberately tiny spec runner: `describe`, `it`, `expect`.

	It reports every failure with the value it actually saw rather than
	a bare "assertion failed", because a test suite that hides its own
	evidence is worse than no test suite.
]]

local Harness = {}

local suites = {}
local currentSuite = nil
local failures = {}
local passes = 0
local depth = 0

local function format(value, seen)
	seen = seen or {}
	local kind = type(value)
	if kind == "string" then
		return string.format("%q", value)
	elseif kind == "number" or kind == "boolean" or kind == "nil" then
		return tostring(value)
	elseif kind == "table" then
		if seen[value] then
			return "<cycle>"
		end
		seen[value] = true
		local parts = {}
		local count = 0
		for key, entry in pairs(value) do
			count += 1
			if count > 12 then
				table.insert(parts, "…")
				break
			end
			table.insert(parts, tostring(key) .. " = " .. format(entry, seen))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

function Harness.describe(name, body)
	local previous = currentSuite
	currentSuite = name
	depth += 1
	local ok, err = pcall(body)
	depth -= 1
	if not ok then
		table.insert(failures, {
			suite = name,
			test = "<suite body>",
			message = "suite threw: " .. tostring(err),
		})
	end
	currentSuite = previous
end

function Harness.it(name, body)
	local ok, err = pcall(body)
	if ok then
		passes += 1
		print(string.format("  \27[32m✓\27[0m %s\n", name))
	else
		table.insert(failures, {
			suite = currentSuite,
			test = name,
			message = tostring(err),
		})
		print(string.format("  \27[31m✗\27[0m %s\n", name))
		print(string.format("      %s\n", tostring(err)))
	end
end

local Expectation = {}
Expectation.__index = Expectation

local function fail(message)
	error(message, 3)
end

function Harness.expect(value)
	return setmetatable({ value = value, negated = false }, Expectation)
end

function Expectation:toBe(expected)
	if self.value ~= expected then
		fail(string.format("expected %s, got %s", format(expected), format(self.value)))
	end
	return self
end

function Expectation:toBeCloseTo(expected, tolerance)
	tolerance = tolerance or 1e-6
	if type(self.value) ~= "number" then
		fail(string.format("expected a number, got %s", format(self.value)))
	end
	if math.abs(self.value - expected) > tolerance then
		fail(string.format("expected %s ± %s, got %s", expected, tolerance, self.value))
	end
	return self
end

function Expectation:toBeGreaterThan(expected)
	if not (type(self.value) == "number" and self.value > expected) then
		fail(string.format("expected > %s, got %s", expected, format(self.value)))
	end
	return self
end

function Expectation:toBeGreaterThanOrEqual(expected)
	if not (type(self.value) == "number" and self.value >= expected) then
		fail(string.format("expected >= %s, got %s", expected, format(self.value)))
	end
	return self
end

function Expectation:toBeLessThanOrEqual(expected)
	if not (type(self.value) == "number" and self.value <= expected) then
		fail(string.format("expected <= %s, got %s", expected, format(self.value)))
	end
	return self
end

function Expectation:toBeLessThan(expected)
	if not (type(self.value) == "number" and self.value < expected) then
		fail(string.format("expected < %s, got %s", expected, format(self.value)))
	end
	return self
end

function Expectation:toBeBetween(low, high)
	if not (type(self.value) == "number" and self.value >= low and self.value <= high) then
		fail(string.format("expected %s..%s, got %s", low, high, format(self.value)))
	end
	return self
end

function Expectation:toBeTruthy()
	if not self.value then
		fail(string.format("expected a truthy value, got %s", format(self.value)))
	end
	return self
end

function Expectation:toBeFalsy()
	if self.value then
		fail(string.format("expected a falsy value, got %s", format(self.value)))
	end
	return self
end

function Expectation:toBeNil()
	if self.value ~= nil then
		fail(string.format("expected nil, got %s", format(self.value)))
	end
	return self
end

function Expectation:toBeType(expected)
	if type(self.value) ~= expected then
		fail(string.format("expected type %s, got %s (%s)", expected, type(self.value), format(self.value)))
	end
	return self
end

function Expectation:toHaveLength(expected)
	if type(self.value) ~= "table" then
		fail(string.format("expected a table, got %s", format(self.value)))
	end
	if #self.value ~= expected then
		fail(string.format("expected length %d, got %d", expected, #self.value))
	end
	return self
end

function Expectation:toContain(needle)
	if type(self.value) == "string" then
		if not self.value:find(needle, 1, true) then
			fail(string.format("expected %q to contain %q", self.value, needle))
		end
		return self
	end
	if type(self.value) == "table" then
		for _, entry in ipairs(self.value) do
			if entry == needle then
				return self
			end
		end
		fail(string.format("expected %s to contain %s", format(self.value), format(needle)))
	end
	fail("toContain expects a string or array")
end

--- Asserts the predicate returns truthy, reporting what it saw.
function Expectation:toSatisfy(predicate, description)
	if not predicate(self.value) then
		fail(string.format("expected value to satisfy %s, got %s", description or "predicate", format(self.value)))
	end
	return self
end

function Expectation:toThrow()
	if type(self.value) ~= "function" then
		fail("toThrow expects a function")
	end
	local ok = pcall(self.value)
	if ok then
		fail("expected the function to throw, but it returned normally")
	end
	return self
end

--[[ Report --------------------------------------------------------- ]]

function Harness.report(label)
	local total = passes + #failures
	print("\n")
	if #failures == 0 then
		print(string.format("\27[32m%s — %d/%d assertions passed\27[0m\n", label, passes, total))
		return 0
	end

	print(string.format("\27[31m%s — %d failed, %d passed (of %d)\27[0m\n\n", label, #failures, passes, total))
	for _, failure in ipairs(failures) do
		print(string.format("  \27[31mFAIL\27[0m  %s › %s\n", failure.suite or "?", failure.test))
		print(string.format("        %s\n", failure.message))
	end
	return #failures
end

function Harness.failures()
	return failures
end

return Harness
