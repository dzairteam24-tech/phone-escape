-- Compile-check every Luau source file (Roblox APIs are not executed, only parsed).
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local files = {
	"src/shared/Config.luau",
	"src/shared/NumberFormat.luau",
	"src/shared/Economy.luau",
	"src/server/DataService.luau",
	"src/server/MapBuilder.luau",
	"src/server/SpeedService.luau",
	"src/server/StageService.luau",
	"src/server/ShopService.luau",
	"src/server/QuestService.luau",
	"src/server/ServerMain.server.luau",
	"src/client/ClientMain.client.luau",
}
local bad = 0
for _, path in files do
	local source = fs.readFile(path)
	local ok, err = pcall(function()
		luau.load(source, { debugName = path })
	end)
	if ok then
		print("OK  ", path)
	else
		bad += 1
		print("BAD ", path, err)
	end
end
if bad > 0 then
	error(bad .. " files failed to compile")
end
print("All files compile.")
