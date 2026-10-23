-- Config for +1 Charge: Phone Escape (📱 هروب الهاتف).
-- The engine numbers are the researched +1 Speed Keyboard Escape economy
-- (level gates, Wins tables, multiplier ladders, Rebirth, Ascend) renamed
-- into a new world: a tiny avatar trapped inside a giant smartphone.
-- Pure Luau (no Roblox APIs) so lune tests can load it.
local Config = {}

-- ============ THE HOME SCREEN (lobby floor) ============
-- The whole lobby floor is a giant phone home screen: every app icon
-- stepped on = +1 Charge. Grid geometry mirrors the proven keyboard lobby.
Config.APP_COLS = 24
Config.APP_ROWS = 18
Config.APP_SIZE = 5
Config.APP_GAP = 0.7
Config.APP_COOLDOWN = 0.3
Config.APP_GLYPHS = {
	"📷", "🎵", "💬", "▶️", "🗺️", "🛒", "⚙️", "📧", "🌐", "🎮",
	"📞", "📅", "☁️", "❤️", "⭐", "📝", "🧮", "⏰", "🔋", "📱",
}

-- ============ LEVELS ============
-- Level is earned from LIFETIME charge (reset by phone upgrade / OS update).
-- Band for level L costs 100 * 2.2^(L-1) lifetime charge.
Config.LEVEL_BASE = 100
Config.LEVEL_GROWTH = 2.2

