-- Shop.luau — المتاجر والباسات والترقيات والأنظمة اليومية.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Format = require(Shared.Format)

local Store = require(script.Parent.Store)
local Play = require(script.Parent.Play)

local Shop = {}
local ctx
local auraOf = {} -- [Player] = Part

local function toast(player, text)
	if ctx and ctx.toast then
		ctx.toast(player, text)
	end
end

local function ownsPassAsync(player, id)
	if id <= 0 then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
	end)
	return ok and owns == true
end

local function bestItem(owned, ladder, data)
	local bestIdx, bestMult = 0, 1
	for _, idx in owned do
		local item = ladder[idx]
		if item and item.mult > bestMult then
			bestIdx, bestMult = idx, item.mult
		end
	end
	for idx, item in ladder do
		if item.pass and data.pass[item.pass] and item.mult > bestMult then
			bestIdx, bestMult = idx, item.mult
		end
	end
	return bestIdx, bestMult
end

function Shop.refreshVisuals(player)
	local data = Store.profiles[player]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (data and root) then
		return
	end
	local old = root:FindFirstChild("GlowTrail")
	if old then
		old:Destroy()
	end
	local caseIdx = bestItem(data.cases, Config.CASES, data)
	local caseItem = Config.CASES[caseIdx]
	if caseItem then
		local a0 = root:FindFirstChild("TrailTop")
		if not a0 then
			a0 = Instance.new("Attachment")
			a0.Name = "TrailTop"
			a0.Position = Vector3.new(0, 1, 0.6)
			a0.Parent = root
		end
		local a1 = root:FindFirstChild("TrailBottom")
		if not a1 then
			a1 = Instance.new("Attachment")
			a1.Name = "TrailBottom"
			a1.Position = Vector3.new(0, -1, 0.6)
			a1.Parent = root
		end
		local trail = Instance.new("Trail")
		trail.Name = "GlowTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(Color3.fromRGB(caseItem.color[1], caseItem.color[2], caseItem.color[3]))
		trail.Lifetime = 0.6
		trail.MinLength = 0.1
		trail.Parent = root
	end
	if auraOf[player] then
		auraOf[player]:Destroy()
		auraOf[player] = nil
	end
	local sigIdx = bestItem(data.signals, Config.SIGNALS, data)
	local sigItem = Config.SIGNALS[sigIdx]
	if sigItem then
		local sphere = Instance.new("Part")
		sphere.Name = "SignalAura"
		sphere.Shape = Enum.PartType.Ball
		sphere.Size = Vector3.new(6, 6, 6)
		sphere.Transparency = 0.75
		sphere.Color = Color3.fromRGB(sigItem.color[1], sigItem.color[2], sigItem.color[3])
		sphere.Material = Enum.Material.Neon
		sphere.CanCollide = false
		sphere.Anchored = true
		sphere.Parent = workspace
		auraOf[player] = sphere
	end
end

function Shop.applyPasses(player)
	local data = Store.profiles[player]
	if not data then
		return
	end
	local gain = 1
	for key, id in Config.PASSES do
		if ownsPassAsync(player, id) then
			data.pass[key] = true
		end
	end
	if data.pass.doubleCharge then
		gain *= 2
	end
	if data.pass.vip then
		gain *= 3
		data.pass.cableGold = true
	end
	Play.passGain[player] = gain
	Play.passWins[player] = data.pass.doubleWins and 2 or 1
	Shop.refreshVisuals(player)
end

-- ===== المهام اليومية =====
local function today()
	return math.floor(os.time() / 86400)
end

local function ensureQuestDay(data)
	if data.questDay ~= today() then
		data.questDay = today()
		data.questProg = {}
		data.questDone = {}
	end
end

local function bump(player, id, amount)
	local data = Store.profiles[player]
	if not data then
		return
	end
	ensureQuestDay(data)
	if data.questDone[id] then
		return
	end
	data.questProg[id] = (data.questProg[id] or 0) + amount
end

