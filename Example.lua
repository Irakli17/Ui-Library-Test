--[[
	Lumen example: every element, the reference layout, and real Roblox features wired to the controls.
	Everything here runs client-side and is restored when the UI is unloaded.
]]

-- Options can be passed straight into the loadstring call. Id keeps this script's UI separate from other scripts using Lumen.
local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Lumen.lua"))({
	Id = "LumenExample",
	Folder = "LumenExample",
	-- Theme = "Cosmos",          -- start in any theme: Lavender, Ocean, Rose, Emerald, Sunset, Mono, Synthwave, Frost, Royal, Candy, Arcade, Cosmos, Storm
})

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local Window = Lumen:CreateWindow({
	Title = "Lumen Interface Suite",
	Tag = "Pro",                         -- green pill
	Version = "v0.0.2",                  -- red pill
	Subtitle = "Example Game",
	Footer = "discord.gg/yourserver",
	WatermarkTitle = "Lumen V2",
	MenuKey = Enum.KeyCode.RightShift,
	Snow = { Count = 70, Speed = 1 },    -- particles follow the theme
	Backdrop = { Dim = 0.5, Blur = 8 },  -- dimmed + blurred world behind the UI
})

-- Anything the script changes in the game is put back when the UI unloads.
local Restore = {}
Lumen.Events.Unloading:Connect(function()
	for _, fn in ipairs(Restore) do pcall(fn) end
end)

------------------------------------------------------------------ Combat (the reference layout)
local Combat = Window:AddTab("Combat")
Combat:AddWarning({ Title = "PATCHED!!!", Text = "example warning for a tab" })

local Left = Combat:AddTabbox("Left")
local Aimbot, FOV, Prediction = Left:AddTab("Aimbot"), Left:AddTab("FOV"), Left:AddTab("Prediction")

Aimbot:AddToggle({ Text = "Cool Toggle", Flag = "CoolToggle", Description = "Hover any setting with a Description to see an explanation like this one.",
	Callback = function(v) print("Cool Toggle:", v) end })
Aimbot:AddToggle({ Text = "Cool Selected Toggle", Default = true })
Aimbot:AddToggle({ Text = "Aimbot", Disabled = true, Description = "Disabled elements are dimmed and can't be clicked." })
Aimbot:AddToggle({ Text = "Cool Toggle" }):AddKeybind({ Default = Enum.KeyCode.Insert, Mode = "Toggle", Name = "Cool Toggle" })
Aimbot:AddToggle({ Text = "Cool Toggle With a Tooltip", Tooltip = "Hover the ? chip to see this" })
local colors = Aimbot:AddToggle({ Text = "Cool Toggle With Colors", Flag = "CoolColors" })
colors:AddColorPicker({ Default = Color3.fromRGB(158, 224, 151), Flag = "ColorA" })
colors:AddColorPicker({ Default = Color3.fromRGB(120, 230, 170), Flag = "ColorB" })
Aimbot:AddToggle({ Text = "Risky Toggle", Risky = true, Description = "Risky = true tints the label red, for features users should think twice about." })
Aimbot:AddSlider({ Text = "Cool Slider", Min = 0, Max = 300, Default = 300, Flag = "CoolSlider", Description = "Drag it, or click the number to type an exact value." })
Aimbot:AddDropdown({ Text = "Cool Dropdown", Values = { "One", "Two", "Three" }, Flag = "CoolDrop" })
Aimbot:AddViewport({ Height = 150, Character = true })   -- your avatar; drag to orbit, auto-rotates when released
Aimbot:AddButton({ Text = "Button", Callback = function() Lumen:Notify("test notif") end })
	:AddSubButton({ Text = "Sub-button", Callback = function() Lumen:Notify("Sub-button pressed") end })

FOV:AddDropdown({ Text = "Multi Dropdown", Values = { "Red", "Green", "Blue", "Yellow" }, Multi = true, Default = { "Red" }, Flag = "MultiDrop" })
FOV:AddDropdown({ Text = "Searchable Dropdown", Flag = "Weapon", Description = "Lists longer than 8 entries get a search box automatically.",
	Values = { "Pistol", "Revolver", "Shotgun", "SMG", "Rifle", "Sniper", "Bow", "Crossbow", "Knife", "Katana", "Spear", "Hammer" } })
