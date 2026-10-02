--[[
    ChaseUI — Feature Demo
    ----------------------
    This script shows off EVERY ChaseUI feature in one window.
    It is a demo only: the callbacks just print / notify so you can see
    things firing. Swap the loader URL for your own raw GitHub link.

    Controls:
      • RightShift      toggle the window (desktop)
      • Floating "C"    reopen on mobile / after minimise
--]]

-- Load the library (replace with YOUR raw GitHub URL once uploaded):
local ChaseUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/USER/REPO/main/ChaseUI.lua"))()

-- If you are testing locally with the file next to this one, you can instead do:
-- local ChaseUI = require(script.Parent.ChaseUI)

-- CHUNK_A

local Window = ChaseUI:CreateWindow({
    Title     = "ChaseUI Demo",
    Name      = "ChaseUI_Demo",            -- ScreenGui / config folder name
    Size      = UDim2.fromOffset(600, 440),
    Accent    = Color3.fromRGB(120, 90, 255), -- black base, custom accent
    ToggleKey = Enum.KeyCode.RightShift,
    ToggleIcon = "C",
    -- Optional key gate — uncomment to require a key before the UI opens:
    -- KeySystem = { Title = "ChaseUI Demo", Keys = { "chase123" }, Note = "Key is: chase123" },
})

-- CHUNK_B

-- ============================= MAIN TAB =============================
local Main = Window:CreateTab("Main", "🏠")

Main:CreateSection("Buttons & Toggles")

Main:CreateButton({
    Name = "Show Notification",
    Callback = function()
        ChaseUI:Notify({ Title = "Hello!", Content = "This is a ChaseUI notification.", Duration = 4 })
    end,
})

Main:CreateToggle({
    Name = "Enable Feature",
    Default = false,
    Flag = "FeatureEnabled",   -- saved by config
    Callback = function(state)
        print("[Demo] Feature toggled:", state)
    end,
})

Main:CreateSection("Sliders")

Main:CreateSlider({
    Name = "Walk Speed",
    Min = 16, Max = 300, Increment = 1, Suffix = " studs/s",
    Default = 16,
    Flag = "WalkSpeed",
    Callback = function(v)
        local char = game.Players.LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end,
})

Main:CreateSlider({
    Name = "FOV (decimals)",
    Min = 0, Max = 1, Increment = 0.05,
    Default = 0.5,
    Callback = function(v) print("[Demo] FOV:", v) end,
})

-- CHUNK_C

-- ========================== INPUTS TAB ==========================
local Inputs = Window:CreateTab("Inputs", "⌨️")

Inputs:CreateSection("Dropdowns")

Inputs:CreateDropdown({
    Name = "Choose Mode",
    Options = { "Idle", "Walk", "Run", "Fly" },
    Default = "Idle",
    Flag = "Mode",
    Callback = function(choice) print("[Demo] Mode:", choice) end,
})

local multi = Inputs:CreateDropdown({
    Name = "Enabled ESP (multi)",
    Options = { "Names", "Boxes", "Health", "Distance" },
    Multi = true,
    Default = { "Names" },
    Callback = function(set) print("[Demo] ESP:", table.concat(set, ", ")) end,
})

Inputs:CreateSection("Text, Keybind & Color")

Inputs:CreateInput({
    Name = "Target Name",
    Placeholder = "type a username…",
    ClearOnFocus = false,
    Flag = "TargetName",
    Callback = function(text, enterPressed)
        print("[Demo] Input:", text, "enter:", enterPressed)
    end,
})

Inputs:CreateKeybind({
    Name = "Panic Key",
    Default = Enum.KeyCode.F,
    Flag = "PanicKey",
    Callback = function() ChaseUI:Notify({ Title = "Panic!", Content = "Keybind fired." }) end,
})

Inputs:CreateColorPicker({
    Name = "Accent Color",
    Default = Color3.fromRGB(120, 90, 255),
    Flag = "AccentColor",
    Callback = function(color) ChaseUI:SetAccent(color) end, -- live retheme
})

-- CHUNK_D

-- ========================== THEME TAB ==========================
local ThemeTab = Window:CreateTab("Theme", "🎨")

ThemeTab:CreateParagraph({
    Title = "Theming",
    Content = "Black is the default base. Every colour is changeable at runtime "
        .. "with ChaseUI:SetTheme{...} or ChaseUI:SetAccent(color). Try the presets below.",
})

ThemeTab:CreateButton({ Name = "Accent: Purple", Callback = function() ChaseUI:SetAccent(Color3.fromRGB(140, 90, 255)) end })
ThemeTab:CreateButton({ Name = "Accent: Green",  Callback = function() ChaseUI:SetAccent(Color3.fromRGB(60, 210, 120)) end })
ThemeTab:CreateButton({ Name = "Accent: Red",    Callback = function() ChaseUI:SetAccent(Color3.fromRGB(240, 70, 70)) end })

ThemeTab:CreateDivider()

ThemeTab:CreateButton({
    Name = "Lighter Background",
    Callback = function()
        ChaseUI:SetTheme({
            Background = Color3.fromRGB(24, 24, 30),
            Element    = Color3.fromRGB(34, 34, 42),
            Topbar     = Color3.fromRGB(20, 20, 26),
        })
    end,
})
ThemeTab:CreateButton({
    Name = "Reset to Black",
    Callback = function()
        ChaseUI:SetTheme({
            Background = Color3.fromRGB(14, 14, 16),
            Element    = Color3.fromRGB(24, 24, 28),
            Topbar     = Color3.fromRGB(10, 10, 12),
        })
    end,
})

-- CHUNK_E

-- ========================== CONFIG TAB ==========================
local Config = Window:CreateTab("Config", "💾")

Config:CreateParagraph({
    Title = "Config save / load",
    Content = "Every element with a Flag is written to a JSON file. "
        .. "Works on executors that expose writefile/readfile.",
})

local CONFIG_PATH = "ChaseUI/demo_config.json"

Config:CreateButton({
    Name = "Save Config",
    Callback = function()
        local ok, err = ChaseUI:SaveConfig(CONFIG_PATH)
        ChaseUI:Notify({ Title = ok and "Saved" or "Save failed", Content = ok and CONFIG_PATH or tostring(err) })
    end,
})
Config:CreateButton({
    Name = "Load Config",
    Callback = function()
        local ok = ChaseUI:LoadConfig(CONFIG_PATH)
        ChaseUI:Notify({ Title = ok and "Loaded" or "Load failed", Content = ok and CONFIG_PATH or "no config found" })
    end,
})

Config:CreateDivider()
Config:CreateButton({ Name = "Read a Flag (WalkSpeed)", Callback = function()
    ChaseUI:Notify({ Title = "WalkSpeed flag", Content = tostring(ChaseUI:GetFlag("WalkSpeed")) })
end })
Config:CreateButton({ Name = "Destroy UI", Callback = function() ChaseUI:Destroy() end })

-- ========================== START ==========================
Window:SelectTab(Main)
ChaseUI:Notify({ Title = "ChaseUI loaded", Content = "Press RightShift to toggle. Enjoy!", Duration = 5 })




