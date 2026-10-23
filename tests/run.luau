-- Lune tests for the Phone Escape economy's pure modules: `lune run tests/run.luau`
local NumberFormat = require("../src/shared/NumberFormat")
local Config = require("../src/shared/Config")
-- Economy requires its sibling the Roblox way (require(script.Parent.Config)),
-- so Lune loads it through this shim: here `script.Parent.Config` IS the
-- already-loaded Config module, and require() hands it straight back.
local Economy = (function()
	local fs = require("@lune/fs")
	local luau = require("@lune/luau")
	local source = fs.readFile("src/shared/Economy.luau")
	local env = {
		script = { Parent = { Config = Config } },
		require = function(module)
			return module
		end,
		math = math,
		string = string,
		table = table,
		pairs = pairs,
		ipairs = ipairs,
		tostring = tostring,
		tonumber = tonumber,
		type = type,
		select = select,
	}
	return luau.load(source, { debugName = "Economy", environment = env })()
end)()

local passed, failed = 0, 0
local function eq(got, want, name)
	if got == want then
		passed += 1
	else
		failed += 1
		print("FAIL", name, "got", got, "want", want)
	end
end
local function ok(cond, name)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL", name)
	end
end
local function near(got, want, name)
	if math.abs(got - want) < 1e-9 then
		passed += 1
	else
		failed += 1
		print("FAIL", name, "got", got, "want", want)
	end
end

-- NumberFormat: his numbers
eq(NumberFormat.format(999), "999", "fmt 999")
eq(NumberFormat.format(1500), "1.5K", "fmt 1.5K")
eq(NumberFormat.format(1000000), "1M", "fmt 1M")
eq(NumberFormat.format(5e12), "5T", "fmt 5T")
eq(NumberFormat.format(5e21), "5000Qi", "fmt 5e21 in Qi (no Zillion in the original)")
eq(NumberFormat.format(1.5e15), "1.5Qa", "fmt Qa")
eq(NumberFormat.format(200000000000000), "200T", "fmt 200T")

