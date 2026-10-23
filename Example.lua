--[[
	TingUI example: every element, the reference layout, and real Roblox features wired to the controls.
	Everything here runs client-side and is restored when the UI is unloaded.
]]

-- Options can be passed straight into the loadstring call. Id keeps this script's UI separate from other scripts using TingUI.
local TingUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/TingUI.lua"))({
	Id = "TingUIExample",
	Folder = "TingUIExample",
	-- Theme = "Hologram",        -- start in any theme: Lavender (default), Ocean, Rose, Sunset, Mono, Frost, Royal,
	--                               Cosmos, Storm, Blueprint, Hazard, Glass, Hologram, Circuit, Serotonin
	-- AssetBase = "https://your.host/icons/",   -- optional: where the high-res icon PNGs live (defaults to this repo)
	-- Shell = { Name = "Example Hub" },          -- how this script shows up when other TingUI scripts share the screen
})

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local Window = TingUI:CreateWindow({
	Title = "TingUI Interface Suite",
	Tag = "Pro",                         -- green pill
	Version = "v0.0.9",                  -- red pill
	Subtitle = "Example Game",
	Footer = "discord.gg/yourserver",
	WatermarkTitle = "TingUI V2",
	MenuKey = Enum.KeyCode.RightShift,
	Snow = { Count = 70, Speed = 1 },    -- particles follow the theme
	Backdrop = { Dim = 0.5, Blur = 8 },  -- dimmed + blurred world behind the UI
	Dock = { "menu", "hotkeys", "notifications", "palette" },   -- the bell opens the notification history
})

-- Anything the script changes in the game is put back when the UI unloads.
local Restore = {}
local skins -- the Skin Changer panel, created at the bottom (declared here so buttons anywhere can open it)
TingUI.Events.Unloading:Connect(function()
	for _, fn in ipairs(Restore) do pcall(fn) end
end)

-- The ESP Preview panel is created up front so controls in any tab can drive it.
-- Visible = false: only the main window shows on first run. Open it from the dock (scan icon) or the Visuals tab.
local espPanel = TingUI:CreatePanel({
	Title = "ESP Preview", Width = 250, Position = UDim2.new(1, -790, 0.5, -90), Visible = false,
	Dock = { Icon = "scan", Tooltip = "ESP Preview", Order = 20 },
})
local esp = espPanel:AddViewport({ Height = 320, Character = true, Color = Color3.fromRGB(58, 58, 62),
	ESP = { Box = "Corner", Name = true, Health = 0.85, Distance = true },
	-- a Roblox-style Highlight: tinted fill plus an outline around the character's silhouette
	Highlight = { Enabled = false, Fill = Color3.fromRGB(158, 224, 151), FillTransparency = 0.55, Outline = Color3.fromRGB(120, 230, 170), Thickness = 2 } })

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
-- A toggle with colour pickers attached: the swatches on the right open a picker. In this example it
-- switches on the character highlight in the ESP Preview; swatch 1 is the fill, swatch 2 the outline.
local colors = Aimbot:AddToggle({ Text = "Cool Toggle With Colors", Flag = "CoolColors",
	Description = "A toggle with colour swatches attached. Click a swatch to pick a colour. Here it turns on the character highlight in the ESP Preview: the first swatch is the fill, the second the outline.",
	Callback = function(v) TingUI:SetFlag("EspHighlight", v) end })
