-- ClientMain v3: HUD modeled on توفيق's screenshot of the real game —
-- left button column (Rebirth / FREE / Teleport / Trails / Auras / Items /
-- Chargers / Code), bottom-center big Speed + Level bar + multiplier lines,
-- right-side Shop + Custom Speed cap, buy-speed product buttons.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NumberFormat = require(Shared.NumberFormat)
local EconomyClient = require(Shared.Economy)
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local gui = Instance.new("ScreenGui")
gui.Name = "PhoneHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function corner(parent, r)
	make("UICorner", { CornerRadius = UDim.new(0, r or 10) }, parent)
end

-- ===== left column: wins + buttons =====
local winsLabel = make("TextLabel", {
	Size = UDim2.new(0, 170, 0, 44), Position = UDim2.new(0, 10, 0, 10),
	BackgroundColor3 = Color3.fromRGB(25, 25, 35), BackgroundTransparency = 0.15,
	Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = Color3.fromRGB(120, 255, 140), Text = "🏆 0",
}, gui)
corner(winsLabel, 12)

local leftButtons = {}
local function leftButton(text, color, order)
	-- two-column grid (v4 comfort: compact, thumb-friendly, nothing off-screen)
	local col = (order - 1) % 2
	local row = math.floor((order - 1) / 2)
	local b = make("TextButton", {
		Size = UDim2.new(0, 118, 0, 60), Position = UDim2.new(0, 10 + col * 126, 0, 66 + row * 68),
		BackgroundColor3 = color, Font = Enum.Font.FredokaOne, TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1), Text = text, BorderSizePixel = 0,
	}, gui)
	corner(b, 12)
	leftButtons[text] = b
	return b
end
local rebBtn = leftButton("📱\nUpgrade", Color3.fromRGB(90, 160, 255), 1)
local giftBtn = leftButton("🎁\nFREE!", Color3.fromRGB(255, 120, 170), 2)
local tpBtn = leftButton("🌀\nTeleport", Color3.fromRGB(150, 90, 220), 3)
local caseBtn = leftButton("📦\nCases", Color3.fromRGB(200, 90, 200), 4)
local signalBtn = leftButton("📶\nSignal", Color3.fromRGB(70, 130, 230), 5)
local itemBtn = leftButton("🎒\nItems", Color3.fromRGB(230, 150, 60), 6)
local trainBtn = leftButton("🏃\nChargers", Color3.fromRGB(60, 170, 90), 7)
local codeBtn = leftButton("🔑\nCode", Color3.fromRGB(90, 90, 110), 8)
local ascBtn = leftButton("🔄\nOS Update", Color3.fromRGB(255, 190, 40), 9)
local questBtn = leftButton("🎖️\nQuests", Color3.fromRGB(220, 170, 40), 10)
local spinBtn = leftButton("🎡\nSpin", Color3.fromRGB(200, 80, 200), 11)
local stepsBtn = leftButton("🔗\nLinks", Color3.fromRGB(90, 170, 90), 12)
spinBtn.MouseButton1Click:Connect(function()
	local _, msg = remotes.Spin:InvokeServer()
	showToast(msg)
end)

-- Objective banner (v6 comfort): always shows the player's next goal.
local objective = make("TextLabel", {
	Size = UDim2.new(0, 460, 0, 26), Position = UDim2.new(0.5, -230, 0, 118),
	BackgroundColor3 = Color3.fromRGB(20, 20, 35), BackgroundTransparency = 0.35,
	Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = Color3.fromRGB(255, 230, 150), Text = "🎯 ...",
}, gui)
corner(objective, 8)

-- Battery bar (boss stages only): driven by GetState's Battery field.
local batteryFrame = make("Frame", {
	Size = UDim2.new(0, 330, 0, 30), Position = UDim2.new(0.5, -165, 0, 150),
	BackgroundColor3 = Color3.fromRGB(30, 30, 40), BorderSizePixel = 0, Visible = false,
}, gui)
corner(batteryFrame, 8)
local batteryFill = make("Frame", {
	Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(90, 255, 120), BorderSizePixel = 0,
}, batteryFrame)
corner(batteryFill, 8)
local batteryText = make("TextLabel", {
	Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne,
	TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "🔋 100%",
}, batteryFrame)

