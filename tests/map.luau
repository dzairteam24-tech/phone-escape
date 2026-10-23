-- tests/map.luau — run MapBuilder.build() against a mock Instance API with
-- STRICT enum validation: any enum member that does not really exist in
-- Roblox errors immediately (this is what would have caught the historic
-- "PixelPerStud" typo that silently killed the map in Studio).
-- Run from the project root:  lune run tests/map.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Config = require("../src/shared/Config")
local NumberFormat = require("../src/shared/NumberFormat")

local passed, failed = 0, 0
local function ok(cond, name)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL", name)
	end
end
local function eq(got, want, name)
	ok(got == want, name .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
end

-- ===== STRICT Enum mock: only real members exist ======================
local function enumGroup(groupName, members)
	local group = {}
	for memberName in members do
		group[memberName] = "Enum." .. groupName .. "." .. memberName
	end
	return setmetatable(group, {
		__index = function(_, key)
			error(("Invalid enum member: Enum.%s.%s does not exist"):format(groupName, tostring(key)), 2)
		end,
	})
end
local Enum = setmetatable({
	Material = enumGroup("Material", {
		SmoothPlastic = true, Plastic = true, Neon = true, Glass = true,
		Wood = true, WoodPlanks = true, Metal = true, DiamondPlate = true,
		Foil = true, Brick = true, Concrete = true, Marble = true, Slate = true,
		Sand = true, Rock = true, Grass = true, Ice = true, Snow = true,
		ForceField = true, Fabric = true, Pebble = true, Cobblestone = true,
	}),
	SurfaceGuiSizingMode = enumGroup("SurfaceGuiSizingMode", {
		FixedSize = true, PixelsPerStud = true, -- NOT "PixelPerStud"
	}),
	Font = enumGroup("Font", {
		FredokaOne = true, GothamBold = true, Gotham = true, GothamBlack = true,
		Roboto = true, SourceSans = true, SourceSansBold = true, LuckiestGuy = true,
		Arcade = true, Cartoon = true, Code = true, Highway = true,
	}),
	NormalId = enumGroup("NormalId", {
		Right = true, Top = true, Back = true, Left = true, Bottom = true, Front = true,
	}),
	PartType = enumGroup("PartType", { Ball = true, Block = true, Cylinder = true }),
	SurfaceType = enumGroup("SurfaceType", {
		Smooth = true, Glue = true, Weld = true, Studs = true, Inlet = true,
		Bumps = true, Glaze = true, Hinge = true, Motor = true, SmoothNoPhysics = true,
	}),
}, {
	__index = function(_, key)
		error(("Invalid enum group: Enum.%s does not exist"):format(tostring(key)), 2)
	end,
})

-- The strictness itself must work, or this test proves nothing:
eq(pcall(function()
	return Enum.SurfaceGuiSizingMode.PixelPerStud
end), false, "strict mock rejects the historic typo PixelPerStud")
eq(pcall(function()
	return Enum.SurfaceGuiSizingMode.PixelsPerStud
end), true, "strict mock accepts the real PixelsPerStud")
eq(pcall(function()
	return Enum.BogusGroup.Whatever
end), false, "strict mock rejects unknown enum groups")

-- ===== Mock datatypes =================================================
local Vector3MT = {}
Vector3MT.__index = function(self, key)
	if key == "X" then
		return self.x
	elseif key == "Y" then
		return self.y
	elseif key == "Z" then
		return self.z
	end
	return nil
end
Vector3MT.__add = function(a, b)
	return setmetatable({ x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }, Vector3MT)
end
Vector3MT.__sub = function(a, b)
	return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, Vector3MT)
end
local Vector3 = {
	new = function(x, y, z)
		return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, Vector3MT)
	end,
}
local Color3 = {
	new = function(r, g, b)
		return { r = r, g = g, b = b }
	end,
	fromRGB = function(r, g, b)
		return { r = r / 255, g = g / 255, b = b / 255 }
	end,
}
local UDim2 = {
	new = function(xs, xo, ys, yo)
		return { xs = xs, xo = xo, ys = ys, yo = yo }
	end,
	fromScale = function(x, y)
		return { xs = x, xo = 0, ys = y, yo = 0 }
	end,
	fromOffset = function(x, y)
		return { xs = 0, xo = x, ys = 0, yo = y }
	end,
}

