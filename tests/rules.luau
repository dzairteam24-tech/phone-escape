-- rules.luau — اختبارات الرياضيات النقية (Config + Format + Rules).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Config = require("../src/shared/Config")
local Format = require("../src/shared/Format")

local SENTINEL = {}
local Rules = luau.load(fs.readFile("src/shared/Rules.luau"), {
	debugName = "Rules",
	environment = {
		script = { Parent = { Config = SENTINEL } },
		require = function(x)
			if x == SENTINEL then
				return Config
			end
			error("unexpected require")
		end,
		math = math,
		table = table,
		string = string,
	},
})()

local passed, failed = 0, 0
local function eq(got, want, label)
	if got == want then
		passed += 1
	else
		failed += 1
		print(("FAIL %s: got %s want %s"):format(label, tostring(got), tostring(want)))
	end
end
local function ok(cond, label)
	eq(cond and true or false, true, label)
end

-- Format
eq(Format.num(0), "0", "fmt 0")
eq(Format.num(999), "999", "fmt 999")
eq(Format.num(1000), "1K", "fmt 1K")
eq(Format.num(1500), "1.5K", "fmt 1.5K")
eq(Format.num(1000000), "1M", "fmt 1M")
eq(Format.num(5000000000), "5B", "fmt 5B")
eq(Format.num(7.5e12), "7.5T", "fmt 7.5T")
eq(Format.num(2e15), "2Qa", "fmt 2Qa")

-- Levels
local lv, into, band = Rules.level(0)
eq(lv, 1, "level of 0")
eq(into, 0, "into of 0")
eq(band, 100, "band 1 = 100")
eq((Rules.level(100)), 2, "level of 100")
eq((Rules.level(330)), 3, "level of 330 (past 100+220)")
ok((Rules.level(1e7)) >= 15, "level of 10M >= 15")

-- Stages
eq(#Config.STAGES, 15, "15 stages")
eq(Config.STAGES[1].req, 1, "s1 req")
eq(Config.STAGES[1].wins, 1, "s1 wins")
eq(Config.STAGES[15].req, 120, "s15 req")
eq(Config.STAGES[15].wins, 150000, "s15 wins")
local bosses, prevReq = 0, 0
for _, s in Config.STAGES do
	if s.boss then
		bosses += 1
	end
	ok(s.req > prevReq, "reqs increasing")
	prevReq = s.req
end
eq(bosses, 3, "3 boss stages")
eq(#Config.WORLD2_REQS, 12, "w2 reqs 12")
eq(Config.WORLD2_WINS[1], 250000, "w2 first wins")
eq(Config.WORLD2_WINS[12], 40000000, "w2 last wins")

-- Phones
eq(#Config.PHONES, 32, "32 phones")
eq(Config.PHONES[1].req, 15, "phone1 req")
eq(Config.PHONES[1].mult, 1.5, "phone1 mult")
eq(Config.PHONES[20].mult, 1e11, "phone20 mult")
eq(Config.PHONES[32].req, 1530, "phone32 req")
eq(Config.PHONES[32].mult, 1e23, "phone32 mult")

-- Chargers
eq(#Config.CHARGERS, 8, "8 chargers")
eq(Config.CHARGERS[1].rate, 2, "chg1 rate")
eq(Config.CHARGERS[1].cost, 0, "chg1 free")
eq(Config.CHARGERS[8].rate, 150000, "chg8 rate")
eq(Rules.chargerRate(Config.CHARGERS[1], 0), 2, "rate lv0")
ok(Rules.chargerRate(Config.CHARGERS[1], 8) > 1000, "rate grows with level")
eq(Rules.chargerUpgradeCost(Config.CHARGERS[2], 0), 250, "upg cost chg2 lv0")
eq(Rules.chargerUpgradeCost(Config.CHARGERS[1], 0), 150, "upg cost free chg lv0")
eq(Rules.chargerUpgradeCost(Config.CHARGERS[1], 1), 900, "upg cost x6 per level")

-- Cases / signals
eq(#Config.CASES, 11, "11 cases")
eq(Config.CASES[11].mult, 5000000, "infinity x5M")
eq(Config.CASES[11].pass, "infinityCase", "infinity is pass")
eq(#Config.SIGNALS, 11, "11 signals")
eq(Config.SIGNALS[11].mult, 10, "darkness x10")
eq(Rules.bestMult({ 1 }, Config.CASES, nil), 1.5, "bestMult owned")
eq(Rules.bestMult({}, Config.CASES, function(k)
	return k == "infinityCase"
end), 5000000, "bestMult via pass")
eq(Rules.itemsMult({ 1, 2 }), 1.08, "items sum pct")
eq(Rules.phoneMult(0), 1, "phoneMult 0")
eq(Rules.phoneMult(1), 1.5, "phoneMult 1")
eq(Rules.gainStack(2, 3, 1.5, 1, 0, 2), 27, "gainStack product")

-- Run bonus
local pct, medal = Rules.runBonus(3, 0, Rules.parTime(1), 1)
eq(pct, 175, "bonus: 3 stars + flawless + gold")
eq(medal, "gold", "medal gold")
local pct2, medal2 = Rules.runBonus(0, 2, 9999, 1)
eq(pct2, 0, "bonus none")
eq(medal2, "", "medal none")
eq(Rules.parTime(1), 20, "par time s1")

-- Daily / spin / offline
local dc, dw = Rules.daily(3, 0)
eq(dc, 1500, "daily charge")
eq(dw, 75, "daily wins")
eq(Rules.spin(0.1, 0).kind, "charge", "spin charge bucket")
eq(Rules.spin(0.1, 0).amount, 2000, "spin charge amount")
eq(Rules.spin(0.99, 0).kind, "jackpot", "spin jackpot")
eq(Rules.offline(100, 100), 1440000, "offline capped at 8h")

-- Links / OS / codes
eq(#Config.LINKS, 17, "17 links")
eq(Config.LINKS[17].amount, 500000000, "top link +500M")
eq(Config.LINKS[17].cost, 7500000000000, "top link cost 7.5T")
eq(Config.OS_PHONES_NEEDED, 32, "OS needs 32 phones")
eq(Config.OS_WINS_COST, 200000000000000, "OS cost 200T")
eq(Config.CODES.LAUNCH.charge, 1000, "code LAUNCH")
eq(#Config.QUESTS, 3, "3 quests")

print(("rules: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
	process.exit(1)
end
