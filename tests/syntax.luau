-- syntax.luau — يترجم كل ملفات المصدر (هذه النسخة من Lune بلا أمر check).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local FILES = {
	"src/shared/Config.luau",
	"src/shared/Format.luau",
	"src/shared/Rules.luau",
	"src/server/Store.luau",
	"src/server/Builder.luau",
	"src/server/Play.luau",
	"src/server/Shop.luau",
	"src/server/Main.server.luau",
	"src/client/UI.client.luau",
}

local failed = 0
for _, path in FILES do
	local ok, err = pcall(luau.load, fs.readFile(path))
	if ok then
		print("OK   " .. path)
	else
		failed += 1
		print("FAIL " .. path .. " -> " .. tostring(err))
	end
end
if failed > 0 then
	print(failed .. " file(s) failed to compile")
	process.exit(1)
end
print("All " .. #FILES .. " source files compile")