-- ===== Mock Instance ==================================================
local NodeMethods = {}
local nodeMT = {
	__index = function(self, key)
		local method = NodeMethods[key]
		if method then
			return method
		end
		local props = rawget(self, "_props")
		if props[key] ~= nil then
			return props[key]
		end
		-- child lookup by name, like Roblox dot access
		for _, child in rawget(self, "_children") do
			if child.Name == key then
				return child
			end
		end
		return nil
	end,
	__newindex = function(self, key, value)
		if key == "Parent" then
			local old = rawget(self, "_parent")
			if old then
				local siblings = rawget(old, "_children")
				for i, child in siblings do
					if child == self then
						table.remove(siblings, i)
						break
					end
				end
			end
			rawset(self, "_parent", value)
			if value then
				table.insert(rawget(value, "_children"), self)
			end
		elseif key == "Name" or key == "ClassName" then
			rawset(self, key, value)
		else
			rawget(self, "_props")[key] = value
		end
	end,
}
local function newNode(className)
	local node = { ClassName = className, Name = className, _props = {}, _children = {}, _attrs = {}, _parent = nil }
	return setmetatable(node, nodeMT)
end
function NodeMethods.SetAttribute(self, name, value)
	rawget(self, "_attrs")[name] = value
end
function NodeMethods.GetAttribute(self, name)
	return rawget(self, "_attrs")[name]
end
function NodeMethods.FindFirstChild(self, name)
	for _, child in rawget(self, "_children") do
		if child.Name == name then
			return child
		end
	end
	return nil
end
function NodeMethods.WaitForChild(self, name)
	return NodeMethods.FindFirstChild(self, name)
end
function NodeMethods.GetChildren(self)
	return rawget(self, "_children")
end
function NodeMethods.GetDescendants(self)
	local out = {}
	local function walk(node)
		for _, child in rawget(node, "_children") do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end
function NodeMethods.Destroy(self)
	self.Parent = nil
end
local Instance = {
	new = function(className)
		return newNode(className)
	end,
}

-- ===== Mock game / workspace ==========================================
local workspaceNode = newNode("Workspace")
workspaceNode.Name = "Workspace"
local lightingNode = newNode("Lighting")
lightingNode.Name = "Lighting"
local services = { Workspace = workspaceNode, Lighting = lightingNode }
local gameNode = {}
function gameNode.GetService(_, name)
	if not services[name] then
		services[name] = newNode(name)
		services[name].Name = name
	end
	return services[name]
end
-- 'game' also answers FindFirstChild-style lookups MapBuilder never uses;
-- keep it minimal and explicit.

-- ===== Load the REAL MapBuilder with only its require header swapped ==
local source = fs.readFile("src/server/MapBuilder.luau")
local header = table.concat({
	'local ReplicatedStorage = game:GetService("ReplicatedStorage")',
	'local Shared = ReplicatedStorage:WaitForChild("Shared")',
	"local Config = require(Shared.Config)",
	"local NumberFormat = require(Shared.NumberFormat)",
}, "\n")
local startAt, endAt = string.find(source, header, 1, true)
ok(startAt ~= nil, "MapBuilder still has the expected Roblox require header")
source = string.sub(source, 1, startAt - 1)
	.. 'local Config = require("../src/shared/Config")\nlocal NumberFormat = require("../src/shared/NumberFormat")'
	.. string.sub(source, endAt + 1)

local prints = {}
local env = {
	-- luau.load chunks cannot use string require on their own; the harness
	-- provides it, serving exactly the two modules the swapped header names.
	require = function(path)
		if path == "../src/shared/Config" then
			return Config
		elseif path == "../src/shared/NumberFormat" then
			return NumberFormat
		end
		error("unexpected require in MapBuilder test: " .. tostring(path))
	end,
	game = gameNode,
	workspace = workspaceNode,
	Instance = Instance,
	Vector3 = Vector3,
	Color3 = Color3,
	UDim2 = UDim2,
	Enum = Enum,
	print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring(select(i, ...))
		end
		table.insert(prints, table.concat(parts, " "))
	end,
	pairs = pairs,
	ipairs = ipairs,
	tostring = tostring,
	tonumber = tonumber,
	type = type,
	select = select,
	string = string,
	math = math,
	table = table,
	pcall = pcall,
	error = error,
}
local chunk = luau.load(source, { debugName = "MapBuilder", environment = env })
local MapBuilder = chunk()

local buildOk, buildErr = pcall(MapBuilder.build)
ok(buildOk, "MapBuilder.build() runs clean under the strict mock" .. (buildOk and "" or (": " .. tostring(buildErr))))

