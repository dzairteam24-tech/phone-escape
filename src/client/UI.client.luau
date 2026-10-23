-- UI.client.luau — واجهة اللاعب: HUD + لوحات المتاجر والمهام والتنقل.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local R = ReplicatedStorage:WaitForChild("PhoneRemotes")

local gui = Instance.new("ScreenGui")
gui.Name = "PhoneUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function el(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function round(o, r)
	el("UICorner", { CornerRadius = UDim.new(0, r or 10) }, o)
end

-- ===== شريط Wins + أزرار اليسار =====
local winsChip = el("TextLabel", {
	Size = UDim2.new(0, 170, 0, 44), Position = UDim2.new(0, 10, 0, 10),
	BackgroundColor3 = Color3.fromRGB(25, 25, 35), BackgroundTransparency = 0.15,
	Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = Color3.fromRGB(120, 255, 140), Text = "🏆 0",
}, gui)
round(winsChip, 12)

local function sideBtn(txt, color, order)
	local col = (order - 1) % 2
	local row = math.floor((order - 1) / 2)
	local b = el("TextButton", {
		Size = UDim2.new(0, 118, 0, 60), Position = UDim2.new(0, 10 + col * 126, 0, 66 + row * 68),
		BackgroundColor3 = color, Font = Enum.Font.FredokaOne, TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1), Text = txt, BorderSizePixel = 0,
	}, gui)
	round(b, 12)
	return b
end
local upgradeBtn = sideBtn("📱\nUpgrade", Color3.fromRGB(90, 160, 255), 1)
local giftBtn = sideBtn("🎁\nFREE!", Color3.fromRGB(255, 120, 170), 2)
local tpBtn = sideBtn("🌀\nTeleport", Color3.fromRGB(150, 90, 220), 3)
local caseBtn = sideBtn("📦\nCases", Color3.fromRGB(200, 90, 200), 4)
local signalBtn = sideBtn("📶\nSignal", Color3.fromRGB(70, 130, 230), 5)
local itemBtn = sideBtn("🎒\nItems", Color3.fromRGB(230, 150, 60), 6)
local chargerBtn = sideBtn("🔌\nChargers", Color3.fromRGB(60, 170, 90), 7)
local codeBtn = sideBtn("🔑\nCode", Color3.fromRGB(90, 90, 110), 8)
local osBtn = sideBtn("🔄\nOS Update", Color3.fromRGB(255, 190, 40), 9)
local questBtn = sideBtn("🎖️\nQuests", Color3.fromRGB(220, 170, 40), 10)
local spinBtn = sideBtn("🎡\nSpin", Color3.fromRGB(200, 80, 200), 11)
local linkBtn = sideBtn("🔗\nLinks", Color3.fromRGB(90, 170, 90), 12)

-- رقم النسخة (زاوية الشاشة — تشخيص الملف الصحيح)
el("TextLabel", {
	Size = UDim2.new(0, 70, 0, 22), Position = UDim2.new(1, -76, 1, -26),
	BackgroundTransparency = 0.4, BackgroundColor3 = Color3.fromRGB(20, 20, 30),
	Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = Color3.fromRGB(160, 255, 180),
	Text = "v" .. Config.VERSION, BorderSizePixel = 0,
}, gui)

-- ===== شريط الهدف + البطارية =====
local objective = el("TextLabel", {
	Size = UDim2.new(0, 460, 0, 26), Position = UDim2.new(0.5, -230, 0, 118),
	BackgroundColor3 = Color3.fromRGB(20, 20, 35), BackgroundTransparency = 0.35,
	Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = Color3.fromRGB(255, 230, 150), Text = "🎯 ...",
}, gui)
round(objective, 8)
local battFrame = el("Frame", {
	Size = UDim2.new(0, 330, 0, 30), Position = UDim2.new(0.5, -165, 0, 150),
	BackgroundColor3 = Color3.fromRGB(30, 30, 40), BorderSizePixel = 0, Visible = false,
}, gui)
round(battFrame, 8)
local battFill = el("Frame", {
	Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(90, 255, 120), BorderSizePixel = 0,
}, battFrame)
round(battFill, 8)
local battText = el("TextLabel", {
	Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne,
	TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "🔋 100%",
}, battFrame)