colors:AddColorPicker({ Default = Color3.fromRGB(158, 224, 151), Flag = "ColorA", Callback = function(c) esp:SetHighlight({ Fill = c }) end })
colors:AddColorPicker({ Default = Color3.fromRGB(120, 230, 170), Flag = "ColorB", Callback = function(c) esp:SetHighlight({ Outline = c }) end })
Aimbot:AddToggle({ Text = "Risky Toggle", Risky = true, Description = "Risky = true tints the label red, for features users should think twice about." })
Aimbot:AddSlider({ Text = "Cool Slider", Min = 0, Max = 300, Default = 300, Flag = "CoolSlider", Description = "Drag it, or click the number to type an exact value." })
Aimbot:AddDropdown({ Text = "Cool Dropdown", Values = { "One", "Two", "Three" }, Flag = "CoolDrop" })
Aimbot:AddViewport({ Height = 150, Character = true })   -- your avatar; drag to orbit, auto-rotates when released
Aimbot:AddButton({ Text = "Button", Callback = function() TingUI:Notify("test notif") end })
	:AddSubButton({ Text = "Sub-button", Callback = function() TingUI:Notify("Sub-button pressed") end })

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
Silent:AddToggle({ Text = "Cool Toggle With Colors", Flag = "EspTint",
	Description = "Same idea: a toggle with a colour swatch. Turn it on to colour the ESP box, name and distance in the ESP Preview with the swatch colour.",
	Callback = function(v)
		esp:SetESP({ Color = v and (TingUI.Flags.EspTintColor or Color3.fromRGB(255, 170, 255)) or Color3.new(1, 1, 1) })
		if v then espPanel:SetVisible(true) end
	end }):AddColorPicker({ Default = Color3.fromRGB(255, 170, 255), Flag = "EspTintColor",
	Callback = function(c) if TingUI.Flags.EspTint then esp:SetESP({ Color = c }) end end })
Silent:AddLabel("I'm a basic label")
Silent:AddSlider({ Text = "Cool Slider", Min = 0, Max = 8000, Default = 8000, Suffix = " km/100", Increment = 10, Flag = "Speed" })
Silent:AddLabel("Label with text in it so coolLabel with text in it so coolLabel with text in it so coolLabel with text in it so cool")
Silent:AddInput({ Text = "Cool Input", Placeholder = "Dynamic Input (textbox)", Flag = "Input", Callback = function(v) print("Input:", v) end })
Silent:AddInput({ Text = "Dynamic Input", Placeholder = "Type here, it grows as you type (Enter to submit)", Dynamic = true, Flag = "DynInput" })
Silent:AddViewport({ Height = 150 })                  -- default: a gray block
Silent:AddButton({ Text = "Button" }):AddSubButton({ Text = "Sub-button", Callback = function() TingUI:Notify("Sub-button pressed") end })
Range:AddLabel("Empty sub-tabs simply show nothing.", { Dim = true })

