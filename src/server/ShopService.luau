-- ShopService v3: passes, Wins shops (Trails / Auras / Items / Chargers),
-- Rebirth (level-gated) + Ascend, codes, free gift, teleport, custom speed cap,
-- buy-speed developer products, and equipped trail/aura visuals.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local NumberFormat = require(Shared.NumberFormat)

local DataService = require(script.Parent.DataService)
local SpeedService = require(script.Parent.SpeedService)
local StageService = require(script.Parent.StageService)

local ShopService = {}
local signalParts = {}

local function ownsPass(player: Player, id: number): boolean
	if id <= 0 then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
	end)
	return ok and owns == true
end

function ShopService.applyPasses(player: Player)
	local data = DataService.profiles[player]
	local mult = 1
	if ownsPass(player, Config.PASSES.DoubleCharge) then
		mult *= 2
	end
	if ownsPass(player, Config.PASSES.VIP) then
		mult *= 3
		if data then
			data.CableGold = true -- VIP includes the gold cable
		end
	end
	SpeedService.passMult[player] = mult
	SpeedService.winMult[player] = ownsPass(player, Config.PASSES.DoubleWins) and 2 or 1
	if data then
		if ownsPass(player, Config.PASSES.InfinityCase) then
			data.InfinityCase = true
		end
		if ownsPass(player, Config.PASSES.GalaxyCase) then
			data.GalaxyCase = true
		end
		if ownsPass(player, Config.PASSES.DarknessSignal) then
			data.DarknessSignal = true
		end
		for _, cable in Config.CABLES do
			if ownsPass(player, Config.PASSES[cable.pass]) then
				data[cable.pass] = true
			end
		end
	end
	ShopService.refreshVisuals(player)
end

function ShopService.refreshVisuals(player: Player)
	local data = DataService.profiles[player]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (data and hrp) then
		return
	end
	local oldTrail = hrp:FindFirstChild("CaseTrail")
	if oldTrail then
		oldTrail:Destroy()
	end
	local a0 = hrp:FindFirstChild("TrailTop")
	local a1 = hrp:FindFirstChild("TrailBottom")
	local caseIdx = Economy.bestOwned(data.CasesOwned, Config.CASES)
	local caseItem = Config.CASES[caseIdx]
	-- pass trails can outrank the best Wins trail (Galaxy x10, Infinity x5M)
	for _, item in Config.CASES do
		if item.pass and data[item.pass] and (not caseItem or item.mult > caseItem.mult) then
			caseItem = item
		end
	end
	if caseItem then
		if not a0 then
			a0 = Instance.new("Attachment")
			a0.Name = "TrailTop"
			a0.Position = Vector3.new(0, 1, 0.6)
			a0.Parent = hrp
		end
		if not a1 then
			a1 = Instance.new("Attachment")
			a1.Name = "TrailBottom"
			a1.Position = Vector3.new(0, -1, 0.6)
			a1.Parent = hrp
		end
		local trail = Instance.new("Trail")
		trail.Name = "CaseTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(Color3.fromRGB(caseItem.color[1], caseItem.color[2], caseItem.color[3]))
		trail.Lifetime = 0.6
		trail.MinLength = 0.1
		trail.Parent = hrp
	end
	if signalParts[player] then
		signalParts[player]:Destroy()
		signalParts[player] = nil
	end
	local signalIdx = Economy.bestOwned(data.SignalsOwned, Config.SIGNALS)
	local signalItem = Config.SIGNALS[signalIdx]
	for _, item in Config.SIGNALS do
		if item.pass and data[item.pass] and (not signalItem or item.mult > signalItem.mult) then
			signalItem = item
		end
	end
	if signalItem then
		local sphere = Instance.new("Part")
		sphere.Name = "Signal"
		sphere.Shape = Enum.PartType.Ball
		sphere.Size = Vector3.new(6, 6, 6)
		sphere.Transparency = 0.75
		sphere.Color = Color3.fromRGB(signalItem.color[1], signalItem.color[2], signalItem.color[3])
		sphere.Material = Enum.Material.Neon
		sphere.CanCollide = false
		sphere.Anchored = true
		sphere.Parent = workspace
		signalParts[player] = sphere
	end
