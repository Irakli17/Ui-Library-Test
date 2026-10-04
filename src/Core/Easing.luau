--!nonstrict
--[[
	Vantage 1.0.0 · Core/Easing
	------------------------------------------------------------------
	Two things live here:

	1. A hand-tuned catalog of easing functions, grouped by intent
	   (enter, exit, move, emphasize) rather than by maths.
	2. A real cubic-bezier solver, so `Easing.bezier(0.16, 1, 0.3, 1)`
	   behaves exactly like CSS's cubic-bezier() — including the
	   non-monotonic, overshooting cases that a naive lerp gets wrong.

	Every function maps [0, 1] -> R, where the result 0 is the start
	and 1 is the end. Overshoot is allowed and expected for the
	"back"/"elastic" families.
]]

local Easing = {}

local PI = math.pi
local sin, cos, pow, sqrt, abs = math.sin, math.cos, math.pow, math.sqrt, math.abs

--[[ Base set ------------------------------------------------------- ]]

--- Identity.
function Easing.linear(t: number): number
	return t
end

function Easing.quadIn(t: number): number
	return t * t
end

function Easing.quadOut(t: number): number
	return -t * (t - 2)
end

function Easing.quadInOut(t: number): number
	t *= 2
	if t < 1 then
		return 0.5 * t * t
	end
	t -= 1
	return -0.5 * (t * (t - 2) - 1)
end

function Easing.cubicIn(t: number): number
	return t * t * t
end

function Easing.cubicOut(t: number): number
	t -= 1
	return t * t * t + 1
end

function Easing.cubicInOut(t: number): number
	t *= 2
	if t < 1 then
		return 0.5 * t * t * t
	end
	t -= 2
	return 0.5 * (t * t * t + 2)
end

function Easing.quartIn(t: number): number
	return t * t * t * t
end

function Easing.quartOut(t: number): number
	t -= 1
	return 1 - t * t * t * t
end

function Easing.quartInOut(t: number): number
	t *= 2
	if t < 1 then
		return 0.5 * t * t * t * t
	end
	t -= 2
	return -0.5 * (t * t * t * t - 2)
end

function Easing.quintIn(t: number): number
	return t * t * t * t * t
end

function Easing.quintOut(t: number): number
	t -= 1
	return t * t * t * t * t + 1
end

function Easing.quintInOut(t: number): number
	t *= 2
	if t < 1 then
		return 0.5 * t * t * t * t * t
	end
	t -= 2
	return 0.5 * (t * t * t * t * t + 2)
end

function Easing.sineIn(t: number): number
	return 1 - cos(t * PI * 0.5)
end

function Easing.sineOut(t: number): number
	return sin(t * PI * 0.5)
end

function Easing.sineInOut(t: number): number
	return -0.5 * (cos(PI * t) - 1)
end

function Easing.expoIn(t: number): number
	if t <= 0 then
		return 0
	end
	return pow(2, 10 * t - 10)
end

function Easing.expoOut(t: number): number
	if t >= 1 then
		return 1
	end
	return 1 - pow(2, -10 * t)
end

function Easing.expoInOut(t: number): number
	if t <= 0 then
		return 0
	end
	if t >= 1 then
		return 1
	end
	t *= 2
	if t < 1 then
		return 0.5 * pow(2, 10 * (t - 1))
	end
	return 0.5 * (2 - pow(2, -10 * (t - 1)))
end

function Easing.circIn(t: number): number
	return 1 - sqrt(1 - t * t)
end

function Easing.circOut(t: number): number
	t -= 1
	return sqrt(1 - t * t)
end

function Easing.circInOut(t: number): number
	t *= 2
	if t < 1 then
		return -0.5 * (sqrt(1 - t * t) - 1)
	end
	t -= 2
	return 0.5 * (sqrt(1 - t * t) + 1)
end

local function backIn(t: number, s: number): number
	return t * t * ((s + 1) * t - s)
end

local function backOut(t: number, s: number): number
	t -= 1
	return t * t * ((s + 1) * t + s) + 1
end

function Easing.backIn(t: number): number
	return backIn(t, 1.70158)
end

function Easing.backOut(t: number): number
	return backOut(t, 1.70158)
end

function Easing.backInOut(t: number): number
	local s = 1.70158 * 1.525
	t *= 2
	if t < 1 then
		return 0.5 * (t * t * ((s + 1) * t - s))
	end
	-- Re-normalise into the second half. Calling backOut with the raw
	-- doubled progress overshoots the endpoint (it evaluates a curve
	-- meant for [-1, 0] at +1), which lands the animation 50% past its
	-- target at exactly t = 1.
	t -= 2
	return 0.5 * (t * t * ((s + 1) * t + s) + 2)
