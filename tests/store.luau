-- store.luau — اختبار انحدار: GetDataStore يرمي (مكان غير منشور) يجب
-- ألا يقتل Store: التحميل يعيد الافتراضي ويربط leaderstats والحفظ صامت.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local function newInst(class)
	local inst = { __class = class, __props = {}, __children = {}, __attrs = {}, __parent = nil }
	return setmetatable(inst, {
		__index = function(t, k)
			if k == "FindFirstChild" then
				return function(self, n)
					for _, c in rawget(self, "__children") do
						if rawget(c, "__props").Name == n then
							return c
						end
					end
					return nil
				end
			end
			return rawget(t, "__props")[k]
		end,
		__newindex = function(t, k, v)
			if k == "Parent" then
				rawset(t, "__parent", v)
				if v then
					table.insert(rawget(v, "__children"), t)
				end
				return
			end
			rawget(t, "__props")[k] = v
		end,
	})
end

local RULES = {}
local gameStub = {
	GetService = function(_, name)
		if name == "DataStoreService" then
			return {
				GetDataStore = function()
					error("DataStores are not available in unpublished places")
				end,
			}
		elseif name == "RunService" then
			return { IsStudio = function() return true end }
		elseif name == "Players" then
			return {}
		elseif name == "ReplicatedStorage" then
			local rulesHolder = { Rules = RULES }
			local sharedNode = {
				WaitForChild = function(_, k)
					return rulesHolder[k]
				end,
			}
			return {
				WaitForChild = function()
					return sharedNode
				end,
			}
		end
		error("unexpected service " .. tostring(name))
	end,
	BindToClose = function() end,
}

local Store = luau.load(fs.readFile("src/server/Store.luau"), {
	debugName = "Store",
	environment = {
		game = gameStub,
		Instance = { new = newInst },
		require = function(x)
			if x == RULES then
				return {
					level = function()
						return 1, 0, 100
					end,
				}
			end
			error("unexpected require")
		end,
		print = print,
		warn = print,
		string = string,
		math = math,
		table = table,
		pairs = pairs,
		ipairs = ipairs,
		type = type,
		tostring = tostring,
		os = os,
		task = task,
	},
})()

local player = newInst("Player")
player.Name = "Tester"
player.UserId = 999

local data = Store.load(player)
assert(data ~= nil and data.charge == 0, "load returns defaults despite DataStore throwing")
assert(Store.profiles[player] == data, "profile registered")
local stats = player:FindFirstChild("leaderstats")
assert(stats ~= nil, "leaderstats bound despite DataStore throwing")
data.charge = 1234
Store.sync(player)
local chargeVal
for _, c in rawget(stats, "__children") do
	if rawget(c, "__props").Name == "Charge" then
		chargeVal = rawget(c, "__props").Value
	end
end
assert(chargeVal == 1234, "sync writes leaderstats (got " .. tostring(chargeVal) .. ")")
Store.save(player) -- يجب ألا يرمي
print("store: DataStore-throw regression PASSED")
process.exit(0)