-- ===== Assertions on the built tree ===================================
local expectedKeys = Config.APP_COLS * Config.APP_ROWS
local expectedStages = #Config.STAGE_LEVEL_REQS
eq(prints[#prints], ("[Phone] Map built: %d app icons, %d stages"):format(expectedKeys, expectedStages), "final print line")

local map = workspaceNode:FindFirstChild("PhoneMap")
ok(map ~= nil, "workspace.PhoneMap exists")
local descendants = map:GetDescendants()
local keys, killFloors, gates, winsPads, stars, chargers, stageFolders = 0, 0, 0, 0, 0, 0, 0
local allAnchored = true
for _, node in descendants do
	if node:GetAttribute("IsApp") then
		keys += 1
	end
	if node:GetAttribute("IsKill") then
		killFloors += 1
	end
	if node:GetAttribute("StageIndex") then
		gates += 1
	end
	if node:GetAttribute("StageWin") then
		winsPads += 1
	end
	if node:GetAttribute("IsStar") then
		stars += 1
	end
	if node:GetAttribute("ChargerIndex") then
		chargers += 1
	end
	if string.match(node.Name, "^Stage_%d+$") and node.ClassName == "Folder" then
		stageFolders += 1
	end
	if (node.ClassName == "Part" or node.ClassName == "SpawnLocation") and node.Anchored ~= true then
		allAnchored = false
	end
end
eq(keys, expectedKeys, "steppable keys built")
eq(stageFolders, expectedStages, "stage folders built")
eq(gates, expectedStages, "level gates built")
eq(winsPads, expectedStages, "Wins pads built")
eq(killFloors, expectedStages + 1, "kill floors built (one per stage + lobby)")
eq(chargers, #Config.CHARGERS, "charger pads built")
ok(stars > 0, "collectible stars built")
ok(allAnchored, "every part in the map is Anchored")

local lobby = map:FindFirstChild("Lobby")
local spawn = lobby and lobby:FindFirstChild("Spawn")
local deck = lobby and lobby:FindFirstChild("SpawnDeck")
ok(spawn ~= nil and spawn.ClassName == "SpawnLocation", "SpawnLocation exists in the lobby")
ok(deck ~= nil, "spawn deck exists")
if spawn and deck then
	local deckTop = deck.Position.Y + deck.Size.Y / 2
	ok(spawn.Position.Y >= deckTop, "player spawns ON the solid deck, not in the air or floor")
	eq(spawn.Position.Z, deck.Position.Z, "spawn is centered on the deck")
end
local stagesFolder = map:FindFirstChild("Stages")
eq(stagesFolder and #stagesFolder:GetChildren(), #Config.STAGE_LEVEL_REQS, "World 1 stage count")
ok(map:FindFirstChild("World2") == nil, "no World 2 world built in v1 (teaser only)")
-- Battery: exactly the 3 boss stages carry BatteryDrain + 3 pickups each
local batteryStages, batteryCells, portals = 0, 0, 0
for _, node in descendants do
	if node:GetAttribute("BatteryDrain") then
		batteryStages += 1
		eq(node:GetAttribute("BatteryDrain"), Config.BATTERY_DRAIN_PCT, "boss drain matches Config")
	end
	if node:GetAttribute("IsBattery") then
		batteryCells += 1
	end
	if node:GetAttribute("IsPortal") ~= nil then
		portals += 1
	end
end
eq(batteryStages, 3, "3 battery (boss) stages")
eq(batteryCells, 9, "9 battery pickups (3 per boss stage)")
eq(portals, 0, "no live portals in v1")
local function overlapsXZ(a, b)
	return math.abs(a.Position.X - b.Position.X) * 2 < (a.Size.X + b.Size.X)
		and math.abs(a.Position.Z - b.Position.Z) * 2 < (a.Size.Z + b.Size.Z)
end
local teaser = lobby:FindFirstChild("W2Teaser")
ok(teaser ~= nil, "World 2 teaser pad exists in the lobby")
if teaser then
	ok(teaser:GetAttribute("IsPortal") == nil, "teaser is decorative (no portal wiring)")
	local shopStall = lobby:FindFirstChild("ItemsShop")
	ok(shopStall ~= nil and not overlapsXZ(teaser, shopStall), "teaser is not buried inside the Items Shop stall")
	local tmFolder = lobby:FindFirstChild("Chargers")
	local onCharger = false
	if tmFolder then
		for _, pad in tmFolder:GetChildren() do
			if overlapsXZ(teaser, pad) then
				onCharger = true
			end
		end
	end
	ok(not onCharger, "teaser does not overlap any charger pad")
end
ok(#MapBuilder.boardLevelLabels == 2 and #MapBuilder.boardWinsLabels == 2, "TOP LEVEL / TOP WINS board labels exported")

print(("map.luau: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error(failed .. " map checks failed")
end