Prediction:AddProgress({ Text = "Progress bar", Default = 64, Description = "Animated progress bar. Call :Set(value) or :Increment(n)." })
Prediction:AddParagraph({ Title = "Paragraph", Content = "A titled block of wrapping text for instructions, changelogs or status." })

local Quick = Combat:AddGroup({ Title = "Quick Actions", Icon = "command", Side = "Left" })
Quick:AddLabel("Standalone keybind (hold)"):AddKeybind({ Default = Enum.KeyCode.X, Mode = "Hold", Name = "Quick Action", Flag = "QuickKey" })
Quick:AddLabel("Always on"):AddKeybind({ Mode = "Always", Name = "Always Active" })

local RightBox = Combat:AddTabbox("Right")
local Silent, Range, Pred2 = RightBox:AddTab("Silent Aim"), RightBox:AddTab("FOV"), RightBox:AddTab("Prediction")
Silent:AddToggle({ Text = "Silent Aim", Flag = "Silent", Disabled = true })
Silent:AddToggle({ Text = "Cool Toggle With Colors" }):AddColorPicker({ Default = Color3.fromRGB(255, 170, 255) })
Silent:AddLabel("I'm a basic label")
Silent:AddSlider({ Text = "Cool Slider", Min = 0, Max = 8000, Default = 8000, Suffix = " km/100", Increment = 10, Flag = "Speed" })
Silent:AddLabel("Label with text in it so coolLabel with text in it so coolLabel with text in it so coolLabel with text in it so cool")
Silent:AddInput({ Text = "Cool Input", Placeholder = "Dynamic Input (textbox)", Flag = "Input", Callback = function(v) print("Input:", v) end })
Silent:AddInput({ Text = "Dynamic Input", Placeholder = "Type here, it grows as you type (Enter to submit)", Dynamic = true, Flag = "DynInput" })
Silent:AddViewport({ Height = 150 })                  -- default: a gray block
Silent:AddButton({ Text = "Button" }):AddSubButton({ Text = "Sub-button", Callback = function() Lumen:Notify("Sub-button pressed") end })
Range:AddLabel("Empty sub-tabs simply show nothing.", { Dim = true })

local Tests = Combat:AddGroup({ Title = "Notifications", Icon = "command", Side = "Right" })
Tests:AddButton({ Text = "Success", Callback = function()
	Lumen:Notify({ Title = "Success", Content = "Settings applied and saved.", Type = "Success" })
end }):AddSubButton({ Text = "Warning", Callback = function()
	Lumen:Notify({ Title = "Warning", Content = "This feature can be unstable in some games.", Type = "Warning" })
end })
Tests:AddButton({ Text = "Error", Callback = function()
	Lumen:Notify({ Title = "Error", Content = "Couldn't reach the server. Try again in a moment.", Type = "Error" })
end }):AddSubButton({ Text = "Info", Callback = function()
	Lumen:Notify({ Title = "Info", Content = "Press Ctrl+K to search everything, Ctrl+Tab to switch tabs.", Type = "Info" })
end })
Tests:AddButton({ Text = "Loading -> Done", Callback = function()
	local n = Lumen:Notify({ Title = "Injecting", Content = "Preparing features...", Type = "Loading" })
	task.delay(2, function() n:Update({ Title = "Ready", Content = "Everything loaded.", Type = "Success" }) end)
end }):AddSubButton({ Text = "With buttons", Callback = function()
	Lumen:Notify({ Title = "Update available", Content = "Version 0.0.3 is out.", Type = "Info", Duration = 8,
		Actions = { { Text = "Changelog", Callback = function() Lumen:Notify("Opening changelog...") end }, { Text = "Later" } } })
end })
Tests:AddButton({
	Text = "Reset Everything",
	Description = "A button that asks first: hold the confirm button for a second.",
	Confirm = { Title = "Reset everything?", Text = "All toggles and sliders go back to their defaults. This can't be undone.",
		Type = "Danger", Confirm = "Reset", Hold = 1 },
	Callback = function() Lumen:Notify({ Title = "Reset", Content = "Everything was reset.", Type = "Success" }) end,
})

------------------------------------------------------------------ Visuals: ESP preview controls, camera, fullbright
local Visuals = Window:AddTab("Visuals")
local espPanel = Lumen:CreatePanel({
	Title = "ESP Preview", Width = 250, Position = UDim2.new(1, -790, 0.5, -90),
	Dock = { Icon = "scan", Tooltip = "ESP Preview", Order = 20 },
})
local esp = espPanel:AddViewport({ Height = 320, Character = true, Color = Color3.fromRGB(58, 58, 62),
	ESP = { Box = "Corner", Name = true, Health = 0.85, Distance = true } })

