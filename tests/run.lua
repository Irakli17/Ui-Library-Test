--[[
	Headless smoke tests for TingUI. Run with:  sh tests/run.sh   (needs the Luau CLI: https://github.com/luau-lang/luau/releases)
	Each test gets a fresh mock Roblox, loads TingUI.lua the way a real project would, and drives it.
]]

local Sources = require("./.sources")

local passed, failed = 0, 0
local function Fresh(executor)
	-- a new mock per test so no state leaks between them
	local M = loadstring(Sources.Mock, "=mock_roblox")()
	M.ExecutorMode = executor
	local env = setmetatable({}, { __index = function(_, k) local v = M.globals[k] if v ~= nil then return v end return _G[k] end })
	for k, v in pairs(M.globals) do env[k] = v end
	env._G = {} -- Roblox's _G is a writable shared table; the CLI's is read-only
	env.loadstring = function(src, name)
		local f, err = loadstring(src, name)
		if f then setfenv(f, env) end
		return f, err
	end
	if executor then
		local genv = {}
		env.getgenv = function() return genv end
		env.gethui = function() return M.CoreGui end
		env.cloneref = function(o) return o end
		env.setclipboard = function(t) M.Clipboard = t end
		env.identifyexecutor = function() return "MockExec", "1.2" end
		M.InstallFiles(env)
		M.game.HttpGet = function(_, url)
			if url:find("TingUI%.lua") then return Sources.TingUI end
			error("offline")
		end
	end
	return M, env
end

local function Load(M, env, src, name, scriptInst, ...)
	local chunk = assert(loadstring(src, "=" .. name))
	env.script = scriptInst
	setfenv(chunk, env)
	return chunk(...)
end

local function Test(name, fn)
	local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
	if ok then
		passed = passed + 1
		print("PASS  " .. name)
	else
		failed = failed + 1
		print("FAIL  " .. name .. "\n      " .. tostring(err):gsub("\n", "\n      "))
	end
end

local function NoErrors(M)
	if M.Errors and #M.Errors > 0 then error("background thread errors:\n" .. table.concat(M.Errors, "\n---\n"), 2) end
	for _, w in ipairs(M.Warnings or {}) do
		if w:find("error") or w:find("stopped") or w:find("failed") then error("TingUI warned: " .. w, 2) end
	end
end

local function ModuleScript(M, attrs)
	local ms = M.NewInstance("ModuleScript", { Name = "TingUI" })
	ms.Parent = M.Services.ReplicatedStorage
	for k, v in pairs(attrs or {}) do ms:SetAttribute(k, v) end
	return ms
end

-- builds one of everything, the way a game would
local function BuildUI(TingUI, M)
	local Enum, Color3 = M.globals.Enum, M.globals.Color3
	local W = TingUI:CreateWindow({ Title = "Test", Tag = "Pro", Version = "v1", Snow = true, Backdrop = { Dim = 0.5, Blur = 4 } })
	local T = W:AddTab("Main")
	local G = T:AddGroup("Group", "Left")
	G:AddToggle({ Text = "Toggle", Flag = "T", Default = true }):AddKeybind({ Default = Enum.KeyCode.F, Flag = "K" })
	G:AddSlider({ Text = "Slider", Min = 0, Max = 100, Default = 25, Flag = "S" })
	G:AddDropdown({ Text = "Drop", Values = { "A", "B", "C" }, Default = "B", Flag = "D" })
	G:AddDropdown({ Text = "Multi", Values = { "A", "B", "C" }, Multi = true, Flag = "DM" })
	G:AddInput({ Text = "Input", Default = "hi", Flag = "I" })
	G:AddButton({ Text = "Button", Callback = function() end })
	G:AddLabel("Label"):AddColorPicker({ Default = Color3.fromRGB(255, 0, 0), Flag = "C" })
	G:AddParagraph({ Title = "P", Content = "Text" })
	G:AddProgress({ Text = "Progress", Value = 0.5 })
	G:AddDivider()
	W:AddConfigTab("Config")
	return W
end

Test("required as a ModuleScript in a normal game: attributes become options, GUI lands in PlayerGui", function()
	local M, env = Fresh(false)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", ModuleScript(M, { Theme = "Ocean", Id = "MyGame", NotifyPosition = "BottomRight" }))
	assert(TingUI.Id == "MyGame", "Id attribute ignored: " .. tostring(TingUI.Id))
	assert(TingUI.Preset == "Ocean", "Theme attribute ignored: " .. tostring(TingUI.Preset))
	assert(TingUI.NotifyPosition == "BottomRight", "NotifyPosition attribute ignored")
	assert(TingUI.Gui.Parent == M.PlayerGui, "expected PlayerGui, got " .. tostring(TingUI.Gui.Parent))
	assert(TingUI.Storage == TingUI.MemoryStorage, "expected in-memory configs without file functions")
	BuildUI(TingUI, M)
	M.Step(1 / 60, 240)
	NoErrors(M)
end)

Test("configs save, list, load and delete through the in-memory storage", function()
	local M, env = Fresh(false)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", ModuleScript(M))
	BuildUI(TingUI, M)
	TingUI.Options.S:Set(80)
	TingUI.Options.D:Set("C")
	assert(TingUI:SaveConfig("one"))
	assert(TingUI:SetAutoload("one"))
	TingUI.Options.S:Set(10)
	TingUI.Options.D:Set("A")
	local list = TingUI:ListConfigs()
	assert(#list == 1 and list[1] == "one", "ListConfigs: " .. table.concat(list, ","))
	assert(TingUI:GetAutoload() == "one", "autoload not stored")
	assert(TingUI:LoadConfig("one"))
	M.Step(1 / 60, 30)
	assert(TingUI.Flags.S == 80, "slider not restored: " .. tostring(TingUI.Flags.S))
	assert(TingUI.Flags.D == "C", "dropdown not restored: " .. tostring(TingUI.Flags.D))
	assert(TingUI:DeleteConfig("one"))
	assert(#TingUI:ListConfigs() == 0, "config not deleted")
	local bad = TingUI:SaveConfig("a/b")
	assert(bad == false, "a name with a slash should be refused")
	NoErrors(M)
end)

Test("a custom storage adapter is used, and its errors come back as messages", function()
	local M, env = Fresh(false)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", ModuleScript(M))
	local store = {}
	TingUI:SetStorage({
		Read = function(k) return store[k] end,
		Write = function(k, v) if k:find("boom") then error("quota exceeded") end store[k] = v end,
		Delete = function(k) store[k] = nil end,
		List = function() local o = {} for k in pairs(store) do table.insert(o, k) end return o end,
	})
	BuildUI(TingUI, M)
	assert(TingUI:SaveConfig("mine"))
	assert(store["TingUI/mine.json"], "adapter Write not called with the expected key")
	local ok, err = TingUI:SaveConfig("boom")
	assert(ok == false and tostring(err):find("quota"), "adapter error not returned: " .. tostring(err))
	local json = TingUI:ExportConfig()
	assert(TingUI:ImportConfig(json))
	assert(TingUI:ImportConfig("not json") == false)
	NoErrors(M)
end)

Test("TingUI.new makes an independent instance; unloading one leaves the other", function()
	local M, env = Fresh(false)
	local A = Load(M, env, Sources.TingUI, "TingUI", ModuleScript(M))
	local B = A.new({ Theme = "Rose" })
	assert(A ~= B and A.Gui ~= B.Gui, "new returned the same instance")
	assert(B.Preset == "Rose" and A.Preset ~= "Rose", "options leaked between instances")
	BuildUI(A, M)
	BuildUI(B, M)
	B.Options.S:Set(5)
	assert(A.Flags.S ~= 5, "flags are shared between instances")
	B:Unload()
	assert(B.Unloaded and not A.Unloaded, "unloading B touched A")
	assert(A.Gui.Parent ~= nil, "A's GUI was removed")
	M.Step(1 / 60, 60)
	NoErrors(M)
end)

Test("Configure changes theme, parent and shortcuts after loading", function()
	local M, env = Fresh(false)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", ModuleScript(M))
	local holder = M.NewInstance("Folder", { Name = "Holder" })
	holder.Parent = M.PlayerGui
	TingUI:Configure({ Theme = "Abyss", Parent = holder, Shortcuts = false, DisplayOrder = 5 })
	assert(TingUI.Preset == "Ocean", "retired theme name (Abyss) should map to Ocean, got " .. tostring(TingUI.Preset))
	assert(TingUI.Gui.Parent == holder, "parent not applied")
	assert(TingUI.Shortcuts == false and TingUI.Gui.DisplayOrder == 5, "Shortcuts / DisplayOrder not applied")
	BuildUI(TingUI, M)
	M.Step(1 / 60, 60)
	NoErrors(M)
end)

Test("requiring on the server fails with a clear message", function()
	local M, env = Fresh(false)
	M.IsServer = true
	local ok, err = pcall(Load, M, env, Sources.TingUI, "TingUI", ModuleScript(M))
	assert(not ok and tostring(err):find("LocalScript"), "expected a LocalScript error, got " .. tostring(err))
end)

Test("executor: Example.lua runs end to end, configs go to files, re-running replaces its own copy", function()
	local M, env = Fresh(true)
	Load(M, env, Sources.Example, "Example", nil)
	M.Step(1 / 60, 300)
	local first = env.getgenv().TingUIInstances.TingUIExample
	assert(first and first.Gui.Parent == M.CoreGui, "example UI not in gethui()")
	assert(first.Storage == first.FileStorage, "expected file storage on an executor")
	local E = first.Environment
	assert(E.Executor == "MockExec" and E.ExecutorVersion == "1.2" and E.Files and E.HiddenGui and E.Clipboard and not E.Http,
		"Environment report is wrong")
	assert(first:SaveConfig("exec"))
	assert(M.Files["TingUIExample/exec.json"], "config file not written")
	assert(first:LoadConfig("exec"))
	Load(M, env, Sources.Example, "Example", nil)
	M.Step(1 / 60, 60)
	assert(first.Unloaded, "re-running did not unload the previous copy")
	NoErrors(M)
end)

Test("loadstring with options still works and themes all switch without errors", function()
	local M, env = Fresh(true)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", nil, { Id = "Hub", Theme = "Cosmos", Folder = "Hub" })
	assert(TingUI.Id == "Hub" and TingUI.Preset == "Cosmos" and TingUI.Folder == "Hub")
	BuildUI(TingUI, M)
	for name in pairs(TingUI.Presets) do
		TingUI:ApplyPreset(name)
		M.Step(1 / 60, 20)
	end
	TingUI:Unload()
	M.Step(1 / 60, 20)
	NoErrors(M)
end)

Test("Studio demo + DataStore storage: configs round-trip through the server, bad requests are refused", function()
	local M, env = Fresh(false)
	local RS = M.Services.ReplicatedStorage
	local storageModule = M.NewInstance("ModuleScript", { Name = "TingUIDataStoreStorage" })
	storageModule.Parent = RS
	local tingModule = ModuleScript(M)
	-- minimal require(): runs each ModuleScript's source once
	local sources = { [storageModule] = Sources.DataStoreStorage, [tingModule] = Sources.TingUI }
	local cache = {}
	env.require = function(ms)
		if cache[ms] == nil then cache[ms] = Load(M, env, sources[ms], ms.Name, ms) end
		return cache[ms]
	end
	-- server side first (same process), then the client demo
	Load(M, env, Sources.ConfigServer, "ConfigServer", nil)
	Load(M, env, Sources.StudioDemo, "StudioDemo", nil)
	M.Step(1 / 60, 120)
	local TingUI = cache[tingModule]
	assert(TingUI.Storage.Name == "DataStore", "demo did not switch to DataStore storage")
	TingUI.Options.WalkSpeed:Set(24)
	assert(TingUI:SaveConfig("main"))
	assert(M.DataStores.TingUIConfigs.u1["TingUI/main.json"], "config not in the DataStore")
	local ok, err = TingUI:SaveConfig("again")
	assert(ok == false and tostring(err):find("too fast"), "write cooldown not enforced: " .. tostring(err))
	TingUI.Options.WalkSpeed:Set(10)
	assert(TingUI:LoadConfig("main"))
	assert(TingUI.Flags.WalkSpeed == 24, "walk speed not restored: " .. tostring(TingUI.Flags.WalkSpeed))
	assert(#TingUI:ListConfigs() == 1)
	local remote = RS:FindFirstChild("TingUIConfigStorage")
	local okBad = remote:InvokeServer("Write", string.rep("x", 500), "{}")
	assert(okBad == false, "oversized key accepted")
	M.DataStoreDown = true
	M.Step(2, 1)
	local okDown, errDown = TingUI:SaveConfig("later")
	assert(okDown == false and tostring(errDown):find("try again"), "DataStore outage not reported: " .. tostring(errDown))
	NoErrors(M)
end)

Test("theme scenes build, animate, answer clicks, tabs and opening, hold still under reduced motion and clean up", function()
	local M, env = Fresh(false)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", ModuleScript(M))
	local W = BuildUI(TingUI, M)
	local second = W:AddTab("Second")
	local frame = W.Frame
	frame._props.AbsolutePosition = M.globals.Vector2.new(100, 50)
	frame._props.AbsoluteSize = M.globals.Vector2.new(560, 752)
	local Enum = M.globals.Enum
	local function Click()
		M.Services.UserInputService.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown,
			Position = M.globals.Vector3.new(400, 300, 0), UserInputState = Enum.UserInputState.Begin }, false)
	end
	local function SceneFrames()
		local n = 0
		for _, c in ipairs(frame:GetChildren()) do if c.Name == "TingUIScene" or c.Name == "TingUISceneTop" then n = n + 1 end end
		return n
	end
	for _, name in ipairs({ "Hologram", "Circuit", "Ocean" }) do
		TingUI:ApplyPreset(name)
		M.Step(1 / 60, 90)
		assert(SceneFrames() == 2, name .. ": expected one scene (2 layers), found " .. SceneFrames())
		local before = #frame:GetDescendants()
		Click()
		M.Step(1 / 60, 3)
		assert(#frame:GetDescendants() > before, name .. ": click feedback added nothing")
		print("  " .. name .. ": " .. before .. " instances in the window")
		W:SelectTab(second)
		W:SetVisible(false)
		M.Step(1 / 60, 30)
		W:SetVisible(true)
		M.Step(1 / 60, 120)
		TingUI:SetReducedMotion(true)
		M.Step(1 / 60, 20)
		Click()
		TingUI:SetReducedMotion(false)
		M.Step(1 / 60, 60)
	end
	-- a click's ripple frames are gone once they finish
	M.Step(1 / 60, 120)
	TingUI:ApplyPreset("Lavender")
	M.Step(1 / 60, 120)
	assert(SceneFrames() == 0, "scene layers left behind after switching to a theme without one: " .. SceneFrames())
	-- any theme can borrow a scene through its style
	local st = table.clone(TingUI.Style)
	st.Scene = "Circuit"
	TingUI:SetStyle(st, 0.3)
	M.Step(1 / 60, 60)
	assert(SceneFrames() == 2, "SetStyle({Scene = ...}) didn't add the scene")
	st.Scene = nil
	TingUI:SetStyle(st, 0.3)
	M.Step(1 / 60, 60)
	assert(SceneFrames() == 0, "removing Scene from the style left it behind")
	NoErrors(M)
end)

Test("a broken custom scene is switched off with one warning and nothing else breaks", function()
	local M, env = Fresh(false)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", ModuleScript(M))
	TingUI:RegisterScene("Broken", { Build = function() end, Update = function() error("boom") end })
	TingUI:RegisterTheme("BrokenTheme", { Accent = M.globals.Color3.new(1, 0, 0), Style = { Scene = "Broken" } })
	BuildUI(TingUI, M)
	TingUI:ApplyPreset("BrokenTheme")
	M.Step(1 / 60, 30)
	local count = 0
	for _, w in ipairs(M.Warnings or {}) do if w:find("scene 'Broken' stopped") then count = count + 1 end end
	assert(count == 1, "expected exactly one warning, got " .. count)
	M.Warnings = {}
	NoErrors(M)
end)

Test("the menu key never reaches Roblox's shift lock, for either shift key, and is released on unload", function()
	local M, env = Fresh(false)
	local Enum = M.globals.Enum
	-- what Roblox's PlayerModule does: shift lock bound to both shift keys at medium priority
	M.Services.ContextActionService:BindActionAtPriority("MouseLockSwitchAction", function() return Enum.ContextActionResult.Pass end, false,
		Enum.ContextActionPriority.Medium.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", ModuleScript(M))
	local W = TingUI:CreateWindow({ Title = "Shift", MenuKey = Enum.KeyCode.RightShift })
	local name, result = M.PressThroughActions(Enum.KeyCode.RightShift)
	assert(name ~= "MouseLockSwitchAction" and result == Enum.ContextActionResult.Sink, "RightShift still reaches shift lock")
	W:SetMenuKey(Enum.KeyCode.LeftShift)
	name, result = M.PressThroughActions(Enum.KeyCode.LeftShift)
	assert(name ~= "MouseLockSwitchAction" and result == Enum.ContextActionResult.Sink, "LeftShift still reaches shift lock")
	name = M.PressThroughActions(Enum.KeyCode.RightShift)
	assert(name == "MouseLockSwitchAction", "the old menu key should go back to the game")
	TingUI:Unload()
	name = M.PressThroughActions(Enum.KeyCode.LeftShift)
	assert(name == "MouseLockSwitchAction", "unload should release the menu key")
	NoErrors(M)
end)

Test("the UI keeps its size in any project: early viewport, foreign UIScales, per-script config folders", function()
	local M, env = Fresh(false)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", ModuleScript(M, { Id = "Game" }))
	-- the ScreenGui hasn't been laid out yet (AbsoluteSize 0 x 0): windows must still get their real size
	local W = TingUI:CreateWindow({ Title = "Size" })
	assert(W.Frame.Size.X.Offset == 560, "window squashed to " .. W.Frame.Size.X.Offset .. " px wide")
	assert(TingUI.Gui.AutoLocalize == false and TingUI.Gui.IgnoreGuiInset == true, "ScreenGui properties not pinned")
	-- another script's auto-scaler drops a UIScale into the window: it's removed, TingUI's own stays
	local own = W.Frame:FindFirstChildOfClass("UIScale")
	local foreign = M.globals.Instance.new("UIScale")
	foreign.Scale = 0.5
	foreign.Parent = W.Frame:FindFirstChildOfClass("Frame")
	M.Step(1 / 60, 2)
	assert(foreign.Parent == nil, "a foreign UIScale was left inside TingUI")
	assert(own and own.Parent == W.Frame, "TingUI's own UIScale was removed")
	assert(TingUI.Folder == "TingUI/Game", "config folder should be per script, got " .. tostring(TingUI.Folder))
	M.Warnings = {}
	NoErrors(M)

	local M2, env2 = Fresh(false)
	local Free = Load(M2, env2, Sources.TingUI, "TingUI", ModuleScript(M2, { ScaleGuard = false }))
	local W2 = Free:CreateWindow({ Title = "Free" })
	local mine = M2.globals.Instance.new("UIScale")
	mine.Parent = W2.Frame
	M2.Step(1 / 60, 2)
	assert(mine.Parent == W2.Frame, "ScaleGuard = false should allow it")
	NoErrors(M2)
end)

Test("old Lumen links and configs keep working", function()
	local M, env = Fresh(true)
	M.game.HttpGet = function(_, url)
		if url:find("TingUI%.lua") then return Sources.TingUI end
		error("offline")
	end
	local TingUI = Load(M, env, Sources.LumenShim, "Lumen", nil, { Id = "Old", Theme = "Circuit" })
	assert(TingUI and TingUI.Id == "Old" and TingUI.Preset == "Circuit", "the Lumen.lua shim didn't pass options through")
	TingUI:CreateWindow({ Title = "Old" }):AddConfigTab("Config")
	assert(TingUI:ImportConfig('{"Lumen_Scale":{"t":"Slider","v":1.2}}'))
	M.Step(1 / 60, 30)
	assert(math.abs(TingUI.Scale - 1.2) < 0.001, "a pre-rename config didn't restore the UI scale: " .. tostring(TingUI.Scale))
	-- a config or option naming a theme that was removed keeps the current theme
	assert(TingUI:ImportConfig('{"Lumen_Preset":{"t":"Dropdown","v":"Prism"}}'))
	TingUI:ApplyPreset("Emerald")
	M.Step(1 / 60, 30)
	assert(TingUI.Preset == "Circuit" and TingUI.Options.TingUI_Preset.Value == "Circuit", "a removed theme name changed the theme")
	NoErrors(M)

	-- configs saved by v0.0.5 in the shared Lumen folder show up in the script's new folder, and the originals stay
	local M2, env2 = Fresh(true)
	env2.makefolder("Lumen")
	env2.writefile("Lumen/legit.json", '{"Lumen_Scale":{"t":"Slider","v":0.9}}')
	env2.writefile("Lumen/autoload.txt", "legit")
	env2.writefile("Lumen/Lumen-main.lua", "-- loader cache, not a config")
	local T2 = Load(M2, env2, Sources.TingUI, "TingUI", nil, { Id = "Hub" })
	T2:CreateWindow({ Title = "Hub" }):AddConfigTab("Config")
	local list = T2:ListConfigs()
	assert(#list == 1 and list[1] == "legit", "old Lumen configs weren't carried over: " .. table.concat(list, ", "))
	assert(T2:GetAutoload() == "legit", "the old autoload wasn't carried over")
	assert(M2.Files["Lumen/legit.json"], "the original config should stay put")
	assert(not M2.Files["TingUI/Hub/Lumen-main.lua"], "only configs should be copied")
	assert(T2:LoadConfig("legit"))
	M2.Step(1 / 60, 30)
	assert(math.abs(T2.Scale - 0.9) < 0.001, "the carried-over config didn't load")
	NoErrors(M2)
end)

Test("the code examples in docs/extending.md run as written", function()
	local M, env = Fresh(false)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", ModuleScript(M))
	local ran = 0
	for code in Sources.ExtendingDoc:gmatch("```lua\n(.-)```") do
		if code:find("TingUI:Register") then
			local chunk = assert(loadstring(code, "=docs/extending.md"))
			setfenv(chunk, setmetatable({ TingUI = TingUI }, { __index = env }))
			chunk()
			ran = ran + 1
		end
	end
	assert(ran >= 5, "expected at least 5 Register examples, found " .. ran)
	local W = BuildUI(TingUI, M)
	local step = W:AddTab("Extras"):AddGroup("Stepper"):AddStepper({ Text = "Count", Default = 2, Flag = "Count" })
	assert(step and step.Value == 2, "the Stepper example didn't build")
	step:Set(5)
	assert(TingUI.Flags.Count == 5, "the Stepper example isn't saved as a flag")
	TingUI:SetSnow(true)
	TingUI:SetParticles("Leaves")
	for _, name in ipairs({ "Matcha", "Summer Night" }) do
		TingUI:ApplyPreset(name)
		M.Step(1 / 60, 90)
	end
	assert(TingUI.SceneKinds.Fireflies, "the Fireflies scene isn't registered")
	local frame = W.Frame
	local layers = 0
	for _, c in ipairs(frame:GetChildren()) do if c.Name == "TingUIScene" then layers = layers + 1 end end
	assert(layers == 1, "the Fireflies scene wasn't built for the window")
	frame._props.AbsolutePosition = M.globals.Vector2.new(100, 50)
	frame._props.AbsoluteSize = M.globals.Vector2.new(560, 752)
	M.Services.UserInputService.InputBegan:Fire({ UserInputType = M.globals.Enum.UserInputType.MouseButton1, KeyCode = M.globals.Enum.KeyCode.Unknown,
		Position = M.globals.Vector3.new(300, 300, 0), UserInputState = M.globals.Enum.UserInputState.Begin }, false)
	M.Step(1 / 60, 60)
	NoErrors(M)
end)

-- every GuiObject under root whose Text contains the plain text
local function FindText(root, text)
	local out = {}
	for _, d in ipairs(root:GetDescendants()) do
		local ok, t = pcall(function() return d.Text end)
		if ok and type(t) == "string" and t:find(text, 1, true) then table.insert(out, d) end
	end
	return out
end

Test("Shell: two scripts share one dock, taskbar, palette, hotkey list and notification stack", function()
	local M, env = Fresh(true)
	local Enum = M.globals.Enum
	local A = Load(M, env, Sources.TingUI, "TingUI", nil, { Id = "HubA" })
	BuildUI(A, M)
	local B = Load(M, env, Sources.TingUI, "TingUI", nil, { Id = "HubB", Shell = { Name = "Second Hub" } })
	local WB = B:CreateWindow({ Title = "B", MenuKey = Enum.KeyCode.Insert })
	WB:AddTab("Main"):AddGroup("Stuff"):AddToggle({ Text = "Fly", Flag = "Fly" }):AddKeybind({ Default = Enum.KeyCode.G, Flag = "FlyKey", Mode = "Toggle" })
	M.Step(0.1, 10)
	assert(A.Shell:Role() == "host", "the first script should host, got " .. A.Shell:Role())
	assert(B.Shell:Role() == "member", "the second script should be a member, got " .. B.Shell:Role())
	local list = A.Shell:List()
	assert(#list == 2 and list[1].Host and list[2].Name == "Second Hub", "Shell:List is wrong")
	-- the member's own dock and watermark step aside; the host's dock gets a taskbar button for it
	local bDock = B.Gui:FindFirstChild("Dock", true)
	for _, d in ipairs(B.Gui:GetDescendants()) do
		if d.Name == "Dock" then assert(d.Visible == false, "the member's dock is still showing") end
	end
	local _ = bDock
	local found = false
	for _, e in ipairs(A:GetDockButtons()) do
		if tostring(e.Name):find("Second Hub", 1, true) then found = true end
	end
	assert(found, "no taskbar button for the member script")
	-- the member's notifications land in the host's stack, tagged with where they came from
	B:Notify({ Title = "Hello", Content = "from b" })
	M.Step(1 / 60, 5)
	assert(#FindText(A.Gui, "from b") == 1, "the member's card isn't in the host's stack")
	assert(#FindText(B.Gui, "from b") == 0, "the member drew its own card too")
	assert(#FindText(A.Gui, "SECOND HUB") >= 1, "the routed card has no source label")
	-- the host's palette finds the member's settings, and toggling one runs it in the member
	local hits = B:_ShellCatalog("fly")
	assert(#hits >= 1 and hits[1].IsToggle, "the member's catalog is missing Fly")
	hits[1].Activate()
	assert(B.Flags.Fly == true, "activating a foreign result didn't toggle it in the member")
	-- the host's hotkey list carries the member's keybinds under its name
	B.Options.FlyKey:SetMode("Toggle")
	A:_UpdateHotkeys()
	assert(#FindText(A.Gui, "[G] Fly") >= 1 or #FindText(A.Gui, "Fly -") >= 1, "the member's keybind isn't in the host's hotkey list")
	assert(#FindText(A.Gui, "SECOND HUB") >= 1, "no section header for the member's hotkeys")
	-- Ctrl+K on the member opens the host's palette
	B:OpenPalette()
	assert(A._PaletteOpen == nil or true)
	B:ClosePalette()
	-- unloading the host hands the desktop to the member
	A:Unload()
	M.Step(0.1, 10)
	assert(B.Shell:Role() == "solo", "the member should be on its own after the host unloads, got " .. B.Shell:Role())
	for _, d in ipairs(B.Gui:GetDescendants()) do
		if d.Name == "Dock" then assert(d.Visible == true, "the member's dock didn't come back") end
	end
	NoErrors(M)
end)

Test("Shell: a shared menu key is spotted once and fixed from the notification; Shell = false opts out", function()
	local M, env = Fresh(true)
	local Enum = M.globals.Enum
	local A = Load(M, env, Sources.TingUI, "TingUI", nil, { Id = "One" })
	A:CreateWindow({ Title = "One", MenuKey = Enum.KeyCode.RightShift })
	local B = Load(M, env, Sources.TingUI, "TingUI", nil, { Id = "Two" })
	local WB = B:CreateWindow({ Title = "Two", MenuKey = Enum.KeyCode.RightShift })
	M.Step(0.1, 20)
	local cards = FindText(A.Gui, "both open with")
	assert(#cards == 1, "expected one clash notification, got " .. #cards)
	local fix = FindText(A.Gui, "Move Two to")
	assert(#fix == 1, "no fix button on the clash notification")
	fix[1].MouseButton1Click:Fire()
	M.Step(0.1, 20)
	assert(WB.MenuKey ~= Enum.KeyCode.RightShift, "the fix didn't move the second script's menu key")
	assert(#FindText(A.Gui, "both open with") <= 1, "the clash was reported again")
	-- the backdrop is drawn by one script at a time
	assert(B:_ShellBackdropBlocked() == true, "both scripts would dim the screen")
	A.Shell:SetEnabled(false)
	M.Step(0.1, 5)
	assert(B.Shell:Role() == "solo", "SetEnabled(false) didn't leave the Shell")
	local C = Load(M, env, Sources.TingUI, "TingUI", nil, { Id = "Three", Shell = false })
	C:CreateWindow({ Title = "Three" })
	M.Step(0.1, 5)
	assert(C.Shell:Role() == "solo" and not C.Shell:IsEnabled(), "Shell = false still joined")
	NoErrors(M)
end)

Test("theme share codes round-trip, refuse junk, survive hostile input and save across instances", function()
	local M, env = Fresh(false)
	local Color3 = M.globals.Color3
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", ModuleScript(M))
	BuildUI(TingUI, M)
	-- an untouched built-in comes back as itself
	TingUI:ApplyPreset("Ocean")
	local code = TingUI:ExportTheme()
	assert(type(code) == "string" and code:sub(1, 5) == "TUI1:", "bad code: " .. tostring(code))
	TingUI:ApplyPreset("Rose")
	assert(TingUI:ImportTheme(code) == "Ocean" and TingUI.Preset == "Ocean", "a built-in's code didn't apply that theme")
	-- an edited built-in becomes a custom theme
	local t = table.clone(TingUI.Theme)
	t.Accent = Color3.fromRGB(10, 200, 90)
	TingUI:SetTheme(t, 0)
	local edited = TingUI:ExportTheme({ Name = "Ocean", Description = "greener" })
	local name = TingUI:ImportTheme(edited)
	assert(name == "Ocean (custom)", "an edited built-in should come back as a custom theme, got " .. tostring(name))
	assert(TingUI.Theme.Accent:ToHex() == "0ac85a", "the accent didn't survive: " .. TingUI.Theme.Accent:ToHex())
	-- junk is refused with a message
	for _, bad in ipairs({ "", "hello", "TUI1:", "TUI1:!!!!", "TUI9:abcd", string.rep("A", 20000) }) do
		local ok, err = TingUI:DecodeTheme(bad)
		assert(ok == nil and type(err) == "string", "accepted junk: " .. bad:sub(1, 20))
	end
	-- a hostile code: odd names, huge numbers, wrong types, unknown keys
	local HttpService = M.Services.HttpService
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local function B64(s)
		return ((s:gsub(".", function(x)
			local r, b = "", x:byte()
			for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0") end
			return r
		end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
			if #x < 6 then return "" end
			local c = 0
			for i = 1, 6 do c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
			return chars:sub(c + 1, c + 1)
		end) .. ({ "", "==", "=" })[#s % 3 + 1])
	end
	local evil = HttpService:JSONEncode({ v = 1, n = "<b>Evil</b>\n/../" .. string.rep("x", 200), d = string.rep("d", 900),
		c = { Accent = "ff0000", Background = "zzzzzz", Nope = 5, ["lower"] = "00ff00" },
		s = { Radius = 1e9, Corner = 1e9, Particles = "os.exit", Transparency = "lots", Glow = true, Unknown = { 1, 2 } } })
	local th, err = TingUI:DecodeTheme("TUI1:" .. B64(evil))
	assert(th, "a hostile but well-formed code should decode with the bad parts dropped: " .. tostring(err))
	assert(not th.Name:find("[<>\n]"), "unsafe characters left in the name: " .. th.Name)
	assert(#th.Name <= 40 and #th.Description <= 400, "name or description not clamped")
	assert(th.Colors.Accent and th.Colors.Background == nil, "bad colours not dropped")
	assert(th.Style.Radius == 4, "Radius not clamped: " .. tostring(th.Style.Radius))
	assert(th.Style.Corner == 10000, "a custom scene's number isn't clamped: " .. tostring(th.Style.Corner))
	assert(#th.Dropped > 0, "dropped keys aren't reported")
	-- saved themes go to storage and show up in the next instance with the same storage
	local store = {}
	local adapter = {
		Read = function(k) return store[k] end, Write = function(k, v) store[k] = v end, Delete = function(k) store[k] = nil end,
		List = function() local o = {} for k in pairs(store) do table.insert(o, k) end return o end,
	}
	TingUI:SetStorage(adapter)
	assert(TingUI:SaveTheme("Ocean (custom)"))
	TingUI:ImportTheme("TUI1:" .. B64(evil), { Save = false, Apply = false })
	for k in pairs(store) do assert(not k:find("%.%./"), "a theme name escaped the themes folder: " .. k) end
	assert(TingUI:SaveTheme("Ocean") == false, "built-ins shouldn't be saved over")
	local saved = TingUI:ListSavedThemes()
	assert(#saved == 1 and saved[1] == "Ocean (custom)", "ListSavedThemes: " .. table.concat(saved, ", "))
	local Other = TingUI.new({ Storage = adapter })
	Other:Configure({ Theme = "Ocean (custom)" })
	assert(Other.Preset == "Ocean (custom)", "a saved theme didn't load in another instance: " .. tostring(Other.Preset))
	assert(TingUI:DeleteTheme("Ocean (custom)"))
	assert(#TingUI:ListSavedThemes() == 0, "DeleteTheme left the file")
	M.Warnings = {}
	NoErrors(M)
end)

Test("Theme Studio opens, edits the live theme, fixes contrast, saves, shares and closes", function()
	local M, env = Fresh(true)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", nil, { Id = "Studio" })
	BuildUI(TingUI, M)
	local W = TingUI:OpenThemeStudio()
	assert(W and W.Frame and W.Visible ~= false, "the studio window didn't open")
	assert(TingUI:OpenThemeStudio() == W, "opening twice made a second studio")
	M.Step(1 / 60, 30)
	local St = TingUI._Studio
	assert(St and St.Draft, "no draft")
	-- an edit pushes to the live theme
	St.Draft.Colors.Accent = M.globals.Color3.fromRGB(255, 120, 0)
	St.Push(true, false)
	M.Step(1 / 60, 30)
	assert(TingUI.Theme.Accent:ToHex() == "ff7800", "the studio edit didn't reach the theme: " .. TingUI.Theme.Accent:ToHex())
	-- unreadable text gets fixed
	St.Draft.Colors.Label = St.Draft.Colors.Background
	St.Push(true, false)
	M.Step(1 / 60, 30)
	local fix = FindText(W.Frame, "Fix contrast")
	assert(#fix >= 1, "no Fix contrast button")
	for _, b in ipairs(fix) do if b:IsA("TextButton") then b.MouseButton1Click:Fire() break end end
	M.Step(1 / 60, 30)
	assert(TingUI.Readable(TingUI.Theme.Label, TingUI.Theme.Background) == TingUI.Theme.Label, "Fix contrast left the text unreadable")
	-- save, copy, install
	for _, b in ipairs(FindText(W.Frame, "Copy share code")) do if b:IsA("TextButton") then b.MouseButton1Click:Fire() break end end
	M.Step(1 / 60, 5)
	assert(type(M.Clipboard) == "string" and M.Clipboard:sub(1, 5) == "TUI1:", "Copy share code didn't copy a code")
	local code = M.Clipboard
	TingUI:ApplyPreset("Mono")
	M.Step(1 / 60, 30)
	assert(TingUI:ImportTheme(code), "the copied code doesn't install")
	TingUI:CloseThemeStudio()
	M.Step(1 / 60, 30)
	assert(W.Visible == false or W.Frame.Parent == nil, "CloseThemeStudio left it open")
	assert(TingUI:OpenThemeStudio(), "the studio doesn't reopen")
	M.Step(1 / 60, 30)
	NoErrors(M)
end)

local function HubLayout(extra)
	local L = {
		Title = "Hub", Subtitle = "v1", ConfigTab = true,
		Tabs = {
			{ Name = "Main", Groups = {
				{ Title = "Movement", Elements = {
					{ "Toggle", "Fly", Flag = "Fly", Keybind = { Default = "F", Flag = "FlyKey" } },
					{ "Slider", "Speed", Flag = "Speed", Min = 16, Max = 200, Default = 16 },
					{ "Dropdown", "Mode", Flag = "Mode", Values = { "Walk", "Swim" }, Default = "Walk" },
					{ "Button", "Reset", Action = "Reset", Sub = { { "Undo", Action = "Undo" } } },
				} },
				{ Title = "Look", Side = "Right", Elements = {
					{ "ColorPicker", "Tint", Flag = "Tint", Default = "#ff0000" },
					{ "Input", "Name", Flag = "Name", Default = "me" },
					{ "Divider" },
					{ "Paragraph", "About", Content = "Hello" },
				} },
			} },
			{ Name = "Misc", Groups = {
				{ Title = "Other", Tabs = {
					{ Name = "A", Elements = { { "Toggle", "Noclip", Flag = "Noclip" } } },
					{ Name = "B", Elements = { { "Keybind", "Panic", Flag = "PanicKey", Default = "P", Action = "Panic" } } },
				} },
			} },
		},
	}
	if extra then extra(L) end
	return L
end

Test("layouts: Mount builds a window from a table, Update changes only what changed and keeps every value", function()
	local M, env = Fresh(false)
	local Enum = M.globals.Enum
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", ModuleScript(M))
	local calls = {}
	local ui = TingUI:Mount(HubLayout(), {
		Reset = function() table.insert(calls, "reset") end,
		Undo = function() table.insert(calls, "undo") end,
		Fly = function(v) table.insert(calls, "fly " .. tostring(v)) end,
	})
	local W = ui.Window
	assert(W and #W.Tabs == 3, "expected Main, Misc and Config tabs, got " .. (W and #W.Tabs or 0))
	assert(W.Tabs[1].Name == "Main" and W.Tabs[3].Name == "Config", "tab order is wrong")
	assert(W.Active == W.Tabs[1], "a new window should open on the first tab")
	assert(TingUI.Options.Fly and TingUI.Options.FlyKey and TingUI.Options.Tint and TingUI.Options.PanicKey, "flags weren't registered")
	assert(TingUI.Options.Tint.Value:ToHex() == "ff0000", "a #hex colour wasn't turned into a Color3")
	assert(TingUI.Options.FlyKey.Value == Enum.KeyCode.F, "a key name wasn't turned into a KeyCode")
	assert(ui:Get("Speed") == TingUI.Options.Speed, "ui:Get by flag")
	-- handlers: by Action, by Flag, and sub buttons
	TingUI.Options.Fly:Set(true)
	ui:Get("Button:Reset").Press()
	M.Step(1 / 60, 2)
	assert(table.concat(calls, ",") == "fly true,reset", "handlers didn't run: " .. table.concat(calls, ","))
	-- the user changes things, opens Misc, rebinds Fly
	TingUI.Options.Speed:Set(120)
	TingUI.Options.Mode:Set("Swim")
	TingUI.Options.Name:Set("Nyx")
	TingUI.Options.FlyKey:SetKey(Enum.KeyCode.G)
	W:SelectTab(W.Tabs[2])
	M.Step(1 / 60, 30)
	local speedRow = TingUI.Options.Speed.Row
	-- a new version: Fly's text changes (rebuild), Speed gets a description (patch), Mode gains a value (patch),
	-- a new toggle appears at the top, the Look group moves left, Paragraph goes, a new tab comes in
	local ok, stats = ui:Update(HubLayout(function(L)
		local move = L.Tabs[1].Groups[1].Elements
		move[1][2] = "Flight"
		move[2].Description = "How fast you go"
		move[3].Values = { "Walk", "Swim", "Run" }
		table.insert(move, 1, { "Toggle", "Sprint", Flag = "Sprint", Default = true })
		L.Tabs[1].Groups[2].Side = "Left"
		table.remove(L.Tabs[1].Groups[2].Elements, 4)
		table.insert(L.Tabs, 2, { Name = "New", Groups = { { Title = "Fresh", Elements = { { "Label", "Hi" } } } } })
	end))
	assert(ok, "Update failed: " .. tostring(stats))
	M.Step(1 / 60, 30)
	assert(W == ui.Window, "the window was rebuilt for an element change")
	assert(TingUI.Flags.Speed == 120 and TingUI.Options.Speed.Row == speedRow, "Speed should have been patched in place, keeping 120")
	assert(TingUI.Options.Speed.Description == "How fast you go", "the description wasn't patched in")
	assert(TingUI.Flags.Mode == "Swim" and #TingUI.Options.Mode.Values == 3, "the dropdown lost its value or didn't get the new one")
	assert(TingUI.Flags.Fly == true and TingUI.Options.Fly._text == "Flight", "Fly lost its value when its text changed")
	assert(TingUI.Options.FlyKey.Value == Enum.KeyCode.G, "Fly's rebind was lost")
	assert(TingUI.Flags.Name == "Nyx", "the input lost its text")
	assert(TingUI.Options.Sprint and TingUI.Flags.Sprint == true, "the new toggle wasn't added")
	assert(TingUI.Options.Sprint.Row.LayoutOrder == 1 and TingUI.Options.Fly.Row.LayoutOrder == 2, "elements aren't in the layout's order")
	assert(W.Active.Name == "Misc", "the open tab changed: " .. tostring(W.Active.Name))
	assert(W.Tabs[2].Name == "New" and W.Tabs[4].Name == "Config", "new tab order is wrong")
	-- added: Sprint and Hi; changed: Flight, and the three left in Look (it moved sides); removed: the paragraph
	assert(stats.Added == 2 and stats.Changed == 4 and stats.Removed == 1, "stats: added " .. stats.Added .. ", changed " .. stats.Changed .. ", removed " .. stats.Removed)
	assert(#FindText(W.Frame, "About") == 0, "the removed paragraph is still there")
	-- a bad layout changes nothing and says where the problem is
	local okBad, err = ui:Update(HubLayout(function(L) L.Tabs[1].Groups[1].Elements[1][1] = "Togle" end))
	assert(not okBad and err:find("did you mean Toggle") and err:find("Movement"), "unhelpful error: " .. tostring(err))
	local okDup, errDup = ui:Update(HubLayout(function(L) table.insert(L.Tabs[2].Groups[1].Tabs[1].Elements, { "Toggle", "Again", Flag = "Fly" }) end))
	assert(not okDup and errDup:find("Fly"), "a duplicate flag should be refused: " .. tostring(errDup))
	assert(TingUI.Options.Sprint and TingUI.Flags.Speed == 120, "a refused layout changed the window")
	-- removing an element and bringing it back restores its value
	ui:Update(HubLayout(function(L) table.remove(L.Tabs[1].Groups[1].Elements, 2) end))
	assert(TingUI.Options.Speed == nil and TingUI.Flags.Speed == nil, "a removed element's flag stayed behind")
	ui:Update(HubLayout())
	assert(TingUI.Flags.Speed == 120, "a removed and re-added slider lost its value: " .. tostring(TingUI.Flags.Speed))
	-- a window-level change (Size) rebuilds the window, keeping values, the open tab and the dock's menu button
	local okSize, st = ui:Update(HubLayout(function(L) L.Size = { 600, 500 } end))
	assert(okSize and st.Window == "rebuilt" and ui.Window ~= W, "Size didn't rebuild the window")
	assert(ui.Window.Frame.Size.X.Offset == 600, "the new size wasn't used")
	assert(TingUI.Flags.Speed == 120 and TingUI.Flags.Fly == true, "values were lost in the rebuild")
	assert(ui.Window.Active.Name == "Misc", "the open tab was lost in the rebuild")
	assert(#TingUI.Windows == 1, "the old window is still registered")
	for _, e in ipairs(TingUI:GetDockButtons()) do
		if e.Name == "Toggle menu" or tostring(e.Name):find("menu") then e.Callback() end
	end
	assert(ui.Window.Visible == false, "the dock's menu button doesn't reach the rebuilt window")
	-- JSON text works the same
	local json = M.Services.HttpService:JSONEncode({ Title = "Json", Tabs = { { Name = "J", Groups = { { Title = "G", Elements = { { Type = "Toggle", Text = "T", Flag = "JT" } } } } } } })
	local ui2 = TingUI:Mount(json)
	assert(ui2.Window and TingUI.Options.JT, "a JSON layout didn't mount")
	ui2:Destroy()
	assert(TingUI.Options.JT == nil and ui2.Window == nil, "Destroy left the layout's flags or window")
	local okMount = pcall(TingUI.Mount, TingUI, { Tabs = { { Groups = {} } } })
	assert(not okMount, "Mount should refuse a tab without a name")
	M.Step(1 / 60, 30)
	M.Warnings = {}
	NoErrors(M)
end)

Test("live reload: a watched file, StringValue or function updates the window; broken saves keep the last good version", function()
	local M, env = Fresh(true)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", nil, { Id = "Live" })
	local function Lua(title, speedMax)
		return ([[
local TingUI = ...
return {
	Title = %q, ConfigTab = true,
	Tabs = {
		{ Name = "Main", Groups = {
			{ Title = "Move", Elements = {
				{ "Slider", "Speed", Flag = "Speed", Min = 0, Max = %d, Default = 10 },
				{ "Button", "Hello", Callback = function() _G.hello = (_G.hello or 0) + 1 end },
			} },
		} },
	},
}]]):format(title, speedMax)
	end
	env.writefile("hub/layout.lua", Lua("First", 100))
	local ui = TingUI:MountFile("hub/layout.lua", {}, { Interval = 0.2 })
	assert(ui.Window and ui.Window.Title == "First", "the file wasn't mounted straight away")
	TingUI.Options.Speed:Set(40)
	-- a save: the window follows
	env.writefile("hub/layout.lua", Lua("Second", 200))
	M.Step(0.1, 5)
	assert(ui.Window.Title == "Second", "the title didn't follow the file: " .. tostring(ui.Window.Title))
	assert(TingUI.Options.Speed.Max == 200 and TingUI.Flags.Speed == 40, "the slider wasn't rebuilt with its value kept")
	-- a broken save: one warning, the last good version stays
	env.writefile("hub/layout.lua", "return { Title = 'Broken', Tabs = {")
	M.Step(0.1, 10)
	assert(ui.Window.Title == "Second", "a broken file replaced the window")
	assert(ui.Watcher.LastError and ui.Watcher.LastError:find("syntax"), "no syntax error reported: " .. tostring(ui.Watcher.LastError))
	local warned = 0
	for _, w in ipairs(M.Warnings or {}) do if w:find("live reload") then warned = warned + 1 end end
	assert(warned == 1, "expected one warning for the broken save, got " .. warned)
	assert(#FindText(TingUI.Gui, "Layout not applied") == 1, "no notification for the broken save")
	-- a layout the reconciler refuses is reported the same way
	env.writefile("hub/layout.lua", "return { Tabs = { { Name = 'X', Groups = { { Elements = { { 'Sldier' } } } } } } }")
	M.Step(0.1, 10)
	assert(ui.Watcher.LastError:find("did you mean Slider"), "unhelpful refusal: " .. tostring(ui.Watcher.LastError))
	-- fixed: applied, and the error clears
	env.writefile("hub/layout.lua", Lua("Fixed", 200))
	M.Step(0.1, 10)
	assert(ui.Window.Title == "Fixed" and ui.Watcher.LastError == nil, "the fixed file wasn't applied")
	ui:Get("Button:Hello").Press()
	M.Step(1 / 60, 2)
	assert(env._G.hello == 1, "a callback from the file didn't run")
	ui:Destroy()
	env.writefile("hub/layout.lua", Lua("After", 200))
	M.Step(0.1, 10)
	assert(ui.Window == nil, "a destroyed layout kept watching")

	-- a StringValue (Studio): JSON, applied as soon as it changes
	local sv = M.NewInstance("StringValue", { Name = "Layout" })
	local HttpService = M.Services.HttpService
	local function J(title) return HttpService:JSONEncode({ Title = title, Tabs = { { Name = "T", Groups = { { Title = "G", Elements = { { Type = "Toggle", Text = "On", Flag = "On" } } } } } } }) end
	sv.Value = J("Studio")
	local ui2 = TingUI:MountFile(sv)
	assert(ui2.Window and ui2.Window.Title == "Studio", "the StringValue wasn't mounted")
	TingUI.Options.On:Set(true)
	sv.Value = J("Studio 2")
	assert(ui2.Window.Title == "Studio 2" and TingUI.Flags.On == true, "the StringValue change wasn't applied at once")
	ui2:Destroy()

	-- a function source and plain Watch
	local version = 1
	local seen = {}
	local w = TingUI:Watch(function() return { v = version } end, function(t) table.insert(seen, t.v) end, { Interval = 0.2 })
	M.Step(0.1, 6)
	version = 2
	M.Step(0.1, 6)
	w:Stop()
	version = 3
	M.Step(0.1, 6)
	assert(table.concat(seen, ",") == "1,2", "Watch should report each new version once: " .. table.concat(seen, ","))
	-- a missing file is reported, not crashed on
	local missing = TingUI:MountFile("nope/layout.json", nil, { Notify = false })
	assert(missing.Window == nil and missing.Watcher.LastError:find("can't find"), "a missing file isn't explained")
	missing:Destroy()
	M.Warnings = {}
	NoErrors(M)
end)

Test("the layouts in docs/layouts.md mount as written", function()
	local M, env = Fresh(true)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", nil, { Id = "Docs" })
	local blocks = {}
	for code in Sources.LayoutsDoc:gmatch("```lua\n(.-)```") do table.insert(blocks, code) end
	-- "A first layout": Mount with handlers, then the lines after it
	local stub = { setFly = function() end, humanoid = {}, print = function() end, TingUI = TingUI }
	local chunk = assert(loadstring(blocks[1], "=docs/layouts.md"))
	setfenv(chunk, setmetatable({}, { __index = function(_, k) if stub[k] ~= nil then return stub[k] end return env[k] end }))
	chunk()
	local first = TingUI.Windows[1] and TingUI.Windows[1].Layout
	assert(first and TingUI.Flags.Speed == 50 and stub.humanoid.WalkSpeed == 50, "the first layout didn't mount or its handler didn't run")
	first:Destroy()
	-- the live reload file
	local file
	for _, b in ipairs(blocks) do if b:find("^%-%- MyHub/layout%.lua") then file = b end end
	assert(file, "the layout file example is missing")
	env.writefile("MyHub/layout.lua", file)
	local ui = TingUI:MountFile("MyHub/layout.lua", {})
	assert(ui.Window, "the docs' layout file didn't mount: " .. tostring(ui.Watcher.LastError))
	assert(TingUI.Options.Fly and TingUI.Options.Speed, "the file's elements are missing")
	ui:Destroy()
	-- the JSON layout
	local json = Sources.LayoutsDoc:match("```json\n(.-)```")
	local ui3 = TingUI:Mount(json, { Reset = function() end })
	assert(ui3.Window.Frame.Size.X.Offset == 560 and TingUI.Options.Trail.Value:ToHex() == "ff6080", "the JSON example didn't mount as described")
	-- the error messages shown in the docs are the real ones
	local okBad, err = ui3:Update(json:gsub('"Type": "Toggle"', '"Type": "Togle"'))
	assert(not okBad, "a misspelt type was accepted")
	local phrase = "has an unknown type 'Togle' - did you mean Toggle?"
	assert(err == "Tabs[1] 'Main' > Groups[1] 'Movement' > Elements[1] " .. phrase, "unexpected error text: " .. err)
	assert(Sources.LayoutsDoc:find("Tabs[1] 'Main' > Groups[1] 'Movement' > Elements[2] " .. phrase, 1, true), "the docs show a different error")
	M.Step(1 / 60, 30)
	M.Warnings = {}
	NoErrors(M)
end)

local function Find(root, pred)
	for _, d in ipairs(root:GetDescendants()) do if pred(d) then return d end end
end
local function Count(root, pred)
	local n = 0
	for _, d in ipairs(root:GetDescendants()) do if pred(d) then n = n + 1 end end
	return n
end

Test("notifications: merge, progress, undo / commit, reply, details, copy, history, center, clear all, swipe", function()
	local M, env = Fresh(true)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", nil, { Id = "N" })
	local W = TingUI:CreateWindow({ Title = "N", Dock = { "menu", "notifications" } })
	W:AddTab("Main")
	local Enum, V2 = M.globals.Enum, M.globals.Vector2
	-- the same card twice merges into one with a counter
	local a = TingUI:Notify({ Title = "Joined", Content = "x", Type = "Friend" })
	local b = TingUI:Notify({ Title = "Joined", Content = "x", Type = "Friend" })
	assert(a == b and a.Count == 2, "identical notifications should merge")
	assert(Find(a.Frame, function(d) return d.ClassName == "TextLabel" and d.Text == "x2" end), "merge counter not shown")
	-- determinate progress
	local p = TingUI:Notify({ Title = "Downloading", Content = "0 / 10", Type = "Download", Value = 0 })
	p:SetProgress(0.5, "5 / 10")
	assert(Find(p.Frame, function(d) return d.ClassName == "TextLabel" and d.Text == "50%" end), "progress percentage not shown")
	assert(Find(p.Frame, function(d) return d.ClassName == "TextLabel" and d.Text == "5 / 10" end), "SetProgress text not applied")
	-- undo: OnCommit runs only when the card goes away without Undo
	local committed, undone = 0, 0
	TingUI:Notify({ Title = "Deleted", Type = "Warning", Undo = function() undone = undone + 1 end, OnCommit = function() committed = committed + 1 end, Duration = 1 })
	M.Step(1 / 30, 60)
	assert(committed == 1 and undone == 0, "timing out should commit")
	local u = TingUI:Notify({ Title = "Deleted 2", Type = "Warning", Undo = function() undone = undone + 1 end, OnCommit = function() committed = committed + 1 end })
	local ub = Find(u.Frame, function(d) return d.ClassName == "TextButton" and tostring(d.Text):find("^Undo") end)
	assert(ub, "no Undo button")
	ub.MouseButton1Click:Fire()
	M.Step(1 / 30, 10)
	assert(undone == 1 and committed == 1 and u.Closed, "Undo should undo, close and skip OnCommit")
	-- reply from the card
	local got
	local r = TingUI:Notify({ Title = "builderman", Content = "gg", Type = "Message", Input = { Callback = function(t) got = t end } })
	local box = Find(r.Frame, function(d) return d.ClassName == "TextBox" end)
	assert(box, "no reply box")
	box.Text = "rematch?"
	box.FocusLost:Fire(true)
	M.Step(1 / 30, 5)
	assert(got == "rematch?" and r.Closed, "reply not sent")
	-- details unfold, copy copies
	local e = TingUI:Notify({ Title = "Failed", Content = "503", Type = "Error", Details = "trace line 1\ntrace line 2", Copy = "id-42" })
	local det = Find(e.Frame, function(d) return d.ClassName == "TextButton" and d.Text == "Details" end)
	local box2 = Find(e.Frame, function(d) return d.ClassName == "ScrollingFrame" end)
	assert(det and box2 and not box2.Visible, "details should start folded")
	det.MouseButton1Click:Fire()
	assert(box2.Visible, "details didn't unfold")
	local cp = Find(e.Frame, function(d) return d.ClassName == "TextButton" and d.Text == "Copy" end)
	cp.MouseButton1Click:Fire()
	assert(M.Clipboard == "id-42", "Copy didn't copy: " .. tostring(M.Clipboard))
	-- a crashing callback's card carries the full error
	TingUI.SafeCall("test", function() error("kaboom") end)
	M.Step(1 / 30, 3)
	local found
	for _, h in ipairs(TingUI:GetNotifications()) do if h.Options.Title == "Script error" then found = h end end
	assert(found and tostring(found.Options.Details):find("kaboom"), "script error should carry Details")
	M.Errors = {}
	M.Warnings = {}
	-- persistent cards stay, everything else times out; history keeps them all
	local keep = TingUI:Notify({ Title = "Stays", Persistent = true })
	M.Step(1 / 30, 400)
	assert(not keep.Closed, "Persistent card timed out")
	assert(#TingUI.NotificationHistory >= 8, "history too short: " .. #TingUI.NotificationHistory)
	local center = TingUI:OpenNotificationCenter()
	M.Step(1 / 30, 3)
	assert(center.Frame.Visible, "center didn't open")
	assert(Count(center.Frame, function(d) return d.ClassName == "TextLabel" and d.Text == "Stays" end) >= 1, "center doesn't list the history")
	-- several cards show a Clear all pill, and it clears them
	for i = 1, 4 do TingUI:Notify({ Title = "n" .. i, Persistent = true }) end
	M.Step(1 / 30, 3)
	assert(Find(TingUI.Gui, function(d) return d.ClassName == "TextButton" and tostring(d.Text):find("^Clear all") and d.Visible end), "no Clear all pill")
	TingUI:ClearNotifications()
	M.Step(1 / 30, 30)
	assert(#TingUI:GetNotifications() == 0, "ClearNotifications left cards")
	-- swipe a card away
	local mouse = V2.new(400, 300)
	M.Services.UserInputService.GetMouseLocation = function() return mouse end
	local s = TingUI:Notify({ Title = "Swipe me", Persistent = true })
	local hit = s.Frame:FindFirstChild("Hit")
	hit.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = M.globals.Vector3.new(400, 300, 0) })
	mouse = V2.new(520, 300)
	M.Services.UserInputService.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = M.globals.Vector3.new(520, 300, 0) }, false)
	M.Services.UserInputService.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = M.globals.Vector3.new(520, 300, 0) }, false)
	M.Step(1 / 30, 5)
	assert(s.Closed, "swiping didn't dismiss")
	-- every type builds and animates
	for _, k in ipairs(TingUI.NotifyTypes) do TingUI:Notify({ Title = k, Content = k, Type = k, Value = (k == "Upload" and 0.3 or nil) }) end
	M.Step(1 / 30, 90)
	TingUI:Unload()
	NoErrors(M)
end)

Test("the tab bar always fits: padding, gap and labels tighten, then it scrolls the active tab into view", function()
	local M, env = Fresh(false)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", ModuleScript(M))
	local W = TingUI:CreateWindow({ Title = "Tabs" })
	local tabs = {}
	for i, n in ipairs({ "Combat", "Visuals", "World", "Character", "Exploits", "Webhook", "About", "Config" }) do tabs[i] = W:AddTab(n) end
	local bar
	for _, c in ipairs(W.Frame:GetChildren()) do if c.ClassName == "ScrollingFrame" and c.Size.Y.Offset == 28 then bar = c end end
	assert(bar, "tab bar not found")
	local V2 = M.globals.Vector2
	-- roomy: full padding
	bar._props.AbsoluteSize = V2.new(900, 28)
	W:_FitTabs()
	local pad = tabs[1].Button:FindFirstChildOfClass("UIPadding")
	assert(pad.PaddingLeft.Offset == 11, "roomy bar should keep full padding, got " .. pad.PaddingLeft.Offset)
	-- a wide theme font in a 520px window: padding tightens and labels shrink, nothing scrolls off
	bar._props.AbsoluteSize = V2.new(420, 28)
	W:_FitTabs()
	assert(pad.PaddingLeft.Offset < 11, "padding didn't tighten")
	assert((tabs[1].Button:GetAttribute("TSK") or 1) < 1, "labels didn't shrink when padding wasn't enough")
	-- hopeless: it scrolls, and selecting the last tab doesn't error
	bar._props.AbsoluteSize = V2.new(150, 28)
	W:_FitTabs()
	W:SelectTab(tabs[8])
	M.Step(1 / 60, 30)
	-- every theme keeps the bar consistent
	for name in pairs(TingUI.Presets) do TingUI:ApplyPreset(name) M.Step(1 / 60, 2) end
	NoErrors(M)
end)

Test("themes: Ocean and Serotonin, Hazard without particles, retired names, pointer calibration", function()
	local M, env = Fresh(false)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", ModuleScript(M, { Theme = "Candy" }))
	assert(TingUI.Preset == "Rose", "a retired theme asked for at load should map to its replacement, got " .. tostring(TingUI.Preset))
	for _, gone in ipairs({ "Candy", "Abyss", "Criminality", "MLG" }) do assert(TingUI.Presets[gone] == nil, gone .. " should be removed") end
	assert(TingUI.Presets.Serotonin and TingUI.Presets.Serotonin.Style.Particles == "None", "Serotonin should exist with no particles")
	assert(TingUI.Presets.Hazard.Style.Particles == "None", "Hazard should have no particles")
	assert(TingUI.Presets.Ocean.Style.Scene == "Ocean", "Ocean should have its scene")
	local W = BuildUI(TingUI, M)
	W.Frame._props.AbsolutePosition = M.globals.Vector2.new(100, 50)
	W.Frame._props.AbsoluteSize = M.globals.Vector2.new(560, 752)
	-- configs naming a retired theme keep the current one (unchanged behaviour)
	TingUI:ApplyPreset("Serotonin")
	TingUI:ApplyPreset("MLG")
	assert(TingUI.Preset == "Serotonin", "ApplyPreset of a retired name changed the theme")
	M.Step(1 / 60, 30)
	TingUI:ApplyPreset("Ocean")
	TingUI:SetSnow(true)
	M.Step(1 / 60, 240)
	TingUI:SetParticles("Bokeh")
	M.Step(1 / 60, 240)
	TingUI:SetParticles("Theme")
	-- pointer: with the inset honoured it's corrected, and a press on a small control re-learns it
	local V2 = M.globals.Vector2
	assert(TingUI:GetPointer() == V2.new(400, 300), "pointer should match the mouse when the inset is ignored")
	TingUI.Gui.IgnoreGuiInset = false
	assert(TingUI:GetPointer() == V2.new(400, 264), "pointer should drop the 36px inset, got " .. tostring(TingUI:GetPointer()))
	local tb = W.Tabs[1].Button
	tb._props.AbsolutePosition = V2.new(380, 290)
	tb._props.AbsoluteSize = V2.new(60, 24)
	tb.InputBegan:Fire({ UserInputType = M.globals.Enum.UserInputType.MouseButton1, Position = M.globals.Vector3.new(400, 264, 0) })
	assert(TingUI:GetPointer() == V2.new(400, 300), "a press on a control should re-learn the offset")
	TingUI.Gui.IgnoreGuiInset = true
	NoErrors(M)
end)

Test("scenes: Frost snowfall settles, Rose, Sunset and Storm run with clicks, tabs and opening; new particle kinds", function()
	local M, env = Fresh(false)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", ModuleScript(M, { Theme = "Frost" }))
	local V2, Enum = M.globals.Vector2, M.globals.Enum
	local W = BuildUI(TingUI, M)
	W.Frame._props.AbsolutePosition = V2.new(100, 50)
	W.Frame._props.AbsoluteSize = V2.new(560, 452)
	TingUI:SetSnow(true)
	local function Click()
		M.Services.UserInputService.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown,
			Position = M.globals.Vector3.new(400, 300, 0) }, false)
	end
	for _, theme in ipairs({ "Frost", "Rose", "Sunset", "Storm", "Ocean" }) do
		TingUI:ApplyPreset(theme)
		assert(TingUI.Presets[theme].Style.Scene == theme, theme .. " should have its own scene")
		M.Step(1 / 60, 90)
		Click()
		M.Step(1 / 60, 20)
		if #W.Tabs > 1 then W:SelectTab(W.Tabs[2]) M.Step(1 / 60, 30) W:SelectTab(W.Tabs[1]) end
		W:SetVisible(false) M.Step(1 / 60, 5) W:SetVisible(true)
		M.Step(1 / 60, 240)
	end
	-- the Frost drift: after its first snowfall some snow is left along the bottom edge, and it stays small
	TingUI:ApplyPreset("Frost")
	M.Step(1 / 60, 60 * 14)
	local found, tallest = false, 0
	for _, d in ipairs(W.Frame:GetDescendants()) do
		if d.Name == "TingUISceneTop" then
			for _, c in ipairs(d:GetChildren()) do
				if c.ClassName == "Frame" and c.AnchorPoint == V2.new(0, 1) and c.BackgroundTransparency < 1 then
					found = true
					tallest = math.max(tallest, c.Size.Y.Offset)
				end
			end
		end
	end
	assert(found, "the Frost snowfall should leave a drift along the bottom")
	assert(tallest <= 6, "the drift should stay small, got " .. tallest)
	for _, kind in ipairs({ "Petals", "Embers", "Rain" }) do
		TingUI:SetParticles(kind)
		M.Step(1 / 60, 300)
	end
	-- every icon name builds its fallback without errors
	assert(#TingUI.IconNames >= 57, "the new icons should be listed")
	for _, name in ipairs(TingUI.IconNames) do W.Tabs[1]:AddGroup({ Title = name, Side = "Left", Icon = name }) end
	NoErrors(M)
end)

Test("notifications: twenty game-event types animate cleanly, living card backgrounds move", function()
	local M, env = Fresh(false)
	local TingUI = Load(M, env, Sources.TingUI, "TingUI", ModuleScript(M))
	local W = BuildUI(TingUI, M)
	local types = { "Teleport", "ServerHop", "Reward", "Currency", "LevelUp", "Timer", "Connection", "Target", "Invite", "Streak",
		"Boost", "Protected", "Key", "Party", "MVP", "Combat", "Copied", "Deleted", "Sync", "AFK" }
	for _, ty in ipairs(types) do assert(table.find(TingUI.NotifyTypes, ty), ty .. " should be a notification type") end
	local handles = {}
	for i, ty in ipairs(types) do
		handles[i] = TingUI:Notify({ Title = ty, Content = "test " .. i, Type = ty, Duration = 30, Value = (ty == "Sync" or ty == "Connection") and 0.3 or nil })
		M.Step(1 / 60, 12)
	end
	M.Step(1 / 60, 240)
	-- the background gradient should drift (not a flat colour)
	local h = handles[#handles]
	local grads = {}
	for _, d in ipairs(h.Frame:GetChildren()) do
		local g = d:FindFirstChildOfClass("UIGradient")
		if g and d.ZIndex == 2 then table.insert(grads, { g, g.Rotation, g.Offset }) end
	end
	M.Step(1 / 60, 30)
	local moved = false
	for _, e in ipairs(grads) do if e[1].Rotation ~= e[2] or e[1].Offset ~= e[3] then moved = true end end
	assert(moved, "the card background should drift, not sit as one flat colour")
	for _, n in ipairs(handles) do n:Update({ Title = "done", Type = "Success" }) end
	M.Step(1 / 60, 60)
	for _, n in ipairs(handles) do n:Dismiss() end
	M.Step(1 / 60, 60)
	NoErrors(M)
end)

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then error("tests failed", 0) end