end

function Easing.elasticIn(t: number): number
	if t <= 0 then
		return 0
	end
	if t >= 1 then
		return 1
	end
	local p = 0.3
	return -(pow(2, 10 * (t - 1)) * sin((t - 1 - p / 4) * (2 * PI) / p))
end

function Easing.elasticOut(t: number): number
	if t <= 0 then
		return 0
	end
	if t >= 1 then
		return 1
	end
	local p = 0.3
	return pow(2, -10 * t) * sin((t - p / 4) * (2 * PI) / p) + 1
end

function Easing.elasticInOut(t: number): number
	if t <= 0 then
		return 0
	end
	if t >= 1 then
		return 1
	end
	local p = 0.3 * 1.5
	t *= 2
	if t < 1 then
		return -0.5 * pow(2, 10 * (t - 1)) * sin((t - 1 - p / 4) * (2 * PI) / p)
	end
	return pow(2, -10 * (t - 1)) * sin((t - 1 - p / 4) * (2 * PI) / p) * 0.5 + 1
end

--- Damped oscillation that settles precisely on 1 — the standard
--- "spring without a physics loop" for one-shot transitions.
local function oscInOut(t: number, a: number): number
	local w = 2 * PI / 3.4
	if t == 0 then
		return 0
	end
	if t == 1 then
		return 1
	end
	return 1 + a * pow(2, -10 * t) * sin(w * t - w / 4)
end

function Easing.oscillate(t: number): number
	return oscInOut(t, -0.6)
end

function Easing.settle(t: number): number
	return oscInOut(t, -0.28)
end

function Easing.bounceOut(t: number): number
	if t < 1 / 2.75 then
		return 7.5625 * t * t
	elseif t < 2 / 2.75 then
		t -= 1.5 / 2.75
		return 7.5625 * t * t + 0.75
	elseif t < 2.5 / 2.75 then
		t -= 2.25 / 2.75
		return 7.5625 * t * t + 0.9375
	end
	t -= 2.625 / 2.75
	return 7.5625 * t * t + 0.984375
end

function Easing.bounceIn(t: number): number
	return 1 - Easing.bounceOut(1 - t)
end

function Easing.bounceInOut(t: number): number
	if t < 0.5 then
		return Easing.bounceIn(t * 2) * 0.5
	end
	return Easing.bounceOut(t * 2 - 1) * 0.5 + 0.5
end

--- A gentle "S" that never overshoots but leaves and arrives slowly.
function Easing.smooth(t: number): number
	return t * t * (3 - 2 * t)
end

--- Smoother: zero first *and* second derivative at both ends.
function Easing.smoother(t: number): number
	return t * t * t * (t * (t * 6 - 15) + 10)
end

--- Asymmetric "whisper in, snap out" used for tooltips and popovers.
function Easing.snap(t: number): number
	return 1 - pow(1 - t, 4.6)
end

--- Mirrors `smooth` around the midpoint: fast middle, soft ends.
function Easing.glide(t: number): number
	return t < 0.5 and 4 * t * t * t or 1 - pow(-2 * t + 2, 3) / 2
end

--[[ Cubic bezier --------------------------------------------------- ]]

local function bezierComponent(t: number, a1: number, a2: number): number
	-- (1-t)^3 * 0 + 3(1-t)^2 t * a1 + 3(1-t) t^2 * a2 + t^3 * 1
	local mt = 1 - t
	return 3 * mt * mt * t * a1 + 3 * mt * t * t * a2 + t * t * t
end

local function bezierSlope(t: number, a1: number, a2: number): number
	local mt = 1 - t
	return 3 * mt * mt * a1 + 6 * mt * t * (a2 - a1) + 3 * t * t * (1 - a2)
end

--- Builds a CSS-compatible cubic-bezier easing function.
--- Solves x(t) = progress for t via Newton-Raphson with a bisection
--- fallback, then evaluates y(t).
function Easing.bezier(x1: number, y1: number, x2: number, y2: number)
	-- The linear shortcut.
	if x1 == y1 and x2 == y2 then
		return Easing.linear
	end

	local EPSILON = 1e-7
	local function solve(progress: number): number
		if progress <= 0 then
			return 0
		end
		if progress >= 1 then
			return 1
		end

		-- Newton-Raphson first; it converges in ~4 iterations.
		local t = progress
		for _ = 1, 8 do
			local x = bezierComponent(t, x1, x2) - progress
			if abs(x) < EPSILON then
				return t
			end
			local slope = bezierSlope(t, x1, x2)
			if abs(slope) < 1e-6 then
				break
			end
			t -= x / slope
		end

		-- Guaranteed-convergence bisection fallback.
		local low, high = 0.0, 1.0
		t = progress
		for _ = 1, 24 do
			local x = bezierComponent(t, x1, x2)
			if abs(x - progress) < EPSILON then
				break
			end
			if x < progress then
				low = t
			else
				high = t
			end
			t = (low + high) * 0.5
		end
		return t
	end

	return function(progress: number): number
		if progress <= 0 then
			return 0
		end
		if progress >= 1 then
			return 1
		end
		return bezierComponent(solve(progress), y1, y2)
	end