-- ===== الأسفل: الشحن والمستوى والمضاعفات =====
local bigCharge = el("TextLabel", {
	Size = UDim2.new(0, 460, 0, 62), Position = UDim2.new(0.5, -230, 1, -178),
	BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3, Text = "0 ⚡",
}, gui)
local levelChip = el("TextLabel", {
	Size = UDim2.new(0, 130, 0, 40), Position = UDim2.new(0.5, -330, 1, -112),
	BackgroundColor3 = Color3.fromRGB(90, 60, 160), Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1), Text = "Level 1", BorderSizePixel = 0,
}, gui)
round(levelChip, 10)
local barBg = el("Frame", {
	Size = UDim2.new(0, 330, 0, 40), Position = UDim2.new(0.5, -190, 1, -112),
	BackgroundColor3 = Color3.fromRGB(30, 30, 40), BorderSizePixel = 0,
}, gui)
round(barBg, 10)
local barFill = el("Frame", {
	Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(60, 220, 255), BorderSizePixel = 0,
}, barBg)
round(barFill, 10)
local barText = el("TextLabel", {
	Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne,
	TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "0 / 100",
}, barBg)
local multLine = el("TextLabel", {
	Size = UDim2.new(0, 700, 0, 30), Position = UDim2.new(0.5, -350, 1, -66),
	BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.fromRGB(200, 220, 255), TextStrokeTransparency = 0.5, Text = "",
}, gui)

local packRow = { { "charge150K", "+150K ⚡" }, { "charge1M", "+1M ⚡" }, { "charge10M", "+10M ⚡" } }
for i, row in packRow do
	local b = el("TextButton", {
		Size = UDim2.new(0, 168, 0, 42), Position = UDim2.new(0.5, -260 + (i - 1) * 178, 1, -34),
		BackgroundColor3 = i == 3 and Color3.fromRGB(255, 190, 40) or Color3.fromRGB(140, 95, 60),
		Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
		Text = row[2], BorderSizePixel = 0,
	}, gui)
	round(b, 10)
	b.MouseButton1Click:Connect(function()
		local pid = Config.PRODUCTS[row[1]]
		if pid and pid > 0 then
			MarketplaceService:PromptProductPurchase(player, pid)
		else
			showToast("This product is not set up yet")
		end
	end)
end

-- ===== اليمين: متجر + سقف الشحن =====
local shopBtn = el("TextButton", {
	Size = UDim2.new(0, 150, 0, 58), Position = UDim2.new(1, -160, 0, 10),
	BackgroundColor3 = Color3.fromRGB(255, 90, 160), Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1), Text = "🛒 Shop", BorderSizePixel = 0,
}, gui)
round(shopBtn, 12)
local capBox = el("TextBox", {
	Size = UDim2.new(0, 96, 0, 40), Position = UDim2.new(1, -160, 0, 78),
	BackgroundColor3 = Color3.fromRGB(240, 240, 245), Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.fromRGB(30, 30, 40), Text = "", PlaceholderText = "Max charge", BorderSizePixel = 0,
}, gui)
round(capBox, 8)
local capOk = el("TextButton", {
	Size = UDim2.new(0, 54, 0, 40), Position = UDim2.new(1, -58, 0, 78),
	BackgroundColor3 = Color3.fromRGB(60, 200, 90), Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1), Text = "OK", BorderSizePixel = 0,
}, gui)
round(capOk, 8)
local capLabel = el("TextLabel", {
	Size = UDim2.new(0, 150, 0, 24), Position = UDim2.new(1, -160, 0, 122),
	BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4, Text = "Max Charge: off",
}, gui)
capOk.MouseButton1Click:Connect(function()
	local cap = tonumber(capBox.Text) or 0
	R.SetCap:FireServer(cap)
	capLabel.Text = cap > 0 and ("Max Charge: " .. Format.num(cap)) or "Max Charge: off"
	showToast(cap > 0 and ("🚦 Max charge set to " .. Format.num(cap)) or "🚦 Charge cap removed")
end)

-- ===== التنبيهات + المؤثرات =====
local toast = el("TextLabel", {
	Size = UDim2.new(0, 680, 0, 46), Position = UDim2.new(0.5, -340, 0, 14),
	BackgroundColor3 = Color3.fromRGB(20, 20, 30), BackgroundTransparency = 0.25,
	Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "", Visible = false,
}, gui)
round(toast, 10)
local toastSeq = 0
function showToast(text)
	toastSeq += 1
	local mine = toastSeq
	toast.Text = text
	toast.Visible = true
	task.delay(2.8, function()
		if toastSeq == mine then
			toast.Visible = false
		end
	end)
