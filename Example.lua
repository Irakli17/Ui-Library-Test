local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Lumen.lua"))()

local Window = Lumen:CreateWindow({
	Title = "Lumen Interface Suite",
	Tag = "Pro",                         -- green pill
	Version = "v2.3.0",                  -- red pill
	Subtitle = "Example Game",
	Footer = "discord.gg/yourserver",
	WatermarkTitle = "Lumen V2",
	MenuKey = Enum.KeyCode.RightShift,
	Snow = { Count = 70, Speed = 1 },    -- falling snow (true for defaults)
	Backdrop = { Dim = 0.5, Blur = 8 },  -- dimmed + blurred world behind the UI
	-- Dock = {"menu", "hotkeys", "palette", "watermark", "snow"},  -- which built-in dock buttons to show (default: menu, hotkeys, palette)
	-- Fill = false,                                                 -- content-sized boxes instead of equal-height columns
})

------------------------------------------------------------------ Main tab
local Main = Window:AddTab("Main")
Main:AddWarning({ Title = "PATCHED!!!", Text = "example warning for a tab" })   -- add Type = "Warning" etc. to tint the title

-- left column: a tabbox with sub-tabs
local Left = Main:AddTabbox("Left")
local Alpha, Beta, Gamma = Left:AddTab("Alpha"), Left:AddTab("Beta"), Left:AddTab("Gamma")

Alpha:AddToggle({ Text = "Cool Toggle", Flag = "CoolToggle", Callback = function(v) print("Cool Toggle:", v) end })
Alpha:AddToggle({ Text = "Cool Selected Toggle", Default = true })
Alpha:AddToggle({ Text = "Disabled Toggle", Disabled = true })
Alpha:AddToggle({ Text = "Cool Toggle" }):AddKeybind({ Default = Enum.KeyCode.Insert, Mode = "Toggle", Name = "Cool Toggle" })
Alpha:AddToggle({ Text = "Cool Toggle With a Tooltip", Tooltip = "Hover the ? chip to see this" })
local colors = Alpha:AddToggle({ Text = "Cool Toggle With Colors", Flag = "CoolColors" })
colors:AddColorPicker({ Default = Color3.fromRGB(158, 224, 151), Flag = "ColorA" })
colors:AddColorPicker({ Default = Color3.fromRGB(120, 230, 170), Flag = "ColorB" })
Alpha:AddSlider({ Text = "Cool Slider", Min = 0, Max = 300, Default = 300, Flag = "CoolSlider" })
Alpha:AddDropdown({ Text = "Cool Dropdown", Values = { "One", "Two", "Three" }, Flag = "CoolDrop" })
Alpha:AddViewport({ Height = 150, Character = true })   -- your avatar; drag to orbit, auto-rotates when released
Alpha:AddButton({ Text = "Button", Callback = function() Lumen:Notify("test notif") end })
Alpha:AddButton({ Text = "Button" }):AddSubButton({ Text = "Sub-button", Callback = function() Lumen:Notify("Sub-button pressed") end })

Beta:AddToggle({ Text = "Another Toggle", Flag = "Another" })
Beta:AddDropdown({ Text = "Multi Dropdown", Values = { "Red", "Green", "Blue", "Yellow" }, Multi = true, Default = { "Red" }, Flag = "MultiDrop" })
Beta:AddImage({ Image = "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150", Height = 90 })
Gamma:AddLabel("Gamma tab content goes here.", { Dim = true })   -- an empty sub-tab would simply show nothing

local Quick = Main:AddGroup({ Title = "Quick Actions", Icon = "command", Side = "Left" })
Quick:AddLabel("Standalone keybind (hold)"):AddKeybind({ Default = Enum.KeyCode.X, Mode = "Hold", Name = "Quick Action", Flag = "QuickKey" })
Quick:AddLabel("Always on"):AddKeybind({ Mode = "Always", Name = "Always Active" })

-- right column
local Right = Main:AddGroup(nil, "Right")
Right:AddToggle({ Text = "Silent Toggle", Flag = "Silent", Disabled = true })
Right:AddToggle({ Text = "Cool Toggle With Colors" }):AddColorPicker({ Default = Color3.fromRGB(255, 170, 255) })
Right:AddLabel("I'm a basic label")
Right:AddSlider({ Text = "Cool Slider", Min = 0, Max = 8000, Default = 8000, Suffix = " km/100", Increment = 10, Flag = "Speed" })
Right:AddLabel("Labels wrap automatically when the text is longer than the column, so you never have to worry about overflow at all.")
Right:AddInput({ Text = "Cool Input", Placeholder = "Dynamic Input (textbox)", Flag = "Input", Callback = function(v) print("Input:", v) end })
Right:AddInput({ Text = "Dynamic Input", Placeholder = "Type here, it grows as you type (Enter to submit)", Dynamic = true, Flag = "DynInput",
	Callback = function(v) print("Dynamic:", v) end })
Right:AddViewport({ Height = 150 })                  -- default: a gray block
Right:AddButton({ Text = "Button" }):AddSubButton({ Text = "Sub-button", Callback = function() Lumen:Notify("Sub-button pressed") end })

