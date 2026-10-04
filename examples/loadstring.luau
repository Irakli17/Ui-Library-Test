--[[
	Vantage · examples/loadstring.luau
	==================================================================
	The smallest possible install: fetch the single file from GitHub and
	run it. Nothing here needs Studio, Rojo, or an upload.

	Paste it into an executor, or into any context where `loadstring` is
	available (Studio needs ServerScriptService.LoadStringEnabled).
]]

local USER = "Irakli17"
local REPO = "Ui-Library-Test"
local BRANCH = "main"

--- `dist/Vantage.min.luau` is the smaller of the two builds; swap it for
--- `Vantage.luau` (or `dist/Vantage.luau`) for the annotated one.
local URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/Vantage.luau", USER, REPO, BRANCH)

--- jsDelivr mirrors the same bytes with better caching, which is worth
--- having as a fallback when raw.githubusercontent.com rate-limits.
local MIRROR = string.format("https://cdn.jsdelivr.net/gh/%s/%s@%s/Vantage.luau", USER, REPO, BRANCH)

local function fetch(url)
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(body) == "string" and #body > 0 then
		return body
	end
	return nil
end

local source = fetch(URL) or fetch(MIRROR)
if not source then
	error("[Vantage] could not download the library from " .. URL)
end

local chunk, compileError = loadstring(source, "Vantage")
if not chunk then
	error("[Vantage] could not compile the downloaded file: " .. tostring(compileError))
end

local Vantage = chunk()

--[[ Use it ------------------------------------------------------------ ]]

Vantage.Setup({ Theme = "obsidian" })

local window = Vantage.Window.new({
	Name = "Vantage",
	Subtitle = "loaded from GitHub",
})

local general = window:Tab({ Name = "General", Icon = "sliders" })
local section = general:Section({ Name = "Hello", Description = "This window was fetched over HTTP." })

section:Toggle({ Name = "Reduce motion", Value = false, Callback = print })
section:Button({
	Text = "Notify me",
	Variant = "primary",
	Callback = function()
		Vantage.Notify.new({ layer = window.NotifyLayer }):push({
			Title = "Vantage",
			Body = "Version " .. Vantage.version .. " is running.",
			Tone = "success",
		})
	end,
})

print(string.format("[Vantage] %s loaded via loadstring", Vantage.version))
