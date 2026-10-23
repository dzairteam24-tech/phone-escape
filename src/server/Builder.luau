-- Builder.luau — يبني عالم اللعبة كاملًا من الكود عند بدء السيرفر:
-- لوبي «شاشة رئيسية» + محطات شحن + 15 مرحلة داخل التطبيقات.
-- البناء يتم في مجلد مؤقت ثم يُستبدل دفعة واحدة (فشل البناء لا يدمر
-- الخريطة المخبوزة الموجودة في المكان).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local Builder = {}

local function block(parent, name, size, pos, rgb, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = pos
	p.Anchored = true
	p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function text(partObj, str, face, rgb)
	local faces = { face }
	if face ~= Enum.NormalId.Top and face ~= Enum.NormalId.Bottom then
		table.insert(faces, face == Enum.NormalId.Front and Enum.NormalId.Back or Enum.NormalId.Front)
	end
	local made
	for _, f in faces do
		local gui = Instance.new("SurfaceGui")
		gui.Face = f
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = partObj
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Font = Enum.Font.FredokaOne
		tl.TextScaled = true
		tl.TextColor3 = rgb or Color3.new(1, 1, 1)
		tl.TextStrokeTransparency = 0.35
		tl.Text = str
		tl.Parent = gui
		made = made or tl
	end
	return made
end

local function boardText(partObj, title)
	local labels = {}
	for _, f in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = f
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = partObj
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Font = Enum.Font.FredokaOne
		tl.TextScaled = true
		tl.TextColor3 = Color3.fromRGB(255, 230, 120)
		tl.Text = title
		tl.Parent = gui
		table.insert(labels, tl)
	end
	return labels
end

local function mix(a, b, t)
	return {
		math.floor(a[1] + (b[1] - a[1]) * t + 0.5),
		math.floor(a[2] + (b[2] - a[2]) * t + 0.5),
		math.floor(a[3] + (b[3] - a[3]) * t + 0.5),
	}
end

-- ===== مسار مرحلة واحدة من رموز الخطة =====
local function course(parent, stageIdx, plan, zTop, zBottom, theme)
	local z = zTop
	local n = 0
	local function starAt(x, y, zz)
		n += 1
		local s = block(parent, "Star" .. n, Vector3.new(1.7, 1.7, 1.7), Vector3.new(x, y, zz), { 255, 215, 0 }, Enum.Material.Neon)
		s.Shape = Enum.PartType.Ball
		s:SetAttribute("Star", true)
		s:SetAttribute("StarOf", stageIdx)
	end
	for _, token in plan do
		n += 1
		local kind, arg = string.match(token, "^(%a+):?(%d*)$")
		local len = tonumber(arg) or 0
		local mid = z - len / 2
		if kind == "run" then
			block(parent, "Run" .. n, Vector3.new(16, 1, len), Vector3.new(0, 0, mid), theme.floor)
		elseif kind == "gap" then
			-- هواء فوق أرضية القتل
		elseif kind == "moving" or kind == "movingy" then
			local p = block(parent, "Lift" .. n, Vector3.new(11, 1, 10), Vector3.new(0, 0, mid), theme.accent)
			p:SetAttribute("Move", true)
			p:SetAttribute("Axis", kind == "movingy" and "Y" or "X")
			p:SetAttribute("Range", kind == "movingy" and 3.2 or 7)
			p:SetAttribute("Speed", 1.1)
			p:SetAttribute("Phase", stageIdx * 1.7 + n)
		elseif kind == "vanish" then
			local seg = len / 3
			for k = 1, 3 do
				local p = block(parent, "Blink" .. n .. "_" .. k, Vector3.new(16, 0.8, seg - 1.5), Vector3.new(0, 0, z - (k - 0.5) * seg), { 255, 240, 170 }, Enum.Material.Neon)
				p:SetAttribute("Vanish", (k + stageIdx) % 3)
			end
		elseif kind == "convF" or kind == "convB" then
			local p = block(parent, "Belt" .. n, Vector3.new(16, 1, len), Vector3.new(0, 0, mid), kind == "convF" and { 90, 200, 255 } or { 255, 150, 90 })
			p:SetAttribute("Belt", kind == "convF" and -26 or 18)
		elseif kind == "bounce" then
			for _, f in { 0.3, 0.7 } do
				local iz = z - len * f
				block(parent, "Isle" .. n, Vector3.new(9, 1, 9), Vector3.new(0, 0, iz), theme.floor)
				local p = block(parent, "Pad" .. n, Vector3.new(6, 0.6, 6), Vector3.new(0, 0.8, iz), { 255, 90, 200 }, Enum.Material.Neon)
				p:SetAttribute("Bounce", 68)
			end
		elseif kind == "sweep" then
			block(parent, "SweepFloor" .. n, Vector3.new(16, 1, len), Vector3.new(0, 0, mid), theme.floor)
			block(parent, "SweepPost" .. n, Vector3.new(1.2, 3, 1.2), Vector3.new(0, 1.5, mid), { 60, 60, 70 })
			local arm = block(parent, "Spinner" .. n, Vector3.new(13, 1.1, 1.1), Vector3.new(0, 1.35, mid), { 235, 70, 60 }, Enum.Material.Neon)
			arm:SetAttribute("Sweep", true)
			arm:SetAttribute("SweepSpeed", 1.1 + stageIdx * 0.04)
			arm:SetAttribute("PivotX", 0)
			arm:SetAttribute("PivotZ", mid)
		elseif kind == "narrow" then
			block(parent, "Bridge" .. n .. "a", Vector3.new(4.5, 1, len / 2), Vector3.new(-3.5, 0, z - len / 4), theme.floor)
			block(parent, "Bridge" .. n .. "b", Vector3.new(4.5, 1, len / 2), Vector3.new(3.5, 0, z - 3 * len / 4), theme.floor)
		elseif kind == "tower" then
			for k = 1, 5 do
				block(parent, "Step" .. n .. "_" .. k, Vector3.new(9, 1, 9), Vector3.new(0, k * 2.1 - 1, z - (k - 0.5) * (len / 5)), theme.floor)
			end
		elseif kind == "split" then
			block(parent, "Safe" .. n, Vector3.new(10, 1, len), Vector3.new(-12.5, 0, mid), theme.floor)
			block(parent, "Risk" .. n, Vector3.new(5, 1, len), Vector3.new(13.5, 0, mid), theme.accent)
			for _, f in { 0.25, 0.5, 0.75 } do
				starAt(13.5, 1.6, z - len * f)
			end
		elseif kind == "mid" then
			local p = block(parent, "MidPad", Vector3.new(12, 0.6, 6), Vector3.new(0, 0.3, z - 3), { 120, 255, 140 }, Enum.Material.Neon)
			p:SetAttribute("Mid", stageIdx)
		end
		z -= len
	end
	if z > zBottom then
		block(parent, "Fill", Vector3.new(16, 1, z - zBottom), Vector3.new(0, 0, (z + zBottom) / 2), theme.floor)
	end
end

function Builder.build()
	-- إضاءة وأجواء
	local Lighting = game:GetService("Lighting")
	if not Lighting:FindFirstChild("PhoneBloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "PhoneBloom"
		bloom.Intensity = 0.35
		bloom.Size = 24
		bloom.Threshold = 0.85
		bloom.Parent = Lighting
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "PhoneGrade"
		cc.Saturation = 0.14
		cc.Contrast = 0.05
		cc.Brightness = 0.02
		cc.Parent = Lighting
		local atm = Instance.new("Atmosphere")
		atm.Name = "PhoneAir"
		atm.Density = 0.16
		atm.Color = Color3.fromRGB(215, 230, 255)
		atm.Decay = Color3.fromRGB(160, 200, 255)
		atm.Parent = Lighting
		Lighting.ClockTime = 14.2
	end

	local world = Instance.new("Folder")
	world.Name = "PhoneWorld_Building"
	local icons, built = 0, 0

	-- ================= اللوبي =================
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = world
	block(lobby, "Slab", Vector3.new(150, 1, 130), Vector3.new(0, -0.7, 34), { 22, 22, 34 })

	local screen = Instance.new("Folder")
	screen.Name = "HomeScreen"
	screen.Parent = lobby
	local pitch = Config.TILE + Config.GAP
	local palette = {
		{ 255, 90, 90 }, { 255, 160, 60 }, { 255, 215, 80 }, { 120, 220, 110 },
		{ 70, 200, 190 }, { 80, 160, 255 }, { 150, 110, 255 }, { 255, 110, 190 },
	}
	for r = 1, Config.GRID_ROWS do
		local z = 84 - (r - 1) * pitch
		for c = 1, Config.GRID_COLS do
			local x = (c - (Config.GRID_COLS + 1) / 2) * pitch
			local rgb = palette[((r * 3 + c) % #palette) + 1]
			local tile = block(screen, "Icon_" .. r .. "_" .. c, Vector3.new(Config.TILE, 0.8, Config.TILE), Vector3.new(x, 0.4, z), rgb)
			tile:SetAttribute("Icon", true)
			icons += 1
			local glyph = Config.GLYPHS[((r - 1) * Config.GRID_COLS + (c - 1)) % #Config.GLYPHS + 1]
			text(tile, glyph, Enum.NormalId.Top)
			block(screen, "Face_" .. r .. "_" .. c, Vector3.new(Config.TILE - 1.3, 0.22, Config.TILE - 1.3), Vector3.new(x, 0.91, z), mix(rgb, { 255, 255, 255 }, 0.25))
		end
	end

	-- إطار الهاتف + العنوان
	block(lobby, "BezelBack", Vector3.new(150, 10, 1), Vector3.new(0, 5, 93), { 30, 30, 45 })
	block(lobby, "BezelL", Vector3.new(1, 10, 118), Vector3.new(-71, 5, 34), { 30, 30, 45 })
	block(lobby, "BezelR", Vector3.new(1, 10, 118), Vector3.new(71, 5, 34), { 30, 30, 45 })
	block(lobby, "Trim", Vector3.new(150, 1, 1.4), Vector3.new(0, 10.4, 93), { 90, 230, 255 }, Enum.Material.Neon)
	local title = block(lobby, "Title", Vector3.new(52, 8, 1), Vector3.new(0, 5.5, 92.4), { 40, 40, 55 })
	text(title, "📱 PHONE ESCAPE 📱", Enum.NormalId.Back)

	-- منطقة الظهور
	block(lobby, "HomeBar", Vector3.new(17, 0.3, 17), Vector3.new(0, 0.95, 80), { 210, 210, 220 })
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 1.4, 80)
	spawn.Anchored = true
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Neutral = true
	spawn.Transparency = 0.4
	spawn.Parent = lobby

	-- لافتات إرشاد
	block(lobby, "SignPost", Vector3.new(0.5, 5, 0.5), Vector3.new(0, 2.5, 30), { 90, 90, 100 })
	local s1 = block(lobby, "Sign1", Vector3.new(20, 4, 0.6), Vector3.new(0, 5.6, 30), { 50, 160, 90 })
	text(s1, "1️⃣ STEP ON APPS = +1 ⚡", Enum.NormalId.Back)
	local s2 = block(lobby, "Sign2", Vector3.new(15, 4, 0.6), Vector3.new(49, 4.5, 82), { 60, 120, 220 })
	text(s2, "🔌 CHARGE HERE ➡", Enum.NormalId.Back)
	local s3 = block(lobby, "Sign3", Vector3.new(20, 4, 0.6), Vector3.new(0, 5.6, -8), { 220, 90, 160 })
	text(s3, "🚪 STAGE 1 — LEVEL 1", Enum.NormalId.Back)

	-- لوحتا الصدارة بجانب بوابة المرحلة 1
	local bl = block(lobby, "BoardTopLevel", Vector3.new(19, 12, 1), Vector3.new(-24, 6.5, -15), { 90, 50, 140 })
	local levelLabels = boardText(bl, "🏆 TOP LEVEL 🏆")
	local bw = block(lobby, "BoardTopWins", Vector3.new(19, 12, 1), Vector3.new(24, 6.5, -15), { 90, 50, 140 })
	local winsLabels = boardText(bw, "🏆 TOP WINS 🏆")

	-- كشك الأدوات (زينة)
	block(lobby, "StallBase", Vector3.new(24, 1, 20), Vector3.new(-56, 0.9, 58), { 120, 80, 170 })
	local stall = block(lobby, "Stall", Vector3.new(18, 8, 12), Vector3.new(-56, 5.4, 60), { 170, 120, 230 })
	block(lobby, "StallRoof", Vector3.new(21, 1, 15), Vector3.new(-56, 9.8, 60), { 90, 50, 160 })
	text(stall, "🛍️ ITEMS", Enum.NormalId.Front)

	-- قوس العالم 2 (إعلان «قريبًا»)
	block(lobby, "ArchL", Vector3.new(3, 13, 3), Vector3.new(50, 6.5, 62), { 90, 90, 100 })
	block(lobby, "ArchR", Vector3.new(3, 13, 3), Vector3.new(62, 6.5, 62), { 90, 90, 100 })
	local arch = block(lobby, "ArchTop", Vector3.new(15, 3, 3), Vector3.new(56, 13.5, 62), { 90, 90, 100 })
	text(arch, "🌍 WORLD 2 — SOON", Enum.NormalId.Front)
	local teaser = block(lobby, "W2Teaser", Vector3.new(10, 0.5, 10), Vector3.new(40, 1.0, 62), { 120, 120, 140 }, Enum.Material.Neon)
	text(teaser, "🔒 WORLD 2\nSOCIAL APPS — SOON", Enum.NormalId.Top)

	-- فقاعات زينة
	local bub = { { 255, 110, 180 }, { 110, 220, 255 }, { 170, 255, 110 }, { 255, 190, 90 } }
	for i, pos in { { -66, 26 }, { 66, 26 }, { -66, 84 }, { 66, 84 } } do
		block(lobby, "Pole" .. i, Vector3.new(0.6, 10, 0.6), Vector3.new(pos[1], 5, pos[2]), { 245, 245, 245 })
		local head = block(lobby, "Bubble" .. i, Vector3.new(5.4, 1.4, 5.4), Vector3.new(pos[1], 10.6, pos[2]), bub[i], Enum.Material.Neon)
		head.Shape = Enum.PartType.Cylinder
		head.Orientation = Vector3.new(0, 0, 90)
	end

	-- منصة محطات الشحن (يمين)
	block(lobby, "StationDeck", Vector3.new(17, 1, 118), Vector3.new(58, 0.25, 26), { 45, 45, 60 })
	local stations = Instance.new("Folder")
	stations.Name = "Stations"
	stations.Parent = lobby
	for i, chg in Config.CHARGERS do
		local z = 74 - (i - 1) * 16
		local pad = block(stations, "Station_" .. i, Vector3.new(13, 0.25, 13), Vector3.new(58, 0.9, z),
			i == #Config.CHARGERS and { 255, 200, 40 } or { 80, 80, 100 }, Enum.Material.Neon)
		pad:SetAttribute("Station", i)
		local price = chg.cost == 0 and "FREE" or "🏆 " .. Format.num(chg.cost)
		text(pad, "🔌 " .. chg.name .. "\n+" .. Format.num(chg.rate) .. "⚡/s\n" .. price, Enum.NormalId.Top)
	end

	-- ================= المراحل =================
	local stages = Instance.new("Folder")
	stages.Name = "Stages"
	stages.Parent = world
	for i, def in Config.STAGES do
		local theme = Config.THEMES[(i - 1) % #Config.THEMES + 1]
		local gateZ = -Config.STAGE_GAP_Z * (i - 1) - 20
		local topZ = gateZ - 6
		local bottomZ = topZ - 84
		local sf = Instance.new("Folder")
		sf.Name = "Stage_" .. i
		sf.Parent = stages
		built += 1
		if def.boss then
			sf:SetAttribute("Boss", true)
		end

		local gateRgb = def.boss and { 255, 200, 40 } or theme.accent
		local gate = block(sf, "Gate", Vector3.new(26, 15, 2), Vector3.new(0, 7.5, gateZ), gateRgb)
		gate:SetAttribute("StageGate", i)
		gate:SetAttribute("Need", def.req)
		text(gate, "🔋 LEVEL " .. def.req .. "\n" .. def.name, Enum.NormalId.Back)
		block(sf, "PostL", Vector3.new(3, 19, 3), Vector3.new(-14.5, 9.5, gateZ), gateRgb)
		block(sf, "PostR", Vector3.new(3, 19, 3), Vector3.new(14.5, 9.5, gateZ), gateRgb)

		course(sf, i, def.plan, topZ, bottomZ, theme)

		if def.boss then
			for nCell, spot in { { -6, 22 }, { 6, 47 }, { 0, 70 } } do
				local cell = block(sf, "Cell_" .. nCell, Vector3.new(2.2, 3, 1.2), Vector3.new(spot[1], 1.8, topZ - spot[2]), { 90, 255, 120 }, Enum.Material.Neon)
				cell.CanCollide = false
				cell:SetAttribute("Cell", true)
				text(cell, "🔋", Enum.NormalId.Front, Color3.fromRGB(20, 80, 20))
			end
		end

		local begin = block(sf, "Begin", Vector3.new(16, 0.6, 6), Vector3.new(0, 0.3, topZ - 3), { 120, 255, 140 }, Enum.Material.Neon)
		begin:SetAttribute("Begin", i)
		local finish = block(sf, "Finish", Vector3.new(16, 0.8, 10), Vector3.new(0, 0.4, bottomZ - 5), { 255, 214, 40 }, Enum.Material.Neon)
		finish:SetAttribute("Finish", i)
		text(finish, "🏆 +" .. Format.num(def.wins) .. " WINS", Enum.NormalId.Top, Color3.fromRGB(80, 60, 0))

		local kill = block(sf, "KillFloor", Vector3.new(60, 1, 100), Vector3.new(0, -8, (topZ + bottomZ) / 2), { 255, 70, 40 }, Enum.Material.Neon)
		kill:SetAttribute("Kill", true)

		local nextGateZ = -Config.STAGE_GAP_Z * i - 20
		if i < #Config.STAGES then
			block(sf, "Walkway", Vector3.new(16, 1, (bottomZ - 10) - nextGateZ), Vector3.new(0, 0, (bottomZ - 10 + nextGateZ) / 2), theme.floor)
		else
			local fin = block(sf, "EndPlatform", Vector3.new(30, 1, 24), Vector3.new(0, 0, bottomZ - 22), { 255, 215, 0 }, Enum.Material.Neon)
			text(fin, "🏆 YOU ESCAPED THE PHONE! 🏆", Enum.NormalId.Top, Color3.fromRGB(80, 60, 0))
		end
	end

	local voidKill = block(world, "VoidKill", Vector3.new(500, 1, 500), Vector3.new(0, -12, -Config.STAGE_GAP_Z * #Config.STAGES / 2), { 255, 70, 40 }, Enum.Material.Neon)
	voidKill.Transparency = 0.6
	voidKill:SetAttribute("Kill", true)

	-- استبدال آمن: الخريطة القديمة تُحذف فقط بعد اكتمال الجديدة
	local old = workspace:FindFirstChild("PhoneWorld")
	if old then
		old:Destroy()
	end
	world.Name = "PhoneWorld"
	world.Parent = workspace

	print(("[Phone] world ready: %d icons, %d stages"):format(icons, built))
	return { levelLabels = levelLabels, winsLabels = winsLabels }
end

return Builder
