-- Main.server.luau — نقطة الانطلاق: الريموتات، بناء العالم، تشغيل
-- الأنظمة (بعزل كامل: فشل نظام لا يوقف الباقي)، ولوحتا الصدارة.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = require(Shared.Rules)
local Format = require(Shared.Format)

-- ===== الريموتات =====
local folder = Instance.new("Folder")
folder.Name = "PhoneRemotes"
local function mk(class, name)
	local r = Instance.new(class)
	r.Name = name
	r.Parent = folder
	return r
end
local R = {
	Toast = mk("RemoteEvent", "Toast"),
	StageCleared = mk("RemoteEvent", "StageCleared"),
	SetCap = mk("RemoteEvent", "SetCap"),
	Teleport = mk("RemoteEvent", "Teleport"),
	GetState = mk("RemoteFunction", "GetState"),
	BuyCase = mk("RemoteFunction", "BuyCase"),
	BuySignal = mk("RemoteFunction", "BuySignal"),
	BuyItem = mk("RemoteFunction", "BuyItem"),
	UnlockCharger = mk("RemoteFunction", "UnlockCharger"),
	UpgradeCharger = mk("RemoteFunction", "UpgradeCharger"),
	BuyLink = mk("RemoteFunction", "BuyLink"),
	UpgradePhone = mk("RemoteFunction", "UpgradePhone"),
	OSUpdate = mk("RemoteFunction", "OSUpdate"),
	RedeemCode = mk("RemoteFunction", "RedeemCode"),
	ClaimGift = mk("RemoteFunction", "ClaimGift"),
	GetQuests = mk("RemoteFunction", "GetQuests"),
	ClaimQuest = mk("RemoteFunction", "ClaimQuest"),
	Spin = mk("RemoteFunction", "Spin"),
}
folder.Parent = ReplicatedStorage

local ctx = {
	remotes = R,
	toast = function(player, text)
		R.Toast:FireClient(player, text)
	end,
}

local Server = script.Parent
local Builder = require(Server.Builder)
local Store = require(Server.Store)
local Play = require(Server.Play)
local Shop = require(Server.Shop)

-- ===== لافتة خطأ مرئية (حتى لا يموت أي فشل بصمت) =====
local function errorSign(title, detail)
	local sign = Instance.new("Part")
	sign.Name = "BUILD_ERROR"
	sign.Size = Vector3.new(70, 14, 1)
	sign.Position = Vector3.new(0, 12, 80)
	sign.Anchored = true
	sign.Color = Color3.fromRGB(200, 30, 30)
	sign.TopSurface = Enum.SurfaceType.Smooth
	sign.Parent = workspace
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.Parent = sign
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.TextColor3 = Color3.new(1, 1, 1)
	tl.Text = title .. ":\n" .. tostring(detail)
	tl.Parent = gui
end

-- ===== بناء العالم =====
local boards
local okBuild, buildResult = pcall(Builder.build)
if okBuild then
	boards = buildResult
else
	warn("[Phone] world build FAILED: " .. tostring(buildResult))
	errorSign("WORLD BUILD ERROR", buildResult)
end

-- ===== تشغيل الأنظمة بعزل (فشل أي نظام يظهر على لافتة) =====
local bootErrors = {}
local function boot(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		warn(("[Phone] %s failed to start:\n%s"):format(name, debug.traceback(tostring(err))))
		table.insert(bootErrors, name .. ": " .. tostring(err))
	end
end
boot("Store", function()
	Store.init(function(player, data)
		Shop.onJoin(player, data)
	end)
end)
boot("Play", function()
	Play.init(ctx)
end)
boot("Shop", function()
	Shop.init(ctx)
end)
if #bootErrors > 0 then
	errorSign("SERVER START ERROR", table.concat(bootErrors, "\n"))
end

-- ===== لوحتا الصدارة العالميتان =====
-- الـgetters نفسها قد ترمي في مكان غير منشور: pcall دائمًا
local odsLevel, odsWins, nameStore
pcall(function()
	odsLevel = DataStoreService:GetOrderedDataStore("PhoneTopLevel_v1")
	odsWins = DataStoreService:GetOrderedDataStore("PhoneTopWins_v1")
	nameStore = DataStoreService:GetDataStore("PhoneBoardNames_v1")
end)

local function writeBoard(labels, title, rows)
	if not labels then
		return
	end
	local lines = { title }
	for i, row in rows do
		table.insert(lines, i .. ". " .. row.name .. " — " .. row.value)
	end
	if #rows == 0 then
		table.insert(lines, "—")
	end
	local text = table.concat(lines, "\n")
	for _, tl in labels do
		tl.Text = text
	end
end

local function topRows(ods, sessionValue)
	local rows = {}
	local ok, pages = pcall(function()
		return ods:GetSortedAsync(false, 10)
	end)
	if ok and pages then
		for _, entry in pages:GetCurrentPage() do
			local userId = tonumber(string.sub(entry.key, 2))
			local name = "Player"
			if userId then
				local okName, saved = pcall(function()
					return nameStore:GetAsync("u" .. userId)
				end)
				if okName and saved then
					name = saved
				end
			end
			table.insert(rows, { name = name, value = Format.num(entry.value) })
		end
		return rows
	end
	local session = {}
	for player in Store.profiles do
		table.insert(session, { name = player.DisplayName, raw = sessionValue(player) })
	end
	table.sort(session, function(a, b)
		return a.raw > b.raw
	end)
	for i = 1, math.min(10, #session) do
		table.insert(rows, { name = session[i].name, value = Format.num(session[i].raw) })
	end
	return rows
end

task.spawn(function()
	while true do
		for player, data in Store.profiles do
			pcall(function()
				nameStore:SetAsync("u" .. player.UserId, player.DisplayName)
				odsWins:SetAsync("u" .. player.UserId, math.floor(data.wins))
				odsLevel:SetAsync("u" .. player.UserId, (Rules.level(data.lifetime)))
			end)
		end
		if boards then
			writeBoard(boards.levelLabels, "🏆 TOP LEVEL 🏆", topRows(odsLevel, function(p)
				return (Rules.level(Store.profiles[p].lifetime))
			end))
			writeBoard(boards.winsLabels, "🏆 TOP WINS 🏆", topRows(odsWins, function(p)
				return Store.profiles[p].wins
			end))
		end
		task.wait(60)
	end
end)

print("[Phone] server ready")
