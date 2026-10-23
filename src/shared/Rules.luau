-- Rules.luau — رياضيات اللعبة النقية (تعمل في السيرفر والعميل والاختبارات).
local Config = require(script.Parent.Config)

local Rules = {}

-- المستوى من الشحن التراكمي: يعيد (المستوى، التقدم داخل الشريط، حجم الشريط)
function Rules.level(lifetime: number): (number, number, number)
	local level = 1
	local rest = lifetime
	while true do
		local band = Config.LEVEL_BASE * (Config.LEVEL_GROWTH ^ (level - 1))
		if rest < band then
			return level, rest, band
		end
		rest -= band
		level += 1
		if level > 9000 then
			return level, rest, band
		end
	end
end

function Rules.stage(i: number): any
	return Config.STAGES[i]
end

-- أفضل مضاعف مملوك من سلم (مع عناصر الباسات: تُمرَّر دالة يملك(مفتاح))
function Rules.bestMult(owned: { number }, ladder: { any }, ownsPass: ((string) -> boolean)?): number
	local best = 1
	for _, idx in owned do
		local item = ladder[idx]
		if item and item.mult > best then
			best = item.mult
		end
	end
	if ownsPass then
		for _, item in ladder do
			if item.pass and ownsPass(item.pass) and item.mult > best then
				best = item.mult
			end
		end
	end
	return best
end

-- الأدوات: النسب تُجمع
function Rules.itemsMult(ownedItems: { number }): number
	local pct = 0
	for _, idx in ownedItems do
		local item = Config.ITEMS[idx]
		if item then
			pct += item.pct
		end
	end
	return 1 + pct / 100
end

-- مضاعف الترقية الحالية (0 ترقية = x1)
function Rules.phoneMult(phones: number): number
	if phones <= 0 then
		return 1
	end
	local phone = Config.PHONES[phones]
	return phone and phone.mult or Config.PHONES[#Config.PHONES].mult
end

-- كومة الكسب الكاملة
function Rules.gainStack(caseMult: number, signalMult: number, itemsMult: number, phones: number, ascends: number, passMult: number): number
	return caseMult * signalMult * itemsMult * Rules.phoneMult(phones) * (Config.OS_MULT ^ ascends) * passMult
end

-- معدل محطة عند مستوى ترقية معين: الترقية تضاعف النمو أُسيًا
function Rules.chargerRate(chg: any, lv: number): number
	return chg.rate * (1 + 0.625 * ((5 ^ lv) - 1))
end

function Rules.chargerUpgradeCost(chg: any, lv: number): number
	local base = (chg.cost and chg.cost > 0) and chg.cost or 150
	return base * (6 ^ lv)
end

-- زمن الهدف (ميدالية ذهبية) لمرحلة
function Rules.parTime(stageIndex: number): number
	return 18 + stageIndex * 2
end

-- بونص الجولة: نسبة إضافية + اسم الميدالية ("" إن لا شيء)
function Rules.runBonus(stars: number, falls: number, elapsed: number, stageIndex: number): (number, string)
	local pct = stars * Config.STAR_PCT
	if falls == 0 then
		pct += Config.FLAWLESS_PCT
	end
	local par = Rules.parTime(stageIndex)
	local medal = ""
	if elapsed <= par then
		medal = "gold"
		pct += Config.MEDALS.gold
	elseif elapsed <= par * 1.6 then
		medal = "silver"
		pct += Config.MEDALS.silver
	elseif elapsed <= par * 2.5 then
		medal = "bronze"
		pct += Config.MEDALS.bronze
	end
	return pct, medal
end

-- عجلة الحظ: roll في [0,1)
function Rules.spin(roll: number, stage: number): { kind: string, amount: number, mult: number, minutes: number }
	local tier = 10 ^ math.floor(stage / 5)
	if roll < 0.34 then
		return { kind = "charge", amount = 2000 * tier, mult = 1, minutes = 0 }
	elseif roll < 0.58 then
		return { kind = "wins", amount = 150 * (stage + 1), mult = 1, minutes = 0 }
	elseif roll < 0.78 then
		return { kind = "boost", amount = 0, mult = 2, minutes = 15 }
	elseif roll < 0.93 then
		return { kind = "boost", amount = 0, mult = 3, minutes = 10 }
	end
	return { kind = "jackpot", amount = 100000 * tier, mult = 1, minutes = 0 }
end

-- مكافأة الدخول اليومية: (شحن، Wins)
function Rules.daily(streak: number, stage: number): (number, number)
	local tier = 10 ^ math.floor(stage / 5)
	return 500 * streak * tier, 25 * streak * (stage + 1)
end

-- أرباح الغياب: 50% من أفضل محطة، سقف 8 ساعات
function Rules.offline(hoursAway: number, bestPerSecond: number): number
	local h = math.min(math.max(hoursAway, 0), Config.OFFLINE_CAP_H)
	return math.floor(h * 3600 * bestPerSecond * Config.OFFLINE_EFF)
end

return Rules