local EspGroup = Visuals:AddGroup({ Title = "ESP Preview", Icon = "scan", Side = "Left" })
EspGroup:AddParagraph({ Content = "These controls drive the ESP Preview panel live, so you can see how the overlay looks before using it." })
EspGroup:AddToggle({ Text = "Show preview panel", Default = true, Callback = function(v) espPanel:SetVisible(v) end })
EspGroup:AddInput({ Text = "Name tag", Default = LocalPlayer and LocalPlayer.DisplayName or "Player", Realtime = true,
	Callback = function(v) esp:SetESP({ Name = v ~= "" and v or " " }) end })
EspGroup:AddSlider({ Text = "Health", Min = 0, Max = 100, Default = 85, Suffix = "%",
	Description = "The health bar fades from green to red as this drops.",
	Callback = function(v) esp:SetESP({ Health = v / 100 }) end })
EspGroup:AddSlider({ Text = "Distance", Min = 0, Max = 500, Default = 42, Suffix = " studs",
	Callback = function(v) esp:SetESP({ DistanceText = v .. " studs" }) end })

local CameraGroup = Visuals:AddGroup({ Title = "Camera", Side = "Right" })
local camera = workspace.CurrentCamera
local baseFov = camera and camera.FieldOfView or 70
table.insert(Restore, function() if camera then camera.FieldOfView = baseFov end end)
CameraGroup:AddSlider({ Text = "Field of view", Min = 40, Max = 120, Default = baseFov, Suffix = "°", Flag = "Fov",
	Description = "How wide your camera sees. Higher shows more of the world at the edges.",
	Callback = function(v) if camera then camera.FieldOfView = v end end })
CameraGroup:AddButton({ Text = "Reset field of view", Callback = function()
	if camera then camera.FieldOfView = baseFov end
	Lumen:SetFlag("Fov", baseFov)
end })

local LightGroup = Visuals:AddGroup({ Title = "Lighting", Side = "Right" })
local saved = {
	Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
	ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
}
local function RestoreLighting() for k, v in pairs(saved) do pcall(function() Lighting[k] = v end) end end
table.insert(Restore, RestoreLighting)
LightGroup:AddToggle({ Text = "Fullbright", Flag = "Fullbright",
	Description = "Lights the whole map evenly so dark areas are visible. Turning it off restores the game's own lighting.",
	Callback = function(v)
		if v then
			Lighting.Brightness = 2
			Lighting.Ambient = Color3.new(1, 1, 1)
			Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
			Lighting.GlobalShadows = false
		else
			for _, k in ipairs({ "Brightness", "Ambient", "OutdoorAmbient", "GlobalShadows" }) do pcall(function() Lighting[k] = saved[k] end) end
		end
	end })

------------------------------------------------------------------ World: time of day, fog
local World = Window:AddTab("World")
local TimeGroup = World:AddGroup({ Title = "Time", Side = "Left" })
local lockTime = false
TimeGroup:AddSlider({ Text = "Time of day", Min = 0, Max = 24, Increment = 0.25, Default = saved.ClockTime or 14, Suffix = "h", Flag = "ClockTime",
	Description = "Changes the time on your screen only. Other players are not affected.",
	Callback = function(v) Lighting.ClockTime = v end })
TimeGroup:AddToggle({ Text = "Lock time", Description = "Keeps the time where you set it, even if the game tries to change it.",
	Callback = function(v) lockTime = v end })
task.spawn(function()
	while not Lumen.Unloaded do
		if lockTime and Lumen.Flags.ClockTime then Lighting.ClockTime = Lumen.Flags.ClockTime end
		task.wait(0.5)
	end
end)
local FogGroup = World:AddGroup({ Title = "Atmosphere", Side = "Right" })
FogGroup:AddToggle({ Text = "Remove fog", Description = "Pushes the fog far away so you can see across the whole map.",
	Callback = function(v) Lighting.FogEnd = v and 1e6 or saved.FogEnd end })
FogGroup:AddSlider({ Text = "Brightness", Min = 0, Max = 5, Increment = 0.1, Default = saved.Brightness or 2,
	Callback = function(v) Lighting.Brightness = v end })
FogGroup:AddButton({ Text = "Restore game lighting", Callback = function()
	RestoreLighting()
	Lumen:Notify({ Title = "Lighting", Content = "Restored the game's original lighting.", Type = "Success" })
end })

