-- world.luau — ينفّذ Builder الحقيقي تحت واجهة Roblox وهمية صارمة
-- (أي اسم Enum غير صالح يفجّر الاختبار) ثم يفحص بنية العالم كاملة.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Config = require("../src/shared/Config")
local Format = require("../src/shared/Format")

-- ===== Enums صارمة =====
local ENUMS = {
	Material = { SmoothPlastic = 1, Neon = 1, Plastic = 1, Glass = 1 },
	SurfaceType = { Smooth = 1 },
	SurfaceGuiSizingMode = { PixelsPerStud = 1, PixelsPerUnit = 1 },
	NormalId = { Top = 1, Bottom = 1, Front = 1, Back = 1, Left = 1, Right = 1 },
	Font = { FredokaOne = 1, GothamBold = 1 },
	PartType = { Block = 1, Ball = 1, Cylinder = 1 },
}
local Enum = setmetatable({}, {
	__index = function(_, enumType)
		local members = ENUMS[enumType]
		if not members then
			error("unknown Enum type: " .. tostring(enumType))
		end
		return setmetatable({}, {
			__index = function(_, member)
				if not members[member] then
					error("INVALID enum member Enum." .. enumType .. "." .. tostring(member))
				end
				return "Enum." .. enumType .. "." .. member
			end,
		})
	end,
})