-- Key pop sound (v6): soft click when your Speed rises, throttled.
local popSound = Instance.new("Sound")
popSound.SoundId = "rbxassetid://6026984224"
popSound.Volume = 0.3
popSound.Parent = gui
local soundOn = true
local lastPop = 0

-- ===== bottom center: speed, level bar, multipliers, buy-speed =====
local bigSpeed = make("TextLabel", {
	Size = UDim2.new(0, 460, 0, 62), Position = UDim2.new(0.5, -230, 1, -178),
	BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3, Text = "0 Speed",
}, gui)
local levelLabel = make("TextLabel", {
	Size = UDim2.new(0, 130, 0, 40), Position = UDim2.new(0.5, -330, 1, -112),
	BackgroundColor3 = Color3.fromRGB(120, 85, 40), Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1), Text = "Level 1", BorderSizePixel = 0,
}, gui)
corner(levelLabel, 10)
local barBg = make("Frame", {
	Size = UDim2.new(0, 330, 0, 40), Position = UDim2.new(0.5, -190, 1, -112),
	BackgroundColor3 = Color3.fromRGB(30, 30, 40), BorderSizePixel = 0,
}, gui)
corner(barBg, 10)
local barFill = make("Frame", {
	Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 170, 60), BorderSizePixel = 0,
}, barBg)
corner(barFill, 10)
local barText = make("TextLabel", {
	Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne,
	TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "0 / 100",
}, barBg)
local multLine = make("TextLabel", {
	Size = UDim2.new(0, 700, 0, 30), Position = UDim2.new(0.5, -350, 1, -66),
	BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.fromRGB(200, 220, 255), TextStrokeTransparency = 0.5, Text = "",
}, gui)

local buyRow = { { "Charge150K", "+150K ⚡" }, { "Charge1M", "+1M ⚡" }, { "Charge10M", "+10M ⚡" } }
for i, row in buyRow do
	local b = make("TextButton", {
		Size = UDim2.new(0, 168, 0, 42), Position = UDim2.new(0.5, -260 + (i - 1) * 178, 1, -34),
		BackgroundColor3 = i == 3 and Color3.fromRGB(255, 190, 40) or Color3.fromRGB(140, 95, 60),
		Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
		Text = row[2], BorderSizePixel = 0,
	}, gui)
	corner(b, 10)
	b.MouseButton1Click:Connect(function()
		local pid = Config.PRODUCTS[row[1]]
		if pid and pid > 0 then
			MarketplaceService:PromptProductPurchase(player, pid)
		else
			showToast("This product is not set up yet")
		end
	end)
end

-- ===== right side: shop + custom speed =====
local shopBtn = make("TextButton", {
	Size = UDim2.new(0, 150, 0, 58), Position = UDim2.new(1, -160, 0, 10),
	BackgroundColor3 = Color3.fromRGB(255, 90, 160), Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1), Text = "🛒 Shop", BorderSizePixel = 0,
}, gui)
corner(shopBtn, 12)
local capBox = make("TextBox", {
	Size = UDim2.new(0, 96, 0, 40), Position = UDim2.new(1, -160, 0, 78),
	BackgroundColor3 = Color3.fromRGB(240, 240, 245), Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.fromRGB(30, 30, 40), Text = "", PlaceholderText = "Max charge", BorderSizePixel = 0,
}, gui)
corner(capBox, 8)
local capOk = make("TextButton", {
	Size = UDim2.new(0, 54, 0, 40), Position = UDim2.new(1, -58, 0, 78),
	BackgroundColor3 = Color3.fromRGB(60, 200, 90), Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1), Text = "OK", BorderSizePixel = 0,
}, gui)
corner(capOk, 8)
local capLabel = make("TextLabel", {
	Size = UDim2.new(0, 150, 0, 24), Position = UDim2.new(1, -160, 0, 122),
	BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4, Text = "Max Charge: off",
}, gui)
capOk.MouseButton1Click:Connect(function()
	local cap = tonumber(capBox.Text) or 0
	remotes.SetCap:FireServer(cap)
	capLabel.Text = cap > 0 and ("Max Charge: " .. NumberFormat.format(cap)) or "Custom Speed: off"
	showToast(cap > 0 and ("🚦 Max charge set to " .. NumberFormat.format(cap)) or "🚦 Charge cap removed")
end)

