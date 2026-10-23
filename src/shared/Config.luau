-- Config.luau — كل أرقام لعبة «هروب الهاتف» (+1 Charge: Phone Escape).
-- الأرقام من بحث اللعبة الأصلية +1 Speed Keyboard Escape كما في وثيقة
-- التصميم المعتمدة. ملف نقي (بلا Roblox APIs) ليعمل في اختبارات Lune.
local Config = {}

Config.VERSION = "4.0" -- تظهر في اللعبة (لافتة البداية + زاوية الشاشة)

-- ===== الشاشة الرئيسية (أرضية اللوبي) =====
Config.GRID_COLS = 24
Config.GRID_ROWS = 18
Config.TILE = 5 -- حجم بلاطة الأيقونة
Config.GAP = 0.7
Config.STEP_COOLDOWN = 0.3
Config.GLYPHS = {
	"📷", "🎵", "💬", "▶️", "🗺️", "🛒", "⚙️", "📧", "🌐", "🎮",
	"📞", "📅", "☁️", "❤️", "⭐", "📝", "🧮", "⏰", "🔋", "📱",
}

-- ===== المستوى =====
-- المستوى من الشحن التراكمي: شريط المستوى L يكلف 100 × 2.2^(L-1).
Config.LEVEL_BASE = 100
Config.LEVEL_GROWTH = 2.2

-- ===== المراحل (العالم 1 — داخل التطبيقات) =====
-- plan = رموز عناصر المسار: run/gap/moving/movingy/vanish/convF/convB/
-- bounce/sweep/narrow/tower/split و mid = نقطة حفظ وسطية.
Config.STAGE_GAP_Z = 110 -- المسافة بين بوابات المراحل
Config.STAGES = {
	{ name = "أول لمسة", req = 1, wins = 1, plan = { "run:84" } },
	{ name = "وابل الإشعارات", req = 5, wins = 3, plan = { "run:24", "gap:6", "run:20", "gap:8", "run:26" } },
	{ name = "أشرطة التمرير", req = 10, wins = 10, plan = { "run:18", "bounce:20", "run:20", "gap:6", "run:20" } },
	{ name = "وضع الطيران", req = 16, wins = 20, plan = { "run:16", "moving:16", "run:14", "split:22", "run:16" } },
	{ name = "تنبيه البطارية 20% 👑", req = 24, wins = 60, boss = true, plan = { "run:12", "bounce:16", "split:22", "sweep:18", "run:16" } },
	{ name = "ألبوم الذكريات", req = 33, wins = 100, plan = { "run:16", "vanish:24", "run:14", "gap:8", "run:22" } },
	{ name = "صور مكدّسة", req = 43, wins = 150, plan = { "run:14", "convF:22", "run:12", "convB:20", "run:16" } },
	{ name = "الذاكرة ممتلئة", req = 54, wins = 300, plan = { "run:14", "tower:26", "run:12", "mid", "gap:8", "run:24" } },
	{ name = "نهر الصور", req = 62, wins = 500, plan = { "run:14", "sweep:20", "narrow:18", "sweep:18", "run:14" } },
	{ name = "حذف جماعي 👑", req = 70, wins = 1000, boss = true, plan = { "run:10", "vanish:22", "convB:18", "sweep:18", "split:16" } },
	{ name = "شريط التقدم", req = 78, wins = 2500, plan = { "run:12", "narrow:20", "gap:6", "narrow:20", "split:26" } },
	{ name = "مصغّرات الحمم", req = 85, wins = 10000, plan = { "run:12", "movingy:18", "tower:24", "moving:14", "run:16" } },
	{ name = "تخطي الإعلان", req = 95, wins = 25000, plan = { "run:10", "vanish:18", "mid", "sweep:16", "convB:16", "bounce:14", "run:10" } },
	{ name = "البث المباشر", req = 105, wins = 50000, plan = { "run:10", "tower:24", "vanish:18", "sweep:16", "gap:8", "run:8" } },
	{ name = "البطارية 1% 👑", req = 120, wins = 150000, boss = true, plan = { "run:8", "bounce:14", "moving:14", "vanish:16", "sweep:16", "split:16" } },
}
-- العالم 2 (التطبيقات الاجتماعية) — أرقامه جاهزة، يُبنى محتواه في التحديث 1
Config.WORLD2_REQS = { 140, 160, 180, 200, 220, 240, 260, 280, 300, 320, 340, 360 }
Config.WORLD2_WINS = { 250000, 400000, 600000, 1000000, 1500000, 2500000, 4000000, 6000000, 10000000, 15000000, 25000000, 40000000 }
Config.WORLD2_UNLOCK = 120

