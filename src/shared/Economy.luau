-- Economy: pure math for the Keyboard formula. Loaded by server AND lune tests.
-- v7: numbers aligned to the real +1 Speed Keyboard Escape (researched
-- 2026-10-23): stages gated by LEVEL, documented Wins tables, documented
-- Trails/Auras/Items/Rebirth ladders.
-- Sibling require, Roblox-style. The Lune tests load this file through a
-- small shim (tests/run.luau) in which `script.Parent.Config` resolves to
-- the already-loaded Config module — so no string-path requires appear
-- inside Roblox modules, per the project rule.
local Config = require(script.Parent.Config)

local Economy = {}

-- Stage gates need LEVEL (not raw Speed), like the original.
function Economy.stageLevelReq(stageIndex: number, world: number?): number
	if world == 2 then
		return Config.STAGE_LEVEL_REQS_W2[stageIndex] or math.huge
	end
	return Config.STAGE_LEVEL_REQS[stageIndex] or math.huge
end

function Economy.stageReward(stageIndex: number, world: number?): number
	if world == 2 then
		return Config.STAGE_WINS_W2[stageIndex] or 0
	end
	return Config.STAGE_WINS[stageIndex] or 0
end

function Economy.stageCount(world: number?): number
	return Config.WORLD_STAGE_COUNT[world or 1] or Config.STAGE_COUNT
end

-- Stage course plan for a stage (v8). World 2 reuses World 1's plans
-- rotated by 3 (harder courses) — the builder applies difficulty scaling.
function Economy.stagePlan(stageIndex: number, world: number?): any
	if world == 2 then
		return Config.STAGE_PLANS[((stageIndex + 2) % #Config.STAGE_PLANS) + 1]
	end
	return Config.STAGE_PLANS[stageIndex]
end

-- Par (gold-medal) time in seconds for a stage run.
function Economy.parTime(stageIndex: number, world: number?): number
	return (18 + stageIndex * 2) * (world == 2 and 1.15 or 1)
end

-- Run bonus (v8): returns total bonus percent and the medal name (""/none).
function Economy.runBonus(stars: number, falls: number, elapsed: number, par: number): (number, string)
	local pct = stars * Config.STAR_BONUS_PCT
	if falls == 0 then
		pct += Config.NOFALL_BONUS_PCT
	end
	local medal = ""
	if elapsed <= par then
		medal = "gold"
		pct += Config.MEDAL_BONUS.gold
	elseif elapsed <= par * 1.6 then
		medal = "silver"
		pct += Config.MEDAL_BONUS.silver
	elseif elapsed <= par * 2.5 then
		medal = "bronze"
		pct += Config.MEDAL_BONUS.bronze
	end
	return pct, medal
end

-- Spin wheel (v6): roll is 0..1. Returns a table describing the prize.
function Economy.spinOutcome(roll: number, maxStage: number): { kind: string, amount: number, mult: number, minutes: number }
	local tier = 10 ^ math.floor(maxStage / 5)
	if roll < 0.34 then
		return { kind = "speed", amount = 2000 * tier, mult = 1, minutes = 0 }
	elseif roll < 0.58 then
		return { kind = "wins", amount = 150 * (maxStage + 1), mult = 1, minutes = 0 }
	elseif roll < 0.78 then
		return { kind = "boost", amount = 0, mult = 2, minutes = 15 }
	elseif roll < 0.93 then
		return { kind = "boost", amount = 0, mult = 3, minutes = 10 }
	else
		return { kind = "jackpot", amount = 100000 * tier, mult = 1, minutes = 0 }
	end
end

-- Level from LIFETIME speed earned. Returns level, progress into the level, band size.
-- NOTE: Rebirth/Ascend reset the lifetime total (the original resets Level).
function Economy.levelFor(totalEarned: number): (number, number, number)
	local level = 1
	local remaining = totalEarned
	while true do
		local band = Config.LEVEL_BASE * (Config.LEVEL_GROWTH ^ (level - 1))
		if remaining < band then
			return level, remaining, band
		end
		remaining -= band
		level += 1
		if level > 5000 then
			return level, remaining, band
		end
	end
end

-- Rebirth ladder (documented 1-20). Next rebirth index = currentRebirths + 1.
function Economy.rebirthLevelRequired(currentRebirths: number): number
	return Config.REBIRTH_LEVELS[currentRebirths + 1] or math.huge
end

function Economy.rebirthMult(currentRebirths: number): number
	if currentRebirths <= 0 then
		return 1
	end
	return Config.REBIRTH_MULTS[currentRebirths] or Config.REBIRTH_MULTS[#Config.REBIRTH_MULTS]
end

-- The full gain stack: Rebirth x Ascend x Trail x Aura x Items x Passes
function Economy.gainMultiplier(rebirthMult: number, ascends: number, caseMult: number, signalMult: number, itemMult: number, passMult: number): number
	return rebirthMult * (Config.ASCEND_MULT ^ ascends) * caseMult * signalMult * itemMult * passMult
end

-- Items give +% each and the percentages SUM (original behavior).
function Economy.itemsMult(ownedItems: { number }): number
	local pct = 0
	for _, idx in ownedItems do
		local item = Config.ITEMS[idx]
		if item then
			pct += item.pct
		end
	end
	return 1 + pct / 100
end

-- Free-progression math (v4)
function Economy.dailyReward(streak: number, maxStage: number): (number, number)
	local tier = 10 ^ math.floor(maxStage / 5)
	return 500 * streak * tier, 25 * streak * (maxStage + 1)
end

function Economy.offlineSpeed(hoursAway: number, bestChargerPerSecond: number): number
	local hours = math.min(math.max(hoursAway, 0), Config.OFFLINE_CAP_HOURS)
	return math.floor(hours * 3600 * bestChargerPerSecond * Config.OFFLINE_EFFICIENCY)
end

-- Charger upgrades (v5): upgrade k adds rate x 2.5 x 5^(k-1).
-- Effective rate at level L = rate x (1 + 0.625 x (5^L - 1)).
function Economy.chargerRate(tm: any, level: number): number
	return tm.rate * (1 + 0.625 * ((5 ^ level) - 1))
end

function Economy.chargerOutput(tm: any, level: number): number
	return Economy.chargerRate(tm, level) * tm.mult
end

-- Cost in Wins to go from `currentLevel` to the next level.
function Economy.chargerUpgradeCost(tm: any, currentLevel: number): number
	local base = (tm.cost and tm.cost > 0) and tm.cost or 150
	return base * (6 ^ currentLevel)
end

function Economy.bestOwned(owned: { number }, ladder: { any }): (number, number)
	local bestIndex, bestMult = 0, 1
	for _, idx in owned do
		local item = ladder[idx]
		if item and item.mult > bestMult then
			bestIndex, bestMult = idx, item.mult
		end
	end
	return bestIndex, bestMult
end

return Economy