-- ===== toast =====
local toast = make("TextLabel", {
	Size = UDim2.new(0, 680, 0, 46), Position = UDim2.new(0.5, -340, 0, 14),
	BackgroundColor3 = Color3.fromRGB(20, 20, 30), BackgroundTransparency = 0.25,
	Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "", Visible = false,
}, gui)
corner(toast, 10)
local toastToken = 0
function showToast(text)
	toastToken += 1
	local my = toastToken
	toast.Text = text
	toast.Visible = true
	task.delay(2.8, function()
		if toastToken == my then
			toast.Visible = false
		end
	end)
end
remotes.Toast.OnClientEvent:Connect(showToast)
local shakeOn = true
local effectsOn = true
remotes.StageCleared.OnClientEvent:Connect(function()
	-- confetti burst at the player (v4 delight, client-only parts)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		local Debris = game:GetService("Debris")
		local colors = { Color3.fromRGB(255, 110, 180), Color3.fromRGB(110, 220, 255), Color3.fromRGB(170, 255, 110), Color3.fromRGB(255, 200, 80) }
		for i = 1, 26 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(0.35, 0.35, 0.35)
			p.Color = colors[(i % #colors) + 1]
			p.Material = Enum.Material.Neon
			p.CanCollide = false
			p.CFrame = hrp.CFrame + Vector3.new(0, 1, 0)
			p.AssemblyLinearVelocity = Vector3.new(math.random(-14, 14), math.random(14, 26), math.random(-14, 14))
			p.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
			p.Parent = workspace
			Debris:AddItem(p, 1.4)
		end
	end
	if not shakeOn then
		return
	end
	local cam = workspace.CurrentCamera
	if cam then
		local orig = cam.CFrame
		for _ = 1, 3 do
			cam.CFrame = orig * CFrame.new(math.random(-2, 2) / 20, math.random(-2, 2) / 20, 0)
			task.wait(0.03)
		end
		cam.CFrame = orig
	end
end)

-- ===== panels =====
local panels = {}
local function shopPanel(key, title)
	local f = make("Frame", {
		Size = UDim2.new(0, 440, 0, 400), Position = UDim2.new(0.5, -220, 0.5, -200),
		BackgroundColor3 = Color3.fromRGB(28, 28, 40), BorderSizePixel = 0, Visible = false,
	}, gui)
	corner(f, 14)
	make("TextLabel", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = title }, f)
	local close = make("TextButton", {
		Size = UDim2.new(0, 38, 0, 38), Position = UDim2.new(1, -44, 0, 4),
		BackgroundColor3 = Color3.fromRGB(200, 60, 60), Font = Enum.Font.FredokaOne,
		TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "X", BorderSizePixel = 0,
	}, f)
	corner(close, 8)
	close.MouseButton1Click:Connect(function()
		f.Visible = false
	end)
	local scroll = make("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -56), Position = UDim2.new(0, 8, 0, 50),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(0, 0, 0, 0),
	}, f)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	panels[key] = { frame = f, scroll = scroll }
	return panels[key]
end
local function rowButton(scroll, text, color, onClick)
	local b = make("TextButton", {
		Size = UDim2.new(1, -8, 0, 50), BackgroundColor3 = color, Font = Enum.Font.FredokaOne,
		TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = text, BorderSizePixel = 0,
	}, scroll)
	corner(b, 10)
	b.MouseButton1Click:Connect(onClick)
	return b
end
local function clearRows(scroll)
	for _, c in scroll:GetChildren() do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
end
local function fixCanvas(panel)
	local count = 0
	for _, c in panel.scroll:GetChildren() do
		if c:IsA("TextButton") then
			count += 1
		end
	end
	panel.scroll.CanvasSize = UDim2.new(0, 0, 0, count * 56 + 10)
end