end
R.Toast.OnClientEvent:Connect(showToast)

local soundOn, shakeOn, effectsOn = true, true, true
local pop = Instance.new("Sound")
pop.SoundId = "rbxassetid://6026984224"
pop.Volume = 0.3
pop.Parent = gui
local lastPopAt = 0

-- ===== مؤثرات الخطوات: صوت كيبورد ممتع + أرقام طائرة =====
local clickPool = {}
for i = 1, 6 do
	local s = Instance.new("Sound")
	s.SoundId = Config.STEP_SOUNDS[(i - 1) % #Config.STEP_SOUNDS + 1]
	s.Volume = 0.45
	s.Parent = gui
	clickPool[i] = s
end
local clickIdx = 0
local function playStepClick()
	if not soundOn then
		return
	end
	clickIdx = clickIdx % #clickPool + 1
	local s = clickPool[clickIdx]
	s.SoundId = Config.STEP_SOUNDS[math.random(#Config.STEP_SOUNDS)]
	s.PlaybackSpeed = 0.95 + math.random() * 0.13
	s:Play()
end

local floatPool = {}
for i = 1, 20 do
	local bb = el("BillboardGui", {
		Size = UDim2.new(0, 120, 0, 46), StudsOffset = Vector3.new(0, 3, 0),
		AlwaysOnTop = true, Enabled = false,
	}, gui)
	local tl = el("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne, TextScaled = true,
		TextColor3 = Color3.fromRGB(130, 255, 110), TextStrokeTransparency = 0.2, Text = "+1",
	}, bb)
	floatPool[i] = { bb = bb, tl = tl, flying = false }
end
local floatIdx = 0
local function spawnStepNumber(amount)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	floatIdx = floatIdx % #floatPool + 1
	local f = floatPool[floatIdx]
	f.bb.Adornee = hrp
	f.bb.StudsOffset = Vector3.new(math.random(-12, 12) / 10, 3.2, 0)
	f.tl.Text = "+" .. Format.num(amount)
	f.tl.TextTransparency = 0
	f.bb.Enabled = true
	if f.flying then
		return -- أُعيد استخدامها أثناء طيرانها: تحديث الرقم يكفي
	end
	f.flying = true
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.8 do
			local k = (os.clock() - t0) / 0.8
			f.bb.StudsOffset = Vector3.new(f.bb.StudsOffset.X, 3.2 + k * 2.4, 0)
			f.tl.TextTransparency = k * k
			task.wait()
		end
		f.bb.Enabled = false
		f.flying = false
	end)
end

R.StepFX.OnClientEvent:Connect(function(amount)
	playStepClick()
	if effectsOn then
		spawnStepNumber(amount or 1)
	end
end)

-- كتم صوت الخطوات الافتراضي: يبقى صوت الكيبورد وحده
local function muteDefaultSteps(char)
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if not hrp then
		return
	end
	local function kill(s)
		if s:IsA("Sound") and s.Name == "Running" then
			s.Volume = 0
		end
	end
	for _, s in hrp:GetChildren() do
		kill(s)
	end
	hrp.ChildAdded:Connect(kill)
end
player.CharacterAdded:Connect(muteDefaultSteps)
if player.Character then
	task.spawn(muteDefaultSteps, player.Character)
end

R.StageCleared.OnClientEvent:Connect(function()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		local Debris = game:GetService("Debris")
		local cols = { Color3.fromRGB(255, 110, 180), Color3.fromRGB(110, 220, 255), Color3.fromRGB(170, 255, 110), Color3.fromRGB(255, 200, 80) }
		for i = 1, 26 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(0.35, 0.35, 0.35)
			p.Color = cols[(i % #cols) + 1]
			p.Material = Enum.Material.Neon
			p.CanCollide = false
			p.CFrame = root.CFrame + Vector3.new(0, 1, 0)
			p.AssemblyLinearVelocity = Vector3.new(math.random(-14, 14), math.random(14, 26), math.random(-14, 14))
			p.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
			p.Parent = workspace
			Debris:AddItem(p, 1.4)
		end
	end
	if shakeOn then
		local cam = workspace.CurrentCamera
		if cam then
			local orig = cam.CFrame
			for _ = 1, 3 do
				cam.CFrame = orig * CFrame.new(math.random(-2, 2) / 20, math.random(-2, 2) / 20, 0)
				task.wait(0.03)
			end
			cam.CFrame = orig
		end
	end
end)

-- ===== اللوحات =====
local panels = {}
local function makePanel(key, title)
	local f = el("Frame", {
		Size = UDim2.new(0, 440, 0, 400), Position = UDim2.new(0.5, -220, 0.5, -200),
		BackgroundColor3 = Color3.fromRGB(28, 28, 40), BorderSizePixel = 0, Visible = false,
	}, gui)
	round(f, 14)
	el("TextLabel", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = title }, f)
	local close = el("TextButton", {
		Size = UDim2.new(0, 38, 0, 38), Position = UDim2.new(1, -44, 0, 4),
		BackgroundColor3 = Color3.fromRGB(200, 60, 60), Font = Enum.Font.FredokaOne,
		TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "X", BorderSizePixel = 0,
	}, f)
	round(close, 8)
	close.MouseButton1Click:Connect(function()
		f.Visible = false
	end)
	local scroll = el("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -56), Position = UDim2.new(0, 8, 0, 50),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(0, 0, 0, 0),
	}, f)
	el("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	panels[key] = { frame = f, scroll = scroll }
	return panels[key]
end
local function row(scroll, text, color, onClick)
	local b = el("TextButton", {
		Size = UDim2.new(1, -8, 0, 50), BackgroundColor3 = color, Font = Enum.Font.FredokaOne,
		TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = text, BorderSizePixel = 0,
	}, scroll)
	round(b, 10)
	if onClick then
		b.MouseButton1Click:Connect(onClick)
	end
	return b
end
local OWNED = Color3.fromRGB(70, 130, 70)
local NORMAL = Color3.fromRGB(60, 60, 85)
local function rebuild(panel, fill)
	for _, c in panel.scroll:GetChildren() do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
	fill()
	local count = 0
	for _, c in panel.scroll:GetChildren() do
		if c:IsA("TextButton") then
			count += 1
		end
	end
	panel.scroll.CanvasSize = UDim2.new(0, 0, 0, count * 56 + 10)
end

local pCases = makePanel("cases", "📦 CASES")
local pSignals = makePanel("signals", "📶 SIGNAL")
local pItems = makePanel("items", "🎒 ITEMS (+% Charge)")
local pChargers = makePanel("chargers", "🔌 CHARGERS")
local pShop = makePanel("shop", "🛒 SHOP")
local pTp = makePanel("tp", "🌀 TELEPORT")
local pQuests = makePanel("quests", "🎖️ DAILY QUESTS")
local pLinks = makePanel("links", "🔗 FAST-CHARGE LINKS (+⚡ per step)")

local Rules = require(Shared.Rules)
local lastCap = 0
local state = {}
local function refresh()
	local ok, st = pcall(function()
		return R.GetState:InvokeServer()
	end)
	if not (ok and st and st.level) then
		return
	end
	state = st
	lastCap = st.cap or 0
	syncStats()
	levelChip.Text = "Level " .. st.level
	barText.Text = Format.num(st.levelInto) .. " / " .. Format.num(st.levelBand)
	barFill.Size = UDim2.new(math.clamp(st.levelInto / math.max(st.levelBand, 1), 0, 1), 0, 1, 0)
	multLine.Text = "Case & Signal x" .. Format.num(st.caseMult * st.signalMult)
		.. "   •   Items x" .. tostring(st.itemMult)
		.. "   •   Phone x" .. Format.num(Rules.phoneMult(st.phones))
		.. "   •   OS x" .. Format.num(st.osMult)
		.. "   •   TOTAL x" .. Format.num(st.stack)

	rebuild(pCases, function()
		for i, item in Config.CASES do
			local owned = (st.cases and table.find(st.cases, i)) or (item.pass and st.pass[item.pass])
			local price = item.pass and "👑 PASS (in 🛒 Shop)" or "🏆 " .. Format.num(item.cost)
			row(pCases.scroll, item.name .. " x" .. Format.num(item.mult) .. (owned and " ✅" or " — " .. price), owned and OWNED or NORMAL, function()
				local _, msg = R.BuyCase:InvokeServer(i)
				showToast(msg)
				refresh()
			end)
		end
	end)
	rebuild(pSignals, function()
		for i, item in Config.SIGNALS do
			local owned = (st.signals and table.find(st.signals, i)) or (item.pass and st.pass[item.pass])
			local price = item.pass and "👑 PASS (in 🛒 Shop)" or (item.cost == 0 and "FREE" or "🏆 " .. Format.num(item.cost))
			row(pSignals.scroll, item.name .. " x" .. Format.num(item.mult) .. (owned and " ✅" or " — " .. price), owned and OWNED or NORMAL, function()
				local _, msg = R.BuySignal:InvokeServer(i)
				showToast(msg)
				refresh()
			end)
		end
	end)
	rebuild(pItems, function()
		for i, item in Config.ITEMS do
			local owned = st.items and table.find(st.items, i)
			row(pItems.scroll, item.name .. " (+" .. item.pct .. "% Charge)" .. (owned and " ✅" or " — 🏆 " .. Format.num(item.cost)), owned and OWNED or NORMAL, function()
				local _, msg = R.BuyItem:InvokeServer(i)
				showToast(msg)
				refresh()
			end)
		end
	end)
	rebuild(pChargers, function()
		for i, chg in Config.CHARGERS do
			local owned = st.chargers and table.find(st.chargers, i)
			local lv = (st.chargerLv and st.chargerLv[i]) or 0
			local outNow = Rules.chargerRate(chg, lv)
			if not owned then
				local price = chg.cost == 0 and "FREE" or "🏆 " .. Format.num(chg.cost)
				row(pChargers.scroll, chg.name .. " (+" .. Format.num(outNow) .. "⚡/s) — " .. price, NORMAL, function()
					local _, msg = R.UnlockCharger:InvokeServer(i)
					showToast(msg)
					refresh()
				end)
			elseif lv >= Config.CHARGER_MAX_LV then
				row(pChargers.scroll, chg.name .. " Lv" .. lv .. " ⭐ MAX (+" .. Format.num(outNow) .. "⚡/s)", Color3.fromRGB(160, 130, 40))
			else
				local cost = Rules.chargerUpgradeCost(chg, lv)
				local outNext = Rules.chargerRate(chg, lv + 1)
				row(pChargers.scroll, "⬆️ " .. chg.name .. " Lv" .. lv .. " (+" .. Format.num(outNow) .. "⚡/s) → +" .. Format.num(outNext) .. " — 🏆 " .. Format.num(cost), NORMAL, function()
					local _, msg = R.UpgradeCharger:InvokeServer(i)
					showToast(msg)
					refresh()
				end)
			end
		end
	end)
	rebuild(pShop, function()
		local passRows = {
			{ "⚡ Double Charge (x2 gains)", Config.PASSES.doubleCharge },
			{ "🏆 Double Wins (x2)", Config.PASSES.doubleWins },
			{ "👑 VIP (x3 gains + Gold Cable)", Config.PASSES.vip },
			{ "♾️ INFINITY CASE (x" .. Format.num(Config.CASES[11].mult) .. ")", Config.PASSES.infinityCase },
			{ "🌌 GALAXY CASE (x10)", Config.PASSES.galaxyCase },
			{ "🌑 DARKNESS SIGNAL (x10)", Config.PASSES.darknessSignal },
			{ "🔌 GOLD CABLE (stations x3)", Config.PASSES.cableGold },
			{ "🔌 DIAMOND CABLE (stations x9)", Config.PASSES.cableDiamond },
			{ "🔌 CANDY CABLE (stations x25)", Config.PASSES.cableCandy },
			{ "🔌 ADMIN CABLE (stations x100)", Config.PASSES.cableAdmin },
		}
		for _, pr in passRows do
			row(pShop.scroll, pr[1], NORMAL, function()
				if pr[2] > 0 then
					MarketplaceService:PromptGamePassPurchase(player, pr[2])
				else
					showToast("This pass is not set up yet")
				end
			end)
		end
		row(pShop.scroll, "⏩ Skip Next Stage", Color3.fromRGB(180, 120, 30), function()
			if Config.PRODUCTS.skipStage > 0 then
				MarketplaceService:PromptProductPurchase(player, Config.PRODUCTS.skipStage)
			else
				showToast("Skip is not set up yet")
			end
		end)
		row(pShop.scroll, "🔊 Sound: " .. (soundOn and "ON" or "OFF"), Color3.fromRGB(90, 90, 110), function()
			soundOn = not soundOn
			refresh()
		end)
		row(pShop.scroll, "📷 Screen shake: " .. (shakeOn and "ON" or "OFF"), Color3.fromRGB(90, 90, 110), function()
			shakeOn = not shakeOn
			refresh()
		end)
		row(pShop.scroll, "👁 Others' effects: " .. (effectsOn and "ON" or "OFF"), Color3.fromRGB(90, 90, 110), function()
			effectsOn = not effectsOn
			applyEffects()
			refresh()
		end)
	end)
	rebuild(pQuests, function()
		local okQ, q = pcall(function()
			return R.GetQuests:InvokeServer()
		end)
		if okQ and q and q.quests then
			row(pQuests.scroll, "📅 Login streak: " .. (q.streak or 1) .. " day(s) — come back daily!", Color3.fromRGB(90, 90, 110))
			for _, quest in q.quests do
				local done = quest.progress >= quest.target
				local status = quest.claimed and " ✅ CLAIMED" or (done and " — TAP TO CLAIM!" or "")
				row(pQuests.scroll, quest.text .. " (" .. Format.num(math.min(quest.progress, quest.target)) .. "/" .. Format.num(quest.target) .. ")" .. status, quest.claimed and OWNED or NORMAL, function()
					local _, msg = R.ClaimQuest:InvokeServer(quest.id)
					showToast(msg)
					refresh()
				end)
			end
		end
	end)
	rebuild(pLinks, function()
		local cur = st.linkIdx or 1
		for i, link in Config.LINKS do
			if i < cur then
				row(pLinks.scroll, "+" .. Format.num(link.amount) .. " ⚡ / step ✅", Color3.fromRGB(70, 110, 70))
			elseif i == cur then
				row(pLinks.scroll, "▶ +" .. Format.num(link.amount) .. " ⚡ / step (ACTIVE)", Color3.fromRGB(40, 140, 70))
			elseif i == cur + 1 then
				row(pLinks.scroll, "⬆️ +" .. Format.num(link.amount) .. " ⚡ / step — 🏆 " .. Format.num(link.cost), NORMAL, function()
					local _, msg = R.BuyLink:InvokeServer()
					showToast(msg)
					refresh()
				end)
			else
				row(pLinks.scroll, "🔒 +" .. Format.num(link.amount) .. " ⚡ / step — 🏆 " .. Format.num(link.cost), Color3.fromRGB(45, 45, 60))
			end
		end
	end)
	rebuild(pTp, function()
		row(pTp.scroll, "🏠 Lobby", NORMAL, function()
			R.Teleport:FireServer("lobby")
			pTp.frame.Visible = false
		end)
		row(pTp.scroll, "🔒 World 2 — Social Apps (SOON)", Color3.fromRGB(70, 120, 190), function()
			R.Teleport:FireServer("world2")
			pTp.frame.Visible = false
		end)
		row(pTp.scroll, "🚀 My next Stage", NORMAL, function()
			R.Teleport:FireServer("stage")
			pTp.frame.Visible = false
		end)
	end)
end

function applyEffects()
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			local root = other.Character:FindFirstChild("HumanoidRootPart")
			local trail = root and root:FindFirstChild("GlowTrail")
			if trail then
				trail.Enabled = effectsOn
			end
		end
	end
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for _, part in workspace:GetChildren() do
		if part.Name == "SignalAura" and part:IsA("BasePart") then
			local mine = myRoot and (part.Position - myRoot.Position).Magnitude < 7
			if not mine then
				part.Transparency = effectsOn and 0.75 or 1
			end
		end
	end
end

local function toggle(panel)
	for _, p in panels do
		p.frame.Visible = (p == panel) and not panel.frame.Visible
	end
	if panel.frame.Visible then
		refresh()
	end
end
caseBtn.MouseButton1Click:Connect(function() toggle(pCases) end)
signalBtn.MouseButton1Click:Connect(function() toggle(pSignals) end)
itemBtn.MouseButton1Click:Connect(function() toggle(pItems) end)
chargerBtn.MouseButton1Click:Connect(function() toggle(pChargers) end)
shopBtn.MouseButton1Click:Connect(function() toggle(pShop) end)
tpBtn.MouseButton1Click:Connect(function() toggle(pTp) end)
questBtn.MouseButton1Click:Connect(function() toggle(pQuests) end)
linkBtn.MouseButton1Click:Connect(function() toggle(pLinks) end)
upgradeBtn.MouseButton1Click:Connect(function()
	local _, msg = R.UpgradePhone:InvokeServer()
	showToast(msg)
	refresh()
end)
osBtn.MouseButton1Click:Connect(function()
	local _, msg = R.OSUpdate:InvokeServer()
	showToast(msg)
	refresh()
end)
giftBtn.MouseButton1Click:Connect(function()
	local _, msg = R.ClaimGift:InvokeServer()
	showToast(msg)
end)
spinBtn.MouseButton1Click:Connect(function()
	local _, msg = R.Spin:InvokeServer()
	showToast(msg)
end)
codeBtn.MouseButton1Click:Connect(function()
	local code = string.upper(capBox.Text)
	if code == "" then
		showToast("Type a code in the cap box first — codes go there too 😉")
		return
	end
	local _, msg = R.RedeemCode:InvokeServer(code)
	showToast(msg)
end)

-- ===== مزامنة الإحصائيات + شفافية البوابات =====
local stats = player:WaitForChild("leaderstats")
function syncStats()
	local chargeNow = stats.Charge.Value
	local eff = lastCap > 0 and math.min(chargeNow, lastCap) or chargeNow
	local spd = math.floor(16 + math.sqrt(math.max(eff, 0)) / 2)
	bigCharge.Text = Format.num(chargeNow) .. " ⚡   🏃 " .. spd
	winsChip.Text = "🏆 " .. Format.num(stats.Wins.Value)
	local level = stats.Level.Value
	local world = workspace:FindFirstChild("PhoneWorld")
	local stagesFolder = world and world:FindFirstChild("Stages")
	if stagesFolder then
		for _, sf in stagesFolder:GetChildren() do
			local gate = sf:FindFirstChild("Gate")
			if gate then
				local need = gate:GetAttribute("Need")
				if need then
					gate.Transparency = level >= need and 0.5 or 0
				end
			end
		end
	end
end
stats.Charge.Changed:Connect(syncStats)
stats.Wins.Changed:Connect(syncStats)
stats.Stage.Changed:Connect(syncStats)
stats.Level.Changed:Connect(syncStats)
stats.Charge.Changed:Connect(function()
	if soundOn and os.clock() - lastPopAt > 0.12 then
		lastPopAt = os.clock()
		pop.PlaybackSpeed = 0.95 + math.random() * 0.15
		pop:Play()
	end
end)
syncStats()

-- ===== حلقة الهدف والبطارية =====
task.spawn(function()
	while true do
		local ok, st = pcall(function()
			return R.GetState:InvokeServer()
		end)
		if ok and st and st.level then
			local text
			if st.stage < #Config.STAGES then
				local nxt = st.stage + 1
				text = "🎯 Next: Stage " .. nxt .. " — needs Level " .. Config.STAGES[nxt].req .. " (you are " .. st.level .. ")"
			else
				text = "🏆 WORLD 1 BEATEN! 📱 Upgrade your phone / 🔄 OS Update to grow stronger"
			end
			local boostLeft = (st.boostUntil or 0) - os.time()
			if boostLeft > 0 then
				text = "🔥 BOOST x" .. (st.boostMult or 1) .. " (" .. math.floor(boostLeft / 60) .. "m " .. (boostLeft % 60) .. "s)  •  " .. text
			end
			objective.Text = text
			if st.battery then
				battFrame.Visible = true
				battFill.Size = UDim2.new(math.clamp(st.battery / 100, 0, 1), 0, 1, 0)
				battFill.BackgroundColor3 = st.battery > 50 and Color3.fromRGB(90, 255, 120) or (st.battery > 25 and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(255, 80, 60))
				battText.Text = "🔋 " .. st.battery .. "%"
			else
				battFrame.Visible = false
			end
		end
		task.wait(2)
	end
end)

task.spawn(function()
	while true do
		refresh()
		applyEffects()
		task.wait(4)
	end
end)
