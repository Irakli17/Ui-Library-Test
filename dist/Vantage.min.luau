

local __modules: { [string]: () -> any } = {}
local __cache: { [string]: any } = {}

local function __require(path: string): any
local cached = __cache[path]
if cached ~= nil then
return cached
end
local loader = __modules[path]
if loader == nil then
error("[Vantage] module not found: " .. tostring(path), 2)
end
local value = loader()
if value == nil then
error("[Vantage] module returned nil: " .. tostring(path), 2)
end
__cache[path] = value
return value
end

local function __namespace(prefix: string): any
return setmetatable({}, {
__index = function(_, key: string)
local path = prefix == "" and key or (prefix .. "." .. key)
if __modules[path] ~= nil then
return __require(path)
end
return nil
end,
})
end

__modules["Core.Signal"] = function()

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

local nextId = 0
local function uid(): number
nextId += 1
return nextId
end

local function reportError(err: any, trace: string?)
local message
if type(err) == "string" then
message = err
else
message = tostring(err)
end
warn(string.format("[Vantage] signal handler error: %s%s", message, trace and ("\n" .. trace) or ""))
end

function Signal.new(name: string?)
local self = setmetatable({}, Signal)
self._handlers = {}
self._connections = {}
self._upstream = {}
self._name = name
self._destroyed = false
return self
end

function Signal:connectionCount(): number
return #self._connections
end

function Signal:connect(handler: (...any) -> ())
assert(type(handler) == "function", "[Vantage] Signal:connect expects a function")

local connection = setmetatable({
_id = uid(),
Connected = true,
_signal = self,
_handler = handler,
}, Connection)

table.insert(self._handlers, connection)

table.insert(self._connections, connection)
if #self._connections > 512 then
table.remove(self._connections, 1)
end
return connection
end

function Signal:once(handler: (...any) -> ())
local fired = false
local connection
connection = self:connect(function(...)
if fired then
return
end
fired = true
connection:disconnect()
handler(...)
end)
return connection
end

function Signal:fire(...)
if self._destroyed then
return
end

local handlers = table.clone(self._handlers)
for _, connection in ipairs(handlers) do
if connection.Connected then
local ok, err = xpcall(connection._handler, function(e)
return tostring(e) .. "\n" .. debug.traceback("", 2)
end, ...)
if not ok then
reportError(err)
end
end
end
end

function Signal:_remove(connection)
local index = table.find(self._handlers, connection)
if index then
table.remove(self._handlers, index)
end
end

function Signal:wait()
local thread = coroutine.running()
local connection
connection = self:connect(function(...)
connection:disconnect()
task.spawn(thread, ...)
end)
return coroutine.yield()
end

function Signal:disconnectAll()
for _, connection in ipairs(table.clone(self._handlers)) do
connection:disconnect()
end
self._handlers = {}
self._connections = {}
end

function Signal:listenerCount(): number
return #self._handlers
end

function Signal:isDestroyed(): boolean
return self._destroyed
end

function Signal:destroy()
if self._destroyed then
return
end
self._destroyed = true
self:disconnectAll()
end

function Connection:disconnect()
if not self.Connected then
return
end
self.Connected = false
self._handler = nil
self._signal:_remove(self)
end

function Connection:isConnected(): boolean
return self.Connected
end

function Connection:destroy()
self:disconnect()
end

Signal.Connection = Connection

function Signal.any(signals: { any }): any
local merged = Signal.new("merged")
for _, signal in ipairs(signals) do
local connection = signal:connect(function(...)
merged:fire(...)
end)
table.insert(merged._upstream, connection)
end

local originalDestroy = merged.destroy
merged.destroy = function(self)
for _, connection in ipairs(self._upstream) do
connection:disconnect()
end
table.clear(self._upstream)
originalDestroy(self)
end

return merged
end

function Signal.deferred(name: string?): any
local gate = Signal.new(name)
local scheduled = false
local latest = nil

local debounced = Signal.new(name and (name .. ":deferred") or "deferred")
gate:connect(function(...)
latest = table.pack(...)
if scheduled then
return
end
scheduled = true
task.defer(function()
scheduled = false
local args = latest
latest = nil
if args then
debounced:fire(table.unpack(args, 1, args.n))
end
end)
end)
debounced._source = gate
return debounced
end

return Signal
end

__modules["Core.Easing"] = function()

local Easing = {}

local PI = math.pi
local sin, cos, pow, sqrt, abs = math.sin, math.cos, math.pow, math.sqrt, math.abs

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

function Easing.smooth(t: number): number
return t * t * (3 - 2 * t)
end

function Easing.smoother(t: number): number
return t * t * t * (t * (t * 6 - 15) + 10)
end

function Easing.snap(t: number): number
return 1 - pow(1 - t, 4.6)
end

function Easing.glide(t: number): number
return t < 0.5 and 4 * t * t * t or 1 - pow(-2 * t + 2, 3) / 2
end

local function bezierComponent(t: number, a1: number, a2: number): number

local mt = 1 - t
return 3 * mt * mt * t * a1 + 3 * mt * t * t * a2 + t * t * t
end

local function bezierSlope(t: number, a1: number, a2: number): number
local mt = 1 - t
return 3 * mt * mt * a1 + 6 * mt * t * (a2 - a1) + 3 * t * t * (1 - a2)
end

function Easing.bezier(x1: number, y1: number, x2: number, y2: number)

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

Easing.catalog = {
linear = Easing.linear,

glide = Easing.glide,
smooth = Easing.smoother,
move = Easing.bezier(0.4, 0.0, 0.2, 1),
moveIn = Easing.bezier(0.4, 0, 1, 1),
moveOut = Easing.bezier(0, 0, 0.2, 1),

enter = Easing.bezier(0.05, 0.7, 0.1, 1),
enterSoft = Easing.bezier(0.22, 1, 0.36, 1),
enterSnap = Easing.bezier(0.16, 1, 0.3, 1),

exit = Easing.bezier(0.3, 0, 0.8, 0.15),
exitSoft = Easing.bezier(0.4, 0, 0.6, 1),

emphasize = Easing.bezier(0.2, 0, 0, 1.2),
emphasizeIn = Easing.bezier(0.7, -0.4, 0.84, 0.4),

settle = Easing.settle,
oscillate = Easing.oscillate,
snap = Easing.snap,

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

function Easing.sample(spec: any, count: number): { number }
local fn = Easing.resolve(spec)
local out = table.create(count)
for index = 1, count do
out[index] = fn((index - 1) / (count - 1))
end
return out
end

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

function Easing.blend(a: any, b: any, mix: number)
local fnA, fnB = Easing.resolve(a), Easing.resolve(b)
return function(t: number): number
return fnA(t) * (1 - mix) + fnB(t) * mix
end
end

return Easing
end

__modules["Core.Motion"] = function()

local RunService
local Easing = __require("Core.Easing")

local Motion = {}

Motion._reducedMotion = false

Motion.Durations = {
instant = 0,
swift = 0.09,
fast = 0.16,
normal = 0.24,
slow = 0.36,
deliberate = 0.55,
cinematic = 0.9,
}

Motion.presets = {
instant = { duration = 0, easing = "linear" },

fast = { duration = 0.16, easing = "move" },
hover = { duration = 0.14, easing = "move" },
press = { duration = 0.08, easing = "exitSoft" },
release = { duration = 0.34, easing = "settle" },
enter = { duration = 0.32, easing = "enterSnap" },
exit = { duration = 0.18, easing = "exit" },
panel = { duration = 0.34, easing = "enterSnap" },
expand = { duration = 0.3, easing = "emphasize" },
collapse = { duration = 0.22, easing = "exit" },
emphasized = { duration = 0.5, easing = "emphasize" },
cinematic = { duration = 0.9, easing = "enterSnap" },
}

function Motion.options(preset: any, overrides: { [any]: any }?): { [any]: any }
local base: any
if type(preset) == "string" then
base = Motion.presets[preset]
if not base then
warn(string.format("[Vantage] unknown motion preset %q", tostring(preset)))
base = Motion.presets.hover
end
else
base = preset or Motion.presets.hover
end
if not overrides then
return base
end
local out = table.clone(base)
for key, value in pairs(overrides) do
out[key] = value
end
return out
end

local copiers = {
number = function(value: number): number
return value
end,
Color3 = function(value: any): any
return Color3.new(value.R, value.G, value.B)
end,
UDim = function(value: any): any
return UDim.new(value.Scale, value.Offset)
end,
UDim2 = function(value: any): any
return UDim2.new(value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset)
end,
Vector2 = function(value: any): any
return Vector2.new(value.X, value.Y)
end,
Vector3 = function(value: any): any
return Vector3.new(value.X, value.Y, value.Z)
end,
Rect = function(value: any): any
return Rect.new(value.Min.X, value.Min.Y, value.Max.X, value.Max.Y)
end,
}

function Motion.copy(value: any): any
local copier = copiers[typeof(value)]
if copier then
return copier(value)
end
if type(value) == "number" then
return value
end
return value
end

local function lerpNumber(a: number, b: number, t: number): number
return a + (b - a) * t
end

function Motion.lerp(from: any, to: any, alpha: number): any
local kind = typeof(from)
if kind ~= typeof(to) then
warn(string.format("[Vantage] cannot interpolate %s -> %s; snapping", kind, typeof(to)))
return alpha >= 1 and to or from
end

if kind == "number" then
return lerpNumber(from, to, alpha)
elseif kind == "Color3" then
return Color3.new(
lerpNumber(from.R, to.R, alpha),
lerpNumber(from.G, to.G, alpha),
lerpNumber(from.B, to.B, alpha)
)
elseif kind == "UDim" then
return UDim.new(
lerpNumber(from.Scale, to.Scale, alpha),
lerpNumber(from.Offset, to.Offset, alpha)
)
elseif kind == "UDim2" then
return UDim2.new(
lerpNumber(from.X.Scale, to.X.Scale, alpha),
lerpNumber(from.X.Offset, to.X.Offset, alpha),
lerpNumber(from.Y.Scale, to.Y.Scale, alpha),
lerpNumber(from.Y.Offset, to.Y.Offset, alpha)
)
elseif kind == "Vector2" then
return Vector2.new(
lerpNumber(from.X, to.X, alpha),
lerpNumber(from.Y, to.Y, alpha)
)
elseif kind == "Vector3" then
return Vector3.new(
lerpNumber(from.X, to.X, alpha),
lerpNumber(from.Y, to.Y, alpha),
lerpNumber(from.Z, to.Z, alpha)
)
elseif kind == "Rect" then
return Rect.new(
lerpNumber(from.Min.X, to.Min.X, alpha),
lerpNumber(from.Min.Y, to.Min.Y, alpha),
lerpNumber(from.Max.X, to.Max.X, alpha),
lerpNumber(from.Max.Y, to.Max.Y, alpha)
)
end

return alpha >= 1 and to or from
end

function Motion.isAnimatable(value: any): boolean
local kind = typeof(value)
return copiers[kind] ~= nil or type(value) == "number"
end

local function isObject(value: any): boolean
local kind = type(value)
return kind == "table" or kind == "userdata" or typeof(value) == "Instance"
end

local ownerTweens = setmetatable({}, { __mode = "k" })

local function trackOwner(owner: any, tween: any)
local list = ownerTweens[owner]
if not list then
list = {}
ownerTweens[owner] = list

pcall(function()
owner.Destroying:Connect(function()
Motion.cancelAll(owner)
end)
end)
end
list[tween] = true
end

local function untrackOwner(owner: any, tween: any)
local list = ownerTweens[owner]
if list then
list[tween] = nil
end
end

function Motion.cancelAll(owner: any): number
local list = ownerTweens[owner]
if not list then
return 0
end
ownerTweens[owner] = nil
local count = 0
for tween in pairs(list) do
tween:cancel()
count += 1
end
return count
end

local ownerProperties = setmetatable({}, { __mode = "k" })

local function claimProperties(target: any, props: { [any]: any }, tween: any)
local claims = ownerProperties[target]
if not claims then
claims = {}
ownerProperties[target] = claims
end
for key in pairs(props) do
local existing = claims[key]
if existing and existing ~= tween then
existing:cancel()
end
claims[key] = tween
end
end

local function releaseProperties(target: any, props: { [any]: any }, tween: any)
local claims = ownerProperties[target]
if not claims then
return
end
for key in pairs(props) do
if claims[key] == tween then
claims[key] = nil
end
end
end

function Motion.trackedOwners(): number
local count = 0
for _ in pairs(ownerTweens) do
count += 1
end
return count
end

local skips = 0

local activeTweens = {}
local activeSprings = {}
local activeTickers = {}
local tweenCount = 0
local springCount = 0
local tickerCount = 0
local connection = nil
local timeScale = 1
local MAX_FRAME_DELTA = 1 / 20
local clock = 0

local function ensureRunning()
if connection then
return
end
if not RunService then
local ok, service = pcall(function()
return game:GetService("RunService")
end)
RunService = ok and service or false
end
if not RunService or not RunService.RenderStepped then

return
end
local event = RunService.RenderStepped
if type(event) == "function" then

connection = { Disconnect = function() end }
event(function(dt)
Motion.step(dt)
end)
return
end
connection = event:Connect(function(dt)
Motion.step(dt)
end)
end

local function stopRunning()
if connection then
connection:Disconnect()
connection = nil
end
end

local function trackTween(tween)
if tween._slot then
return
end
tweenCount += 1
activeTweens[tweenCount] = tween
tween._slot = tweenCount
ensureRunning()
end

local function findTweenSlot(tween): number?
for index = 1, tweenCount do
if activeTweens[index] == tween then
return index
end
end
return nil
end

local function untrackTween(tween)
local slot = tween._slot
tween._slot = nil
if not slot then
return
end

if slot > tweenCount or activeTweens[slot] ~= tween then
slot = findTweenSlot(tween)
if not slot then
return
end
end
local last = activeTweens[tweenCount]
activeTweens[slot] = last
if last then
last._slot = slot
end
activeTweens[tweenCount] = nil
tweenCount -= 1
end

local function trackSpring(spring)
springCount += 1
activeSprings[springCount] = spring
spring._slot = springCount
ensureRunning()
end

local function untrackSpring(spring)
local slot = spring._slot
if not slot then
return
end
local last = activeSprings[springCount]
activeSprings[slot] = last
if last then
last._slot = slot
end
activeSprings[springCount] = nil
springCount -= 1
spring._slot = nil
end

function Motion.setTimeScale(value: number)
timeScale = math.max(0, value)
end

function Motion.getTimeScale(): number
return timeScale
end

function Motion.stats()
return {
tweens = tweenCount,
springs = springCount,
tickers = tickerCount,
total = tweenCount + springCount + tickerCount,
running = connection ~= nil,
}
end

local function trackTicker(ticker)
tickerCount += 1
activeTickers[tickerCount] = ticker
ticker._slot = tickerCount
ensureRunning()
end

local function untrackTicker(ticker)
local slot = ticker._slot
if not slot then
return
end
local last = activeTickers[tickerCount]
activeTickers[slot] = last
if last then
last._slot = slot
end
activeTickers[tickerCount] = nil
tickerCount -= 1
ticker._slot = nil
end

local Ticker = {}
Ticker.__index = Ticker

function Motion.ticker(callback: (number, number, any) -> ()): any
local self = setmetatable({
_callback = callback,
_elapsed = 0,
_paused = false,
_running = true,
}, Ticker)
trackTicker(self)
return self
end

function Ticker:_update(dt: number)
if self._paused then
return
end
self._elapsed += dt
local ok, err = pcall(self._callback, dt, self._elapsed, self)
if not ok then
warn("[Vantage] ticker errored: " .. tostring(err))

self:destroy()
end
end

function Ticker:pause()
self._paused = true
return self
end

function Ticker:resume()
self._paused = false
return self
end

function Ticker:isRunning(): boolean
return self._running and not self._paused
end

function Ticker:elapsed(): number
return self._elapsed
end

function Ticker:reset()
self._elapsed = 0
return self
end

function Ticker:destroy()
self._running = false
self._callback = nil
untrackTicker(self)
end

function Motion.breathe(instance: any, property: string, from: number, to: number, period: number, options: { [any]: any }?): any
local tween = Motion.tween(instance, { [property] = to }, Motion.options({
duration = period * 0.5,
easing = "sineInOut",
repeatCount = -1,
reverse = true,
}, options))
instance[property] = from
return tween
end

function Motion.step(dt: number)
dt = math.min(dt or 0, MAX_FRAME_DELTA) * timeScale
if dt <= 0 then
return
end
clock += dt

for index = tweenCount, 1, -1 do
local tween = activeTweens[index]
if tween then
tween:_update(dt)
else
skips += 1
end
end

for index = springCount, 1, -1 do
local spring = activeSprings[index]
if spring then
spring:_update(dt)
else
skips += 1
end
end

for index = tickerCount, 1, -1 do
local ticker = activeTickers[index]
if ticker then
ticker:_update(dt)
else
skips += 1
end
end

if tweenCount == 0 and springCount == 0 and tickerCount == 0 then
stopRunning()
end
end

function Motion.audit(): { [any]: any }
local holes, tracked, duplicates, strays = 0, 0, 0, 0
local seen = {}
for index = 1, tweenCount do
local tween = activeTweens[index]
if tween == nil then
holes += 1
else
tracked += 1
if seen[tween] then
duplicates += 1
end
seen[tween] = true
end
end

for index = tweenCount + 1, #activeTweens do
if activeTweens[index] ~= nil then
strays += 1
end
end
return {
count = tweenCount,
tracked = tracked,
holes = holes,
duplicates = duplicates,
strays = strays,
skips = skips,
arraySize = #activeTweens,
}
end

function Motion.resetAudit()
skips = 0
end

function Motion.clock(): number
return clock
end

local Tween = {}
Tween.__index = Tween

local Signal = __require("Core.Signal")

local function isReduced()
return Motion._reducedMotion == true
end

function Motion.tween(target: any, props: { [any]: any }, options: { [any]: any }?): any
local opts = options or {}
local self = setmetatable({

_target = target,
_props = props,
_delay = math.max(0, opts.delay or 0),
_duration = math.max(0, opts.duration or Motion.Durations.normal),
_easing = Easing.resolve(opts.easing or "move"),
_repeatCount = opts.repeatCount or 0,
_reverse = opts.reverse == true,
_speed = opts.speed or 1,
_elapsed = 0,
_iteration = 0,
_startValues = nil,
_playing = true,
_finished = false,
_onUpdate = opts.onUpdate,
_onComplete = opts.onComplete,
_owner = isObject(target) and target or nil,
Completed = Signal.new("Tween.Completed"),
Cancelled = Signal.new("Tween.Cancelled"),
}, Tween)

if isReduced() then
self._duration = 0
self._delay = 0
self._easing = Easing.linear
end

if opts.play == false then
self._playing = false
end

if self._owner then
trackOwner(self._owner, self)
end
claimProperties(target, props, self)
if self._playing then
trackTween(self)
self:_update(0)
end
return self
end

function Motion.tweenAll(targets: { any }, props: { [any]: any }, options: { [any]: any }?): { any }
local out = {}
for _, target in ipairs(targets) do
table.insert(out, Motion.tween(target, props, options))
end
return out
end

function Tween:_capture()
if self._startValues then
return
end
local captured = {}
if isObject(self._target) then
for key in pairs(self._props) do
local ok, value = pcall(function()
return self._target[key]
end)
if not ok or value == nil then
if not ok then
warn(string.format("[Vantage] cannot read %s on target; property skipped", tostring(key)))
end
captured[key] = false
else
captured[key] = Motion.copy(value)
end
end
end
self._startValues = captured
end

function Tween:_write(alpha)
local target = self._target
if isObject(target) then
for key, goal in pairs(self._props) do
local start = self._startValues[key]
if start ~= false then
local value = Motion.lerp(start, goal, alpha)
local ok = pcall(function()
target[key] = value
end)
if not ok then
warn(string.format("[Vantage] cannot assign %s on target", tostring(key)))
end
end
end
elseif type(target) == "function" then
target(alpha, self._elapsed, self)
end
end

function Tween:_update(dt)
if not self._playing or self._finished then
return
end

if self._delay > 0 then
self._delay -= dt * self._speed
if self._delay > 0 then
return
end
dt = -self._delay / self._speed
self._delay = 0
end

self:_capture()

self._elapsed += dt * self._speed

local cycle = self._reverse and self._duration * 2 or self._duration

local alpha = cycle <= 0 and 1 or math.min(self._elapsed / cycle, 1)
local eased
if self._reverse then

local phase = alpha * 2
if phase > 1 then
phase = 2 - phase
end
eased = self._easing(phase)
else
eased = self._easing(alpha)
end

self:_write(eased)
if self._onUpdate then
local ok, err = pcall(self._onUpdate, alpha, self._elapsed, self)
if not ok then
warn("[Vantage] tween onUpdate errored: " .. tostring(err))
end
end

if self._elapsed < cycle then
return
end

self._iteration += 1
local looping = self._repeatCount == -1 or self._iteration <= self._repeatCount
if looping then

self._elapsed = cycle > 0 and (self._elapsed % cycle) or 0
return
end

self:_complete()
end

function Tween:_complete()
if self._finished then
return
end
self:_capture()
self:_write(1)
self._finished = true
self._playing = false
untrackTween(self)
releaseProperties(self._target, self._props, self)
if self._owner then
untrackOwner(self._owner, self)
end
if self._onComplete then
local ok, err = pcall(self._onComplete, self)
if not ok then
warn("[Vantage] tween onComplete errored: " .. tostring(err))
end
end
self.Completed:fire(self)
end

function Tween:cancel()
if self._finished and not self._playing then
return
end
self._playing = false
self._finished = true
untrackTween(self)
releaseProperties(self._target, self._props, self)
if self._owner then
untrackOwner(self._owner, self)
end
self.Cancelled:fire(self)
end

function Tween:complete()
if self._finished then
return
end
self:_complete()
end

function Tween:isPlaying(): boolean
return self._playing and not self._finished
end

function Tween:setSpeed(speed: number)
self._speed = speed
end

function Tween:retarget(props: { [any]: any }, options: { [any]: any }?)
releaseProperties(self._target, self._props, self)
claimProperties(self._target, props, self)
if options then
if options.duration then
self._duration = math.max(0, options.duration)
end
if options.easing then
self._easing = Easing.resolve(options.easing)
end
end
self._props = props

self._startValues = nil
self:_capture()
local alpha = self._duration <= 0 and 1 or math.min(self._elapsed / self._duration, 1)
self._elapsed = self._duration * alpha
return self
end

function Tween:resume()
if self._finished then
return self
end
if not self._playing then
self._playing = true
trackTween(self)
end
return self
end

function Tween:pause()
if self._playing and not self._finished then
self._playing = false
untrackTween(self)
end
return self
end

Tween.destroy = Tween.cancel

function Motion.animate(options: { [any]: any }, onUpdate: (number, number, any) -> ()): any
local opts = table.clone(options)
opts.onUpdate = onUpdate
return Motion.tween(function() end, {}, opts)
end

function Motion.stagger(items: { any }, each: number, third: any, fourth: { [any]: any }?)
local created = {}
for index, item in ipairs(items) do
local delay = (index - 1) * each
local tween
if type(third) == "function" then
local result = third(item, index)
if result == nil then
continue
end
local options = table.clone(result)
options.delay = (options.delay or 0) + delay
tween = Motion.tween(item, options.props or {}, options)
else
local options = Motion.options(fourth or "enter", { delay = delay })
tween = Motion.tween(item, third, options)
end
table.insert(created, tween)
end
return created
end

function Motion.sequence(steps: { { [any]: any } }): any
local cancelled = false
local handle = {
cancel = function()
cancelled = true
end,
isPlaying = function()
return not cancelled
end,
}

local index = 0
local function advance()
if cancelled then
return
end
index += 1
local step = steps[index]
if not step then
if handle.Completed then
handle.Completed:fire(handle)
end
return
end
local options = table.clone(step)
local userComplete = step.onComplete
options.onComplete = function(...)
if userComplete then
userComplete(...)
end
advance()
end
local tween = Motion.animate(options, step.onUpdate or function() end)
handle._current = tween
end

handle.Completed = Signal.new("Sequence.Completed")
advance()
return handle
end

function Motion.delay(seconds: number, callback: () -> ()): any
return Motion.tween(function() end, {}, {
duration = seconds,
easing = "linear",
onComplete = callback,
})
end

function Motion.fade(instance: any, alpha: number, options: { [any]: any }?): any
local props = {}
local properties = {
"BackgroundTransparency",
"ImageTransparency",
"TextTransparency",
"TextStrokeTransparency",
}
for _, property in ipairs(properties) do
local ok, value = pcall(function()
return instance[property]
end)
if ok and type(value) == "number" then
props[property] = alpha
end
end
return Motion.tween(instance, props, options)
end

function Motion.ensureScale(instance: any): any
local scale = instance:FindFirstChild("VantageScale")
if not scale then
scale = Instance.new("UIScale")
scale.Name = "VantageScale"
scale.Parent = instance
end
return scale
end

function Motion.setScale(instance: any, value: number): any
local scale = Motion.ensureScale(instance)
scale.Scale = value
return scale
end

function Motion.scale(instance: any, value: number, options: { [any]: any }?): any
local scale = Motion.ensureScale(instance)
return Motion.tween(scale, { Scale = value }, Motion.options("hover", options))
end

function Motion.pulse(instance: any, amount: number, options: { [any]: any }?): any
local scale = Motion.ensureScale(instance)
local out = Motion.options("press", options)
return Motion.tween(scale, { Scale = amount }, out)
end

local Spring = {}
Spring.__index = Spring

function Motion.spring(config: { [any]: any }?)
local cfg = config or {}
local response = math.max(0.01, cfg.response or cfg.tension and 0.3 or 0.32)
local damping = cfg.damping or cfg.friction and 0.9 or 0.86

local self = setmetatable({
_value = cfg.initial or 0,
_goal = cfg.initial or 0,
_velocity = 0,
_response = response,
_damping = damping,
_atRest = true,
_paused = false,
_epsilon = cfg.epsilon or 0.0004,
_listeners = {},
_driving = cfg.driving == true,
}, Spring)

if self._driving then
self._paused = false
end

return self
end

function Spring:setGoal(goal: number)
if self._goal == goal then
return self
end
self._goal = goal
if self._value == goal and math.abs(self._velocity) < self._epsilon then
return self
end
self._atRest = false
trackSpring(self)
return self
end

function Spring:snap(value: number)
self._value = value
self._goal = value
self._velocity = 0
self._atRest = true
untrackSpring(self)
self:_notify()
return self
end

function Spring:get(): number
return self._value
end

function Spring:getGoal(): number
return self._goal
end

function Spring:getVelocity(): number
return self._velocity
end

function Spring:isAtRest(): boolean
return self._atRest
end

function Spring:isSettled(tolerance: number?): boolean
local limit = tolerance or self._epsilon
return math.abs(self._goal - self._value) <= limit
and math.abs(self._velocity) <= limit * 20
end

function Spring:observe(callback: (number, any) -> ())
table.insert(self._listeners, callback)
callback(self._value, self)
return function()
local index = table.find(self._listeners, callback)
if index then
table.remove(self._listeners, index)
end
end
end

function Spring:setDriving(driving: boolean)
self._driving = driving
if driving then
self._atRest = false
trackSpring(self)
elseif self:isSettled() then
self._atRest = true
untrackSpring(self)
end
return self
end

function Spring:push(value: number)
self._value = value
self._atRest = false
trackSpring(self)
self:_notify()
return self
end

function Spring:impulse(velocity: number)
self._velocity += velocity
if math.abs(velocity) > 0 then
self._atRest = false
trackSpring(self)
end
return self
end

function Spring:_notify()
for index = #self._listeners, 1, -1 do
local listener = self._listeners[index]
local ok, err = pcall(listener, self._value, self)
if not ok then
warn("[Vantage] spring observer errored: " .. tostring(err))
table.remove(self._listeners, index)
end
end
end

local SUB_STEP = 1 / 240

function Spring:_update(dt)
if self._paused then
return
end

local remaining = dt
while remaining > 1e-6 do
local step = math.min(SUB_STEP, remaining)
remaining -= step

local omega = (2 * math.pi) / self._response
local zeta = self._damping

local displacement = self._value - self._goal
local acceleration = -omega * omega * displacement - 2 * zeta * omega * self._velocity
self._velocity += acceleration * step
self._value += self._velocity * step
end

self:_notify()

local settled = math.abs(self._goal - self._value) < self._epsilon
and math.abs(self._velocity) < self._epsilon * 12
if settled then
self._value = self._goal
self._velocity = 0
if not self._driving then
self._atRest = true
untrackSpring(self)
end
end
end

function Spring:finish()
self._value = self._goal
self._velocity = 0
self:_notify()
self._atRest = true
untrackSpring(self)
end

function Spring:destroy()
self._listeners = {}
self._atRest = true
untrackSpring(self)
end

Motion.springs = {
precise = { response = 0.22, damping = 1.0 },
snappy = { response = 0.28, damping = 0.9 },
quick = { response = 0.32, damping = 0.86 },
standard = { response = 0.42, damping = 0.88 },
gentle = { response = 0.62, damping = 0.9 },
glacial = { response = 1.1, damping = 0.95 },
bouncy = { response = 0.42, damping = 0.6 },
elastic = { response = 0.5, damping = 0.42 },
stiff = { response = 0.38, damping = 1.0 },
}

function Motion.springFrom(name: string, initial: number?): any
local preset = Motion.springs[name] or Motion.springs.quick
local config = table.clone(preset)
config.initial = initial or 0
return Motion.spring(config)
end

local AnimatedValue = {}
AnimatedValue.__index = AnimatedValue

function Motion.value(initial: number, config: { [any]: any }?): any
local cfg = table.clone(config or {})
cfg.initial = initial or 0
local spring = Motion.spring(cfg)
local self = setmetatable({
_spring = spring,
_listeners = {},
}, AnimatedValue)

spring:observe(function(value)
for index = #self._listeners, 1, -1 do
local ok, err = pcall(self._listeners[index], value)
if not ok then
warn("[Vantage] animated value listener errored: " .. tostring(err))
table.remove(self._listeners, index)
end
end
end)

return self
end

function AnimatedValue:set(goal: number)
self._spring:setGoal(goal)
return self
end

function AnimatedValue:snap(value: number)
self._spring:snap(value)
return self
end

function AnimatedValue:get(): number
return self._spring:get()
end

function AnimatedValue:observe(callback: (number) -> ())
table.insert(self._listeners, callback)
callback(self._spring:get())
return function()
local index = table.find(self._listeners, callback)
if index then
table.remove(self._listeners, index)
end
end
end

function AnimatedValue:destroy()
table.clear(self._listeners)
self._spring:destroy()
end

function Motion.setReducedMotion(enabled: boolean)
Motion._reducedMotion = enabled == true
end

function Motion.getReducedMotion(): boolean
return Motion._reducedMotion == true
end

return Motion
end

__modules["Core.Util"] = function()

local Util = {}

function Util.clamp(value: number, min: number, max: number): number
if value < min then
return min
elseif value > max then
return max
end
return value
end

function Util.clamp01(value: number): number
return Util.clamp(value, 0, 1)
end

function Util.lerp(a: number, b: number, alpha: number): number
return a + (b - a) * alpha
end

function Util.map(value: number, inMin: number, inMax: number, outMin: number, outMax: number): number
if inMax == inMin then
return outMin
end
return outMin + (value - inMin) / (inMax - inMin) * (outMax - outMin)
end

function Util.inverseLerp(a: number, b: number, value: number): number
if a == b then
return 0
end
return Util.clamp01((value - a) / (b - a))
end

function Util.round(value: number, places: number?): number
local factor = 10 ^ (places or 0)
return math.floor(value * factor + 0.5) / factor
end

function Util.snap(value: number, step: number?): number
if not step or step <= 0 then
return value
end
return math.floor(value / step + 0.5) * step
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Util.compact(value: number, places: number?): string
local sign = value < 0 and "-" or ""
value = math.abs(value)
if value < 1000 then
return sign .. tostring(Util.round(value, places or 0))
end
local tier = math.floor(math.log(value, 1000))
tier = math.min(tier, #SUFFIXES)
local scaled = value / 1000 ^ tier
local decimals = scaled < 10 and 2 or (scaled < 100 and 1 or 0)
return sign .. string.format("%." .. decimals .. "f", scaled) .. SUFFIXES[tier + 1]
end

function Util.commas(value: number, places: number?): string
local rounded = Util.round(value, places or 0)
local text = string.format("%." .. (places or 0) .. "f", math.abs(rounded))
local whole, fraction = string.match(text, "^(%d+)(%.?.*)$")
whole = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
return (rounded < 0 and "-" or "") .. whole .. (fraction or "")
end

function Util.count(value: number): string
local rounded = Util.round(value, 1)
if rounded == math.floor(rounded) then
return Util.commas(rounded, 0)
end
return Util.commas(rounded, 1)
end

function Util.percent(fraction: number, places: number?): string
return string.format("%." .. (places or 0) .. "f%%", fraction * 100)
end

function Util.padNumber(value: number, width: number?): string
local text = tostring(value)
local target = width or 3
while #text < target do
text = " " .. text
end
return text
end

function Util.duration(seconds: number): string
seconds = math.max(0, math.floor(seconds))
local hours = math.floor(seconds / 3600)
local minutes = math.floor((seconds % 3600) / 60)
local secs = seconds % 60
if hours > 0 then
return string.format("%d:%02d:%02d", hours, minutes, secs)
elseif minutes > 0 then
return string.format("%d:%02d", minutes, secs)
end
return string.format("%ds", secs)
end

function Util.bytes(value: number): string
local units = { "B", "KB", "MB", "GB" }
local index = 1
while value >= 1024 and index < #units do
value /= 1024
index += 1
end
return string.format("%.1f %s", value, units[index])
end

function Util.millis(seconds: number): string
if seconds < 1 then
return string.format("%.0f ms", seconds * 1000)
end
return string.format("%.2f s", seconds)
end

function Util.copy(source: { [any]: any }): { [any]: any }
local out = table.create(#source)
for key, value in pairs(source) do
out[key] = value
end
return out
end

function Util.deepMerge(target: { [any]: any }, patch: { [any]: any }?): { [any]: any }
local out = Util.copy(target)
if not patch then
return out
end
for key, value in pairs(patch) do
if type(value) == "table" and type(out[key]) == "table" then
out[key] = Util.deepMerge(out[key], value)
else
out[key] = value
end
end
return out
end

function Util.deepCopy(source: any): any
if type(source) ~= "table" then
return source
end
local out = {}
for key, value in pairs(source) do
out[key] = Util.deepCopy(value)
end
return out
end

function Util.filter(source: { any }, predicate: (any, number) -> boolean): { any }
local out = table.create(#source)
for index, value in ipairs(source) do
if predicate(value, index) then
table.insert(out, value)
end
end
return out
end

function Util.mapList(source: { any }, transform: (any, number) -> any): { any }
local out = table.create(#source)
for index, value in ipairs(source) do
out[index] = transform(value, index)
end
return out
end

function Util.reduce(source: { any }, reducer: (any, any) -> any, initial: any): any
local accumulator = initial
for _, value in ipairs(source) do
accumulator = reducer(accumulator, value)
end
return accumulator
end

local function clampByte(value: number): number
return math.floor(Util.clamp(value, 0, 255) + 0.5)
end

function Util.hexToColor(hex: string): (Color3, number)
local cleaned = hex:gsub("#", ""):gsub("%s", "")
if #cleaned == 3 then
cleaned = cleaned:sub(1, 1):rep(2) .. cleaned:sub(2, 2):rep(2) .. cleaned:sub(3, 3):rep(2)
end
if #cleaned ~= 6 and #cleaned ~= 8 then
warn(string.format("[Vantage] malformed hex colour %q, using magenta", hex))
return Color3.fromRGB(255, 0, 255), 1
end
local r = tonumber(cleaned:sub(1, 2), 16) or 0
local g = tonumber(cleaned:sub(3, 4), 16) or 0
local b = tonumber(cleaned:sub(5, 6), 16) or 0
local a = 1
if #cleaned == 8 then
a = (tonumber(cleaned:sub(7, 8), 16) or 255) / 255
end
return Color3.fromRGB(r, g, b), a
end

function Util.colorToHex(color: Color3, alpha: number?): string
local r = clampByte(color.R * 255)
local g = clampByte(color.G * 255)
local b = clampByte(color.B * 255)
if alpha then
return string.format("#%02X%02X%02X%02X", r, g, b, clampByte(alpha * 255))
end
return string.format("#%02X%02X%02X", r, g, b)
end

function Util.mixColor(a: Color3, b: Color3, alpha: number): Color3
return Color3.new(
Util.lerp(a.R, b.R, alpha),
Util.lerp(a.G, b.G, alpha),
Util.lerp(a.B, b.B, alpha)
)
end

function Util.lighten(color: Color3, amount: number): Color3
return Util.mixColor(color, Color3.new(1, 1, 1), amount)
end

function Util.darken(color: Color3, amount: number): Color3
return Util.mixColor(color, Color3.new(0, 0, 0), amount)
end

function Util.luminance(color: Color3): number
local function channel(c: number): number
if c <= 0.03928 then
return c / 12.92
end
return ((c + 0.055) / 1.055) ^ 2.4
end
return 0.2126 * channel(color.R) + 0.7152 * channel(color.G) + 0.0722 * channel(color.B)
end

function Util.contrast(a: Color3, b: Color3): number
local la, lb = Util.luminance(a), Util.luminance(b)
local lighter = math.max(la, lb)
local darker = math.min(la, lb)
return (lighter + 0.05) / (darker + 0.05)
end

function Util.contrastText(background: Color3, dark: Color3?, light: Color3?): Color3
local darkColor = dark or Color3.fromRGB(14, 12, 10)
local lightColor = light or Color3.fromRGB(250, 250, 252)
if Util.contrast(background, darkColor) >= Util.contrast(background, lightColor) then
return darkColor
end
return lightColor
end

function Util.ensureContrast(color: Color3, background: Color3, target: number): Color3
if Util.contrast(color, background) >= target then
return color
end
local towardLight = Util.luminance(background) < 0.4
for step = 1, 20 do
local candidate = towardLight
and Util.lighten(color, step * 0.04)
or Util.darken(color, step * 0.04)
if Util.contrast(candidate, background) >= target or step == 20 then
return candidate
end
end
return color
end

Util.fontStack = {
display = Enum.Font.GothamBlack,
heading = Enum.Font.GothamBold,
subheading = Enum.Font.GothamMedium,
body = Enum.Font.Gotham,
bodyMedium = Enum.Font.GothamMedium,
bodyBold = Enum.Font.GothamBold,
mono = Enum.Font.RobotoMono,
}

Util.fontKeys = {
"display", "heading", "subheading", "body", "bodyMedium", "bodyBold", "mono",
}

function Util.applyFont(instance: any, key: string?)
local fontEnum = Util.fontStack[key or "body"] or Util.fontStack.body
local ok = pcall(function()
instance.Font = fontEnum
end)
if not ok and instance:IsA("TextLabel") then

pcall(function()
instance.FontFace = Font.fromEnum(fontEnum)
end)
end
pcall(function()
instance.FontFace = Font.fromEnum(fontEnum)
end)
return instance
end

local TextService

function Util.measureText(text: string, font: any, size: number, frameSize: any?): any
if not TextService then
local ok, service = pcall(function()
return game:GetService("TextService")
end)
TextService = ok and service or false
end
if TextService and TextService.GetTextSize then
local ok, result = pcall(function()
return TextService:GetTextSize(
text,
size,
font or Enum.Font.Gotham,
frameSize or Vector2.new(1000000, 1000000)
)
end)
if ok then
return result
end
end

return Vector2.new(#text * size * 0.54, size * 1.25)
end

function Util.splitGraphemes(text: string): { string }
local out = {}
for _, code in utf8.codes(text) do
table.insert(out, utf8.char(code))
end
return out
end

function Util.titleCase(text: string): string
local spaced = text:gsub("(%l)(%u)", "%1 %2"):gsub("[_%-]+", " ")
local out = {}
for word in spaced:gmatch("%S+") do
table.insert(out, word:sub(1, 1):upper() .. word:sub(2))
end
return table.concat(out, " ")
end

function Util.wrapText(text: string, maxChars: number): string
local lines, current = {}, {}
local length = 0
for word in text:gmatch("%S+") do
local wordLength = #word
if length > 0 and length + wordLength + 1 > maxChars then
table.insert(lines, table.concat(current, " "))
current, length = {}, 0
end
table.insert(current, word)
length += wordLength + (length > 0 and 1 or 0)
end
if #current > 0 then
table.insert(lines, table.concat(current, " "))
end
return table.concat(lines, "\n")
end

function Util.escapeRichText(text: string): string
return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function Util.fuzzyMatch(query: string, target: string, previous: { number }?): (number?, { number }?)
if query == "" then
return 1, {}
end
local lowerQuery = query:lower()
local lowerTarget = target:lower()
if #lowerQuery > #lowerTarget then
return nil, nil
end

local score = 0
local matches = {}
local targetIndex = 1
local previousIndex = -1

for queryIndex = 1, #lowerQuery do
local char = lowerQuery:sub(queryIndex, queryIndex)
if char == " " then
continue
end
local found = lowerTarget:find(char, targetIndex, true)
if not found then
return nil, nil
end

local isWordStart = found == 1
or lowerTarget:sub(found - 1, found - 1):match("[%s_%-%./]") ~= nil
or target:sub(found, found):match("%u") ~= nil

score += 10
if isWordStart then
score += 22
end
if previousIndex == found - 1 then
score += 30
else
score -= math.min(found - targetIndex, 14)
end
if queryIndex == 1 and found == 1 then
score += 16
end

previousIndex = found
targetIndex = found + 1
table.insert(matches, found)
end

score -= math.floor(#target * 0.4)

if previous then
for index = 1, math.max(#previous, #matches) do
if previous[index] ~= matches[index] then
score += 6
break
end
end
end

return score, matches
end

function Util.create(className: string, properties: { [string]: any }?, children: { any }?): any
local instance = Instance.new(className)
local fontKey: string? = nil
if properties then
for key, value in pairs(properties) do
if key ~= "Parent" and value ~= nil then
if key == "Font" and type(value) == "string" then

fontKey = value
else
instance[key] = value
end
end
end
end
if fontKey then
Util.applyFont(instance, fontKey)
end
if children then
for _, child in ipairs(children) do
child.Parent = instance
end
end
if properties and properties.Parent then
instance.Parent = properties.Parent
end
return instance
end

function Util.frame(properties: { [string]: any }?, children: { any }?): any
local frame = Util.create("Frame", properties, children)
frame.BorderSizePixel = 0
if frame.BackgroundTransparency == nil then
frame.BackgroundTransparency = 0
end
return frame
end

function Util.row(properties: { [string]: any }?, children: { any }?): any
local merged = Util.copy(properties or {})
merged.BackgroundTransparency = merged.BackgroundTransparency or 1
return Util.frame(merged, children)
end

function Util.group(properties: { [string]: any }?, children: { any }?): any
local merged = Util.copy(properties or {})
merged.BackgroundTransparency = merged.BackgroundTransparency or 1
local group = Util.create("CanvasGroup", merged, children)
group.BorderSizePixel = 0
return group
end

function Util.text(properties: { [string]: any }?, children: { any }?): any
local merged = Util.copy(properties or {})
merged.BackgroundTransparency = 1
merged.TextColor3 = merged.TextColor3 or Color3.fromRGB(235, 235, 242)
merged.TextXAlignment = merged.TextXAlignment or Enum.TextXAlignment.Left
merged.TextYAlignment = merged.TextYAlignment or Enum.TextYAlignment.Center
if merged.TextSize == nil then
merged.TextSize = 13
end
local label = Util.create("TextLabel", merged, children)
Util.applyFont(label, merged.Font or "body")
label.RichText = merged.RichText or false
return label
end

function Util.image(properties: { [string]: any }?, children: { any }?): any
return Util.create("ImageLabel", properties, children)
end

function Util.corner(instance: any, radius: number?): any
local corner = instance:FindFirstChildOfClass("UICorner")
if not corner then
corner = Instance.new("UICorner")
corner.Parent = instance
end
corner.CornerRadius = UDim.new(0, radius or 0)
return corner
end

function Util.pill(instance: any): any
return Util.corner(instance, 999)
end

function Util.stroke(instance: any, color: any, thickness: number?, transparency: number?): any
local stroke = instance:FindFirstChildOfClass("UIStroke")
if not stroke then
stroke = Instance.new("UIStroke")
stroke.Parent = instance
end
stroke.Color = color or Color3.fromRGB(60, 60, 70)
stroke.Thickness = thickness or 1
stroke.Transparency = transparency or 0
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
if stroke.LineJoinMode == nil then
pcall(function()
stroke.LineJoinMode = Enum.LineJoinMode.Round
end)
end
return stroke
end

function Util.gradient(instance: any, keypoints: { any }, rotation: number?, enabled: boolean?): any
local gradient = instance:FindFirstChildOfClass("UIGradient")
if not gradient then
gradient = Instance.new("UIGradient")
gradient.Parent = instance
end

local count = #keypoints
if count == 0 then
gradient.Enabled = false
return gradient
end

local times = table.create(count)
local previous = 0
for index, keypoint in ipairs(keypoints) do
local time = keypoint.Time
if time == nil then
time = count == 1 and 0 or (index - 1) / (count - 1)
end
time = Util.clamp01(time)
if time < previous then
time = previous
end
previous = time
times[index] = time
end

if count == 1 then

gradient.Color = ColorSequence.new(keypoints[1].Color or Color3.new(1, 1, 1))
gradient.Transparency = NumberSequence.new(Util.clamp01(keypoints[1].Transparency or 0))
else

times[1] = 0
times[count] = 1

local colorStops = table.create(count)
local stops = table.create(count)
for index = 1, count do
colorStops[index] = ColorSequenceKeypoint.new(times[index], keypoints[index].Color or Color3.new(1, 1, 1))
stops[index] = NumberSequenceKeypoint.new(times[index], Util.clamp01(keypoints[index].Transparency or 0))
end

gradient.Color = ColorSequence.new(colorStops)
gradient.Transparency = NumberSequence.new(stops)
end

gradient.Rotation = rotation or 0
gradient.Enabled = enabled ~= false
return gradient
end

function Util.pad(instance: any, padding: { [string]: number }): any
local uiPadding = instance:FindFirstChildOfClass("UIPadding")
if not uiPadding then
uiPadding = Instance.new("UIPadding")
uiPadding.Parent = instance
end
if padding.Top then
uiPadding.PaddingTop = UDim.new(0, padding.Top)
end
if padding.Bottom then
uiPadding.PaddingBottom = UDim.new(0, padding.Bottom)
end
if padding.Left then
uiPadding.PaddingLeft = UDim.new(0, padding.Left)
end
if padding.Right then
uiPadding.PaddingRight = UDim.new(0, padding.Right)
end
return uiPadding
end

function Util.list(instance: any, properties: { [string]: any }?): any
local layout = instance:FindFirstChildOfClass("UIListLayout")
if not layout then
layout = Instance.new("UIListLayout")
layout.Parent = instance
end
if properties then
for key, value in pairs(properties) do
layout[key] = value
end
end
return layout
end

function Util.stack(instance: any, padding: number?, alignment: any?): any
return Util.list(instance, {
FillDirection = Enum.FillDirection.Vertical,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, padding or 0),
HorizontalAlignment = alignment or Enum.HorizontalAlignment.Left,
})
end

function Util.clipRounded(instance: any, radius: number): any
instance.ClipsDescendants = true
return Util.corner(instance, radius)
end

function Util.sizeConstraint(instance: any, min: any?, max: any?): any
local constraint = instance:FindFirstChildOfClass("UISizeConstraint")
if not constraint then
constraint = Instance.new("UISizeConstraint")
constraint.Parent = instance
end
if min then
constraint.MinSize = min
end
if max then
constraint.MaxSize = max
end
return constraint
end

function Util.tag(instance: any, tagName: string)
local ok, service = pcall(function()
return game:GetService("CollectionService")
end)
if ok and service then
pcall(function()
service:AddTag(instance, tagName)
end)
end
return instance
end

function Util.name(instance: any, name: string, debugLabel: string?): any
instance.Name = debugLabel and string.format("Vantage%s_%s", name, debugLabel) or ("Vantage" .. name)
return instance
end

function Util.safeCall(callback: any, ...): boolean
if type(callback) ~= "function" then
return false
end
local ok, err = xpcall(callback, function(e)
return tostring(e) .. "\n" .. debug.traceback("", 2)
end, ...)
if not ok then
warn("[Vantage] callback error: " .. tostring(err))
return false
end
return true
end

function Util.defer(callback: () -> ())
if task and task.defer then
task.defer(Util.safeCall, callback)
else
coroutine.wrap(Util.safeCall)(callback)
end
end

function Util.debounce(callback: (...any) -> (), delay: number)
local token = 0
return function(...)
token += 1
local mine = token
local args = table.pack(...)
task.delay(delay, function()
if mine == token then
Util.safeCall(callback, table.unpack(args, 1, args.n))
end
end)
end
end

function Util.throttle(callback: (...any) -> (), interval: number)
local last = 0
local queued = nil
local args = nil
return function(...)
local now = os.clock()
if now - last >= interval then
last = now
Util.safeCall(callback, ...)
elseif not queued then
args = table.pack(...)
queued = true
task.delay(interval - (now - last), function()
queued = false
last = os.clock()
Util.safeCall(callback, table.unpack(args, 1, args.n))
end)
end
end
end

local uidCounter = 0

function Util.uid(prefix: string?): string
uidCounter += 1
return string.format("%s%d", prefix or "v", uidCounter)
end

function Util.isDescendantOf(instance: any, ancestor: any): boolean
local current = instance
while current do
if current == ancestor then
return true
end
current = current.Parent
end
return false
end

function Util.walk(root: any, className: string?, visit: (any) -> ())
for _, child in ipairs(root:GetChildren()) do
if not className or child:IsA(className) then
visit(child)
end
Util.walk(child, className, visit)
end
end

local GuiService, UserInputService
Util._insetCache = nil
Util._insetCacheAt = 0

function Util.insets()
local now = os.clock()
if Util._insetCache and now - Util._insetCacheAt < 1 then
return Util._insetCache
end

if not GuiService then
local ok, service = pcall(function()
return game:GetService("GuiService")
end)
GuiService = ok and service or false
end
if not UserInputService then
local ok, service = pcall(function()
return game:GetService("UserInputService")
end)
UserInputService = ok and service or false
end

local top, bottom, left, right = 0, 0, 0, 0
if GuiService and GuiService.GetGuiInset then
local ok, inset = pcall(function()
return GuiService:GetGuiInset()
end)
if ok and inset then
top = inset.Y
left = inset.X
end
end

local touch = false
if UserInputService and UserInputService.TouchEnabled ~= nil then
touch = UserInputService.TouchEnabled == true
end
local isPhone = touch
if isPhone then

bottom = 24
left = math.max(left, 12)
right = math.max(right, 12)
end

Util._insetCache = { top = top, bottom = bottom, left = left, right = right }
Util._insetCacheAt = now
return Util._insetCache
end

function Util.viewport(): any
local camera = workspace and workspace.CurrentCamera
if camera then
local size = camera.ViewportSize
if size and size.X > 0 then
return size
end
end
return Vector2.new(1920, 1080)
end

function Util.breakpoint(width: number?): string
local w = width or Util.viewport().X
if w < 600 then
return "phone"
elseif w < 1000 then
return "tablet"
elseif w < 1500 then
return "compact"
end
return "desktop"
end

function Util.uiScale(baseWidth: number?): number
local width = Util.viewport().X
local reference = baseWidth or 1920

local raw = width / reference
return Util.clamp(0.78 + (raw - 0.78) * 0.62, 0.72, 1.35)
end

function Util.isTouch(): boolean
if not UserInputService then
pcall(function()
UserInputService = game:GetService("UserInputService")
end)
end
return UserInputService ~= nil
and UserInputService ~= false
and UserInputService.TouchEnabled == true
and UserInputService.KeyboardEnabled == false
end

function Util.prefersReducedMotion(): boolean
if not UserInputService then
pcall(function()
UserInputService = game:GetService("UserInputService")
end)
end
if UserInputService and UserInputService ~= false then
local ok, value = pcall(function()
return UserInputService.ReducedMotionEnabled
end)
if ok and value ~= nil then
return value == true
end
end
return false
end

function Util.arrayEquals(a: { any }, b: { any }): boolean
if #a ~= #b then
return false
end
for index = 1, #a do
if a[index] ~= b[index] then
return false
end
end
return true
end

Util.version = "1.0.0"
Util.build = "stable"

return Util
end

__modules["Core.Config"] = function()

local Signal = __require("Core.Signal")

local Config = {}

Config.name = "Vantage"
Config.version = "1.0.0"
Config.build = "1.0.0-stable"

Config.animations = true

Config.respectSystemReducedMotion = true

Config.allowWarnings = true

Config.debug = false

Config.tagging = true
Config.tag = "Vantage"

Config.sounds = {
enabled = true,
volume = 0.35,
hover = "",
click = "rbxasset://sounds/electronicpingshort.wav",
toggle = "rbxasset://sounds/electronicpingshort.wav",
open = "rbxasset://sounds/electronicpingshort.wav",
close = "rbxasset://sounds/electronicpingshort.wav",
notify = "rbxasset://sounds/electronicpingshort.wav",
error = "",
}

Config.isolateControls = false

Config.keybinds = {
toggleInterface = Enum.KeyCode.RightShift,
commandPalette = Enum.KeyCode.K,
commandPaletteModifier = Enum.KeyCode.LeftControl,
closeOverlay = Enum.KeyCode.Escape,
}

Config.persistence = {
load = nil :: ((key: string) -> any?)?,
save = nil :: ((key: string, value: any) -> ())?,
}

Config.defaults = {
theme = "obsidian",
size = UDim2.fromOffset(680, 440),
position = UDim2.fromScale(0.5, 0.5),
anchor = Vector2.new(0.5, 0.5),
minSize = Vector2.new(420, 300),
resizable = true,
draggable = true,
closeOnEscape = true,
sidebarWidth = 168,
titleBarHeight = 40,
statusBarHeight = 24,
uiScale = nil :: number?,
}

Config.Changed = Signal.new("Config.Changed")

local internal = {}
for key, value in pairs(Config) do
internal[key] = value
end

function Config.get(key: string): any
return Config[key]
end

function Config.set(key: string, value: any)
local previous = Config[key]
if previous == value then
return
end
Config[key] = value
if key == "animations" then
local Motion = __require("Core.Motion")
Motion.setReducedMotion(not (value == true)
or (Config.respectSystemReducedMotion and __require("Core.Util").prefersReducedMotion()))
end
Config.Changed:fire(key, value, previous)
if Config.debug then
print(string.format("[Vantage] config.%s = %s", key, tostring(value)))
end
end

function Config.merge(patch: { [string]: any })
for key, value in pairs(patch) do
Config.set(key, value)
end
end

function Config.observe(key: any, callback: (any, any, any) -> ())
if key ~= nil then
callback(key, Config[key], nil)
end
local connection = Config.Changed:connect(function(changedKey, value, previous)
if key == nil or changedKey == key then
callback(changedKey, value, previous)
end
end)
return function()
connection:disconnect()
end
end

function Config.reset()
for key, value in pairs(internal) do
if type(value) ~= "function" and type(value) ~= "table" then
Config.set(key, value)
end
end
end

return Config
end

__modules["Core.Glyph"] = function()

local Util = __require("Core.Util")

local Glyph = {}

local GRID = 100

local function stroke(parent: any, x1: number, y1: number, x2: number, y2: number, weight: number, unit: number, color: any, zIndex: number)
local dx, dy = x2 - x1, y2 - y1
local length = math.sqrt(dx * dx + dy * dy)
local angle = math.deg(math.atan2(dy, dx))
local thickness = math.max(1, weight * unit)
local bar = Util.frame({
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.fromOffset((x1 + x2) * 0.5 * unit, (y1 + y2) * 0.5 * unit),

Size = UDim2.fromOffset(length * unit + thickness * 0.5, thickness),
Rotation = angle,
BackgroundColor3 = color,
ZIndex = zIndex,
Parent = parent,
})
Util.pill(bar)
return bar
end

local function polyline(parent: any, points: { any }, weight: number, unit: number, color: any, zIndex: number, closed: boolean?)
for index = 1, #points - 1 do
local a, b = points[index], points[index + 1]
stroke(parent, a[1], a[2], b[1], b[2], weight, unit, color, zIndex)
end
if closed and #points > 2 then
local a, b = points[#points], points[1]
stroke(parent, a[1], a[2], b[1], b[2], weight, unit, color, zIndex)
end
end

local function arcPoints(cx: number, cy: number, radius: number, startDeg: number, endDeg: number, segments: number?): { any }
local steps = segments or math.max(6, math.floor(math.abs(endDeg - startDeg) / 9))
local points = table.create(steps + 1)
for index = 0, steps do
local angle = math.rad(startDeg + (endDeg - startDeg) * (index / steps))
points[index + 1] = { cx + math.cos(angle) * radius, cy + math.sin(angle) * radius }
end
return points
end

local function disc(parent: any, cx: number, cy: number, radius: number, unit: number, color: any, zIndex: number)
local size = radius * 2 * unit
local dot = Util.frame({
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.fromOffset(cx * unit, cy * unit),
Size = UDim2.fromOffset(size, size),
BackgroundColor3 = color,
ZIndex = zIndex,
Parent = parent,
})
Util.pill(dot)
return dot
end

local function ring(parent: any, cx: number, cy: number, radius: number, weight: number, unit: number, color: any, zIndex: number)
local size = radius * 2 * unit
local frame = Util.frame({
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.fromOffset(cx * unit, cy * unit),
Size = UDim2.fromOffset(size, size),
BackgroundTransparency = 1,
ZIndex = zIndex,
Parent = parent,
})
Util.pill(frame)
Util.stroke(frame, color, math.max(1, weight * unit), 0)
return frame
end

Glyph.definitions = {}

local function define(name: string, painter: (any, number, any, number, number) -> ())
Glyph.definitions[name] = painter
end

local function pointsLine(list: { any }): { any }
local points = table.create(#list / 2)
for index = 1, #list, 2 do
points[#points + 1] = { list[index], list[index + 1] }
end
return points
end

define("check", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 22, 52, 42, 72, 78, 28 }), weight, unit, color, z)
end)

define("close", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 27, 27, 73, 73 }), weight, unit, color, z)
polyline(parent, pointsLine({ 73, 27, 27, 73 }), weight, unit, color, z)
end)

define("plus", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 50, 22, 50, 78 }), weight, unit, color, z)
polyline(parent, pointsLine({ 22, 50, 78, 50 }), weight, unit, color, z)
end)

define("minus", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 22, 50, 78, 50 }), weight, unit, color, z)
end)

define("chevron-down", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 26, 38, 50, 64, 74, 38 }), weight, unit, color, z)
end)

define("chevron-up", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 26, 62, 50, 36, 74, 62 }), weight, unit, color, z)
end)

define("chevron-left", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 62, 26, 36, 50, 62, 74 }), weight, unit, color, z)
end)

define("chevron-right", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 38, 26, 64, 50, 38, 74 }), weight, unit, color, z)
end)

define("arrow-right", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 18, 50, 78, 50 }), weight, unit, color, z)
polyline(parent, pointsLine({ 54, 26, 78, 50, 54, 74 }), weight, unit, color, z)
end)

define("arrow-left", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 82, 50, 22, 50 }), weight, unit, color, z)
polyline(parent, pointsLine({ 46, 26, 22, 50, 46, 74 }), weight, unit, color, z)
end)

define("arrow-up", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 50, 82, 50, 22 }), weight, unit, color, z)
polyline(parent, pointsLine({ 26, 46, 50, 22, 74, 46 }), weight, unit, color, z)
end)

define("arrow-down", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 50, 18, 50, 78 }), weight, unit, color, z)
polyline(parent, pointsLine({ 26, 54, 50, 78, 74, 54 }), weight, unit, color, z)
end)

define("search", function(parent, unit, color, weight, z)
ring(parent, 44, 44, 24, weight, unit, color, z)
polyline(parent, pointsLine({ 62, 62, 82, 82 }), weight, unit, color, z)
end)

define("dot", function(parent, unit, color, weight, z)
disc(parent, 50, 50, weight * 0.9, unit, color, z)
end)

define("sparkle", function(parent, unit, color, weight, z)

local long = weight * 0.55
polyline(parent, pointsLine({ 50, 8, 50, 92 }), long, unit, color, z)
polyline(parent, pointsLine({ 8, 50, 92, 50 }), long, unit, color, z)
polyline(parent, pointsLine({ 28, 28, 72, 72 }), long * 0.42, unit, color, z)
polyline(parent, pointsLine({ 72, 28, 28, 72 }), long * 0.42, unit, color, z)
end)

define("star", function(parent, unit, color, weight, z)
local points = {}
for index = 1, 10 do
local angle = math.rad(-90 + (index - 1) * 36)
local radius = index % 2 == 1 and 40 or 17
points[#points + 1] = { 50 + math.cos(angle) * radius, 50 + math.sin(angle) * radius }
end
polyline(parent, points, weight * 0.72, unit, color, z, true)
end)

define("ellipsis", function(parent, unit, color, weight, z)
for _, x in ipairs({ 24, 50, 76 }) do
disc(parent, x, 50, weight * 0.62, unit, color, z)
end
end)

define("hamburger", function(parent, unit, color, weight, z)
for _, y in ipairs({ 30, 50, 70 }) do
polyline(parent, pointsLine({ 20, y, 80, y }), weight, unit, color, z)
end
end)

define("sliders", function(parent, unit, color, weight, z)
local rows = { { 32, 38 }, { 52, 66 }, { 72, 24 } }
for _, row in ipairs(rows) do
polyline(parent, pointsLine({ 18, row[1], 82, row[1] }), weight * 0.8, unit, color, z)
disc(parent, row[2], row[1], weight * 1.15, unit, color, z + 1)
end
end)

define("wave", function(parent, unit, color, weight, z)
local points = {}
for index = 0, 24 do
local x = 12 + index * 3.2
points[#points + 1] = { x, 50 + math.sin(index / 24 * math.pi * 2) * 22 }
end
polyline(parent, points, weight, unit, color, z)
end)

define("ring", function(parent, unit, color, weight, z)
ring(parent, 50, 50, 34, weight, unit, color, z)
end)

define("loader", function(parent, unit, color, weight, z)
polyline(parent, arcPoints(50, 50, 34, -90, 200, 24), weight, unit, color, z)
end)

define("progress-ring", function(parent, unit, color, weight, z)
polyline(parent, arcPoints(50, 50, 34, -90, 270, 30), weight, unit, color, z)
end)

define("clock", function(parent, unit, color, weight, z)
ring(parent, 50, 50, 34, weight, unit, color, z)
polyline(parent, pointsLine({ 50, 50, 50, 28 }), weight, unit, color, z)
polyline(parent, pointsLine({ 50, 50, 68, 60 }), weight, unit, color, z)
end)

define("refresh", function(parent, unit, color, weight, z)
polyline(parent, arcPoints(50, 50, 32, -60, 240, 22), weight, unit, color, z)
polyline(parent, pointsLine({ 62, 6, 72, 28, 48, 26 }), weight, unit, color, z)
end)

define("trash", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 20, 30, 80, 30 }), weight, unit, color, z)
polyline(parent, pointsLine({ 40, 18, 60, 18 }), weight, unit, color, z)
polyline(parent, pointsLine({ 27, 30, 32, 84, 68, 84, 73, 30 }), weight, unit, color, z)
polyline(parent, pointsLine({ 44, 44, 46, 72 }), weight * 0.7, unit, color, z)
polyline(parent, pointsLine({ 56, 44, 54, 72 }), weight * 0.7, unit, color, z)
end)

define("copy", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 36, 16, 84, 16, 84, 64, 36, 64, 36, 16 }), weight, unit, color, z)
polyline(parent, pointsLine({ 64, 84, 16, 84, 16, 36, 26, 36 }), weight, unit, color, z)
end)

define("lock", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 22, 46, 78, 46, 78, 86, 22, 86, 22, 46 }), weight, unit, color, z)
polyline(parent, arcPoints(50, 46, 18, 180, 360, 14), weight, unit, color, z)
end)

define("unlock", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 22, 46, 78, 46, 78, 86, 22, 86, 22, 46 }), weight, unit, color, z)
polyline(parent, arcPoints(66, 46, 18, 180, 300, 12), weight, unit, color, z)
end)

define("info", function(parent, unit, color, weight, z)
ring(parent, 50, 50, 34, weight, unit, color, z)
disc(parent, 50, 32, 7, unit, color, z + 1)
polyline(parent, pointsLine({ 50, 46, 50, 70 }), weight, unit, color, z)
end)

define("warning", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 50, 16, 88, 82, 12, 82, 50, 16 }), weight, unit, color, z)
polyline(parent, pointsLine({ 50, 42, 50, 62 }), weight, unit, color, z)
disc(parent, 50, 73, 6, unit, color, z + 1)
end)

define("sun", function(parent, unit, color, weight, z)
ring(parent, 50, 50, 18, weight, unit, color, z)
for index = 1, 8 do
local angle = math.rad(index * 45)
local x1, y1 = 50 + math.cos(angle) * 28, 50 + math.sin(angle) * 28
local x2, y2 = 50 + math.cos(angle) * 38, 50 + math.sin(angle) * 38
polyline(parent, pointsLine({ x1, y1, x2, y2 }), weight * 0.8, unit, color, z)
end
end)

define("moon", function(parent, unit, color, weight, z)

polyline(parent, arcPoints(50, 50, 36, -68, 248, 20), weight, unit, color, z)
polyline(parent, arcPoints(72, 50, 38, 118, 428, 20), weight, unit, color, z)
end)

define("chart", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 16, 84, 86, 84 }), weight, unit, color, z)
polyline(parent, pointsLine({ 16, 84, 16, 16 }), weight, unit, color, z)
polyline(parent, pointsLine({ 28, 68, 44, 48, 60, 58, 80, 28 }), weight, unit, color, z)
end)

define("filter", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 16, 24, 84, 24, 60, 52, 60, 84, 40, 74, 40, 52, 16, 24 }), weight, unit, color, z)
end)

define("bell", function(parent, unit, color, weight, z)
polyline(parent, arcPoints(50, 46, 28, 180, 360, 18), weight, unit, color, z)
polyline(parent, pointsLine({ 22, 46, 18, 74, 82, 74, 78, 46 }), weight, unit, color, z)
polyline(parent, arcPoints(50, 78, 10, 0, 180, 10), weight, unit, color, z)
end)

define("user", function(parent, unit, color, weight, z)
ring(parent, 50, 34, 18, weight, unit, color, z)
polyline(parent, arcPoints(50, 92, 34, 200, 340, 16), weight, unit, color, z)
end)

define("palette", function(parent, unit, color, weight, z)
ring(parent, 50, 50, 36, weight, unit, color, z)
disc(parent, 36, 34, weight * 0.95, unit, color, z + 1)
disc(parent, 66, 38, weight * 0.95, unit, color, z + 1)
disc(parent, 30, 64, weight * 0.95, unit, color, z + 1)
disc(parent, 58, 70, weight * 0.95, unit, color, z + 1)
end)

define("grid", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 18, 24, 82, 24, 82, 46, 18, 46, 18, 24 }), weight, unit, color, z)
polyline(parent, pointsLine({ 18, 56, 82, 56, 82, 78, 18, 78, 18, 56 }), weight, unit, color, z)
polyline(parent, pointsLine({ 46, 24, 46, 78 }), weight, unit, color, z)
end)

define("list", function(parent, unit, color, weight, z)
for _, y in ipairs({ 26, 50, 74 }) do
disc(parent, 22, y, weight * 0.72, unit, color, z)
polyline(parent, pointsLine({ 38, y, 84, y }), weight * 0.9, unit, color, z)
end
end)

define("gear", function(parent, unit, color, weight, z)
ring(parent, 50, 50, 22, weight, unit, color, z)
ring(parent, 50, 50, 36, weight * 0.75, unit, color, z)
for index = 1, 8 do
local angle = math.rad(index * 45)
local x1, y1 = 50 + math.cos(angle) * 36, 50 + math.sin(angle) * 36
local x2, y2 = 50 + math.cos(angle) * 48, 50 + math.sin(angle) * 48
polyline(parent, pointsLine({ x1, y1, x2, y2 }), weight * 1.5, unit, color, z)
end
end)

define("layout", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 16, 18, 84, 18, 84, 82, 16, 82, 16, 18 }), weight, unit, color, z)
polyline(parent, pointsLine({ 40, 18, 40, 82 }), weight, unit, color, z)
polyline(parent, pointsLine({ 40, 46, 84, 46 }), weight, unit, color, z)
end)

define("power", function(parent, unit, color, weight, z)
polyline(parent, arcPoints(50, 54, 30, -60, 240, 20), weight, unit, color, z)
polyline(parent, pointsLine({ 50, 14, 50, 50 }), weight, unit, color, z)
end)

define("bolt", function(parent, unit, color, weight, z)
polyline(parent, pointsLine({ 58, 12, 30, 54, 48, 54, 40, 88, 68, 44, 50, 44, 58, 12 }), weight, unit, color, z)
end)

Glyph.names = {}

do
local names = {}
for name in pairs(Glyph.definitions) do
table.insert(names, name)
end
table.sort(names)
Glyph.names = names
end

function Glyph.draw(parent: any, name: string, options: { [any]: any }?): any
local opts = options or {}
local size = opts.size or 16
local definition = Glyph.definitions[name]
if not definition then
warn(string.format("[Vantage] unknown glyph %q. Available: %s", name, table.concat(Glyph.names, ", ")))
return nil
end

local unit = size / GRID
local container = Util.frame({
Name = "VantageGlyph_" .. name,
AnchorPoint = opts.anchor or Vector2.new(0, 0),
Position = opts.position or UDim2.fromOffset(0, 0),
Size = UDim2.fromOffset(size, size),
BackgroundTransparency = 1,
ZIndex = opts.zIndex or 1,
Parent = parent,
})

definition(
container,
unit,
opts.color or Color3.new(1, 1, 1),
opts.weight or 11,
opts.zIndex or 1
)

local alpha = opts.transparency or 0
container:SetAttribute("GlyphTransparency", alpha)
if alpha > 0 then
Glyph.setTransparency(container, alpha)
end

Util.tag(container, "Vantage")
return container
end

function Glyph.setColor(container: any, color: any)
for _, child in ipairs(container:GetChildren()) do
if child:IsA("Frame") and child.BackgroundTransparency < 1 then
child.BackgroundColor3 = color
elseif child:IsA("Frame") then
local stroke = child:FindFirstChildOfClass("UIStroke")
if stroke then
stroke.Color = color
end
end
Glyph.setColor(child, color)
end
end

function Glyph.setTransparency(container: any, transparency: number)
for _, child in ipairs(container:GetChildren()) do
if child:IsA("Frame") then
if child.BackgroundTransparency < 1 then
child.BackgroundTransparency = transparency
end
local stroke = child:FindFirstChildOfClass("UIStroke")
if stroke then
stroke.Transparency = transparency
end
Glyph.setTransparency(child, transparency)
end
end
end

function Glyph.animateIn(container: any, options: { [any]: any }?)
local Motion = __require("Core.Motion")
local opts = Motion.options("enter", options)
local baseAlpha = container:GetAttribute("GlyphTransparency") or 0

local plans = {}
for _, child in ipairs(container:GetDescendants()) do
if child:IsA("Frame") then
local stroke = child:FindFirstChildOfClass("UIStroke")
table.insert(plans, {
frame = child,
background = child.BackgroundTransparency,
stroke = stroke,
strokeTarget = baseAlpha,
})
child.BackgroundTransparency = 1
if stroke then
stroke.Transparency = 1
end
end
end

Motion.setScale(container, 0.74)
Motion.scale(container, 1, opts)

for _, plan in ipairs(plans) do
if plan.background < 1 then
Motion.tween(plan.frame, { BackgroundTransparency = plan.background }, opts)
end
if plan.stroke then
Motion.tween(plan.stroke, { Transparency = plan.strokeTarget }, opts)
end
end
end

function Glyph.create(parent: any, name: string, options: { [any]: any }?): any
return Glyph.draw(parent, name, options)
end

return Glyph
end

__modules["Core.Maid"] = function()

local Maid = {}
Maid.__index = Maid

function Maid.new(name: string?)
return setmetatable({
_items = {},
_name = name,
_dead = false,
}, Maid)
end

function Maid:add(item: any): any
if item == nil then
return item
end
if self._dead then

Maid.release(item)
return item
end
table.insert(self._items, item)
return item
end

function Maid:addAll(items: { any })
for _, item in ipairs(items) do
self:add(item)
end
return self
end

function Maid:remove(item: any): any
local index = table.find(self._items, item)
if index then
table.remove(self._items, index)
end
return item
end

function Maid:set(key: string, item: any): any
local previous = self._slots and self._slots[key]
if previous and previous ~= item then
Maid.release(previous)
end
self._slots = self._slots or {}
self._slots[key] = item
return item
end

function Maid:clean()
local items = self._items
self._items = {}
if self._slots then
for _, item in pairs(self._slots) do
table.insert(items, item)
end
self._slots = nil
end

for index = #items, 1, -1 do
Maid.release(items[index])
end
return self
end

function Maid:destroy()
if self._dead then
return
end
self:clean()
self._dead = true
self._items = nil
self._slots = nil
end

function Maid:isDead(): boolean
return self._dead == true
end

function Maid.release(item: any)
if item == nil then
return
end

local kind = typeof(item)
if kind == "Instance" then
item:Destroy()
return
end
if kind == "RBXScriptConnection" then
item:Disconnect()
return
end

local itemType = type(item)
if itemType == "function" then
local ok, err = pcall(item)
if not ok then
warn("[Vantage] maid cleanup function errored: " .. tostring(err))
end
return
end

if itemType == "table" then
if type(item.destroy) == "function" then
local ok, err = pcall(item.destroy, item)
if not ok then
warn("[Vantage] maid destroy() errored: " .. tostring(err))
end
return
end
if type(item.disconnect) == "function" then
local ok, err = pcall(item.disconnect, item)
if not ok then
warn("[Vantage] maid disconnect() errored: " .. tostring(err))
end
return
end
if type(item.cancel) == "function" then
local ok, err = pcall(item.cancel, item)
if not ok then
warn("[Vantage] maid cancel() errored: " .. tostring(err))
end
return
end
end
end

Maid.none = Maid.new("none")

return Maid
end

__modules["Core.Theme"] = function()

local Util = __require("Core.Util")
local Signal = __require("Core.Signal")

local Theme = {}

Theme.colorTokens = {

"canvas",
"surface",
"surfaceAlt",
"sunken",
"elevated",
"raised",
"overlay",
"scrim",

"borderSubtle",
"border",
"borderStrong",

"text",
"textMuted",
"textDim",
"textInverted",

"accent",
"accentHover",
"accentPressed",
"accentMuted",
"accentSurface",
"accentBorder",
"onAccent",

"success",
"successSurface",
"onSuccess",
"warning",
"warningSurface",
"onWarning",
"danger",
"dangerSurface",
"onDanger",
"info",
"infoSurface",
"onInfo",

"hover",
"pressed",
"selected",
"focusRing",
"trackOff",
"trackOn",
"knob",
"skeleton",
"skeletonHighlight",
"shadow",
"glass",
}

Theme.numberTokens = {
"radiusXs", "radiusSm", "radiusMd", "radiusLg", "radiusXl", "radiusPill",
"borderWidth", "focusWidth",
"space1", "space2", "space3", "space4", "space5", "space6", "space7", "space8",
"controlSm", "controlMd", "controlLg",
"fontSizeXs", "fontSizeSm", "fontSizeMd", "fontSizeLg", "fontSizeXl", "fontSizeDisplay",
"lineHeight", "letterWide",
}

Theme.opacityTokens = {
"scrimTransparency",
"shadowTransparency",
"hoverTransparency",
"disabledTransparency",
"hairlineTransparency",
}

Theme.tokens = Theme.colorTokens

Theme.allTokens = {}
for _, list in ipairs({ Theme.colorTokens, Theme.numberTokens, Theme.opacityTokens }) do
for _, key in ipairs(list) do
table.insert(Theme.allTokens, key)
end
end

local function interpolable(a: any, b: any): boolean
local kind = typeof(b)
return (kind == "Color3" and typeof(a) == "Color3")
or (kind == "number" and type(a) == "number")
end

local function hsv(h: number, s: number, v: number): any
return Color3.fromHSV((h % 1 + 1) % 1, Util.clamp01(s), Util.clamp01(v))
end

local SEMANTIC = {
success = { h = 0.42, s = 0.62, v = 0.88 },
warning = { h = 0.10, s = 0.80, v = 0.95 },
danger = { h = 0.99, s = 0.72, v = 0.96 },
info = { h = 0.63, s = 0.72, v = 0.99 },
}

local function semanticColor(name: string, mode: string): any
local base = SEMANTIC[name]
if mode == "light" then
return hsv(base.h, base.s * 0.92, base.v * 0.62)
end
return hsv(base.h, base.s, base.v)
end

function Theme.derive(definition: { [any]: any }): { [any]: any }
local mode = definition.mode or "dark"
local dark = mode == "dark"

local accent = definition.accent
if not accent then
if typeof(definition.seed) == "Color3" then
accent = definition.seed
else
accent = (Util.hexToColor(definition.seed or "#F0A93B"))
end
end

local hue = select(1, Color3.toHSV(accent))
local tokens = {}

if dark then
tokens.canvas = hsv(hue, 0.11, 0.040)
tokens.surface = hsv(hue, 0.10, 0.066)
tokens.surfaceAlt = hsv(hue, 0.095, 0.083)
tokens.sunken = hsv(hue, 0.12, 0.030)
tokens.elevated = hsv(hue, 0.09, 0.104)
tokens.raised = hsv(hue, 0.085, 0.128)
tokens.overlay = hsv(hue, 0.075, 0.160)
tokens.borderSubtle = hsv(hue, 0.09, 0.118)
tokens.border = hsv(hue, 0.10, 0.172)
tokens.borderStrong = hsv(hue, 0.11, 0.255)
tokens.text = hsv(hue, 0.055, 0.965)
tokens.textMuted = hsv(hue, 0.075, 0.640)
tokens.textDim = hsv(hue, 0.09, 0.415)
tokens.textInverted = hsv(hue, 0.10, 0.055)
tokens.hover = hsv(hue, 0.10, 0.145)
tokens.pressed = hsv(hue, 0.11, 0.205)
tokens.trackOff = hsv(hue, 0.09, 0.200)
tokens.knob = hsv(hue, 0.03, 0.975)
tokens.skeleton = hsv(hue, 0.09, 0.125)
tokens.skeletonHighlight = hsv(hue, 0.07, 0.185)
tokens.shadow = Color3.fromRGB(0, 0, 0)
tokens.scrim = hsv(hue, 0.30, 0.028)
tokens.glass = hsv(hue, 0.14, 0.072)
else
tokens.canvas = hsv(hue, 0.035, 0.955)
tokens.surface = hsv(hue, 0.012, 1.000)
tokens.surfaceAlt = hsv(hue, 0.030, 0.975)
tokens.sunken = hsv(hue, 0.045, 0.930)
tokens.elevated = hsv(hue, 0.010, 1.000)
tokens.raised = hsv(hue, 0.020, 0.990)
tokens.overlay = hsv(hue, 0.045, 0.935)
tokens.borderSubtle = hsv(hue, 0.045, 0.935)
tokens.border = hsv(hue, 0.065, 0.870)
tokens.borderStrong = hsv(hue, 0.085, 0.755)
tokens.text = hsv(hue, 0.180, 0.135)
tokens.textMuted = hsv(hue, 0.115, 0.400)
tokens.textDim = hsv(hue, 0.085, 0.585)
tokens.textInverted = hsv(hue, 0.02, 0.995)
tokens.hover = hsv(hue, 0.055, 0.930)
tokens.pressed = hsv(hue, 0.075, 0.880)
tokens.trackOff = hsv(hue, 0.070, 0.855)
tokens.knob = hsv(hue, 0.01, 1.000)
tokens.skeleton = hsv(hue, 0.040, 0.905)
tokens.skeletonHighlight = hsv(hue, 0.020, 0.960)
tokens.shadow = hsv(hue, 0.35, 0.180)
tokens.scrim = hsv(hue, 0.20, 0.180)
tokens.glass = hsv(hue, 0.02, 1.000)

accent = Util.darken(accent, 0.22)
end

tokens.scrimTransparency = dark and 0.42 or 0.34
tokens.shadowTransparency = dark and 0.55 or 0.82
tokens.hoverTransparency = 0.0
tokens.disabledTransparency = 0.45
tokens.hairlineTransparency = dark and 0.35 or 0.55

tokens.accent = accent
if dark then
tokens.accentHover = Util.lighten(accent, 0.14)
tokens.accentPressed = Util.darken(accent, 0.16)
else
tokens.accentHover = Util.darken(accent, 0.08)
tokens.accentPressed = Util.darken(accent, 0.20)
end
tokens.onAccent = Util.contrastText(accent, tokens.textInverted, tokens.knob)
tokens.accentMuted = Util.mixColor(accent, tokens.surface, dark and 0.45 or 0.55)
tokens.accentSurface = Util.mixColor(accent, tokens.surface, dark and 0.84 or 0.90)
tokens.accentBorder = Util.mixColor(accent, tokens.surface, dark and 0.62 or 0.70)
tokens.selected = Util.mixColor(accent, tokens.surface, dark and 0.80 or 0.88)
tokens.focusRing = Util.lighten(accent, dark and 0.05 or 0.0)
tokens.trackOn = accent

for _, name in ipairs({ "success", "warning", "danger", "info" }) do
local base = semanticColor(name, mode)
tokens[name] = base
tokens[name .. "Surface"] = Util.mixColor(base, tokens.surface, dark and 0.86 or 0.90)
tokens["on" .. name:sub(1, 1):upper() .. name:sub(2)] =
Util.contrastText(base, tokens.textInverted, tokens.knob)
end

tokens.radiusXs = 4
tokens.radiusSm = 6
tokens.radiusMd = 10
tokens.radiusLg = 14
tokens.radiusXl = 20
tokens.radiusPill = 999
tokens.borderWidth = 1
tokens.focusWidth = 2
tokens.space1 = 4
tokens.space2 = 8
tokens.space3 = 12
tokens.space4 = 16
tokens.space5 = 20
tokens.space6 = 24
tokens.space7 = 32
tokens.space8 = 40
tokens.controlSm = 26
tokens.controlMd = 32
tokens.controlLg = 40
tokens.fontSizeXs = 10
tokens.fontSizeSm = 11
tokens.fontSizeMd = 13
tokens.fontSizeLg = 15
tokens.fontSizeXl = 18
tokens.fontSizeDisplay = 24
tokens.lineHeight = 1.35
tokens.letterWide = 0

if definition.overrides then
for key, value in pairs(definition.overrides) do
tokens[key] = value
end
end

return tokens
end

Theme.builtins = {
obsidian = {
label = "Obsidian",
description = "Amber on warm charcoal. The house theme.",
mode = "dark",
seed = "#F0A93B",
category = "Signature",
},
graphite = {
label = "Graphite",
description = "Neutral studio grey with a steel accent. Zero hue bias.",
mode = "dark",
seed = "#B6BCC8",
category = "Signature",
},
porcelain = {
label = "Porcelain",
description = "Light, low-glare, print-inspired. Accent darkened for AAA contrast.",
mode = "light",
seed = "#E0A030",
category = "Light",
},
sakura = {
label = "Sakura",
description = "Light rose with a warm neutral base.",
mode = "light",
seed = "#EE6FA6",
category = "Light",
},
ember = {
label = "Ember",
description = "Burnt orange on soot. High energy, warm shadows.",
mode = "dark",
seed = "#FF6B3D",
category = "Vivid",
},
verdant = {
label = "Verdant",
description = "Emerald over deep forest neutral.",
mode = "dark",
seed = "#34D399",
category = "Vivid",
},
amethyst = {
label = "Amethyst",
description = "Violet with a soft magenta lean.",
mode = "dark",
seed = "#A78BFA",
category = "Vivid",
},
rosewood = {
label = "Rosewood",
description = "Deep rose on oxblood neutrals.",
mode = "dark",
seed = "#FB7185",
category = "Vivid",
},
midnight = {
label = "Midnight",
description = "Indigo-neutral with a cool accent.",
mode = "dark",
seed = "#7C8CFF",
category = "Vivid",
},
frost = {
label = "Frost",
description = "Azure on slate, for teams that want the blue.",
mode = "dark",
seed = "#4DA3FF",
category = "Vivid",
},
}

Theme.registry = {}

for name, definition in pairs(Theme.builtins) do
Theme.registry[name] = definition
end

function Theme.register(name: string, definition: { [any]: any })
local entry = table.clone(definition)
entry.name = name
Theme.registry[name] = entry
return entry
end

function Theme.list(): { any }
local out = {}
for name, definition in pairs(Theme.registry) do
local tokens = Theme.derive(definition)
table.insert(out, {
name = name,
label = definition.label or Util.titleCase(name),
description = definition.description or "",
mode = definition.mode or "dark",
category = definition.category or "Custom",
seed = definition.seed,
swatch = { tokens.canvas, tokens.surface, tokens.accent, tokens.text },
})
end
table.sort(out, function(a, b)
if a.category == b.category then
return a.label < b.label
end
return a.category < b.category
end)
return out
end

function Theme.fromSeed(seed: string, mode: string?, overrides: { [any]: any }?): { [any]: any }
return Theme.derive({
seed = seed,
mode = mode or "dark",
overrides = overrides,
})
end

local active = {}
local activeName = "obsidian"
local activeMode = "dark"
local activeDefinition = Theme.builtins.obsidian

Theme.Changed = Signal.new("Theme.Changed")

Theme.Transitioning = Signal.new("Theme.Transitioning")

function Theme.current(): { [any]: any }
return active
end

function Theme.name(): string
return activeName
end

function Theme.mode(): string
return activeMode
end

function Theme.definition(): { [any]: any }
return activeDefinition
end

function Theme.get(key: string): any
return active[key]
end

function Theme.set(key: string, value: any)
if active[key] == value then
return
end
active[key] = value
Theme.Changed:fire(active, { [key] = value })
end

function Theme.patch(values: { [string]: any })
local changed = {}
local didChange = false
for key, value in pairs(values) do
if active[key] ~= value then
active[key] = value
changed[key] = value
didChange = true
end
end
if didChange then
Theme.Changed:fire(active, changed)
end
end

local function write(tokens: { [any]: any }, keys: { string }?)
for key, value in pairs(tokens) do
if not keys or keys[key] then
active[key] = value
end
end
end

write(Theme.derive(Theme.builtins.obsidian))

function Theme.apply(target: any, options: { [any]: any }?): { [any]: any }
local tokens
local definition

if type(target) == "table" then
tokens = target
definition = { mode = options and options.mode or activeMode, label = "Custom" }
activeName = options and options.name or "custom"
elseif type(target) == "string" then
definition = Theme.registry[target]
if not definition then

if target:match("^#?%x%x%x") then
definition = { seed = target, mode = options and options.mode or "dark", label = "Custom" }
else
warn(string.format("[Vantage] unknown theme %q", target))
return active
end
end
tokens = Theme.derive(definition)
activeName = target
else
warn("[Vantage] Theme.apply expects a theme name or token table")
return active
end

activeDefinition = definition
activeMode = definition.mode or "dark"

if options and options.transition then
return Theme.transition(tokens, type(options.transition) == "table" and options.transition or nil)
end

write(tokens)
Theme.Changed:fire(active, nil)
return active
end

local transitionHandle = nil

local function morph(tokens: { [any]: any }, options: { [any]: any }?): { [any]: any }
local Motion = __require("Core.Motion")
local opts = Motion.options("panel", options)

if transitionHandle then
transitionHandle:cancel()
transitionHandle = nil
end

local start = {}
local goals = {}
local keys = {}
for key, goal in pairs(tokens) do
local current = active[key]
if interpolable(current, goal) then
start[key] = current
goals[key] = goal
table.insert(keys, key)
else
active[key] = goal
end
end

local function writeFrame(alpha: number)
local changed = {}
for _, key in ipairs(keys) do
local value = Motion.lerp(start[key], goals[key], alpha)

if typeof(value) == "Color3" then
value = Color3.fromRGB(
math.floor(value.R * 255 + 0.5),
math.floor(value.G * 255 + 0.5),
math.floor(value.B * 255 + 0.5)
)
end
if active[key] ~= value then
active[key] = value
changed[key] = value
end
end
if next(changed) then
Theme.Changed:fire(active, changed)
end
Theme.Transitioning:fire(active, alpha)
end

local handle = Motion.tween(function() end, {}, {
duration = opts.duration,
easing = opts.easing,
onUpdate = writeFrame,
onComplete = function()
writeFrame(1)
transitionHandle = nil
Theme.Changed:fire(active, nil)
end,
})

transitionHandle = handle
return active
end

function Theme.observe(callback: (any, any) -> ())
callback(active, nil)
local connection = Theme.Changed:connect(callback)
return function()
connection:disconnect()
end
end

function Theme.bind(maid: any, bindings: { [any]: any }, callback: (any, any) -> ())

local tokensUsed = {}
local list = {}
for instance, properties in pairs(bindings) do
table.insert(list, { instance = instance, properties = properties })
for _, token in pairs(properties) do
tokensUsed[token] = true
end
end

local function apply(tokens, changed)
local full = changed == nil or next(changed) == nil
for _, entry in ipairs(list) do
local relevant = full
if not relevant then
for _, token in pairs(entry.properties) do
if changed[token] ~= nil then
relevant = true
break
end
end
end
if not relevant then
continue
end
for property, token in pairs(entry.properties) do
entry.instance[property] = tokens[token]
end
end
if callback then
callback(tokens, changed)
end
end

local connection = Theme.Changed:connect(apply)
if maid then
maid:add(connection)
end
apply(active, nil)
return connection
end

function Theme.swatch(name: string): { any }
local definition = Theme.registry[name]
if not definition then
return { Color3.new(), Color3.new(1, 1, 1) }
end
local tokens = Theme.derive(definition)
return { tokens.canvas, tokens.surface, tokens.accent, tokens.text }
end

function Theme.export(name: string): string
local definition = Theme.registry[name]
if not definition then
return "-- unknown theme: " .. tostring(name)
end
local tokens = Theme.derive(definition)
local lines = {
"-- Generated by Vantage 1.0.0",
"local Vantage = require(path.to.Vantage)",
"",
"Vantage.Theme.register(\"" .. name .. "\", {",
"	label = " .. string.format("%q", definition.label or name) .. ",",
"	description = " .. string.format("%q", definition.description or "") .. ",",
"	mode = \"" .. (definition.mode or "dark") .. "\",",
"	seed = \"" .. Util.colorToHex(tokens.accent) .. "\",",
"	category = " .. string.format("%q", definition.category or "Custom") .. ",",
"	overrides = {",
}
for _, key in ipairs(Theme.colorTokens) do
lines[#lines + 1] = string.format("		%s = Color3.fromRGB(%d, %d, %d),", key,
math.floor(tokens[key].R * 255 + 0.5),
math.floor(tokens[key].G * 255 + 0.5),
math.floor(tokens[key].B * 255 + 0.5))
end
lines[#lines + 1] = "	},"
lines[#lines + 1] = "})"
return table.concat(lines, "\n")
end

function Theme.setTransitionOptions(options: { [any]: any })
Theme._transitionOptions = options
end

Theme._transitionOptions = nil

function Theme.transition(tokens: { [any]: any }, options: { [any]: any }?): { [any]: any }
return morph(tokens, options or Theme._transitionOptions)
end

return Theme
end

__modules["Feedback.LogoMark"] = function()

local Util = __require("Core.Util")

local LogoMark = {}

LogoMark.palette = {
core = Color3.fromRGB(255, 255, 255),
coreMid = Color3.fromRGB(214, 231, 255),
coreDeep = Color3.fromRGB(43, 106, 255),
coreEdge = Color3.fromRGB(14, 74, 222),
orbit = Color3.fromRGB(56, 150, 255),
orbitBright = Color3.fromRGB(120, 197, 255),
sparkle = Color3.fromRGB(168, 214, 255),
cut = Color3.fromRGB(6, 8, 14),
}

local function ring(parent: any, size: number, position: any, thickness: number, color: any, transparency: number, zIndex: number, rotation: number?)
local frame = Util.frame({
Name = "Ring",
AnchorPoint = Vector2.new(0.5, 0.5),
Position = position,
Size = UDim2.fromScale(size, size),
BackgroundTransparency = 1,
Rotation = rotation or 0,
ZIndex = zIndex,
Parent = parent,
})
Util.pill(frame)
local stroke = Util.stroke(frame, color, thickness, transparency)
return frame, stroke
end

local function bar(parent: any, scaleX: number, scaleY: number, position: any, rotation: number, color: any, transparency: number, zIndex: number)
local frame = Util.frame({
Name = "Bar",
AnchorPoint = Vector2.new(0.5, 0.5),
Position = position,
Size = UDim2.fromScale(scaleX, scaleY),
BackgroundColor3 = color,
BackgroundTransparency = transparency,
Rotation = rotation,
ZIndex = zIndex,
Parent = parent,
})
Util.pill(frame)
return frame
end

function LogoMark.build(parent: any, size: number, options: { [any]: any }?): any
local opts = options or {}
local palette = LogoMark.palette
local detail = opts.Detail or 1
local thick = math.max(1, math.floor(size * 0.022 + 0.5))

local container = Util.frame({
Name = "VantageLogoMark",
Size = UDim2.fromOffset(size, size),
BackgroundTransparency = 1,
Parent = parent,
})
Util.tag(container, "Vantage")

local parts = {}
local function track(instance: any, band: number, kind: string)
table.insert(parts, { instance = instance, band = band, kind = kind })
return instance
end

if opts.Glow ~= false then
local glowColor = opts.GlowColor or palette.orbit
for index, scale in ipairs({ 1.16, 1.08, 1.03 }) do
local halo = Util.frame({
Name = "Halo" .. index,
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.fromScale(0.5, 0.5),
Size = UDim2.fromScale(scale, scale),
BackgroundColor3 = glowColor,
BackgroundTransparency = 0.9 + index * 0.025,
ZIndex = 1,
Parent = container,
})
Util.corner(halo, 20)
end
end

local orbitRing = ring(container, 0.9, UDim2.fromScale(0.5, 0.5), thick, palette.orbit, 0.35, 3, -18)
Util.gradient(orbitRing, {
{ Time = 0, Color = palette.orbitBright, Transparency = 0.15 },
{ Time = 0.55, Color = palette.orbit, Transparency = 0.55 },
{ Time = 1, Color = palette.orbit, Transparency = 0.92 },
}, 120)
track(orbitRing, 0.5, "orbit")

local outerRing = ring(container, 0.98, UDim2.fromScale(0.5, 0.5), thick, palette.orbitBright, 0.62, 2, 0)
Util.gradient(outerRing, {
{ Time = 0, Color = palette.orbitBright, Transparency = 0.25 },
{ Time = 0.6, Color = palette.orbit, Transparency = 0.7 },
{ Time = 1, Color = palette.orbit, Transparency = 1 },
}, 0)
track(outerRing, 0.34, "orbit")

local body = Util.frame({
Name = "Body",
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.fromScale(0.485, 0.475),
Size = UDim2.fromScale(0.56, 0.56),
BackgroundColor3 = palette.core,
Rotation = -12,
ZIndex = 5,
Parent = container,
})
Util.corner(body, math.floor(size * 0.075))
Util.gradient(body, {
{ Time = 0, Color = palette.core },
{ Time = 0.45, Color = palette.coreMid },
{ Time = 0.78, Color = palette.coreDeep },
{ Time = 1, Color = palette.coreEdge },
}, 118)
track(body, 0.42, "body")

local cut = Util.frame({
Name = "Cut",
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.fromScale(0.525, 0.5),
Size = UDim2.fromScale(0.155, 0.155),
BackgroundColor3 = palette.cut,
Rotation = -12,
ZIndex = 6,
Parent = container,
})
Util.corner(cut, math.floor(size * 0.02))
track(cut, 0.5, "cut")

local swoosh = bar(container, 1.06, 0.075, UDim2.fromScale(0.5, 0.6), -24, palette.orbitBright, 0.15, 7)
Util.gradient(swoosh, {
{ Time = 0, Color = palette.orbitBright, Transparency = 1 },
{ Time = 0.28, Color = palette.orbitBright, Transparency = 0.05 },
{ Time = 0.62, Color = palette.orbit, Transparency = 0.2 },
{ Time = 1, Color = palette.orbit, Transparency = 1 },
}, 0)
track(swoosh, 0.62, "swoosh")

local trail = bar(container, 0.92, 0.045, UDim2.fromScale(0.46, 0.68), -24, palette.orbitBright, 0.45, 6)
Util.gradient(trail, {
{ Time = 0, Color = palette.orbitBright, Transparency = 1 },
{ Time = 0.4, Color = palette.orbit, Transparency = 0.55 },
{ Time = 1, Color = palette.orbitBright, Transparency = 1 },
}, 0)
track(trail, 0.68, "swoosh")

local function sparkle(cx: number, cy: number, span: number, rotation: number, band: number)
local holder = Util.row({
Name = "Sparkle",
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.fromScale(cx, cy),
Size = UDim2.fromScale(span, span),
Rotation = rotation,
ZIndex = 8,
Parent = container,
})
local arm = math.max(0.04, 0.052 * detail)
local vertical = bar(holder, arm, 1, UDim2.fromScale(0.5, 0.5), 0, palette.sparkle, 0.08, 8)
local horizontal = bar(holder, 1, arm, UDim2.fromScale(0.5, 0.5), 0, palette.sparkle, 0.08, 8)

bar(holder, arm * 0.5, 0.66, UDim2.fromScale(0.5, 0.5), 45, palette.sparkle, 0.42, 8)
bar(holder, arm * 0.5, 0.66, UDim2.fromScale(0.5, 0.5), -45, palette.sparkle, 0.42, 8)
Util.gradient(vertical, {
{ Time = 0, Color = palette.sparkle, Transparency = 0.7 },
{ Time = 0.5, Color = Color3.new(1, 1, 1), Transparency = 0 },
{ Time = 1, Color = palette.sparkle, Transparency = 0.7 },
}, 90)
Util.gradient(horizontal, {
{ Time = 0, Color = palette.sparkle, Transparency = 0.7 },
{ Time = 0.5, Color = Color3.new(1, 1, 1), Transparency = 0 },
{ Time = 1, Color = palette.sparkle, Transparency = 0.7 },
}, 0)
track(holder, band, "sparkle")
return holder
end

sparkle(0.79, 0.19, 0.26, 0, 0.19)
sparkle(0.24, 0.78, 0.3, 0, 0.78)
if detail > 0.9 then
sparkle(0.86, 0.72, 0.14, 0, 0.72)
end

local rim = Util.frame({
Name = "Rim",
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.fromScale(0.485, 0.475),
Size = UDim2.fromScale(0.56, 0.56),
BackgroundTransparency = 1,
Rotation = -12,
ZIndex = 7,
Parent = container,
})
Util.corner(rim, math.floor(size * 0.075))
local rimStroke = Util.stroke(rim, Color3.new(1, 1, 1), 1, 0.3)
Util.gradient(rimStroke, {
{ Time = 0, Color = Color3.new(1, 1, 1), Transparency = 0.15 },
{ Time = 0.5, Color = Color3.new(1, 1, 1), Transparency = 0.85 },
{ Time = 1, Color = palette.orbitBright, Transparency = 0.6 },
}, 118)
track(rim, 0.42, "rim")

return {
Instance = container,
parts = parts,
}
end

return LogoMark
end

__modules["Feedback.LogoWave"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local LogoMark = __require("Feedback.LogoMark")

local LogoWave = {}
LogoWave.__index = LogoWave

local TWO_PI = math.pi * 2

LogoWave.defaults = {
Size = 96,
Amplitude = 5.5,
Frequency = 1.15,
Speed = 0.42,
Slices = 32,
Bleed = nil,
Envelope = true,
Tint = Color3.fromRGB(255, 255, 255),
TintStrength = 0.34,
TransparencyShine = 0.1,
Glow = true,
GlowPulse = 0.05,
Entrance = true,
}

local function envelopeAt(band: number): number
return 0.36 + 0.64 * math.sin(math.pi * Util.clamp01(band))
end

function LogoWave.new(spec: { [any]: any }, context: { [any]: any })
local opts = table.clone(LogoWave.defaults)
for key, value in pairs(spec or {}) do
opts[key] = value
end

local size = opts.Size
local imageId = opts.Image
local hasImage = type(imageId) == "string" and imageId ~= "" and imageId ~= "rbxassetid://0"

local slices = math.clamp(math.floor(opts.Slices or 32), 6, 64)
if hasImage then

slices = math.clamp(math.floor(size / 3), 6, slices)
else
slices = math.clamp(slices, 6, 24)
end
local sliceHeight = size / slices

local phaseStep = TWO_PI * (opts.Frequency or 1) / slices
local bleed = opts.Bleed or math.ceil((opts.Amplitude or 5) * (phaseStep + 2 / slices)) + 2
bleed = math.max(2, bleed)

local self = setmetatable({
_spec = opts,
_size = size,
_sliceCount = slices,
_sliceHeight = sliceHeight,
_bleed = bleed,
_time = 0,
_mode = hasImage and "image" or "mark",
_theme = Theme.current(),
_playing = true,
_opacity = 1,
_maid = context.maid,
}, LogoWave)

local container = Util.group({
Name = "VantageLogoWave",
Size = UDim2.fromOffset(size, size),
BackgroundTransparency = 1,
Parent = context.parent,
})
Util.tag(container, "Vantage")
self.Instance = container

self._glowParts = {}
if opts.Glow ~= false and hasImage then
local glowColor = opts.GlowColor or self._theme.accent
for index, scale in ipairs({ 1.14, 1.07, 1.03 }) do
local halo = Util.image({
Name = "Halo" .. index,
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.fromScale(0.5, 0.5),
Size = UDim2.fromScale(scale, scale),
Image = imageId,
ImageColor3 = glowColor,
ImageTransparency = 0.88 - index * 0.02,
BackgroundTransparency = 1,
ZIndex = 1,
Parent = container,
})
table.insert(self._glowParts, { instance = halo, base = halo.ImageTransparency })
end
end

self._slices = {}
self._parts = {}

if hasImage then
local sliceLayer = Util.frame({
Name = "Slices",
Size = UDim2.fromScale(1, 1),
BackgroundTransparency = 1,
ZIndex = 4,
Parent = container,
})
self._sliceLayer = sliceLayer

for index = 1, slices do
local band = (index - 1) / slices
local base = (index - 1) * sliceHeight

local window = Util.frame({
Name = string.format("Slice%02d", index),
AnchorPoint = Vector2.new(0, 0),
Position = UDim2.fromOffset(0, base - bleed),
Size = UDim2.fromOffset(size, sliceHeight + bleed * 2),
BackgroundTransparency = 1,
ClipsDescendants = true,

ZIndex = 4 + index,
Parent = sliceLayer,
})

local image = Util.image({
Name = "Band",
AnchorPoint = Vector2.new(0, 0),
Position = UDim2.fromOffset(0, -(base - bleed)),
Size = UDim2.fromOffset(size, size),
Image = imageId,
ImageColor3 = opts.Tint,
ImageTransparency = 0,
BackgroundTransparency = 1,
ScaleType = Enum.ScaleType.Stretch,
ZIndex = 1,
Parent = window,
})

table.insert(self._slices, {
window = window,
image = image,
band = band,
baseY = base - bleed,
phase = band * TWO_PI * (opts.Frequency or 1),
})
end
else

local mark = LogoMark.build(container, size, {
Glow = opts.Glow,
GlowColor = opts.GlowColor,
})
self._mark = mark
local origin = {}
for _, part in ipairs(mark.parts) do
origin[part.instance] = part.instance.Position
table.insert(self._parts, {
instance = part.instance,
band = part.band,
base = part.instance.Position,
phase = part.band * TWO_PI * (opts.Frequency or 1),
kind = part.kind,
})
end
self._partOrigins = origin
for _, entry in ipairs(self._parts) do
entry.instance.ZIndex = entry.instance.ZIndex + 3
end
end

if opts.Entrance ~= false then
Motion.setScale(container, 0.8)
Motion.scale(container, 1, { duration = 0.62, easing = "emphasize" })
self._opacity = 0
end

self:_render(0)
self._ticker = Motion.ticker(function(_, elapsed)
self:_render(elapsed)
end)

if context.maid then
context.maid:add(function()
self:destroy()
end)
end

return self
end

function LogoWave:_render(elapsed: number)
local opts = self._spec
local amp = opts.Amplitude or 5
local speed = opts.Speed or 0.42
local tintStrength = opts.TintStrength or 0
local shineStrength = opts.TransparencyShine or 0
local tint = opts.Tint
local opacity = self._opacity

if #self._glowParts > 0 then
local pulse = opts.GlowPulse or 0
local breath = 0.5 + 0.5 * math.sin(elapsed * 1.1)
for index, entry in ipairs(self._glowParts) do
entry.instance.ImageTransparency = entry.base + (1 - breath) * pulse
end
end

if self._mode == "image" then
local slices = self._slices
for index = 1, #slices do
local slice = slices[index]
local ramp = opts.Envelope and envelopeAt(slice.band) or 1
local angle = elapsed * speed * TWO_PI - slice.phase
local offset = math.sin(angle) * amp * ramp
slice.window.Position = UDim2.fromOffset(0, slice.baseY + offset)

if tintStrength > 0 or shineStrength > 0 then

local shine = 0.5 + 0.5 * math.sin(angle + math.pi * 0.5)
if tintStrength > 0 then
slice.image.ImageColor3 = Util.mixColor(
Color3.new(1, 1, 1),
tint,
shine * tintStrength
)
end
if shineStrength > 0 then
slice.image.ImageTransparency = Util.clamp01(
(1 - shine) * shineStrength + (1 - opacity)
)
end
elseif opacity < 1 then
slice.image.ImageTransparency = 1 - opacity
end
end
else
local parts = self._parts
for index = 1, #parts do
local part = parts[index]
local ramp = opts.Envelope and envelopeAt(part.band) or 1
local angle = elapsed * speed * TWO_PI - part.phase
local offset = math.sin(angle) * amp * ramp * 0.75
local base = part.base
part.instance.Position = UDim2.new(
base.X.Scale,
base.X.Offset,
base.Y.Scale,
base.Y.Offset + offset
)
end
if #self._glowParts == 0 and self._mark then

local mark = self._mark
for _, child in ipairs(mark.Instance:GetChildren()) do
if child.Name:sub(1, 4) == "Halo" then
child.BackgroundTransparency = math.min(0.98, child.BackgroundTransparency + (1 - opacity) * 0.5)
end
end
end
end
end

function LogoWave:SetOpacity(opacity: number)
self._opacity = Util.clamp01(opacity)
if self._mode == "image" then
for _, entry in ipairs(self._glowParts) do
entry.instance.ImageTransparency = Util.clamp01(entry.base + (1 - self._opacity) * 0.6)
end
for _, slice in ipairs(self._slices) do
local shine = self._spec.TransparencyShine or 0
slice.image.ImageTransparency = Util.clamp01((1 - self._opacity) + (1 - self._opacity) * shine)
end
else
self.Instance.GroupTransparency = 1 - self._opacity
end
return self
end

function LogoWave:Configure(patch: { [any]: any })
for key, value in pairs(patch) do
self._spec[key] = value
end
if patch.Amplitude or patch.Frequency then
local phaseStep = TWO_PI * (self._spec.Frequency or 1) / self._sliceCount
self._bleed = math.max(2, math.ceil((self._spec.Amplitude or 5) * (phaseStep + 2 / self._sliceCount)) + 2)
for index, slice in ipairs(self._slices) do
local base = (index - 1) * self._sliceHeight
slice.baseY = base - self._bleed
slice.window.Size = UDim2.fromOffset(self._size, self._sliceHeight + self._bleed * 2)
slice.image.Position = UDim2.fromOffset(0, -(base - self._bleed))
end
end
return self
end

function LogoWave:Pulse(options: { [any]: any }?)
local opts = options or {}
local ring = Util.frame({
Name = "Pulse",
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.fromScale(0.5, 0.5),
Size = UDim2.fromScale(0.7, 0.7),
BackgroundTransparency = 1,
ZIndex = 20,
Parent = self.Instance,
})
Util.pill(ring)
local stroke = Util.stroke(ring, opts.Color or self._spec.Tint or Color3.new(1, 1, 1), 2, 0.2)
Motion.tween(ring, { Size = UDim2.fromScale(1.9, 1.9) }, {
duration = 0.7,
easing = "exitSoft",
onComplete = function()
ring:Destroy()
end,
})
Motion.tween(stroke, { Transparency = 1 }, { duration = 0.7, easing = "exitSoft" })
return self
end

function LogoWave:Play()
if self._ticker and not self._playing then
self._ticker:resume()
self._playing = true
end
return self
end

function LogoWave:Pause()
if self._ticker and self._playing then
self._ticker:pause()
self._playing = false
end
return self
end

function LogoWave:IsPlaying(): boolean
return self._playing
end

function LogoWave:RefreshTheme()
local tokens = Theme.current()
self._theme = tokens
if #self._glowParts > 0 then
for _, entry in ipairs(self._glowParts) do
entry.instance.ImageColor3 = self._spec.GlowColor or tokens.accent
end
end
return self
end

function LogoWave:destroy()
if self._ticker then
self._ticker:destroy()
self._ticker = nil
end
if self.Instance then
Motion.cancelAll(self.Instance)
self.Instance:Destroy()
self.Instance = nil
end
end

return LogoWave
end

__modules["Feedback.LoadingScreen"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local Config = __require("Core.Config")
local Maid = __require("Core.Maid")
local Signal = __require("Core.Signal")
local LogoWave = __require("Feedback.LogoWave")

local LoadingScreen = {}
LoadingScreen.__index = LoadingScreen

LoadingScreen.LogoImage = ""

LoadingScreen.defaults = {
Title = "Vantage",
Version = "v" .. Config.version,
Tagline = "Interface, engineered.",

Assets = {},

Phases = nil,
MinDuration = 1.6,
MaxDuration = 25,
StallTimeout = 6,
TipInterval = 4.6,
Tips = {
"Press {TOGGLE} at any time to show or hide the interface.",
"Every control in Vantage supports keyboard navigation.",
"Theme changes morph rather than cut, so nothing flashes.",
"Hold Shift on a slider for fine adjustment.",
"Right-click a keybind to clear it.",
"ContentProvider preloading happens in parallel with your gameplay setup.",
},
Logo = {
Image = nil :: string?,
Size = 92,
Position = "bottom-right",
Padding = 26,
ShowWordmark = true,
Amplitude = 5.5,
Frequency = 1.15,
Speed = 0.42,
Slices = 32,
Tint = Color3.fromRGB(255, 255, 255),
TintStrength = 0.34,
Glow = true,
},
ShowTips = true,
ShowRail = true,
ShowPercentage = true,

AutoContinue = 2.4,
RequireInput = false,
Parent = nil,
OnProgress = nil,
OnPhase = nil,
OnComplete = nil,
OnContinue = nil,
BlurBackground = true,
}

local function formatTip(text: string): string
local toggle = Config.keybinds.toggleInterface
local name = toggle and toggle.Name or "RightShift"
return (text:gsub("{TOGGLE}", name):gsub("{VERSION}", Config.version))
end

local function resolveParent(explicit: any): any
if explicit then
return explicit
end
local ok, playerGui = pcall(function()
local players = game:GetService("Players")
return players.LocalPlayer and players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
end)
if ok and playerGui then
return playerGui
end
local ok2, coreGui = pcall(function()
return game:GetService("CoreGui")
end)
return ok2 and coreGui or nil
end

function LoadingScreen.new(spec: { [any]: any }): any
local options = Util.deepMerge(LoadingScreen.defaults, spec or {})
if options.Logo.Image == nil then
options.Logo.Image = LoadingScreen.LogoImage
end

local tokens = Theme.current()
local self = setmetatable({
_spec = options,
_maid = Maid.new("loadingScreen"),
_tokens = tokens,
_phaseIndex = 0,
_progress = 0,
_displayed = 0,
_complete = false,
_destroyed = false,
_failures = 0,
_startedAt = os.clock(),
_lastAssetAt = os.clock(),
_tipIndex = 1,
_settings = {
mouseIconEnabled = nil,
},
}, LoadingScreen)

self.Progress = Signal.new("LoadingScreen.Progress")
self.PhaseChanged = Signal.new("LoadingScreen.Phase")
self.Completed = Signal.new("LoadingScreen.Completed")
self.Continued = Signal.new("LoadingScreen.Continued")

local camera = workspace and workspace.CurrentCamera

local parent = resolveParent(options.Parent)
local screen = Util.create("ScreenGui", {
Name = "VantageLoadingScreen",
ResetOnSpawn = false,
IgnoreGuiInset = true,
DisplayOrder = 2000,
ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
Parent = parent,
})
Util.tag(screen, "Vantage")
self.ScreenGui = screen

local root = Util.frame({
Name = "Root",
Size = UDim2.fromScale(1, 1),
BackgroundColor3 = tokens.canvas,
Parent = screen,
})
self.Root = root

local canvasGradient = Util.gradient(root, {
{ Time = 0, Color = Util.lighten(tokens.canvas, 0.045) },
{ Time = 0.55, Color = tokens.canvas },
{ Time = 1, Color = Util.darken(tokens.canvas, 0.35) },
}, 90)
self._canvasGradient = canvasGradient

local wash = Util.frame({
Name = "Wash",
Size = UDim2.fromScale(1, 1),
BackgroundColor3 = tokens.accent,
BackgroundTransparency = 0.94,
ZIndex = 1,
Parent = root,
})
Util.gradient(wash, {
{ Time = 0, Color = tokens.accent, Transparency = 1 },
{ Time = 0.45, Color = tokens.accent, Transparency = 0.85 },
{ Time = 1, Color = tokens.accent, Transparency = 1 },
}, 90)
self._wash = wash

local vignette = Util.frame({
Name = "Vignette",
Size = UDim2.fromScale(1, 1),
BackgroundColor3 = tokens.shadow,
BackgroundTransparency = 0.78,
ZIndex = 2,
Parent = root,
})
Util.gradient(vignette, {
{ Time = 0, Color = tokens.shadow, Transparency = 0.35 },
{ Time = 0.5, Color = tokens.shadow, Transparency = 1 },
{ Time = 1, Color = tokens.shadow, Transparency = 0.35 },
}, 90)
self._vignette = vignette

local left = Util.group({
Name = "LeftColumn",
AnchorPoint = Vector2.new(0, 1),
Position = UDim2.new(0, 0, 1, 0),
Size = UDim2.new(0.62, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
ZIndex = 5,
Parent = root,
})
Util.stack(left, 6)
self._left = left

local percentage = Util.text({
Name = "Percentage",
Text = "0",
TextSize = 62,
Font = "display",
TextColor3 = tokens.text,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Bottom,
Size = UDim2.new(1, 0, 0, 66),
Visible = options.ShowPercentage ~= false,
LayoutOrder = 1,
Parent = left,
})
self._percentage = percentage

local phaseRow = Util.row({
Name = "PhaseRow",
Size = UDim2.new(1, 0, 0, 16),
AutomaticSize = Enum.AutomaticSize.X,
LayoutOrder = 2,
Parent = left,
})
Util.list(phaseRow, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 8),
VerticalAlignment = Enum.VerticalAlignment.Center,
})

local phaseDotHolder = Util.row({
Name = "Dot",
Size = UDim2.fromOffset(7, 7),
LayoutOrder = 1,
Parent = phaseRow,
})
local phaseDot = Util.frame({
Name = "DotFrame",
Size = UDim2.fromScale(1, 1),
BackgroundColor3 = tokens.accent,
Parent = phaseDotHolder,
})
Util.pill(phaseDot)
self._phaseDot = phaseDot

local phaseLabel = Util.text({
Name = "Phase",
Text = "Preparing",
TextSize = tokens.fontSizeMd,
Font = "subheading",
TextColor3 = tokens.accent,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Center,
Size = UDim2.new(0, 0, 1, 0),
AutomaticSize = Enum.AutomaticSize.X,
LayoutOrder = 2,
Parent = phaseRow,
})
self._phaseLabel = phaseLabel

local detail = Util.text({
Name = "Detail",
Text = "",
TextSize = tokens.fontSizeSm,
Font = "body",
TextColor3 = tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
TextWrapped = true,
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 3,
Parent = left,
})
self._detail = detail

local tipHolder = Util.row({
Name = "Tip",
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 4,
Visible = options.ShowTips ~= false,
Parent = left,
})
Util.stack(tipHolder, 4)
self._tipHolder = tipHolder

local tipOverline = Util.text({
Name = "Overline",
Text = "DID YOU KNOW",
TextSize = tokens.fontSizeXs,
Font = "bodyBold",
TextColor3 = tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Left,
Size = UDim2.new(1, 0, 0, 12),
LayoutOrder = 1,
Parent = tipHolder,
})
local tipLabel = Util.text({
Name = "TipText",
Text = formatTip(options.Tips[1] or ""),
TextSize = tokens.fontSizeSm,
Font = "body",
TextColor3 = tokens.textMuted,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
TextWrapped = true,
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 2,
Parent = tipHolder,
})
self._tipLabel = tipLabel

local logoBlock = Util.group({
Name = "LogoBlock",
AnchorPoint = Vector2.new(1, 1),
Position = UDim2.new(1, 0, 1, 0),
Size = UDim2.new(0, options.Logo.Size, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
ZIndex = 6,
Parent = root,
})
Util.stack(logoBlock, 10)
self._logoBlock = logoBlock

local waveHolder = Util.row({
Name = "Wave",
Size = UDim2.fromOffset(options.Logo.Size, options.Logo.Size),
LayoutOrder = 1,
Parent = logoBlock,
})
self._waveHolder = waveHolder

local wordmark
local wordmarkSub
if options.Logo.ShowWordmark ~= false then
local wordmarkHolder = Util.row({
Name = "Wordmark",
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 2,
Parent = logoBlock,
})
Util.stack(wordmarkHolder, 2)

wordmark = Util.text({
Name = "Name",
Text = string.upper(options.Title or "Vantage"),
TextSize = 15,
Font = "display",
TextColor3 = tokens.text,
TextXAlignment = Enum.TextXAlignment.Right,
Size = UDim2.new(1, 0, 0, 18),
LayoutOrder = 1,
Parent = wordmarkHolder,
})
wordmarkSub = Util.text({
Name = "Tagline",
Text = options.Tagline or "",
TextSize = tokens.fontSizeSm,
Font = "body",
TextColor3 = tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Right,
Size = UDim2.new(1, 0, 0, 14),
Visible = (options.Tagline or "") ~= "",
LayoutOrder = 2,
Parent = wordmarkHolder,
})
end

local waveSpec = table.clone(options.Logo)
waveSpec.Size = options.Logo.Size
waveSpec.Entrance = false
if Motion.getReducedMotion() then
waveSpec.Amplitude = 0
waveSpec.TintStrength = 0
end

local wave = LogoWave.new(waveSpec, {
parent = waveHolder,
maid = self._maid,
})
self.Logo = wave

local rail
local railFill
if options.ShowRail ~= false then
rail = Util.group({
Name = "Rail",
AnchorPoint = Vector2.new(0, 1),
Position = UDim2.new(0, 0, 1, 0),
Size = UDim2.new(1, 0, 0, 3),
BackgroundColor3 = tokens.border,
BackgroundTransparency = 0.6,
ZIndex = 7,
Parent = root,
})
railFill = Util.frame({
Name = "Fill",
Size = UDim2.new(0, 0, 1, 0),
BackgroundColor3 = tokens.accent,
ZIndex = 8,
Parent = rail,
})
Util.gradient(railFill, {
{ Time = 0, Color = tokens.accent },
{ Time = 0.65, Color = tokens.accentHover },
{ Time = 1, Color = Util.lighten(tokens.accent, 0.35) },
}, 0)

local head = Util.frame({
Name = "Head",
AnchorPoint = Vector2.new(1, 0.5),
Position = UDim2.new(1, 0, 0.5, 0),
Size = UDim2.fromOffset(52, 3),
BackgroundColor3 = Util.lighten(tokens.accent, 0.5),
BackgroundTransparency = 0.35,
ZIndex = 9,
Parent = railFill,
})
Util.gradient(head, {
{ Time = 0, Color = Util.lighten(tokens.accent, 0.5), Transparency = 1 },
{ Time = 1, Color = Util.lighten(tokens.accent, 0.55), Transparency = 0 },
}, 0)
self._railHead = head
end
self._rail = rail
self._railFill = railFill

local continueHolder = Util.group({
Name = "Continue",
AnchorPoint = Vector2.new(0.5, 1),
Position = UDim2.new(0.5, 0, 1, -34),
Size = UDim2.new(0, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.XY,
BackgroundColor3 = tokens.accent,
BackgroundTransparency = 1,
Visible = false,
ZIndex = 12,
Parent = root,
})
Util.corner(continueHolder, tokens.radiusPill)
Util.pad(continueHolder, { Left = 18, Right = 18, Top = 9, Bottom = 9 })
local continueLabel = Util.text({
Name = "Label",
Text = "Continue",
TextSize = tokens.fontSizeMd,
Font = "bodyBold",
TextColor3 = tokens.onAccent,
TextXAlignment = Enum.TextXAlignment.Center,
TextYAlignment = Enum.TextYAlignment.Center,
Size = UDim2.new(0, 0, 0, 18),
AutomaticSize = Enum.AutomaticSize.X,
Parent = continueHolder,
})
self._continueHit = Util.create("TextButton", {
Name = "Hit",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
Size = UDim2.fromScale(1, 1),
ZIndex = 13,
Parent = continueHolder,
})
self._continueHolder = continueHolder
self._continueLabel = continueLabel

local function layout()
local insets = Util.insets()
local pad = options.Logo.Padding
local bottom = insets.bottom + pad
local side = insets.left + pad
local right = insets.right + pad

left.Position = UDim2.new(0, side, 1, -(bottom + 42))
left.Size = UDim2.new(0.56, -side, 0, 0)

logoBlock.Position = UDim2.new(1, -right, 1, -bottom)
if options.Logo.ShowWordmark == false then
logoBlock.Size = UDim2.new(0, options.Logo.Size, 0, options.Logo.Size)
else
logoBlock.Size = UDim2.new(0, math.max(options.Logo.Size, 150), 0, 0)
end

if rail then
rail.Position = UDim2.new(0, 0, 1, -insets.bottom)
end

continueHolder.Position = UDim2.new(0.5, 0, 1, -(bottom + 8))
end
self._layout = layout
layout()
self._maid:add(Theme.Changed:connect(function(next)
tokens = next
self._tokens = next
root.BackgroundColor3 = next.canvas
percentage.TextColor3 = next.text
phaseLabel.TextColor3 = next.accent
phaseDot.BackgroundColor3 = next.accent
detail.TextColor3 = next.textDim
tipLabel.TextColor3 = next.textMuted
tipOverline.TextColor3 = next.textDim
if wordmark then
wordmark.TextColor3 = next.text
end
if wordmarkSub then
wordmarkSub.TextColor3 = next.textDim
end
if rail then
rail.BackgroundColor3 = next.border
Util.gradient(railFill, {
{ Time = 0, Color = next.accent },
{ Time = 0.65, Color = next.accentHover },
{ Time = 1, Color = Util.lighten(next.accent, 0.35) },
}, 0)
end
Util.gradient(root, {
{ Time = 0, Color = Util.lighten(next.canvas, 0.045) },
{ Time = 0.55, Color = next.canvas },
{ Time = 1, Color = Util.darken(next.canvas, 0.35) },
}, 90)
wave:RefreshTheme()
layout()
end))
if camera and camera.GetPropertyChangedSignal then
pcall(function()
self._maid:add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
task.defer(layout)
end))
end)
end

return self
end

function LoadingScreen:SetProgress(value: number, detailText: string?)
value = Util.clamp01(value)
if value < self._progress then
value = self._progress
end
self._progress = value

if not self._progressSpring then
local spring = Motion.springFrom("gentle", 0)
self._progressSpring = spring
self._maid:add(function()
spring:destroy()
end)
spring:observe(function(displayed)
self._displayed = displayed
local fraction = Util.clamp01(displayed)
if self._railFill then
self._railFill.Size = UDim2.new(fraction, 0, 1, 0)
end
local rounded = math.floor(fraction * 100 + 0.5)
if self._percentage and self._percentage.Text ~= tostring(rounded) then
self._percentage.Text = tostring(rounded)
end
end)
end
self._progressSpring:setGoal(value)

if detailText ~= nil and self._detail and self._detail.Text ~= detailText then
self._detail.Text = detailText
end

self.Progress:fire(value, detailText, self)
Util.safeCall(self._spec.OnProgress, value, detailText, self)
return self
end

function LoadingScreen:SetPhase(name: string, detailText: string?)
if self._phaseLabel.Text ~= name then
self._phaseLabel.Text = name
Motion.setScale(self._phaseLabel, 0.94)
Motion.scale(self._phaseLabel, 1, { duration = 0.3, easing = "settle" })
end
if detailText ~= nil and self._detail then
self._detail.Text = detailText
end
self.PhaseChanged:fire(name, detailText, self)
Util.safeCall(self._spec.OnPhase, name, detailText, self)
return self
end

local function defaultPhases(self: any): { any }
local spec = self._spec
return {
{
Name = "Preparing",
Weight = 0.08,
Run = function(report)
report(0.4, "Reading configuration")
if Config.persistence and Config.persistence.load then
report(0.75, "Restoring saved layout")
end
report(1, nil)
end,
},
{
Name = "Streaming assets",
Weight = #spec.Assets > 0 and 0.78 or 0.02,
Run = function(report)
if #spec.Assets == 0 then
report(1, "No assets to preload")
return
end
local ok, ContentProvider = pcall(function()
return game:GetService("ContentProvider")
end)
if not ok or not ContentProvider then
report(1, "ContentProvider unavailable")
return
end

local total = #spec.Assets
local done = 0
local failed = 0
local started = os.clock()

local success, err = pcall(function()
ContentProvider:PreloadAsync(spec.Assets, function(_, status)
done += 1
self._lastAssetAt = os.clock()
if status and status ~= Enum.AssetFetchStatus.Success then
failed += 1
end
local elapsed = os.clock() - started
local line = string.format("%d of %d assets  ·  %.1fs", done, total, elapsed)
if failed > 0 then
line = string.format("%s  ·  %d unavailable", line, failed)
end
report(done / total, line)
end)
end)

self._failures = failed
if not success then
self._loadError = tostring(err)
report(1, "Asset streaming reported an error; continuing")
else
report(1, nil)
end
end,
},
{
Name = "Finalising",
Weight = 0.14,
Run = function(report)
report(0.35, "Building interface")
report(0.7, "Warming animation engine")
report(1, nil)
end,
},
}
end

function LoadingScreen:Start()
local spec = self._spec
local phases = spec.Phases or defaultPhases(self)

task.spawn(function()
local totalWeight = 0
for _, phase in ipairs(phases) do
totalWeight += (phase.Weight or 1)
end
if totalWeight <= 0 then
totalWeight = 1
end

local consumed = 0
local startingProgress = self._progress

for _, phase in ipairs(phases) do
if self._destroyed then
return
end
self:SetPhase(phase.Name or "Working", phase.Detail)

local weight = (phase.Weight or 1) / totalWeight
local phaseBase = startingProgress + consumed * (1 - startingProgress)
local phaseSpan = weight * (1 - startingProgress)
consumed += weight

local reported = 0
local function report(fraction: number, detailText: string?)
reported = Util.clamp01(fraction)
self:SetProgress(phaseBase + reported * phaseSpan, detailText)
end

if type(phase.Run) == "function" then

local ok, err = pcall(phase.Run, report, self)
if not ok then
self._loadError = tostring(err)
report(1, "Phase reported an error; continuing")
end
elseif type(phase.Duration) == "number" then
local elapsed = 0
while elapsed < phase.Duration and not self._destroyed do
task.wait(0.05)
elapsed += 0.05
report(elapsed / phase.Duration, phase.Detail)
end
else
report(1, phase.Detail)
end
end

self:SetProgress(1, self._loadError and "Finished with warnings" or nil)
self:_finish()
end)

self._maid:add(task.delay((spec.MinDuration or 0), function()
self._minDurationElapsed = true
self:_maybeFinish()
end))

self._maid:add(task.delay(spec.MaxDuration or 25, function()
if not self._complete then
self._timedOut = true
self:SetProgress(1, "Taking longer than expected; continuing")
self:_finish()
end
end))

self:_startTips()
self:_watchForStalls()
return self
end

function LoadingScreen:_startTips()
local tips = self._spec.Tips
if self._spec.ShowTips == false or not tips or #tips <= 1 then
return
end
self._maid:add(function()
self._tipToken = (self._tipToken or 0) + 1
end)
local function cycle()
self._tipToken = (self._tipToken or 0) + 1
local token = self._tipToken
task.delay(self._spec.TipInterval or 4.6, function()
if token ~= self._tipToken or self._destroyed then
return
end
self._tipIndex = (self._tipIndex % #tips) + 1
local label = self._tipLabel
if not label then
return
end
Motion.tween(label, { TextTransparency = 1 }, Motion.options("exit", {
duration = 0.2,
onComplete = function()
label.Text = formatTip(tips[self._tipIndex])
Motion.tween(label, { TextTransparency = 0 }, Motion.options("enter", { duration = 0.26 }))
end,
}))
cycle()
end)
end
cycle()
end

function LoadingScreen:_watchForStalls()
self._maid:add(Motion.ticker(function()
if self._destroyed or self._complete then
return
end
local quietFor = os.clock() - (self._lastAssetAt or os.clock())
if quietFor > (self._spec.StallTimeout or 6) and not self._stallNoted then
self._stallNoted = true
self._detail.Text = "Still working — this can take a moment on a slow connection"
end

local pulse = 0.5 + 0.5 * math.sin(os.clock() * 2.2)
self._phaseDot.BackgroundTransparency = 0.15 + pulse * 0.35
end))
end

function LoadingScreen:_finish()
if self._complete then
return
end
self._complete = true

self.Completed:fire(self)
Util.safeCall(self._spec.OnComplete, self)
self:_maybeFinish()
end

function LoadingScreen:_maybeFinish()
if self._revealed or self._destroyed then
return
end
if not self._complete then
return
end
if not self._minDurationElapsed and (self._spec.MinDuration or 0) > 0 then
return
end
self._revealed = true

self.Logo:Pulse({ Color = self._tokens.accent })
self._continueHolder.Visible = true
Motion.setScale(self._continueHolder, 0.9)
Motion.scale(self._continueHolder, 1, { duration = 0.42, easing = "emphasize" })
Motion.tween(self._continueHolder, { BackgroundTransparency = 0 }, Motion.options("enter"))

self._maid:add(self._continueHit.Activated:Connect(function()
self:Continue()
end))

if self._spec.RequireInput then
self._continueLabel.Text = "Press any key"
self._maid:add(game:GetService("UserInputService").InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.Keyboard
or input.UserInputType == Enum.UserInputType.MouseButton1
or input.UserInputType == Enum.UserInputType.Touch
then
self:Continue()
end
end))
elseif self._spec.AutoContinue then

local remaining = self._spec.AutoContinue
local token = (self._autoToken or 0) + 1
self._autoToken = token
local function tick()
if token ~= self._autoToken or self._destroyed or self._continued then
return
end
remaining -= 0.1
if remaining <= 0 then
self:Continue()
return
end
self._continueLabel.Text = string.format("Continue  ·  %.1fs", remaining)
task.delay(0.1, tick)
end
self._continueLabel.Text = string.format("Continue  ·  %.1fs", remaining)
task.delay(0.1, tick)
else
self._continueLabel.Text = "Continue"
end

Util.safeCall(self._spec.OnReady, self)
end

function LoadingScreen:Continue(instant: boolean?)
if self._continued then
return self
end
self._continued = true
self.Continued:fire(self)
Util.safeCall(self._spec.OnContinue, self)

if instant or Motion.getReducedMotion() then
self:Destroy()
return self
end

Motion.tween(self._logoBlock, { GroupTransparency = 1 }, Motion.options("exit", { duration = 0.36 }))
task.delay(0.1, function()
if not self._destroyed and self.Logo then
self.Logo:SetOpacity(0)
end
end)
Motion.tween(self._left, { GroupTransparency = 1 }, Motion.options("exit", { duration = 0.32 }))
if self._rail then
Motion.tween(self._rail, { GroupTransparency = 1, BackgroundTransparency = 1 }, Motion.options("exit"))
end
Motion.tween(self._continueHolder, { GroupTransparency = 1 }, Motion.options("exit", { duration = 0.24 }))
Motion.tween(self.Root, { BackgroundTransparency = 1 }, {
duration = 0.46,
easing = "exitSoft",
onComplete = function()
self:Destroy()
end,
})
return self
end

function LoadingScreen:GetProgress(): number
return self._displayed
end

function LoadingScreen:IsComplete(): boolean
return self._complete
end

function LoadingScreen:GetReport()
return {
progress = self._progress,
displayed = self._displayed,
complete = self._complete,
failures = self._failures,
loadError = self._loadError,
timedOut = self._timedOut == true,
stalled = self._stallNoted == true,
duration = os.clock() - self._startedAt,
mode = self.Logo and self.Logo._mode or "unknown",
slices = self.Logo and self.Logo._sliceCount or 0,
}
end

function LoadingScreen:Destroy()
if self._destroyed then
return
end
self._destroyed = true

self.Progress:destroy()
self.PhaseChanged:destroy()
self.Completed:destroy()
self.Continued:destroy()

self._maid:destroy()

if self.ScreenGui then
self.ScreenGui:Destroy()
self.ScreenGui = nil
end
end

function LoadingScreen.Run(spec: { [any]: any })
local screen = LoadingScreen.new(spec)
screen:Start()

local handle = {
screen = screen,
Instance = screen.ScreenGui,
}

function handle.wait(timeout: number?)
local deadline = timeout and (os.clock() + timeout) or nil
while not screen._continued and not screen._destroyed do
if deadline and os.clock() > deadline then
break
end
task.wait(0.05)
end
return screen
end

function handle.continue()
screen:Continue()
end

function handle.destroy()
screen:Destroy()
end

return handle
end

return LoadingScreen
end

__modules["Layout.Elements"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")

local Elements = {}

local function makeText(spec: { [any]: any }, context: any, variant: string): any
local tokens = Theme.current()
local presets = {
display = {
textSize = "fontSizeDisplay",
font = "display",
color = "text",
align = Enum.TextXAlignment.Left,
},
heading = {
textSize = "fontSizeLg",
font = "heading",
color = "text",
align = Enum.TextXAlignment.Left,
},
subheading = {
textSize = "fontSizeMd",
font = "subheading",
color = "text",
align = Enum.TextXAlignment.Left,
},
body = {
textSize = "fontSizeMd",
font = "body",
color = "textMuted",
align = Enum.TextXAlignment.Left,
},
caption = {
textSize = "fontSizeSm",
font = "body",
color = "textDim",
align = Enum.TextXAlignment.Left,
},
overline = {
textSize = "fontSizeXs",
font = "bodyBold",
color = "textDim",
align = Enum.TextXAlignment.Left,
},
code = {
textSize = "fontSizeSm",
font = "mono",
color = "accent",
align = Enum.TextXAlignment.Left,
},
}
local preset = presets[variant] or presets.body

local label = Util.text({
Name = "Vantage" .. Util.titleCase(variant):gsub("%s", ""),
Text = spec.Text or spec.Body or "",
TextSize = spec.TextSize or tokens[preset.textSize],
Font = spec.Font or preset.font,
TextColor3 = spec.Color or tokens[spec.ColorToken or preset.color],
TextXAlignment = spec.Align == "center" and Enum.TextXAlignment.Center
or (spec.Align == "right" and Enum.TextXAlignment.Right or preset.align),
TextYAlignment = Enum.TextYAlignment.Top,
TextWrapped = spec.Wrap ~= false,
RichText = spec.RichText == true,
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = spec.LayoutOrder or 1,
Parent = context.parent,
})
Util.tag(label, "Vantage")

if variant == "overline" then
label.Text = string.upper(label.Text)
end

if context.maid then
context.maid:add(Theme.Changed:connect(function(next)
label.TextColor3 = spec.Color or next[spec.ColorToken or preset.color]
if not spec.TextSize then
label.TextSize = next[preset.textSize]
end
end))
end

return label
end

function Elements.heading(spec: any, context: any): any
return makeText(spec, context, "heading")
end

function Elements.overline(spec: any, context: any): any
return makeText(spec, context, "overline")
end

function Elements.body(spec: any, context: any): any
return makeText(spec, context, "body")
end

function Elements.caption(spec: any, context: any): any
return makeText(spec, context, "caption")
end

function Elements.paragraph(spec: any, context: any): any
local tokens = Theme.current()
local text = spec.Text or ""
if spec.Segments then
local parts = {}
for _, segment in ipairs(spec.Segments) do
local body = Util.escapeRichText(segment.Text or "")
if segment.Bold then
body = "<b>" .. body .. "</b>"
end
if segment.Tone then
body = string.format('<font color="#%s">%s</font>', Util.colorToHex(tokens[segment.Tone] or tokens.text), body)
end
table.insert(parts, body)
end
text = table.concat(parts)
end

local label = Util.text({
Name = "VantageParagraph",
Text = text,
TextSize = tokens.fontSizeMd,
Font = "body",
TextColor3 = tokens[spec.Tone or "textMuted"],
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
TextWrapped = true,
RichText = spec.Segments ~= nil or spec.RichText == true,
LineHeight = 1.15,
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = spec.LayoutOrder or 1,
Parent = context.parent,
})
Util.tag(label, "Vantage")

if context.maid then
context.maid:add(Theme.Changed:connect(function(next)
if spec.Tone then
label.TextColor3 = next[spec.Tone]
end
end))
end
return label
end

function Elements.divider(spec: any, context: any): any
local tokens = Theme.current()
local root = Util.row({
Name = "VantageDivider",
Size = UDim2.new(1, 0, 0, spec.Label and 16 or 1),
LayoutOrder = (spec and spec.LayoutOrder) or 1,
Parent = context.parent,
})
Util.list(root, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 10),
VerticalAlignment = Enum.VerticalAlignment.Center,
})

local line = Util.frame({
Name = "Line",
Size = UDim2.new(1, 0, 0, 1),
BackgroundColor3 = tokens.border,
BackgroundTransparency = tokens.hairlineTransparency,
LayoutOrder = 1,
Parent = root,
})

if spec.Label then
line.Size = UDim2.new(1, -90, 0, 1)
local label = Util.text({
Name = "Label",
Text = spec.Label,
TextSize = tokens.fontSizeSm,
Font = "bodyMedium",
TextColor3 = tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Right,
Size = UDim2.new(1, 0, 1, 0),
LayoutOrder = 2,
Parent = root,
})
if context.maid then
context.maid:add(Theme.Changed:connect(function(next)
line.BackgroundColor3 = next.border
label.TextColor3 = next.textDim
end))
end
end

return root
end

function Elements.badge(spec: any, context: any): any
local tokens = Theme.current()
local tone = spec.Tone or "accent"
local background = spec.Background or tokens[tone .. "Surface"]
local foreground = spec.Color or tokens[tone]

local pill = Util.row({
Name = "VantageBadge",
AnchorPoint = spec.AnchorPoint or Vector2.new(0, 0.5),
Position = spec.Position or UDim2.fromOffset(0, 0),
Size = UDim2.new(0, 0, 0, 18),
AutomaticSize = Enum.AutomaticSize.X,
BackgroundColor3 = background,
LayoutOrder = spec.LayoutOrder or 1,
Parent = context.parent,
})
Util.pill(pill)
Util.pad(pill, { Left = 7, Right = 7 })
if spec.Stroke then
Util.stroke(pill, tokens[tone], 1, 0.45)
end

local label = Util.text({
Name = "Text",
Text = spec.Text or "",
TextSize = tokens.fontSizeXs + 1,
Font = "bodyBold",
TextColor3 = foreground,
TextXAlignment = Enum.TextXAlignment.Center,
TextYAlignment = Enum.TextYAlignment.Center,
Size = UDim2.new(0, 0, 1, 0),
AutomaticSize = Enum.AutomaticSize.X,
Parent = pill,
})
Util.tag(pill, "Vantage")

if context.maid then
context.maid:add(Theme.Changed:connect(function(next)
pill.BackgroundColor3 = spec.Background or next[tone .. "Surface"]
label.TextColor3 = spec.Color or next[tone]
end))
end

local object = {
Instance = pill,
Label = label,
}
function object:Set(text: string, nextTone: string?)
label.Text = text
if nextTone then
tone = nextTone
local next = Theme.current()
pill.BackgroundColor3 = spec.Background or next[tone .. "Surface"]
label.TextColor3 = spec.Color or next[tone]
end
return self
end
function object:destroy()
pill:Destroy()
end
return object
end

function Elements.spacer(spec: any, context: any): any
local frame = Util.row({
Name = "VantageSpacer",
Size = UDim2.new(1, 0, 0, (spec and spec.Size) or 8),
LayoutOrder = (spec and spec.LayoutOrder) or 1,
Parent = context.parent,
})
return frame
end

function Elements.image(spec: any, context: any): any
local tokens = Theme.current()
local height = spec.Height or 140
local frame = Util.frame({
Name = "VantageImage",
Size = UDim2.new(spec.Width or 1, 0, 0, height),
BackgroundColor3 = tokens.sunken,
LayoutOrder = spec.LayoutOrder or 1,
ClipsDescendants = true,
Parent = context.parent,
})
Util.corner(frame, tokens.radiusMd)
Util.stroke(frame, tokens.border, 1, 0.4)

local image = Util.image({
Name = "Image",
Image = spec.Image or "",
ImageTransparency = 1,
ScaleType = spec.ScaleType or Enum.ScaleType.Crop,
Size = UDim2.fromScale(1, 1),
BackgroundTransparency = 1,
Parent = frame,
})

if spec.Caption then
local caption = Util.text({
Name = "Caption",
Text = spec.Caption,
TextSize = tokens.fontSizeSm,
Font = "body",
TextColor3 = tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Left,
Size = UDim2.new(1, -16, 1, 0),
Position = UDim2.fromOffset(12, 0),
Parent = frame,
})
Util.gradient(caption, {

{ Time = 0, Color = Color3.new(0, 0, 0), Transparency = 0.35 },
{ Time = 0.6, Color = Color3.new(0, 0, 0), Transparency = 0.9 },
{ Time = 1, Color = Color3.new(0, 0, 0), Transparency = 0.9 },
}, 90)
end

Motion.tween(image, { ImageTransparency = spec.Transparency or 0 }, Motion.options("enter"))

return frame
end

function Elements.stat(spec: any, context: any): any
local tokens = Theme.current()
local root = Util.row({
Name = "VantageStat",
Size = UDim2.new(spec.Width or 0, spec.Width and 0 or 0, 0, 14),
AutomaticSize = Enum.AutomaticSize.X,
LayoutOrder = spec.LayoutOrder or 1,
Parent = context.parent,
})
Util.list(root, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 5),
VerticalAlignment = Enum.VerticalAlignment.Center,
})

local key = Util.text({
Name = "Key",
Text = spec.Label or "",
TextSize = tokens.fontSizeXs + 1,
Font = "bodyBold",
TextColor3 = tokens.textDim,
Size = UDim2.new(0, 0, 1, 0),
AutomaticSize = Enum.AutomaticSize.X,
LayoutOrder = 1,
Parent = root,
})

local value = Util.text({
Name = "Value",
Text = spec.Value or "--",
TextSize = tokens.fontSizeXs + 1,
Font = "mono",
TextColor3 = tokens[spec.Tone or "textMuted"],
Size = UDim2.new(0, 0, 1, 0),
AutomaticSize = Enum.AutomaticSize.X,
LayoutOrder = 2,
Parent = root,
})

local object = { Instance = root, Key = key, Value = value }
function object:Set(text: string, tone: string?)
if value.Text == text then
return self
end
value.Text = text
if tone then
value.TextColor3 = Theme.current()[tone]
end
return self
end
function object:destroy()
root:Destroy()
end
return object
end

function Elements.columns(spec: any, context: any): any
local count = spec.Count or 2
local gap = spec.Gap or 16

local root = Util.row({
Name = "VantageColumns",
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = spec.LayoutOrder or 1,
Parent = context.parent,
})
Util.list(root, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, gap),
VerticalAlignment = Enum.VerticalAlignment.Top,
})

local columns = {}
for index = 1, count do
local column = Util.row({
Name = "Column" .. index,
Size = UDim2.new(1 / count, -(gap * (count - 1) / count), 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = index,
Parent = root,
})
Util.stack(column, spec.RowGap or 8)
columns[index] = column
end

return {
Instance = root,
Columns = columns,
get = function(_, index: number)
return columns[index] or columns[1]
end,
add = function(_, index: number, instance: any)
instance.Parent = columns[index] or columns[1]
return instance
end,
}
end

return Elements
end

__modules["Layout.Field"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local Glyph = __require("Core.Glyph")

local Field = {}
Field.__index = Field

Field.STACK_BREAKPOINT = 236

Field.GAP = 14

Field.STACK_GAP = 8

function Field.new(spec: { [any]: any }, context: { [any]: any })
local tokens = Theme.current()
local maid = context.maid

local self = setmetatable({
_spec = spec,
_maid = maid,
_tokens = tokens,
_stacked = false,
_disabled = spec.Disabled == true,
}, Field)

local root = Util.frame({
Name = "VantageField",
BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
Parent = context.parent,
})
Util.tag(root, "Vantage")
self.Instance = root

local floor = Util.frame({
Name = "Floor",
BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 0, spec.MinHeight or tokens.controlLg),
Parent = root,
})
floor.ZIndex = 0
self._floor = floor

local info = Util.row({
Name = "Info",
Position = UDim2.fromOffset(0, 0),
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
Parent = root,
})
Util.stack(info, 2)
local infoPadding = Util.pad(info, { Top = 0, Bottom = 0, Left = 0, Right = Field.GAP })
info.ZIndex = 2
self.Info = info
self._infoPadding = infoPadding

local labelRow = Util.row({
Name = "LabelRow",
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 1,
Parent = info,
})
Util.list(labelRow, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 8),
VerticalAlignment = Enum.VerticalAlignment.Center,
})

if spec.Icon then
local iconHolder = Util.row({
Name = "Icon",
Size = UDim2.fromOffset(14, 18),
LayoutOrder = 1,
Parent = labelRow,
})
local icon = Glyph.draw(iconHolder, spec.Icon, {
size = 14,
color = tokens.textDim,
weight = 11,
zIndex = 3,
position = UDim2.fromOffset(0, 2),
})
self.Icon = icon
end

local label = Util.text({
Name = "Label",
Text = spec.Name or "",
TextSize = tokens.fontSizeMd,
Font = "bodyMedium",
TextColor3 = spec.Disabled and tokens.textDim or tokens.text,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Center,
TextWrapped = true,
Size = UDim2.new(0, 0, 0, 18),
AutomaticSize = Enum.AutomaticSize.XY,
LayoutOrder = 2,
Parent = labelRow,
})
self.Label = label
if spec.RichText then
label.RichText = true
end

local description = Util.text({
Name = "Description",
Text = spec.Description or "",
TextSize = tokens.fontSizeSm,
Font = "body",
TextColor3 = tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
TextWrapped = true,
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 2,
Visible = (spec.Description ~= nil and spec.Description ~= ""),
Parent = info,
})
self.Description = description

local spacer = Util.row({
Name = "Spacer",
Size = UDim2.new(1, 0, 0, 0),
LayoutOrder = 3,
Parent = info,
})
self._spacer = spacer

local status = Util.text({
Name = "Status",
Text = "",
TextSize = tokens.fontSizeSm,
Font = "body",
TextColor3 = tokens.danger,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
TextWrapped = true,
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 4,
Visible = false,
Parent = info,
})
self.Status = status

local controlHost = Util.row({
Name = "Control",
AnchorPoint = Vector2.new(1, 0),
Position = UDim2.new(1, 0, 0, 0),
Size = UDim2.new(0, spec.ControlWidth or 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.XY,
Parent = root,
})
controlHost.ZIndex = 3
self.Control = controlHost

local hit = Util.create("TextButton", {
Name = "LabelHit",
Text = "",
BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
AutoButtonColor = false,
ZIndex = 4,
Parent = info,
})
self._hit = hit

local activations = {}
self._activations = activations

local function measure()
local available = root.AbsoluteSize.X
local controlSize = controlHost.AbsoluteSize
local stacked = available > 0 and available < Field.STACK_BREAKPOINT
local controlWidth = controlSize.X
local controlHeight = controlSize.Y

if controlHeight <= 0 and controlWidth <= 0 then
return
end

if stacked == self._stacked and self._controlHeight == controlHeight
and self._controlWidth == controlWidth and available == self._measuredWidth
then
return
end

self._stacked = stacked
self._controlHeight = controlHeight
self._controlWidth = controlWidth
self._measuredWidth = available

if stacked then
infoPadding.PaddingRight = UDim.new(0, 0)
spacer.Size = UDim2.new(1, 0, 0, controlHeight + Field.STACK_GAP)
controlHost.AnchorPoint = Vector2.new(0, 0)
controlHost.Position = UDim2.new(0, 0, 0, info.AbsoluteSize.Y)
controlHost.Size = UDim2.new(1, 0, 0, controlHeight)
else
infoPadding.PaddingRight = UDim.new(0, controlWidth + Field.GAP)
spacer.Size = UDim2.new(1, 0, 0, 0)
controlHost.AnchorPoint = Vector2.new(1, 0)
controlHost.Position = UDim2.new(1, 0, 0, 0)
controlHost.Size = UDim2.new(0, controlWidth, 0, controlHeight)
end
end

self._measure = measure

local function scheduleMeasure()

if self._measureQueued then
return
end
self._measureQueued = true
task.defer(function()
self._measureQueued = false
measure()
end)
end

if maid then
maid:add(root:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleMeasure))
maid:add(controlHost:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleMeasure))
maid:add(info:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleMeasure))
maid:add(Theme.Changed:connect(function(_, changed)
if changed == nil or changed.controlMd ~= nil or changed.fontSizeMd ~= nil then
scheduleMeasure()
end
end))
end

local hovering = false
local function refreshLabelColor()
local tokensNow = self._tokens
local target
if self._statusLevel then
target = ({
error = tokensNow.danger,
warning = tokensNow.warning,
success = tokensNow.success,
info = tokensNow.info,
})[self._statusLevel] or tokensNow.text
elseif self._disabled then
target = tokensNow.textDim
elseif hovering then
target = tokensNow.accentHover
else
target = tokensNow.text
end
Motion.tween(label, { TextColor3 = target }, Motion.options("hover"))
end
self._refreshLabelColor = refreshLabelColor

hit.MouseEnter:Connect(function()
hovering = true
refreshLabelColor()
end)
hit.MouseLeave:Connect(function()
hovering = false
refreshLabelColor()
end)
hit.Activated:Connect(function()
if self._disabled then
return
end
for _, callback in ipairs(self._activations) do
Util.safeCall(callback)
end
end)

scheduleMeasure()
task.delay(0.05, measure)

return self
end

function Field:onActivate(callback: () -> ())
table.insert(self._activations, callback)
return self
end

function Field:addConnection(connection: any)
if self._maid then
self._maid:add(connection)
end
return connection
end

function Field:setDisabled(disabled: boolean)
if self._disabled == disabled then
return self
end
self._disabled = disabled
self._hit.Active = not disabled
if self._refreshLabelColor then
self._refreshLabelColor()
end
if self.Icon then
Glyph.setTransparency(self.Icon, disabled and 0.5 or 0)
end
if self._onDisabled then
self._onDisabled(disabled)
end
return self
end

function Field:isDisabled(): boolean
return self._disabled
end

function Field:setDescription(text: string?)
local has = text ~= nil and text ~= ""
if self.Description.Visible ~= has then
self.Description.Visible = has
self._measure()
end
self.Description.Text = text or ""
return self
end

function Field:setLabel(text: string)
self.Label.Text = text
self._measure()
return self
end

function Field:setStatus(level: string?, message: string?)
self._statusLevel = level
local tokens = self._tokens
local hasMessage = message ~= nil and message ~= ""
local colors = {
error = tokens.danger,
warning = tokens.warning,
success = tokens.success,
info = tokens.info,
}
self.Status.Text = message or ""
self.Status.TextColor3 = colors[level or ""] or tokens.textMuted
if self.Status.Visible ~= hasMessage then
self.Status.Visible = hasMessage
self._measure()
end
if self._refreshLabelColor then
self._refreshLabelColor()
end
return self
end

function Field:onDisabledChanged(callback: (boolean) -> ())
self._onDisabled = callback
return self
end

function Field:destroy()
if self.Instance then
Motion.cancelAll(self.Instance)
self.Instance:Destroy()
self.Instance = nil
end
end

return Field
end

__modules["Primitives.Ripple"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")

local Ripple = {}
Ripple.__index = Ripple

local MAX_POOL = 6

function Ripple.new(host: any, options: { [any]: any }?)
local self = setmetatable({
_host = host,
_options = options or {},
_pool = {},
_live = 0,
_seed = 0,
}, Ripple)

host.ClipsDescendants = true
if self._options.clip ~= false then
Util.corner(host, self._options.radius or 8)
end

return self
end

local function acquire(self: any)
for _, ripple in ipairs(self._pool) do
if not ripple.busy then
return ripple
end
end
if #self._pool >= MAX_POOL then

local oldest = self._pool[1]
table.remove(self._pool, 1)
return oldest
end

local frame = Util.frame({
Name = "VantageRipple",
AnchorPoint = Vector2.new(0.5, 0.5),
BackgroundColor3 = Color3.new(1, 1, 1),
BackgroundTransparency = 1,
Size = UDim2.fromOffset(0, 0),
ZIndex = self._options.zIndex or 4,
Parent = self._host,
})
Util.pill(frame)

local entry = { frame = frame, busy = false, tween = nil }
table.insert(self._pool, entry)
return entry
end

function Ripple:burst(x: number?, y: number?, options: { [any]: any }?)
local opts = self._options
local override = options or {}

local size = self._host.AbsoluteSize
local width, height = size.X, size.Y
if width <= 0 or height <= 0 then

return
end

local originX = x or width * 0.5
local originY = y or height * 0.5

local radius = math.max(
math.sqrt(originX * originX + originY * originY),
math.sqrt((width - originX) ^ 2 + originY * originY),
math.sqrt(originX * originX + (height - originY) ^ 2),
math.sqrt((width - originX) ^ 2 + (height - originY) ^ 2)
)

local entry = acquire(self)
if entry.tween then
entry.tween:cancel()
entry.tween = nil
end

local frame = entry.frame
entry.busy = true
self._seed += 1
frame.ZIndex = (opts.zIndex or 4) + (self._seed % 3)

local color = override.color or opts.color
if not color then
color = __require("Core.Theme").current().accent
end
frame.BackgroundColor3 = color
frame.BackgroundTransparency = override.transparency or opts.transparency or 0.72
frame.Position = UDim2.fromOffset(originX, originY)
frame.Size = UDim2.fromOffset(0, 0)

local target = radius * 2
local duration = override.duration or opts.duration or 0.52

entry.tween = Motion.tween(frame, {
Size = UDim2.fromOffset(target, target),
BackgroundTransparency = 1,
}, {
duration = duration,
easing = override.easing or "exitSoft",
onComplete = function()
entry.busy = false
entry.tween = nil
end,
})

return entry
end

function Ripple:flash(options: { [any]: any }?)
local opts = table.clone(self._options)
for key, value in pairs(options or {}) do
opts[key] = value
end
local size = self._host.AbsoluteSize
return self:burst(size.X * 0.5, size.Y * 0.5, opts)
end

function Ripple:clear()
for _, entry in ipairs(self._pool) do
if entry.tween then
entry.tween:cancel()
entry.tween = nil
end
entry.busy = false
entry.frame.BackgroundTransparency = 1
entry.frame.Size = UDim2.fromOffset(0, 0)
end
end

function Ripple:destroy()
self:clear()
for _, entry in ipairs(self._pool) do
entry.frame:Destroy()
end
table.clear(self._pool)
end

return Ripple
end

__modules["Primitives.Button"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local Glyph = __require("Core.Glyph")
local Config = __require("Core.Config")
local Signal = __require("Core.Signal")
local Ripple = __require("Primitives.Ripple")

local Button = {}
Button.__index = Button

local VARIANTS = {
primary = {
background = "accent",
backgroundHover = "accentHover",
backgroundPressed = "accentPressed",
foreground = "onAccent",
border = "accentHover",
borderStrength = 0.0,
ripple = "onAccent",
},
secondary = {
background = "elevated",
backgroundHover = "raised",
backgroundPressed = "overlay",
foreground = "text",
border = "border",
borderStrength = 1.0,
ripple = "accent",
},
subtle = {
background = "surfaceAlt",
backgroundHover = "hover",
backgroundPressed = "pressed",
foreground = "textMuted",
border = "borderSubtle",
borderStrength = 1.0,
ripple = "accent",
},
ghost = {
background = nil,
backgroundHover = "hover",
backgroundPressed = "pressed",
foreground = "textMuted",
foregroundHover = "text",
border = nil,
borderStrength = 0.0,
ripple = "accent",
},
danger = {
background = "danger",
backgroundHover = "danger",
backgroundPressed = "danger",
foreground = "onDanger",
border = "danger",
borderStrength = 0.0,
ripple = "onDanger",
hoverLighten = 0.12,
pressedDarken = 0.14,
},
success = {
background = "success",
backgroundHover = "success",
backgroundPressed = "success",
foreground = "onSuccess",
border = "success",
borderStrength = 0.0,
ripple = "onSuccess",
hoverLighten = 0.12,
pressedDarken = 0.14,
},
link = {
background = nil,
backgroundHover = nil,
backgroundPressed = nil,
foreground = "accent",
foregroundHover = "accentHover",
border = nil,
borderStrength = 0.0,
ripple = "accent",
},
}

local SIZES = {
sm = { height = 26, padding = 10, fontSize = "fontSizeSm", gap = 6, iconSize = 12 },
md = { height = 32, padding = 14, fontSize = "fontSizeMd", gap = 8, iconSize = 14 },
lg = { height = 40, padding = 18, fontSize = "fontSizeLg", gap = 9, iconSize = 16 },
}

local function playCue(name: string)
local sounds = Config.sounds
if not sounds or not sounds.enabled then
return
end
local id = sounds[name]
if not id or id == "" then
return
end
local ok = pcall(function()
local sound = Instance.new("Sound")
sound.SoundId = id
sound.Volume = sounds.volume or 0.35
sound.Parent = game:GetService("SoundService")
sound:Play()
task.delay(3, function()
sound:Destroy()
end)
end)
return ok
end

function Button.new(spec: { [any]: any }, context: { [any]: any }?): any
local ctx = context or {}
local tokens = Theme.current()
local sizeSpec = SIZES[spec.Size or "md"] or SIZES.md
local variant = VARIANTS[spec.Variant or "secondary"] or VARIANTS.secondary

local self = setmetatable({
_spec = spec,
_variantName = spec.Variant or "secondary",
_variant = variant,
_sizeName = spec.Size or "md",
_size = sizeSpec,
_maid = ctx.maid,
_disabled = spec.Disabled == true,
_loading = spec.Loading == true,
_fullWidth = spec.FullWidth == true,
_confirming = false,
_hovering = false,
_pressing = false,
_tokens = tokens,
}, Button)

self.Clicked = Signal.new("Button.Clicked")

local height = sizeSpec.height

local root = Util.frame({
Name = "VantageButton",
BackgroundColor3 = variant.background and tokens[variant.background] or tokens.surface,
BackgroundTransparency = variant.background and 0 or 1,
Size = UDim2.new(self._fullWidth and 1 or 0, 0, 0, height),
AutomaticSize = self._fullWidth and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
ClipsDescendants = true,
LayoutOrder = spec.LayoutOrder or 1,
Parent = ctx.parent,
})
Util.tag(root, "Vantage")
if spec.Text then
root.Name = "VantageButton_" .. tostring(spec.Text)
end
Util.corner(root, tokens.radiusMd)
self.Instance = root

local stroke
if variant.border then
stroke = Util.stroke(root, tokens[variant.border], 1, 1 - variant.borderStrength)
end
self._stroke = stroke

local focusRing = Util.frame({
Name = "FocusRing",
BackgroundTransparency = 1,
Size = UDim2.new(1, 4, 1, 4),
Position = UDim2.fromOffset(-2, -2),
Visible = false,
ZIndex = 0,
Parent = root,
})
Util.corner(focusRing, tokens.radiusMd + 2)
local focusStroke = Util.stroke(focusRing, tokens.focusRing, tokens.focusWidth, 1)
self._focusRing = focusRing
self._focusStroke = focusStroke

local content = Util.row({
Name = "Content",
AnchorPoint = Vector2.new(0, 0.5),
Position = UDim2.new(0, sizeSpec.padding, 0.5, 0),
Size = self._fullWidth and UDim2.new(1, -sizeSpec.padding * 2, 1, 0) or UDim2.new(0, 0, 1, 0),
AutomaticSize = self._fullWidth and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
Parent = root,
})
Util.list(content, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, sizeSpec.gap),
VerticalAlignment = Enum.VerticalAlignment.Center,
HorizontalAlignment = spec.Align == "left" and Enum.HorizontalAlignment.Left
or (spec.Align == "right" and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Center),
})
self.Content = content

local iconHolder = Util.row({
Name = "Icon",
Size = UDim2.fromOffset(sizeSpec.iconSize, sizeSpec.iconSize),
LayoutOrder = 1,
Visible = false,
Parent = content,
})
self._iconHolder = iconHolder

local label = Util.text({
Name = "Label",
Text = spec.Text or "",
TextSize = tokens[sizeSpec.fontSize],
Font = "bodyMedium",
TextColor3 = variant.foreground and tokens[variant.foreground] or tokens.text,
TextXAlignment = Enum.TextXAlignment.Center,
TextYAlignment = Enum.TextYAlignment.Center,
TextTruncate = Enum.TextTruncate.AtEnd,
Size = UDim2.new(0, 0, 0, sizeSpec.fontSize and tokens[sizeSpec.fontSize] + 4 or 18),
AutomaticSize = Enum.AutomaticSize.X,
LayoutOrder = 2,
Parent = content,
})
self.Label = label

local shortcutHolder = Util.row({
Name = "Shortcut",
Size = UDim2.new(0, 0, 0, 18),
AutomaticSize = Enum.AutomaticSize.X,
LayoutOrder = 3,
Visible = false,
Parent = content,
})
self._shortcutHolder = shortcutHolder

local shortcutLabel = Util.text({
Name = "ShortcutLabel",
Text = "",
TextSize = tokens.fontSizeXs + 1,
Font = "mono",
TextColor3 = tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Center,
TextYAlignment = Enum.TextYAlignment.Center,
Size = UDim2.new(0, 0, 1, 0),
AutomaticSize = Enum.AutomaticSize.X,
Parent = shortcutHolder,
})
Util.pad(shortcutHolder, { Left = 6, Right = 6 })
self._shortcutLabel = shortcutLabel

local spinnerHolder = Util.row({
Name = "Spinner",
Size = UDim2.fromOffset(sizeSpec.iconSize, sizeSpec.iconSize),
LayoutOrder = 0,
Visible = false,
Parent = content,
})
self._spinnerHolder = spinnerHolder
local spinner = Glyph.draw(spinnerHolder, "loader", {
size = sizeSpec.iconSize,
color = variant.foreground and tokens[variant.foreground] or tokens.text,
weight = 12,
zIndex = 4,
})
self._spinner = spinner
if spinner then
self._spinnerRotation = Motion.tween(spinner, { Rotation = 360 }, {
duration = 0.9,
easing = "linear",
repeatCount = -1,
})
end

local rippleLayer = Util.row({
Name = "Ripples",
Size = UDim2.fromScale(1, 1),
Parent = root,
})
rippleLayer.ZIndex = 3
content.ZIndex = 4
local ripple = Ripple.new(rippleLayer, {
radius = tokens.radiusMd,
zIndex = 3,
color = variant.ripple and tokens[variant.ripple] or tokens.text,
transparency = variant == VARIANTS.primary and 0.78 or 0.78,
})
self._ripple = ripple

local confirmOverlay = Util.row({
Name = "Confirm",
Size = UDim2.fromScale(1, 1),
BackgroundColor3 = tokens.dangerSurface,
BackgroundTransparency = 1,
Visible = false,
ZIndex = 6,
Parent = root,
})
Util.corner(confirmOverlay, tokens.radiusMd)
local confirmLabel = Util.text({
Name = "ConfirmLabel",
Text = spec.ConfirmText or "Click again to confirm",
TextSize = tokens.fontSizeSm,
Font = "bodyMedium",
TextColor3 = tokens.danger,
TextXAlignment = Enum.TextXAlignment.Center,
Size = UDim2.fromScale(1, 1),
Parent = confirmOverlay,
})
self._confirmOverlay = confirmOverlay
self._confirmLabel = confirmLabel

local hit = Util.create("TextButton", {
Name = "Hit",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
Size = UDim2.fromScale(1, 1),
ZIndex = 8,
Parent = root,
})
root.Active = true
self._hit = hit

local function resolveColor(key: string?)
return key and tokens[key] or nil
end

local function applyState(animated: boolean?)

local opts = Motion.options((animated == false) and "instant" or "hover")
local v = self._variant
local disabled = self._disabled
local background, foreground, border, transparency

if disabled then
background = resolveColor(v.background)
foreground = tokens.textDim
border = v.border and tokens.borderSubtle or nil
transparency = 1 - (v.borderStrength > 0 and 0.55 or 0.38)
elseif self._pressing and not self._confirming then
background = resolveColor(v.backgroundPressed)
foreground = resolveColor(v.foreground) or tokens.text
border = resolveColor(v.border)
transparency = 0
if background and v.pressedDarken then
background = Util.darken(background, v.pressedDarken)
end
elseif self._hovering then
background = resolveColor(v.backgroundHover)
foreground = resolveColor(v.foregroundHover) or resolveColor(v.foreground) or tokens.text
border = resolveColor(v.border)
transparency = 0
if background and v.hoverLighten then
background = Util.lighten(background, v.hoverLighten)
end
else
background = resolveColor(v.background)
foreground = resolveColor(v.foreground) or tokens.text
border = resolveColor(v.border)
transparency = 0
end

if background == nil then
root.BackgroundTransparency = 1
else
Motion.tween(root, { BackgroundColor3 = background, BackgroundTransparency = transparency }, opts)
end

local targetForeground = self._loading and tokens.textDim or foreground
Motion.tween(label, { TextColor3 = targetForeground }, opts)
if self._spinner and self._spinnerHolder.Visible then
Glyph.setColor(self._spinner, targetForeground)
end
if self.Icon and self._iconHolder.Visible then
Glyph.setColor(self.Icon, targetForeground)
end
Motion.tween(shortcutLabel, { TextColor3 = tokens.textDim }, opts)

if stroke and border then
Motion.tween(stroke, {
Color = border,
Transparency = disabled and 0.6 or (1 - v.borderStrength),
}, opts)
end
end
self._applyState = applyState

local function pressScale(target: number)
Motion.scale(content, target, {
duration = target < 1 and 0.09 or 0.34,
easing = target < 1 and "exitSoft" or "settle",
})
end
Motion.setScale(content, 1)

local pointerX, pointerY = nil, nil
hit.MouseEnter:Connect(function(x, y)
pointerX, pointerY = x, y
end)
hit.MouseMoved:Connect(function(x, y)
pointerX, pointerY = x, y
end)

local function toLocal(inputPosition: any)
local origin = rippleLayer.AbsolutePosition
return inputPosition.X - origin.X, inputPosition.Y - origin.Y
end

hit.MouseEnter:Connect(function()
self._hovering = true
applyState()
end)
hit.MouseLeave:Connect(function()
self._hovering = false
self._pressing = false
pressScale(1)
applyState()
end)

hit.InputBegan:Connect(function(input)
if self._disabled or self._loading then
return
end
local isActivation = input.UserInputType == Enum.UserInputType.MouseButton1
or input.UserInputType == Enum.UserInputType.Touch
if not isActivation then
return
end

self._pressing = true
pressScale(0.965)

if input.UserInputType == Enum.UserInputType.Touch then
local x, y = toLocal(input.Position)
ripple:burst(x, y)
elseif pointerX then
ripple:burst(pointerX, pointerY)
else
ripple:burst(nil, nil)
end

if not self._confirming then
playCue("click")
end
applyState()
end)

hit.InputEnded:Connect(function(input)
if input.UserInputType ~= Enum.UserInputType.MouseButton1
and input.UserInputType ~= Enum.UserInputType.Touch
then
return
end
self._pressing = false
pressScale(1)
applyState()
end)

local function activate()
if self._disabled or self._loading then
return
end

if spec.Confirm and not self._confirming then
self._confirming = true
confirmOverlay.Visible = true
confirmLabel.Text = spec.ConfirmText or "Click again to confirm"
Motion.tween(confirmOverlay, {
BackgroundTransparency = 0.12,
}, Motion.options("fast", { easing = "enterSnap" }))
Motion.tween(label, { TextTransparency = 1 }, Motion.options("fast"))
self._confirmToken = (self._confirmToken or 0) + 1
local token = self._confirmToken
task.delay(spec.ConfirmTimeout or 2.2, function()
if token == self._confirmToken and self._confirming then
self:resetConfirm()
end
end)
return
end

if self._confirming then
self:resetConfirm()
end

self.Clicked:fire()
Util.safeCall(spec.Callback, self)
end

hit.Activated:Connect(activate)

if ctx.maid then
ctx.maid:add(function()
if self._spinnerRotation then
self._spinnerRotation:cancel()
self._spinnerRotation = nil
end
end)
end

if spec.Shortcut then
shortcutHolder.Visible = true
shortcutLabel.Text = tostring(spec.Shortcut)
shortcutHolder.BackgroundColor3 = tokens.sunken
shortcutHolder.BackgroundTransparency = 0.35
Util.corner(shortcutHolder, tokens.radiusXs)
end

local iconName = spec.Icon
local iconImage = spec.IconImage
if iconName then
iconHolder.Visible = true
local glyph = Glyph.draw(iconHolder, iconName, {
size = sizeSpec.iconSize,
color = variant.foreground and tokens[variant.foreground] or tokens.text,
weight = 12,
zIndex = 4,
})
self.Icon = glyph
elseif iconImage then
iconHolder.Visible = true
self.Icon = Util.image({
Name = "IconImage",
Image = iconImage,
ImageColor3 = variant.foreground and tokens[variant.foreground] or tokens.text,
Size = UDim2.fromScale(1, 1),
BackgroundTransparency = 1,
ZIndex = 4,
Parent = iconHolder,
})
end

if self._loading then
self:setLoading(true)
end
applyState(false)

if (spec.Tooltip or spec.TooltipText) and ctx.tooltip then
ctx.tooltip.attach(hit, spec.Tooltip or spec.TooltipText, spec.TooltipTitle)
end

local function onTheme(next: any)
self._tokens = next
local corner = root:FindFirstChildOfClass("UICorner")
if corner then
corner.CornerRadius = UDim.new(0, next.radiusMd)
end
local confirmCorner = confirmOverlay:FindFirstChildOfClass("UICorner")
if confirmCorner then
confirmCorner.CornerRadius = UDim.new(0, next.radiusMd)
end
if self._focusStroke then
self._focusStroke.Color = next.focusRing
self._focusStroke.Thickness = next.focusWidth
end
applyState(false)
end

if ctx.maid then
ctx.maid:add(Theme.Changed:connect(onTheme))
end

return self
end

function Button:resetConfirm()
self._confirming = false
self._confirmToken = (self._confirmToken or 0) + 1
Motion.tween(self._confirmOverlay, { BackgroundTransparency = 1 }, Motion.options("exit", {
onComplete = function()
self._confirmOverlay.Visible = false
end,
}))
Motion.tween(self.Label, { TextTransparency = 0 }, Motion.options("fast"))
end

function Button:setText(text: string)
if self.Label.Text == text then
return self
end
local previous = self.Label.Text
self.Label.Text = text
if previous == "" or Motion.getReducedMotion() then
return self
end
Motion.tween(self.Label, { TextTransparency = 1 }, Motion.options("exit", {
onComplete = function()
Motion.tween(self.Label, { TextTransparency = self._loading and 0.45 or 0 }, Motion.options("enter"))
end,
}))
return self
end

function Button:getText(): string
return self.Label.Text
end

function Button:setVariant(variant: string)
if VARIANTS[variant] then
self._variantName = variant
self._variant = VARIANTS[variant]
self._applyState()
end
return self
end

function Button:setEnabled(enabled: boolean)
self._disabled = not enabled
self._hit.Active = enabled
self._applyState()
return self
end

function Button:isEnabled(): boolean
return not self._disabled
end

function Button:setLoading(loading: boolean)
self._loading = loading
self._spinnerHolder.Visible = loading
if self.Icon then
self._iconHolder.Visible = not loading
end
Motion.tween(self.Label, { TextTransparency = loading and 0.45 or 0 }, Motion.options("fast"))
if loading then
if self._spinner and self._spinnerRotation then
self._spinnerRotation:resume()
end
elseif self._spinnerRotation then
self._spinnerRotation:pause()
end
self._applyState()
return self
end

function Button:setVisible(visible: boolean)
self.Instance.Visible = visible
return self
end

function Button:onClick(callback: () -> ())
self.Clicked:connect(callback)
return self
end

function Button:invoke()
self.Clicked:fire()
Util.safeCall(self._spec.Callback, self)
end

function Button:flash()
self._ripple:burst(nil, nil)
return self
end

function Button:setTooltip(text: string)
if self._tooltipHandle then
self._tooltipHandle:text(text)
end
return self
end

function Button:destroy()
if self._spinnerRotation then
self._spinnerRotation:cancel()
self._spinnerRotation = nil
end
if self._ripple then
self._ripple:destroy()
end
if self.Clicked then
self.Clicked:destroy()
end
if self.Instance then
Motion.cancelAll(self.Instance)
self.Instance:Destroy()
self.Instance = nil
end
end

Button.playCue = playCue
Button.VARIANTS = VARIANTS
Button.SIZES = SIZES

return Button
end

__modules["Primitives.Toggle"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local Glyph = __require("Core.Glyph")
local Signal = __require("Core.Signal")
local Button = __require("Primitives.Button")
local Field = __require("Layout.Field")

local Toggle = {}
Toggle.__index = Toggle

local TRACK_WIDTH = 40
local TRACK_HEIGHT = 22
local KNOB_INSET = 3

function Toggle.new(spec: { [any]: any }, context: { [any]: any })
local ctx = context or {}
local tokens = Theme.current()

local self = setmetatable({
_spec = spec,
_maid = ctx.maid,
_tokens = tokens,
_value = spec.Value == true,
_enabled = spec.Disabled ~= true,
}, Toggle)

self.Changed = Signal.new("Toggle.Changed")

local field = Field.new({
Name = spec.Name,
Description = spec.Description,
Icon = spec.Icon or "power",
Disabled = spec.Disabled,
ControlWidth = TRACK_WIDTH,
MinHeight = TRACK_HEIGHT + 4,
}, { maid = ctx.maid, parent = ctx.parent })
self.Field = field
self.Instance = field.Instance

local track = Util.frame({
Name = "Track",
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.fromScale(0.5, 0.5),
Size = UDim2.fromOffset(TRACK_WIDTH, TRACK_HEIGHT),
BackgroundColor3 = self._value and tokens.trackOn or tokens.trackOff,
Parent = field.Control,
})
Util.pill(track)
track.Size = UDim2.fromOffset(TRACK_WIDTH, TRACK_HEIGHT)
field.Control.Size = UDim2.fromOffset(TRACK_WIDTH, TRACK_HEIGHT)
field.Control.AutomaticSize = Enum.AutomaticSize.None
self.Track = track

local rim = Util.frame({
Name = "Rim",
Size = UDim2.new(1, -2, 1, -2),
Position = UDim2.fromOffset(1, 1),
BackgroundTransparency = 1,
ZIndex = 1,
Parent = track,
})
Util.pill(rim)
Util.stroke(rim, tokens.borderStrong, 1, 0.75)
self._rim = rim

local knob = Util.frame({
Name = "Knob",
AnchorPoint = Vector2.new(0, 0.5),
Position = UDim2.new(0, KNOB_INSET, 0.5, 0),
Size = UDim2.fromOffset(TRACK_HEIGHT - KNOB_INSET * 2, TRACK_HEIGHT - KNOB_INSET * 2),
BackgroundColor3 = tokens.knob,
ZIndex = 3,
Parent = track,
})
Util.pill(knob)
Util.stroke(knob, tokens.shadow, 1, 0.82)
self.Knob = knob

local check = Glyph.draw(knob, "check", {
size = 9,
color = tokens.onAccent,
weight = 16,
zIndex = 4,
transparency = 1,
})
if check then
check.AnchorPoint = Vector2.new(0.5, 0.5)
check.Position = UDim2.fromScale(0.5, 0.5)
end
self._check = check

local progress = Motion.springFrom("snappy", self._value and 1 or 0)
self._progress = progress

local knobOffsetMax = TRACK_WIDTH - (TRACK_HEIGHT - KNOB_INSET * 2) - KNOB_INSET * 2

if ctx.maid then
ctx.maid:add(function()
progress:destroy()
end)
end

local function onProgress(value: number)
knob.Position = UDim2.new(0, KNOB_INSET + knobOffsetMax * value, 0.5, 0)

track.BackgroundColor3 = Util.mixColor(tokens.trackOff, tokens.trackOn, Util.clamp01(value))
if check then
Glyph.setTransparency(check, 1 - Util.clamp01(value * 1.6 - 0.1))
end
end

progress:observe(onProgress)
onProgress(progress:get())

local hit = Util.create("TextButton", {
Name = "Hit",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
Size = UDim2.new(1, 0, 1, 0),
ZIndex = 6,
Parent = track,
})

local hovering = false

local function refreshHover()
local target = self._value and tokens.accentHover or tokens.borderStrong
if self._value then
target = self._value and (hovering and tokens.accentHover or tokens.trackOn) or track.BackgroundColor3
else
target = hovering and Util.lighten(tokens.trackOff, 0.1) or tokens.trackOff
end
if not self._value then
Motion.tween(track, { BackgroundColor3 = target }, Motion.options("hover"))
end
Motion.scale(knob, hovering and 1.08 or 1, Motion.options("hover"))
end

hit.MouseEnter:Connect(function()
hovering = true
refreshHover()
end)
hit.MouseLeave:Connect(function()
hovering = false
refreshHover()
end)
hit.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1
or input.UserInputType == Enum.UserInputType.Touch
then
Motion.scale(knob, 0.9, Motion.options("press"))
end
end)
hit.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1
or input.UserInputType == Enum.UserInputType.Touch
then
Motion.scale(knob, hovering and 1.08 or 1, Motion.options("release"))
end
end)
hit.Activated:Connect(function()
self:Set(not self._value, true)
end)

field:onActivate(function()
self:Set(not self._value, true)
end)

if ctx.maid then
ctx.maid:add(Theme.Changed:connect(function(next)
tokens = next
self._tokens = next
Util.corner(track, next.radiusPill)
rim:FindFirstChildOfClass("UIStroke").Color = next.borderStrong
knob.BackgroundColor3 = next.knob
if check then
Glyph.setColor(check, next.onAccent)
end
onProgress(progress:get())
end))
end

self._hit = hit
self._onProgress = onProgress
return self
end

function Toggle:Set(value: boolean, fromUser: boolean?)
value = value == true
if self._value == value and not fromUser then
return self
end
self._value = value
self._progress:setGoal(value and 1 or 0)
if fromUser then
Button.playCue("toggle")
self.Changed:fire(value)
Util.safeCall(self._spec.Callback, value, self)
end
return self
end

function Toggle:Get(): boolean
return self._value
end

function Toggle:setEnabled(enabled: boolean)
self._enabled = enabled
self.Field:setDisabled(not enabled)
self._hit.Active = enabled
return self
end

function Toggle:destroy()
if self.Changed then
self.Changed:destroy()
end
self.Field:destroy()
end

return Toggle
end

__modules["Primitives.Slider"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local Signal = __require("Core.Signal")
local Field = __require("Layout.Field")

local Slider = {}
Slider.__index = Slider

local KNOB = 14
local TRACK_HEIGHT = 6
local BUBBLE_HEIGHT = 22

local KEY_STEP = {
[Enum.KeyCode.Right] = 1,
[Enum.KeyCode.Up] = 1,
[Enum.KeyCode.Left] = -1,
[Enum.KeyCode.Down] = -1,
}

function Slider.new(spec: { [any]: any }, context: { [any]: any })
local ctx = context or {}
local tokens = Theme.current()

local minimum = spec.Min or 0
local maximum = spec.Max or 100
if maximum < minimum then
minimum, maximum = maximum, minimum
end
local step = spec.Step or ((maximum - minimum) / 100)
if step <= 0 then
step = (maximum - minimum) / 100
end
local decimals = spec.Decimals or math.max(0, math.min(6, -math.floor(math.log10(step) + 0.0001)))

local self = setmetatable({
_spec = spec,
_maid = ctx.maid,
_tokens = tokens,
_min = minimum,
_max = maximum,
_step = step,
_decimals = decimals,
_value = Util.clamp(spec.Value ~= nil and spec.Value or minimum, minimum, maximum),
_dragging = false,
_hovering = false,
_showTicks = spec.Ticks == true,
_enabled = spec.Disabled ~= true,
}, Slider)

self.Changed = Signal.new("Slider.Changed")
self.Released = Signal.new("Slider.Released")

local function fractionOf(value: number): number
local span = self._max - self._min
if span == 0 then
return 0
end
return Util.clamp01((value - self._min) / span)
end
self._fraction = fractionOf

local controlWidth = spec.ControlWidth or 168

local field = Field.new({
Name = spec.Name,
Description = spec.Description,
Icon = spec.Icon,
Disabled = spec.Disabled,
ControlWidth = controlWidth,
Align = "right",
}, { maid = ctx.maid, parent = ctx.parent })
self.Field = field
self.Instance = field.Instance

local container = field.Control
container.Size = UDim2.fromOffset(controlWidth, 26)
container.AutomaticSize = Enum.AutomaticSize.None

local bubble = Util.row({
Name = "Value",
AnchorPoint = Vector2.new(0.5, 0),
Position = UDim2.new(0, 0, 0, 0),
Size = UDim2.new(0, 0, 0, BUBBLE_HEIGHT),
AutomaticSize = Enum.AutomaticSize.X,
BackgroundColor3 = tokens.elevated,
Parent = container,
})
Util.corner(bubble, tokens.radiusSm)
Util.pad(bubble, { Left = 8, Right = 8 })
Util.stroke(bubble, tokens.border, 1, 0.35)
local bubbleLabel = Util.text({
Name = "ValueLabel",
Text = "0",
TextSize = tokens.fontSizeSm,
Font = "mono",
TextColor3 = tokens.text,
TextXAlignment = Enum.TextXAlignment.Center,
Size = UDim2.new(0, 0, 1, 0),
AutomaticSize = Enum.AutomaticSize.X,
Parent = bubble,
})
self.ValueLabel = bubbleLabel
self._bubble = bubble

local editor = Util.create("TextBox", {
Name = "Editor",
Text = "",
PlaceholderText = "",
TextSize = tokens.fontSizeSm,
Font = Enum.Font.RobotoMono,
TextColor3 = tokens.text,
BackgroundColor3 = tokens.raised,
BackgroundTransparency = 1,
TextXAlignment = Enum.TextXAlignment.Center,
TextYAlignment = Enum.TextYAlignment.Center,
ClearTextOnFocus = true,
Visible = false,
AnchorPoint = Vector2.new(0.5, 0),
Size = UDim2.new(0, 62, 0, BUBBLE_HEIGHT),
ZIndex = 12,
Parent = container,
})
Util.corner(editor, tokens.radiusSm)
local editorStroke = Util.stroke(editor, tokens.accent, 1, 0)
self._editor = editor
self._editorStroke = editorStroke

local track = Util.frame({
Name = "Track",
AnchorPoint = Vector2.new(0, 0.5),
Position = UDim2.new(0, 0, 1, -KNOB * 0.5 - 2),
Size = UDim2.new(1, 0, 0, TRACK_HEIGHT),
BackgroundColor3 = tokens.trackOff,
Parent = container,
})
Util.pill(track)
self.Track = track

local ticks = Util.row({
Name = "Ticks",
Size = UDim2.new(1, 0, 0, 4),
Position = UDim2.new(0, 0, 1, 3),
Parent = container,
})
self._ticks = ticks
self._tickMarks = {}

local fill = Util.frame({
Name = "Fill",
Size = UDim2.new(0, 0, 1, 0),
BackgroundColor3 = tokens.accent,
ZIndex = 2,
Parent = track,
})
Util.pill(fill)
Util.gradient(fill, {
{ Time = 0, Color = tokens.accent },
{ Time = 1, Color = tokens.accentHover },
}, 0)
self.Fill = fill

local knob = Util.frame({
Name = "Knob",
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.new(0, 0, 0.5, 0),
Size = UDim2.fromOffset(KNOB, KNOB),
BackgroundColor3 = tokens.knob,
ZIndex = 4,
Parent = track,
})
Util.pill(knob)
Util.stroke(knob, tokens.accent, 2, 0.15)
self.Knob = knob

local hit = Util.create("TextButton", {
Name = "Hit",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
Size = UDim2.new(1, 0, 0, KNOB + 12),
Position = UDim2.new(0, 0, 0, BUBBLE_HEIGHT + 2),
ZIndex = 8,
Parent = container,
})
self._hit = hit

local indicator = Motion.springFrom("quick", fractionOf(self._value))
self._indicator = indicator

local function format(value: number): string
if type(spec.Format) == "function" then
return tostring(spec.Format(value))
end
local text = string.format("%." .. self._decimals .. "f", value)
if spec.Suffix then
return text .. spec.Suffix
end
return text
end
self.Format = format

local function render(fraction: number)
fraction = Util.clamp01(fraction)
fill.Size = UDim2.new(fraction, 0, 1, 0)
local width = track.AbsoluteSize.X
local knobX = fraction * width
knob.Position = UDim2.new(fraction, 0, 0.5, 0)
bubble.AnchorPoint = Vector2.new(0.5, 0)
local clampedX = Util.clamp(knobX, 26, math.max(26, width - 26))
bubble.Position = UDim2.fromOffset(clampedX, 0)
if not self._editing then
bubbleLabel.Text = format(self._value)
end
end

self._render = render
indicator:observe(render)

if ctx.maid then
ctx.maid:add(function()
indicator:destroy()
end)
end

local function buildTicks()
for _, mark in ipairs(self._tickMarks) do
mark:Destroy()
end
table.clear(self._tickMarks)
if not self._showTicks then
return
end
local span = self._max - self._min
local count = math.floor(span / self._step + 0.5)

if count < 2 or count > 24 then
return
end
for index = 0, count do
local mark = Util.frame({
Name = "Tick",
AnchorPoint = Vector2.new(0.5, 0),
Position = UDim2.new(index / count, 0, 0, 0),
Size = UDim2.fromOffset(1, 4),
BackgroundColor3 = tokens.borderStrong,
BackgroundTransparency = 0.35,
Parent = ticks,
})
table.insert(self._tickMarks, mark)
end
end
self._buildTicks = buildTicks
buildTicks()

local function fractionToValue(fraction: number): number
local raw = self._min + Util.clamp01(fraction) * (self._max - self._min)
local snapped = Util.snap(raw, self._step)
return Util.clamp(tonumber(string.format("%." .. self._decimals .. "f", snapped)) or snapped, self._min, self._max)
end

self._fractionToValue = fractionToValue

local function setValue(value: number, fromUser: boolean?, commit: boolean?)
value = Util.clamp(Util.snap(value, self._step), self._min, self._max)
if self._value == value then
if commit then
self.Released:fire(value)
Util.safeCall(spec.Callback, value, self, true)
end
return
end
self._value = value
self._indicator:setGoal(fractionOf(value))
self.Changed:fire(value, self)
if fromUser then
if spec.CommitOnRelease then
if commit then
Util.safeCall(spec.Callback, value, self, true)
self.Released:fire(value)
end
else
Util.safeCall(spec.Callback, value, self, commit == true)
if commit then
self.Released:fire(value)
end
end
end
end
self.SetValue = setValue

local function fractionFromX(x: number): number
local width = track.AbsoluteSize.X
if width <= 0 then
return 0
end

return (x - track.AbsolutePosition.X) / width
end

local dragging = false
local dragConnection
local releaseConnection

local function stopDrag()
if not dragging and not self._dragging then
return
end
dragging = false
self._dragging = false
if dragConnection then
dragConnection:Disconnect()
dragConnection = nil
end
if releaseConnection then
releaseConnection:Disconnect()
releaseConnection = nil
end
Motion.scale(knob, self._hovering and 1.12 or 1, Motion.options("release"))
Motion.tween(bubble, { BackgroundColor3 = tokens.elevated }, Motion.options("hover"))
setValue(self._value, true, true)
end

local function beginDrag(x: number)
dragging = true
self._dragging = true
Motion.scale(knob, 1.28, Motion.options("press", { duration = 0.12 }))
Motion.tween(bubble, { BackgroundColor3 = tokens.raised }, Motion.options("hover"))
setValue(fractionToValue(fractionFromX(x)), true)
end

local function updateDrag(x: number)
if not dragging then
return
end
setValue(fractionToValue(fractionFromX(x)), true)
end

hit.InputBegan:Connect(function(input)
if not self._enabled then
return
end
local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
local isTouch = input.UserInputType == Enum.UserInputType.Touch
if not (isMouse or isTouch) then
return
end

beginDrag(input.Position.X)

local UserInputService = game:GetService("UserInputService")
if isTouch then
dragConnection = UserInputService.TouchMoved:Connect(function(touchInput)
updateDrag(touchInput.Position.X)
end)
releaseConnection = UserInputService.TouchEnded:Connect(function()
stopDrag()
end)
else
dragConnection = UserInputService.InputChanged:Connect(function(changed)
if changed.UserInputType == Enum.UserInputType.MouseMovement then
updateDrag(changed.Position.X)
end
end)
releaseConnection = UserInputService.InputEnded:Connect(function(changed)
if changed.UserInputType == Enum.UserInputType.MouseButton1 then
stopDrag()
end
end)
end
end)

hit.MouseEnter:Connect(function()
self._hovering = true

self._focused = true
if not dragging then
Motion.scale(knob, 1.12, Motion.options("hover"))
end
end)
hit.MouseLeave:Connect(function()
self._hovering = false
self._focused = false
if not dragging then
Motion.scale(knob, 1, Motion.options("hover"))
end
end)

bubble.Active = true
local bubbleHit = Util.create("TextButton", {
Name = "ValueHit",
Text = "",
BackgroundTransparency = 1,
Size = UDim2.fromScale(1, 1),
ZIndex = 9,
Parent = bubble,
})
self._bubbleHit = bubbleHit

local function commitEdit()
local parsed = tonumber(self._editor.Text)
self._editing = false
editor.Visible = false
bubbleLabel.Visible = true
if parsed then
setValue(parsed, true, true)
end
self._indicator:snap(fractionOf(self._value))
render(fractionOf(self._value))
end

bubbleHit.Activated:Connect(function()
if not self._enabled or self._editing then
return
end
self._editing = true
editor.Text = string.format("%." .. self._decimals .. "f", self._value)
bubbleLabel.Visible = false
editor.Visible = true
editor:CaptureFocus()
end)
editor.FocusLost:Connect(commitEdit)

field:onActivate(function()
if not self._enabled then
return
end
bubbleHit:Activate()
end)

local keyConnection
local function onKey(input, processed)
if processed or not self._enabled or not self._focused then
return
end
local direction = KEY_STEP[input.KeyCode]
if direction then
local increment = self._step * (input:IsModifierKeyDown(Enum.KeyCode.LeftShift) and 0.1 or 1)
setValue(self._value + direction * math.max(increment, 10 ^ -self._decimals), true, true)
elseif input.KeyCode == Enum.KeyCode.PageUp then
setValue(self._value + (self._max - self._min) * 0.1, true, true)
elseif input.KeyCode == Enum.KeyCode.PageDown then
setValue(self._value - (self._max - self._min) * 0.1, true, true)
elseif input.KeyCode == Enum.KeyCode.Home then
setValue(self._min, true, true)
elseif input.KeyCode == Enum.KeyCode.End then
setValue(self._max, true, true)
else
return
end
end

local UserInputService = game:GetService("UserInputService")
keyConnection = UserInputService.InputBegan:Connect(onKey)
if ctx.maid then
ctx.maid:add(keyConnection)
ctx.maid:add(function()
stopDrag()
end)
end
self._focused = false

if ctx.maid then
ctx.maid:add(Theme.Changed:connect(function(next)
tokens = next
self._tokens = next
track.BackgroundColor3 = next.trackOff
knob.BackgroundColor3 = next.knob
local knobStroke = knob:FindFirstChildOfClass("UIStroke")
if knobStroke then
knobStroke.Color = next.accent
end
bubble.BackgroundColor3 = next.elevated
bubbleLabel.TextColor3 = next.text
editor.TextColor3 = next.text
editor.BackgroundColor3 = next.raised
editorStroke.Color = next.accent
Util.gradient(fill, {
{ Time = 0, Color = next.accent },
{ Time = 1, Color = next.accentHover },
}, 0)
for _, mark in ipairs(self._tickMarks) do
mark.BackgroundColor3 = next.borderStrong
end
end))
end

self._render = render
render(fractionOf(self._value))
indicator:snap(fractionOf(self._value))

return self
end

function Slider:Get(): number
return self._value
end

function Slider:Set(value: number, fromUser: boolean?)
self.SetValue(value, fromUser, true)
return self
end

function Slider:setEnabled(enabled: boolean)
self._enabled = enabled
self.Field:setDisabled(not enabled)
self._hit.Active = enabled
return self
end

function Slider:destroy()
if self.Changed then
self.Changed:destroy()
end
if self.Released then
self.Released:destroy()
end
self.Field:destroy()
end

return Slider
end

__modules["Primitives.Dropdown"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local Glyph = __require("Core.Glyph")
local Signal = __require("Core.Signal")
local Field = __require("Layout.Field")

local Dropdown = {}
Dropdown.__index = Dropdown

local ROW_HEIGHT = 28
local MAX_VISIBLE_ROWS = 7
local SEARCH_THRESHOLD = 8

local function normalizeOptions(options: { any }): { any }
local out = {}
for index, option in ipairs(options) do
if type(option) == "table" then
table.insert(out, {
label = tostring(option.Label or option.Value or option),
value = option.Value ~= nil and option.Value or option.Label,
description = option.Description,
icon = option.Icon,
swatch = option.Swatch,
subtitle = option.Subtitle,
})
else
table.insert(out, {
label = tostring(option),
value = option,
})
end
end
return out
end

function Dropdown.new(spec: { [any]: any }, context: { [any]: any })
local ctx = context or {}
local tokens = Theme.current()
local options = normalizeOptions(spec.Options or {})
assert(#options > 0, "[Vantage] Dropdown requires at least one option")

local multi = spec.Multi == true
local searchable = spec.Searchable
if searchable == nil then
searchable = #options >= SEARCH_THRESHOLD
end

local self = setmetatable({
_spec = spec,
_maid = ctx.maid,
_tokens = tokens,
_options = options,
_multi = multi,
_open = false,
_selected = {},
_highlight = 1,
_query = "",
_enabled = spec.Disabled ~= true,
}, Dropdown)

self.Changed = Signal.new("Dropdown.Changed")
self.Opened = Signal.new("Dropdown.Opened")
self.Closed = Signal.new("Dropdown.Closed")

local seed = spec.Value
if seed ~= nil and not multi then
seed = { seed }
end
if type(seed) ~= "table" then
seed = {}
end
for _, value in ipairs(seed) do
self._selected[value] = true
end

local controlWidth = spec.ControlWidth or 190

local field = Field.new({
Name = spec.Name,
Description = spec.Description,
Icon = spec.Icon,
Disabled = spec.Disabled,
ControlWidth = controlWidth,
}, { maid = ctx.maid, parent = ctx.parent })
self.Field = field
self.Instance = field.Instance

local container = field.Control
container.Size = UDim2.fromOffset(controlWidth, 32)
container.AutomaticSize = Enum.AutomaticSize.None

local shell = Util.frame({
Name = "Shell",
Size = UDim2.fromScale(1, 1),
BackgroundColor3 = tokens.sunken,
Parent = container,
})
Util.corner(shell, tokens.radiusSm)
local shellStroke = Util.stroke(shell, tokens.border, 1, 0.2)
Util.pad(shell, { Left = 10, Right = 26 })
self._shell = shell
self._shellStroke = shellStroke

local swatch = Util.frame({
Name = "Swatch",
AnchorPoint = Vector2.new(0, 0.5),
Position = UDim2.new(0, 9, 0.5, 0),
Size = UDim2.fromOffset(10, 10),
BackgroundColor3 = tokens.accent,
Visible = false,
ZIndex = 3,
Parent = shell,
})
Util.pill(swatch)
self._swatch = swatch

local valueLabel = Util.text({
Name = "Value",
Text = spec.Placeholder or "Select...",
TextSize = tokens.fontSizeSm,
Font = "body",
TextColor3 = tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Center,
TextTruncate = Enum.TextTruncate.AtEnd,
Size = UDim2.fromScale(1, 1),
ZIndex = 3,
Parent = shell,
})
self.ValueLabel = valueLabel

local chevronHolder = Util.row({
Name = "Chevron",
AnchorPoint = Vector2.new(1, 0.5),
Position = UDim2.new(1, -8, 0.5, 0),
Size = UDim2.fromOffset(10, 10),
ZIndex = 3,
Parent = shell,
})
local chevron = Glyph.draw(chevronHolder, "chevron-down", {
size = 10,
color = tokens.textDim,
weight = 14,
zIndex = 3,
})
self._chevron = chevron

local hit = Util.create("TextButton", {
Name = "Hit",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
Size = UDim2.fromScale(1, 1),
ZIndex = 6,
Parent = shell,
})
self._hit = hit

local layer = ctx.layer or container.Parent or container
local panel = Util.frame({
Name = "VantageDropdownPanel",
AnchorPoint = Vector2.new(0, 0),
Position = UDim2.fromOffset(0, 0),
Size = UDim2.fromOffset(controlWidth, 0),
BackgroundColor3 = tokens.elevated,
ClipsDescendants = true,
Visible = false,
ZIndex = 200,
Parent = layer,
})
Util.corner(panel, tokens.radiusMd)
Util.stroke(panel, tokens.border, 1, 0.15)
Util.tag(panel, "Vantage")
self.Panel = panel

local panelInner = Util.row({
Name = "Inner",
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
Position = UDim2.fromOffset(0, 0),
Parent = panel,
})
Util.stack(panelInner, 0)
self._panelInner = panelInner

local searchHolder = Util.row({
Name = "Search",
Size = UDim2.new(1, 0, 0, 30),
LayoutOrder = 1,
Visible = searchable,
Parent = panelInner,
})
Util.pad(searchHolder, { Left = 10, Right = 10, Top = 6, Bottom = 0 })
self._searchHolder = searchHolder

local searchShell = Util.frame({
Name = "SearchShell",
Size = UDim2.fromScale(1, 1),
BackgroundColor3 = tokens.sunken,
Parent = searchHolder,
})
Util.corner(searchShell, tokens.radiusSm)
Util.pad(searchShell, { Left = 24, Right = 8 })

local searchGlyphHolder = Util.row({
Name = "Icon",
AnchorPoint = Vector2.new(0, 0.5),
Position = UDim2.new(0, 7, 0.5, 0),
Size = UDim2.fromOffset(11, 11),
ZIndex = 4,
Parent = searchShell,
})
local searchGlyph = Glyph.draw(searchGlyphHolder, "search", {
size = 11,
color = tokens.textDim,
weight = 12,
zIndex = 4,
})
self._searchGlyph = searchGlyph

local searchBox = Util.create("TextBox", {
Name = "SearchBox",
Text = "",
PlaceholderText = "Search...",
PlaceholderColor3 = tokens.textDim,
TextSize = tokens.fontSizeSm,
Font = Enum.Font.Gotham,
TextColor3 = tokens.text,
BackgroundTransparency = 1,
TextXAlignment = Enum.TextXAlignment.Left,
Size = UDim2.fromScale(1, 1),
ClearTextOnFocus = false,
ZIndex = 4,
Parent = searchShell,
})
Util.applyFont(searchBox, "body")
self._searchBox = searchBox

local rowsHolder = Util.row({
Name = "Rows",
Size = UDim2.new(1, 0, 0, 0),
LayoutOrder = 2,
Parent = panelInner,
})
Util.stack(rowsHolder, 0)
self._rowsHolder = rowsHolder

local scroll = Util.create("ScrollingFrame", {
Name = "Scroll",
LayoutOrder = 2,
Size = UDim2.new(1, 0, 0, 0),
BackgroundTransparency = 1,
BorderSizePixel = 0,
ScrollBarThickness = 3,
ScrollBarImageColor3 = tokens.borderStrong,
ScrollBarImageTransparency = 0.25,
CanvasSize = UDim2.new(0, 0, 0, 0),
AutomaticCanvasSize = Enum.AutomaticSize.Y,
ScrollingDirection = Enum.ScrollingDirection.Y,
ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
ZIndex = 200,
Parent = panelInner,
})
rowsHolder.Parent = scroll
rowsHolder.Size = UDim2.new(1, 0, 0, 0)
rowsHolder.Position = UDim2.fromOffset(0, 0)
self._scroll = scroll

local empty = Util.text({
Name = "Empty",
Text = "No matches",
TextSize = tokens.fontSizeSm,
Font = "body",
TextColor3 = tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Center,
TextYAlignment = Enum.TextYAlignment.Center,
Size = UDim2.new(1, 0, 0, 44),
Visible = false,
LayoutOrder = 3,
Parent = panelInner,
})
self._empty = empty

local rows = {}
self._rows = rows

local function rowSelected(row): boolean
return self._selected[row.option.value] == true
end

local function refreshRow(row, animated: boolean?)
local active = rowSelected(row)
local highlighted = row.index == self._highlight
local opts = Motion.options((animated == false) and "instant" or "fast")

if row.checkbox then
Motion.tween(row.checkbox, {
BackgroundColor3 = active and tokens.accent or Color3.new(0, 0, 0),
BackgroundTransparency = active and 0 or 1,
}, opts)
if row.check then
Glyph.setColor(row.check, tokens.onAccent)
Glyph.setTransparency(row.check, active and 0 or 1)
end
local stroke = row.checkbox:FindFirstChildOfClass("UIStroke")
if stroke then
Motion.tween(stroke, { Transparency = active and 0 or 0.4 }, opts)
end
end

local background = nil
if active and not multi then
background = tokens.selected
elseif highlighted then
background = tokens.hover
end

if background then
Motion.tween(row.frame, { BackgroundColor3 = background, BackgroundTransparency = 0 }, opts)
else
Motion.tween(row.frame, { BackgroundTransparency = 1 }, opts)
end

Motion.tween(row.label, {
TextColor3 = active and tokens.text or (highlighted and tokens.text or tokens.textMuted),
}, opts)
end
self._refreshRow = refreshRow

local function buildRows()
for _, row in ipairs(rows) do
row.frame:Destroy()
end
table.clear(rows)

for index, option in ipairs(options) do
local row = Util.row({
Name = "Row" .. index,
Size = UDim2.new(1, 0, 0, ROW_HEIGHT + (option.description and 12 or 0)),
LayoutOrder = index,
Parent = rowsHolder,
})
Util.pad(row, { Left = 8, Right = 8 })
Util.corner(row, tokens.radiusXs)

local entry = {
index = index,
option = option,
frame = row,
}

local cursor = 8
if multi then
local checkbox = Util.frame({
Name = "Check",
AnchorPoint = Vector2.new(0, 0.5),
Position = UDim2.new(0, 8, 0.5, 0),
Size = UDim2.fromOffset(14, 14),
BackgroundColor3 = tokens.accent,
BackgroundTransparency = 1,
ZIndex = 4,
Parent = row,
})
Util.corner(checkbox, 4)
Util.stroke(checkbox, tokens.borderStrong, 1, 0.4)
local check = Glyph.draw(checkbox, "check", {
size = 9,
color = tokens.onAccent,
weight = 16,
zIndex = 5,
transparency = 1,
})
if check then
check.AnchorPoint = Vector2.new(0.5, 0.5)
check.Position = UDim2.fromScale(0.5, 0.5)
end
entry.checkbox = checkbox
entry.check = check
cursor = 30
elseif option.swatch then
local swatchRow = Util.frame({
Name = "Swatch",
AnchorPoint = Vector2.new(0, 0.5),
Position = UDim2.new(0, 10, 0.5, option.description and 0.34 or 0.5),
Size = UDim2.fromOffset(10, 10),
BackgroundColor3 = option.swatch,
ZIndex = 4,
Parent = row,
})
Util.pill(swatchRow)
cursor = 28
elseif option.icon then
local iconHolder = Util.row({
Name = "Icon",
AnchorPoint = Vector2.new(0, 0.5),
Position = UDim2.new(0, 9, 0.5, option.description and 0.34 or 0.5),
Size = UDim2.fromOffset(12, 12),
ZIndex = 4,
Parent = row,
})
Glyph.draw(iconHolder, option.icon, {
size = 12,
color = tokens.textDim,
weight = 12,
zIndex = 4,
})
cursor = 28
end

local label = Util.text({
Name = "Label",
Text = option.label,
TextSize = tokens.fontSizeSm,
Font = "body",
TextColor3 = tokens.textMuted,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Center,
TextTruncate = Enum.TextTruncate.AtEnd,
Position = UDim2.fromOffset(cursor, 0),
Size = UDim2.new(1, -(cursor + 8), 0, option.description and ROW_HEIGHT or (ROW_HEIGHT + 12)),
ZIndex = 4,
Parent = row,
})
entry.label = label

if option.description then
entry.description = Util.text({
Name = "Sub",
Text = option.description,
TextSize = tokens.fontSizeXs + 1,
Font = "body",
TextColor3 = tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
TextTruncate = Enum.TextTruncate.AtEnd,
Position = UDim2.fromOffset(cursor, ROW_HEIGHT),
Size = UDim2.new(1, -(cursor + 8), 0, 12),
ZIndex = 4,
Parent = row,
})
end

local rowHit = Util.create("TextButton", {
Name = "Hit",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
Size = UDim2.fromScale(1, 1),
ZIndex = 6,
Parent = row,
})
entry.hit = rowHit

rowHit.MouseEnter:Connect(function()
self._highlight = index
for _, other in ipairs(rows) do
refreshRow(other)
end
end)
rowHit.Activated:Connect(function()
self:_selectRow(entry, true)
end)

table.insert(rows, entry)
end
end
self._buildRows = buildRows
buildRows()

local visibleRows = math.min(#options, MAX_VISIBLE_ROWS)
local panelHeight = visibleRows * ROW_HEIGHT + (searchable and 36 or 8) + 8
self._panelHeight = panelHeight

local function layoutPanel()
local viewport = Util.viewport()
local insets = Util.insets()
local origin = shell.AbsolutePosition
local size = shell.AbsoluteSize

local width = math.max(size.X, 150)
local spaceBelow = viewport.Y - (origin.Y + size.Y) - insets.bottom - 8
local spaceAbove = origin.Y - insets.top - 8

local height = math.min(panelHeight, math.max(spaceBelow, spaceAbove))
local flip = spaceBelow < panelHeight and spaceAbove > spaceBelow

local y = flip and (origin.Y - height - 4) or (origin.Y + size.Y + 4)
local x = Util.clamp(origin.X, insets.left + 4, viewport.X - width - insets.right - 4)
y = Util.clamp(y, insets.top + 4, viewport.Y - height - insets.bottom - 4)

panel.Size = UDim2.fromOffset(width, height)
panel.Position = UDim2.fromOffset(x, y)
scroll.Size = UDim2.new(1, 0, 0, math.max(0, height - (searchable and 36 or 8)))
searchHolder.Size = UDim2.new(1, 0, 0, searchable and 30 or 0)
searchHolder.Visible = searchable
end
self._layoutPanel = layoutPanel

local visible = {}
self._visible = visible

local function applyFilter()
local query = self._query
local matches = {}
for index, option in ipairs(options) do
local haystack = option.description and (option.label .. " " .. option.description) or option.label
local score, positions = Util.fuzzyMatch(query, haystack)
if score then
table.insert(matches, { index = index, score = score, positions = positions })
end
end
if query ~= "" then
table.sort(matches, function(a, b)
if a.score == b.score then
return a.index < b.index
end
return a.score > b.score
end)
end

table.clear(visible)
for order, match in ipairs(matches) do
local row = rows[match.index]
if row then
row.frame.Visible = true
row.frame.LayoutOrder = order
table.insert(visible, row)
end
end
for _, row in ipairs(rows) do
if not table.find(visible, row) then
row.frame.Visible = false
end
end

empty.Visible = #visible == 0
scroll.CanvasSize = UDim2.new(0, 0, 0, #visible * ROW_HEIGHT + 8)

if #visible > 0 then
local stillVisible = false
for _, row in ipairs(visible) do
if row.index == self._highlight then
stillVisible = true
break
end
end
if not stillVisible then
self._highlight = visible[1].index
end
end
for _, row in ipairs(rows) do
refreshRow(row)
end
end
self._applyFilter = applyFilter

local function ensureVisible()
local row = rows[self._highlight]
if not row then
return
end
local top = 0
for _, candidate in ipairs(visible) do
if candidate == row then
break
end
top += candidate.frame.AbsoluteSize.Y
end
local bottom = top + row.frame.AbsoluteSize.Y
local viewTop = scroll.CanvasPosition.Y
local viewBottom = viewTop + scroll.AbsoluteSize.Y
if top < viewTop then
Motion.tween(scroll, { CanvasPosition = Vector2.new(0, top) }, Motion.options("fast"))
elseif bottom > viewBottom then
Motion.tween(scroll, { CanvasPosition = Vector2.new(0, bottom - scroll.AbsoluteSize.Y) }, Motion.options("fast"))
end
end
self._ensureVisible = ensureVisible

local function summarize()
local picked = {}
for _, option in ipairs(options) do
if self._selected[option.value] then
table.insert(picked, option)
end
end
if #picked == 0 then
valueLabel.Text = spec.Placeholder or "Select..."
valueLabel.TextColor3 = tokens.textDim
swatch.Visible = false
return
end
if multi then
if #picked == 1 then
valueLabel.Text = picked[1].label
else
valueLabel.Text = string.format("%s +%d", picked[1].label, #picked - 1)
end
else
valueLabel.Text = picked[1].label
end
valueLabel.TextColor3 = tokens.text
if picked[1].swatch then
swatch.Visible = true
swatch.BackgroundColor3 = picked[1].swatch
else
swatch.Visible = false
end
end
self._summarize = summarize

function self:_selectRow(row, fromUser: boolean?)
if not fromUser then
return
end
if multi then
self._selected[row.option.value] = not self._selected[row.option.value] or nil
refreshRow(row)
summarize()
local picked = {}
for _, option in ipairs(options) do
if self._selected[option.value] then
table.insert(picked, option.value)
end
end
self.Changed:fire(picked, self)
Util.safeCall(spec.Callback, picked, self)
else
self._selected = {}
self._selected[row.option.value] = true
summarize()
self:Close()
self.Changed:fire(row.option.value, self)
Util.safeCall(spec.Callback, row.option.value, self)
end
end

local function open()
if self._open or not self._enabled then
return
end
self._open = true
self._highlight = self:GetVisibleHighlight()
self._query = ""
searchBox.Text = ""
applyFilter()
layoutPanel()

local targetWidth = math.max(container.AbsoluteSize.X, 150)
panel.Visible = true
panel.ClipsDescendants = true
panel.Size = UDim2.fromOffset(targetWidth, 0)
Motion.tween(panel, { Size = UDim2.fromOffset(targetWidth, panelHeight) }, {
duration = 0.26,
easing = "enterSnap",
})
Motion.setScale(panel, 0.97)
Motion.scale(panel, 1, { duration = 0.26, easing = "enterSnap" })
if chevron then

Motion.tween(chevronHolder, { Rotation = 180 }, Motion.options("enter"))
end
Motion.tween(shellStroke, { Color = tokens.accent, Transparency = 0.45 }, Motion.options("hover"))
Motion.tween(shell, { BackgroundColor3 = tokens.surfaceAlt }, Motion.options("hover"))

local UserInputService = game:GetService("UserInputService")
self._closeConnection = UserInputService.InputBegan:Connect(function(input, processed)
if processed then
return
end
if input.UserInputType == Enum.UserInputType.MouseButton1
or input.UserInputType == Enum.UserInputType.Touch
then
local position = input.Position
local panelRect = {
x = panel.AbsolutePosition.X,
y = panel.AbsolutePosition.Y,
w = panel.AbsoluteSize.X,
h = panel.AbsoluteSize.Y,
}
local inside = position.X >= panelRect.x and position.X <= panelRect.x + panelRect.w
and position.Y >= panelRect.y and position.Y <= panelRect.y + panelRect.h
local shellSize = shell.AbsoluteSize
local shellOrigin = shell.AbsolutePosition
local insideShell = position.X >= shellOrigin.X and position.X <= shellOrigin.X + shellSize.X
and position.Y >= shellOrigin.Y and position.Y <= shellOrigin.Y + shellSize.Y
if not inside and not insideShell then
self:Close()
end
end
end)

self.Opened:fire()
end
self.Open = open

local function close()
if not self._open then
return
end
self._open = false
if self._closeConnection then
self._closeConnection:Disconnect()
self._closeConnection = nil
end
if chevron then
Motion.tween(chevronHolder, { Rotation = 0 }, Motion.options("exit"))
end
Motion.tween(shell, { BackgroundColor3 = tokens.sunken }, Motion.options("hover"))
Motion.tween(shellStroke, { Color = tokens.border, Transparency = 0.2 }, Motion.options("hover"))
Motion.tween(panel, { Size = UDim2.fromOffset(panel.AbsoluteSize.X, 0) }, {
duration = 0.18,
easing = "exit",
onComplete = function()
panel.Visible = false
end,
})
local searchBoxFocused = self._searchBox and self._searchBox:IsFocused()
if searchBoxFocused then
self._searchBox:ReleaseFocus()
end
self.Closed:fire()
end
self.Close = close

hit.Activated:Connect(function()
if self._open then
close()
else
open()
end
end)

hit.MouseEnter:Connect(function()
if not self._open then
Motion.tween(shell, { BackgroundColor3 = tokens.hover }, Motion.options("hover"))
end
end)
hit.MouseLeave:Connect(function()
if not self._open then
Motion.tween(shell, { BackgroundColor3 = tokens.sunken }, Motion.options("hover"))
end
end)

field:onActivate(function()
if self._open then
close()
else
open()
end
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
self._query = searchBox.Text
applyFilter()
ensureVisible()
end)

local UserInputService = game:GetService("UserInputService")
local function onKey(input, processed)
if not self._open then
return
end
if processed and input.KeyCode ~= Enum.KeyCode.Escape then
return
end
local code = input.KeyCode
if code == Enum.KeyCode.Down then
local position = self:GetVisibleIndex()
local next = visible[math.min(position + 1, #visible)]
if next then
self._highlight = next.index
applyFilter()
ensureVisible()
end
elseif code == Enum.KeyCode.Up then
local position = self:GetVisibleIndex()
local next = visible[math.max(position - 1, 1)]
if next then
self._highlight = next.index
applyFilter()
ensureVisible()
end
elseif code == Enum.KeyCode.Return or code == Enum.KeyCode.KeypadEnter then
local row = rows[self._highlight]
if row then
self:_selectRow(row, true)
end
elseif code == Enum.KeyCode.Escape then
close()
elseif code == Enum.KeyCode.Tab then
close()
elseif code == Enum.KeyCode.Home then
if visible[1] then
self._highlight = visible[1].index
applyFilter()
end
elseif code == Enum.KeyCode.End then
local last = visible[#visible]
if last then
self._highlight = last.index
applyFilter()
ensureVisible()
end
end
end
if ctx.maid then
ctx.maid:add(UserInputService.InputBegan:Connect(onKey))
ctx.maid:add(function()
close()
panel:Destroy()
end)
ctx.maid:add(Theme.Changed:connect(function(next)
tokens = next
self._tokens = next
panel.BackgroundColor3 = next.elevated
shell.BackgroundColor3 = self._open and next.surfaceAlt or next.sunken
searchShell.BackgroundColor3 = next.sunken
searchBox.TextColor3 = next.text
summarize()
for _, row in ipairs(rows) do
refreshRow(row)
end
end))
end

summarize()

return self
end

function Dropdown:GetVisibleIndex(): number
for position, row in ipairs(self._visible) do
if row.index == self._highlight then
return position
end
end
return 1
end

function Dropdown:GetHighlightIndex(): number
return self._highlight
end

function Dropdown:Get(): any
if not self._multi then
for _, option in ipairs(self._options) do
if self._selected[option.value] then
return option.value
end
end
return nil
end
local out = {}
for _, option in ipairs(self._options) do
if self._selected[option.value] then
table.insert(out, option.value)
end
end
return out
end

function Dropdown:Set(value: any, fromUser: boolean?)
self._selected = {}
local list = self._multi and (type(value) == "table" and value or { value }) or { value }
for _, entry in ipairs(list) do
if entry ~= nil then
self._selected[entry] = true
end
end
self._summarize()
for _, row in ipairs(self._rows) do
self._refreshRow(row)
end
if fromUser then
self.Changed:fire(self:Get(), self)
Util.safeCall(self._spec.Callback, self:Get(), self)
end
return self
end

function Dropdown:SetOptions(options: { any })
self._options = normalizeOptions(options)
self._highlight = 1
self._buildRows()
self._applyFilter()
self._summarize()
return self
end

function Dropdown:IsOpen(): boolean
return self._open
end

function Dropdown:setEnabled(enabled: boolean)
self._enabled = enabled
self.Field:setDisabled(not enabled)
self._hit.Active = enabled
if not enabled then
self:Close()
end
return self
end

function Dropdown:destroy()
if self.Changed then
self.Changed:destroy()
end
if self.Opened then
self.Opened:destroy()
end
if self.Closed then
self.Closed:destroy()
end
self.Field:destroy()
end

return Dropdown
end

__modules["Primitives.Input"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local Glyph = __require("Core.Glyph")
local Signal = __require("Core.Signal")
local Field = __require("Layout.Field")

local Input = {}
Input.__index = Input

local function sanitizeNumeric(text: string, allowNegative: boolean, allowDecimal: boolean): string
local out = {}
local seenDot = false
for index = 1, #text do
local char = text:sub(index, index)
if char:match("%d") then
table.insert(out, char)
elseif char == "." and allowDecimal and not seenDot then
seenDot = true
table.insert(out, ".")
elseif char == "-" and allowNegative and #out == 0 then
table.insert(out, char)
end
end
return table.concat(out)
end

function Input.new(spec: { [any]: any }, context: { [any]: any })
local ctx = context or {}
local tokens = Theme.current()

local multiline = spec.Multiline == true

local self = setmetatable({
_spec = spec,
_maid = ctx.maid,
_tokens = tokens,
_value = spec.Value or "",
_focused = false,
_enabled = spec.Disabled ~= true,
}, Input)

self.Changed = Signal.new("Input.Changed")
self.Submitted = Signal.new("Input.Submitted")

local controlWidth = spec.ControlWidth or (multiline and 260 or 190)

local field = Field.new({
Name = spec.Name,
Description = spec.Description,
Icon = spec.Icon,
Disabled = spec.Disabled,
ControlWidth = controlWidth,
}, { maid = ctx.maid, parent = ctx.parent })
self.Field = field
self.Instance = field.Instance

local container = field.Control
container.Size = UDim2.fromOffset(controlWidth, multiline and 76 or 32)
container.AutomaticSize = Enum.AutomaticSize.None

local shell = Util.frame({
Name = "Shell",
Size = UDim2.fromScale(1, 1),
BackgroundColor3 = tokens.sunken,
Parent = container,
})
Util.corner(shell, tokens.radiusSm)
local shellStroke = Util.stroke(shell, tokens.border, 1, 0.15)
Util.pad(shell, {
Left = spec.Prefix and 30 or 10,
Right = (spec.Suffix or spec.MaxLength) and 34 or 10,
Top = multiline and 8 or 0,
Bottom = multiline and 8 or 0,
})
self.Shell = shell
self._shellStroke = shellStroke

local box = Util.create(multiline and "TextBox" or "TextBox", {
Name = "Box",
Text = self._value,
PlaceholderText = spec.Placeholder or "",
PlaceholderColor3 = tokens.textDim,
TextSize = tokens.fontSizeMd,
Font = Enum.Font.Gotham,
TextColor3 = tokens.text,
BackgroundTransparency = 1,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
TextWrapped = multiline,
MultiLine = multiline,
ClearTextOnFocus = spec.ClearOnFocus == true,
Size = UDim2.fromScale(1, 1),
ZIndex = 3,
Parent = shell,
})
Util.applyFont(box, "body")
self.Box = box
self._box = box

if spec.MaxLength then
box.TextEditable = true

end

if spec.Prefix then
local prefix = Util.text({
Name = "Prefix",
Text = spec.Prefix,
TextSize = tokens.fontSizeMd,
Font = "body",
TextColor3 = tokens.textDim,
Size = UDim2.new(0, 20, 1, 0),
Position = UDim2.fromOffset(10, 0),
ZIndex = 4,
Parent = shell,
})
self._prefix = prefix
end

local suffixHolder = Util.row({
Name = "Suffix",
AnchorPoint = Vector2.new(1, 0.5),
Position = UDim2.new(1, -10, multiline and 0.5 or 0.5, 0),
Size = UDim2.new(0, 0, 0, 18),
AutomaticSize = Enum.AutomaticSize.X,
ZIndex = 4,
Parent = shell,
})
Util.list(suffixHolder, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 6),
VerticalAlignment = Enum.VerticalAlignment.Center,
})

local counter = Util.text({
Name = "Counter",
Text = "",
TextSize = tokens.fontSizeSm,
Font = "mono",
TextColor3 = tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Right,
Size = UDim2.new(0, 0, 1, 0),
AutomaticSize = Enum.AutomaticSize.X,
LayoutOrder = 1,
Visible = spec.MaxLength ~= nil,
Parent = suffixHolder,
})
self.Counter = counter

local actionHolder = Util.row({
Name = "Action",
Size = UDim2.fromOffset(18, 18),
LayoutOrder = 2,
Visible = false,
Parent = suffixHolder,
})
self._actionHolder = actionHolder
local actionHit = Util.create("TextButton", {
Name = "ActionHit",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
Size = UDim2.fromScale(1, 1),
Parent = actionHolder,
})
local actionGlyph = Glyph.draw(actionHolder, "close", {
size = 10,
color = tokens.textDim,
weight = 13,
zIndex = 5,
})
if actionGlyph then
actionGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
actionGlyph.Position = UDim2.fromScale(0.5, 0.5)
end
self._actionGlyph = actionGlyph
self._actionHit = actionHit

local ring = Util.frame({
Name = "FocusRing",
BackgroundTransparency = 1,
Size = UDim2.new(1, 4, 1, 4),
Position = UDim2.fromOffset(-2, -2),
ZIndex = 1,
Parent = shell,
})
Util.corner(ring, tokens.radiusSm + 2)
local ringStroke = Util.stroke(ring, tokens.accent, tokens.focusWidth, 1)
self._ring = ring
self._ringStroke = ringStroke

local function passesValidation(text: string)
if type(spec.Validator) ~= "function" then
return nil, nil
end
local ok, result, message = pcall(spec.Validator, text)
if not ok then
return false, tostring(result)
end
if result == false then
return false, message or "Invalid value"
end
return true, message
end

local function updateCounter()
if not spec.MaxLength then
return
end
local length = utf8.len(box.Text) or #box.Text
counter.Text = string.format("%d/%d", length, spec.MaxLength)
counter.TextColor3 = length >= spec.MaxLength and tokens.warning or tokens.textDim
end
self._updateCounter = updateCounter

local validating = false

local function pushUpdate(commit: boolean?)
local text = box.Text

if spec.MaxLength then
local length = utf8.len(text) or #text
if length > spec.MaxLength then

local kept = {}
local count = 0
for _, code in utf8.codes(text) do
count += 1
if count > spec.MaxLength then
break
end
table.insert(kept, utf8.char(code))
end
text = table.concat(kept)
local wasFocused = self._focused
box.Text = text
self._focused = wasFocused
end
end

if spec.Numeric then
local cleaned = sanitizeNumeric(text, spec.AllowNegative ~= false, spec.AllowDecimal ~= false)
if cleaned ~= text then

local caret = box.CursorPosition
box.Text = cleaned
pcall(function()
box.CursorPosition = math.max(1, caret - (#text - #cleaned))
end)
text = cleaned
end
end

self._value = text
updateCounter()

if validating then
return
end
validating = true
task.defer(function()
validating = false
local ok, message = passesValidation(self._value)
if ok == nil then
return
end
if ok then
field:setStatus("success", message)
else
field:setStatus("error", message)
end
end)

self.Changed:fire(text, self)
Util.safeCall(spec.Callback, text, self)
if commit then
self.Submitted:fire(text, self)
Util.safeCall(spec.Submit, text, self)
end
end

box:GetPropertyChangedSignal("Text"):Connect(function()
pushUpdate(false)
end)

box.Focused:Connect(function()
self._focused = true
Motion.tween(shell, { BackgroundColor3 = tokens.surfaceAlt }, Motion.options("hover"))
Motion.tween(shellStroke, { Color = tokens.accent, Transparency = 0.4 }, Motion.options("hover"))
ring.Visible = true
ringStroke.Transparency = 1
Motion.tween(ringStroke, { Transparency = 0.35 }, Motion.options("enter", { duration = 0.22 }))
Motion.setScale(ring, 0.97)
Motion.scale(ring, 1, Motion.options("enter", { duration = 0.26 }))
end)

box.FocusLost:Connect(function(enterPressed)
self._focused = false
ring.Visible = false
Motion.tween(shell, { BackgroundColor3 = tokens.sunken }, Motion.options("hover"))
Motion.tween(shellStroke, { Color = tokens.border, Transparency = 0.15 }, Motion.options("hover"))
if enterPressed and not multiline then
pushUpdate(true)
end
end)

local function refreshAction()
local show = self._focused and #box.Text > 0
if self._actionHolder.Visible ~= show then
self._actionHolder.Visible = show
if show then
Motion.setScale(actionHolder, 0.6)
Motion.scale(actionHolder, 1, Motion.options("enter"))
end
end
end
box:GetPropertyChangedSignal("Text"):Connect(refreshAction)
box.Focused:Connect(refreshAction)
box.FocusLost:Connect(refreshAction)

actionHit.Activated:Connect(function()
box.Text = ""
box:CaptureFocus()
end)
actionHit.MouseEnter:Connect(function()
if self._actionGlyph then
Glyph.setColor(self._actionGlyph, tokens.danger)
end
end)
actionHit.MouseLeave:Connect(function()
if self._actionGlyph then
Glyph.setColor(self._actionGlyph, tokens.textDim)
end
end)

field:onActivate(function()
if not self._enabled then
return
end
box:CaptureFocus()
end)

updateCounter()
refreshAction()

if ctx.maid then
ctx.maid:add(Theme.Changed:connect(function(next)
tokens = next
self._tokens = next
shell.BackgroundColor3 = self._focused and next.surfaceAlt or next.sunken
box.TextColor3 = next.text
box.PlaceholderColor3 = next.textDim
ringStroke.Color = next.accent
ringStroke.Thickness = next.focusWidth
if self._prefix then
self._prefix.TextColor3 = next.textDim
end
counter.TextColor3 = next.textDim
updateCounter()
end))
end

return self
end

function Input:Get(): string
return self._value
end

function Input:Set(value: string, silent: boolean?)
self._value = tostring(value)
self._box.Text = self._value
self._updateCounter()
if not silent then
self.Changed:fire(self._value, self)
Util.safeCall(self._spec.Callback, self._value, self)
end
return self
end

function Input:Focus()
self._box:CaptureFocus()
return self
end

function Input:Blur()
self._box:ReleaseFocus()
return self
end

function Input:setEnabled(enabled: boolean)
self._enabled = enabled
self.Field:setDisabled(not enabled)
self._box.TextEditable = enabled
return self
end

function Input:setStatus(level: string?, message: string?)
self.Field:setStatus(level, message)
return self
end

function Input:destroy()
if self.Changed then
self.Changed:destroy()
end
if self.Submitted then
self.Submitted:destroy()
end
self.Field:destroy()
end

return Input
end

__modules["Primitives.Keybind"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local Glyph = __require("Core.Glyph")
local Signal = __require("Core.Signal")
local Button = __require("Primitives.Button")
local Field = __require("Layout.Field")

local Keybind = {}
Keybind.__index = Keybind

local MOUSE_NAMES = {
[Enum.UserInputType.MouseButton1] = "Mouse 1",
[Enum.UserInputType.MouseButton2] = "Mouse 2",
[Enum.UserInputType.MouseButton3] = "Mouse 3",
[Enum.UserInputType.MouseWheel] = "Wheel",
}

local MODIFIER_ORDER = {
"LeftControl",
"LeftShift",
"LeftAlt",
"RightControl",
"RightShift",
"RightAlt",
}

function Keybind.isModifier(keyCode: any): boolean
for _, name in ipairs(MODIFIER_ORDER) do
if keyCode == Enum.KeyCode[name] then
return true
end
end
return false
end

function Keybind.format(input: any): string
if input.UserInputType == Enum.UserInputType.Keyboard then
if Keybind.isModifier(input.KeyCode) then
return input.KeyCode.Name
end

local parts = {}
local ok, ctrl = pcall(function()
return input:IsModifierKeyDown(Enum.KeyCode.LeftControl)
or input:IsModifierKeyDown(Enum.KeyCode.RightControl)
end)
if ok and ctrl then
table.insert(parts, "Ctrl")
end
local okShift, shift = pcall(function()
return input:IsModifierKeyDown(Enum.KeyCode.LeftShift)
or input:IsModifierKeyDown(Enum.KeyCode.RightShift)
end)
if okShift and shift then
table.insert(parts, "Shift")
end
table.insert(parts, input.KeyCode.Name)
return table.concat(parts, "+")
end

return MOUSE_NAMES[input.UserInputType] or input.UserInputType.Name
end

function Keybind.chordOf(value: any): string
if value == nil then
return ""
end
if typeof(value) == "EnumItem" then
return value.Name
end
if type(value) == "table" then
local parts = {}
for _, entry in ipairs(value) do
local part = Keybind.chordOf(entry)
if part ~= "" then
table.insert(parts, part)
end
end
return table.concat(parts, "+")
end
return tostring(value)
end

function Keybind.new(spec: { [any]: any }, context: { [any]: any })
local ctx = context or {}
local tokens = Theme.current()

local self = setmetatable({
_spec = spec,
_maid = ctx.maid,
_tokens = tokens,
_value = Keybind.chordOf(spec.Value),
_capturing = false,
_enabled = spec.Disabled ~= true,
}, Keybind)

self.Changed = Signal.new("Keybind.Changed")

local field = Field.new({
Name = spec.Name,
Description = spec.Description,
Icon = spec.Icon or "gear",
Disabled = spec.Disabled,
ControlWidth = 104,
}, { maid = ctx.maid, parent = ctx.parent })
self.Field = field
self.Instance = field.Instance

local container = field.Control
container.Size = UDim2.fromOffset(104, 32)
container.AutomaticSize = Enum.AutomaticSize.None

local shell = Util.frame({
Name = "Shell",
Size = UDim2.fromScale(1, 1),
BackgroundColor3 = tokens.sunken,
Parent = container,
})
Util.corner(shell, tokens.radiusSm)
local shellStroke = Util.stroke(shell, tokens.border, 1, 0.2)
self._shell = shell
self._shellStroke = shellStroke

local label = Util.text({
Name = "Key",
Text = self._value ~= "" and self._value or "Unbound",
TextSize = tokens.fontSizeSm,
Font = "mono",
TextColor3 = self._value ~= "" and tokens.text or tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Center,
TextYAlignment = Enum.TextYAlignment.Center,
TextTruncate = Enum.TextTruncate.AtEnd,
Size = UDim2.fromScale(1, 1),
ZIndex = 3,
Parent = shell,
})
Util.pad(shell, { Left = 20, Right = 20 })
self.Label = label

local clearHolder = Util.row({
Name = "Clear",
AnchorPoint = Vector2.new(1, 0.5),
Position = UDim2.new(1, -6, 0.5, 0),
Size = UDim2.fromOffset(14, 14),
Visible = false,
ZIndex = 5,
Parent = shell,
})
local clearGlyph = Glyph.draw(clearHolder, "close", {
size = 8,
color = tokens.textDim,
weight = 13,
zIndex = 5,
})
if clearGlyph then
clearGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
clearGlyph.Position = UDim2.fromScale(0.5, 0.5)
end
self._clearHolder = clearHolder
self._clearGlyph = clearGlyph

local hit = Util.create("TextButton", {
Name = "Hit",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
Size = UDim2.fromScale(1, 1),
ZIndex = 8,
Parent = shell,
})
self._hit = hit

local captureConnection
local UserInputService = game:GetService("UserInputService")

local function stopCapture(cancelled: boolean?)
if not self._capturing then
return
end
self._capturing = false
if captureConnection then
captureConnection:Disconnect()
captureConnection = nil
end
shell.BackgroundColor3 = tokens.sunken
shellStroke.Color = tokens.border
shellStroke.Transparency = 0.2
if cancelled then
self:setLabelText(self._value)
end
end
self._stopCapture = stopCapture

local function startCapture()
if self._capturing or not self._enabled then
return
end
self._capturing = true
label.Text = "Press a key..."
label.TextColor3 = tokens.textDim
shell.BackgroundColor3 = tokens.surfaceAlt
shellStroke.Color = tokens.accent
shellStroke.Transparency = 0.3

captureConnection = UserInputService.InputBegan:Connect(function(input, processed)
if processed then
return
end

if input.UserInputType == Enum.UserInputType.MouseMovement
or input.UserInputType == Enum.UserInputType.Focus
then
return
end
if input.KeyCode == Enum.KeyCode.Escape then
stopCapture(true)
return
end

if input.KeyCode == Enum.KeyCode.Backspace then
self:Set("", true)
stopCapture()
return
end

if Keybind.isModifier(input.KeyCode) then
return
end

if input.UserInputType == Enum.UserInputType.MouseButton1
and spec.AllowMouse == false
then
return
end
if input.UserInputType == Enum.UserInputType.Gamepad1
and spec.AllowGamepad == false
then
return
end

self:Set(Keybind.format(input), true)
stopCapture()
end)
end

hit.Activated:Connect(function()
if self._capturing then
stopCapture(true)
else
startCapture()
end
end)

hit.MouseButton2Click:Connect(function()
if self._value ~= "" then
self:Set("", true)
end
end)

hit.MouseEnter:Connect(function()
if self._value ~= "" then
clearHolder.Visible = self._value ~= ""
end
if self._enabled and not self._capturing then
Motion.tween(shell, { BackgroundColor3 = tokens.hover }, Motion.options("hover"))
if clearGlyph then
Glyph.setColor(clearGlyph, tokens.textMuted)
end
end
end)
hit.MouseLeave:Connect(function()
if not self._capturing then
clearHolder.Visible = false
Motion.tween(shell, { BackgroundColor3 = tokens.sunken }, Motion.options("hover"))
end
end)

field:onActivate(function()
startCapture()
end)

if ctx.maid then
ctx.maid:add(function()
stopCapture(true)
end)
ctx.maid:add(Theme.Changed:connect(function(next)
tokens = next
self._tokens = next
if not self._capturing then
shell.BackgroundColor3 = next.sunken
shellStroke.Color = next.border
end
self:setLabelText(self._value)
end))
end

return self
end

function Keybind:setLabelText(value: string)
local bound = value ~= ""
self.Label.Text = bound and value or "Unbound"
self.Label.TextColor3 = self._tokens[bound and "text" or "textDim"]
end

function Keybind:Set(value: any, fromUser: boolean?)
value = Keybind.chordOf(value)
if self._value == value and not fromUser then
return self
end
local previous = self._value
self._value = value
self:setLabelText(value)
if fromUser then
Button.playCue("click")

local target = value ~= "" and self._tokens.accent or self._tokens.textDim
self._shellStroke.Color = target
Motion.tween(self._shellStroke, { Transparency = 0.7 }, Motion.options("hover"))
Motion.setScale(self.Label, 0.86)
Motion.scale(self.Label, 1, Motion.options("release", { easing = "settle" }))
self.Changed:fire(value, previous, self)
Util.safeCall(self._spec.Callback, value, previous, self)
end
return self
end

function Keybind:Get(): string
return self._value
end

function Keybind:IsCapturing(): boolean
return self._capturing
end

function Keybind:ToKeyCodes(): { any }
local codes = {}
for part in self._value:gmatch("[^+]+") do
local trimmed = part:gsub("^%s+", ""):gsub("%s+$", "")
local ok, code = pcall(function()
return Enum.KeyCode[trimmed]
end)
if ok and code then
table.insert(codes, code)
end
end
return codes
end

function Keybind:setEnabled(enabled: boolean)
self._enabled = enabled
self.Field:setDisabled(not enabled)
if not enabled then
self:stopCapture(true)
end
return self
end

function Keybind:destroy()
if self._stopCapture then
self._stopCapture(true)
end
if self.Changed then
self.Changed:destroy()
end
self.Field:destroy()
end

return Keybind
end

__modules["Primitives.Segmented"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local Glyph = __require("Core.Glyph")
local Signal = __require("Core.Signal")
local Button = __require("Primitives.Button")
local Field = __require("Layout.Field")

local Segmented = {}
Segmented.__index = Segmented

function Segmented.new(spec: { [any]: any }, context: { [any]: any })
local ctx = context or {}
local tokens = Theme.current()
local options = spec.Options or {}
assert(#options > 0, "[Vantage] Segmented requires at least one option")

local self = setmetatable({
_spec = spec,
_maid = ctx.maid,
_tokens = tokens,
_options = options,
_index = 1,
_enabled = spec.Disabled ~= true,
}, Segmented)

self.Changed = Signal.new("Segmented.Changed")

local initialIndex = 1
if spec.Value ~= nil then
for index, option in ipairs(options) do
local label = type(option) == "table" and (option.Label or option.Value) or option
if label == spec.Value or (type(option) == "table" and option.Value == spec.Value) then
initialIndex = index
break
end
if index == spec.Value then
initialIndex = index
break
end
end
end
self._index = initialIndex

local segmentWidth = spec.SegmentWidth or 62
local controlWidth = segmentWidth * #options
local height = 30

local field = Field.new({
Name = spec.Name,
Description = spec.Description,
Icon = spec.Icon,
Disabled = spec.Disabled,
ControlWidth = controlWidth,
Align = "right",
}, { maid = ctx.maid, parent = ctx.parent })
self.Field = field
self.Instance = field.Instance

local container = field.Control
container.Size = UDim2.fromOffset(controlWidth, height)
container.AutomaticSize = Enum.AutomaticSize.None

local shell = Util.frame({
Name = "Shell",
Size = UDim2.fromScale(1, 1),
BackgroundColor3 = tokens.sunken,
Parent = container,
})
Util.corner(shell, tokens.radiusSm + 1)
Util.stroke(shell, tokens.borderSubtle, 1, 0.5)
Util.pad(shell, { Top = 3, Bottom = 3, Left = 3, Right = 3 })
self._shell = shell

local indicator = Util.frame({
Name = "Indicator",
AnchorPoint = Vector2.new(0, 0),
Position = UDim2.fromOffset(0, 0),
Size = UDim2.fromScale(1 / #options, 1),
BackgroundColor3 = tokens.elevated,
ZIndex = 2,
Parent = shell,
})
Util.corner(indicator, tokens.radiusSm - 1)
Util.stroke(indicator, tokens.border, 1, 0.35)
self._indicator = indicator

local slotHolder = Util.row({
Name = "Slots",
Size = UDim2.fromScale(1, 1),
ZIndex = 3,
Parent = shell,
})
Util.list(slotHolder, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 0),
VerticalAlignment = Enum.VerticalAlignment.Center,
})

self._labels = {}
self._slots = {}
self._icons = {}

for index, option in ipairs(options) do
local label = type(option) == "table" and (option.Label or option.Value or tostring(option)) or tostring(option)
local iconName = type(option) == "table" and option.Icon or nil
local value = type(option) == "table" and (option.Value or label) or option

local slot = Util.row({
Name = "Slot" .. index,
Size = UDim2.new(1 / #options, 0, 1, 0),
LayoutOrder = index,
Parent = slotHolder,
})
Util.list(slot, {
FillDirection = iconName and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 5),
HorizontalAlignment = Enum.HorizontalAlignment.Center,
VerticalAlignment = Enum.VerticalAlignment.Center,
})

if iconName then
local iconHolder = Util.row({
Size = UDim2.fromOffset(12, 12),
LayoutOrder = 1,
Parent = slot,
})
local glyph = Glyph.draw(iconHolder, iconName, {
size = 12,
color = tokens.textDim,
weight = 12,
zIndex = 4,
})
self._icons[index] = glyph
end

local text = Util.text({
Name = "Text",
Text = label,
TextSize = tokens.fontSizeSm,
Font = "bodyMedium",
TextColor3 = tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Center,
TextYAlignment = Enum.TextYAlignment.Center,
TextTruncate = Enum.TextTruncate.AtEnd,
Size = UDim2.new(1, 0, 1, 0),
AutomaticSize = Enum.AutomaticSize.None,
LayoutOrder = 2,
ZIndex = 4,
Parent = slot,
})
self._labels[index] = text
self._slots[index] = { frame = slot, value = value, label = label }

local hit = Util.create("TextButton", {
Name = "Hit",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
Size = UDim2.fromScale(1, 1),
ZIndex = 6,
Parent = slot,
})

hit.MouseEnter:Connect(function()
if self._index ~= index and self._enabled then
Motion.tween(text, { TextColor3 = tokens.text }, Motion.options("hover"))
local glyph = self._icons[index]
if glyph then
Glyph.setColor(glyph, tokens.textMuted)
end
end
end)
hit.MouseLeave:Connect(function()
if self._index ~= index then
Motion.tween(text, { TextColor3 = tokens.textDim }, Motion.options("hover"))
local glyph = self._icons[index]
if glyph then
Glyph.setColor(glyph, tokens.textDim)
end
end
end)
hit.Activated:Connect(function()
self:Set(value, true)
end)
end

local function layout(animated: boolean?)
local index = self._index
local target = UDim2.new((index - 1) / #options, 0, 0, 0)

if animated == false or Motion.getReducedMotion() then
indicator.Position = target
else

local spring = self._spring
if not spring then
spring = Motion.springFrom("snappy", index - 1)
self._spring = spring
if ctx.maid then
ctx.maid:add(function()
spring:destroy()
end)
end
spring:observe(function(value)
indicator.Position = UDim2.new((value) / #options, 0, 0, 0)
end)
end
spring:setGoal(index - 1)
end

for slotIndex, label in ipairs(self._labels) do
local active = slotIndex == index
local color = active and tokens.text or tokens.textDim
if self._enabled then
Motion.tween(label, { TextColor3 = color, TextTransparency = 0 }, Motion.options("hover"))
end
local glyph = self._icons[slotIndex]
if glyph then
Glyph.setColor(glyph, active and tokens.accent or tokens.textDim)
end
end
end

self._layout = layout

if ctx.maid then
ctx.maid:add(Theme.Changed:connect(function(next)
tokens = next
self._tokens = next
shell.BackgroundColor3 = next.sunken
indicator.BackgroundColor3 = next.elevated
local indicatorStroke = indicator:FindFirstChildOfClass("UIStroke")
if indicatorStroke then
indicatorStroke.Color = next.border
end
for slotIndex, label in ipairs(self._labels) do
label.TextColor3 = slotIndex == self._index and next.text or next.textDim
end
end))
end

layout(false)
task.defer(function()
layout(false)
end)

return self
end

function Segmented:Set(value: any, fromUser: boolean?)
local index = value
if type(value) == "string" then
for position, slot in ipairs(self._slots) do
if slot.value == value or slot.label == value then
index = position
break
end
end
end
if type(index) ~= "number" or not self._slots[index] then
return self
end
if self._index == index and not fromUser then
return self
end
self._index = index
self._layout(true)
if fromUser then
Button.playCue("click")
local slot = self._slots[index]
self.Changed:fire(slot.value, self)
Util.safeCall(self._spec.Callback, slot.value, self)
end
return self
end

function Segmented:Get(): any
return self._slots[self._index] and self._slots[self._index].value
end

function Segmented:GetIndex(): number
return self._index
end

function Segmented:setEnabled(enabled: boolean)
self._enabled = enabled
self.Field:setDisabled(not enabled)
local target = enabled and self._tokens.text or self._tokens.textDim
for index, label in ipairs(self._labels) do
Motion.tween(label, {
TextColor3 = (enabled and index == self._index) and target or self._tokens.textDim,
}, Motion.options("hover"))
end
return self
end

function Segmented:destroy()
if self.Changed then
self.Changed:destroy()
end
self.Field:destroy()
end

return Segmented
end

__modules["Primitives.Progress"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")

local Progress = {}
Progress.__index = Progress

local SIZES = {
xs = 3,
sm = 5,
md = 8,
lg = 12,
}

function Progress.new(spec: { [any]: any }, context: { [any]: any })
local ctx = context or {}
local tokens = Theme.current()

local self = setmetatable({
_spec = spec,
_maid = ctx.maid,
_tokens = tokens,
_min = spec.Min or 0,
_max = spec.Max or 100,
_value = spec.Value or 0,
_indeterminate = spec.Indeterminate == true,
}, Progress)

local height = SIZES[spec.Size or "sm"] or SIZES.sm

local labelled = spec.Name ~= nil
local root = Util.row({
Name = "VantageProgress",
Size = UDim2.new(1, 0, 0, labelled and 0 or height),
AutomaticSize = labelled and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
Parent = ctx.parent,
})
Util.tag(root, "Vantage")
self.Instance = root

if labelled then
Util.stack(root, 6)
local header = Util.row({
Size = UDim2.new(1, 0, 0, 16),
LayoutOrder = 1,
Parent = root,
})
Util.list(header, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 8),
})

local name = Util.text({
Name = "Name",
Text = spec.Name,
TextSize = tokens.fontSizeSm,
Font = "bodyMedium",
TextColor3 = tokens.text,
Size = UDim2.new(1, -56, 1, 0),
LayoutOrder = 1,
Parent = header,
})
self.NameLabel = name

local percent = Util.text({
Name = "Percent",
Text = "0%",
TextSize = tokens.fontSizeSm,
Font = "mono",
TextColor3 = tokens.accent,
TextXAlignment = Enum.TextXAlignment.Right,
Size = UDim2.new(0, 48, 1, 0),
LayoutOrder = 2,
Visible = not spec.HidePercent,
Parent = header,
})
self.PercentLabel = percent
end

local track = Util.frame({
Name = "Track",
Size = UDim2.new(1, 0, 0, height),
BackgroundColor3 = tokens.sunken,
LayoutOrder = labelled and 2 or 1,
ClipsDescendants = true,
Parent = root,
})
Util.pill(track)
Util.stroke(track, tokens.borderSubtle, 1, 0.5)
self.Track = track

local fill = Util.frame({
Name = "Fill",
Size = UDim2.new(0, 0, 1, 0),
BackgroundColor3 = tokens.accent,
Parent = track,
})
Util.pill(fill)
Util.gradient(fill, {
{ Time = 0, Color = tokens.accent },
{ Time = 0.55, Color = tokens.accentHover },
{ Time = 1, Color = Util.lighten(tokens.accent, 0.28) },
}, 0)
self.Fill = fill

local sheen = Util.frame({
Name = "Sheen",
Size = UDim2.new(0, 70, 1, 0),
Position = UDim2.fromOffset(-70, 0),
BackgroundColor3 = Color3.new(1, 1, 1),
BackgroundTransparency = 1,
ZIndex = 3,
Parent = fill,
})
Util.gradient(sheen, {
{ Time = 0, Color = Color3.new(1, 1, 1), Transparency = 1 },
{ Time = 0.5, Color = Color3.new(1, 1, 1), Transparency = 0.62 },
{ Time = 1, Color = Color3.new(1, 1, 1), Transparency = 1 },
}, 0)
self._sheen = sheen

local sheenTween
local function startSheen()
if sheenTween then
return
end
sheenTween = Motion.tween(sheen, { Position = UDim2.new(1, 0, 0, 0) }, {
duration = 1.6,
easing = "linear",
repeatCount = -1,
onUpdate = function(_, _, tween)

tween._props = { Position = UDim2.new(1, track.AbsoluteSize.X, 0, 0) }
end,
})
end

local indicator = Motion.springFrom("standard", 0)
self._indicator = indicator

local function render(value: number)
local span = self._max - self._min
local fraction = span == 0 and 0 or Util.clamp01((value - self._min) / span)
fill.Size = UDim2.new(fraction, 0, 1, 0)

fill.Visible = fraction > 0.0005

if self.PercentLabel then
local text
if type(spec.Format) == "function" then
text = tostring(spec.Format(value, fraction))
elseif spec.Format == "value" then
text = tostring(math.floor(value + 0.5))
else
text = string.format("%d%%", math.floor(fraction * 100 + 0.5))
end
if self.PercentLabel.Text ~= text then
self.PercentLabel.Text = text
end
end
end

indicator:observe(render)

if ctx.maid then
ctx.maid:add(function()
indicator:destroy()
if sheenTween then
sheenTween:cancel()
end
end)
end

startSheen()
self:SetValue(spec.Value or 0, true)

if self._indeterminate then
self._range = Motion.tween(fill, {
Position = UDim2.new(1, 0, 0, 0),
}, {
duration = 1.4,
easing = "quadInOut",
repeatCount = -1,
reverse = true,
})
fill.Size = UDim2.new(0.32, 0, 1, 0)
self._sweepToken = 1
end

if ctx.maid then
ctx.maid:add(Theme.Changed:connect(function(next)
tokens = next
self._tokens = next
track.BackgroundColor3 = next.sunken
Util.gradient(fill, {
{ Time = 0, Color = next.accent },
{ Time = 0.55, Color = next.accentHover },
{ Time = 1, Color = Util.lighten(next.accent, 0.28) },
}, 0)
if self.PercentLabel then
self.PercentLabel.TextColor3 = next.accent
end
if self.NameLabel then
self.NameLabel.TextColor3 = next.text
end
end))
end

return self
end

function Progress:SetValue(value: number, instant: boolean?)
self._value = Util.clamp(value, self._min, self._max)
if instant then
self._indicator:snap(self._value)
else
self._indicator:setGoal(self._value)
end
return self
end

function Progress:GetValue(): number
return self._value
end

function Progress:GetFraction(): number
local span = self._max - self._min
return span == 0 and 0 or Util.clamp01((self._value - self._min) / span)
end

function Progress:SetIndeterminate(enabled: boolean)
if self._indeterminate == enabled then
return self
end
self._indeterminate = enabled
if enabled then
self.Fill.Size = UDim2.new(0.32, 0, 1, 0)
self._range = Motion.tween(self.Fill, { Position = UDim2.new(1, 0, 0, 0) }, {
duration = 1.4,
easing = "quadInOut",
repeatCount = -1,
reverse = true,
})
else
if self._range then
self._range:cancel()
self._range = nil
end
self.Fill.Position = UDim2.fromOffset(0, 0)
self:SetValue(self._value, true)
end
return self
end

function Progress:SetTone(tokenName: string)
local tokens = self._tokens
local color = tokens[tokenName] or tokens.accent
Util.gradient(self.Fill, {
{ Time = 0, Color = color },
{ Time = 0.55, Color = Util.lighten(color, 0.12) },
{ Time = 1, Color = Util.lighten(color, 0.3) },
}, 0)
if self.PercentLabel then
self.PercentLabel.TextColor3 = color
end
return self
end

function Progress:SetLabel(text: string)
if self.NameLabel then
self.NameLabel.Text = text
end
return self
end

function Progress:destroy()
if self._range then
self._range:cancel()
end
if self.Instance then
Motion.cancelAll(self.Instance)
self.Instance:Destroy()
self.Instance = nil
end
end

return Progress
end

__modules["Layout.Section"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local Glyph = __require("Core.Glyph")
local Signal = __require("Core.Signal")
local Elements = __require("Layout.Elements")

local Section = {}
Section.__index = Section

function Section.new(spec: { [any]: any }, context: { [any]: any })
local tokens = Theme.current()

local self = setmetatable({
_spec = spec,
_maid = context.maid,
_tokens = tokens,
_collapsed = spec.Collapsed == true,
_expanded = not (spec.Collapsed == true),
_maidChildren = __require("Core.Maid").new("section"),
_window = context.window,
_tab = context.tab,
}, Section)

self.Toggled = Signal.new("Section.Toggled")

local root = Util.group({
Name = "VantageSection",
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = spec.Order or 1,
Parent = context.parent,
})
Util.tag(root, "Vantage")
self.Instance = root

local card = Util.frame({
Name = "Card",
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
BackgroundColor3 = spec.Flush and tokens.surface or tokens.surfaceAlt,
BackgroundTransparency = spec.Flush and 1 or 0,
Parent = root,
})
Util.corner(card, tokens.radiusLg)
if not spec.Flush then
Util.stroke(card, tokens.borderSubtle, 1, 0.35)
end
Util.clipRounded(card, tokens.radiusLg)
local cardStack = Util.stack(card, 0)
cardStack.Padding = UDim.new(0, 0)
self.Card = card

local header = Util.row({
Name = "Header",
Size = UDim2.new(1, 0, 0, spec.Description and 52 or 42),
LayoutOrder = 1,
Parent = card,
})
Util.pad(header, { Left = 16, Right = 12, Top = 10, Bottom = 10 })
self.Header = header

local headerStack = Util.stack(header, 2)
headerStack.HorizontalAlignment = Enum.HorizontalAlignment.Left

local titleRow = Util.row({
Name = "TitleRow",
Size = UDim2.new(1, 0, 0, 20),
LayoutOrder = 1,
Parent = header,
})
Util.list(titleRow, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 8),
VerticalAlignment = Enum.VerticalAlignment.Center,
})

if spec.Icon then
local iconHolder = Util.row({
Name = "Icon",
Size = UDim2.fromOffset(14, 14),
LayoutOrder = 1,
Parent = titleRow,
})
local glyph = Glyph.draw(iconHolder, spec.Icon, {
size = 14,
color = tokens.accent,
weight = 12,
zIndex = 4,
})
self.Icon = glyph
end

local title = Util.text({
Name = "Title",
Text = spec.Name or "Section",
TextSize = tokens.fontSizeMd + 1,
Font = "subheading",
TextColor3 = tokens.text,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Center,
TextTruncate = Enum.TextTruncate.AtEnd,
Size = UDim2.new(0, 0, 1, 0),
AutomaticSize = Enum.AutomaticSize.X,
LayoutOrder = 2,
Parent = titleRow,
})
self.Title = title

self.Badge = nil
if spec.Badge then
local badgeHolder = Util.row({
Name = "BadgeHolder",
Size = UDim2.new(0, 0, 0, 18),
AutomaticSize = Enum.AutomaticSize.X,
LayoutOrder = 3,
Parent = titleRow,
})
self.Badge = Elements.badge({
Text = spec.Badge,
Tone = spec.BadgeTone or "accent",
}, { parent = badgeHolder, maid = self._maid })
end

if spec.Description then
local description = Util.text({
Name = "Description",
Text = spec.Description,
TextSize = tokens.fontSizeSm,
Font = "body",
TextColor3 = tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
TextWrapped = true,
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 2,
Parent = header,
})
self.Description = description
end

local chevronHolder = Util.row({
Name = "Chevron",
AnchorPoint = Vector2.new(1, 0.5),
Position = UDim2.new(1, -12, 0, spec.Description and 26 or 21),
Size = UDim2.fromOffset(14, 14),
ZIndex = 5,
Parent = header,
})
local chevron = Glyph.draw(chevronHolder, "chevron-down", {
size = 14,
color = tokens.textDim,
weight = 12,
zIndex = 5,
})
self._chevron = chevron
self._chevronHolder = chevronHolder

local headerHit = Util.create("TextButton", {
Name = "HeaderHit",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
Size = UDim2.fromScale(1, 1),
ZIndex = 6,
Parent = header,
})
self._headerHit = headerHit

local body = Util.row({
Name = "Body",
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 2,
Parent = card,
})
Util.stack(body, 2)
Util.pad(body, { Left = 16, Right = 16, Top = 2, Bottom = 14 })
self.Body = body
self._body = body

self._childrenMaid = __require("Core.Maid").new("sectionChildren")
local childContext = {
maid = self._childrenMaid,
parent = body,
window = context.window,
tab = context.tab,
section = self,
layer = context.layer or body,
}
self.Context = childContext

local collapseTween

local function measureHeight(): number
return body.AbsoluteSize.Y
end

local function expand(animated: boolean?)
if self._expanded then
return
end
self._expanded = true
self._collapsed = false
body.Visible = true
body.ClipsDescendants = true

if animated == false or Motion.getReducedMotion() then
body.AutomaticSize = Enum.AutomaticSize.Y
body.Size = UDim2.new(1, 0, 0, 0)
body.ClipsDescendants = false
if chevron then
chevronHolder.Rotation = 0
end
return
end

body.AutomaticSize = Enum.AutomaticSize.Y
body.Size = UDim2.new(1, 0, 0, 0)
Motion.setScale(body, 1)
task.defer(function()
if not self._expanded then
return
end
local target = measureHeight()
body.AutomaticSize = Enum.AutomaticSize.None
body.Size = UDim2.new(1, 0, 0, 0)
if collapseTween then
collapseTween:cancel()
end
collapseTween = Motion.tween(body, { Size = UDim2.new(1, 0, 0, target) }, {
duration = 0.3,
easing = "enterSnap",
onUpdate = function(alpha)
for index, child in ipairs(body:GetChildren()) do
if child:IsA("GuiObject") then
child.Visible = alpha > 0.02
end
end
end,
onComplete = function()
body.AutomaticSize = Enum.AutomaticSize.Y
body.Size = UDim2.new(1, 0, 0, 0)
body.ClipsDescendants = false
for _, child in ipairs(body:GetChildren()) do
if child:IsA("GuiObject") then
child.Visible = true
end
end
end,
})
end)

if chevron then
Motion.tween(chevronHolder, { Rotation = 0 }, Motion.options("enter"))
end
end

local function collapse(animated: boolean?)
if not self._expanded then
return
end
self._expanded = false
self._collapsed = true

if collapseTween then
collapseTween:cancel()
collapseTween = nil
end

if animated == false or Motion.getReducedMotion() then
body.AutomaticSize = Enum.AutomaticSize.None
body.Size = UDim2.new(1, 0, 0, 0)
body.Visible = false
if chevron then
chevronHolder.Rotation = -90
end
return
end

local current = measureHeight()
body.AutomaticSize = Enum.AutomaticSize.None
body.Size = UDim2.new(1, 0, 0, current)
body.ClipsDescendants = true
collapseTween = Motion.tween(body, { Size = UDim2.new(1, 0, 0, 0) }, {
duration = 0.22,
easing = "exit",
onComplete = function()
body.Visible = false
body.AutomaticSize = Enum.AutomaticSize.Y
body.Size = UDim2.new(1, 0, 0, 0)
body.ClipsDescendants = false
collapseTween = nil
end,
})

if chevron then
Motion.tween(chevronHolder, { Rotation = -90 }, Motion.options("exit"))
end
end
self._expand = expand
self._collapse = collapse
self._measureHeight = measureHeight

headerHit.Activated:Connect(function()
self:SetCollapsed(not self._collapsed, true)
end)
headerHit.MouseEnter:Connect(function()
Motion.tween(card, { BackgroundColor3 = Util.lighten(tokens.surfaceAlt, 0.02) }, Motion.options("hover"))
Motion.tween(chevronHolder, { BackgroundTransparency = 1 }, Motion.options("hover"))
end)
headerHit.MouseLeave:Connect(function()
Motion.tween(card, { BackgroundColor3 = spec.Flush and tokens.surface or tokens.surfaceAlt }, Motion.options("hover"))
end)

if spec.Footer then
local footer = Util.row({
Name = "Footer",
Size = UDim2.new(1, 0, 0, 38),
LayoutOrder = 3,
Parent = card,
})
Util.pad(footer, { Left = 16, Right = 16, Top = 8, Bottom = 10 })
Util.list(footer, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 8),
VerticalAlignment = Enum.VerticalAlignment.Center,
})
self.Footer = footer
childContext.footer = footer
end

if self._collapsed then
body.Visible = false
if chevron then
chevronHolder.Rotation = -90
end
end

if self._maid then
self._maid:add(Theme.Changed:connect(function(next)
tokens = next
self._tokens = next
card.BackgroundColor3 = spec.Flush and next.surface or next.surfaceAlt
cardStack.Padding = UDim.new(0, 0)
local corner = card:FindFirstChildOfClass("UICorner")
if corner then
corner.CornerRadius = UDim.new(0, next.radiusLg)
end
title.TextColor3 = next.text
title.TextSize = next.fontSizeMd + 1
if self.Description then
self.Description.TextColor3 = next.textDim
self.Description.TextSize = next.fontSizeSm
end
if self.Icon then
Glyph.setColor(self.Icon, next.accent)
end
if chevron then
Glyph.setColor(chevron, next.textDim)
end
end))
self._maid:add(function()
self._childrenMaid:destroy()
end)
end

return self
end

function Section:SetCollapsed(collapsed: boolean, animated: boolean?)
if self._collapsed == collapsed then
return self
end
if collapsed then
self._collapse(animated ~= false)
else
self._expand(animated ~= false)
end
if animated then
self.Toggled:fire(collapsed, self)
end
return self
end

function Section:IsCollapsed(): boolean
return self._collapsed
end

local Button = __require("Primitives.Button")
local Toggle = __require("Primitives.Toggle")
local Slider = __require("Primitives.Slider")
local Dropdown = __require("Primitives.Dropdown")
local Input = __require("Primitives.Input")
local Keybind = __require("Primitives.Keybind")
local Segmented = __require("Primitives.Segmented")
local Progress = __require("Primitives.Progress")

function Section:_mount(object: any): any
if type(object) == "table" and object.Instance then
self._mounted = self._mounted or {}
table.insert(self._mounted, object)
end
return object
end

function Section:_childContext(): { [any]: any }
local window = self._window
return {
maid = self._childrenMaid,
parent = self.Body,
tooltip = window and window.Tooltip or nil,
window = window,
section = self,
tab = self._tab,
layer = self.Context and self.Context.layer or self.Body,
}
end

function Section:Button(spec: any): any
local options = table.clone(spec or {})
if options.Variant == nil then
options.Variant = "secondary"
end
return self:_mount(Button.new(options, self:_childContext()))
end

function Section:Toggle(spec: any): any
return self:_mount(Toggle.new(spec, self:_childContext()))
end

function Section:Slider(spec: any): any
return self:_mount(Slider.new(spec, self:_childContext()))
end

function Section:Dropdown(spec: any): any
return self:_mount(Dropdown.new(spec, self:_childContext()))
end

function Section:Input(spec: any): any
return self:_mount(Input.new(spec, self:_childContext()))
end

function Section:Keybind(spec: any): any
return self:_mount(Keybind.new(spec, self:_childContext()))
end

function Section:Segmented(spec: any): any
return self:_mount(Segmented.new(spec, self:_childContext()))
end

function Section:Progress(spec: any): any
return self:_mount(Progress.new(spec, self:_childContext()))
end

local function elementContext(self): any
return { parent = self.Body, maid = self._childrenMaid }
end

function Section:Paragraph(spec: any): any
return self:_mount(Elements.paragraph(spec, elementContext(self)))
end

function Section:Heading(spec: any): any
return self:_mount(Elements.heading(spec, elementContext(self)))
end

function Section:Overline(spec: any): any
return self:_mount(Elements.overline(spec, elementContext(self)))
end

function Section:Divider(spec: any?): any
return self:_mount(Elements.divider(spec or {}, elementContext(self)))
end

function Section:Spacer(size: number?): any
return Elements.spacer({ Size = size or 8 }, elementContext(self))
end

function Section:Image(spec: any): any
return self:_mount(Elements.image(spec, elementContext(self)))
end

function Section:Columns(spec: any): any
return Elements.columns(spec or {}, elementContext(self))
end

function Section:ButtonRow(spec: { [any]: any }?): any
local options = spec or {}
local row = Util.row({
Name = "VantageButtonRow",
Size = UDim2.new(1, 0, 0, 32),
Parent = self.Body,
})
Util.list(row, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, options.Gap or 8),
VerticalAlignment = Enum.VerticalAlignment.Center,
HorizontalAlignment = options.Align == "right" and Enum.HorizontalAlignment.Right
or (options.Align == "center" and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left),
})
local context = self:_childContext()
context.parent = row
return {
Instance = row,
Button = function(_, buttonSpec)
return Button.new(buttonSpec, context)
end,
}
end

function Section:Stats(stats: { any }): any
local row = Util.row({
Name = "VantageStats",
Size = UDim2.new(1, 0, 0, 16),
Parent = self.Body,
})
Util.list(row, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 16),
VerticalAlignment = Enum.VerticalAlignment.Center,
})
local built = {}
for index, entry in ipairs(stats) do
table.insert(built, Elements.stat({
Label = entry.Label,
Value = entry.Value,
Tone = entry.Tone,
LayoutOrder = index,
}, { parent = row, maid = self._childrenMaid }))
end
return { Instance = row, Items = built }
end

function Section:Add(instance: any): any
instance.Parent = self.Body
return instance
end

function Section:Refresh()
if not self._collapsed then
local body = self._body
body.AutomaticSize = Enum.AutomaticSize.Y
body.Size = UDim2.new(1, 0, 0, 0)
end
return self
end

function Section:destroy()
if self.Toggled then
self.Toggled:destroy()
end
self._childrenMaid:destroy()
if self.Instance then
Motion.cancelAll(self.Instance)
self.Instance:Destroy()
self.Instance = nil
end
end

return Section
end

__modules["Layout.Tab"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local Maid = __require("Core.Maid")
local Signal = __require("Core.Signal")
local Elements = __require("Layout.Elements")
local Section = __require("Layout.Section")

local Button = __require("Primitives.Button")
local Toggle = __require("Primitives.Toggle")
local Slider = __require("Primitives.Slider")
local Dropdown = __require("Primitives.Dropdown")
local Input = __require("Primitives.Input")
local Keybind = __require("Primitives.Keybind")
local Segmented = __require("Primitives.Segmented")
local Progress = __require("Primitives.Progress")

local Tab = {}
Tab.__index = Tab

function Tab.new(spec: { [any]: any }, context: { [any]: any })
local tokens = Theme.current()

local self = setmetatable({
_spec = spec,
_maid = Maid.new("tab"),
_window = context.window,
_tokens = tokens,
_name = spec.Name or "Tab",
_sections = {},
_mounted = {},
_componentMaid = Maid.new("tabComponents"),
}, Tab)

self.Changed = Signal.new("Tab.Changed")

local root = Util.row({
Name = "VantageTabContent",
Size = UDim2.fromScale(1, 1),
Visible = false,
Parent = context.parent,
})
Util.tag(root, "Vantage")
self.Instance = root

local scroll = Util.create("ScrollingFrame", {
Name = "Scroll",
Size = UDim2.fromScale(1, 1),
BackgroundTransparency = 1,
BorderSizePixel = 0,
ScrollBarThickness = 4,
ScrollBarImageColor3 = tokens.borderStrong,
ScrollBarImageTransparency = 0.4,
CanvasSize = UDim2.new(0, 0, 0, 0),
AutomaticCanvasSize = Enum.AutomaticSize.Y,
ScrollingDirection = Enum.ScrollingDirection.Y,
ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
ScrollingEnabled = true,
Parent = root,
})
self.Scroll = scroll
Util.pad(scroll, { Right = 4 })

local content = Util.row({
Name = "Content",
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
Position = UDim2.fromOffset(0, 0),
Parent = scroll,
})
Util.stack(content, 14)
Util.pad(content, { Top = 4, Bottom = 20, Left = 0, Right = 6 })
self.Content = content

self._layer = context.layer or root
self._context = context

self._visible = false

if self._maid then
self._maid:add(Theme.Changed:connect(function(next)
tokens = next
self._tokens = next
scroll.ScrollBarImageColor3 = next.borderStrong
end))
end

return self
end

function Tab:_mount(object: any): any
if type(object) == "table" and object.Instance then
table.insert(self._mounted, object)
end
return object
end

function Tab:_activate(animated: boolean?)
self._visible = true
self.Instance.Visible = true
if animated == false or Motion.getReducedMotion() then
self.Instance.BackgroundTransparency = 1
return
end

self.Instance.BackgroundTransparency = 1
Motion.setScale(self.Content, 1)
for index, section in ipairs(self._sections) do
local root = section.Instance
root.GroupTransparency = 1
Motion.tween(root, { GroupTransparency = 0 }, {
duration = 0.3,
easing = "enterSnap",
delay = math.min(index - 1, 5) * 0.035,
})
root.Position = UDim2.fromOffset(0, 8)
Motion.tween(root, { Position = UDim2.fromOffset(0, 0) }, {
duration = 0.34,
easing = "enterSnap",
delay = math.min(index - 1, 5) * 0.035,
})
end
end

function Tab:_deactivate()
self._visible = false
self.Instance.Visible = false
end

function Tab:IsVisible(): boolean
return self._visible
end

function Tab:GetName(): string
return self._name
end

function Tab:ScrollToTop()
self.Scroll.CanvasPosition = Vector2.new(0, 0)
return self
end

function Tab:Section(spec: { [any]: any }): any
local sectionSpec = table.clone(spec or {})
sectionSpec.Order = sectionSpec.Order or (#self._sections + 1)
local section = Section.new(sectionSpec, {
maid = self._maid,
parent = self.Content,
window = self._window,
tab = self,
layer = self._layer,
})
table.insert(self._sections, section)
return section
end

Tab.section = Tab.Section

function Tab:Paragraph(spec: any): any
return self:_mount(Elements.paragraph(spec, { parent = self.Content, maid = self._maid }))
end

function Tab:Heading(spec: any): any
return self:_mount(Elements.heading(spec, { parent = self.Content, maid = self._maid }))
end

function Tab:Overline(spec: any): any
return self:_mount(Elements.overline(spec, { parent = self.Content, maid = self._maid }))
end

function Tab:Divider(spec: any): any
return self:_mount(Elements.divider(spec or {}, { parent = self.Content, maid = self._maid }))
end

function Tab:Spacer(size: number?): any
return Elements.spacer({ Size = size or 8 }, { parent = self.Content, maid = self._maid })
end

function Tab:Image(spec: any): any
return self:_mount(Elements.image(spec, { parent = self.Content, maid = self._maid }))
end

function Tab:Columns(spec: any): any
return Elements.columns(spec or {}, { parent = self.Content, maid = self._maid })
end

function Tab:ButtonRow(spec: { [any]: any }?): any
local options = spec or {}
local row = Util.row({
Name = "VantageButtonRow",
Size = UDim2.new(1, 0, 0, 32),
Parent = self.Content,
})
Util.list(row, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, options.Gap or 8),
VerticalAlignment = Enum.VerticalAlignment.Center,
HorizontalAlignment = options.Align == "right" and Enum.HorizontalAlignment.Right
or (options.Align == "center" and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left),
})
local context = {
maid = self._componentMaid,
parent = row,
tooltip = self._window and self._window.Tooltip or nil,
}
return {
Instance = row,
Button = function(_, buttonSpec)
return Button.new(buttonSpec, context)
end,
}
end

function Tab:Button(spec: any): any

local options = table.clone(spec or {})
if options.Variant == nil then
options.Variant = "secondary"
end
options.Parent = self.Content
return self:_mount(Button.new(options, {
maid = self._componentMaid,
parent = self.Content,
tooltip = self._window and self._window.Tooltip or nil,
}))
end

function Tab:Toggle(spec: any): any
return self:_mount(Toggle.new(spec, {
maid = self._componentMaid,
parent = self.Content,
tooltip = self._window and self._window.Tooltip or nil,
}))
end

function Tab:Slider(spec: any): any
return self:_mount(Slider.new(spec, {
maid = self._componentMaid,
parent = self.Content,
}))
end

function Tab:Dropdown(spec: any): any
return self:_mount(Dropdown.new(spec, {
maid = self._componentMaid,
parent = self.Content,
layer = self._layer,
}))
end

function Tab:Input(spec: any): any
return self:_mount(Input.new(spec, {
maid = self._componentMaid,
parent = self.Content,
}))
end

function Tab:Keybind(spec: any): any
return self:_mount(Keybind.new(spec, {
maid = self._componentMaid,
parent = self.Content,
}))
end

function Tab:Segmented(spec: any): any
return self:_mount(Segmented.new(spec, {
maid = self._componentMaid,
parent = self.Content,
}))
end

function Tab:Progress(spec: any): any
return self:_mount(Progress.new(spec, {
maid = self._componentMaid,
parent = self.Content,
}))
end

function Tab:Stats(stats: { any }): any
local row = Util.row({
Name = "VantageStats",
Size = UDim2.new(1, 0, 0, 16),
Parent = self.Content,
})
Util.list(row, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 16),
VerticalAlignment = Enum.VerticalAlignment.Center,
})
local built = {}
for index, entry in ipairs(stats) do
table.insert(built, Elements.stat({
Label = entry.Label,
Value = entry.Value,
Tone = entry.Tone,
LayoutOrder = index,
}, { parent = row, maid = self._maid }))
end
return { Instance = row, Items = built }
end

function Tab:destroy()
if self.Changed then
self.Changed:destroy()
end
self._componentMaid:destroy()
self._maid:destroy()
if self.Instance then
Motion.cancelAll(self.Instance)
self.Instance:Destroy()
self.Instance = nil
end
end

return Tab
end

__modules["Overlay.Tooltip"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local Maid = __require("Core.Maid")

local Tooltip = {}
Tooltip.__index = Tooltip

local DELAY = 0.42
local GAP = 8
local MAX_WIDTH = 260

function Tooltip.new(spec: { [any]: any })
local tokens = Theme.current()
local self = setmetatable({
_layer = spec.layer,
_delay = spec.delay or DELAY,
_maid = Maid.new("tooltip"),
_tokens = tokens,
_current = nil,
_token = 0,
}, Tooltip)

local root = Util.row({
Name = "VantageTooltip",
AnchorPoint = Vector2.new(0, 0),
Position = UDim2.fromOffset(0, 0),
Size = UDim2.new(0, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.XY,
BackgroundColor3 = tokens.raised,
BackgroundTransparency = 1,
Visible = false,
ZIndex = 750,
Parent = spec.layer,
})
Util.corner(root, tokens.radiusMd)
Util.stroke(root, tokens.border, 1, 0.35)
Util.pad(root, { Left = 10, Right = 10, Top = 7, Bottom = 7 })
Util.stack(root, 2)
Util.tag(root, "Vantage")
self.Instance = root

local title = Util.text({
Name = "Title",
Text = "",
TextSize = tokens.fontSizeSm,
Font = "subheading",
TextColor3 = tokens.text,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
TextWrapped = true,
Size = UDim2.new(0, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.XY,
LayoutOrder = 1,
Visible = false,
Parent = root,
})
local body = Util.text({
Name = "Body",
Text = "",
TextSize = tokens.fontSizeSm,
Font = "body",
TextColor3 = tokens.textMuted,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
TextWrapped = true,
Size = UDim2.new(0, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.XY,
LayoutOrder = 2,
Parent = root,
})
self.TitleLabel = title
self.BodyLabel = body

if self._maid then
self._maid:add(Theme.Changed:connect(function(next)
tokens = next
self._tokens = next
root.BackgroundColor3 = next.raised
title.TextColor3 = next.text
body.TextColor3 = next.textMuted
local stroke = root:FindFirstChildOfClass("UIStroke")
if stroke then
stroke.Color = next.border
end
end))
end

self._root = root
return self
end

local function measure(instance: any): Vector2
local size = instance.AbsoluteSize
if size.X > 0 and size.Y > 0 then
return size
end
return Vector2.new(MAX_WIDTH, 40)
end

function Tooltip:_place(anchor: any)
local root = self._root
local viewport = Util.viewport()
local insets = Util.insets()
local anchorPosition = anchor.AbsolutePosition
local anchorSize = anchor.AbsoluteSize
local size = measure(root)

local available = math.min(MAX_WIDTH, viewport.X - 24)
root.Size = UDim2.fromOffset(math.min(size.X, available), 0)
root.AutomaticSize = Enum.AutomaticSize.XY
local finalSize = measure(root)

local aboveY = anchorPosition.Y - finalSize.Y - GAP
local belowY = anchorPosition.Y + anchorSize.Y + GAP
local placeAbove = aboveY >= insets.top + 6
if not placeAbove and belowY + finalSize.Y > viewport.Y - insets.bottom - 6 then

placeAbove = (anchorPosition.Y - insets.top) > (viewport.Y - (anchorPosition.Y + anchorSize.Y) - insets.bottom)
end

local y = placeAbove and aboveY or belowY
local x = anchorPosition.X + anchorSize.X * 0.5 - finalSize.X * 0.5
x = Util.clamp(x, insets.left + 6, viewport.X - finalSize.X - insets.right - 6)
y = Util.clamp(y, insets.top + 6, viewport.Y - finalSize.Y - insets.bottom - 6)

root.Position = UDim2.fromOffset(x, y)
self._placedAbove = placeAbove
return root.Position
end

function Tooltip:attach(instance: any, text: string, titleText: string?)
if not instance or not text then
return { text = function() end, destroy = function() end }
end

local handle = { _text = text, _title = titleText }

local enter
local leave

local function hide()
self._token += 1
if self._current ~= handle then
return
end
self._current = nil
local root = self._root
if not root.Visible then
return
end
Motion.scale(root, 0.96, { duration = 0.12, easing = "exit" })
Motion.tween(root, { BackgroundTransparency = 1 }, {
duration = 0.12,
easing = "exit",
onComplete = function()
root.Visible = false
end,
})
Motion.tween(self.TitleLabel, { TextTransparency = 1 }, Motion.options("exit"))
Motion.tween(self.BodyLabel, { TextTransparency = 1 }, Motion.options("exit"))
end

local function show()
self._current = handle
local token = self._token
local root = self._root

self.TitleLabel.Text = handle._title or ""
self.TitleLabel.Visible = handle._title ~= nil and handle._title ~= ""
self.BodyLabel.Text = handle._text

root.Visible = true
root.BackgroundTransparency = 1
Motion.setScale(root, 1)

root.Position = UDim2.fromOffset(-9999, -9999)
task.defer(function()
if token ~= self._token or self._current ~= handle then
return
end
self:_place(instance)
Motion.scale(root, 1, { duration = 0.18, easing = "enterSnap" })
Motion.tween(root, { BackgroundTransparency = 0 }, { duration = 0.14, easing = "enterSnap" })
Motion.tween(self.TitleLabel, { TextTransparency = 0 }, Motion.options("enter", { duration = 0.16 }))
Motion.tween(self.BodyLabel, { TextTransparency = 0 }, Motion.options("enter", { duration = 0.2 }))
end)
end

enter = instance.MouseEnter:Connect(function()
self._token += 1
local token = self._token
task.delay(self._delay, function()
if token == self._token and not self._current then
show()
end
end)
end)

leave = instance.MouseLeave:Connect(function()
hide()
end)

handle.text = function(nextText: string, nextTitle: string?)
handle._text = nextText
if nextTitle ~= nil then
handle._title = nextTitle
end
if self._current == handle then
self.BodyLabel.Text = nextText
self.TitleLabel.Text = handle._title or ""
self.TitleLabel.Visible = (handle._title or "") ~= ""
self:_place(instance)
end
end

handle.destroy = function()
enter:Disconnect()
leave:Disconnect()
if self._current == handle then
hide()
end
end

return handle
end

function Tooltip:showAt(position: Vector2, text: string, titleText: string?)
self.TitleLabel.Text = titleText or ""
self.TitleLabel.Visible = (titleText or "") ~= ""
self.BodyLabel.Text = text
self._root.Visible = true
self._root.Position = UDim2.fromOffset(position.X, position.Y)
Motion.tween(self._root, { BackgroundTransparency = 0 }, Motion.options("fast"))
return self
end

function Tooltip:destroy()
self._maid:destroy()
if self.Instance then
Motion.cancelAll(self.Instance)
self.Instance:Destroy()
self.Instance = nil
end
end

return Tooltip
end

__modules["Layout.Window"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local Config = __require("Core.Config")
local Signal = __require("Core.Signal")
local Maid = __require("Core.Maid")
local Glyph = __require("Core.Glyph")
local Elements = __require("Layout.Elements")
local Tab = __require("Layout.Tab")

local Window = {}
Window.__index = Window

local TITLE_HEIGHT = 40
local STATUS_HEIGHT = 24
local SIDEBAR_WIDTH = 168

local function resolveParent(explicit: any): any
if explicit then
return explicit
end
local ok, playerGui = pcall(function()
local players = game:GetService("Players")
return players.LocalPlayer and players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
end)
if ok and playerGui then
return playerGui
end
local ok2, coreGui = pcall(function()
return game:GetService("CoreGui")
end)
if ok2 and coreGui then
return coreGui
end

return nil
end

local SPEC_ALIASES = {
Name = "name",
Subtitle = "subtitle",
Theme = "theme",
Size = "size",
Position = "position",
Anchor = "anchor",
MinSize = "minSize",
MaxSize = "maxSize",
Resizable = "resizable",
Draggable = "draggable",
Sidebar = "sidebar",
SidebarWidth = "sidebarWidth",
StatusBar = "statusBar",
StatusBarHeight = "statusBarHeight",
TitleBarHeight = "titleBarHeight",
ToggleKey = "toggleKey",
CloseKey = "closeKey",
UIScale = "uiScale",
Scale = "uiScale",
Version = "version",
}

local function canonicalSpec(spec: { [any]: any }): { [any]: any }
local out = table.clone(spec)
for public, internal in pairs(SPEC_ALIASES) do
if out[internal] == nil and out[public] ~= nil then
out[internal] = out[public]
end
end

if out.Backdrop == nil and out.backdrop ~= nil then
out.Backdrop = out.backdrop
end
return out
end

function Window.new(spec: { [any]: any }): any
local defaults = Config.defaults
local config = Util.deepMerge(defaults, canonicalSpec(spec or {}))
local tokens = Theme.current()

if spec and spec.Theme then
Theme.apply(spec.Theme, { name = spec.Theme })
tokens = Theme.current()
end

local self = setmetatable({
_spec = config,
_maid = Maid.new("window"),
_tabs = {},
_tabOrder = {},
_tokens = tokens,
_themeName = spec and spec.Theme or Theme.name(),
_minimized = false,
_maximized = false,
_hidden = false,
_tabIndex = 1,
_statusTick = 0,
_fpsBuffer = {},
_fpsIndex = 0,
}, Window)

self._tabIndicatorVisible = false

self.Closed = Signal.new("Window.Closed")
self.Minimized = Signal.new("Window.Minimized")
self.TabChanged = Signal.new("Window.TabChanged")
self.ThemeChanged = Signal.new("Window.ThemeChanged")

local parent = resolveParent(config.Parent)
local screen = Util.create("ScreenGui", {
Name = "Vantage",
ResetOnSpawn = false,
ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
IgnoreGuiInset = true,
DisplayOrder = config.DisplayOrder or 100,
Enabled = true,
Parent = parent,
})
Util.tag(screen, "Vantage")
self.ScreenGui = screen

local root = Util.frame({
Name = "Root",
Size = UDim2.fromScale(1, 1),
BackgroundTransparency = 1,
Parent = screen,
})
Util.list(root, {
FillDirection = Enum.FillDirection.Vertical,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 0),
})
self.Root = root

local scrim = Util.frame({
Name = "Scrim",
Size = UDim2.fromScale(1, 1),
BackgroundColor3 = tokens.scrim,
BackgroundTransparency = config.Backdrop and 0.35 or 1,
Visible = config.Backdrop == true,
ZIndex = 1,
Parent = root,
})
self.Scrim = scrim

local shellHolder = Util.frame({
Name = "ShellHolder",
Size = UDim2.fromScale(1, 1),
BackgroundTransparency = 1,
ZIndex = 2,
Parent = root,
})
Util.list(shellHolder, {
FillDirection = Enum.FillDirection.Vertical,
SortOrder = Enum.SortOrder.LayoutOrder,
})
self.ShellHolder = shellHolder

local minSize = Vector2.new(config.minSize.X, config.minSize.Y)

local shell = Util.frame({
Name = "Shell",
AnchorPoint = config.anchor or Vector2.new(0.5, 0.5),
Position = config.position or UDim2.fromScale(0.5, 0.5),
Size = config.size or UDim2.fromOffset(680, 440),
BackgroundColor3 = tokens.surface,
BackgroundTransparency = 0.02,
ClipsDescendants = false,
ZIndex = 2,
Parent = shellHolder,
})
Util.corner(shell, tokens.radiusXl)
Util.stroke(shell, tokens.border, 1, 0.25)
Util.tag(shell, "Vantage")
self.Shell = shell

local shadow = Util.frame({
Name = "Shadow",
AnchorPoint = config.anchor or Vector2.new(0.5, 0.5),
Position = UDim2.new(
(config.position or UDim2.fromScale(0.5, 0.5)).X.Scale,
(config.position or UDim2.fromScale(0.5, 0.5)).X.Offset,
(config.position or UDim2.fromScale(0.5, 0.5)).Y.Scale,
(config.position or UDim2.fromScale(0.5, 0.5)).Y.Offset + 10
),
Size = config.size or UDim2.fromOffset(680, 440),
BackgroundColor3 = tokens.shadow,
BackgroundTransparency = 0.72,
ZIndex = 1,
Parent = shellHolder,
})
Util.corner(shadow, tokens.radiusXl + 6)
self.Shadow = shadow

local inner = Util.frame({
Name = "Inner",
Size = UDim2.fromScale(1, 1),
BackgroundTransparency = 1,
ClipsDescendants = true,
Parent = shell,
})
Util.corner(inner, tokens.radiusXl)
Util.list(inner, {
FillDirection = Enum.FillDirection.Vertical,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 0),
})
self.Inner = inner

local titleBar = Util.frame({
Name = "TitleBar",
Size = UDim2.new(1, 0, 0, config.titleBarHeight or TITLE_HEIGHT),
BackgroundColor3 = tokens.surface,
BackgroundTransparency = 1,
LayoutOrder = 1,
Parent = inner,
})
Util.corner(titleBar, tokens.radiusXl)
Util.pad(titleBar, { Left = 14, Right = 8 })
self.TitleBar = titleBar

Util.list(titleBar, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 8),
VerticalAlignment = Enum.VerticalAlignment.Center,
})

local markGlyphHolder = Util.row({
Name = "Mark",
Size = UDim2.fromOffset(18, 18),
LayoutOrder = 1,
Parent = titleBar,
})
local markGlyph = Glyph.draw(markGlyphHolder, "ring", {
size = 16,
color = tokens.accent,
weight = 9,
zIndex = 4,
position = UDim2.fromOffset(1, 1),
})
self._markGlyph = markGlyph

local titleBlock = Util.row({
Name = "TitleBlock",
Size = UDim2.new(0, 0, 1, 0),
AutomaticSize = Enum.AutomaticSize.X,
LayoutOrder = 2,
Parent = titleBar,
})
Util.list(titleBlock, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 8),
VerticalAlignment = Enum.VerticalAlignment.Center,
})

local title = Util.text({
Name = "Title",
Text = config.name or Config.name,
TextSize = tokens.fontSizeMd,
Font = "subheading",
TextColor3 = tokens.text,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Center,
TextTruncate = Enum.TextTruncate.AtEnd,
Size = UDim2.new(0, 0, 1, 0),
AutomaticSize = Enum.AutomaticSize.X,
LayoutOrder = 1,
Parent = titleBlock,
})
self.Title = title

local subtitle = Util.text({
Name = "Subtitle",
Text = config.subtitle or "",
TextSize = tokens.fontSizeSm,
Font = "body",
TextColor3 = tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Center,
Size = UDim2.new(0, 0, 1, 0),
AutomaticSize = Enum.AutomaticSize.X,
LayoutOrder = 2,
Visible = config.subtitle ~= nil,
Parent = titleBlock,
})
self.Subtitle = subtitle

local versionBadgeHolder = Util.row({
Name = "Version",
Size = UDim2.new(0, 0, 0, 18),
AutomaticSize = Enum.AutomaticSize.X,
LayoutOrder = 3,
Parent = titleBlock,
})
local versionBadge = Elements.badge({
Text = config.version or ("v" .. Config.version),
Tone = "accent",
}, { parent = versionBadgeHolder, maid = self._maid })
self._versionBadge = versionBadge

local dragSurface = Util.create("TextButton", {
Name = "DragSurface",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
AnchorPoint = Vector2.new(0, 0),
Position = UDim2.fromOffset(0, 0),
Size = UDim2.new(1, -132, 1, 0),
ZIndex = 2,
Parent = titleBar,
})
self._dragSurface = dragSurface

local controls = Util.row({
Name = "Controls",
AnchorPoint = Vector2.new(1, 0.5),
Position = UDim2.new(1, -6, 0.5, 0),
Size = UDim2.new(0, 0, 1, 0),
AutomaticSize = Enum.AutomaticSize.X,
ZIndex = 3,
Parent = titleBar,
})
Util.list(controls, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 4),
VerticalAlignment = Enum.VerticalAlignment.Center,
HorizontalAlignment = Enum.HorizontalAlignment.Right,
})
self._controls = controls

local function controlButton(order: number, glyphName: string, tone: string, callback: () -> ()): any
local holder = Util.frame({
Name = "Control_" .. glyphName,
Size = UDim2.fromOffset(24, 24),
BackgroundColor3 = tokens.hover,
BackgroundTransparency = 1,
LayoutOrder = order,
Parent = controls,
})
Util.corner(holder, tokens.radiusSm)
local glyph = Glyph.draw(holder, glyphName, {
size = 11,
color = tokens.textDim,
weight = 12,
zIndex = 6,
})
if glyph then
glyph.AnchorPoint = Vector2.new(0.5, 0.5)
glyph.Position = UDim2.fromScale(0.5, 0.5)
end
local hit = Util.create("TextButton", {
Name = "Hit",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
Size = UDim2.fromScale(1, 1),
ZIndex = 7,
Parent = holder,
})
hit.MouseEnter:Connect(function()
Motion.tween(holder, { BackgroundTransparency = 0 }, Motion.options("hover"))
if glyph then
Glyph.setColor(glyph, tokens[tone])
end
end)
hit.MouseLeave:Connect(function()
Motion.tween(holder, { BackgroundTransparency = 1 }, Motion.options("hover"))
if glyph then
Glyph.setColor(glyph, tokens.textDim)
end
end)
hit.Activated:Connect(callback)
return { holder = holder, glyph = glyph, hit = hit }
end

self._minimizeControl = controlButton(1, "minus", "text", function()
self:Minimize(not self._minimized)
end)
self._maximizeControl = controlButton(2, "layout", "text", function()
self:Maximize(not self._maximized)
end)
self._closeControl = controlButton(3, "close", "danger", function()
self:Close()
end)

local body = Util.frame({
Name = "Body",
Size = UDim2.new(1, 0, 1, -(config.titleBarHeight or TITLE_HEIGHT) - (config.statusBarHeight or STATUS_HEIGHT)),
BackgroundTransparency = 1,
LayoutOrder = 2,
Parent = inner,
})
Util.list(body, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 0),
})
self.Body = body

local sidebar = Util.row({
Name = "Sidebar",
Size = UDim2.new(0, config.sidebarWidth or SIDEBAR_WIDTH, 1, 0),
LayoutOrder = 1,
Visible = config.sidebar ~= false,
Parent = body,
})
Util.stack(sidebar, 2)
Util.pad(sidebar, { Left = 10, Right = 6, Top = 2, Bottom = 10 })
self.Sidebar = sidebar

self._sidebarSearch = nil
local sidebarSearchHolder = Util.row({
Name = "Search",
Size = UDim2.new(1, 0, 0, 28),
LayoutOrder = 0,
Visible = false,
Parent = sidebar,
})
local sidebarSearchShell = Util.frame({
Name = "Shell",
Size = UDim2.fromScale(1, 1),
BackgroundColor3 = tokens.sunken,
Parent = sidebarSearchHolder,
})
Util.corner(sidebarSearchShell, tokens.radiusSm)
Util.pad(sidebarSearchShell, { Left = 24, Right = 8 })
local sidebarSearchGlyphHolder = Util.row({
Name = "Icon",
AnchorPoint = Vector2.new(0, 0.5),
Position = UDim2.new(0, 7, 0.5, 0),
Size = UDim2.fromOffset(11, 11),
ZIndex = 4,
Parent = sidebarSearchShell,
})
Glyph.draw(sidebarSearchGlyphHolder, "search", {
size = 11,
color = tokens.textDim,
weight = 12,
zIndex = 4,
})
local sidebarSearch = Util.create("TextBox", {
Name = "Box",
Text = "",
PlaceholderText = "Filter",
PlaceholderColor3 = tokens.textDim,
TextSize = tokens.fontSizeSm,
Font = Enum.Font.Gotham,
TextColor3 = tokens.text,
BackgroundTransparency = 1,
TextXAlignment = Enum.TextXAlignment.Left,
Size = UDim2.fromScale(1, 1),
ZIndex = 4,
Parent = sidebarSearchShell,
})
Util.applyFont(sidebarSearch, "body")
self._sidebarSearch = sidebarSearch

local tabList = Util.row({
Name = "TabList",
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 1,
Parent = sidebar,
})
Util.stack(tabList, 2)
self._tabList = tabList

local tabIndicator = Util.frame({
Name = "Indicator",
AnchorPoint = Vector2.new(0, 0),
Position = UDim2.fromOffset(0, 0),
Size = UDim2.new(1, 0, 0, 34),
BackgroundColor3 = tokens.selected,
Visible = false,
ZIndex = 1,
Parent = sidebar,
})
Util.corner(tabIndicator, tokens.radiusMd)
Util.stroke(tabIndicator, tokens.accentBorder, 1, 0.7)
self._tabIndicator = tabIndicator

local sidebarFooter = Util.row({
Name = "SidebarFooter",
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 99,
Parent = sidebar,
})
Util.stack(sidebarFooter, 4)
self._sidebarFooter = sidebarFooter

local contentHolder = Util.row({
Name = "Content",
Size = UDim2.new(1, -(config.sidebarWidth or SIDEBAR_WIDTH), 1, 0),
LayoutOrder = 2,
Parent = body,
})
self.ContentHolder = contentHolder

local statusBar
local statusItems = {}
if config.statusBar ~= false then
statusBar = Util.frame({
Name = "StatusBar",
Size = UDim2.new(1, 0, 0, config.statusBarHeight or STATUS_HEIGHT),
BackgroundColor3 = tokens.canvas,
BackgroundTransparency = 0.55,
LayoutOrder = 3,
Parent = inner,
})
Util.corner(statusBar, tokens.radiusXl)
Util.pad(statusBar, { Left = 14, Right = 14 })
Util.stroke(statusBar, tokens.borderSubtle, 1, 0.6)
self.StatusBar = statusBar

local left = Util.row({
Name = "Left",
AnchorPoint = Vector2.new(0, 0.5),
Position = UDim2.new(0, 12, 0.5, 0),
Size = UDim2.new(0, 0, 1, 0),
AutomaticSize = Enum.AutomaticSize.X,
Parent = statusBar,
})
Util.list(left, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 14),
VerticalAlignment = Enum.VerticalAlignment.Center,
})
local right = Util.row({
Name = "Right",
AnchorPoint = Vector2.new(1, 0.5),
Position = UDim2.new(1, -12, 0.5, 0),
Size = UDim2.new(0, 0, 1, 0),
AutomaticSize = Enum.AutomaticSize.X,
Parent = statusBar,
})
Util.list(right, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 14),
VerticalAlignment = Enum.VerticalAlignment.Center,
})

local order = { left = 0, right = 0 }
local function addStatus(side: string, label: string, initial: string, tone: string?): any
order[side] += 1
return Elements.stat({
Label = label,
Value = initial,
Tone = tone,
LayoutOrder = order[side],
}, { parent = side == "left" and left or right, maid = self._maid })
end

statusItems.tab = addStatus("left", "VIEW", "—")
statusItems.motion = addStatus("left", "MOTION", "0")
statusItems.fps = addStatus("right", "FPS", "60", "success")
statusItems.ping = addStatus("right", "PING", "—")
statusItems.memory = addStatus("right", "MEM", "—")
self.StatusItems = statusItems
end

local resizeHandle
if config.resizable ~= false then
resizeHandle = Util.create("TextButton", {
Name = "ResizeHandle",
Text = "",
BackgroundTransparency = 1,
AnchorPoint = Vector2.new(1, 1),
Position = UDim2.fromScale(1, 1),
Size = UDim2.fromOffset(20, 20),
ZIndex = 9,
Parent = shell,
})
local gripHolder = Util.row({
Name = "Grip",
AnchorPoint = Vector2.new(1, 1),
Position = UDim2.fromScale(1, 1),
Size = UDim2.fromOffset(9, 9),
ZIndex = 9,
Parent = shell,
})
local grip = Glyph.draw(gripHolder, "chevron-right", {
size = 9,
color = tokens.textDim,
weight = 14,
zIndex = 9,
transparency = 0.45,
})
if grip then

gripHolder.Rotation = 45
end
self._resizeHandle = resizeHandle
self._grip = gripHolder
end

local overlayLayer = Util.frame({
Name = "OverlayLayer",
Size = UDim2.fromScale(1, 1),
BackgroundTransparency = 1,
ZIndex = 400,
Parent = root,
})
self.OverlayLayer = overlayLayer

local notifyLayer = Util.frame({
Name = "NotifyLayer",
AnchorPoint = Vector2.new(1, 0),
Position = UDim2.new(1, -16, 0, 16),
Size = UDim2.fromOffset(320, 0),
BackgroundTransparency = 1,
ZIndex = 600,
Parent = root,
})
Util.list(notifyLayer, {
FillDirection = Enum.FillDirection.Vertical,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 8),
HorizontalAlignment = Enum.HorizontalAlignment.Right,
})
self.NotifyLayer = notifyLayer

local tooltipLayer = Util.frame({
Name = "TooltipLayer",
Size = UDim2.fromScale(1, 1),
BackgroundTransparency = 1,
ZIndex = 700,
Parent = root,
})
self.TooltipLayer = tooltipLayer

local Tooltip = __require("Overlay.Tooltip")
self.Tooltip = Tooltip.new({ layer = tooltipLayer, delay = config.tooltipDelay })
self._maid:add(self.Tooltip)

local uiScale = Util.create("UIScale", {
Name = "VantageScale",
Scale = 1,
Parent = root,
})
self.UIScale = uiScale

local function applyScale()
local width = Util.viewport().X
local raw
if config.uiScale then
raw = config.uiScale
elseif width < 620 then
raw = 0.86
elseif width < 1000 then
raw = 0.94
else
raw = Util.uiScale(1920)
end
uiScale.Scale = raw
end
applyScale()

local camera = workspace and workspace.CurrentCamera
if camera then
pcall(function()
self._maid:add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
applyScale()
end))
end)
end
self._maid:add(Theme.Changed:connect(function(next)
self._tokens = next
applyScale()

task.defer(function()
self._clampToViewport()
end)
end))

local dragging = false
local dragStart
local dragOrigin
local dragConnection
local dragEndConnection

local function clampPosition(position: UDim2): UDim2
local viewport = Util.viewport()
local size = shell.AbsoluteSize
local anchor = shell.AnchorPoint
local x = position.X.Scale * viewport.X + position.X.Offset
local y = position.Y.Scale * viewport.Y + position.Y.Offset
local left = x - size.X * anchor.X
local top = y - size.Y * anchor.Y

local minLeft = -size.X + 120
local maxLeft = viewport.X - 60
local minTop = 0
local maxTop = viewport.Y - 40
local clampedLeft = Util.clamp(left, minLeft, math.max(minLeft, maxLeft))
local clampedTop = Util.clamp(top, minTop, math.max(minTop, maxTop))
return UDim2.fromOffset(
clampedLeft + size.X * anchor.X,
clampedTop + size.Y * anchor.Y
)
end

self._clampToViewport = function()
if self._maximized then
return
end
local clamped = clampPosition(shell.Position)
if clamped ~= shell.Position then
shell.Position = clamped
shadow.Position = UDim2.new(clamped.X.Scale, clamped.X.Offset, clamped.Y.Scale, clamped.Y.Offset + 10)
end
end

local function beginDrag(inputX: number, inputY: number)
if config.draggable == false or self._maximized then
return
end
dragging = true
dragStart = Vector2.new(inputX, inputY)
dragOrigin = Vector2.new(shell.AbsolutePosition.X, shell.AbsolutePosition.Y)
Motion.tween(shell, {
BackgroundTransparency = 0.05,
}, Motion.options("hover"))
if self._grip then
Glyph.setTransparency(self._grip, 0.15)
end
end

local function updateDrag(inputX: number, inputY: number)
if not dragging then
return
end
local delta = Vector2.new(inputX - dragStart.X, inputY - dragStart.Y)
local viewport = Util.viewport()
local size = shell.AbsoluteSize
local anchor = shell.AnchorPoint
local targetLeft = dragOrigin.X + delta.X
local targetTop = dragOrigin.Y + delta.Y
targetLeft = Util.clamp(targetLeft, -size.X + 120, viewport.X - 60)
targetTop = Util.clamp(targetTop, 0, viewport.Y - 40)
local position = UDim2.fromOffset(targetLeft + size.X * anchor.X, targetTop + size.Y * anchor.Y)
shell.Position = position
shadow.Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + 10)
end

local function endDrag()
if not dragging then
return
end
dragging = false
Motion.tween(shell, { BackgroundTransparency = 0.02 }, Motion.options("hover"))
if dragConnection then
dragConnection:Disconnect()
dragConnection = nil
end
if dragEndConnection then
dragEndConnection:Disconnect()
dragEndConnection = nil
end
self:_persist()
end

local UserInputService = game:GetService("UserInputService")

dragSurface.InputBegan:Connect(function(input)
if input.UserInputType ~= Enum.UserInputType.MouseButton1
and input.UserInputType ~= Enum.UserInputType.Touch
then
return
end
beginDrag(input.Position.X, input.Position.Y)

if input.UserInputType == Enum.UserInputType.Touch then
dragConnection = UserInputService.TouchMoved:Connect(function(moveInput)
updateDrag(moveInput.Position.X, moveInput.Position.Y)
end)
dragEndConnection = UserInputService.TouchEnded:Connect(endDrag)
else
dragConnection = UserInputService.InputChanged:Connect(function(changed)
if changed.UserInputType == Enum.UserInputType.MouseMovement then
updateDrag(changed.Position.X, changed.Position.Y)
end
end)
dragEndConnection = UserInputService.InputEnded:Connect(function(changed)
if changed.UserInputType == Enum.UserInputType.MouseButton1 then
endDrag()
end
end)
end
end)

local lastTitleClick = 0
dragSurface.MouseButton1Click:Connect(function()
local now = os.clock()
if now - lastTitleClick < 0.32 then
lastTitleClick = 0
self:Maximize(not self._maximized)
else
lastTitleClick = now
end
end)

if resizeHandle then
local resizing = false
local resizeStart
local resizeOrigin
local resizeMove
local resizeEnd

local function beginResize(x: number, y: number)
if self._maximized then
return
end
resizing = true
resizeStart = Vector2.new(x, y)
resizeOrigin = shell.AbsoluteSize
if self._grip then
Glyph.setTransparency(self._grip, 0)
end
end

local function updateResize(x: number, y: number)
if not resizing then
return
end
local viewport = Util.viewport()
local delta = Vector2.new(x - resizeStart.X, y - resizeStart.Y)
local size = Vector2.new(
Util.clamp(resizeOrigin.X + delta.X, minSize.X, math.min(config.maxSize and config.maxSize.X or viewport.X, viewport.X - 40)),
Util.clamp(resizeOrigin.Y + delta.Y, minSize.Y, math.min(config.maxSize and config.maxSize.Y or viewport.Y, viewport.Y - 40))
)
shell.Size = UDim2.fromOffset(size.X, size.Y)
shadow.Size = UDim2.fromOffset(size.X, size.Y)
end

local function endResize()
if not resizing then
return
end
resizing = false
if self._grip then
Glyph.setTransparency(self._grip, 0.45)
end
if resizeMove then
resizeMove:Disconnect()
resizeMove = nil
end
if resizeEnd then
resizeEnd:Disconnect()
resizeEnd = nil
end
self:_persist()
end

resizeHandle.InputBegan:Connect(function(input)
if input.UserInputType ~= Enum.UserInputType.MouseButton1
and input.UserInputType ~= Enum.UserInputType.Touch
then
return
end
beginResize(input.Position.X, input.Position.Y)
if input.UserInputType == Enum.UserInputType.Touch then
resizeMove = UserInputService.TouchMoved:Connect(function(moveInput)
updateResize(moveInput.Position.X, moveInput.Position.Y)
end)
resizeEnd = UserInputService.TouchEnded:Connect(endResize)
else
resizeMove = UserInputService.InputChanged:Connect(function(changed)
if changed.UserInputType == Enum.UserInputType.MouseMovement then
updateResize(changed.Position.X, changed.Position.Y)
end
end)
resizeEnd = UserInputService.InputEnded:Connect(function(changed)
if changed.UserInputType == Enum.UserInputType.MouseButton1 then
endResize()
end
end)
end
end)
end

self._maid:add(function()
Motion.cancelAll(shell)
end)

self:_playEntrance()

local toggleKey = config.toggleKey
if toggleKey == nil then
toggleKey = Config.keybinds.toggleInterface
end

self._maid:add(UserInputService.InputBegan:Connect(function(input, processed)
if processed then
return
end
if toggleKey and input.KeyCode == toggleKey then
self:Toggle()
return
end
if config.closeKey and input.KeyCode == config.closeKey then
self:Hide()
end
end))

self:_restore()

self._ready = true
return self
end

function Window:_persist()
local persistence = Config.persistence
if not (persistence and persistence.save) then
return
end
Util.safeCall(persistence.save, "window", {
size = { X = self.Shell.AbsoluteSize.X, Y = self.Shell.AbsoluteSize.Y },
position = { X = self.Shell.AbsolutePosition.X, Y = self.Shell.AbsolutePosition.Y },
tab = self._tabIndex,
theme = self._themeName,
})
end

function Window:_restore()
local persistence = Config.persistence
if not (persistence and persistence.load) then
return
end
local ok, saved = pcall(persistence.load, "window")
if not ok or type(saved) ~= "table" then
return
end
if saved.size and saved.size.X and saved.size.Y then
self.Shell.Size = UDim2.fromOffset(saved.size.X, saved.size.Y)
self.Shadow.Size = UDim2.fromOffset(saved.size.X, saved.size.Y)
end
if saved.position and saved.position.X and saved.position.Y then

local anchor = self.Shell.AnchorPoint
local size = self.Shell.AbsoluteSize
self.Shell.Position = UDim2.fromOffset(
saved.position.X + size.X * anchor.X,
saved.position.Y + size.Y * anchor.Y
)
self.Shadow.Position = UDim2.new(
self.Shell.Position.X.Scale,
self.Shell.Position.X.Offset,
self.Shell.Position.Y.Scale,
self.Shell.Position.Y.Offset + 10
)
self:_clampToViewport()
end
end

function Window:_playEntrance()
if Motion.getReducedMotion() then
Motion.setScale(self.Shell, 1)
return
end
Motion.setScale(self.Shell, 0.94)
Motion.scale(self.Shell, 1, { duration = 0.42, easing = "enterSnap" })
self.Shell.BackgroundTransparency = 1
self.Shadow.BackgroundTransparency = 1
Motion.tween(self.Shell, { BackgroundTransparency = 0.02 }, { duration = 0.36, easing = "enterSnap" })
Motion.tween(self.Shadow, { BackgroundTransparency = 0.72 }, { duration = 0.36, easing = "enterSnap" })
self.Shell.Position = UDim2.new(
self.Shell.Position.X.Scale,
self.Shell.Position.X.Offset,
self.Shell.Position.Y.Scale,
self.Shell.Position.Y.Offset + 14
)
Motion.tween(self.Shell, {
Position = UDim2.new(
self.Shell.Position.X.Scale,
self.Shell.Position.X.Offset,
self.Shell.Position.Y.Scale,
self.Shell.Position.Y.Offset - 14
),
}, { duration = 0.46, easing = "enterSnap" })
end

function Window:Tab(spec: { [any]: any }): any
local tabSpec = table.clone(spec or {})
tabSpec.Order = tabSpec.Order or (#self._tabOrder + 1)

local entry = {}

local tab = Tab.new(tabSpec, {
maid = self._maid,
parent = self.ContentHolder,
window = self,
layer = self.Root,
})

local row = Util.frame({
Name = "Tab_" .. tostring(tabSpec.Name),
Size = UDim2.new(1, 0, 0, 34),
BackgroundColor3 = self._tokens.hover,
BackgroundTransparency = 1,
LayoutOrder = tabSpec.Order,
Parent = self._tabList,
})
Util.corner(row, self._tokens.radiusMd)
Util.pad(row, { Left = 10, Right = 8 })

local rowContent = Util.row({
Name = "Content",
Size = UDim2.fromScale(1, 1),
Parent = row,
})
Util.list(rowContent, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 9),
VerticalAlignment = Enum.VerticalAlignment.Center,
})

if tabSpec.Icon then
local iconHolder = Util.row({
Name = "Icon",
Size = UDim2.fromOffset(14, 14),
LayoutOrder = 1,
Parent = rowContent,
})
entry.icon = Glyph.draw(iconHolder, tabSpec.Icon, {
size = 14,
color = self._tokens.textDim,
weight = 12,
zIndex = 4,
})
end

local label = Util.text({
Name = "Label",
Text = tabSpec.Name or "Tab",
TextSize = self._tokens.fontSizeMd,
Font = "bodyMedium",
TextColor3 = self._tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Center,
TextTruncate = Enum.TextTruncate.AtEnd,
Size = UDim2.new(1, -24, 1, 0),
LayoutOrder = 2,
Parent = rowContent,
})
entry.label = label

local badgeValue = Util.text({
Name = "Badge",
Text = tabSpec.Badge and tostring(tabSpec.Badge) or "",
TextSize = self._tokens.fontSizeXs + 1,
Font = "mono",
TextColor3 = self._tokens.accent,
TextXAlignment = Enum.TextXAlignment.Right,
Size = UDim2.new(0, 20, 1, 0),
LayoutOrder = 3,
Visible = tabSpec.Badge ~= nil,
Parent = rowContent,
})
entry.badge = badgeValue

local hit = Util.create("TextButton", {
Name = "Hit",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
Size = UDim2.fromScale(1, 1),
ZIndex = 6,
Parent = row,
})
entry.hit = hit
entry.row = row
entry.tab = tab
entry.spec = tabSpec

hit.Activated:Connect(function()
self:SelectTab(tab)
end)
hit.MouseEnter:Connect(function()
if self._tabs[self._tabIndex] ~= entry then
Motion.tween(row, { BackgroundTransparency = 0.55 }, Motion.options("hover"))
Motion.tween(label, { TextColor3 = self._tokens.textMuted }, Motion.options("hover"))
if entry.icon then
Glyph.setColor(entry.icon, self._tokens.textMuted)
end
end
end)
hit.MouseLeave:Connect(function()
if self._tabs[self._tabIndex] ~= entry then
Motion.tween(row, { BackgroundTransparency = 1 }, Motion.options("hover"))
Motion.tween(label, { TextColor3 = self._tokens.textDim }, Motion.options("hover"))
if entry.icon then
Glyph.setColor(entry.icon, self._tokens.textDim)
end
end
end)

Motion.setScale(row, 1)

table.insert(self._tabs, entry)
table.sort(self._tabs, function(a, b)
return (a.spec.Order or 0) < (b.spec.Order or 0)
end)

entry.tab.Owner = self

table.insert(self._tabOrder, tab)

if #self._tabs == 1 then
self:SelectTab(tab, { animated = false })
end

task.defer(function()
if self._tabIndex then
self:SelectTab(self._tabIndex, { animated = false })
end
end)

return tab
end

function Window:SelectTab(target: any, options: { [any]: any }?)
local index
if type(target) == "number" then
index = target
elseif type(target) == "string" then
for position, entry in ipairs(self._tabs) do
if entry.spec.Name == target then
index = position
break
end
end
else
for position, entry in ipairs(self._tabs) do
if entry.tab == target then
index = position
break
end
end
end

if not index or not self._tabs[index] then
return self
end
if self._tabIndex == index and self._tabs[index].tab:IsVisible() then
self._tabs[index].tab:ScrollToTop()
return self
end

local previous = self._tabs[self._tabIndex]
if previous then
previous.tab:_deactivate()
Motion.tween(previous.row, { BackgroundTransparency = 1 }, Motion.options("hover"))
Motion.tween(previous.label, { TextColor3 = self._tokens.textDim }, Motion.options("hover"))
if previous.icon then
Glyph.setColor(previous.icon, self._tokens.textDim)
end
end

self._tabIndex = index
local entry = self._tabs[index]
entry.tab:_activate(options == nil or options.animated ~= false)
Motion.tween(entry.label, { TextColor3 = self._tokens.text }, Motion.options("hover"))
if entry.icon then
Glyph.setColor(entry.icon, self._tokens.accent)
end

local sidebarOrigin = self._tabList.AbsolutePosition.Y
local offset = entry.row.AbsolutePosition.Y - sidebarOrigin
self._tabIndicator.Size = UDim2.new(1, 0, 0, entry.row.AbsoluteSize.Y)

if not self._indicatorSpring then
local spring = Motion.springFrom("snappy", offset)
self._indicatorSpring = spring
self._maid:add(function()
spring:destroy()
end)
spring:observe(function(value)
self._tabIndicator.Position = UDim2.fromOffset(0, value)
end)
end

if self._tabIndicatorVisible then
self._indicatorSpring:setGoal(offset)
else
self._indicatorSpring:snap(offset)
self._tabIndicatorVisible = true
end
self._tabIndicator.Visible = true

if self.StatusItems and self.StatusItems.tab then
self.StatusItems.tab:Set(entry.spec.Name or "")
end

self.TabChanged:fire(entry.tab, entry.spec, self)
return self
end

function Window:GetTab(name: string): any
for _, entry in ipairs(self._tabs) do
if entry.spec.Name == name then
return entry.tab
end
end
return nil
end

function Window:CurrentTab(): any
local entry = self._tabs[self._tabIndex]
return entry and entry.tab or nil
end

function Window:SetTabVisible(name: string, visible: boolean)
for _, entry in ipairs(self._tabs) do
if entry.spec.Name == name then
entry.row.Visible = visible
if not visible and self._tabs[self._tabIndex] == entry then
for position, candidate in ipairs(self._tabs) do
if candidate.row.Visible then
self:SelectTab(position)
break
end
end
end
end
end
return self
end

function Window:Show(animated: boolean?)
self._hidden = false
self.Root.Visible = true
if animated == false or Motion.getReducedMotion() then
return self
end
self:_playEntrance()
return self
end

function Window:Hide(animated: boolean?)
self._hidden = true
if animated == false or Motion.getReducedMotion() then
self.Root.Visible = false
return self
end
Motion.tween(self.Shell, { BackgroundTransparency = 1 }, Motion.options("exit"))
Motion.scale(self.Shell, 0.97, Motion.options("exit"))
Motion.tween(self.Shadow, { BackgroundTransparency = 1 }, Motion.options("exit"))
task.delay(0.2, function()
if self._hidden then
self.Root.Visible = false
Motion.setScale(self.Shell, 1)
end
end)
return self
end

function Window:Toggle()
if self._hidden then
self:Show()
else
self:Hide()
end
return self
end

function Window:IsVisible(): boolean
return not self._hidden
end

function Window:Minimize(minimized: boolean)
minimized = minimized == true
if self._minimized == minimized then
return self
end
self._minimized = minimized

if minimized then
self._restoreSize = self.Shell.AbsoluteSize.Y
end

local target = minimized and (self._spec.titleBarHeight or TITLE_HEIGHT)
or (self._restoreSize or (self._spec.size and self._spec.size.Y.Offset) or 440)

self.Body.Visible = not minimized
if self.StatusBar then
self.StatusBar.Visible = not minimized
end
Motion.tween(self.Shell, { Size = UDim2.new(self.Shell.Size.X.Scale, self.Shell.Size.X.Offset, 0, target) }, {
duration = 0.34,
easing = minimized and "exit" or "enterSnap",
})
Motion.tween(self.Shadow, { Size = UDim2.new(self.Shell.Size.X.Scale, self.Shell.Size.X.Offset, 0, target) }, {
duration = 0.34,
easing = minimized and "exit" or "enterSnap",
})
if self._minimizeControl and self._minimizeControl.glyph then
Glyph.setColor(self._minimizeControl.glyph, minimized and self._tokens.accent or self._tokens.textDim)
end
self.Minimized:fire(minimized, self)
return self
end

function Window:Maximize(maximized: boolean)
maximized = maximized == true
if self._maximized == maximized then
return self
end
self._maximized = maximized

local viewport = Util.viewport()
local insets = Util.insets()
local duration = Motion.getReducedMotion() and 0 or 0.34

if maximized then
self._restoreGeometry = {
size = self.Shell.Size,
position = self.Shell.Position,
}
local width = viewport.X - insets.left - insets.right - 24
local height = viewport.Y - insets.top - insets.bottom - 24
local position = UDim2.fromOffset(
insets.left + 12 + width * 0.5,
insets.top + 12 + height * 0.5
)
Motion.tween(self.Shell, {
Size = UDim2.fromOffset(width, height),
Position = position,
}, { duration = duration, easing = "enterSnap" })
Motion.tween(self.Shadow, {
Size = UDim2.fromOffset(width, height),
Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + 10),
}, { duration = duration, easing = "enterSnap" })
elseif self._restoreGeometry then
Motion.tween(self.Shell, {
Size = self._restoreGeometry.size,
Position = self._restoreGeometry.position,
}, { duration = duration, easing = "enterSnap" })
Motion.tween(self.Shadow, {
Size = self._restoreGeometry.size,
Position = UDim2.new(
self._restoreGeometry.position.X.Scale,
self._restoreGeometry.position.X.Offset,
self._restoreGeometry.position.Y.Scale,
self._restoreGeometry.position.Y.Offset + 10
),
}, { duration = duration, easing = "enterSnap" })
end
if self._maximizeControl and self._maximizeControl.glyph then
Glyph.setColor(self._maximizeControl.glyph, maximized and self._tokens.accent or self._tokens.textDim)
end
return self
end

function Window:IsMaximized(): boolean
return self._maximized
end

function Window:Close()
local onClose = self._spec.onClose
self.Closed:fire(self)
Util.safeCall(onClose, self)

Motion.tween(self.Shell, { BackgroundTransparency = 1 }, Motion.options("exit"))
Motion.scale(self.Shell, 0.96, Motion.options("exit"))
Motion.tween(self.Shadow, { BackgroundTransparency = 1 }, Motion.options("exit"))
task.delay(0.22, function()
self:Destroy()
end)
end

function Window:Destroy()
if self._destroyed then
return
end
self._destroyed = true

if self.Tooltip then
self.Tooltip:destroy()
self.Tooltip = nil
end

for _, entry in ipairs(self._tabs) do
entry.tab:destroy()
end
table.clear(self._tabs)

self.Closed:destroy()
self.Minimized:destroy()
self.TabChanged:destroy()
self.ThemeChanged:destroy()
self._maid:destroy()

if self.ScreenGui then
self.ScreenGui:Destroy()
self.ScreenGui = nil
end
end

function Window:SetTheme(name: string, options: { [any]: any }?)
if type(name) == "table" then
Theme.apply(name, { transition = options or true, name = options and options.name })
else
Theme.apply(name, { transition = options == nil and true or options, name = name })
end
self._themeName = type(name) == "string" and name or "custom"
self.ThemeChanged:fire(self._themeName, self)
return self
end

function Window:GetTheme(): string
return self._themeName
end

function Window:GetTabNames(): { string }
local names = {}
for _, entry in ipairs(self._tabs) do
if entry.row.Visible then
table.insert(names, entry.spec.Name)
end
end
return names
end

function Window:CycleTab(direction: number)
if #self._tabs == 0 then
return self
end
local index = self._tabIndex
for _ = 1, #self._tabs do
index = ((index - 1 + direction) % #self._tabs) + 1
if self._tabs[index] and self._tabs[index].row.Visible then
self:SelectTab(index)
return self
end
end
return self
end

return Window
end

__modules["Overlay.CommandPalette"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local Config = __require("Core.Config")
local Maid = __require("Core.Maid")
local Signal = __require("Core.Signal")
local Glyph = __require("Core.Glyph")

local CommandPalette = {}
CommandPalette.__index = CommandPalette

local ROW_HEIGHT = 34
local MAX_ROWS = 8
local RECENT_LIMIT = 6

function CommandPalette.new(context: { [any]: any })
local tokens = Theme.current()
local self = setmetatable({
_layer = context.layer,
_maid = Maid.new("palette"),
_tokens = tokens,
_commands = {},
_recent = {},
_open = false,
_query = "",
_highlight = 1,
_results = {},
_rows = {},
}, CommandPalette)

self.Ran = Signal.new("CommandPalette.Ran")

local root = Util.frame({
Name = "VantageCommandPalette",
Size = UDim2.fromScale(1, 1),
BackgroundColor3 = tokens.scrim,
BackgroundTransparency = 1,
Visible = false,
ZIndex = 800,
Parent = context.layer,
})
self.Instance = root

local blocker = Util.create("TextButton", {
Name = "Blocker",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
Size = UDim2.fromScale(1, 1),
ZIndex = 1,
Parent = root,
})
blocker.Activated:Connect(function()
self:Close()
end)

local panel = Util.group({
Name = "Panel",
AnchorPoint = Vector2.new(0.5, 0),
Position = UDim2.new(0.5, 0, 0, 96),
Size = UDim2.fromOffset(440, 52),
BackgroundColor3 = tokens.elevated,
BackgroundTransparency = 0,
ClipsDescendants = true,
ZIndex = 810,
Parent = root,
})
Util.corner(panel, tokens.radiusLg)
Util.stroke(panel, tokens.border, 1, 0.2)
Util.tag(panel, "Vantage")
self.Panel = panel

local searchRow = Util.row({
Name = "SearchRow",
Size = UDim2.new(1, 0, 0, 52),
Parent = panel,
})
Util.pad(searchRow, { Left = 16, Right = 14 })

local searchIconHolder = Util.row({
Name = "Icon",
AnchorPoint = Vector2.new(0, 0.5),
Position = UDim2.new(0, 16, 0.5, 0),
Size = UDim2.fromOffset(15, 15),
ZIndex = 4,
Parent = panel,
})
Glyph.draw(searchIconHolder, "search", {
size = 15,
color = tokens.textDim,
weight = 12,
zIndex = 4,
})

local box = Util.create("TextBox", {
Name = "Box",
Text = "",
PlaceholderText = "Type a command...",
PlaceholderColor3 = tokens.textDim,
TextSize = tokens.fontSizeLg,
Font = Enum.Font.GothamMedium,
TextColor3 = tokens.text,
BackgroundTransparency = 1,
TextXAlignment = Enum.TextXAlignment.Left,
Size = UDim2.new(1, -60, 1, 0),
Position = UDim2.fromOffset(42, 0),
ClearTextOnFocus = false,
ZIndex = 4,
Parent = panel,
})
Util.applyFont(box, "bodyMedium")
self.SearchBox = box

local hintHolder = Util.row({
Name = "Hint",
AnchorPoint = Vector2.new(1, 0.5),
Position = UDim2.new(1, -14, 0.5, 0),
Size = UDim2.fromOffset(0, 18),
AutomaticSize = Enum.AutomaticSize.X,
ZIndex = 4,
Parent = panel,
})
Util.pad(hintHolder, { Left = 6, Right = 6 })
Util.corner(hintHolder, tokens.radiusXs)
hintHolder.BackgroundColor3 = tokens.sunken
hintHolder.BackgroundTransparency = 0.3
Util.text({
Name = "HintLabel",
Text = "ESC",
TextSize = tokens.fontSizeXs,
Font = "mono",
TextColor3 = tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Center,
Size = UDim2.new(1, 0, 1, 0),
Parent = hintHolder,
})

local listHolder = Util.row({
Name = "List",
Size = UDim2.new(1, 0, 0, 0),
Position = UDim2.fromOffset(0, 52),
Parent = panel,
})
Util.stack(listHolder, 0)
Util.pad(listHolder, { Left = 8, Right = 8, Bottom = 8 })

self.ListHolder = listHolder

local empty = Util.text({
Name = "Empty",
Text = "No matching commands",
TextSize = tokens.fontSizeSm,
Font = "body",
TextColor3 = tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Center,
TextYAlignment = Enum.TextYAlignment.Center,
Size = UDim2.new(1, -16, 0, 40),
Visible = false,
Parent = listHolder,
})
self._empty = empty

function self:Register(commands)
for _, command in ipairs(commands or {}) do
table.insert(self._commands, command)
end
return self
end

local function buildRows()
for _, row in ipairs(self._rows) do
row.frame:Destroy()
end
table.clear(self._rows)
end
self._buildRows = buildRows

local paint
local runHighlighted

local function ensureRows(count: number)
while #self._rows < count do
local index = #self._rows + 1
local rowIndex = index
local frame = Util.frame({
Name = "Row" .. index,
Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
BackgroundColor3 = tokens.hover,
BackgroundTransparency = 1,
LayoutOrder = index,
Parent = listHolder,
})
Util.corner(frame, tokens.radiusSm)
Util.pad(frame, { Left = 10, Right = 10 })

local iconHolder = Util.row({
Name = "Icon",
AnchorPoint = Vector2.new(0, 0.5),
Position = UDim2.new(0, 10, 0.5, 0),
Size = UDim2.fromOffset(13, 13),
ZIndex = 4,
Parent = frame,
})

local label = Util.text({
Name = "Label",
Text = "",
TextSize = tokens.fontSizeMd,
Font = "bodyMedium",
TextColor3 = tokens.text,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Center,
TextTruncate = Enum.TextTruncate.AtEnd,
Position = UDim2.fromOffset(34, 0),
Size = UDim2.new(1, -120, 1, 0),
ZIndex = 4,
Parent = frame,
})

local sectionLabel = Util.text({
Name = "Section",
Text = "",
TextSize = tokens.fontSizeXs,
Font = "bodyBold",
TextColor3 = tokens.textDim,
TextXAlignment = Enum.TextXAlignment.Right,
TextYAlignment = Enum.TextYAlignment.Center,
Position = UDim2.fromOffset(0, 0),
Size = UDim2.new(1, -12, 1, 0),
ZIndex = 4,
Parent = frame,
})

local hit = Util.create("TextButton", {
Name = "Hit",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
Size = UDim2.fromScale(1, 1),
ZIndex = 6,
Parent = frame,
})

local entry = {
index = rowIndex,
frame = frame,
iconHolder = iconHolder,
label = label,
section = sectionLabel,
hit = hit,
}

hit.MouseEnter:Connect(function()
self._highlight = entry.index
paint()
end)
hit.Activated:Connect(function()
self._highlight = entry.index
runHighlighted()
end)

table.insert(self._rows, entry)
end
end

paint = function()
for index, row in ipairs(self._rows) do
local result = self._results[index]
if not result then
row.frame.Visible = false
continue
end
row.frame.Visible = true
local active = index == self._highlight

row.label.Text = result.command.Label or result.command.Name or ""
row.section.Text = result.command.Section or ""
Motion.tween(row.frame, {
BackgroundTransparency = active and 0 or 1,
}, Motion.options("hover"))
Motion.tween(row.label, {
TextColor3 = active and tokens.text or tokens.textMuted,
}, Motion.options("hover"))

for _, child in ipairs(row.iconHolder:GetChildren()) do
child:Destroy()
end
Glyph.draw(row.iconHolder, result.command.Icon or "arrow-right", {
size = 13,
color = active and tokens.accent or tokens.textDim,
weight = 12,
zIndex = 4,
})
end
end
self._paint = paint

local function search()
local query = self._query
local scored = {}
if query == "" then

local seen = {}
for _, command in ipairs(self._recent) do
table.insert(scored, { command = command, score = 1000 })
seen[command] = true
end
for _, command in ipairs(self._commands) do
if not seen[command] then
table.insert(scored, { command = command, score = 0 })
end
end
else
for _, command in ipairs(self._commands) do
local haystack = (command.Label or command.Name or "")
.. (command.Section and (" " .. command.Section) or "")
.. (command.Description and (" " .. command.Description) or "")
local score = Util.fuzzyMatch(query, haystack)
if score then
table.insert(scored, { command = command, score = score })
end
end
table.sort(scored, function(a, b)
return a.score > b.score
end)
end

table.clear(self._results)
for index = 1, math.min(#scored, MAX_ROWS) do
self._results[index] = scored[index]
end
self._highlight = math.clamp(self._highlight, 1, math.max(#self._results, 1))
ensureRows(math.max(#self._results, 1))
empty.Visible = #self._results == 0
paint()
end
self._search = search

function self:Refresh()
search()
return self
end

local function layout()
local rowCount = math.max(#self._results, 1)
panel.Size = UDim2.fromOffset(440, 52 + rowCount * ROW_HEIGHT + 8)
end
self._layout = layout

function self:Open()
if self._open then
return self
end
self._open = true
self._query = ""
self._highlight = 1
box.Text = ""
search()
layout()

root.Visible = true
panel.Size = UDim2.fromOffset(440, 52)
panel.GroupTransparency = 1
Motion.tween(panel, { GroupTransparency = 0 }, Motion.options("enter", { duration = 0.16 }))
Motion.scale(panel, 0.97, { duration = 0.26, easing = "enterSnap" })
Motion.tween(root, { BackgroundTransparency = tokens.scrimTransparency }, Motion.options("enter", { duration = 0.2 }))
task.defer(function()
if not self._open then
return
end
layout()
Motion.scale(panel, 1, { duration = 0.26, easing = "enterSnap" })
end)
box:CaptureFocus()
return self
end

function self:Close()
if not self._open then
return self
end
self._open = false
if box:IsFocused() then
box:ReleaseFocus()
end
Motion.tween(root, { BackgroundTransparency = 1 }, Motion.options("exit"))
Motion.tween(panel, { GroupTransparency = 1 }, Motion.options("exit", {
onComplete = function()
root.Visible = false
end,
}))
return self
end

function self:Toggle()
if self._open then
self:Close()
else
self:Open()
end
return self
end

function self:IsOpen(): boolean
return self._open
end

runHighlighted = function()
local result = self._results[self._highlight]
if not result then
return
end
local command = result.command

table.remove(self._recent, table.find(self._recent, command) or -1)
table.insert(self._recent, 1, command)
while #self._recent > RECENT_LIMIT do
table.remove(self._recent)
end

self:Close()
self.Ran:fire(command, self)
Util.safeCall(command.Run, command, self)
end

box:GetPropertyChangedSignal("Text"):Connect(function()
self._query = box.Text
self._highlight = 1
search()
layout()
end)

local UserInputService = game:GetService("UserInputService")
local modifier = Config.keybinds.commandPaletteModifier or Enum.KeyCode.LeftControl
local key = Config.keybinds.commandPalette or Enum.KeyCode.K

self._maid:add(UserInputService.InputBegan:Connect(function(input, processed)
if processed then
return
end
if input.KeyCode == key and input:IsModifierKeyDown(modifier) then
self:Toggle()
return
end
if not self._open then
return
end
local code = input.KeyCode
if code == Enum.KeyCode.Down then
self._highlight = math.min(self._highlight + 1, math.max(#self._results, 1))
paint()
elseif code == Enum.KeyCode.Up then
self._highlight = math.max(self._highlight - 1, 1)
paint()
elseif code == Enum.KeyCode.Home then
self._highlight = 1
paint()
elseif code == Enum.KeyCode.End then
self._highlight = math.max(#self._results, 1)
paint()
elseif code == Enum.KeyCode.Return or code == Enum.KeyCode.KeypadEnter then
runHighlighted()
elseif code == Enum.KeyCode.Escape then
self:Close()
end
end))

self._maid:add(Theme.Changed:connect(function(next)
tokens = next
self._tokens = next
panel.BackgroundColor3 = next.elevated
box.TextColor3 = next.text
box.PlaceholderColor3 = next.textDim
empty.TextColor3 = next.textDim
paint()
end))

if context.maid then
context.maid:add(function()
self:destroy()
end)
end

return self
end

function CommandPalette:Add(commands: { any })
for _, command in ipairs(commands or {}) do
table.insert(self._commands, command)
end
return self
end

function CommandPalette:List()
return self._commands
end

function CommandPalette:destroy()
self.Ran:destroy()
self._maid:destroy()
if self.Instance then
Motion.cancelAll(self.Instance)
self.Instance:Destroy()
self.Instance = nil
end
end

return CommandPalette
end

__modules["Overlay.Modal"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local Maid = __require("Core.Maid")
local Signal = __require("Core.Signal")
local Glyph = __require("Core.Glyph")
local Button = __require("Primitives.Button")

local Modal = {}
Modal.__index = Modal

local TONES = {
info = "info",
success = "success",
warning = "warning",
danger = "danger",
prompt = "accent",
}

function Modal.new(spec: { [any]: any }, context: { [any]: any })
local ctx = context or {}
local tokens = Theme.current()
local tone = TONES[spec.Tone or "prompt"] or "accent"

local self = setmetatable({
_spec = spec,
_maid = Maid.new("modal"),
_tokens = tokens,
_closed = false,
_result = nil,
}, Modal)

self.Closed = Signal.new("Modal.Closed")
self.Result = Signal.new("Modal.Result")

local layer = ctx.layer or spec.Layer

local backdrop = Util.frame({
Name = "VantageModalBackdrop",
Size = UDim2.fromScale(1, 1),
BackgroundColor3 = tokens.scrim,
BackgroundTransparency = 1,
ZIndex = 500,
Parent = layer,
})
self.Backdrop = backdrop

local blocker = Util.create("TextButton", {
Name = "Blocker",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
Size = UDim2.fromScale(1, 1),
ZIndex = 1,
Parent = backdrop,
})
blocker.Activated:Connect(function()
if spec.Dismissible ~= false then
self:Close(nil, "backdrop")
end
end)

local width = spec.Width or 340

local panel = Util.group({
Name = "Panel",
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.fromScale(0.5, 0.5),
Size = UDim2.fromOffset(width, 0),
AutomaticSize = Enum.AutomaticSize.Y,
BackgroundColor3 = tokens.elevated,
BackgroundTransparency = 0,
ZIndex = 510,
Parent = backdrop,
})
Util.corner(panel, tokens.radiusXl)
Util.stroke(panel, tokens.border, 1, 0.25)
Util.tag(panel, "Vantage")
self.Instance = panel

local stack = Util.row({
Name = "Stack",
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
Parent = panel,
})
Util.stack(stack, 0)
Util.pad(stack, { Left = 20, Right = 20, Top = 18, Bottom = 18 })
self.Content = stack

local header = Util.row({
Name = "Header",
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 1,
Parent = stack,
})
Util.list(header, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 10),
VerticalAlignment = Enum.VerticalAlignment.Top,
})

if spec.Icon ~= false then
local iconHolder = Util.row({
Name = "Icon",
Size = UDim2.fromOffset(18, 18),
LayoutOrder = 1,
Parent = header,
})
local glyph = Glyph.draw(iconHolder, spec.Icon or (spec.Tone == "danger" and "warning" or "info"), {
size = 18,
color = tokens[tone],
weight = 12,
zIndex = 512,
})
self.Icon = glyph
end

local titleBlock = Util.row({
Name = "Titles",
Size = UDim2.new(1, -28, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 2,
Parent = header,
})
Util.stack(titleBlock, 4)

local title = Util.text({
Name = "Title",
Text = spec.Title or "",
TextSize = tokens.fontSizeLg,
Font = "heading",
TextColor3 = tokens.text,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
TextWrapped = true,
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 1,
Visible = spec.Title ~= nil,
Parent = titleBlock,
})
self.Title = title

local body = Util.text({
Name = "Body",
Text = spec.Body or "",
TextSize = tokens.fontSizeMd,
Font = "body",
TextColor3 = tokens.textMuted,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
TextWrapped = true,
RichText = spec.RichText == true,
LineHeight = 1.15,
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 2,
Visible = (spec.Body or "") ~= "",
Parent = titleBlock,
})
self.Body = body

local actions = Util.row({
Name = "Actions",
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 2,
Parent = stack,
})
Util.list(actions, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 8),
VerticalAlignment = Enum.VerticalAlignment.Center,
HorizontalAlignment = spec.Align == "left" and Enum.HorizontalAlignment.Left
or Enum.HorizontalAlignment.Right,
})
self.Actions = actions
self._actionsHolder = actions

local spacer = Util.row({
Name = "Spacer",
Size = UDim2.new(1, 0, 0, 14),
LayoutOrder = 2,
Parent = stack,
})
spacer.LayoutOrder = 2
actions.LayoutOrder = 3

backdrop.BackgroundTransparency = 1
Motion.tween(backdrop, { BackgroundTransparency = tokens.scrimTransparency }, {
duration = 0.22,
easing = "enterSoft",
})
Motion.setScale(panel, 0.96)
Motion.scale(panel, 1, { duration = 0.38, easing = "emphasize" })
panel.GroupTransparency = 1
Motion.tween(panel, { GroupTransparency = 0 }, { duration = 0.2, easing = "enterSoft" })
panel.Position = UDim2.fromScale(0.5, 0.54)
Motion.tween(panel, { Position = UDim2.fromScale(0.5, 0.5) }, { duration = 0.4, easing = "enterSnap" })

if spec.Dismissible ~= false then
local UserInputService = game:GetService("UserInputService")
self._maid:add(UserInputService.InputBegan:Connect(function(input, processed)
if processed then
return
end
if input.KeyCode == Enum.KeyCode.Escape then
self:Close(nil, "escape")
end
end))
end

if ctx.maid then
ctx.maid:add(function()
self:Close(nil, "host")
end)
end

self:_buildActions()

self._maid:add(Theme.Changed:connect(function(next)
tokens = next
self._tokens = next
panel.BackgroundColor3 = next.elevated
title.TextColor3 = next.text
title.TextSize = next.fontSizeLg
body.TextColor3 = next.textMuted
if self.Icon then
Glyph.setColor(self.Icon, next[tone])
end
local stroke = panel:FindFirstChildOfClass("UIStroke")
if stroke then
stroke.Color = next.border
end
end))

return self
end

function Modal:_buildActions()
if self._built then
return
end
self._built = true
local spec = self._spec
local actions = spec.Actions or { { Text = "Close", Variant = "primary" } }
for index, action in ipairs(actions) do
Button.new({
Text = action.Text,
Variant = action.Variant or (index == #actions and "primary" or "secondary"),
Size = "md",
LayoutOrder = index,
Callback = function()
self:Close(action.Value ~= nil and action.Value or action.Text, "action")
end,
}, { parent = self._actionsHolder, maid = self._maid })
end
end

function Modal:Close(result: any, reason: string?)
if self._closed then
return self
end
self._closed = true
self._result = result

self.Result:fire(result, reason, self)
self.Closed:fire(result, reason, self)
Util.safeCall(self._spec.OnResult, result, reason, self)

local backdrop = self.Backdrop
local panel = self.Instance
Motion.tween(backdrop, { BackgroundTransparency = 1 }, { duration = 0.18, easing = "exit" })
Motion.scale(panel or backdrop, 0.97, { duration = 0.18, easing = "exit" })
Motion.tween(panel or backdrop, { GroupTransparency = 1 }, { duration = 0.16, easing = "exit" })
task.delay(0.22, function()
self:destroy()
end)
return self
end

function Modal:Await()
while not self._closed do
task.wait(0.05)
end
return self._result
end

function Modal:onResult(callback: (any, string?) -> ())
self.Result:connect(callback)
return self
end

function Modal:GetResult(): any
return self._result
end

function Modal:IsOpen(): boolean
return not self._closed
end

function Modal:destroy()
if self.Instance then
Motion.cancelAll(self.Instance)
end
self.Closed:destroy()
self.Result:destroy()
self._maid:destroy()
if self.Backdrop then
self.Backdrop:Destroy()
self.Backdrop = nil
self.Instance = nil
end
end

function Modal.Confirm(spec: { [any]: any }, context: { [any]: any })
local options = table.clone(spec or {})
options.Actions = options.Actions or {
{ Text = options.CancelText or "Cancel", Variant = "secondary", Value = false },
{ Text = options.ConfirmText or "Confirm", Variant = options.Tone == "danger" and "danger" or "primary", Value = true },
}
return Modal.new(options, context):Await() == true
end

function Modal.Alert(spec: { [any]: any }, context: { [any]: any })
local options = table.clone(spec or {})
options.Actions = options.Actions or { { Text = options.DismissText or "Got it", Variant = "primary", Value = "ok" } }
return Modal.new(options, context):Await()
end

return Modal
end

__modules["Overlay.Notify"] = function()

local Util = __require("Core.Util")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local Glyph = __require("Core.Glyph")
local Signal = __require("Core.Signal")
local Maid = __require("Core.Maid")
local Button = __require("Primitives.Button")

local Notify = {}
Notify.__index = Notify

local TONES = {
info = { accent = "info", icon = "info" },
success = { accent = "success", icon = "check" },
warning = { accent = "warning", icon = "warning" },
danger = { accent = "danger", icon = "warning" },
error = { accent = "danger", icon = "warning" },
brand = { accent = "accent", icon = "sparkle" },
default = { accent = "accent", icon = "dot" },
}

local WIDTH = 300

function Notify.new(context: { [any]: any })
local tokens = Theme.current()
local self = setmetatable({
_layer = context.layer,
_maid = Maid.new("notify"),
_tokens = tokens,
_max = context.maxVisible or 4,
_active = {},
_queue = {},
_byKey = {},
_counter = 0,
}, Notify)

self.Pushed = Signal.new("Notify.Pushed")
self.Dismissed = Signal.new("Notify.Dismissed")

local host = Util.frame({
Name = "VantageNotifyHost",
AnchorPoint = Vector2.new(1, 0),
Position = UDim2.new(1, -16, 0, 16),
Size = UDim2.fromOffset(WIDTH, 0),
AutomaticSize = Enum.AutomaticSize.Y,
BackgroundTransparency = 1,
ZIndex = 600,
Parent = context.layer,
})
Util.list(host, {
FillDirection = Enum.FillDirection.Vertical,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 8),
HorizontalAlignment = Enum.HorizontalAlignment.Right,
})
self.Instance = host

if context.maid then
context.maid:add(function()
self:destroy()
end)
end

return self
end

local function buildToast(self: any, spec: any): any
local tokens = self._tokens
local tone = TONES[spec.Tone or spec.Type or "default"] or TONES.default

local toast = {}

toast.key = spec.Key
toast.count = 1
toast._spec = spec
toast._buttons = {}

local card = Util.group({
Name = "VantageToast",
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
BackgroundColor3 = tokens.elevated,
BackgroundTransparency = 0.02,
ClipsDescendants = true,
LayoutOrder = spec.Order or 1,
Parent = self.Instance,
})
Util.corner(card, tokens.radiusLg)
Util.stroke(card, tokens.border, 1, 0.3)
Util.tag(card, "Vantage")
toast.Instance = card

local rail = Util.frame({
Name = "Rail",
Size = UDim2.new(0, 3, 1, 0),
Position = UDim2.fromOffset(0, 0),
BackgroundColor3 = tokens[tone.accent],
ZIndex = 3,
Parent = card,
})
Util.corner(rail, tokens.radiusLg)
toast._rail = rail

local inner = Util.row({
Name = "Inner",
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
Position = UDim2.fromOffset(0, 0),
Parent = card,
})
Util.pad(inner, { Left = 14, Right = 12, Top = 12, Bottom = 12 })
Util.stack(inner, 6)
toast._inner = inner

local header = Util.row({
Name = "Header",
Size = UDim2.new(1, 0, 0, 18),
LayoutOrder = 1,
Parent = inner,
})
Util.list(header, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 8),
VerticalAlignment = Enum.VerticalAlignment.Center,
})

local iconHolder = Util.row({
Name = "Icon",
Size = UDim2.fromOffset(14, 14),
LayoutOrder = 1,
Parent = header,
})
local icon = Glyph.draw(iconHolder, spec.Icon or tone.icon, {
size = 14,
color = tokens[tone.accent],
weight = 12,
zIndex = 4,
})
toast._iconHolder = iconHolder
toast._icon = icon

local title = Util.text({
Name = "Title",
Text = spec.Title or spec.Name or "",
TextSize = tokens.fontSizeMd,
Font = "subheading",
TextColor3 = tokens.text,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Center,
TextTruncate = Enum.TextTruncate.AtEnd,
Size = UDim2.new(1, -60, 1, 0),
LayoutOrder = 2,
Parent = header,
})
toast._title = title

local countLabel = Util.text({
Name = "Count",
Text = "",
TextSize = tokens.fontSizeXs + 1,
Font = "mono",
TextColor3 = tokens[tone.accent],
TextXAlignment = Enum.TextXAlignment.Center,
TextYAlignment = Enum.TextYAlignment.Center,
Size = UDim2.new(0, 22, 1, 0),
LayoutOrder = 3,
Visible = false,
Parent = header,
})
toast._count = countLabel

local closeHolder = Util.frame({
Name = "Close",
Size = UDim2.fromOffset(16, 16),
BackgroundColor3 = tokens.hover,
BackgroundTransparency = 1,
LayoutOrder = 4,
Parent = header,
})
Util.corner(closeHolder, 4)
local closeGlyph = Glyph.draw(closeHolder, "close", {
size = 9,
color = tokens.textDim,
weight = 13,
zIndex = 5,
})
toast._closeGlyph = closeGlyph
if closeGlyph then
closeGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
closeGlyph.Position = UDim2.fromScale(0.5, 0.5)
end
local closeHit = Util.create("TextButton", {
Name = "CloseHit",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
Size = UDim2.fromScale(1, 1),
ZIndex = 6,
Parent = closeHolder,
})
toast._closeHolder = closeHolder
toast._closeHit = closeHit

local body = Util.text({
Name = "Body",
Text = spec.Body or spec.Text or "",
TextSize = tokens.fontSizeSm,
Font = "body",
TextColor3 = tokens.textMuted,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
TextWrapped = true,
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 2,
Visible = (spec.Body or spec.Text) ~= nil,
Parent = inner,
})
toast._body = body

local actionRow = Util.row({
Name = "Actions",
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = 3,
Visible = false,
Parent = inner,
})
Util.list(actionRow, {
FillDirection = Enum.FillDirection.Horizontal,
SortOrder = Enum.SortOrder.LayoutOrder,
Padding = UDim.new(0, 6),
VerticalAlignment = Enum.VerticalAlignment.Center,
})
toast._actionRow = actionRow

local countdownTrack = Util.frame({
Name = "Countdown",
Size = UDim2.new(1, 0, 0, 2),
AnchorPoint = Vector2.new(0, 1),
Position = UDim2.new(0, 0, 1, 0),
BackgroundColor3 = tokens[tone.accent],
BackgroundTransparency = 0.82,
ZIndex = 3,
Parent = card,
})
toast._countdown = countdownTrack
toast._countdownFill = Util.frame({
Name = "Fill",
Size = UDim2.fromScale(1, 1),
BackgroundColor3 = tokens[tone.accent],
ZIndex = 4,
Parent = countdownTrack,
})

local hit = Util.create("TextButton", {
Name = "Hit",
Text = "",
BackgroundTransparency = 1,
AutoButtonColor = false,
Size = UDim2.fromScale(1, 1),
ZIndex = 2,
Parent = card,
})
toast._hit = hit

return toast
end

function Notify:push(spec: { [any]: any }): string
self._counter += 1
local id = spec.Id or ("vantage-toast-" .. tostring(self._counter))

if spec.Key and self._byKey[spec.Key] then
local existing = self._byKey[spec.Key]
existing.count += 1
existing._body.Text = spec.Body or spec.Text or existing._body.Text
if spec.Title then
existing._title.Text = spec.Title
end
existing._count.Visible = existing.count > 1
existing._count.Text = "x" .. tostring(existing.count)
Motion.setScale(existing.Instance, 0.96)
Motion.scale(existing.Instance, 1, { duration = 0.3, easing = "settle" })
existing._remaining = spec.Duration
return existing.id
end

local toast = buildToast(self, spec)
toast.id = id
table.insert(self._queue, toast)
self:_pump()

self.Pushed:fire(toast, self)
if not spec.Silent then
Button.playCue("notify")
end
return id
end

function Notify:_pump()
while #self._active < self._max and #self._queue > 0 do
local toast = table.remove(self._queue, 1)
self:_show(toast)
end
end

function Notify:_show(toast: any)
table.insert(self._active, toast)
if toast.key then
self._byKey[toast.key] = toast
end

local card = toast.Instance
local spec = toast._spec

if spec.Actions and #spec.Actions > 0 then
toast._actionRow.Visible = true
for index, action in ipairs(spec.Actions) do
local button = Button.new({
Text = action.Text,
Variant = action.Tone or (index == 1 and "secondary" or "ghost"),
Size = "sm",
LayoutOrder = index,
Callback = function()
Util.safeCall(action.Callback, self)
if action.KeepOpen ~= true then
self:dismiss(toast)
end
end,
}, { parent = toast._actionRow, maid = self._maid })
table.insert(toast._buttons, button)
end
end

local duration = spec.Duration
if duration == nil then
duration = spec.Persist and math.huge or 4.6
end
toast._duration = duration
toast._remaining = duration
toast._paused = false

card.Visible = true
card.Position = UDim2.fromOffset(WIDTH * 0.5, 0)
card.GroupTransparency = 1
Motion.tween(card, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, {
duration = 0.36,
easing = "enterSnap",
})
Motion.setScale(card, 0.94)
Motion.scale(card, 1, { duration = 0.4, easing = "settle" })
toast._countdownFill.Size = UDim2.fromScale(1, 1)

if duration ~= math.huge and duration > 0 then
toast._countdownTween = Motion.tween(toast._countdownFill, { Size = UDim2.fromScale(0, 1) }, {
duration = duration,
easing = "linear",
onComplete = function()
if not toast._paused then
self:dismiss(toast)
end
end,
})
end

toast._hit.Activated:Connect(function()
if spec.OnClick then
Util.safeCall(spec.OnClick, toast, self)
end
if spec.OnClickDismiss ~= false then
self:dismiss(toast)
end
end)
toast._closeHit.Activated:Connect(function()
self:dismiss(toast)
end)
toast._closeHit.MouseEnter:Connect(function()
toast._closeHolder.BackgroundTransparency = 0
Glyph.setColor(toast._closeGlyph, self._tokens.textMuted)
end)
toast._closeHit.MouseLeave:Connect(function()
toast._closeHolder.BackgroundTransparency = 1
if toast._closeGlyph then
Glyph.setColor(toast._closeGlyph, self._tokens.textDim)
end
end)
toast._hit.MouseEnter:Connect(function()
toast._paused = true
if toast._countdownTween then
toast._countdownTween:pause()
end
end)
toast._hit.MouseLeave:Connect(function()
toast._paused = false
if toast._countdownTween then
toast._countdownTween:resume()
end
end)
end

function Notify:dismiss(target: any)
local toast
if type(target) == "string" then
for _, candidate in ipairs(self._active) do
if candidate.id == target then
toast = candidate
break
end
end
if not toast then
for index, candidate in ipairs(self._queue) do
if candidate.id == target then
table.remove(self._queue, index)
return self
end
end
end
else
toast = target
end
if not toast then
return self
end

local index = table.find(self._active, toast)
if not index then
return self
end
table.remove(self._active, index)
if toast.key then
self._byKey[toast.key] = nil
end
if toast._countdownTween then
toast._countdownTween:cancel()
end

local card = toast.Instance
Motion.tween(card, { GroupTransparency = 1, Position = UDim2.fromOffset(30, 0) }, {
duration = 0.2,
easing = "exit",
onComplete = function()
card:Destroy()
end,
})
Motion.scale(card, 0.96, { duration = 0.2, easing = "exit" })

self.Dismissed:fire(toast, self)

task.defer(function()
self:_pump()
end)
return self
end

function Notify:clear()
for _, toast in ipairs(table.clone(self._active)) do
self:dismiss(toast)
end
for _, toast in ipairs(self._queue) do
toast.Instance:Destroy()
end
table.clear(self._queue)
table.clear(self._byKey)
return self
end

function Notify:count(): number
return #self._active
end

function Notify:destroy()
self.Pushed:destroy()
self.Dismissed:destroy()
self._maid:destroy()
if self.Instance then
self.Instance:Destroy()
self.Instance = nil
end
end

return Notify
end

__modules["init"] = function()

local Core = __namespace("Core")

local Util = __require("Core.Util")
local Signal = __require("Core.Signal")
local Maid = __require("Core.Maid")
local Easing = __require("Core.Easing")
local Motion = __require("Core.Motion")
local Theme = __require("Core.Theme")
local Config = __require("Core.Config")
local Glyph = __require("Core.Glyph")

local Layout = __namespace("Layout")

local Window = __require("Layout.Window")
local Tab = __require("Layout.Tab")
local Section = __require("Layout.Section")
local Elements = __require("Layout.Elements")
local Field = __require("Layout.Field")

local Primitives = __namespace("Primitives")

local Button = __require("Primitives.Button")
local Toggle = __require("Primitives.Toggle")
local Slider = __require("Primitives.Slider")
local Dropdown = __require("Primitives.Dropdown")
local Input = __require("Primitives.Input")
local Keybind = __require("Primitives.Keybind")
local Segmented = __require("Primitives.Segmented")
local Progress = __require("Primitives.Progress")
local Ripple = __require("Primitives.Ripple")

local Overlay = __namespace("Overlay")

local Notify = __require("Overlay.Notify")
local Modal = __require("Overlay.Modal")
local Tooltip = __require("Overlay.Tooltip")
local CommandPalette = __require("Overlay.CommandPalette")

local Feedback = __namespace("Feedback")

local LoadingScreen = __require("Feedback.LoadingScreen")
local LogoWave = __require("Feedback.LogoWave")

local Vantage = {}

Vantage.name = "Vantage"
Vantage.version = Util.version
Vantage.build = Util.build

Vantage.Util = Util
Vantage.Signal = Signal
Vantage.Maid = Maid
Vantage.Easing = Easing
Vantage.Motion = Motion
Vantage.Theme = Theme
Vantage.Config = Config
Vantage.Glyph = Glyph

Vantage.Window = Window
Vantage.Tab = Tab
Vantage.Section = Section
Vantage.Elements = Elements
Vantage.Field = Field

Vantage.Button = Button
Vantage.Toggle = Toggle
Vantage.Slider = Slider
Vantage.Dropdown = Dropdown
Vantage.Input = Input
Vantage.Keybind = Keybind
Vantage.Segmented = Segmented
Vantage.Progress = Progress
Vantage.Ripple = Ripple

Vantage.Notify = Notify
Vantage.Modal = Modal
Vantage.Tooltip = Tooltip
Vantage.CommandPalette = CommandPalette

Vantage.LoadingScreen = LoadingScreen
Vantage.LogoWave = LogoWave

function Vantage.Themes()
return Theme.list()
end

function Vantage.SetTheme(name: string, options: { [any]: any }?)
return Theme.apply(name, options)
end

function Vantage.RegisterTheme(name: string, definition: { [any]: any })
return Theme.register(name, definition)
end

function Vantage.ThemeFromSeed(seed: string, mode: string?)
return Theme.fromSeed(seed, mode or "dark")
end

function Vantage.ExportTheme(name: string): string
return Theme.export(name)
end

function Vantage.CreateWindow(spec: { [any]: any })
return Window.new(spec)
end

function Vantage.Setup(options: { [any]: any }?)
local opts = options or {}

if opts.Theme then
Theme.apply(opts.Theme)
end

if opts.Animations ~= nil then
Config.set("animations", opts.Animations == true)
end

local reduced = Config.respectSystemReducedMotion and Util.prefersReducedMotion()
Motion.setReducedMotion(not Config.animations or reduced)

if opts.Config then
Config.merge(opts.Config)
end

if opts.Tagging ~= nil then
Config.set("tagging", opts.Tagging == true)
end

return Vantage
end

function Vantage.Diagnostics()
local inset = Util.insets()
local viewport = Util.viewport()
return {
version = Vantage.version,
theme = Theme.name(),
mode = Theme.mode(),
animations = Config.animations,
reducedMotion = Motion.getReducedMotion(),
motion = Motion.stats(),
viewport = { width = viewport.X, height = viewport.Y },
insets = inset,
breakpoint = Util.breakpoint(),
loadedAt = os.clock(),
}
end

function Vantage.GetInstances()
local ok, CollectionService = pcall(function()
return game:GetService("CollectionService")
end)
if not ok or not CollectionService then
return {}
end
return CollectionService:GetTagged(Config.tag)
end

return Vantage
end

return __require("init")