local casesPanel = shopPanel("cases", "📦 CASES")
local signalsPanel = shopPanel("auras", "📶 SIGNAL")
local itemsPanel = shopPanel("items", "🎒 ITEMS (+% Charge)")
local trainPanel = shopPanel("train", "🔌 CHARGERS")
local passPanel = shopPanel("shop", "🛒 SHOP")
local tpPanel = shopPanel("tp", "🌀 TELEPORT")
local questsPanel = shopPanel("quests", "🎖️ MEDAL QUESTS (daily)")
local stepsPanel = shopPanel("steps", "🔗 FAST-CHARGE LINKS (+⚡ per step)")

local function applyEffects()
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			local hrp = other.Character:FindFirstChild("HumanoidRootPart")
			local trail = hrp and hrp:FindFirstChild("CaseTrail")
			if trail then
				trail.Enabled = effectsOn
			end
		end
	end
	local myHrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for _, part in workspace:GetChildren() do
		if part.Name == "Signal" and part:IsA("BasePart") then
			local mine = myHrp and (part.Position - myHrp.Position).Magnitude < 7
			if not mine then
				part.Transparency = effectsOn and 0.75 or 1
			end
		end
	end
end

local lastState = {}
local function refreshShops()
	local state = remotes.GetState:InvokeServer()
	lastState = state
	levelLabel.Text = "Level " .. (state.Level or 1)
	barText.Text = NumberFormat.format(state.LevelInto or 0) .. " / " .. NumberFormat.format(state.LevelBand or 100)
	barFill.Size = UDim2.new(math.clamp((state.LevelInto or 0) / math.max(state.LevelBand or 100, 1), 0, 1), 0, 1, 0)
	multLine.Text = "Case & Signal x" .. NumberFormat.format((state.CaseMult or 1) * (state.SignalMult or 1))
		.. "   •   Items x" .. tostring(state.ItemMult or 1)
		.. "   •   Phone x" .. NumberFormat.format(state.RebirthMult or 1)
		.. "   •   OS x" .. NumberFormat.format(state.AscendMult or 1)
		.. "   •   TOTAL x" .. NumberFormat.format(state.GainMult or 1)

	clearRows(casesPanel.scroll)
	for i, item in Config.CASES do
		local owned = (state.CasesOwned and table.find(state.CasesOwned, i)) or (item.pass and state[item.pass])
		local costText = item.pass and "👑 PASS (in 🛒 Shop)" or "🏆 " .. NumberFormat.format(item.cost)
		local text = item.name .. " x" .. NumberFormat.format(item.mult) .. (owned and " ✅" or " — " .. costText)
		rowButton(casesPanel.scroll, text, owned and Color3.fromRGB(70, 130, 70) or Color3.fromRGB(60, 60, 85), function()
			local _, msg = remotes.BuyCase:InvokeServer(i)
			showToast(msg)
			refreshShops()
		end)
	end
	fixCanvas(casesPanel)

	clearRows(signalsPanel.scroll)
	for i, item in Config.SIGNALS do
		local owned = (state.SignalsOwned and table.find(state.SignalsOwned, i)) or (item.pass and state[item.pass])
		local costText = item.pass and "👑 PASS (in 🛒 Shop)" or (item.cost == 0 and "FREE" or "🏆 " .. NumberFormat.format(item.cost))
		local text = item.name .. " x" .. item.mult .. (owned and " ✅" or " — " .. costText)
		rowButton(signalsPanel.scroll, text, owned and Color3.fromRGB(70, 130, 70) or Color3.fromRGB(60, 60, 85), function()
			local _, msg = remotes.BuySignal:InvokeServer(i)
			showToast(msg)
			refreshShops()
		end)
	end
	fixCanvas(signalsPanel)

	clearRows(itemsPanel.scroll)
	for i, item in Config.ITEMS do
		local owned = state.ItemsOwned and table.find(state.ItemsOwned, i)
		local text = item.name .. " (+" .. item.pct .. "% Charge)" .. (owned and " ✅" or " — 🏆 " .. NumberFormat.format(item.cost))
		rowButton(itemsPanel.scroll, text, owned and Color3.fromRGB(70, 130, 70) or Color3.fromRGB(60, 60, 85), function()
			local _, msg = remotes.BuyItem:InvokeServer(i)
			showToast(msg)
			refreshShops()
		end)
	end
	fixCanvas(itemsPanel)

	clearRows(trainPanel.scroll)
	for i, item in Config.CHARGERS do
		local owned = state.ChargersOwned and table.find(state.ChargersOwned, i)
		local level = (state.ChargerLevels and state.ChargerLevels[i]) or 0
		local outNow = EconomyClient.chargerOutput(item, level)
		if not owned then
			local costText = item.cost == -1 and "👑 VIP PASS" or (item.cost == 0 and "FREE" or "🏆 " .. NumberFormat.format(item.cost))
			rowButton(trainPanel.scroll, item.name .. " (+" .. NumberFormat.format(outNow) .. "/s) — " .. costText, Color3.fromRGB(60, 60, 85), function()
				local _, msg = remotes.UnlockCharger:InvokeServer(i)
				showToast(msg)
				refreshShops()
			end)
		elseif level >= Config.CHARGER_MAX_LEVEL then
			rowButton(trainPanel.scroll, item.name .. " Lv" .. level .. " ⭐ MAX (+" .. NumberFormat.format(outNow) .. "/s)", Color3.fromRGB(160, 130, 40), function() end)
		else
			local cost = EconomyClient.chargerUpgradeCost(item, level)
			local outNext = EconomyClient.chargerOutput(item, level + 1)
			local text = "⬆️ " .. item.name .. " Lv" .. level .. " (+" .. NumberFormat.format(outNow) .. "/s) → +" .. NumberFormat.format(outNext) .. "/s — 🏆 " .. NumberFormat.format(cost)
			rowButton(trainPanel.scroll, text, Color3.fromRGB(60, 60, 85), function()
				local _, msg = remotes.UpgradeCharger:InvokeServer(i)
				showToast(msg)
				refreshShops()
			end)
		end
	end
	fixCanvas(trainPanel)

	clearRows(passPanel.scroll)
	local passRows = {
		{ name = "⚡ Double Charge (x2 gains)", id = Config.PASSES.DoubleCharge },
		{ name = "🏆 Double Wins (x2)", id = Config.PASSES.DoubleWins },
		{ name = "👑 VIP (x3 gains + Gold Cable)", id = Config.PASSES.VIP },
		{ name = "♾️ INFINITY CASE (x" .. NumberFormat.format(Config.INFINITY_CASE.mult) .. ")", id = Config.PASSES.InfinityCase },
		{ name = "🌌 GALAXY CASE (x10)", id = Config.PASSES.GalaxyCase },
		{ name = "🌑 DARKNESS SIGNAL (x10)", id = Config.PASSES.DarknessSignal },
		{ name = "🔌 كابل ذهبي — GOLD CABLE (stations x3)", id = Config.PASSES.CableGold },
		{ name = "🔌 كابل ماسي — DIAMOND CABLE (stations x9)", id = Config.PASSES.CableDiamond },
		{ name = "🔌 كابل الحلوى — CANDY CABLE (stations x25)", id = Config.PASSES.CableCandy },
		{ name = "🔌 كابل الأدمين — ADMIN CABLE (stations x100)", id = Config.PASSES.CableAdmin },
	}
	for _, row in passRows do
		rowButton(passPanel.scroll, row.name, Color3.fromRGB(60, 60, 85), function()
			if row.id > 0 then
				MarketplaceService:PromptGamePassPurchase(player, row.id)
			else
				showToast("This pass is not set up yet")
			end
		end)
	end
	rowButton(passPanel.scroll, "🔊 Sound: " .. (soundOn and "ON" or "OFF"), Color3.fromRGB(90, 90, 110), function()
		soundOn = not soundOn
		refreshShops()
	end)
	rowButton(passPanel.scroll, "⏩ Skip Next Stage", Color3.fromRGB(180, 120, 30), function()
		if Config.PRODUCTS.SkipStage > 0 then
			MarketplaceService:PromptProductPurchase(player, Config.PRODUCTS.SkipStage)
		else
			showToast("Skip is not set up yet")
		end
	end)
	-- comfort settings (v4)
	rowButton(passPanel.scroll, "📷 Screen shake: " .. (shakeOn and "ON" or "OFF"), Color3.fromRGB(90, 90, 110), function()
		shakeOn = not shakeOn
		refreshShops()
	end)
	rowButton(passPanel.scroll, "👁 Others' effects: " .. (effectsOn and "ON" or "OFF"), Color3.fromRGB(90, 90, 110), function()
		effectsOn = not effectsOn
		applyEffects()
		refreshShops()
	end)
	fixCanvas(passPanel)

	-- quests (v4)
	local q = remotes.GetQuests:InvokeServer()
	clearRows(questsPanel.scroll)
	if q and q.quests then
		rowButton(questsPanel.scroll, "📅 Login streak: " .. (q.streak or 1) .. " day(s) — come back daily!", Color3.fromRGB(90, 90, 110), function() end)
		for _, quest in q.quests do
			local done = quest.progress >= quest.target
			local status = quest.claimed and " ✅ CLAIMED" or (done and " — TAP TO CLAIM!" or "")
			local text = quest.text .. " (" .. NumberFormat.format(math.min(quest.progress, quest.target)) .. "/" .. NumberFormat.format(quest.target) .. ")" .. status
			rowButton(questsPanel.scroll, text, quest.claimed and Color3.fromRGB(70, 130, 70) or Color3.fromRGB(60, 60, 85), function()
				local _, msg = remotes.ClaimQuest:InvokeServer(quest.id)
				showToast(msg)
				refreshShops()
			end)
		end
	end
	fixCanvas(questsPanel)

	-- step pads (v7)
	clearRows(stepsPanel.scroll)
	local curStep = state.StepIndex or 1
	for i, pad in Config.STEP_PADS do
		if i < curStep then
			rowButton(stepsPanel.scroll, "+" .. NumberFormat.format(pad.amount) .. " ⚡ / step ✅", Color3.fromRGB(70, 110, 70), function() end)
		elseif i == curStep then
			rowButton(stepsPanel.scroll, "▶ +" .. NumberFormat.format(pad.amount) .. " ⚡ / step (ACTIVE)", Color3.fromRGB(40, 140, 70), function() end)
		elseif i == curStep + 1 then
			rowButton(stepsPanel.scroll, "⬆️ +" .. NumberFormat.format(pad.amount) .. " ⚡ / step — 🏆 " .. NumberFormat.format(pad.cost), Color3.fromRGB(60, 60, 85), function()
				local _, msg = remotes.BuyStep:InvokeServer()
				showToast(msg)
				refreshShops()
			end)
		else
			rowButton(stepsPanel.scroll, "🔒 +" .. NumberFormat.format(pad.amount) .. " ⚡ / step — 🏆 " .. NumberFormat.format(pad.cost), Color3.fromRGB(45, 45, 60), function() end)
		end
	end
	fixCanvas(stepsPanel)

	clearRows(tpPanel.scroll)
	rowButton(tpPanel.scroll, "🏠 Lobby", Color3.fromRGB(60, 60, 85), function()
		remotes.Teleport:FireServer("lobby")
		tpPanel.frame.Visible = false
	end)
	rowButton(tpPanel.scroll, "🔒 World 2 — Social Apps (SOON)", Color3.fromRGB(70, 120, 190), function()
		remotes.Teleport:FireServer("world2")
		tpPanel.frame.Visible = false
	end)
	rowButton(tpPanel.scroll, "🚀 My next Stage", Color3.fromRGB(60, 60, 85), function()
		remotes.Teleport:FireServer("stage")
		tpPanel.frame.Visible = false
	end)
	fixCanvas(tpPanel)
