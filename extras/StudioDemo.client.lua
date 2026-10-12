--[[
	Minimal TingUI setup for a normal Roblox game. Lives in StarterPlayerScripts as a LocalScript.
	Press RightShift to show or hide the window.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local TingUI = require(ReplicatedStorage:WaitForChild("TingUI"))

-- configs go to a DataStore through the server (see extras/DataStoreStorage.lua); without this they stay in memory
local storage = ReplicatedStorage:FindFirstChild("TingUIDataStoreStorage")
if storage then TingUI:SetStorage(require(storage).Client()) end

TingUI:Configure({ Theme = "Lavender", NotifyPosition = "BottomRight" })

local Window = TingUI:CreateWindow({ Title = "My Game", Tag = "Beta", Version = "v1.0.0", MenuKey = Enum.KeyCode.RightShift })
local Main = Window:AddTab("Main")
local Movement = Main:AddGroup("Movement")

Movement:AddSlider({
	Text = "Walk speed", Min = 8, Max = 32, Default = 16, Flag = "WalkSpeed",
	Callback = function(v)
		local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = v end
	end,
})
Movement:AddToggle({ Text = "Show watermark", Default = true, Flag = "ShowWatermark", Callback = function(on) TingUI:SetWatermarkVisible(on) end })
Movement:AddButton({ Text = "Say hi", Callback = function() TingUI:Notify({ Title = "Hi", Content = "TingUI is running.", Type = "Success" }) end })

Window:AddConfigTab("Settings")
TingUI:LoadAutoload()
