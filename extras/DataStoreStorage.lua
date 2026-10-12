--[[
	TingUI config storage backed by a DataStore, for real games (no executor file functions there).

	Server (a Script, once):
		require(ReplicatedStorage.TingUIDataStoreStorage).Serve()

	Client (your LocalScript, before building windows):
		local TingUI = require(ReplicatedStorage.TingUI)
		TingUI:SetStorage(require(ReplicatedStorage.TingUIDataStoreStorage).Client())

	Each player's configs live under one DataStore key ("u<UserId>"), so they follow the player between servers.
	The server checks every request: strings only, bounded sizes, a cap on how many configs one player keeps,
	and a short cooldown between writes so nobody can burn through the DataStore budget.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataStoreStorage = {}

local REMOTE_NAME = "TingUIConfigStorage"
local MAX_KEY = 120          -- characters in a config key ("<Folder>/<name>.json")
local MAX_VALUE = 60000      -- characters in one saved config
local MAX_ENTRIES = 40       -- configs + autoload per player
local WRITE_COOLDOWN = 1.5   -- seconds between writes per player

function DataStoreStorage.Serve(options)
	options = options or {}
	local Players = game:GetService("Players")
	local store = game:GetService("DataStoreService"):GetDataStore(options.StoreName or "TingUIConfigs")

	local remote = Instance.new("RemoteFunction")
	remote.Name = options.RemoteName or REMOTE_NAME
	remote.Parent = ReplicatedStorage

	local cache, lastWrite = {}, {}

	local function Load(player)
		local data = cache[player]
		if data then return data end
		local ok, res = pcall(function() return store:GetAsync("u" .. player.UserId) end)
		if not ok then error("Couldn't reach saved configs, try again in a moment", 0) end
		data = type(res) == "table" and res or {}
		cache[player] = data
		return data
	end

	local function Save(player, data)
		local now = os.clock()
		if lastWrite[player] and now - lastWrite[player] < WRITE_COOLDOWN then error("Saving too fast, wait a second", 0) end
		lastWrite[player] = now
		local ok = pcall(function() store:SetAsync("u" .. player.UserId, data, { player.UserId }) end)
		if not ok then error("Couldn't save, try again in a moment", 0) end
	end

	local function Count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

	local Ops = {
		Read = function(data, key) return data[key] end,
		List = function(data, folder)
			local out = {}
			for k in pairs(data) do
				if k:sub(1, #folder + 1) == folder .. "/" then table.insert(out, k) end
			end
			return out
		end,
		Write = function(data, key, value, player)
			if type(value) ~= "string" or #value > MAX_VALUE then error("That config is too large", 0) end
			if data[key] == nil and Count(data) >= MAX_ENTRIES then error("Too many saved configs, delete one first", 0) end
			local old = data[key]
			data[key] = value
			local ok, err = pcall(Save, player, data)
			if not ok then data[key] = old error(err, 0) end
		end,
		Delete = function(data, key, _, player)
			if data[key] == nil then return end
			local old = data[key]
			data[key] = nil
			local ok, err = pcall(Save, player, data)
			if not ok then data[key] = old error(err, 0) end
		end,
	}

	remote.OnServerInvoke = function(player, op, key, value)
		local fn = type(op) == "string" and Ops[op]
		if not fn or type(key) ~= "string" or #key > MAX_KEY then return false, "Bad request" end
		return pcall(function() return fn(Load(player), key, value, player) end)
	end

	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
		lastWrite[player] = nil
	end)
	return remote
end

function DataStoreStorage.Client(options)
	options = options or {}
	local remote = ReplicatedStorage:WaitForChild(options.RemoteName or REMOTE_NAME)
	local function Call(op, key, value)
		local ok, res = remote:InvokeServer(op, key, value)
		if not ok then error(res, 0) end
		return res
	end
	return {
		Name = "DataStore",
		Persistent = true,
		Read = function(key) return Call("Read", key) end,
		Write = function(key, value) Call("Write", key, value) end,
		Delete = function(key) Call("Delete", key) end,
		List = function(folder) return Call("List", folder) end,
	}
end

return DataStoreStorage
