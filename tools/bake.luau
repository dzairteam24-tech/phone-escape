-- bake.luau — يخبز الخريطة في ملف المكان: ينفّذ Builder.build() الحقيقي
-- على واجهة Roblox وهمية ويكتب map/PhoneWorld.model.json بصيغة Rojo،
-- لترى الخريطة فور فتح المكان في Studio. وقت التشغيل يعيد Builder البناء
-- من الكود (الكود هو مصدر الحقيقة دائمًا).
--   lune run tools/bake.luau && rojo build default.project.json -o game.rbxlx
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

-- Enums كرموز مقيدة: أي عضو غير معروف في أي خاصية يفجّر الخبز
local ENUM_MEMBERS = {
	Material = { SmoothPlastic = true, Neon = true, Glass = true },
	SurfaceType = { Smooth = true },
	NormalId = { Top = true, Bottom = true, Front = true, Back = true, Left = true, Right = true },
	SurfaceGuiSizingMode = { PixelsPerStud = true },
	PartType = { Ball = true, Cylinder = true, Block = true },
	Font = { FredokaOne = true },
}
local function enumProxy()
	return setmetatable({}, {
		__index = function(enums, enumName)
			local items = setmetatable({}, {
				__index = function(items, item)
					local v = { __enum = item, __enumType = enumName }
					rawset(items, item, v)
					return v
				end,
			})
			rawset(enums, enumName, items)
			return items
		end,
	})
end

local function newInstance(class)
	local inst = { __class = class, __props = {}, __order = {}, __children = {}, __attrs = {} }
	return setmetatable(inst, {
		__index = function(t, k)
			if k == "SetAttribute" then
				return function(self, n, v)
					rawget(self, "__attrs")[n] = v
				end
			elseif k == "FindFirstChild" or k == "WaitForChild" then
				return function(self, n)
					for _, c in rawget(self, "__children") do
						if c.__props.Name == n then
							return c
						end
					end
					return nil
				end
			elseif k == "Destroy" then
				return function() end
			end
			return rawget(t, "__props")[k]
		end,
		__newindex = function(t, k, v)
			local props = rawget(t, "__props")
			if k == "Parent" then
				table.insert(v.__children, t)
				return
			end
			if props[k] == nil then
				table.insert(rawget(t, "__order"), k)
			end
			props[k] = v
		end,
	})
end

local Vector3 = {
	new = function(x, y, z)
		return { __v3 = { x, y, z } }
	end,
}
local Color3 = {
	fromRGB = function(r, g, b)
		return { __c3 = { r / 255, g / 255, b / 255 } }
	end,
	new = function(r, g, b)
		return { __c3 = { r, g, b } }
	end,
}
local UDim2 = {
	fromScale = function(a, b)
		return { __udim2 = { { a, 0 }, { b, 0 } } }
	end,
}

local function orientationMatrix(o)
	local x, y, z = math.rad(o[1]), math.rad(o[2]), math.rad(o[3])
	local cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
	local function mul(a, b)
		local r = {}
		for i = 1, 3 do
			r[i] = {}
			for j = 1, 3 do
				r[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]
			end
		end
		return r
	end
	local Ry = { { cy, 0, sy }, { 0, 1, 0 }, { -sy, 0, cy } }
	local Rx = { { 1, 0, 0 }, { 0, cx, -sx }, { 0, sx, cx } }
	local Rz = { { cz, -sz, 0 }, { sz, cz, 0 }, { 0, 0, 1 } }
	local m = mul(mul(Ry, Rx), Rz)
	for i = 1, 3 do
		for j = 1, 3 do
			if math.abs(m[i][j]) < 1e-12 then
				m[i][j] = 0
			end
		end
	end
	return m
end

local function convert(v)
	if type(v) ~= "table" then
		return v
	end
	if v.__v3 then
		return v.__v3
	end
	if v.__c3 then
		return v.__c3
	end
	if v.__udim2 then
		return { UDim2 = v.__udim2 }
	end
	if v.__enum then
		local allowed = ENUM_MEMBERS[v.__enumType]
		assert(allowed and allowed[v.__enum], "enum not allowed in bake: " .. tostring(v.__enumType) .. "." .. tostring(v.__enum))
		return v.__enum
	end
	error("cannot convert property value")
end

local fontNames = { FredokaOne = "rbxasset://fonts/families/FredokaOne.json" }

local function toModel(inst)
	local props = inst.__props
	local out = { className = inst.__class, name = props.Name }
	local properties = {}
	local position = props.Position and props.Position.__v3
	local orientation = props.Orientation and props.Orientation.__v3
	for _, k in inst.__order do
		local v = props[k]
		if k == "Name" or k == "Position" or k == "Orientation" then
			-- عبر الاسم / CFrame
		elseif k == "Font" then
			local family = fontNames[v.__enum]
			assert(family, "unknown font " .. tostring(v.__enum))
			properties.FontFace = { Font = { family = family, weight = "Regular", style = "Normal" } }
		else
			properties[k] = convert(v)
		end
	end
	if position then
		local m = orientation and orientationMatrix(orientation) or { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
		properties.CFrame = { CFrame = { position = position, orientation = m } }
	end
	if next(properties) then
		out.properties = properties
	end
	if next(inst.__attrs) then
		out.attributes = inst.__attrs
	end
	if #inst.__children > 0 then
		out.children = {}
		for _, c in inst.__children do
			table.insert(out.children, toModel(c))
		end
	end
	return out
end

local Config = require("../src/shared/Config")
local Format = require("../src/shared/Format")
local Shared = { Config = Config, Format = Format }
local lighting = newInstance("Lighting")
local workspaceInst = newInstance("Workspace")
local game = {
	GetService = function(_, n)
		if n == "ReplicatedStorage" then
			return {
				WaitForChild = function()
					return Shared
				end,
			}
		end
		if n == "Lighting" then
			return lighting
		end
		error("service " .. n)
	end,
}

local chunk = luau.load(fs.readFile("src/server/Builder.luau"), {
	debugName = "Builder",
	environment = {
		Instance = { new = newInstance },
		Vector3 = Vector3,
		Color3 = Color3,
		UDim2 = UDim2,
		Enum = enumProxy(),
		game = game,
		workspace = workspaceInst,
		require = function(x)
			return x
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
		setmetatable = setmetatable,
	},
})
chunk().build()

local worldNode = workspaceInst.__children[1]
assert(worldNode and worldNode.__props.Name == "PhoneWorld", "PhoneWorld not built")
local model = toModel(worldNode)
model.name = nil -- الاسم يأتي من شجرة المشروع
fs.writeDir("map")
fs.writeFile("map/PhoneWorld.model.json", serde.encode("json", model, false))
print("Baked map/PhoneWorld.model.json")