end

local function toggle(panel)
	for _, p in panels do
		p.frame.Visible = (p == panel) and not panel.frame.Visible
	end
	if panel.frame.Visible then
		refreshShops()
	end
end
caseBtn.MouseButton1Click:Connect(function() toggle(casesPanel) end)
signalBtn.MouseButton1Click:Connect(function() toggle(signalsPanel) end)
itemBtn.MouseButton1Click:Connect(function() toggle(itemsPanel) end)
trainBtn.MouseButton1Click:Connect(function() toggle(trainPanel) end)
shopBtn.MouseButton1Click:Connect(function() toggle(passPanel) end)
tpBtn.MouseButton1Click:Connect(function() toggle(tpPanel) end)
questBtn.MouseButton1Click:Connect(function() toggle(questsPanel) end)
stepsBtn.MouseButton1Click:Connect(function() toggle(stepsPanel) end)
rebBtn.MouseButton1Click:Connect(function()
	local _, msg = remotes.UpgradePhone:InvokeServer()
	showToast(msg)
	refreshShops()
end)
ascBtn.MouseButton1Click:Connect(function()
	local _, msg = remotes.Ascend:InvokeServer()
	showToast(msg)
	refreshShops()
end)
giftBtn.MouseButton1Click:Connect(function()
	local _, msg = remotes.ClaimGift:InvokeServer()
	showToast(msg)
end)
codeBtn.MouseButton1Click:Connect(function()
	local code = string.upper(capBox.Text)
	if code == "" then
		showToast("Type a code in the cap box first — codes go there too 😉")
		return
	end
	local _, msg = remotes.RedeemCode:InvokeServer(code)
	showToast(msg)
end)