-- ===== عند دخول لاعب (يستدعيها Main بعد تحميل البيانات) =====
function Shop.onJoin(player, data)
	ensureQuestDay(data)
	-- سلسلة الدخول اليومية
	local day = today()
	if data.loginDay ~= day then
		data.streak = (day - (data.loginDay or 0) == 1) and (data.streak or 0) + 1 or 1
		data.loginDay = day
		local c, w = Rules.daily(data.streak, data.stage)
		Play.grant(player, c)
		data.wins += w
		Store.sync(player)
		task.delay(3, function()
			toast(player, "📅 Day " .. data.streak .. " streak! +" .. Format.num(c) .. " Charge, +" .. Format.num(w) .. " Wins")
		end)
	end
	-- أرباح الغياب
	if data.lastSeen and data.lastSeen > 0 and not RunService:IsStudio() then
		local hours = (os.time() - data.lastSeen) / 3600
		if hours * 60 >= Config.OFFLINE_MIN_MIN then
			local best = 0
			for _, idx in data.chargers do
				local chg = Config.CHARGERS[idx]
				if chg then
					best = math.max(best, Rules.chargerRate(chg, data.chargerLv[idx] or 0))
				end
			end
			local earned = Rules.offline(hours, best)
			if earned > 0 then
				Play.grant(player, earned)
				task.delay(5, function()
					toast(player, "🌙 While you were away: +" .. Format.num(earned) .. " Charge!")
				end)
			end
		end
	end
	-- ترحيب بالجدد
	if data.lifetime == 0 and data.stage == 0 then
		task.delay(2, function()
			toast(player, "👋 1) Step on the APPS to gain Charge ⚡!")
		end)
		task.delay(8, function()
			toast(player, "👋 2) Clear STAGES for Wins — spend them on Cases & Signal!")
		end)
	end
	Shop.applyPasses(player)
end

local function buyLadder(player, ladder, ownedKey, idx, kindLabel)
	local data = Store.profiles[player]
	local item = ladder[idx]
	if not (data and item) then
		return false, "Invalid " .. kindLabel
	end
	if table.find(data[ownedKey], idx) then
		return false, "Already owned"
	end
	if item.pass then
		if data.pass[item.pass] then
			return false, "Already owned (pass)"
		end
		return false, "👑 Robux pass item — get it in the Shop (🛒)"
	end
	if data.wins < item.cost then
		return false, "Need " .. Format.num(item.cost) .. " Wins"
	end
	data.wins -= item.cost
	table.insert(data[ownedKey], idx)
	Store.sync(player)
	Shop.refreshVisuals(player)
	if item.pct then
		return true, "✅ " .. item.name .. " (+" .. item.pct .. "% Charge)"
	end
	return true, "✅ " .. item.name .. " (x" .. tostring(item.mult) .. ")"
end