local Tests = Combat:AddGroup({ Title = "Notifications", Icon = "command", Side = "Right" })
Tests:AddButton({ Text = "Success", Callback = function()
	TingUI:Notify({ Title = "Success", Content = "Settings applied and saved.", Type = "Success" })
end }):AddSubButton({ Text = "Warning", Callback = function()
	TingUI:Notify({ Title = "Warning", Content = "This feature can be unstable in some games.", Type = "Warning" })
end })
Tests:AddButton({ Text = "Error", Callback = function()
	TingUI:Notify({ Title = "Error", Content = "Couldn't reach the server. Try again in a moment.", Type = "Error" })
end }):AddSubButton({ Text = "Info", Callback = function()
	TingUI:Notify({ Title = "Info", Content = "Press Ctrl+K to search everything, Ctrl+Tab to switch tabs.", Type = "Info" })
end })
Tests:AddButton({ Text = "Loading -> Done", Callback = function()
	local n = TingUI:Notify({ Title = "Injecting", Content = "Preparing features...", Type = "Loading" })
	task.delay(2, function() n:Update({ Title = "Ready", Content = "Everything loaded.", Type = "Success" }) end)
end }):AddSubButton({ Text = "With buttons", Callback = function()
	TingUI:Notify({ Title = "Update available", Content = "Version 0.0.9 is out.", Type = "Info", Duration = 8,
		Actions = { { Text = "Changelog", Callback = function() TingUI:Notify("Opening changelog...") end }, { Text = "Later" } } })
end })
-- richer notifications: progress, replies, undo, details, merging, and a type for each kind of event
Tests:AddButton({ Text = "Download", Description = "A live progress bar; the arrow keeps dropping into the tray until it's done, then it turns into a success.", Callback = function()
	local n = TingUI:Notify({ Title = "Downloading", Content = "skins.pak  0 / 18 MB", Type = "Download", Value = 0 })
	task.spawn(function()
		for i = 1, 18 do
			task.wait(0.15)
			if n.Closed then return end
			n:SetProgress(i / 18, string.format("skins.pak  %d / 18 MB", i))
		end
		n:Update({ Title = "Downloaded", Content = "18 new skins are ready.", Type = "Success", Value = 1, Duration = 4,
			Actions = { { Text = "Open", Style = "Primary", Callback = function() if skins then skins:SetVisible(true) end end } } })
	end)
end }):AddSubButton({ Text = "Reply", Description = "Answer straight from the card. Typing pauses its timer.", Callback = function()
	TingUI:Notify({ Title = "builderman", Content = "gg, want to run it back?", Type = "Message",
		Input = { Placeholder = "Reply...", Button = "Send", Callback = function(text)
			TingUI:Notify({ Title = "Sent", Content = text, Type = "Success" })
		end } })
end })
Tests:AddButton({ Text = "Undo", Description = "An action you can take back while the Undo button counts down.", Callback = function()
	TingUI:Notify({ Title = "Waypoint removed", Content = "\"Spawn\" was deleted.", Type = "Warning",
		Undo = function() TingUI:Notify({ Content = "\"Spawn\" is back.", Type = "Success" }) end,
		OnCommit = function() print("waypoint deleted for good") end })
end }):AddSubButton({ Text = "Details", Description = "An error with the technical part tucked away, plus a copy button.", Callback = function()
	TingUI:Notify({ Title = "Request failed", Content = "The server answered 503.", Type = "Error", Duration = 10,
		Details = "POST /api/v1/sync\nstatus: 503 Service Unavailable\nretry-after: 30\nrequest-id: 7f3c-91aa-02de",
		Copy = "request-id: 7f3c-91aa-02de" })
end })
Tests:AddButton({ Text = "Friend request", Description = "A picture instead of the badge, with Accept / Ignore.", Callback = function()
	local id = LocalPlayer and LocalPlayer.UserId or 1
	TingUI:Notify({ Title = "Friend request", Content = "Someone wants to be friends.", Type = "Friend", Duration = 10,
		Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(id) .. "&w=150&h=150",
		Actions = { { Text = "Accept", Style = "Primary", Callback = function() TingUI:Notify({ Content = "Friends now.", Type = "Heart" }) end }, { Text = "Ignore" } } })
end }):AddSubButton({ Text = "Achievement", Description = "Gold, a spin-in star, sparks and a double shine.", Callback = function()
	TingUI:Notify({ Title = "Achievement unlocked", Content = "Tried every notification.", Type = "Achievement", Duration = 6 })
end })
Tests:AddButton({ Text = "Merge x3", Description = "The same notification three times becomes one card with a counter.", Callback = function()
	for i = 1, 3 do task.delay((i - 1) * 0.4, function() TingUI:Notify({ Title = "Player joined", Content = "The server is filling up.", Type = "Friend" }) end) end
end }):AddSubButton({ Text = "Security", Description = "Two choices, one of them marked as dangerous.", Callback = function()
	TingUI:Notify({ Title = "New login", Content = "Your account was used on a new device.", Type = "Security", Duration = 10,
		Actions = { { Text = "It was me", Style = "Primary" }, { Text = "Secure it", Style = "Danger", Callback = function() TingUI:Notify({ Content = "Signed out everywhere else.", Type = "Success" }) end } } })
end })
Tests:AddButton({ Text = "Pinned", Description = "Never times out. Hover any card for the pin and close buttons; drag one sideways to fling it away.", Callback = function()
	TingUI:Notify({ Title = "Server restarting", Content = "In 5 minutes. This stays until you close it.", Type = "Update", Persistent = true })
end }):AddSubButton({ Text = "History", Description = "Every notification so far, newest first (also the bell in the dock).", Callback = function()
	TingUI:OpenNotificationCenter()
end })
-- game events: each type has its own animated badge (twenty of them; see docs/elements.md for the full list)
local function Pair(a, b)
	Tests:AddButton({ Text = a[1], Description = a[2], Callback = a[3] }):AddSubButton({ Text = b[1], Description = b[2], Callback = b[3] })
end
local function Run(n, finish)
	task.spawn(function()
		for i = 1, 10 do
			task.wait(0.2)
			if n.Closed then return end
			n:SetProgress(i / 10)
		end
		n:Update(finish)
	end)