-- ===== stat sync + gate fading + level polling =====
local ls = player:WaitForChild("leaderstats")
local function refreshStats()
	bigSpeed.Text = NumberFormat.format(ls.Charge.Value) .. " ⚡"
	winsLabel.Text = "🏆 " .. NumberFormat.format(ls.Wins.Value)
	-- Gates fade when your LEVEL meets the requirement (v7 level gates).
	local level = ls:FindFirstChild("Level") and ls.Level.Value or 1
	local map = workspace:WaitForChild("PhoneMap")
	local stages = map:FindFirstChild("Stages")
	if stages then
		for _, stageFolder in stages:GetChildren() do
			local gate = stageFolder:FindFirstChild("Gate")
			if gate then
				local req = gate:GetAttribute("Requirement")
				if req then
					gate.Transparency = level >= req and 0.5 or 0
				end
			end
		end
	end
end
ls.Charge.Changed:Connect(refreshStats)
ls.Wins.Changed:Connect(refreshStats)
ls.Stage.Changed:Connect(refreshStats)
if ls:FindFirstChild("Level") then
	ls.Level.Changed:Connect(refreshStats)
end
refreshStats()

-- Pop sound on speed gains (v6)
ls.Charge.Changed:Connect(function()
	if soundOn and os.clock() - lastPop > 0.12 then
		lastPop = os.clock()
		popSound.PlaybackSpeed = 0.95 + math.random() * 0.15
		popSound:Play()
	end
end)