-- Keyboard floor dimensions
eq(Config.APP_COLS * Config.APP_ROWS, 432, "432 app icons on the home screen")
ok(#Config.APP_GLYPHS >= 12, "app glyphs for the icons")

-- Stages (v7): LEVEL gates + documented Wins tables, like the original
eq(Config.STAGE_COUNT, 15, "15 stages in World 1")
eq(#Config.STAGE_LEVEL_REQS_W2, 12, "12 stages in World 2")
local inc = true
for i = 2, 15 do
	if Config.STAGE_LEVEL_REQS[i] <= Config.STAGE_LEVEL_REQS[i - 1] then
		inc = false
	end
end
ok(inc, "stage level reqs strictly increase")
eq(Economy.stageLevelReq(10), 70, "W1 stage 10 recommends Level 70 (documented)")
eq(Economy.stageLevelReq(15), 120, "W1 stage 15 = Level 120")
eq(Economy.stageLevelReq(1, 2), 140, "W2 stage 1 recommends Level 140 (documented)")
eq(Economy.stageLevelReq(12, 2), 360, "W2 stage 12 = 140 + 11x20")
eq(Economy.stageReward(1), 1, "W1 s1 wins = 1 (documented)")
eq(Economy.stageReward(7), 150, "W1 s7 wins = 150")
eq(Economy.stageReward(15), 150000, "W1 s15 wins = 150K")
eq(Economy.stageReward(1, 2), 250000, "W2 s1 wins = 250K (documented)")
eq(Economy.stageReward(12, 2), 40000000, "W2 s12 wins = 40M")

-- Levels: band(L) = 100 * 2.2^(L-1), cumulative
local lvl, into, band = Economy.levelFor(0)
eq(lvl, 1, "level at 0")
eq(into, 0, "into at 0")
eq(band, 100, "band 1 = 100")
lvl, into, band = Economy.levelFor(100)
eq(lvl, 2, "level at 100")
eq(into, 0, "into at 100")
near(band, 220, "band 2 = 220")
lvl, into = Economy.levelFor(150)
eq(lvl, 2, "level at 150")
eq(into, 50, "into at 150")
lvl = Economy.levelFor(100 + 220 + 484 + 1)
eq(lvl, 4, "level after 3 bands")

-- Rebirth ladder (v7, documented 1-20)
eq(Economy.rebirthLevelRequired(0), 15, "rebirth 1 needs Level 15 (documented)")
eq(Economy.rebirthLevelRequired(9), 200, "rebirth 10 needs Level 200")
eq(Economy.rebirthLevelRequired(19), 600, "rebirth 20 needs Level 600")
eq(Economy.rebirthLevelRequired(20), 650, "upgrade 21 needs Level 650")
eq(Economy.rebirthLevelRequired(31), 1530, "upgrade 32 needs Level 1530")
eq(Economy.rebirthLevelRequired(32), math.huge, "no upgrade 33")
eq(Economy.rebirthMult(0), 1, "no rebirth = x1")
eq(Economy.rebirthMult(1), 1.5, "rebirth 1 = x1.5")
eq(Economy.rebirthMult(10), 10, "rebirth 10 = x10")
eq(Economy.rebirthMult(11), 100, "rebirth 11 = x100")
eq(Economy.rebirthMult(20), 100000000000, "rebirth 20 = x100B")
eq(Config.ASCEND_REBIRTHS_NEEDED, 32, "OS update needs 32 phone upgrades")
eq(#Config.PHONE_MODELS, 32, "32 phone models")
eq(#Config.REBIRTH_LEVELS, 32, "32 upgrade level rungs")
eq(#Config.REBIRTH_MULTS, 32, "32 upgrade mult rungs")
eq(Economy.rebirthMult(32), 1e23, "upgrade 32 = x1e23")
eq(Config.ASCEND_MULT, 8, "ascend x8 per tier (documented)")
eq(Config.ASCEND_WINS_COST, 200000000000000, "ascend costs 200T wins")

-- Full multiplier stack: rebirthMult x 8^asc x trail x aura x item x pass
eq(Economy.gainMultiplier(1, 0, 1, 1, 1, 1), 1, "mult base")
eq(Economy.gainMultiplier(3, 1, 10, 3, 2, 2), 3 * 8 * 10 * 3 * 2 * 2, "mult full stack")

-- Ladders (v7, documented values)
eq(Config.CASES[1].name, "غطاء أخضر", "first case is the green case")
eq(Config.CASES[1].mult, 1.5, "green case x1.5")
eq(Config.CASES[1].cost, 500, "green case 500 wins")
eq(Config.INFINITY_CASE.mult, 5000000, "Infinity x5M (documented, corrects x1M)")
local godlike
local galaxyT
for _, tr in Config.CASES do
	if tr.name == "غطاء إلهي" then godlike = tr end
	if tr.name == "غطاء المجرة" then galaxyT = tr end
end
eq(godlike.mult, 100000, "godlike case x100K")
eq(godlike.cost, 5000000000, "godlike case 5B wins")
eq(galaxyT.pass, "GalaxyCase", "Galaxy is a pass trail")
eq(Config.SIGNALS[1].mult, 1.2, "signal glow x1.2")
eq(Config.SIGNALS[1].cost, 1000000, "signal glow 1M wins")
local darkness = Config.SIGNALS[#Config.SIGNALS]
eq(darkness.name, "إشارة الظلام", "top signal is Darkness")
eq(darkness.mult, 10, "Darkness x10")
eq(darkness.pass, "DarknessSignal", "Darkness is a pass aura")
-- Items: +% values SUM (original behavior)
eq(Config.ITEMS[1].pct, 3, "Common +3%")
eq(Config.ITEMS[1].cost, 3000, "Common 3K wins")
eq(Config.ITEMS[#Config.ITEMS].pct, 100, "Golden Mask +100%")
eq(Config.ITEMS[#Config.ITEMS].cost, 1000000000, "Golden Mask 1B wins")
eq(Economy.itemsMult({}), 1, "no items = x1")
near(Economy.itemsMult({ 1, 2, 3, 4, 5, 6, 7 }), 3.08, "all items = +208%")

-- Step pads (v7): documented rungs + documented top
eq(Config.STEP_PADS[1].amount, 1, "base step +1")
eq(Config.STEP_PADS[2].cost, 3, "+2 step costs 3 wins (documented)")
eq(Config.STEP_PADS[8].amount, 500, "step rung +500")
eq(Config.STEP_PADS[8].cost, 50000, "+500 step costs 50K (documented)")
eq(Config.STEP_PADS[#Config.STEP_PADS].amount, 500000000, "top step +500M")
eq(Config.STEP_PADS[#Config.STEP_PADS].cost, 7500000000000, "top step 7.5T wins (documented)")
local stepsInc = true
for i = 2, #Config.STEP_PADS do
	if Config.STEP_PADS[i].amount <= Config.STEP_PADS[i - 1].amount or Config.STEP_PADS[i].cost <= Config.STEP_PADS[i - 1].cost then
		stepsInc = false
	end
end
ok(stepsInc, "step pads strictly increase")

-- Chargers
eq(#Config.CHARGERS, 8, "8 charging stations")
eq(Config.CHARGERS[1].cost, 0, "starter free")
eq(Config.CHARGERS[8].cost, 250000000, "top station costs 250M wins")

-- Codes & products
ok(Config.CODES.LAUNCH ~= nil and Config.CODES.LAUNCH.speed == 1000, "LAUNCH code")
eq(Config.PRODUCT_AMOUNTS.Charge10M, 10000000, "+10M product amount")
ok(Config.GIFT_COOLDOWN > 0, "gift cooldown set")

-- bestOwned
local idx, mult = Economy.bestOwned({ 2, 5 }, Config.CASES)
eq(idx, 5, "best trail index")
eq(mult, 5, "best trail mult (Rainbow x5)")

-- Free progression (v4): daily rewards scale with streak & stage tier
local ds, dw = Economy.dailyReward(1, 0)
eq(ds, 500, "daily speed day1")
eq(dw, 25, "daily wins day1")
ds, dw = Economy.dailyReward(3, 7)
eq(ds, 500 * 3 * 10, "daily speed streak3 stage7")
eq(dw, 25 * 3 * 8, "daily wins streak3 stage7")
-- Offline: 50% efficiency, 8h cap, best charger per-second output
eq(Economy.offlineSpeed(1, 10), 18000, "offline 1h @10/s")
eq(Economy.offlineSpeed(100, 10), 8 * 3600 * 10 * 0.5, "offline capped at 8h")
eq(Economy.offlineSpeed(0, 10), 0, "offline zero")
-- Quests are defined and sane
eq(#Config.QUESTS, 3, "3 daily quests")
for _, qdef in Config.QUESTS do
	ok(qdef.target > 0 and (qdef.wins > 0 or qdef.speed > 0), "quest " .. qdef.id .. " has a reward")
end
ok(Config.GIFT_COOLDOWN <= 300, "gift cooldown is generous")

-- Charger upgrades (v5): his numbers — Starter +20, then +100, then +500
local starter = Config.CHARGERS[1]
eq(Economy.chargerRate(starter, 0), 2, "USB base rate = 2/s")
eq(Economy.chargerRate(starter, 1), 7, "USB lv1 = 2 + 5")
eq(Economy.chargerRate(starter, 2), 32, "USB lv2")
eq(Economy.chargerRate(starter, 3), 157, "USB lv3")
eq(Economy.chargerOutput(Config.CHARGERS[4], 0), 250, "wireless dock output lv0 = 250/s")
ok(Economy.chargerRate(starter, 8) > Economy.chargerRate(starter, 7), "upgrades keep growing")
eq(Economy.chargerUpgradeCost(starter, 0), 150, "starter upgrade 1 cost")
eq(Economy.chargerUpgradeCost(starter, 1), 900, "starter upgrade 2 cost")
eq(Economy.chargerUpgradeCost(Config.CHARGERS[4], 0), 25000, "dock upgrade scales with its cost")
eq(Config.CHARGER_MAX_LEVEL, 8, "8 upgrade levels")

-- Battery (new mechanic): drains on boss stages, pickups refill
ok(Config.BATTERY_DRAIN_PCT > 0 and Config.BATTERY_DRAIN_PCT < 3, "battery drain sane")
eq(Config.BATTERY_PICKUP_PCT, 10, "battery pickup +10%")
-- Cables: station-output passes (documented mults 3/9/25/100)
eq(#Config.CABLES, 4, "4 Robux cables")
eq(Config.CABLES[1].mult, 3, "gold cable x3")
eq(Config.CABLES[4].mult, 100, "admin cable x100")
ok(Config.PASSES.CableAdmin ~= nil and Config.PASSES.CableGold ~= nil, "cable passes defined")

-- World 2 (v7): Level-120 unlock, documented wins table
eq(Config.WORLD2_UNLOCK_LEVEL, 120, "W2 unlocks at Level 120 (documented)")
eq(Economy.stageCount(1), 15, "stageCount W1")
eq(Economy.stageCount(2), 12, "stageCount W2")

-- Spin wheel (v6): every prize band reachable and sane
local kinds = {}
for _, roll in { 0.05, 0.4, 0.65, 0.85, 0.97 } do
	local o = Economy.spinOutcome(roll, 0)
	kinds[o.kind] = true
	if o.kind == "boost" then
		ok(o.mult >= 2 and o.minutes >= 5, "boost prize sane")
	else
		ok(o.amount > 0, "spin prize positive")
	end
end
ok(kinds.speed and kinds.wins and kinds.boost and kinds.jackpot, "all spin kinds reachable")
local o1 = Economy.spinOutcome(0.05, 10)
local o2 = Economy.spinOutcome(0.05, 0)
ok(o1.amount > o2.amount, "spin scales with progress")
ok(Config.SPIN_COOLDOWN >= 3600, "spin cooldown sane")

-- Stage plans (v8): named courses, boss every 5, known elements, ~84 studs
eq(#Config.STAGE_PLANS, 15, "15 stage plans")
local known = { run = true, gap = true, moving = true, movingy = true, vanish = true, convF = true, convB = true, bounce = true, sweep = true, narrow = true, tower = true, split = true, mid = true }
local namesSeen = {}
for si, plan in Config.STAGE_PLANS do
	ok(plan.name and not namesSeen[plan.name], "plan " .. si .. " has a unique name")
	namesSeen[plan.name] = true
	local total = 0
	for _, token in plan.elements do
		local nm, ar = string.match(token, "^(%a+):?(%d*)$")
		ok(known[nm] == true, "plan " .. si .. " element " .. token .. " is known")
		total += tonumber(ar) or 0
	end
	ok(total <= 84, "plan " .. si .. " fits the 84-stud run (got " .. total .. ")")
	ok(total >= 60, "plan " .. si .. " is substantial (got " .. total .. ")")
end
ok(Config.STAGE_PLANS[5].boss and Config.STAGE_PLANS[10].boss and Config.STAGE_PLANS[15].boss, "boss stages at 5/10/15")
eq(Config.STAGE_PLANS[1].elements[1], "run:84", "stage 1 is a pure tutorial run")
eq(Economy.stagePlan(1, 2).name, Config.STAGE_PLANS[4].name, "W2 reuses plans rotated by 3")
-- Run bonuses (v8)
local pct, medal = Economy.runBonus(0, 1, 999, 20)
eq(pct, 0, "slow run with falls = no bonus")
eq(medal, "", "no medal for a slow run")
pct, medal = Economy.runBonus(3, 0, 20, 20)
eq(medal, "gold", "at par = gold")
eq(pct, 3 * 25 + 50 + 50, "3 stars + flawless + gold = +175%")
pct, medal = Economy.runBonus(0, 2, 30, 20)
eq(medal, "silver", "1.5x par = silver")
eq(pct, 25, "silver alone = +25%")
ok(Economy.parTime(15, 1) > Economy.parTime(1, 1), "par grows with stage")

print(string.format("Phone tests: %d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
