-- QuestService (v4 free progression): daily login + streak, offline earnings,
-- and the Medal Quests (daily). Free players must progress well — Robux only
-- speeds things up; that is what keeps a game alive and growing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local NumberFormat = require(Shared.NumberFormat)

local DataService = require(script.Parent.DataService)
local SpeedService = require(script.Parent.SpeedService)

local QuestService = {}
local remotes
local trainFrac = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

-- Daily quests roll over at midnight even for players who stay online:
-- every quest read/write goes through this first.
local function ensureQuestDay(data)
	local day = today()
	if data.QuestDay ~= day then
		data.QuestDay = day
		data.QuestProgress = {}
		data.QuestClaimed = {}
	end
end

local function toast(player, text)
	if remotes then
		remotes.Toast:FireClient(player, text)
	end
end

local function bestChargerPerSecond(data): number
	local best = 0
	for _, idx in data.ChargersOwned do
		local tm = Config.CHARGERS[idx]
		if tm then
			local level = (data.ChargerLevels and data.ChargerLevels[idx]) or 0
			best = math.max(best, Economy.chargerOutput(tm, level))
		end
	end
	return best
end

local function onJoin(player: Player)
	local data = DataService.profiles[player]
	if not data then
		return
	end
	-- Offline earnings (uses LastSeen stamped by the previous session's save)
	if data.LastSeen and data.LastSeen > 0 then
		local awaySeconds = os.time() - data.LastSeen
		if awaySeconds >= Config.OFFLINE_MIN_MINUTES * 60 then
			local hours = awaySeconds / 3600
			local earned = Economy.offlineSpeed(hours, bestChargerPerSecond(data))
			if earned > 0 then
				SpeedService.grantSpeed(player, earned)
				toast(player, "🌙 While you were away: +" .. NumberFormat.format(earned) .. " Charge!")
			end
		end
	end
	-- Daily login + streak
	local day = today()
	if data.LastLoginDay ~= day then
		if data.LastLoginDay == day - 1 then
			data.LoginStreak += 1
		else
			data.LoginStreak = 1
		end
		data.LastLoginDay = day
		local speedReward, winsReward = Economy.dailyReward(data.LoginStreak, data.MaxStage)
		SpeedService.grantSpeed(player, speedReward)
		data.Wins += winsReward
		DataService.syncStats(player)
		toast(player, "📅 Day " .. data.LoginStreak .. " streak! +" .. NumberFormat.format(speedReward) .. " Charge, +" .. NumberFormat.format(winsReward) .. " Wins")
	end
	-- Daily quests reset
	ensureQuestDay(data)
	-- Welcome guidance for brand-new players
	if data.TotalEarned == 0 and data.MaxStage == 0 then
		task.delay(2, function()
			toast(player, "👋 1) Step on the APPS to gain Charge ⚡!")
		end)
		task.delay(7, function()
			toast(player, "👋 2) Clear STAGES to earn Wins, 3) spend Wins on Cases & Signal!")
		end)
	end
end

local function bump(player: Player, questId: string, amount: number)
	local data = DataService.profiles[player]
	if not data then
		return
	end
	ensureQuestDay(data)
	data.QuestProgress[questId] = math.min((data.QuestProgress[questId] or 0) + amount, 1000000000)
end

function QuestService.init(remotesFolder)
	remotes = remotesFolder
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			local data = DataService.profiles[player]
			while not data do
				task.wait(0.2)
				data = DataService.profiles[player]
			end
			task.wait(0.5)
			onJoin(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		if DataService.profiles[player] then
			task.spawn(onJoin, player)
		end
	end

	SpeedService.hooks.onKey = function(player)
		bump(player, "keys", 1)
	end
	SpeedService.hooks.onTrain = function(player, dt)
		trainFrac[player] = (trainFrac[player] or 0) + dt
		if trainFrac[player] >= 1 then
			local whole = math.floor(trainFrac[player])
			trainFrac[player] -= whole
			bump(player, "train", whole)
		end
	end
	local StageService = require(script.Parent.StageService)
	StageService.onClaim = function(player)
		bump(player, "stages", 1)
	end
	Players.PlayerRemoving:Connect(function(player)
		trainFrac[player] = nil
	end)

	remotes.GetQuests.OnServerInvoke = function(player)
		local data = DataService.profiles[player]
		if not data then
			return {}
		end
		ensureQuestDay(data)
		local out = { streak = data.LoginStreak, quests = {} }
		for _, q in Config.QUESTS do
			table.insert(out.quests, {
				id = q.id,
				text = q.text,
				target = q.target,
				progress = math.floor(data.QuestProgress[q.id] or 0),
				claimed = data.QuestClaimed[q.id] == true,
				wins = q.wins,
				speed = q.speed,
			})
		end
		return out
	end

	remotes.ClaimQuest.OnServerInvoke = function(player, questId)
		local data = DataService.profiles[player]
		if not data then
			return false, "No data"
		end
		ensureQuestDay(data)
		for _, q in Config.QUESTS do
			if q.id == questId then
				if data.QuestClaimed[questId] then
					return false, "Already claimed"
				end
				if (data.QuestProgress[questId] or 0) < q.target then
					return false, "Not finished yet"
				end
				data.QuestClaimed[questId] = true
				if q.speed > 0 then
					SpeedService.grantSpeed(player, q.speed)
				end
				if q.wins > 0 then
					data.Wins += q.wins
					DataService.syncStats(player)
				end
				return true, "🎖️ Quest done! +" .. NumberFormat.format(q.speed) .. " Charge, +" .. NumberFormat.format(q.wins) .. " Wins"
			end
		end
		return false, "Unknown quest"
	end
end

return QuestService
