--[[
	Lumen is now TingUI. This file only keeps old links working:

		loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Lumen.lua"))(options)

	loads TingUI.lua from the same repo (GitHub, then the jsDelivr mirror) with the same options and returns it.
	Nothing else in your script needs to change. Point your link at TingUI.lua whenever it suits you.
]]

local args = table.pack(...)
local env = (getgenv and getgenv()) or _G
if args.n == 0 and type(env.LumenOptions) == "table" then
	args = table.pack(env.LumenOptions)
	env.LumenOptions = nil
end

local src
for _, url in ipairs({
	"https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/TingUI.lua",
	"https://cdn.jsdelivr.net/gh/Irakli17/Ui-Library-Test@main/TingUI.lua",
}) do
	local ok, body = pcall(function() return game:HttpGet(url) end)
	if ok and type(body) == "string" and body:find("TingUI Library", 1, true) then src = body break end
end
if not src then error("[TingUI] couldn't download TingUI.lua (Lumen was renamed to TingUI)", 0) end
return loadstring(src, "=TingUI")(table.unpack(args, 1, args.n))