end

--[[ Catalog lookup ------------------------------------------------ ]]

--- Named easings used by name in component props, e.g.
--- `easing = "snap"`. Prefer these names over raw function refs so
--- that tuning happens in exactly one place.
Easing.catalog = {
	linear = Easing.linear,

	-- Moves: things sliding, resizing, re-ordering.
	glide = Easing.glide,
	smooth = Easing.smoother,
	move = Easing.bezier(0.4, 0.0, 0.2, 1),
	moveIn = Easing.bezier(0.4, 0, 1, 1),
	moveOut = Easing.bezier(0, 0, 0.2, 1),

	-- Enters: something arriving on screen. Decelerate hard.
	enter = Easing.bezier(0.05, 0.7, 0.1, 1),
	enterSoft = Easing.bezier(0.22, 1, 0.36, 1),
	enterSnap = Easing.bezier(0.16, 1, 0.3, 1),

	-- Exits: something leaving. Accelerate away, keep it quick.
	exit = Easing.bezier(0.3, 0, 0.8, 0.15),
	exitSoft = Easing.bezier(0.4, 0, 0.6, 1),

	-- Emphasised: for heroes, logos, moments that deserve a flourish.
	emphasize = Easing.bezier(0.2, 0, 0, 1.2),
	emphasizeIn = Easing.bezier(0.7, -0.4, 0.84, 0.4),

	-- One-shot physics-ish.
	settle = Easing.settle,
	oscillate = Easing.oscillate,
	snap = Easing.snap,

	-- Standards.
	quad = Easing.quadInOut,
	cubic = Easing.cubicInOut,
	quart = Easing.quartInOut,
	quint = Easing.quintInOut,
	sine = Easing.sineInOut,
	expo = Easing.expoInOut,
	circ = Easing.circInOut,
	back = Easing.backOut,
	bounce = Easing.bounceOut,
	elastic = Easing.elasticOut,
} :: { [string]: any }

-- Every public easing is also reachable by its literal function name,
-- so `easing = "cubicOut"` and `easing = Easing.cubicOut` agree.
Easing.directionalNames = {
	"quadIn", "quadOut", "quadInOut",
	"cubicIn", "cubicOut", "cubicInOut",
	"quartIn", "quartOut", "quartInOut",
	"quintIn", "quintOut", "quintInOut",
	"sineIn", "sineOut", "sineInOut",
	"expoIn", "expoOut", "expoInOut",
	"circIn", "circOut", "circInOut",
	"backIn", "backOut", "backInOut",
	"bounceIn", "bounceInOut",
	"elasticIn", "elasticInOut",
	"linear", "settle", "oscillate", "smooth", "smoother", "snap", "glide",
}

for _, name in ipairs(Easing.directionalNames) do
	Easing.catalog[name] = Easing[name]
end

--- Resolves an easing spec (string | function | nil) to a function.
function Easing.resolve(spec: any)
	if spec == nil then
		return Easing.catalog.move
	end
	if type(spec) == "function" then
		return spec
	end
	if type(spec) == "string" then
		local found = Easing.catalog[spec]
		if not found then
			warn(string.format("[Vantage] unknown easing %q, falling back to 'move'", spec))
			return Easing.catalog.move
		end
		return found
	end
	return Easing.catalog.move
end

--- Samples an easing into `count` points, useful for docs graphs.
function Easing.sample(spec: any, count: number): { number }
	local fn = Easing.resolve(spec)
	local out = table.create(count)
	for index = 1, count do
		out[index] = fn((index - 1) / (count - 1))
	end
	return out
end

--- Inverts a monotonic easing: given an output, find the input.
function Easing.invert(spec: any, value: number): number
	local fn = Easing.resolve(spec)
	local low, high = 0.0, 1.0
	for _ = 1, 28 do
		local mid = (low + high) * 0.5
		if fn(mid) < value then
			low = mid
		else
			high = mid
		end
	end
	return (low + high) * 0.5
end

--- Blends two easings. Handy for "start like an exit, end like an enter".
function Easing.blend(a: any, b: any, mix: number)
	local fnA, fnB = Easing.resolve(a), Easing.resolve(b)
	return function(t: number): number
		return fnA(t) * (1 - mix) + fnB(t) * mix
	end
end

return Easing
