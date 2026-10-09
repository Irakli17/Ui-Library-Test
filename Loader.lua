--[[
	Lumen loader: a sturdier way to loadstring the library.

	local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/Irakli17/Ui-Library-Test/main/Loader.lua"))()({
		Id = "MyHub",          -- any Lumen load option (Id, Theme, Folder, Font, ...)
		Version = "main",      -- branch or tag to load, e.g. "v0.0.2-stable" to pin a release
	})

	What it does:
	  1. tries raw.githubusercontent.com, then the jsDelivr CDN mirror (handy when GitHub is slow or blocked)
	  2. checks the download really is Lumen before running it
	  3. keeps a copy on disk (if your executor has writefile) and falls back to it when you're offline
	  4. returns nil + a readable error instead of crashing your script
]]

local REPO = "Irakli17/Ui-Library-Test"

local function Fetch(url)
	local ok, body = pcall(function() return game:HttpGet(url) end)
	if ok and type(body) == "string" and #body > 1000 and body:find("Lumen UI Library", 1, true) then
		return body
	end
	return nil, ok and "unexpected response" or tostring(body)
end

return function(options)
	options = options or {}
	local version = options.Version or "main"
	local sources = {
		("https://raw.githubusercontent.com/%s/%s/Lumen.lua"):format(REPO, version),
		("https://cdn.jsdelivr.net/gh/%s@%s/Lumen.lua"):format(REPO, version),
	}
	local folder = options.Folder or "Lumen"
	local cachePath = folder .. "/Lumen-" .. version:gsub("[^%w%.%-]", "_") .. ".lua"
	local canFile = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
		and type(isfolder) == "function" and type(makefolder) == "function"

	local src, lastErr
	for _, url in ipairs(sources) do
		src, lastErr = Fetch(url)
		if src then break end
	end

	if src and canFile then
		pcall(function()
			if not isfolder(folder) then makefolder(folder) end
			writefile(cachePath, src)
		end)
	elseif not src and canFile then
		pcall(function()
			if isfile(cachePath) then
				src = readfile(cachePath)
				warn("[Lumen] couldn't download the library, using the cached copy (" .. cachePath .. ")")
			end
		end)
	end

	if not src then
		local msg = "[Lumen] couldn't download the library: " .. tostring(lastErr)
		warn(msg)
		return nil, msg
	end

	local chunk, compileErr = loadstring(src, "=Lumen")
	if not chunk then
		warn("[Lumen] failed to compile: " .. tostring(compileErr))
		return nil, compileErr
	end
	local ok, lib = pcall(chunk, options)
	if not ok then
		warn("[Lumen] failed to start: " .. tostring(lib))
		return nil, lib
	end
	return lib
end