-- ألوان عوالم المراحل (تُدار على المراحل بالتناوب)
Config.THEMES = {
	{ floor = { 96, 110, 130 }, accent = { 70, 150, 255 } }, -- إعدادات
	{ floor = { 150, 110, 200 }, accent = { 255, 120, 210 } }, -- معرض
	{ floor = { 132, 122, 152 }, accent = { 255, 70, 70 } }, -- فيديو
	{ floor = { 110, 200, 150 }, accent = { 40, 190, 110 } }, -- محادثات
	{ floor = { 255, 170, 110 }, accent = { 255, 110, 160 } }, -- قصص
	{ floor = { 112, 132, 166 }, accent = { 90, 200, 245 } }, -- نظام
}

-- مكافآت الأداء: نجمة +25%، بلا سقوط +50%، ميداليات الوقت +50/+25/+10
Config.STAR_PCT = 25
Config.FLAWLESS_PCT = 50
Config.MEDALS = { gold = 50, silver = 25, bronze = 10 }

-- ===== البطارية (مراحل الزعماء) =====
Config.BATTERY_DRAIN = 1.1 -- % في الثانية
Config.BATTERY_CELL = 10 -- % من خلية على الطريق

-- ===== محطات الشحن =====
-- تُرقّى 8 مرات بالـWins: الترقية k تضيف rate × 2.5 × 5^(k-1)،
-- وكلفتها = سعر المحطة × 6^المستوى (أو 150 للمجانية).
Config.CHARGER_MAX_LV = 8
Config.CHARGERS = {
	{ name = "منفذ USB", rate = 2, cost = 0 },
	{ name = "شاحن سريع", rate = 10, cost = 250 },
	{ name = "شاحن حائط", rate = 50, cost = 2500 },
	{ name = "قاعدة لاسلكية", rate = 250, cost = 25000 },
	{ name = "شاحن GaN", rate = 1250, cost = 250000 },
	{ name = "محطة شحن سيارة", rate = 6000, cost = 2500000 },
	{ name = "برج شحن", rate = 30000, cost = 25000000 },
	{ name = "مولّد الطوارئ", rate = 150000, cost = 250000000 },
}
-- كوابل Robux: تُضاعف إنتاج المحطات فقط
Config.CABLES = {
	{ name = "كابل ذهبي", mult = 3, pass = "cableGold" },
	{ name = "كابل ماسي", mult = 9, pass = "cableDiamond" },
	{ name = "كابل الحلوى", mult = 25, pass = "cableCandy" },
	{ name = "كابل الأدمين", mult = 100, pass = "cableAdmin" },
}

-- ===== الأغطية المضيئة (Trails) =====
Config.CASES = {
	{ name = "غطاء أخضر", mult = 1.5, cost = 500, color = { 120, 255, 120 } },
	{ name = "غطاء أزرق", mult = 2, cost = 1500, color = { 80, 160, 255 } },
	{ name = "غطاء بنفسجي", mult = 3, cost = 5000, color = { 170, 90, 255 } },
	{ name = "غطاء أحمر", mult = 4, cost = 25000, color = { 255, 70, 70 } },
	{ name = "غطاء قوس قزح", mult = 5, cost = 100000, color = { 255, 140, 220 } },
	{ name = "غطاء المجرة", mult = 10, cost = 0, pass = "galaxyCase", color = { 130, 80, 255 } },
	{ name = "غطاء كوني", mult = 100, cost = 5000000, color = { 150, 80, 255 } },
	{ name = "غطاء الفراغ", mult = 1000, cost = 50000000, color = { 40, 40, 60 } },
	{ name = "غطاء سوبرنوفا", mult = 10000, cost = 500000000, color = { 255, 180, 60 } },
	{ name = "غطاء إلهي", mult = 100000, cost = 5000000000, color = { 255, 215, 0 } },
	{ name = "غطاء اللانهاية", mult = 5000000, cost = 0, pass = "infinityCase", color = { 120, 255, 255 } },
}

-- ===== هالات الإشارة (Auras) =====
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
	{ name = "إشارة الظلام", mult = 10, cost = 0, pass = "darknessSignal", color = { 25, 25, 35 } },
}

-- ===== الأدوات (+% تُجمع) =====
Config.ITEMS = {
	{ name = "واقي شاشة", pct = 3, cost = 3000 },
	{ name = "حامل هاتف", pct = 5, cost = 25000 },
	{ name = "عدسة كاميرا", pct = 10, cost = 250000 },
	{ name = "مبرد الهاتف", pct = 15, cost = 3500000 },
	{ name = "شريحة ذهبية", pct = 25, cost = 40000000 },
	{ name = "بطارية نووية", pct = 50, cost = 400000000 },
	{ name = "غطاء الملك الذهبي (سري)", pct = 100, cost = 1000000000 },
}

