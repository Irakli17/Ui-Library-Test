--!nonstrict
--[[
	Vantage 1.0.0 · Core/Signal
	------------------------------------------------------------------
	A tiny, dependency-free event primitive. Every public callback in
	Vantage routes through this so that one bad listener can never take
	down another, and so that teardown is always guaranteed.

	Handlers are invoked in connection order. Errors are captured and
	reported with a traceback instead of unwinding the fire loop.
]]

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

--- Creates a new signal.
--- @return Signal
function Signal.new(name: string?)
	local self = setmetatable({}, Signal)
	self._handlers = {}
	self._connections = {}
	self._upstream = {}
	self._name = name
	self._destroyed = false
	return self
end

--- Number of connections ever handed out by this signal (diagnostics).
function Signal:connectionCount(): number
	return #self._connections
end

--- Connects a handler. Returns a Connection you can disconnect.
function Signal:connect(handler: (...any) -> ())
	assert(type(handler) == "function", "[Vantage] Signal:connect expects a function")

	local connection = setmetatable({
		_id = uid(),
		Connected = true,
		_signal = self,
		_handler = handler,
	}, Connection)

	table.insert(self._handlers, connection)
	-- Connection history is bounded: it exists so that `destroy()` can
	-- guarantee teardown, not so that it can be enumerated forever.
	table.insert(self._connections, connection)
	if #self._connections > 512 then
		table.remove(self._connections, 1)
	end
	return connection
end

--- Connects a handler that runs at most once.
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

--- Fires all handlers with the given arguments.
function Signal:fire(...)
	if self._destroyed then
		return
	end

	-- Snapshot so that handlers may safely connect/disconnect mid-fire.
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

--- Internal: removes a connection from the live list.
function Signal:_remove(connection)
	local index = table.find(self._handlers, connection)
	if index then
		table.remove(self._handlers, index)
	end
end

--- Yields until the next fire, then returns its arguments.
function Signal:wait()
	local thread = coroutine.running()
	local connection
	connection = self:connect(function(...)
		connection:disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

--- Disconnects every handler.
function Signal:disconnectAll()
	for _, connection in ipairs(table.clone(self._handlers)) do
		connection:disconnect()
	end
	self._handlers = {}
	self._connections = {}
end

--- Number of live handlers.
function Signal:listenerCount(): number
	return #self._handlers
end

--- True when the signal has been destroyed.
function Signal:isDestroyed(): boolean
	return self._destroyed
end

--- Disconnects everything and permanently disables the signal.
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

--- Connection doubles as a maid-compatible item.
function Connection:destroy()
	self:disconnect()
end

Signal.Connection = Connection

--[[ Merging helpers ------------------------------------------------ ]]

--- Fires whenever any of the given signals fire. Destroying the
--- merged signal tears down every upstream connection it owns.
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

--- A signal whose fires are deferred to the next resumption point,
--- which coalesces bursts (useful for text input, resize, scroll).
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
