-- DataService: leaderstats + DataStore persistence per player.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Economy"))

local store = DataStoreService:GetDataStore("PhoneCharge_v1")

local DataService = {}
DataService.profiles = {}

local DEFAULTS = {
	Speed = 0,
	Wins = 0,
	Rebirths = 0,
	Ascends = 0,
	TotalEarned = 0, -- lifetime speed: drives Level; RESET by Rebirth/Ascend (v7, like the original)
	MaxStage = 0, -- highest stage cleared
	CasesOwned = {}, -- ladder indexes
	SignalsOwned = {},
	ItemsOwned = {},
	ChargersOwned = { 1 }, -- starter pad owned
	ChargerLevels = {}, -- [chargerIndex] = upgrade level 0..8 (v5)
	InfinityCase = false, -- the Robux crown jewel
	GalaxyCase = false, -- Robux pass trail (v7)
	DarknessSignal = false, -- Robux pass signal
	CableGold = false, -- Robux cables (station-output multipliers)
	CableDiamond = false,
	CableCandy = false,
	CableAdmin = false,
	StepIndex = 1, -- current step pad (v7): +Speed per step from Config.STEP_PADS
	CodesUsed = {},
	SpeedCap = 0, -- 0 = no cap (the "Custom Speed" box in the screenshot)
	LastGift = 0, -- os.time of last free gift claim
	-- v4 free progression
	LastSeen = 0, -- os.time when the profile was last saved (offline earnings)
	LastLoginDay = 0, -- day number (os.time()/86400) of last daily reward
	LoginStreak = 0,
	QuestDay = 0,
	QuestProgress = {}, -- [questId] = number
	QuestClaimed = {}, -- [questId] = true
	BestTimes = {}, -- [ "w<world>_<stage>" ] = best clear seconds (v8 medals)
	-- v6: World 2 progress, spin wheel, temporary boosts
	MaxStageW2 = 0,
	LastSpin = 0,
	BoostUntil = 0, -- os.time when the active boost ends
	BoostMult = 1,
}

local function freshData()
	local data = {}
	for k, v in DEFAULTS do
		data[k] = if type(v) == "table" then table.clone(v) else v
	end
	return data
end

local function bindLeaderstats(player: Player, data)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local speed = Instance.new("NumberValue")
	speed.Name = "Charge"
	speed.Value = data.Speed
	speed.Parent = ls
	local wins = Instance.new("NumberValue")
	wins.Name = "Wins"
	wins.Value = data.Wins
	wins.Parent = ls
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Phones"
	rebirths.Value = data.Rebirths
	rebirths.Parent = ls
	local stage = Instance.new("IntValue")
	stage.Name = "Stage"
	stage.Value = data.MaxStage
	stage.Parent = ls
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = Economy.levelFor(data.TotalEarned)
	level.Parent = ls
	ls.Parent = player
end

function DataService.syncStats(player: Player)
	local data = DataService.profiles[player]
	local ls = player:FindFirstChild("leaderstats")
	if not (data and ls) then
		return
	end
	ls.Charge.Value = data.Speed
	ls.Wins.Value = data.Wins
	ls.Phones.Value = data.Rebirths
	ls.Stage.Value = data.MaxStage
	if ls:FindFirstChild("Level") then
		ls.Level.Value = Economy.levelFor(data.TotalEarned)
	end
end

function DataService.load(player: Player)
	local data = freshData()
	if not RunService:IsStudio() then
		-- one retry: a failed first read must not wipe a veteran's progress
		local ok, saved = pcall(function()
			return store:GetAsync("player_" .. player.UserId)
		end)
		if not ok then
			task.wait(1)
			ok, saved = pcall(function()
				return store:GetAsync("player_" .. player.UserId)
			end)
		end
		if ok and type(saved) == "table" then
			for k in DEFAULTS do
				if saved[k] ~= nil then
					data[k] = saved[k]
				end
			end
		end
	end
	DataService.profiles[player] = data
	bindLeaderstats(player, data)
	return data
end

function DataService.save(player: Player)
	local data = DataService.profiles[player]
	if not data or RunService:IsStudio() then
		return
	end
	data.LastSeen = os.time()
	pcall(function()
		store:SetAsync("player_" .. player.UserId, data)
	end)
end

function DataService.init()
	Players.PlayerAdded:Connect(function(player)
		DataService.load(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		DataService.save(player)
		DataService.profiles[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		if not DataService.profiles[player] then
			DataService.load(player)
		end
	end
	task.spawn(function()
		while true do
			task.wait(120)
			for player in DataService.profiles do
				DataService.save(player)
			end
		end
	end)
	game:BindToClose(function()
		for player in DataService.profiles do
			DataService.save(player)
		end
	end)
end

return DataService