function Shop.init(context)
	ctx = context
	local R = ctx.remotes

	Play.hooks.icons = function(player)
		bump(player, "icons", 1)
	end
	Play.hooks.stages = function(player)
		bump(player, "stages", 1)
	end
	Play.hooks.charge = function(player, seconds)
		bump(player, "charge", seconds)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.4)
			Shop.applyPasses(player)
		end)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player)
		Shop.applyPasses(player)
	end)

	R.GetState.OnServerInvoke = function(player)
		local data = Store.profiles[player]
		if not data then
			return {}
		end
		local level, into, band = Rules.level(data.lifetime)
		local nextPhone = Config.PHONES[data.phones + 1]
		return {
			cases = data.cases,
			signals = data.signals,
			items = data.items,
			chargers = data.chargers,
			chargerLv = data.chargerLv,
			linkIdx = data.linkIdx,
			pass = data.pass,
			caseMult = Play.caseMult(player),
			signalMult = Play.signalMult(player),
			itemMult = Rules.itemsMult(data.items),
			stack = Play.stack(player),
			level = level,
			levelInto = into,
			levelBand = band,
			phones = data.phones,
			nextPhoneReq = nextPhone and nextPhone.req or nil,
			nextPhoneName = nextPhone and nextPhone.name or nil,
			ascends = data.ascends,
			osMult = Config.OS_MULT ^ data.ascends,
			cap = data.cap,
			giftIn = math.max(0, Config.GIFT_EVERY - (os.time() - (data.lastGift or 0))),
			spinIn = math.max(0, Config.SPIN_EVERY - (os.time() - (data.lastSpin or 0))),
			boostUntil = data.boostUntil or 0,
			boostMult = data.boostMult or 1,
			battery = Play.batteryOf(player),
			stage = data.stage,
		}
	end

	R.BuyCase.OnServerInvoke = function(player, idx)
		return buyLadder(player, Config.CASES, "cases", idx, "case")
	end
	R.BuySignal.OnServerInvoke = function(player, idx)
		return buyLadder(player, Config.SIGNALS, "signals", idx, "signal")
	end
	R.BuyItem.OnServerInvoke = function(player, idx)
		local ok, msg = buyLadder(player, Config.ITEMS, "items", idx, "item")
		if ok then
			msg = "🎒 " .. msg
		end
		return ok, msg
	end

	R.UnlockCharger.OnServerInvoke = function(player, idx)
		local data = Store.profiles[player]
		local chg = Config.CHARGERS[idx]
		if not (data and chg) then
			return false, "Invalid station"
		end
		if table.find(data.chargers, idx) then
			return false, "Already unlocked"
		end
		if data.wins < chg.cost then
			return false, "Need " .. Format.num(chg.cost) .. " Wins"
		end
		data.wins -= chg.cost
		table.insert(data.chargers, idx)
		Store.sync(player)
		return true, "🔌 " .. chg.name .. " unlocked!"
	end

	R.UpgradeCharger.OnServerInvoke = function(player, idx)
		local data = Store.profiles[player]
		local chg = Config.CHARGERS[idx]
		if not (data and chg) then
			return false, "Invalid station"
		end
		if not table.find(data.chargers, idx) then
			return false, "Unlock this station first"
		end
		local lv = data.chargerLv[idx] or 0
		if lv >= Config.CHARGER_MAX_LV then
			return false, "⭐ MAX level"
		end
		local cost = Rules.chargerUpgradeCost(chg, lv)
		if data.wins < cost then
			return false, "Need " .. Format.num(cost) .. " Wins to upgrade"
		end
		data.wins -= cost
		data.chargerLv[idx] = lv + 1
		Store.sync(player)
		return true, "⬆️ " .. chg.name .. " Lv" .. (lv + 1) .. " — now +" .. Format.num(Rules.chargerRate(chg, lv + 1)) .. " Charge/s"
	end

	R.BuyLink.OnServerInvoke = function(player)
		local data = Store.profiles[player]
		if not data then
			return false, "No data"
		end
		local nxt = Config.LINKS[(data.linkIdx or 1) + 1]
		if not nxt then
			return false, "🔗 MAX link owned!"
		end
		if data.wins < nxt.cost then
			return false, "Need " .. Format.num(nxt.cost) .. " Wins for the +" .. Format.num(nxt.amount) .. "⚡/step link"
		end
		data.wins -= nxt.cost
		data.linkIdx += 1
		Store.sync(player)
		return true, "🔗 Link upgraded! Now +" .. Format.num(nxt.amount) .. " Charge per step"
	end

	R.UpgradePhone.OnServerInvoke = function(player)
		local data = Store.profiles[player]
		if not data then
			return false, "No data"
		end
		local nxt = Config.PHONES[data.phones + 1]
		if not nxt then
			return false, "📱 MAX phone reached!"
		end
		local level = Rules.level(data.lifetime)
		if level < nxt.req then
			return false, "📱 " .. nxt.name .. " needs Level " .. nxt.req .. " (you are " .. level .. ")"
		end
		data.charge = 0
		data.lifetime = 0
		data.stage = 0
		data.phones += 1
		Store.sync(player)
		Play.resetRun(player)
		return true, "📱 Upgraded to " .. nxt.name .. "! Gains now x" .. Format.num(Rules.phoneMult(data.phones))
	end

	R.OSUpdate.OnServerInvoke = function(player)
		local data = Store.profiles[player]
		if not data then
			return false, "No data"
		end
		if data.phones < Config.OS_PHONES_NEEDED then
			return false, "🔄 OS Update needs " .. Config.OS_PHONES_NEEDED .. " phone upgrades (you have " .. data.phones .. ")"
		end
		if data.wins < Config.OS_WINS_COST then
			return false, "🔄 OS Update needs " .. Format.num(Config.OS_WINS_COST) .. " Wins"
		end
		data.wins -= Config.OS_WINS_COST
		data.phones = 0
		data.charge = 0
		data.lifetime = 0
		data.stage = 0
		data.ascends += 1
		Store.sync(player)
		Play.resetRun(player)
		Play.toLobby(player)
		return true, "🔄 OS UPDATED! Permanent x" .. Format.num(Config.OS_MULT ^ data.ascends) .. " from OS updates"
	end

	R.RedeemCode.OnServerInvoke = function(player, code)
		local data = Store.profiles[player]
		if not data or type(code) ~= "string" then
			return false, "Invalid code"
		end
		local key = string.upper(code)
		local reward = Config.CODES[key]
		if not reward then
			return false, "❌ Code not found"
		end
		if data.codes[key] then
			return false, "Already used this code"
		end
		data.codes[key] = true
		if reward.charge > 0 then
			Play.grant(player, reward.charge)
		end
		if reward.wins > 0 then
			data.wins += reward.wins
			Store.sync(player)
		end
		return true, "🎁 Code redeemed! +" .. Format.num(reward.charge) .. " Charge, +" .. Format.num(reward.wins) .. " Wins"
	end

	R.ClaimGift.OnServerInvoke = function(player)
		local data = Store.profiles[player]
		if not data then
			return false, "No data"
		end
		local left = Config.GIFT_EVERY - (os.time() - (data.lastGift or 0))
		if left > 0 then
			return false, "🎁 Free gift in " .. math.ceil(left / 60) .. " min"
		end
		data.lastGift = os.time()
		local c = 1000 * (10 ^ math.floor(data.stage / 5))
		local w = 25 * (data.stage + 1)
		Play.grant(player, c)
		data.wins += w
		Store.sync(player)
		return true, "🎁 FREE! +" .. Format.num(c) .. " Charge, +" .. Format.num(w) .. " Wins"
	end

	R.Spin.OnServerInvoke = function(player)
		local data = Store.profiles[player]
		if not data then
			return false, "No data"
		end
		local left = Config.SPIN_EVERY - (os.time() - (data.lastSpin or 0))
		if left > 0 then
			return false, "🎡 Free spin in " .. math.floor(left / 3600) .. "h " .. math.ceil((left % 3600) / 60) .. "m"
		end
		data.lastSpin = os.time()
		local outcome = Rules.spin(math.random(), data.stage)
		if outcome.kind == "charge" then
			Play.grant(player, outcome.amount)
			return true, "🎡 You won +" .. Format.num(outcome.amount) .. " Charge!"
		elseif outcome.kind == "wins" then
			data.wins += outcome.amount
			Store.sync(player)
			return true, "🎡 You won +" .. Format.num(outcome.amount) .. " Wins!"
		elseif outcome.kind == "boost" then
			local now = os.time()
			local active = (data.boostUntil or 0) > now and (data.boostMult or 1) or 1
			data.boostMult = math.max(active, outcome.mult)
			data.boostUntil = math.max(data.boostUntil or 0, now) + outcome.minutes * 60
			return true, "🎡 BOOST! x" .. data.boostMult .. " gains for " .. outcome.minutes .. " min!"
		end
		Play.grant(player, outcome.amount)
		return true, "🎡💎 JACKPOT! +" .. Format.num(outcome.amount) .. " Charge!"
	end

	R.GetQuests.OnServerInvoke = function(player)
		local data = Store.profiles[player]
		if not data then
			return {}
		end
		ensureQuestDay(data)
		local list = {}
		for _, q in Config.QUESTS do
			table.insert(list, {
				id = q.id,
				text = q.text,
				target = q.target,
				progress = math.floor(data.questProg[q.id] or 0),
				claimed = data.questDone[q.id] == true,
			})
		end
		return { streak = data.streak or 1, quests = list }
	end

	R.ClaimQuest.OnServerInvoke = function(player, id)
		local data = Store.profiles[player]
		if not data then
			return false, "No data"
		end
		ensureQuestDay(data)
		for _, q in Config.QUESTS do
			if q.id == id then
				if data.questDone[id] then
					return false, "Already claimed"
				end
				if (data.questProg[id] or 0) < q.target then
					return false, "Quest not finished yet"
				end
				data.questDone[id] = true
				if q.charge > 0 then
					Play.grant(player, q.charge)
				end
				if q.wins > 0 then
					data.wins += q.wins
					Store.sync(player)
				end
				return true, "🎖️ Quest done! +" .. Format.num(q.charge) .. " Charge, +" .. Format.num(q.wins) .. " Wins"
			end
		end
		return false, "Unknown quest"
	end

	R.SetCap.OnServerEvent:Connect(function(player, cap)
		local data = Store.profiles[player]
		if data and type(cap) == "number" then
			data.cap = math.max(0, math.floor(cap))
		end
	end)

	R.Teleport.OnServerEvent:Connect(function(player, dest)
		local data = Store.profiles[player]
		if not data then
			return
		end
		if dest == "lobby" then
			Play.toLobby(player)
		elseif dest == "stage" then
			local target = math.min(data.stage + 1, #Config.STAGES)
			local cf = Play.stageStart(target)
			if cf then
				Play.sendTo(player, cf)
			end
		elseif dest == "world2" then
			toast(player, "🔒 World 2 — Social Apps — is coming in Update 1!")
		end
	end)

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local data = player and Store.profiles[player]
		if not (player and data) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if Config.PRODUCTS.skipStage > 0 and receipt.ProductId == Config.PRODUCTS.skipStage then
			if data.stage >= #Config.STAGES then
				Play.claimSkip(player, #Config.STAGES)
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not root then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			local nxt = data.stage + 1
			Play.claimSkip(player, nxt)
			local cf = Play.stageStart(nxt)
			if cf then
				Play.sendTo(player, cf)
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		for key, amount in Config.PACK_AMOUNTS do
			local pid = Config.PRODUCTS[key]
			if pid and pid > 0 and receipt.ProductId == pid then
				Play.grant(player, amount)
				toast(player, "⚡ +" .. Format.num(amount) .. " Charge!")
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	RunService.Heartbeat:Connect(function()
		for player, sphere in auraOf do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and sphere.Parent then
				sphere.CFrame = root.CFrame
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if auraOf[player] then
			auraOf[player]:Destroy()
			auraOf[player] = nil
		end
	end)
end

return Shop
