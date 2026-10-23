-- ServerMain: remotes, map, services, and the global TOP LEVEL / TOP WINS boards.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local NumberFormat = require(Shared.NumberFormat)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(class, name): Instance
	local r = Instance.new(class)
	r.Name = name
	r.Parent = remotes
	return r
end
local R = {
	Toast = remote("RemoteEvent", "Toast"),
	StageCleared = remote("RemoteEvent", "StageCleared"),
	SetCap = remote("RemoteEvent", "SetCap"),
	Teleport = remote("RemoteEvent", "Teleport"),
	GetState = remote("RemoteFunction", "GetState"),
	BuyCase = remote("RemoteFunction", "BuyCase"),
	BuySignal = remote("RemoteFunction", "BuySignal"),
	BuyItem = remote("RemoteFunction", "BuyItem"),
	UnlockCharger = remote("RemoteFunction", "UnlockCharger"),
	UpgradeCharger = remote("RemoteFunction", "UpgradeCharger"),
	BuyStep = remote("RemoteFunction", "BuyStep"),
	UpgradePhone = remote("RemoteFunction", "UpgradePhone"),
	Ascend = remote("RemoteFunction", "Ascend"),
	RedeemCode = remote("RemoteFunction", "RedeemCode"),
	ClaimGift = remote("RemoteFunction", "ClaimGift"),
	GetQuests = remote("RemoteFunction", "GetQuests"),
	ClaimQuest = remote("RemoteFunction", "ClaimQuest"),
	Spin = remote("RemoteFunction", "Spin"),
}
remotes.Parent = ReplicatedStorage

local Server = script.Parent
local MapBuilder = require(Server.MapBuilder)
local DataService = require(Server.DataService)
local SpeedService = require(Server.SpeedService)
local StageService = require(Server.StageService)
local ShopService = require(Server.ShopService)

-- Fail-safe: if the map build throws, show the error in-world instead of
-- leaving the player in an empty map with no explanation.
local ok, buildErr = pcall(MapBuilder.build)
if not ok then
	-- Fail-safe: never leave the player in an empty world without an explanation.
	warn("[Phone] Map build FAILED: " .. tostring(buildErr))
	local sign = Instance.new("Part")
	sign.Name = "BUILD_ERROR"
	sign.Size = Vector3.new(70, 14, 1)
	sign.Position = Vector3.new(0, 12, 80)
	sign.Anchored = true
	sign.Color = Color3.fromRGB(200, 30, 30)
	sign.Material = Enum.Material.SmoothPlastic
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
	tl.Text = "MAP BUILD ERROR:\n" .. tostring(buildErr)
	tl.Parent = gui
end
local QuestService = require(Server.QuestService)

-- Every service init is isolated: one failing service must never stop the
-- others — and never stop the map (already built above) from appearing.
local function initService(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		warn(("[Phone] %s init FAILED:\n%s"):format(name, debug.traceback(tostring(err))))
	end
end
initService("DataService", DataService.init)
SpeedService.toastFn = function(player, text)
	R.Toast:FireClient(player, text)
end
initService("SpeedService", SpeedService.init)
initService("StageService", function()
	StageService.init(R)
end)
initService("ShopService", function()
	ShopService.init(R)
end)
initService("QuestService", function()
	QuestService.init(R)
end)

-- ===== Global boards: TOP LEVEL and TOP WINS (OrderedDataStores) =====
local odsLevel = DataStoreService:GetOrderedDataStore("TopLevel_v1")
local odsWins = DataStoreService:GetOrderedDataStore("TopWins_v1")
local nameStore = DataStoreService:GetDataStore("BoardNames_v1")

local function setBoard(labels, title, rows)
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
		local entries = pages:GetCurrentPage()
		for _, entry in entries do
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
			table.insert(rows, { name = name, value = NumberFormat.format(entry.value) })
		end
		return rows
	end
	-- Studio / failure fallback: rank this server's players
	local session = {}
	for player in DataService.profiles do
		table.insert(session, { name = player.DisplayName, raw = sessionValue(player) })
	end
	table.sort(session, function(a, b)
		return a.raw > b.raw
	end)
	for i = 1, math.min(10, #session) do
		table.insert(rows, { name = session[i].name, value = NumberFormat.format(session[i].raw) })
	end
	return rows
end

task.spawn(function()
	while true do
		for player, data in DataService.profiles do
			pcall(function()
				nameStore:SetAsync("u" .. player.UserId, player.DisplayName)
				odsWins:SetAsync("u" .. player.UserId, math.floor(data.Wins))
				odsLevel:SetAsync("u" .. player.UserId, Economy.levelFor(data.TotalEarned))
			end)
		end
		setBoard(MapBuilder.boardLevelLabels, "🏆 TOP LEVEL 🏆", topRows(odsLevel, function(p)
			return Economy.levelFor(DataService.profiles[p].TotalEarned)
		end))
		setBoard(MapBuilder.boardWinsLabels, "🏆 TOP WINS 🏆", topRows(odsWins, function(p)
			return DataService.profiles[p].Wins
		end))
		task.wait(60)
	end
end)

print("[Phone] Server ready. Config stages:", Config.STAGE_COUNT)