end
Pair({ "Teleport", "The pin drops onto its spot and pings it.", function()
	TingUI:Notify({ Title = "Teleported", Content = "Moved to the safe zone.", Type = "Teleport" })
end }, { "Server hop", "The globe spins and a dot hops round it while it searches.", function()
	Run(TingUI:Notify({ Title = "Server hop", Content = "Looking for a quieter server...", Type = "ServerHop", Value = 0 }),
		{ Title = "Server found", Content = "9 / 30 players. Joining...", Type = "ServerHop", Value = 1, Duration = 4 })
end })
Pair({ "Reward", "The box shakes, pops open and throws confetti.", function()
	TingUI:Notify({ Title = "Daily reward", Content = "You got 3 crates.", Type = "Reward", Actions = { { Text = "Open", Style = "Primary" } } })
end }, { "Currency", "The coin flips three times and glints.", function()
	TingUI:Notify({ Title = "+250 coins", Content = "Balance: 4,180.", Type = "Currency" })
end })
Pair({ "Level up", "The trophy rises while chevrons climb past it.", function()
	TingUI:Notify({ Title = "Level 24", Content = "1,450 / 12,000 XP to the next one.", Type = "LevelUp", Value = 0.12, Duration = 5 })
end }, { "Timer", "A stopwatch hand sweeps; it ticks every second.", function()
	TingUI:Notify({ Title = "Boss in 30 seconds", Content = "Head to the arena.", Type = "Timer", Duration = 8 })
end })
Pair({ "Connection", "The signal bars light one by one, then hold.", function()
	Run(TingUI:Notify({ Title = "Reconnecting", Content = "The connection dropped. Trying again...", Type = "Connection", Value = 0 }),
		{ Title = "Connected", Content = "Ping 48 ms.", Type = "Connection", Value = 1, Duration = 4 })
end }, { "Target", "Brackets close in and lock on.", function()
	TingUI:Notify({ Title = "Target locked", Content = "Nearest player, 42 studs away.", Type = "Target" })
end })
Pair({ "Invite", "The envelope slides in and an unread dot pops on.", function()
	TingUI:Notify({ Title = "Party invite", Content = "builderman invited you to their party.", Type = "Invite", Duration = 10,
		Actions = { { Text = "Join", Style = "Primary" }, { Text = "Decline" } } })
end }, { "Streak", "The flame flickers and throws off embers.", function()
	TingUI:Notify({ Title = "5-day streak", Content = "Come back tomorrow to keep it going.", Type = "Streak", Duration = 6 })
end })
Pair({ "Boost", "The rocket rumbles, launches and comes back round.", function()
	TingUI:Notify({ Title = "Speed boost", Content = "x2 walk speed for 60 seconds.", Type = "Boost" })
end }, { "Protected", "The shield slams in and a dome hums round it.", function()
	TingUI:Notify({ Title = "Spawn protection", Content = "You can't be damaged for 10 seconds.", Type = "Protected" })
end })
Pair({ "Key", "The key turns in the lock and clicks.", function()
	TingUI:Notify({ Title = "Key accepted", Content = "Premium features unlocked.", Type = "Key" })
end }, { "Party", "The group hops and members pop in around it.", function()
	TingUI:Notify({ Title = "Party ready", Content = "4 / 4 players joined.", Type = "Party" })
end })
Pair({ "MVP", "The crown drops on with a bounce and glints.", function()
	TingUI:Notify({ Title = "MVP", Content = "Most eliminations this round.", Type = "MVP", Duration = 6 })
end }, { "Combat", "The sword swings, a slash crosses the badge, the card jolts.", function()
	TingUI:Notify({ Title = "Under attack", Content = "You took 35 damage from behind.", Type = "Combat" })
end })
Pair({ "Copied", "A second copy peels off and settles beside it.", function()
	TingUI:Notify({ Title = "Copied", Content = "Job ID copied to the clipboard.", Type = "Copied" })
end }, { "Deleted", "Something drops into the bin; Undo puts it back.", function()
	TingUI:Notify({ Title = "Waypoint deleted", Content = "\"Spawn\" was removed.", Type = "Deleted",
		Undo = function() TingUI:Notify({ Content = "\"Spawn\" is back.", Type = "Success" }) end })
end })
Pair({ "Sync", "Spins while it works, then eases to a stop.", function()
	Run(TingUI:Notify({ Title = "Syncing", Content = "Saving your config...", Type = "Sync", Value = 0 }),
		{ Title = "Synced", Content = "Everything is saved.", Type = "Sync", Value = 1, Duration = 4 })
end }, { "AFK", "The moon rocks and little z's drift up.", function()
	TingUI:Notify({ Title = "AFK detected", Content = "You'll be kicked in 2 minutes. Move to stay.", Type = "AFK", Duration = 8,
		Actions = { { Text = "I'm here", Style = "Primary" } } })
end })
Tests:AddButton({
	Text = "Reset Everything",
	Description = "A button that asks first: hold the confirm button for a second.",
	Confirm = { Title = "Reset everything?", Text = "All toggles and sliders go back to their defaults. This can't be undone.",
		Type = "Danger", Confirm = "Reset", Hold = 1 },
	Callback = function() TingUI:Notify({ Title = "Reset", Content = "Everything was reset.", Type = "Success" }) end,
})