------------------------------------------------------------------ Character
local Character = Window:AddTab("Character")
local AvatarGroup = Character:AddGroup({ Title = "Avatar", Icon = "user", Side = "Left" })
local avatar = AvatarGroup:AddViewport({ Height = 260, Character = true })
AvatarGroup:AddButton({ Text = "Refresh preview", Description = "Re-captures your current outfit.", Callback = function()
	local ch = LocalPlayer and LocalPlayer.Character
	if ch then
		ch.Archivable = true
		avatar:SetObject(ch:Clone())
	end
end })
local InfoGroup = Character:AddGroup({ Title = "Account", Side = "Right" })
InfoGroup:AddParagraph({ Title = LocalPlayer and LocalPlayer.DisplayName or "Player",
	Content = string.format("@%s\nUser ID: %s\nAccount age: %s days", tostring(LocalPlayer and LocalPlayer.Name),
		tostring(LocalPlayer and LocalPlayer.UserId), tostring(LocalPlayer and LocalPlayer.AccountAge)) })
InfoGroup:AddButton({ Text = "Copy username", Callback = function()
	if Lumen:Clipboard(LocalPlayer.Name) then Lumen:Notify({ Content = "Username copied.", Type = "Success" })
	else Lumen:Notify({ Content = "Your executor can't copy to the clipboard.", Type = "Warning" }) end
end })
InfoGroup:AddButton({ Text = "Reset character", Description = "Respawns your character, like the reset button in the Roblox menu.",
	Confirm = { Title = "Reset character?", Text = "Your character will respawn.", Type = "Warning", Confirm = "Reset" },
	Callback = function()
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.Health = 0 end
	end })

------------------------------------------------------------------ Exploits (reference tab name): players and server tools
local Exploits = Window:AddTab("Exploits")
local PlayersGroup = Exploits:AddGroup({ Title = "Players", Icon = "user", Side = "Left" })
local target = PlayersGroup:AddPlayerDropdown({ Text = "Player", Flag = "Target",
	Description = "Every player in the server. The list updates by itself as people join and leave." })
local spectating = false
local function Spectate(p)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local hum = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	local mine = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	cam.CameraSubject = hum or mine
end
table.insert(Restore, function() Spectate(nil) end)
PlayersGroup:AddToggle({ Text = "Spectate", Flag = "Spectate", Description = "Points your camera at the selected player. Turn off to come back.",
	Callback = function(v)
		spectating = v
		Spectate(v and target:GetPlayer() or nil)
	end })
target:OnChanged(function() if spectating then Spectate(target:GetPlayer()) end end)
PlayersGroup:AddButton({ Text = "Copy their username", Callback = function()
	local p = target:GetPlayer()
	if p and Lumen:Clipboard(p.Name) then Lumen:Notify({ Content = "Copied @" .. p.Name, Type = "Success" }) end
end })

local ServerGroup = Exploits:AddGroup({ Title = "Server", Side = "Right" })
local serverInfo = ServerGroup:AddParagraph({ Title = "This server", Content = "..." })
local fill = ServerGroup:AddProgress({ Text = "Players", Max = Players.MaxPlayers or 1, Suffix = " players" })
local function UpdateServer()
	local count = #Players:GetPlayers()
	serverInfo:SetContent(string.format("Place ID: %s\nJob ID: %s", tostring(game.PlaceId), tostring(game.JobId)))
	fill:Set(count)
end
UpdateServer()
Players.PlayerAdded:Connect(UpdateServer)
Players.PlayerRemoving:Connect(function() task.defer(UpdateServer) end)
ServerGroup:AddButton({ Text = "Copy Job ID", Callback = function()
	if Lumen:Clipboard(game.JobId) then Lumen:Notify({ Content = "Job ID copied.", Type = "Success" }) end
end }):AddSubButton({ Text = "Copy join script", Description = "A one-line script that joins this exact server.", Callback = function()
	local line = string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%s, "%s")', tostring(game.PlaceId), tostring(game.JobId))
	if Lumen:Clipboard(line) then Lumen:Notify({ Content = "Join script copied.", Type = "Success" }) end
end })
ServerGroup:AddButton({ Text = "Rejoin", Description = "Leaves and rejoins this same server.",
	Confirm = { Title = "Rejoin this server?", Text = "You'll be teleported back into the same server.", Type = "Info", Confirm = "Rejoin" },
	Callback = function()
		local n = Lumen:Notify({ Title = "Rejoining", Content = "Teleporting...", Type = "Loading" })
		local ok, err = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
		if not ok then n:Update({ Title = "Rejoin failed", Content = tostring(err), Type = "Error" }) end
	end })