-- ============ STAGES — LEVEL GATES (researched anchors) ============
-- World 1: 15 stages. Ladder anchored to documented points (Stage 10 ~
-- Level 70, Stage 15 = Level 120). World 2 unlocks at Level 120; its
-- stages recommend 140, then +20 per stage (documented).
Config.STAGE_SPACING = 110
Config.STAGE_LEVEL_REQS = {
	1, 5, 10, 16, 24, 33, 43, 54, 62, 70, 78, 85, 95, 105, 120,
}
Config.STAGE_WINS = {
	1, 3, 10, 20, 60, 100, 150, 300, 500, 1000, 2500, 10000, 25000, 50000, 150000,
}
Config.STAGE_COUNT = #Config.STAGE_LEVEL_REQS
Config.STAGE_LEVEL_REQS_W2 = {
	140, 160, 180, 200, 220, 240, 260, 280, 300, 320, 340, 360,
}
Config.STAGE_WINS_W2 = {
	250000, 400000, 600000, 1000000, 1500000, 2500000, 4000000, 6000000, 10000000, 15000000, 25000000, 40000000,
}
Config.WORLD_STAGE_COUNT = { #Config.STAGE_LEVEL_REQS, #Config.STAGE_LEVEL_REQS_W2 }
Config.STAGE_THEMES = {
	{ name = "Settings", floor = { 96, 110, 130 }, accent = { 70, 150, 255 } },
	{ name = "Gallery", floor = { 150, 110, 200 }, accent = { 255, 120, 210 } },
	{ name = "Video", floor = { 60, 55, 70 }, accent = { 255, 70, 70 } },
	{ name = "Chat", floor = { 110, 200, 150 }, accent = { 40, 190, 110 } },
	{ name = "Stories", floor = { 255, 170, 110 }, accent = { 255, 110, 160 } },
	{ name = "System", floor = { 35, 40, 60 }, accent = { 90, 230, 255 } },
}

-- ============ FAST-CHARGE LINKS (+Charge per step, bought with Wins) ============
-- Researched ladder: +1 free, +2/3, +3/15, +25/100, +50/500, +100/2.5K,
-- +250/15K, +500/50K ... top +500M/step for 7.5T Wins (documented).
Config.STEP_PADS = {
	{ amount = 1, cost = 0 },
	{ amount = 2, cost = 3 },
	{ amount = 3, cost = 15 },
	{ amount = 25, cost = 100 },
	{ amount = 50, cost = 500 },
	{ amount = 100, cost = 2500 },
	{ amount = 250, cost = 15000 },
	{ amount = 500, cost = 50000 },
	{ amount = 5000, cost = 2500000 },
	{ amount = 50000, cost = 100000000 },
	{ amount = 500000, cost = 50000000000 },
	{ amount = 5000000, cost = 250000000000 },
	{ amount = 25000000, cost = 450000000000 },
	{ amount = 50000000, cost = 800000000000 },
	{ amount = 100000000, cost = 1500000000000 },
	{ amount = 250000000, cost = 3000000000000 },
	{ amount = 500000000, cost = 7500000000000 },
}

-- ============ STAGE PLANS — courses inside the apps ============
-- Element tokens: run/gap/moving/movingy/vanish/convF/convB/bounce/sweep/
-- narrow/tower/split, each "name:length", plus "mid" = mid checkpoint.
-- Teach -> test -> combine; a boss (👑) every 5 stages mixes everything
-- and runs on the draining-battery mechanic.
Config.STAGE_PLANS = {
	{ name = "أول لمسة", elements = { "run:84" } },
	{ name = "وابل الإشعارات", elements = { "run:24", "gap:6", "run:20", "gap:8", "run:26" } },
	{ name = "أشرطة التمرير", elements = { "run:18", "bounce:20", "run:20", "gap:6", "run:20" } },
	{ name = "وضع الطيران", elements = { "run:16", "moving:16", "run:14", "split:22", "run:16" } },
	{ name = "تنبيه البطارية 20% 👑", boss = true, elements = { "run:12", "bounce:16", "split:22", "sweep:18", "run:16" } },
	{ name = "ألبوم الذكريات", elements = { "run:16", "vanish:24", "run:14", "gap:8", "run:22" } },
	{ name = "صور مكدّسة", elements = { "run:14", "convF:22", "run:12", "convB:20", "run:16" } },
	{ name = "الذاكرة ممتلئة", elements = { "run:14", "tower:26", "run:12", "mid", "gap:8", "run:24" } },
	{ name = "نهر الصور", elements = { "run:14", "sweep:20", "narrow:18", "sweep:18", "run:14" } },
	{ name = "حذف جماعي 👑", boss = true, elements = { "run:10", "vanish:22", "convB:18", "sweep:18", "split:16" } },
	{ name = "شريط التقدم", elements = { "run:12", "narrow:20", "gap:6", "narrow:20", "split:26" } },
	{ name = "مصغّرات الحمم", elements = { "run:12", "movingy:18", "tower:24", "moving:14", "run:16" } },
	{ name = "تخطي الإعلان", elements = { "run:10", "vanish:18", "mid", "sweep:16", "convB:16", "bounce:14", "run:10" } },
	{ name = "البث المباشر", elements = { "run:10", "tower:24", "vanish:18", "sweep:16", "gap:8", "run:8" } },
	{ name = "البطارية 1% 👑", boss = true, elements = { "run:8", "bounce:14", "moving:14", "vanish:16", "sweep:16", "split:16" } },
}
-- Run bonuses: each star +25% of the stage reward, a no-fall run +50%,
-- timer medals (gold/silver/bronze) +50%/+25%/+10%.
Config.STAR_BONUS_PCT = 25
Config.NOFALL_BONUS_PCT = 50
Config.MEDAL_BONUS = { gold = 50, silver = 25, bronze = 10 }

-- ============ BATTERY (the new signature mechanic) ============
-- Boss stages run on a draining battery: it starts at 100%, drains
-- BATTERY_DRAIN_PCT per second, battery pickups on the course give
-- +BATTERY_PICKUP_PCT. At 0% the run fails back to the last checkpoint.
Config.BATTERY_DRAIN_PCT = 1.1
Config.BATTERY_PICKUP_PCT = 10

-- ============ CHARGING STATIONS (training) ============
-- Standing on a station grants charge per second = rate x your full gain
-- stack. Bought with Wins; each station upgrades 8 times, paid in Wins
-- only: upgrade k adds rate x 2.5 x 5^(k-1); cost = price x 6^level.
Config.CHARGER_MAX_LEVEL = 8
Config.CHARGERS = {
	{ name = "منفذ USB", rate = 2, mult = 1, cost = 0 },
	{ name = "شاحن سريع", rate = 10, mult = 1, cost = 250 },
	{ name = "شاحن حائط", rate = 50, mult = 1, cost = 2500 },
	{ name = "قاعدة لاسلكية", rate = 250, mult = 1, cost = 25000 },
	{ name = "شاحن GaN", rate = 1250, mult = 1, cost = 250000 },
	{ name = "محطة شحن سيارة", rate = 6000, mult = 1, cost = 2500000 },
	{ name = "برج شحن", rate = 30000, mult = 1, cost = 25000000 },
	{ name = "مولّد الطوارئ", rate = 150000, mult = 1, cost = 250000000 },
}
-- Robux cables (from the original's charger passes): multiply STATION
-- output while you stand on any station. Gold x3 (79 R$), Diamond x9
-- (345 R$), Candy x25 (749 R$), Admin x100 (1,199 R$) — Sep 2026 prices.
Config.CABLES = {
	{ name = "كابل ذهبي", mult = 3, pass = "CableGold" },
	{ name = "كابل ماسي", mult = 9, pass = "CableDiamond" },
	{ name = "كابل الحلوى", mult = 25, pass = "CableCandy" },
	{ name = "كابل الأدمين", mult = 100, pass = "CableAdmin" },
}

-- ============ GLOWING CASES (Trails — researched ladder) ============
Config.CASES = {
	{ name = "غطاء أخضر", mult = 1.5, cost = 500, color = { 120, 255, 120 } },
	{ name = "غطاء أزرق", mult = 2, cost = 1500, color = { 80, 160, 255 } },
	{ name = "غطاء بنفسجي", mult = 3, cost = 5000, color = { 170, 90, 255 } },
	{ name = "غطاء أحمر", mult = 4, cost = 25000, color = { 255, 70, 70 } },
	{ name = "غطاء قوس قزح", mult = 5, cost = 100000, color = { 255, 140, 220 } },
	{ name = "غطاء المجرة", mult = 10, cost = 0, pass = "GalaxyCase", color = { 130, 80, 255 } },
	{ name = "غطاء كوني", mult = 100, cost = 5000000, color = { 150, 80, 255 } },
	{ name = "غطاء الفراغ", mult = 1000, cost = 50000000, color = { 40, 40, 60 } },
	{ name = "غطاء سوبرنوفا", mult = 10000, cost = 500000000, color = { 255, 180, 60 } },
	{ name = "غطاء إلهي", mult = 100000, cost = 5000000000, color = { 255, 215, 0 } },
	{ name = "غطاء اللانهاية", mult = 5000000, cost = 0, pass = "InfinityCase", color = { 120, 255, 255 } },
}
Config.INFINITY_CASE = { name = "غطاء اللانهاية", mult = 5000000, color = { 120, 255, 255 } }

-- ============ SIGNAL SIGNALS (researched ladder) ============
Config.SIGNALS = {
	{ name = "توهج الإشارة", mult = 1.2, cost = 1000000, color = { 255, 255, 180 } },
	{ name = "إشارة الرياح", mult = 1.5, cost = 5000000, color = { 200, 255, 220 } },
	{ name = "إشارة الماء", mult = 2, cost = 10000000, color = { 90, 180, 255 } },
	{ name = "ميدالية الشحن", mult = 2, cost = 0, color = { 255, 200, 80 } },
	{ name = "إشارة النار", mult = 3, cost = 25000000, color = { 255, 130, 60 } },
	{ name = "إشارة كهربائية", mult = 4, cost = 50000000, color = { 255, 240, 120 } },
	{ name = "إشارة الحلوى", mult = 5, cost = 100000000, color = { 255, 130, 200 } },
	{ name = "إشارة الشوكولاتة", mult = 6, cost = 250000000, color = { 140, 85, 50 } },
	{ name = "إشارة العاصفة", mult = 7, cost = 500000000, color = { 150, 150, 255 } },
	{ name = "إشارة الأبجدية", mult = 8.5, cost = 1000000000, color = { 255, 255, 255 } },
	{ name = "إشارة الظلام", mult = 10, cost = 0, pass = "DarknessSignal", color = { 25, 25, 35 } },
}

-- ============ ITEMS (+% each — they SUM, researched) ============
Config.ITEMS = {
	{ name = "واقي شاشة", pct = 3, cost = 3000, color = { 240, 160, 90 } },
	{ name = "حامل هاتف", pct = 5, cost = 25000, color = { 255, 120, 200 } },
	{ name = "عدسة كاميرا", pct = 10, cost = 250000, color = { 120, 75, 45 } },
	{ name = "مبرد الهاتف", pct = 15, cost = 3500000, color = { 255, 200, 230 } },
	{ name = "شريحة ذهبية", pct = 25, cost = 40000000, color = { 255, 205, 40 } },
	{ name = "بطارية نووية", pct = 50, cost = 400000000, color = { 90, 90, 200 } },
	{ name = "غطاء الملك الذهبي (سري)", pct = 100, cost = 1000000000, color = { 255, 215, 0 } },
}

-- ============ PHONE UPGRADES (Rebirth — researched ladder, extended) ============
-- Upgrade n needs Level REBIRTH_LEVELS[n] and sets your gain multiplier
-- to REBIRTH_MULTS[n]. Resets Charge AND Level; keeps Wins and gear.
-- Rungs 1-20 are documented; 21-32 extend the same pattern (the original
-- raised its cap to 32 without publishing those rungs).
Config.PHONE_MODELS = {
	"هاتف الطوب", "هاتف الأزرار", "هاتف الشاشة الصغيرة", "أول هاتف ذكي",
	"هاتف البلاستيك", "هاتف الزجاج", "هاتف الكاميرا الواحدة", "هاتف الكاميرتين",
	"هاتف الشاشة الكاملة", "هاتف النتوء", "هاتف 5G", "هاتف الشاشة المنحنية",
	"هاتف القلم", "هاتف قابل للطي", "هاتف الشفافية", "هاتف الكاميرا الخفية",
	"هاتف الذكاء الاصطناعي", "هاتف الهولوغرام", "هاتف المستقبل", "الهاتف الكمّي",
	"هاتف الواقع المعزز", "هاتف العين الذكية", "هاتف الصوت النقي", "هاتف الليزر",
	"هاتف البلازما", "هاتف الجرافين", "هاتف النانو", "هاتف الزمن",
	"هاتف الأبعاد", "هاتف الوعي", "هاتف الأبدية", "هاتف الخلق",
}
Config.REBIRTH_LEVELS = {
	15, 25, 40, 60, 75, 100, 125, 150, 175, 200,
	225, 260, 300, 340, 380, 420, 465, 510, 560, 600,
	650, 705, 765, 830, 900, 975, 1055, 1140, 1230, 1325, 1425, 1530,
}
Config.REBIRTH_MULTS = {
	1.5, 2, 2.5, 3, 3.5, 4, 5, 6, 7.5, 10,
	100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000, 10000000000, 100000000000,
	1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21, 1e22, 1e23,
}
-- OS Update (Ascend, documented shape): 32 phone upgrades + 200T Wins
-- -> permanent x8 gains per tier (tier 2 = x16). Resets Charge, Level
-- and phone upgrades; the Wins cost is paid.
Config.ASCEND_REBIRTHS_NEEDED = 32
Config.ASCEND_WINS_COST = 200000000000000
Config.ASCEND_MULT = 8

-- ============ CODES & FREE GIFT ============
Config.CODES = {
	LAUNCH = { speed = 1000, wins = 0 },
	PHONE = { speed = 0, wins = 50 },
	BATTERY = { speed = 100000, wins = 0 },
}
Config.GIFT_COOLDOWN = 300 -- seconds
-- Gift charge = 1000 * 10^floor(MaxStage/5), gift wins = 25 * (MaxStage+1)

-- ============ WORLD 2 (data ready — world ships in Update 1) ============
Config.WORLD2_UNLOCK_LEVEL = 120
Config.WORLD2_Z = 3080
Config.WORLD2_LOBBY_Z = 3120

-- ============ SPIN WHEEL + BOOSTS ============
Config.SPIN_COOLDOWN = 43200 -- 12 hours, free
Config.SEASONAL = false -- seasonal decor arrives with events

-- ============ FREE PROGRESSION ============
-- Daily login reward: charge = 500 x streak x 10^floor(MaxStage/5),
-- wins = 25 x streak x (MaxStage+1). Offline earnings: 50% of your best
-- station's output while away, capped at 8 hours.
Config.OFFLINE_CAP_HOURS = 8
Config.OFFLINE_EFFICIENCY = 0.5
Config.OFFLINE_MIN_MINUTES = 10
Config.QUESTS = {
	{ id = "keys", text = "اخطُ على 500 أيقونة", target = 500, wins = 100, speed = 0 },
	{ id = "stages", text = "اخلص مرحلتين", target = 2, wins = 250, speed = 0 },
	{ id = "train", text = "اشحن 3 دقائق على المحطات", target = 180, wins = 0, speed = 5000 },
}

-- ============ MONETIZATION (IDs = 0 until created in Creator Hub) ============
Config.PASSES = {
	DoubleCharge = 0, -- x2 gains (suggested 99 R$)
	DoubleWins = 0, -- x2 Wins (suggested 95 R$)
	VIP = 0, -- x3 gains + gold cable (suggested 399 R$)
	InfinityCase = 0, -- x5,000,000 case (researched 1,799 R$)
	GalaxyCase = 0, -- x10 case (researched 389 R$)
	DarknessSignal = 0, -- x10 signal (researched 739 R$)
	CableGold = 0, -- station output x3 (researched 79 R$)
	CableDiamond = 0, -- station output x9 (researched 345 R$)
	CableCandy = 0, -- station output x25 (researched 749 R$)
	CableAdmin = 0, -- station output x100 (researched 1,199 R$)
}
Config.PRODUCTS = {
	SkipStage = 0,
	Charge150K = 0, -- +150,000 Charge
	Charge1M = 0, -- +1,000,000 Charge
	Charge10M = 0, -- +10,000,000 Charge
}
Config.PRODUCT_AMOUNTS = { Charge150K = 150000, Charge1M = 1000000, Charge10M = 10000000 }

return Config
