local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Lumen.lua"))()

local Window = Lumen:CreateWindow({
	Title = "Lumen Interface Suite",
	Tag = "Pro",                 -- green pill
	Version = "v2.0.0",          -- red pill
	Subtitle = "Example Game",
	Footer = "dsc.gg/yourserver",
	MenuKey = Enum.KeyCode.RightShift,
	Snow = true,                 -- falling snow + dimmed backdrop
})

------------------------------------------------------------------ Main tab
local Main = Window:AddTab("Main")
Main:AddWarning({ Title = "NOTICE", Text = "Example warning banner for a tab", Type = "Warning" })

local Box = Main:AddTabbox("Left")
local A = Box:AddTab("Alpha")
local B = Box:AddTab("Beta")
local C = Box:AddTab("Gamma")

local t1 = A:AddToggle({ Text = "Cool Toggle", Flag = "CoolToggle", Callback = function(v) print("Cool Toggle:", v) end })
t1:AddKeybind({ Default = Enum.KeyCode.Insert, Mode = "Toggle", Name = "Cool Toggle" })

A:AddToggle({ Text = "Cool Toggle With a Tooltip", Tooltip = "Hover the ? chip to see this" })

local t3 = A:AddToggle({ Text = "Cool Toggle With Colors", Flag = "CoolColors" })
t3:AddColorPicker({ Default = Color3.fromRGB(120, 230, 120), Flag = "ColorA" })
t3:AddColorPicker({ Default = Color3.fromRGB(80, 220, 160), Flag = "ColorB" })

A:AddSlider({ Text = "Cool Slider", Min = 0, Max = 300, Default = 120, Flag = "CoolSlider" })
A:AddDropdown({ Text = "Cool Dropdown", Values = { "One", "Two", "Three" }, Default = "One", Flag = "CoolDrop" })
A:AddImage({ Image = "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150", Height = 110 })
A:AddButton({ Text = "Button", Callback = function() Lumen:Notify({ Title = "Button", Content = "Clicked!", Type = "Success" }) end })

B:AddToggle({ Text = "Another Toggle", Flag = "Another" })
B:AddDropdown({ Text = "Multi Dropdown", Values = { "Red", "Green", "Blue", "Yellow" }, Multi = true, Default = { "Red" }, Flag = "MultiDrop" })
C:AddLabel("Gamma tab content goes here.", { Dim = true })

local Right = Main:AddGroup("Controls", "Right")
Right:AddToggle({ Text = "Silent Toggle", Flag = "Silent" })
Right:AddLabel("I'm a basic label")
Right:AddSlider({ Text = "Speed", Min = 0, Max = 8000, Default = 8000, Suffix = " km/h", Increment = 10, Flag = "Speed" })
Right:AddLabel("Labels wrap automatically when the text is longer than the column, so you never have to worry about overflow.", { Dim = true })
Right:AddInput({ Text = "Cool Input", Placeholder = "Dynamic Input (textbox)", Flag = "Input", Callback = function(v) print("Input:", v) end })
Right:AddDivider()
Right:AddButton({ Text = "Button" }):AddSubButton({ Text = "Sub-button", Callback = function() Lumen:Notify("Sub-button pressed") end })
Right:AddLabel("Standalone keybind"):AddKeybind({ Default = Enum.KeyCode.X, Mode = "Hold", Name = "Blade Farm", Flag = "BladeKey" })

------------------------------------------------------------ Floating panels
local credits = Lumen:CreateCredits({
	Title = "CREDITS",
	Subtitle = "Cool people behind *your* script",
	Position = UDim2.new(1, -330, 0.5, -120),
	Entries = {
		{ Name = "@developer", Role = "Owner/Developer", RoleColor = Color3.fromRGB(96, 205, 140), Description = "Founder and developer." },
		{ Name = "@tester", Role = "Owner/Tester", RoleColor = Color3.fromRGB(240, 170, 70), Description = "Co-founder." },
		{ Name = "@helper", Role = "Contributor", RoleColor = Color3.fromRGB(100, 160, 240), Description = "Lorem ipsum dolor sit amet." },
	},
})

-- Uncomment to show a key prompt. Validate is your own function: return true, or false + message.
-- Lumen:CreateKeySystem({
-- 	Title = "Key System",
-- 	Note = "Get your key from our Discord",
-- 	GetKeyLink = "https://discord.gg/yourserver",
-- 	Validate = function(key) return key == "my-secret-key", "That key is not valid" end,
-- 	OnSuccess = function() print("Unlocked!") end,
-- })

------------------------------------------------------------------ Settings
Window:AddConfigTab("Config")

Lumen:Notify({ Title = "Lumen", Content = "Loaded. Press RightShift to hide/show.", Type = "Info" })
Lumen:LoadAutoload()