------------------------------------------------------------------ Webhook: send a Discord message through the executor's HTTP
local Webhook = Window:AddTab("Webhook")
local HookGroup = Webhook:AddGroup({ Title = "Discord webhook", Side = "Left" })
HookGroup:AddParagraph({ Content = "Paste a webhook URL from Discord (Server Settings > Integrations > Webhooks). Needs an executor with an HTTP request function." })
local url = HookGroup:AddInput({ Text = "Webhook URL", Placeholder = "https://discord.com/api/webhooks/...", Flag = "WebhookUrl" })
local message = HookGroup:AddInput({ Text = "Message", Placeholder = "Hello from Lumen!", Dynamic = true, Flag = "WebhookMessage" })
local embedColor
HookGroup:AddLabel("Embed colour"):AddColorPicker({ Default = Color3.fromRGB(159, 150, 193), Flag = "WebhookColor",
	Callback = function(c) embedColor = c end })
HookGroup:AddButton({ Text = "Send test message", Callback = function()
	local u = url.Value
	if not (u:match("^https://discord%.com/api/webhooks/") or u:match("^https://discordapp%.com/api/webhooks/")) then
		Lumen:Notify({ Title = "Webhook", Content = "That doesn't look like a Discord webhook URL.", Type = "Warning" })
		return
	end
	local c = embedColor or Color3.fromRGB(159, 150, 193)
	local body = HttpService:JSONEncode({
		username = "Lumen",
		embeds = { {
			title = "Test from " .. tostring(LocalPlayer.Name),
			description = message.Value ~= "" and message.Value or "Hello from Lumen!",
			color = math.floor(c.R * 255) * 65536 + math.floor(c.G * 255) * 256 + math.floor(c.B * 255),
		} },
	})
	local n = Lumen:Notify({ Title = "Webhook", Content = "Sending...", Type = "Loading" })
	task.spawn(function()
		local res, err = Lumen:Request({ Url = u, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
		local code = res and (res.StatusCode or res.status_code)
		if code and code >= 200 and code < 300 then
			n:Update({ Title = "Webhook", Content = "Message delivered.", Type = "Success" })
		else
			n:Update({ Title = "Webhook failed", Content = err or ("Discord answered " .. tostring(code)), Type = "Error" })
		end
	end)
end })

------------------------------------------------------------------ About + Config
local About = Window:AddTab("About")
About:AddGroup("Credits", "Left"):AddCredits({
	{ Name = "@developer", Role = "Owner/Developer", RoleColor = Color3.fromRGB(80, 159, 119), Description = "Founder and developer." },
	{ Name = "@tester", Role = "Owner/Tester", RoleColor = Color3.fromRGB(168, 128, 82), Description = "Co-founder." },
})
About:AddGroup("Contributors", "Right"):AddCredits({
	{ Name = "@helper", Role = "Contributor » Bug fixing", RoleColor = Color3.fromRGB(159, 88, 88), Description = "Lorem ipsum dolor sit amet." },
	{ Name = "@designer", Role = "Contributor » Lorem ipsum", RoleColor = Color3.fromRGB(80, 158, 237), Description = "Lorem ipsum dolor sit amet." },
})

Window:AddConfigTab("Config")   -- menu, effects, layout toggles, theme editor, tests, configs: all adjustable in the UI

------------------------------------------------------------ Floating panels from the reference
local skins = Lumen:CreatePanel({ Title = "Skin Changer", Width = 440, Position = UDim2.new(1, -490, 0, 96) })
local items = {}
for i = 1, 12 do
	items[i] = { Image = "rbxthumb://type=AvatarHeadShot&id=" .. i .. "&w=150&h=150" }
end
skins:AddImageGrid({ Items = items, Columns = 4, CellHeight = 82, Callback = function() Lumen:Notify("Skin selected") end })

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

Lumen:Notify("test notif")
Lumen:Notify("test notif")
Lumen:Notify({ Title = "Loaded", Content = "Lumen " .. Lumen.Version .. " is ready. RightShift hides the menu, Ctrl+K searches.", Type = "Success" })

Lumen:LoadAutoload()
