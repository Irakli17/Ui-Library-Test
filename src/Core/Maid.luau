--!nonstrict
--[[
	Vantage 1.0.0 · Core/Maid
	------------------------------------------------------------------
	Deterministic teardown. Anything handed to a Maid is released in
	reverse order when the Maid is cleaned, which keeps the destroy
	graph deterministic and leak-free.

	Accepted items:
		Instance            -> :Destroy()
		Connection          -> :disconnect()
		Maid / Signal       -> :destroy()
		table with .destroy -> :destroy()
		table with .cancel  -> :cancel()
		function            -> called
]]

local Maid = {}
Maid.__index = Maid

--- Creates an empty Maid.
function Maid.new(name: string?)
	return setmetatable({
		_items = {},
		_name = name,
		_dead = false,
	}, Maid)
end

--- Registers an item for cleanup. Returns the item for chaining.
function Maid:add(item: any): any
	if item == nil then
		return item
	end
	if self._dead then
		-- Already destroyed: release immediately rather than leaking.
		Maid.release(item)
		return item
	end
	table.insert(self._items, item)
	return item
end

--- Registers many items at once.
function Maid:addAll(items: { any })
	for _, item in ipairs(items) do
		self:add(item)
	end
	return self
end

--- Removes an item without releasing it.
function Maid:remove(item: any): any
	local index = table.find(self._items, item)
	if index then
		table.remove(self._items, index)
	end
	return item
end

--- Replaces a named slot: releases whatever was there.
function Maid:set(key: string, item: any): any
	local previous = self._slots and self._slots[key]
	if previous and previous ~= item then
		Maid.release(previous)
	end
	self._slots = self._slots or {}
	self._slots[key] = item
	return item
end

--- Releases everything and leaves the Maid reusable.
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

--- Releases everything and marks the Maid permanently dead.
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

--- Releases a single item according to its type.
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

--- A Maid that never releases anything; useful as a null object.
Maid.none = Maid.new("none")

return Maid