------------------------------------------------------------------ Visuals: ESP preview, highlight, panels, camera
local Visuals = Window:AddTab("Visuals")

local EspGroup = Visuals:AddGroup({ Title = "ESP Preview", Icon = "scan", Side = "Left" })
EspGroup:AddParagraph({ Content = "These controls drive the ESP Preview panel live, so you can see how the overlay looks before using it." })
local showPanel = EspGroup:AddToggle({ Text = "Show preview panel", Description = "Opens the floating ESP Preview. The scan icon in the dock does the same.",
	Callback = function(v) espPanel:SetVisible(v) end })
EspGroup:AddInput({ Text = "Name tag", Default = LocalPlayer and LocalPlayer.DisplayName or "Player", Realtime = true,
	Callback = function(v) esp:SetESP({ Name = v ~= "" and v or " " }) end })
EspGroup:AddSlider({ Text = "Health", Min = 0, Max = 100, Default = 85, Suffix = "%",
	Description = "The health bar fades from green to red as this drops.",
	Callback = function(v) esp:SetESP({ Health = v / 100 }) end })
EspGroup:AddSlider({ Text = "Distance", Min = 0, Max = 500, Default = 42, Suffix = " studs",
	Callback = function(v) esp:SetESP({ DistanceText = v .. " studs" }) end })

local HighlightGroup = Visuals:AddGroup({ Title = "Highlight", Icon = "eye", Side = "Left" })
HighlightGroup:AddToggle({ Text = "Character highlight", Flag = "EspHighlight",
	Description = "Outlines and tints the character in the ESP Preview, like Roblox's Highlight instance.",
	Callback = function(v)
		esp:SetHighlight({ Enabled = v })
		if v then espPanel:SetVisible(true) showPanel:Set(true) end
	end })
	:AddColorPicker({ Default = Color3.fromRGB(158, 224, 151), Flag = "HighlightFill", Callback = function(c) esp:SetHighlight({ Fill = c }) end })
HighlightGroup:AddLabel("Outline colour"):AddColorPicker({ Default = Color3.fromRGB(120, 230, 170), Flag = "HighlightOutline",
	Callback = function(c) esp:SetHighlight({ Outline = c }) end })
HighlightGroup:AddSlider({ Text = "Fill opacity", Min = 0, Max = 100, Default = 45, Suffix = "%",
	Description = "How strongly the fill colour covers the character. 0% shows only the outline.",
	Callback = function(v) esp:SetHighlight({ FillTransparency = 1 - v / 100 }) end })
HighlightGroup:AddSlider({ Text = "Outline thickness", Min = 1, Max = 4, Default = 2, Suffix = " px",
	Callback = function(v) esp:SetHighlight({ Thickness = v }) end })

