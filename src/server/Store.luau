-- Store.luau — بيانات اللاعبين: تحميل/حفظ DataStore + leaderstats.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"))

local Store = {}
Store.profiles = {} -- [Player] = data
Store.values = {} -- [Player] = { charge=NumberValue, wins=..., phones=..., stage=..., level=... }

-- تنبيه حرج: لا تستدعِ GetDataStore في أعلى الموديول — في مكان غير منشور
-- (GameId=0) يرمي خطأً يقتل سكربت السيرفر كله عند الـrequire. كسول + pcall.
local dsCache = nil -- false = حاولنا وفشل
local function getDs()
	if dsCache == nil then
		local ok, res = pcall(function()
			return DataStoreService:GetDataStore("PhoneEscape_v1")
		end)
		dsCache = (ok and res) or false
		if not ok then
			warn("[Phone] DataStore unavailable (unpublished place?): " .. tostring(res))
		end
	end
	return dsCache or nil
end

local function defaults()
	return {
		charge = 0,
		wins = 0,
		lifetime = 0, -- الشحن التراكمي (يقود المستوى، يُصفّر بالترقية)
		stage = 0, -- أعلى مرحلة مخلّصة
		phones = 0, -- عدد ترقيات الهاتف
		ascends = 0, -- عدد تحديثات النظام
		cases = {},
		signals = {},
		items = {},
		chargers = { 1 },
		chargerLv = {},
		linkIdx = 1,
		pass = {}, -- [passKey] = true (من الباسات المشتراة)
		codes = {},
		cap = 0, -- سقف سرعة يدوي (0 = بلا سقف)
		lastGift = 0,
		lastSpin = 0,
		boostUntil = 0,
		boostMult = 1,
		lastSeen = 0,
		loginDay = 0,
		streak = 0,
		questDay = 0,
		questProg = {},
		questDone = {},
		best = {}, -- ["s<idx>"] = أفضل زمن
	}
end

local function bindStats(player: Player, data)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local vals = {}
	local function num(name, value)
		local v = Instance.new("NumberValue")
		v.Name = name
		v.Value = value
		v.Parent = folder
		vals[string.lower(name)] = v
		return v
	end
	num("Charge", data.charge)
	num("Wins", data.wins)
	num("Phones", data.phones)
	num("Stage", data.stage)
	num("Level", (Rules.level(data.lifetime)))
	folder.Parent = player
	Store.values[player] = vals
end

function Store.sync(player: Player)
	local data = Store.profiles[player]
	local vals = Store.values[player]
	if not (data and vals) then
		return
	end
	vals.charge.Value = data.charge
	vals.wins.Value = data.wins
	vals.phones.Value = data.phones
	vals.stage.Value = data.stage
	vals.level.Value = (Rules.level(data.lifetime))
end

function Store.load(player: Player)
	local data = defaults()
	local ds = getDs()
	if ds and not RunService:IsStudio() then
		local ok, saved
		for _ = 1, 2 do -- محاولة + إعادة: قراءة فاشلة لا تمسح تقدم أحد
			ok, saved = pcall(function()
				return ds:GetAsync("p_" .. player.UserId)
			end)
			if ok then
				break
			end
			task.wait(1)
		end
		if ok and type(saved) == "table" then
			for key, value in defaults() do
				if saved[key] ~= nil then
					data[key] = saved[key]
				end
			end
		end
	end
	Store.profiles[player] = data
	bindStats(player, data)
	return data
end

function Store.save(player: Player)
	local data = Store.profiles[player]
	local ds = getDs()
	if not data or not ds or RunService:IsStudio() then
		return
	end
	data.lastSeen = os.time()
	pcall(function()
		ds:SetAsync("p_" .. player.UserId, data)
	end)
end

function Store.init(onLoaded: (Player) -> ())
	Players.PlayerAdded:Connect(function(player)
		local data = Store.load(player)
		if onLoaded then
			onLoaded(player, data)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		Store.save(player)
		Store.profiles[player] = nil
		Store.values[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		if not Store.profiles[player] then
			local data = Store.load(player)
			if onLoaded then
				onLoaded(player, data)
			end
		end
	end
	task.spawn(function()
		while true do
			task.wait(120)
			for player in Store.profiles do
				Store.save(player)
			end
		end
	end)
	game:BindToClose(function()
		for player in Store.profiles do
			Store.save(player)
		end
	end)
end

return Store