end

local function buyLadder(player, ladder, ownedTable, idx, kindName)
	local data = DataService.profiles[player]
	local item = ladder[idx]
	if not (data and item) then
		return false, "Invalid " .. kindName
	end
	if table.find(ownedTable, idx) then
		return false, "Already owned"
	end
	if item.pass then
		if data[item.pass] then
			return false, "Already owned (pass)"
		end
		return false, "👑 Robux pass item — get it in the Shop (🛒)"
	end
	if data.Wins < item.cost then
		return false, "Need " .. NumberFormat.format(item.cost) .. " Wins"
	end
	data.Wins -= item.cost
	table.insert(ownedTable, idx)
	DataService.syncStats(player)
	ShopService.refreshVisuals(player)
	if item.pct then
		return true, "✅ " .. item.name .. " equipped! (+" .. item.pct .. "% Charge)"
	end
	return true, "✅ " .. item.name .. " equipped! (x" .. tostring(item.mult) .. ")"
end

function ShopService.init(remotes)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.4)
			ShopService.applyPasses(player)
		end)
		task.spawn(function()
			local data = DataService.profiles[player]
			while not data do
				task.wait(0.2)
				data = DataService.profiles[player]
			end
			ShopService.applyPasses(player)
		end)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player)
		ShopService.applyPasses(player)
	end)

	remotes.GetState.OnServerInvoke = function(player)
		local data = DataService.profiles[player]
		if not data then
			return {}
		end
		local level, into, band = Economy.levelFor(data.TotalEarned)
		return {
			CasesOwned = data.CasesOwned,
			SignalsOwned = data.SignalsOwned,
			ItemsOwned = data.ItemsOwned,
			ChargersOwned = data.ChargersOwned,
			ChargerLevels = data.ChargerLevels,
			InfinityCase = data.InfinityCase,
			GalaxyCase = data.GalaxyCase or false,
			DarknessSignal = data.DarknessSignal or false,
			CaseMult = SpeedService.caseMult(player),
			SignalMult = SpeedService.signalMult(player),
			ItemMult = SpeedService.itemMult(player),
			RebirthMult = Economy.rebirthMult(data.Rebirths),
			StepIndex = data.StepIndex or 1,
			AscendMult = Config.ASCEND_MULT ^ data.Ascends,
			GainMult = SpeedService.gainMult(player),
			Level = level,
			LevelInto = into,
			LevelBand = band,
			RebirthLevelReq = Economy.rebirthLevelRequired(data.Rebirths),
			Ascends = data.Ascends,
			SpeedCap = data.SpeedCap,
			GiftReadyIn = math.max(0, Config.GIFT_COOLDOWN - (os.time() - (data.LastGift or 0))),
			MaxStageW2 = data.MaxStageW2 or 0,
			Battery = StageService.runBattery(player),
			BoostUntil = data.BoostUntil or 0,
			BoostMult = data.BoostMult or 1,
			SpinReadyIn = math.max(0, Config.SPIN_COOLDOWN - (os.time() - (data.LastSpin or 0))),
		}
	end

	remotes.BuyCase.OnServerInvoke = function(player, idx)
		local data = DataService.profiles[player]
		return buyLadder(player, Config.CASES, data and data.CasesOwned, idx, "trail")
	end
	remotes.BuySignal.OnServerInvoke = function(player, idx)
		local data = DataService.profiles[player]
		return buyLadder(player, Config.SIGNALS, data and data.SignalsOwned, idx, "aura")
	end
	remotes.BuyItem.OnServerInvoke = function(player, idx)
		local data = DataService.profiles[player]
		local ok, msg = buyLadder(player, Config.ITEMS, data and data.ItemsOwned, idx, "item")
		if ok then
			msg = "🎒 " .. msg
		end
		return ok, msg
	end

	remotes.UnlockCharger.OnServerInvoke = function(player, idx)
		local data = DataService.profiles[player]
		local item = Config.CHARGERS[idx]
		if not (data and item) then
			return false, "Invalid station"
		end
		if table.find(data.ChargersOwned, idx) then
			return false, "Already unlocked"
		end
		if item.cost == -1 then
			return false, "👑 VIP only — get the VIP pass"
		end
		if data.Wins < item.cost then
			return false, "Need " .. NumberFormat.format(item.cost) .. " Wins"
		end
		data.Wins -= item.cost
		table.insert(data.ChargersOwned, idx)
		DataService.syncStats(player)
		return true, "🏃 " .. item.name .. " charger unlocked!"
	end

	-- Charger upgrades (v5): paid in Wins earned by playing — never Robux.
	remotes.UpgradeCharger.OnServerInvoke = function(player, idx)
		local data = DataService.profiles[player]
		local tm = Config.CHARGERS[idx]
		if not (data and tm) then
			return false, "Invalid station"
		end
		if not table.find(data.ChargersOwned, idx) then
			return false, "Unlock this charger first"
		end
		data.ChargerLevels = data.ChargerLevels or {}
		local level = data.ChargerLevels[idx] or 0
		if level >= Config.CHARGER_MAX_LEVEL then
			return false, "⭐ This charger is MAX level"
		end
		local cost = Economy.chargerUpgradeCost(tm, level)
		if data.Wins < cost then
			return false, "Need " .. NumberFormat.format(cost) .. " Wins to upgrade"
		end
		data.Wins -= cost
		data.ChargerLevels[idx] = level + 1
		DataService.syncStats(player)
		local nowRate = Economy.chargerOutput(tm, level + 1)
		return true, "⬆️ " .. tm.name .. " Lv" .. (level + 1) .. "! Now +" .. NumberFormat.format(nowRate) .. " Charge/s"
	end

	-- Rebirth (v7, documented ladder): needs the ladder's Level, resets Speed
	-- AND Level (TotalEarned), keeps Wins, gear, chargers and step pads.
	remotes.UpgradePhone.OnServerInvoke = function(player)
		local data = DataService.profiles[player]
		if not data then
			return false, "No data"
		end
		if data.Rebirths >= #Config.REBIRTH_LEVELS then
			return false, "📱 MAX phone (" .. #Config.REBIRTH_LEVELS .. ") reached!"
		end
		local level = Economy.levelFor(data.TotalEarned)
		local req = Economy.rebirthLevelRequired(data.Rebirths)
		if level < req then
			return false, "📱 Phone upgrade " .. (data.Rebirths + 1) .. " needs Level " .. req .. " (you are " .. level .. ")"
		end
		data.Speed = 0
		data.TotalEarned = 0
		data.MaxStage = 0
		data.MaxStageW2 = 0
		data.Rebirths += 1
		DataService.syncStats(player)
		StageService.checkpoints[player] = nil
		StageService.armed[player] = {}
		StageService.resetRun(player)
		local model = Config.PHONE_MODELS[data.Rebirths] or ""
		return true, "📱 Upgraded to " .. model .. "! Gain multiplier is now x" .. NumberFormat.format(Economy.rebirthMult(data.Rebirths))
	end

	-- Ascend (v7, documented shape): max Rebirths + 200T Wins -> x8 per tier.
	-- Resets Speed, Level and Rebirths; the Wins cost is paid.
	remotes.Ascend.OnServerInvoke = function(player)
		local data = DataService.profiles[player]
		if not data then
			return false, "No data"
		end
		if data.Rebirths < Config.ASCEND_REBIRTHS_NEEDED then
			return false, "🔄 OS Update needs " .. Config.ASCEND_REBIRTHS_NEEDED .. " phone upgrades (you have " .. data.Rebirths .. ")"
		end
		if data.Wins < Config.ASCEND_WINS_COST then
			return false, "🔄 OS Update needs " .. NumberFormat.format(Config.ASCEND_WINS_COST) .. " Wins (you have " .. NumberFormat.format(data.Wins) .. ")"
		end
		data.Wins -= Config.ASCEND_WINS_COST
		data.Rebirths = 0
		data.Speed = 0
		data.TotalEarned = 0
		data.MaxStage = 0
		data.MaxStageW2 = 0
		data.Ascends += 1
		DataService.syncStats(player)
		StageService.checkpoints[player] = nil
		StageService.armed[player] = {}
		StageService.resetRun(player)
		StageService.teleportToCheckpoint(player)
		return true, "🔄 OS UPDATED! Permanent x" .. NumberFormat.format(Config.ASCEND_MULT ^ data.Ascends) .. " from OS updates"
	end

	-- Step pads (v7): buy the NEXT +Speed-per-step pad with Wins.
	remotes.BuyStep.OnServerInvoke = function(player)
		local data = DataService.profiles[player]
		if not data then
			return false, "No data"
		end
		local current = data.StepIndex or 1
		local nextPad = Config.STEP_PADS[current + 1]
		if not nextPad then
			return false, "👟 MAX step pad owned!"
		end
		if data.Wins < nextPad.cost then
			return false, "Need " .. NumberFormat.format(nextPad.cost) .. " Wins for the +" .. NumberFormat.format(nextPad.amount) .. "⚡/step link"
		end
		data.Wins -= nextPad.cost
		data.StepIndex = current + 1
		DataService.syncStats(player)
		return true, "🔗 Fast-charge link upgraded! Now +" .. NumberFormat.format(nextPad.amount) .. " Charge per step"
	end

	remotes.RedeemCode.OnServerInvoke = function(player, code)
		local data = DataService.profiles[player]
		if not data or type(code) ~= "string" then
			return false, "Invalid code"
		end
		local reward = Config.CODES[string.upper(code)]
		if not reward then
			return false, "❌ Code not found"
		end
		if data.CodesUsed[string.upper(code)] then
			return false, "Already used this code"
		end
		data.CodesUsed[string.upper(code)] = true
		if reward.speed > 0 then
			SpeedService.grantSpeed(player, reward.speed)
		end
		if reward.wins > 0 then
			data.Wins += reward.wins
			DataService.syncStats(player)
		end
		return true, "🎁 Code redeemed! +" .. NumberFormat.format(reward.speed) .. " Charge, +" .. NumberFormat.format(reward.wins) .. " Wins"
	end

	remotes.ClaimGift.OnServerInvoke = function(player)
		local data = DataService.profiles[player]
		if not data then
			return false, "No data"
		end
		local left = Config.GIFT_COOLDOWN - (os.time() - (data.LastGift or 0))
		if left > 0 then
			return false, "🎁 Free gift in " .. math.ceil(left / 60) .. " min"
		end
		data.LastGift = os.time()
		local speedGift = 1000 * (10 ^ math.floor(data.MaxStage / 5))
		local winsGift = 25 * (data.MaxStage + 1)
		SpeedService.grantSpeed(player, speedGift)
		data.Wins += winsGift
		DataService.syncStats(player)
		return true, "🎁 FREE! +" .. NumberFormat.format(speedGift) .. " Charge, +" .. NumberFormat.format(winsGift) .. " Wins"
	end

	-- Spin wheel (v6): free every 12h — speed, wins, boosts, or the jackpot.
	remotes.Spin.OnServerInvoke = function(player)
		local data = DataService.profiles[player]
		if not data then
			return false, "No data"
		end
		local left = Config.SPIN_COOLDOWN - (os.time() - (data.LastSpin or 0))
		if left > 0 then
			return false, "🎡 Free spin in " .. math.floor(left / 3600) .. "h " .. math.ceil((left % 3600) / 60) .. "m"
		end
		data.LastSpin = os.time()
		local outcome = Economy.spinOutcome(math.random(), math.max(data.MaxStage, data.MaxStageW2 or 0))
		if outcome.kind == "speed" then
			SpeedService.grantSpeed(player, outcome.amount)
			return true, "🎡 You won +" .. NumberFormat.format(outcome.amount) .. " Charge!"
		elseif outcome.kind == "wins" then
			data.Wins += outcome.amount
			DataService.syncStats(player)
			return true, "🎡 You won +" .. NumberFormat.format(outcome.amount) .. " Wins!"
		elseif outcome.kind == "boost" then
			local now = os.time()
			local activeMult = (data.BoostUntil or 0) > now and (data.BoostMult or 1) or 1
			data.BoostMult = math.max(activeMult, outcome.mult)
			data.BoostUntil = math.max(data.BoostUntil or 0, now) + outcome.minutes * 60
			return true, "🎡 BOOST! x" .. data.BoostMult .. " gains for " .. outcome.minutes .. " min!"
		else
			SpeedService.grantSpeed(player, outcome.amount)
			return true, "🎡💎 JACKPOT! +" .. NumberFormat.format(outcome.amount) .. " Charge!"
		end
	end

	remotes.SetCap.OnServerEvent:Connect(function(player, cap)
		local data = DataService.profiles[player]
		if data and type(cap) == "number" then
			data.SpeedCap = math.max(0, math.floor(cap))
		end
	end)

	remotes.Teleport.OnServerEvent:Connect(function(player, dest)
		local data = DataService.profiles[player]
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not (data and hrp) then
			return
		end
		if dest == "lobby" then
			hrp.CFrame = CFrame.new(0, 4, 80)
			StageService.checkpoints[player] = nil
		elseif dest == "world2" then
			remotes.Toast:FireClient(player, "🔒 World 2 — Social Apps — is coming in Update 1!")
		elseif dest == "world1" then
			StageService.setSpawn(player, CFrame.new(0, 4, 80))
		elseif dest == "stage" then
			local target = math.max(1, data.MaxStage + 1)
			if target > Config.STAGE_COUNT then
				target = Config.STAGE_COUNT
			end
			local zStart = -Config.STAGE_SPACING * (target - 1) - 26
			hrp.CFrame = CFrame.new(0, 3, zStart - 2)
			StageService.checkpoints[player] = CFrame.new(0, 3, zStart - 2)
		end
	end)

	-- Developer products: SkipStage + the buy-speed buttons from the screenshot.
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local data = player and DataService.profiles[player]
		if not (player and data) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if Config.PRODUCTS.SkipStage > 0 and receipt.ProductId == Config.PRODUCTS.SkipStage then
			if data.MaxStage < Config.STAGE_COUNT then
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if not hrp then
					-- Character not loaded yet: let Roblox retry the receipt.
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				local nextStage = data.MaxStage + 1
				StageService.claimStage(player, nextStage)
				local zStart = -Config.STAGE_SPACING * (nextStage - 1) - 26
				hrp.CFrame = CFrame.new(0, 3, zStart)
				StageService.checkpoints[player] = CFrame.new(0, 3, zStart)
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
			-- Every World 1 stage is already cleared: never leave a paid
			-- receipt unprocessed — grant the final stage's Wins instead.
			StageService.claimStage(player, Config.STAGE_COUNT)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		for key, amount in Config.PRODUCT_AMOUNTS do
			local pid = Config.PRODUCTS[key]
			if pid and pid > 0 and receipt.ProductId == pid then
				SpeedService.grantSpeed(player, amount)
				remotes.Toast:FireClient(player, "⚡ +" .. NumberFormat.format(amount) .. " Charge!")
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	RunService.Heartbeat:Connect(function()
		for player, sphere in signalParts do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and sphere.Parent then
				sphere.CFrame = hrp.CFrame
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if signalParts[player] then
			signalParts[player]:Destroy()
			signalParts[player] = nil
		end
	end)
end

return ShopService