-- (skins, the Skin Changer panel, is declared at the top and created at the bottom)
local PanelsGroup = Visuals:AddGroup({ Title = "Panels", Icon = "window", Side = "Right" })
PanelsGroup:AddParagraph({ Content = "Extra floating windows stay hidden on first run. Open them here, from the dock, or from Config > Layout." })
PanelsGroup:AddButton({ Text = "Skin Changer", Callback = function() if skins then skins:Toggle() end end })
	:AddSubButton({ Text = "ESP Preview", Callback = function() showPanel:Set(not espPanel.Frame.Visible) end })

local CameraGroup = Visuals:AddGroup({ Title = "Camera", Side = "Right" })
local camera = workspace.CurrentCamera
local baseFov = camera and camera.FieldOfView or 70
table.insert(Restore, function() if camera then camera.FieldOfView = baseFov end end)
CameraGroup:AddSlider({ Text = "Field of view", Min = 40, Max = 120, Default = baseFov, Suffix = "°", Flag = "Fov",
	Description = "How wide your camera sees. Higher shows more of the world at the edges.",
	Callback = function(v) if camera then camera.FieldOfView = v end end })
CameraGroup:AddButton({ Text = "Reset field of view", Callback = function()
	if camera then camera.FieldOfView = baseFov end
	TingUI:SetFlag("Fov", baseFov)
end })

------------------------------------------------------------------ World: lighting, time of day, fog
local World = Window:AddTab("World")
local LightGroup = World:AddGroup({ Title = "Lighting", Icon = "sparkle", Side = "Left" })
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

local TimeGroup = World:AddGroup({ Title = "Time", Side = "Left" })
local lockTime = false
TimeGroup:AddSlider({ Text = "Time of day", Min = 0, Max = 24, Increment = 0.25, Default = saved.ClockTime or 14, Suffix = "h", Flag = "ClockTime",
	Description = "Changes the time on your screen only. Other players are not affected.",
	Callback = function(v) Lighting.ClockTime = v end })
TimeGroup:AddToggle({ Text = "Lock time", Description = "Keeps the time where you set it, even if the game tries to change it.",
	Callback = function(v) lockTime = v end })
task.spawn(function()
	while not TingUI.Unloaded do
		if lockTime and TingUI.Flags.ClockTime then Lighting.ClockTime = TingUI.Flags.ClockTime end
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
	TingUI:Notify({ Title = "Lighting", Content = "Restored the game's original lighting.", Type = "Success" })
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
	if TingUI:Clipboard(LocalPlayer.Name) then TingUI:Notify({ Content = "Username copied.", Type = "Success" })
	else TingUI:Notify({ Content = "Your executor can't copy to the clipboard.", Type = "Warning" }) end
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
	if p and TingUI:Clipboard(p.Name) then TingUI:Notify({ Content = "Copied @" .. p.Name, Type = "Success" }) end
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
	if TingUI:Clipboard(game.JobId) then TingUI:Notify({ Content = "Job ID copied.", Type = "Success" }) end
end }):AddSubButton({ Text = "Copy join script", Description = "A one-line script that joins this exact server.", Callback = function()
	local line = string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%s, "%s")', tostring(game.PlaceId), tostring(game.JobId))
	if TingUI:Clipboard(line) then TingUI:Notify({ Content = "Join script copied.", Type = "Success" }) end
end })
ServerGroup:AddButton({ Text = "Rejoin", Description = "Leaves and rejoins this same server.",
	Confirm = { Title = "Rejoin this server?", Text = "You'll be teleported back into the same server.", Type = "Info", Confirm = "Rejoin" },
	Callback = function()
		local n = TingUI:Notify({ Title = "Rejoining", Content = "Teleporting...", Type = "Loading" })
		local ok, err = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
		if not ok then n:Update({ Title = "Rejoin failed", Content = tostring(err), Type = "Error" }) end
	end })