-- ===== Instances وهمية =====
local function newInst(class)
	local inst = { __class = class, __props = {}, __children = {}, __attrs = {}, __parent = nil }
	return setmetatable(inst, {
		__index = function(t, k)
			if k == "SetAttribute" then
				return function(self, n, v)
					rawget(self, "__attrs")[n] = v
				end
			elseif k == "GetAttribute" then
				return function(self, n)
					return rawget(self, "__attrs")[n]
				end
			elseif k == "FindFirstChild" then
				return function(self, n)
					for _, c in rawget(self, "__children") do
						if rawget(c, "__props").Name == n then
							return c
						end
					end
					return nil
				end
			elseif k == "WaitForChild" then
				return function(self, n)
					local hit = self:FindFirstChild(n)
					if not hit then
						error("WaitForChild: no child " .. tostring(n))
					end
					return hit
				end
			elseif k == "GetChildren" then
				return function(self)
					return rawget(self, "__children")
				end
			elseif k == "Destroy" then
				return function(self)
					local p = rawget(self, "__parent")
					if p then
						local kids = rawget(p, "__children")
						for i, c in kids do
							if c == self then
								table.remove(kids, i)
								break
							end
						end
					end
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

local lighting = newInst("Lighting")
local workspaceInst = newInst("Workspace")
local C1, F1 = {}, {}
local SharedTable = { Config = C1, Format = F1 }
local gameMock = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return {
				WaitForChild = function(_, n)
					assert(n == "Shared", "unexpected WaitForChild " .. tostring(n))
					return SharedTable
				end,
			}
		elseif name == "Lighting" then
			return lighting
		end
		error("unexpected service " .. tostring(name))
	end,
}

local Builder = luau.load(fs.readFile("src/server/Builder.luau"), {
	debugName = "Builder",
	environment = {
		Instance = { new = newInst },
		Vector3 = {
			new = function(x, y, z)
				return { X = x, Y = y, Z = z }
			end,
		},
		Color3 = {
			fromRGB = function(r, g, b)
				return { R = r, G = g, B = b }
			end,
			new = function(r, g, b)
				return { R = r, G = g, B = b }
			end,
		},
		UDim2 = {
			fromScale = function(a, b)
				return { __udim2 = { a, b } }
			end,
		},
		Enum = Enum,
		game = gameMock,
		workspace = workspaceInst,
		require = function(x)
			if x == C1 then
				return Config
			elseif x == F1 then
				return Format
			end
			error("unexpected require target")
		end,
		print = print,
		string = string,
		math = math,
		table = table,
		tonumber = tonumber,
		tostring = tostring,
		ipairs = ipairs,
		pairs = pairs,
		type = type,
	},
})()

local result = Builder.build()
assert(result and result.levelLabels and result.winsLabels, "build returns board labels")

-- ===== فحص البنية =====
local passed, failed = 0, 0
local function eq(got, want, label)
	if got == want then
		passed += 1
	else
		failed += 1
		print(("FAIL %s: got %s want %s"):format(label, tostring(got), tostring(want)))
	end
end
local function ok(cond, label)
	eq(cond and true or false, true, label)
end

local root = workspaceInst:FindFirstChild("PhoneWorld")
ok(root ~= nil, "PhoneWorld exists")

local counts = { Icon = 0, Station = 0, Enter = 0, Cell = 0, Star = 0, Mid = 0, Begin = 0, Finish = 0, Kill = 0, Move = 0, Sweep = 0, Belt = 0, Bounce = 0 }
local portalAttrs = 0
local stageFolders = {}
local gates = {}
local spawnFound, teaserFound = false, false
local function walk(node)
	local attrs = rawget(node, "__attrs")
	for key, value in attrs do
		if counts[key] ~= nil and value then
			counts[key] += 1
		end
		if string.find(key, "Portal") then
			portalAttrs += 1
		end
	end
	local name = rawget(node, "__props").Name
	if name == "Gate" and attrs.Need ~= nil then
		table.insert(gates, node)
	end
	if rawget(node, "__class") == "SpawnLocation" then
		spawnFound = true
	end
	if name == "IslandBase" then
		teaserFound = true
	end
	local idx = name and string.match(name, "^Stage_(%d+)$")
	if idx and rawget(node, "__class") == "Folder" then
		stageFolders[tonumber(idx)] = node
	end
	for _, c in rawget(node, "__children") do
		walk(c)
	end
end
walk(root)

eq(counts.Icon, 144, "144 charge nodes")
eq(counts.Station, 8, "8 stations")
eq(counts.Enter, 15, "15 tower enter pads")
eq(#gates, 15, "15 gate signs")
eq(counts.Cell, 9, "9 battery cells")
eq(counts.Star, 15, "15 stars (5 split sections x3)")
eq(counts.Mid, 2, "2 mid checkpoints")
eq(counts.Begin, 15, "15 begin pads")
eq(counts.Finish, 15, "15 finish pads")
eq(counts.Kill, 16, "kill floors: 15 stages + void")
ok(counts.Move >= 3, "movers present")
ok(counts.Sweep >= 4, "sweepers present")
ok(counts.Bounce >= 4, "bounce pads present")
ok(counts.Belt >= 4, "conveyors present")
eq(portalAttrs, 0, "no portal attributes anywhere")
ok(spawnFound, "SpawnLocation exists")
ok(teaserFound, "W2 teaser exists")

local folderCount, bossCount = 0, 0
for i, sf in stageFolders do
	folderCount += 1
	if rawget(sf, "__attrs").Boss then
		bossCount += 1
	end
	local hasBegin, hasFinish, hasKill, hasEnter = false, false, false, false
	for _, c in rawget(sf, "__children") do
		local a = rawget(c, "__attrs")
		if a.Begin == i then
			hasBegin = true
		end
		if a.Finish == i then
			hasFinish = true
		end
		if a.Kill then
			hasKill = true
		end
		if a.Enter == i then
			hasEnter = true
		end
	end
	ok(hasBegin and hasFinish and hasKill and hasEnter, "stage " .. i .. " has begin+finish+kill+enter")
end
eq(folderCount, 15, "15 stage folders")
eq(bossCount, 3, "3 boss folders")

for gi, gate in gates do
	ok(rawget(gate, "__attrs").Need ~= nil, "gate sign " .. gi .. " carries a Need level")
end
local needs = {}
for _, gate in gates do
	needs[rawget(gate, "__attrs").Need] = true
end
for i, def in Config.STAGES do
	ok(needs[def.req] == true, "a gate sign shows stage " .. i .. " requirement " .. def.req)
end

print(("world: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
	process.exit(1)
end