-- Objective + boost banner refresh (v6)
task.spawn(function()
	while true do
		local okState, st = pcall(function()
			return remotes.GetState:InvokeServer()
		end)
		if okState and st and st.Level then
			local stageNow = ls.Stage.Value
			local text
			local boostLeft = (st.BoostUntil or 0) - os.time()
			if stageNow < #Config.STAGE_LEVEL_REQS then
				local nxt = stageNow + 1
				text = "🎯 Next: Stage " .. nxt .. " — needs Level " .. Config.STAGE_LEVEL_REQS[nxt] .. " (you are " .. (st.Level or 1) .. ")"
			else
				text = "🏆 WORLD 1 BEATEN! 📱 Upgrade your phone / 🔄 OS Update to grow stronger"
			end
			if boostLeft > 0 then
				text = "🔥 BOOST x" .. (st.BoostMult or 1) .. " (" .. math.floor(boostLeft / 60) .. "m " .. (boostLeft % 60) .. "s)  •  " .. text
			end
			objective.Text = text
			if st.Battery then
				batteryFrame.Visible = true
				batteryFill.Size = UDim2.new(math.clamp(st.Battery / 100, 0, 1), 0, 1, 0)
				batteryFill.BackgroundColor3 = st.Battery > 50 and Color3.fromRGB(90, 255, 120) or (st.Battery > 25 and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(255, 80, 60))
				batteryText.Text = "🔋 " .. st.Battery .. "%"
			else
				batteryFrame.Visible = false
			end
		end
		task.wait(2)
	end
end)

task.spawn(function()
	while true do
		refreshShops()
		applyEffects() -- keep "hide others' effects" true for players who joined later
		task.wait(4)
	end
end)
