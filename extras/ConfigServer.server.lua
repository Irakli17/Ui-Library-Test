-- Serves TingUI configs from a DataStore. Put this in ServerScriptService (dev.project.json does it for you).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage:WaitForChild("TingUIDataStoreStorage")).Serve()
