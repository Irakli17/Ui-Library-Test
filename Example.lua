local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Lumen.lua"))()

local Window = Lumen:CreateWindow({
	Title = "Lumen Interface Suite",
	Tag = "Pro",                        -- green pill
	Version = "v2.1",                   -- red pill
	Subtitle = "Example Game",
	Footer = "dsc.gg/yourserver",
	MenuKey = Enum.KeyCode.RightShift,
	Snow = { Count = 70, Speed = 1 },   -- falling snow (true for defaults)
	Backdrop = { Dim = 0.5, Blur = 8 }, -- dimmed + blurred world behind the UI
})

------------------------------------------------------------------ Main tab
local Main = Window:AddTab("Main")
Main:AddWarning({ Title = "NOTICE", Text = "example warning for a tab", Type = "Warning" })

-- left: tabbox with sub-tabs
local Box = Main:AddTabbox("Left")
local A = Box:AddTab("Alpha")
local B = Box:AddTab("Beta")
local C = Box:AddTab("Gamma")

A:AddToggle({ Text = "Cool Toggle", Flag = "CoolToggle", Callback = function(v) print("Cool Toggle:", v) end })
	:AddKeybind({ Default = Enum.KeyCode.Insert, Mode = "Toggle", Name = "Cool Toggle" })
A:AddToggle({ Text = "Cool Selected Toggle", Default = true })
A:AddToggle({ Text = "Cool Toggle With a Tooltip", Tooltip = "Hover the ? chip to see this" })
local colors = A:AddToggle({ Text = "Cool Toggle With Colors", Flag = "CoolColors" })
colors:AddColorPicker({ Default = Color3.fromRGB(120, 230, 120), Flag = "ColorA" })
colors:AddColorPicker({ Default = Color3.fromRGB(80, 220, 160), Flag = "ColorB" })
A:AddSlider({ Text = "Cool Slider", Min = 0, Max = 300, Default = 300, Flag = "CoolSlider" })
A:AddDropdown({ Text = "Cool Dropdown", Values = { "One", "Two", "Three" }, Flag = "CoolDrop" })
A:AddViewport({ Height = 150, Character = true })   -- rotating preview of your own avatar
A:AddButton({ Text = "Button", Callback = function() Lumen:Notify("test notif") end })

B:AddToggle({ Text = "Another Toggle", Flag = "Another" })
B:AddDropdown({ Text = "Multi Dropdown", Values = { "Red", "Green", "Blue", "Yellow" }, Multi = true, Default = { "Red" }, Flag = "MultiDrop" })
C:AddLabel("Gamma tab content goes here.", { Dim = true })

-- right: plain group
local Right = Main:AddGroup(nil, "Right")
Right:AddToggle({ Text = "Silent Toggle", Flag = "Silent" })
Right:AddToggle({ Text = "Cool Toggle With Colors" }):AddColorPicker({ Default = Color3.fromRGB(255, 170, 255) })
Right:AddLabel("I'm a basic label")
Right:AddSlider({ Text = "Cool Slider", Min = 0, Max = 8000, Default = 8000, Suffix = " km/100", Increment = 10, Flag = "Speed" })
Right:AddLabel("Labels wrap automatically when the text is longer than the column, so you never have to worry about overflow at all.")
Right:AddInput({ Text = "Cool Input", Placeholder = "Dynamic Input (textbox)", Flag = "Input", Callback = function(v) print("Input:", v) end })
Right:AddViewport({ Height = 150 })                  -- default: a gray block
Right:AddButton({ Text = "Button" }):AddSubButton({ Text = "Sub-button", Callback = function() Lumen:Notify("Sub-button pressed") end })
Right:AddLabel("Blade Farm key"):AddKeybind({ Default = Enum.KeyCode.X, Mode = "Hold", Name = "Blade Farm", Flag = "BladeKey" })

------------------------------------------------------------------ More tabs
Window:AddTab("Visuals")
Window:AddTab("World")
Window:AddTab("Character")
Window:AddTab("Webhook")
Window:AddConfigTab("Config")   -- menu, effects, theme editor, configs: everything adjustable in the UI

------------------------------------------------------------ Floating panels
-- Image grid panel
local skins = Lumen:CreatePanel({ Title = "Skin Changer", Width = 400, Position = UDim2.new(1, -440, 0, 90) })
local items = {}
for i = 1, 8 do
	items[i] = { Image = "rbxthumb://type=AvatarHeadShot&id=" .. i .. "&w=150&h=150", Name = "Skin " .. i }
end
skins:AddImageGrid({ Items = items, Columns = 4, CellHeight = 80, Callback = function(item, i) Lumen:Notify("Selected " .. item.Name) end })

-- Preview panel with a 3D viewport
local preview = Lumen:CreatePanel({ Title = "Preview", Width = 240, Position = UDim2.new(1, -700, 0.5, -60) })
preview:AddViewport({ Height = 300, Character = true })

-- Key prompt. Validate is YOUR function: return true, or false + a message.
Lumen:CreateKeySystem({
	Title = "Key System",
	Note = "Get your key from our Discord",
	GetKeyLink = "https://discord.gg/yourserver",
	Validate = function(k) return k == "my-secret-key", "That key is not valid" end,
	OnSuccess = function() Lumen:Notify("Unlocked!") end,
	Position = UDim2.new(1, -740, 1, -190),
})

-- Credits
Lumen:CreateCredits({
	Title = "CREDITS",
	Subtitle = "Cool people behind *your* script",
	Position = UDim2.new(1, -350, 0.5, -20),
	Entries = {
		{ Name = "@developer", Role = "Owner/Developer", RoleColor = Color3.fromRGB(96, 205, 140), Description = "Founder and developer." },
		{ Name = "@tester", Role = "Owner/Tester", RoleColor = Color3.fromRGB(240, 170, 70), Description = "Co-founder." },
		{ Name = "@helper", Role = "Contributor » Bug fixing", RoleColor = Color3.fromRGB(232, 92, 104), Description = "Lorem ipsum dolor sit amet." },
		{ Name = "@designer", Role = "Contributor » Lorem ipsum", RoleColor = Color3.fromRGB(100, 160, 240), Description = "Lorem ipsum dolor sit amet." },
	},
})

-- Extra dock button (icons: window, keyboard, list, bell, user, snow, gear, or an rbxassetid)
Lumen:AddDockButton({ Icon = "user", Tooltip = "Say hi", Callback = function() Lumen:Notify("Hello!") end })

Lumen:Notify("test notif")
Lumen:Notify("test notif")
Lumen:LoadAutoload()