-- notification + confirmation tests
local Tests = Main:AddGroup({ Title = "Tests", Icon = "command", Side = "Right" })
Tests:AddButton({ Text = "Success", Callback = function()
	Lumen:Notify({ Title = "Success", Content = "Settings applied.", Type = "Success" })
end }):AddSubButton({ Text = "Failure", Callback = function()
	Lumen:Notify({ Title = "Failure", Content = "Could not apply settings.", Type = "Danger" })
end })
Tests:AddButton({ Text = "Warning", Callback = function()
	Lumen:Notify({ Title = "Warning", Content = "This may be unstable.", Type = "Warning" })
end }):AddSubButton({ Text = "Info", Callback = function()
	Lumen:Notify({ Title = "Info", Content = "Press Ctrl+K to search everything.", Type = "Info" })
end })
-- a button that asks first: hold-to-confirm dialog in the theme's style
Tests:AddButton({
	Text = "Reset Everything",
	Confirm = { Title = "Reset everything?", Text = "All toggles and sliders go back to their defaults. This can't be undone.",
		Type = "Danger", Confirm = "Reset", Hold = 1 },
	Callback = function() Lumen:Notify({ Title = "Reset", Content = "Everything was reset.", Type = "Success" }) end,
})
Tests:AddButton({ Text = "Quick confirm", Confirm = { Title = "Apply changes?", Text = "Click Confirm or press Enter.", Type = "Info" },
	Callback = function() Lumen:Notify({ Content = "Applied." }) end })

local RightBox = Main:AddTabbox("Right")
local Delta = RightBox:AddTab("Delta")
RightBox:AddTab("Epsilon")
RightBox:AddTab("Zeta")
Delta:AddLabel("Empty sub-tabs show nothing", { Dim = true })

------------------------------------------------------------------ More tabs (empty tabs show nothing)
Window:AddTab("Visuals")
Window:AddTab("World")
Window:AddTab("Character")
Window:AddTab("Exploits")
Window:AddTab("Webhook")
-- credits inside a tab
local About = Window:AddTab("About")
About:AddGroup("Credits", "Left"):AddCredits({
	{ Name = "@developer", Role = "Owner/Developer", RoleColor = Color3.fromRGB(80, 159, 119), Description = "Founder and developer." },
	{ Name = "@tester", Role = "Owner/Tester", RoleColor = Color3.fromRGB(168, 128, 82), Description = "Co-founder." },
})
About:AddGroup("Contributors", "Right"):AddCredits({
	{ Name = "@helper", Role = "Contributor » Bug fixing", RoleColor = Color3.fromRGB(159, 88, 88), Description = "Lorem ipsum dolor sit amet." },
	{ Name = "@designer", Role = "Contributor » Lorem ipsum", RoleColor = Color3.fromRGB(80, 158, 237), Description = "Lorem ipsum dolor sit amet." },
})

Window:AddConfigTab("Config")   -- menu, effects, tab/section toggles, theme editor, configs: all adjustable in the UI

------------------------------------------------------------ Floating panels
local skins = Lumen:CreatePanel({ Title = "Skin Changer", Width = 440, Position = UDim2.new(1, -490, 0, 96) })
local items = {}
for i = 1, 12 do
	items[i] = { Image = "rbxthumb://type=AvatarHeadShot&id=" .. i .. "&w=150&h=150" }
end
skins:AddImageGrid({ Items = items, Columns = 4, CellHeight = 82, Callback = function() Lumen:Notify("Skin selected") end })

-- 3D preview. Drag to orbit in any direction, wheel to zoom. Gets its own dock button (scan icon).
local preview = Lumen:CreatePanel({
	Title = "Preview", Width = 250, Position = UDim2.new(1, -790, 0.5, -90),
	Dock = { Icon = "scan", Tooltip = "Preview", Order = 20 },
})
preview:AddViewport({ Height = 320, Character = true, Color = Color3.fromRGB(58, 58, 62) })

Lumen:CreateKeySystem({
	Title = "Key System",
	Note = "Get your key from our Discord",
	Placeholder = "Enter your key...",
	DiscordLink = "https://discord.gg/yourserver",   -- adds the Discord icon in the header
	GetKeyLink = "https://example.com/getkey",
	Validate = function(k) return k == "my-secret-key", "That key is not valid" end,
	OnSuccess = function() Lumen:Notify("Unlocked!") end,
	Position = UDim2.new(1, -900, 1, -230),
})

Lumen:CreateCredits({
	Title = "CREDITS",
	Subtitle = "Cool people behind *your* script",
	Position = UDim2.new(1, -400, 0.5, -10),
	Height = 420,
	Dock = { Icon = "user", Tooltip = "Credits", Order = 50 },
	Entries = {
		{ Name = "@developer", Role = "Owner/Developer", RoleColor = Color3.fromRGB(80, 159, 119), Description = "Founder and developer." },
		{ Name = "@tester", Role = "Owner/Tester", RoleColor = Color3.fromRGB(168, 128, 82), Description = "Co-founder." },
		{ Name = "@helper", Role = "Contributor » Bug fixing", RoleColor = Color3.fromRGB(159, 88, 88), Description = "Lorem ipsum dolor sit amet." },
		{ Name = "@designer", Role = "Contributor » Lorem ipsum", RoleColor = Color3.fromRGB(80, 158, 237), Description = "Lorem ipsum dolor sit amet." },
	},
})

-- your own dock button (icons: window, keyboard, command, scan, bell, user, gear, snow, list, discord, or an rbxassetid)
-- Lumen:AddDockButton({ Icon = "gear", Tooltip = "Say hi", Order = 60, Callback = function() Lumen:Notify("Hello!") end })
-- (left commented out so the dock matches the reference exactly: menu, preview, hotkeys, palette, credits)

Lumen:Notify("test notif")
Lumen:Notify("test notif")
Lumen:LoadAutoload()
