-- Lumen UI example: every element in one script.
-- Replace the URL with your own GitHub raw link.
local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_NAME/YOUR_REPO/main/Lumen.lua"))()

local Window = Lumen:CreateWindow({
	Title = "Lumen Demo",
	Subtitle = "v1.0",
	Theme = "Dark",                       -- Dark | Light | Ocean | Rose
	ToggleKey = Enum.KeyCode.RightShift,  -- show / hide the menu
})

----------------------------------------------------------------------
local Main = Window:AddTab({ Name = "Main", Icon = "★" })

Main:AddSection("Basics")
Main:AddButton({
	Name = "Say hello",
	Description = "Shows a notification",
	Callback = function()
		Lumen:Notify({ Title = "Hello!", Content = "Button clicked.", Type = "Success" })
	end,
})

Main:AddToggle({
	Name = "Enable feature",
	Description = "Flip it on or off",
	Default = false,
	Flag = "FeatureEnabled",
	Callback = function(on) print("Feature:", on) end,
})

Main:AddSlider({
	Name = "Walk speed",
	Min = 16, Max = 100, Default = 16, Increment = 1, Suffix = " studs/s",
	Flag = "WalkSpeed",
	Callback = function(v)
		local hum = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = v end
	end,
})

Main:AddDropdown({
	Name = "Team",
	Options = { "Red", "Blue", "Green" },
	Default = "Red",
	Flag = "Team",
	Callback = function(choice) print("Team:", choice) end,
})

Main:AddDropdown({
	Name = "Targets (multi)",
	Options = { "Players", "NPCs", "Items", "Vehicles" },
	Multi = true,
	Default = { "Players" },
	Flag = "Targets",
	Callback = function(list) print("Targets:", table.concat(list, ", ")) end,
})

----------------------------------------------------------------------
local Inputs = Window:AddTab({ Name = "Inputs", Icon = "✎" })

Inputs:AddTextbox({
	Name = "Display name",
	Placeholder = "Enter a name",
	Flag = "DisplayName",
	Callback = function(text) print("Name:", text) end,
})

Inputs:AddTextbox({
	Name = "Amount",
	Numeric = true, Default = 10,
	Callback = function(n) print("Amount:", n) end,
})

Inputs:AddKeybind({
	Name = "Quick action",
	Description = "Click, then press a key. Esc cancels, Backspace clears.",
	Default = Enum.KeyCode.F,
	Flag = "QuickKey",
	Callback = function() Lumen:Notify({ Title = "Keybind pressed" }) end,
})

Inputs:AddColorPicker({
	Name = "Highlight colour",
	Default = Color3.fromRGB(255, 80, 120),
	Flag = "Highlight",
	Callback = function(c) print("Colour:", c) end,
})

----------------------------------------------------------------------
local Settings = Window:AddTab({ Name = "Settings", Icon = "⚙" })

Settings:AddSection("Appearance")
Settings:AddDropdown({
	Name = "Theme",
	Options = { "Dark", "Light", "Ocean", "Rose" },
	Default = "Dark",
	Callback = function(name) Lumen:SetTheme(name) end,
})

Settings:AddSection("Config")
Settings:AddButton({
	Name = "Save config",
	Callback = function()
		local ok, err = Lumen:SaveConfig("default")
		Lumen:Notify({ Title = ok and "Config saved" or "Save failed", Content = ok and "" or tostring(err), Type = ok and "Success" or "Error" })
	end,
})
Settings:AddButton({
	Name = "Load config",
	Callback = function()
		local ok, err = Lumen:LoadConfig("default")
		Lumen:Notify({ Title = ok and "Config loaded" or "Load failed", Content = ok and "" or tostring(err), Type = ok and "Success" or "Error" })
	end,
})
Settings:AddButton({
	Name = "Unload UI",
	Description = "Removes the menu completely",
	Callback = function() Lumen:Destroy() end,
})

Settings:AddParagraph("About", "Lumen UI is a single-file Roblox UI library. Drag the title bar to move, drag the corner to resize.")