-- ===== وصلات الشحن السريع (+شحن لكل خطوة) =====
Config.LINKS = {
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

-- ===== ترقية الهاتف (Rebirth) =====
-- 1-20 موثقة من الأصلية؛ 21-32 امتداد بنفس النمط (سقف الأصلية 32).
Config.PHONES = {
	{ name = "هاتف الطوب", req = 15, mult = 1.5 },
	{ name = "هاتف الأزرار", req = 25, mult = 2 },
	{ name = "هاتف الشاشة الصغيرة", req = 40, mult = 2.5 },
	{ name = "أول هاتف ذكي", req = 60, mult = 3 },
	{ name = "هاتف البلاستيك", req = 75, mult = 3.5 },
	{ name = "هاتف الزجاج", req = 100, mult = 4 },
	{ name = "هاتف الكاميرا الواحدة", req = 125, mult = 5 },
	{ name = "هاتف الكاميرتين", req = 150, mult = 6 },
	{ name = "هاتف الشاشة الكاملة", req = 175, mult = 7.5 },
	{ name = "هاتف النتوء", req = 200, mult = 10 },
	{ name = "هاتف 5G", req = 225, mult = 100 },
	{ name = "هاتف الشاشة المنحنية", req = 260, mult = 1000 },
	{ name = "هاتف القلم", req = 300, mult = 10000 },
	{ name = "هاتف قابل للطي", req = 340, mult = 100000 },
	{ name = "هاتف الشفافية", req = 380, mult = 1000000 },
	{ name = "هاتف الكاميرا الخفية", req = 420, mult = 10000000 },
	{ name = "هاتف الذكاء الاصطناعي", req = 465, mult = 100000000 },
	{ name = "هاتف الهولوغرام", req = 510, mult = 1000000000 },
	{ name = "هاتف المستقبل", req = 560, mult = 10000000000 },
	{ name = "الهاتف الكمّي", req = 600, mult = 100000000000 },
	{ name = "هاتف الواقع المعزز", req = 650, mult = 1e12 },
	{ name = "هاتف العين الذكية", req = 705, mult = 1e13 },
	{ name = "هاتف الصوت النقي", req = 765, mult = 1e14 },
	{ name = "هاتف الليزر", req = 830, mult = 1e15 },
	{ name = "هاتف البلازما", req = 900, mult = 1e16 },
	{ name = "هاتف الجرافين", req = 975, mult = 1e17 },
	{ name = "هاتف النانو", req = 1055, mult = 1e18 },
	{ name = "هاتف الزمن", req = 1140, mult = 1e19 },
	{ name = "هاتف الأبعاد", req = 1230, mult = 1e20 },
	{ name = "هاتف الوعي", req = 1325, mult = 1e21 },
	{ name = "هاتف الأبدية", req = 1425, mult = 1e22 },
	{ name = "هاتف الخلق", req = 1530, mult = 1e23 },
}

-- ===== تحديث النظام (Ascend) =====
Config.OS_PHONES_NEEDED = 32
Config.OS_WINS_COST = 200000000000000
Config.OS_MULT = 8

-- ===== أنظمة يومية =====
Config.GIFT_EVERY = 300 -- هدية مجانية كل 5 دقائق
Config.SPIN_EVERY = 43200 -- عجلة كل 12 ساعة
Config.OFFLINE_CAP_H = 8
Config.OFFLINE_EFF = 0.5
Config.OFFLINE_MIN_MIN = 10
Config.QUESTS = {
	{ id = "icons", text = "اخطُ على 500 أيقونة", target = 500, wins = 100, charge = 0 },
	{ id = "stages", text = "اخلص مرحلتين", target = 2, wins = 250, charge = 0 },
	{ id = "charge", text = "اشحن 3 دقائق على المحطات", target = 180, wins = 0, charge = 5000 },
}
Config.CODES = {
	LAUNCH = { charge = 1000, wins = 0 },
	PHONE = { charge = 0, wins = 50 },
	BATTERY = { charge = 100000, wins = 0 },
}

-- ===== الربح (IDs = 0 حتى تُنشأ في Creator Hub) =====
Config.PASSES = {
	doubleCharge = 0, -- x2 كسب (مقترح 99 R$)
	doubleWins = 0, -- x2 Wins (مقترح 95 R$)
	vip = 0, -- x3 كسب + كابل ذهبي (مقترح 399 R$)
	galaxyCase = 0, -- غطاء x10 (موثق 389 R$)
	infinityCase = 0, -- غطاء x5,000,000 (موثق 1,799 R$)
	darknessSignal = 0, -- إشارة x10 (موثق 739 R$)
	cableGold = 0, -- محطات x3 (موثق 79 R$)
	cableDiamond = 0, -- محطات x9 (موثق 345 R$)
	cableCandy = 0, -- محطات x25 (موثق 749 R$)
	cableAdmin = 0, -- محطات x100 (موثق 1,199 R$)
}
Config.PRODUCTS = {
	skipStage = 0, -- مقترح 49 R$
	charge150K = 0, -- +150K شحن (مقترح 99 R$)
	charge1M = 0, -- +1M شحن (مقترح 399 R$)
	charge10M = 0, -- +10M شحن (مقترح 1,499 R$)
}
Config.PACK_AMOUNTS = { charge150K = 150000, charge1M = 1000000, charge10M = 10000000 }

return Config
