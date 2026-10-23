-- SpeedService: the heart of the Keyboard formula.
-- * Stepping on a keyboard KEY = +1 Speed (key lights up, per-player cooldown
--   so you must keep running across keys).
-- * Standing on an owned TREADMILL = +rate x pad-mult per second.
-- * Everything is multiplied by (1+rebirths) x trail x aura x passes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)

local DataService = require(script.Parent.DataService)

local SpeedService = {}
SpeedService.passMult = {} -- [Player] = gains multiplier from passes
SpeedService.winMult = {} -- [Player] = wins multiplier from passes
SpeedService.toastFn = nil -- set by ServerMain: (player, text) -> ()
SpeedService.hooks = {} -- optional: onKey(player), onTrain(player, seconds) — set by ServerMain for quests
local frac = {}
local keyCooldown = {} -- [Player] = {[BasePart] = os.clock()}

-- Best multiplier from a ladder, including Robux-pass entries whose
-- ownership flag lives on the profile (data.GalaxyCase, data.InfinityCase…)
local function ladderMult(data, owned, ladder): number
	local _, mult = Economy.bestOwned(owned, ladder)
	for _, item in ladder do
		if item.pass and data[item.pass] then
			mult = math.max(mult, item.mult)
		end
	end
	return mult
end

function SpeedService.caseMult(player: Player): number
	local data = DataService.profiles[player]
	if not data then
		return 1
	end
	return ladderMult(data, data.CasesOwned, Config.CASES)
end

function SpeedService.signalMult(player: Player): number
	local data = DataService.profiles[player]
	if not data then
		return 1
	end
	return ladderMult(data, data.SignalsOwned, Config.SIGNALS)
end

-- Robux cable multiplier: applies ONLY to charging-station output
-- (from the original's treadmill passes: Gold x3 / Diamond x9 / ...).
function SpeedService.cableMult(player: Player): number
	local data = DataService.profiles[player]
	if not data then
		return 1
	end
	local mult = 1
	for _, cable in Config.CABLES do
		if data[cable.pass] then
			mult = math.max(mult, cable.mult)
		end
	end
	return mult
end

function SpeedService.itemMult(player: Player): number
	local data = DataService.profiles[player]
	if not data then
		return 1
	end
	return Economy.itemsMult(data.ItemsOwned)
end

function SpeedService.gainMult(player: Player): number
	local data = DataService.profiles[player]
	if not data then
		return 1
	end
	return Economy.gainMultiplier(Economy.rebirthMult(data.Rebirths), data.Ascends, SpeedService.caseMult(player), SpeedService.signalMult(player), SpeedService.itemMult(player), SpeedService.passMult[player] or 1)
end

function SpeedService.addSpeed(player: Player, baseAmount: number)
	local data = DataService.profiles[player]
	if not data then
		return
	end
	local mult = SpeedService.gainMult(player)
	-- Temporary spin boost (v6): multiplies active play gains only.
	if data.BoostUntil and data.BoostUntil > os.time() and data.BoostMult then
		mult *= data.BoostMult
	end
	frac[player] = (frac[player] or 0) + baseAmount * mult
	local whole = math.floor(frac[player])
	if whole > 0 then
		frac[player] -= whole
		data.Speed += whole
		data.TotalEarned += whole
		DataService.syncStats(player)
	end
end

-- Direct grant (products, codes, gift): counts toward lifetime/Level too.
function SpeedService.grantSpeed(player: Player, amount: number)
	local data = DataService.profiles[player]
	if not data then
		return
	end
	data.Speed += amount
	data.TotalEarned += amount
	DataService.syncStats(player)
end

local function walkSpeedFor(speedStat: number): number
	return math.min(16 + math.sqrt(math.max(speedStat, 0)) / 4, 250)
end

function SpeedService.applyWalkSpeed(player: Player)
	local data = DataService.profiles[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if data and hum then
		local effective = data.Speed
		if data.SpeedCap and data.SpeedCap > 0 then
			effective = math.min(effective, data.SpeedCap)
		end
		hum.WalkSpeed = walkSpeedFor(effective)
	end
end

local function partsUnderPlayer(player: Player): { BasePart }
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return {}
	end
	local map = workspace:FindFirstChild("PhoneMap")
	if not map then
		return {}
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	return workspace:GetPartBoundsInBox(CFrame.new(hrp.Position - Vector3.new(0, 2.6, 0)), Vector3.new(3.4, 2.2, 3.4), params)
end

local keyFlashBusy = {}
local function flashKey(key: BasePart)
	if keyFlashBusy[key] then
		return
	end
	keyFlashBusy[key] = true
	local origColor, origMat = key.Color, key.Material
	key.Color = Color3.fromRGB(120, 255, 140)
	key.Material = Enum.Material.Neon
	task.delay(0.25, function()
		if key.Parent then
			key.Color = origColor
			key.Material = origMat
		end
		keyFlashBusy[key] = nil
	end)
end

function SpeedService.init()
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local data = DataService.profiles[player]
			if not data then
				continue
			end
			keyCooldown[player] = keyCooldown[player] or {}
			for _, hit in partsUnderPlayer(player) do
				if hit:GetAttribute("IsApp") then
					local last = keyCooldown[player][hit] or 0
					if now - last >= Config.APP_COOLDOWN then
						keyCooldown[player][hit] = now
						local stepPad = Config.STEP_PADS[data.StepIndex or 1] or Config.STEP_PADS[1]
						SpeedService.addSpeed(player, stepPad.amount)
						flashKey(hit)
						if SpeedService.hooks.onKey then
							SpeedService.hooks.onKey(player)
						end
					end
				elseif hit:GetAttribute("ChargerIndex") then
					local idx = hit:GetAttribute("ChargerIndex")
					local tm = Config.CHARGERS[idx]
					if tm then
						if table.find(data.ChargersOwned, idx) then
							local level = (data.ChargerLevels and data.ChargerLevels[idx]) or 0
							SpeedService.addSpeed(player, Economy.chargerOutput(tm, level) * SpeedService.cableMult(player) * dt)
							if SpeedService.hooks.onTrain then
								SpeedService.hooks.onTrain(player, dt)
							end
						elseif SpeedService.toastFn and (now - (keyCooldown[player].tmToast or 0)) > 4 then
							keyCooldown[player].tmToast = now
							SpeedService.toastFn(player, "🔒 Buy the " .. tm.name .. " station in the Chargers panel")
						end
					end
				end
			end
			SpeedService.applyWalkSpeed(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		frac[player] = nil
		keyCooldown[player] = nil
		SpeedService.passMult[player] = nil
		SpeedService.winMult[player] = nil
	end)
end

return SpeedService