------------------------------------------------------------------ Webhook: send a Discord message through the executor's HTTP
local Webhook = Window:AddTab("Webhook")
local HookGroup = Webhook:AddGroup({ Title = "Discord webhook", Side = "Left" })
HookGroup:AddParagraph({ Content = "Paste a webhook URL from Discord (Server Settings > Integrations > Webhooks). Needs an executor with an HTTP request function." })
local url = HookGroup:AddInput({ Text = "Webhook URL", Placeholder = "https://discord.com/api/webhooks/...", Flag = "WebhookUrl" })
local message = HookGroup:AddInput({ Text = "Message", Placeholder = "Hello from TingUI!", Dynamic = true, Flag = "WebhookMessage" })
local embedColor
HookGroup:AddLabel("Embed colour"):AddColorPicker({ Default = Color3.fromRGB(159, 150, 193), Flag = "WebhookColor",
	Callback = function(c) embedColor = c end })
HookGroup:AddButton({ Text = "Send test message", Callback = function()
	local u = url.Value
	if not (u:match("^https://discord%.com/api/webhooks/") or u:match("^https://discordapp%.com/api/webhooks/")) then
		TingUI:Notify({ Title = "Webhook", Content = "That doesn't look like a Discord webhook URL.", Type = "Warning" })
		return
	end
	local c = embedColor or Color3.fromRGB(159, 150, 193)
	local body = HttpService:JSONEncode({
		username = "TingUI",
		embeds = { {
			title = "Test from " .. tostring(LocalPlayer.Name),
			description = message.Value ~= "" and message.Value or "Hello from TingUI!",
			color = math.floor(c.R * 255) * 65536 + math.floor(c.G * 255) * 256 + math.floor(c.B * 255),
		} },
	})
	local n = TingUI:Notify({ Title = "Webhook", Content = "Sending...", Type = "Loading" })
	task.spawn(function()
		local res, err = TingUI:Request({ Url = u, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
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
-- Every extra window starts hidden (Visible = false) so first run shows only the main UI.
skins = TingUI:CreatePanel({ Title = "Skin Changer", Width = 440, Position = UDim2.new(1, -490, 0, 96), Visible = false,
	Dock = { Icon = "palette", Tooltip = "Skin Changer", Order = 30 } })
local items = {}
for i = 1, 12 do
	items[i] = { Image = "rbxthumb://type=AvatarHeadShot&id=" .. i .. "&w=420&h=420" }
end
skins:AddImageGrid({ Items = items, Columns = 4, CellHeight = 82, Callback = function() TingUI:Notify("Skin selected") end })

local keySystem = TingUI:CreateKeySystem({
	Visible = false,
	Title = "Key System",
	Note = "Get your key from our Discord",
	Placeholder = "Enter your key...",
	DiscordLink = "https://discord.gg/yourserver",   -- adds the Discord icon in the header
	GetKeyLink = "https://example.com/getkey",
	Validate = function(k) return k == "my-secret-key", "That key is not valid" end,
	OnSuccess = function() TingUI:Notify("Unlocked!") end,
	Position = UDim2.new(1, -900, 1, -230),
})

TingUI:CreateCredits({
	Title = "CREDITS",
	Subtitle = "Cool people behind *your* script",
	Position = UDim2.new(1, -400, 0.5, -10),
	Height = 420,
	Dock = { Icon = "user", Tooltip = "Credits", Order = 50 },
	Visible = false,
	Entries = {
		{ Name = "@developer", Role = "Owner/Developer", RoleColor = Color3.fromRGB(80, 159, 119), Description = "Founder and developer." },
		{ Name = "@tester", Role = "Owner/Tester", RoleColor = Color3.fromRGB(168, 128, 82), Description = "Co-founder." },
		{ Name = "@helper", Role = "Contributor » Bug fixing", RoleColor = Color3.fromRGB(159, 88, 88), Description = "Lorem ipsum dolor sit amet." },
		{ Name = "@designer", Role = "Contributor » Lorem ipsum", RoleColor = Color3.fromRGB(80, 158, 237), Description = "Lorem ipsum dolor sit amet." },
	},
})

-- About tab: open the demo windows
About:AddGroup("Demos", "Left"):AddButton({ Text = "Key System demo", Description = "Opens the example key prompt. The valid key is my-secret-key.",
	Callback = function() keySystem:Toggle() end })
TingUI:Notify({ Title = "Loaded", Content = "TingUI " .. TingUI.Version .. " is ready. RightShift hides the menu, Ctrl+K searches.", Type = "Success" })

TingUI:LoadAutoload()
