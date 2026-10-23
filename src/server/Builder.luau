-- Builder.luau — يبني عالم اللعبة كاملًا من الكود عند بدء السيرفر.
-- التصميم v3 «مدينة الدوائر»: أنت صغير داخل هاتف — لوحة أمّ ليلية عملاقة:
-- ساحة معالج مركزية، شوارع مضيئة بعقد شحن، أبراج شرائح تصعدها للهروب.
-- البناء في مجلد مؤقت ثم استبدال دفعة واحدة (فشل البناء لا يدمر المخبوز).
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
		tl.TextColor3 = Color3.fromRGB(120, 255, 220)
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

-- ===== مسار صاعد داخل برج =====
local RISES = { run = 2, gap = 1.2, moving = 2, movingy = 2, vanish = 2, convF = 2, convB = 2, bounce = 2, sweep = 2, narrow = 2, tower = 8.4, split = 2, mid = 0 }

local function towerCourse(parent, stageIdx, plan, cx, theme, isBoss)
	local z = -115
	local y = 3.6 -- سطح المنصة الحالية
	local segments = {}
	local starN = 0
	local prevRise, prevKind = 0, nil
	local function pillar(topY, midZ)
		local h = topY - 2
		if h > 0.5 then
			block(parent, "Pillar", Vector3.new(5, h, 5), Vector3.new(cx, 1 + h / 2, midZ), { 40, 44, 58 })
		end
	end
	local function starAt(x, topY, zz)
		starN += 1
		local s = block(parent, "Star" .. starN, Vector3.new(1.7, 1.7, 1.7), Vector3.new(x, topY + 1.6, zz), { 255, 215, 0 }, Enum.Material.Neon)
		s.Shape = Enum.PartType.Ball
		s:SetAttribute("Star", true)
		s:SetAttribute("StarOf", stageIdx)
	end
	for _, token in plan do
		local kind, arg = string.match(token, "^(%a+):?(%d*)$")
		local len = math.floor((tonumber(arg) or 0) * 0.85)
		if kind == "mid" then
			block(parent, "MidBase", Vector3.new(14, 1, 8), Vector3.new(cx, y - 0.5, z - 4), theme.floor)
			local p = block(parent, "MidPad", Vector3.new(12, 0.6, 6), Vector3.new(cx, y + 0.3, z - 4), { 120, 255, 140 }, Enum.Material.Neon)
			p:SetAttribute("Mid", stageIdx)
			table.insert(segments, { midZ = z - 4, topY = y })
			z -= 8
			prevRise, prevKind = 0, "mid"
		else
			local rise = RISES[kind] or 2
			if #segments > 0 and prevRise >= 1.2 and prevKind ~= "tower" then
				block(parent, "Step", Vector3.new(8, 0.5, 3), Vector3.new(cx, y - prevRise / 2 - 0.25, z + 0.5), theme.floor)
			end
			local mid = z - len / 2
			if kind == "run" then
				block(parent, "Run", Vector3.new(16, 1, len), Vector3.new(cx, y - 0.5, mid), theme.floor)
				pillar(y, mid)
			elseif kind == "gap" then
				-- هواء: اقفز
			elseif kind == "moving" or kind == "movingy" then
				local p = block(parent, "Lift", Vector3.new(11, 1, 10), Vector3.new(cx, y - 0.5, mid), theme.accent)
				p:SetAttribute("Move", true)
				p:SetAttribute("Axis", kind == "movingy" and "Y" or "X")
				p:SetAttribute("Range", kind == "movingy" and 3.2 or 7)
				p:SetAttribute("Speed", 1.1)
				p:SetAttribute("Phase", stageIdx * 1.7 + #segments)
			elseif kind == "vanish" then
				local seg = len / 3
				for k = 1, 3 do
					local p = block(parent, "Blink", Vector3.new(16, 0.8, seg - 1.5), Vector3.new(cx, y - 0.4, z - (k - 0.5) * seg), { 255, 240, 170 }, Enum.Material.Neon)
					p:SetAttribute("Vanish", (k + stageIdx) % 3)
				end
			elseif kind == "convF" or kind == "convB" then
				local p = block(parent, "Belt", Vector3.new(16, 1, len), Vector3.new(cx, y - 0.5, mid), kind == "convF" and { 90, 200, 255 } or { 255, 150, 90 })
				p:SetAttribute("Belt", kind == "convF" and -26 or 18)
				pillar(y, mid)
			elseif kind == "bounce" then
				for _, f in { 0.3, 0.7 } do
					local iz = z - len * f
					block(parent, "Isle", Vector3.new(9, 1, 9), Vector3.new(cx, y - 0.5, iz), theme.floor)
					local p = block(parent, "Pad", Vector3.new(6, 0.6, 6), Vector3.new(cx, y + 0.3, iz), { 255, 90, 200 }, Enum.Material.Neon)
					p:SetAttribute("Bounce", 68)
				end
			elseif kind == "sweep" then
				block(parent, "SweepFloor", Vector3.new(16, 1, len), Vector3.new(cx, y - 0.5, mid), theme.floor)
				block(parent, "SweepPost", Vector3.new(1.2, 3, 1.2), Vector3.new(cx, y + 1.5, mid), { 60, 60, 70 })
				local arm = block(parent, "Spinner", Vector3.new(13, 1.1, 1.1), Vector3.new(cx, y + 1.35, mid), { 235, 70, 60 }, Enum.Material.Neon)
				arm:SetAttribute("Sweep", true)
				arm:SetAttribute("SweepSpeed", 1.1 + stageIdx * 0.04)
				arm:SetAttribute("PivotX", cx)
				arm:SetAttribute("PivotZ", mid)
				pillar(y, mid)
			elseif kind == "narrow" then
				block(parent, "BridgeA", Vector3.new(4.5, 1, len / 2), Vector3.new(cx - 3.5, y - 0.5, z - len / 4), theme.floor)
				block(parent, "BridgeB", Vector3.new(4.5, 1, len / 2), Vector3.new(cx + 3.5, y - 0.5, z - 3 * len / 4), theme.floor)
			elseif kind == "tower" then
				for k = 1, 5 do
					local stepTop = y + (k - 1) * 2.1
					block(parent, "StepT", Vector3.new(9, 1, 9), Vector3.new(cx, stepTop - 0.5, z - (k - 0.5) * (len / 5)), theme.floor)
				end
				pillar(y, mid)
			elseif kind == "split" then
				block(parent, "Safe", Vector3.new(10, 1, len), Vector3.new(cx - 8, y - 0.5, mid), theme.floor)
				block(parent, "Risk", Vector3.new(5, 1, len), Vector3.new(cx + 10.5, y - 0.5, mid), theme.accent)
				for _, f in { 0.25, 0.5, 0.75 } do
					starAt(cx + 10.5, y, z - len * f)
				end
				pillar(y, mid)
			end
			table.insert(segments, { midZ = mid, topY = y })
			z -= len
			y += rise
			prevRise, prevKind = rise, kind
		end
	end
	if isBoss then
		local picks = { math.ceil(#segments * 0.3), math.ceil(#segments * 0.55), math.ceil(#segments * 0.8) }
		for nCell, si in picks do
			local seg = segments[si]
			if seg then
				local cell = block(parent, "Cell_" .. nCell, Vector3.new(2.2, 3, 1.2), Vector3.new(cx + (si % 2 == 0 and -6 or 6), seg.topY + 1.8, seg.midZ), { 90, 255, 120 }, Enum.Material.Neon)
				cell.CanCollide = false
				cell:SetAttribute("Cell", true)
				text(cell, "🔋", Enum.NormalId.Front, Color3.fromRGB(20, 80, 20))
			end
		end
	end
	return y, z
end

function Builder.build()
	-- إضاءة ليلية
	local Lighting = game:GetService("Lighting")
	if not Lighting:FindFirstChild("PhoneBloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "PhoneBloom"
		bloom.Intensity = 0.55
		bloom.Size = 32
		bloom.Threshold = 0.7
		bloom.Parent = Lighting
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "PhoneGrade"
		cc.Saturation = 0.12
		cc.Contrast = 0.08
		cc.Brightness = -0.03
		cc.Parent = Lighting
		local atm = Instance.new("Atmosphere")
		atm.Name = "PhoneAir"
		atm.Density = 0.22
		atm.Color = Color3.fromRGB(140, 170, 230)
		atm.Decay = Color3.fromRGB(40, 60, 120)
		atm.Parent = Lighting
		Lighting.ClockTime = 0.3
	end

	local world = Instance.new("Folder")
	world.Name = "PhoneWorld_Building"
	local nodes = 0

	-- ================= لوحة الأم =================
	local city = Instance.new("Folder")
	city.Name = "City"
	city.Parent = world
	block(city, "Board", Vector3.new(560, 1, 420), Vector3.new(0, -0.7, -20), { 16, 20, 30 })

	-- مسارات الدوائر المضيئة (مربعات + محاور)
	for _, r in { 30, 55, 80 } do
		block(city, "TraceN", Vector3.new(2 * r, 0.12, 1), Vector3.new(0, 0.03, 40 - r), { 40, 220, 200 }, Enum.Material.Neon)
		block(city, "TraceS", Vector3.new(2 * r, 0.12, 1), Vector3.new(0, 0.03, 40 + r), { 40, 220, 200 }, Enum.Material.Neon)
		block(city, "TraceW", Vector3.new(1, 0.12, 2 * r), Vector3.new(-r, 0.03, 40), { 40, 220, 200 }, Enum.Material.Neon)
		block(city, "TraceE", Vector3.new(1, 0.12, 2 * r), Vector3.new(r, 0.03, 40), { 40, 220, 200 }, Enum.Material.Neon)
	end
	block(city, "TraceAxisZ", Vector3.new(1, 0.12, 270), Vector3.new(0, 0.03, 35), { 40, 220, 200 }, Enum.Material.Neon)
	block(city, "TraceAxisX", Vector3.new(270, 0.12, 1), Vector3.new(0, 0.03, 40), { 40, 220, 200 }, Enum.Material.Neon)

	-- عقد الشحن في الشوارع
	local nodePalette = { { 60, 230, 255 }, { 255, 110, 220 }, { 120, 255, 140 }, { 255, 200, 80 } }
	local function node(x, zz, tall)
		nodes += 1
		local rgb = nodePalette[(nodes % #nodePalette) + 1]
		local yy = tall and 0.55 or 0.12
		local pad = block(city, "Node_" .. nodes, Vector3.new(0.7, 4.6, 4.6), Vector3.new(x, yy, zz), rgb, Enum.Material.Neon)
		pad.Shape = Enum.PartType.Cylinder
		pad.Orientation = Vector3.new(0, 0, 90)
		pad:SetAttribute("Icon", true)
		local core = block(city, "Core_" .. nodes, Vector3.new(0.5, 2.3, 2.3), Vector3.new(x, yy + 0.45, zz), mix(rgb, { 255, 255, 255 }, 0.35), Enum.Material.Neon)
		core.Shape = Enum.PartType.Cylinder
		core.Orientation = Vector3.new(0, 0, 90)
	end
	for _, ring in { { 30, 20 }, { 55, 32 }, { 80, 44 } } do
		local r, count = ring[1], ring[2]
		for k = 0, count - 1 do
			local a = (k / count) * math.pi * 2
			node(math.cos(a) * r, 40 + math.sin(a) * r, false)
		end
	end
	for dir = 0, 7 do
		local a = dir * math.pi / 4
		for step = 1, 5 do
			local r = 85 + step * 10
			local x, zz = math.cos(a) * r, 40 + math.sin(a) * r
			node(x, zz, zz > 128)
		end
	end

	-- ================= ساحة المعالج =================
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = world
	block(plaza, "CpuBase", Vector3.new(36, 3, 36), Vector3.new(0, 1.3, 40), { 24, 26, 36 })
	block(plaza, "CpuTop", Vector3.new(30, 0.5, 30), Vector3.new(0, 3.05, 40), { 45, 50, 66 })
	local cpuCore = block(plaza, "CpuCore", Vector3.new(18, 0.7, 18), Vector3.new(0, 3.6, 40), { 60, 230, 255 }, Enum.Material.Neon)
	text(cpuCore, "⚡ CPU ⚡", Enum.NormalId.Top, Color3.fromRGB(10, 40, 50))
	block(plaza, "PinN", Vector3.new(36.5, 0.7, 2), Vector3.new(0, 2.6, 57.2), { 255, 200, 60 }, Enum.Material.Neon)
	block(plaza, "PinS", Vector3.new(36.5, 0.7, 2), Vector3.new(0, 2.6, 22.8), { 255, 200, 60 }, Enum.Material.Neon)
	block(plaza, "PinW", Vector3.new(2, 0.7, 36.5), Vector3.new(-17.2, 2.6, 40), { 255, 200, 60 }, Enum.Material.Neon)
	block(plaza, "PinE", Vector3.new(2, 0.7, 36.5), Vector3.new(17.2, 2.6, 40), { 255, 200, 60 }, Enum.Material.Neon)

	block(plaza, "BannerPostL", Vector3.new(1, 12, 1), Vector3.new(-16, 6, 66), { 60, 60, 75 })
	block(plaza, "BannerPostR", Vector3.new(1, 12, 1), Vector3.new(16, 6, 66), { 60, 60, 75 })
	local banner = block(plaza, "Banner", Vector3.new(36, 7, 1), Vector3.new(0, 10.5, 66), { 20, 24, 38 })
	text(banner, "⚡ CHARGE CITY ⚡", Enum.NormalId.Front, Color3.fromRGB(120, 255, 220))

	block(plaza, "SpawnDeck", Vector3.new(18, 0.3, 18), Vector3.new(0, 0.05, 84), { 210, 215, 225 })
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.7, 84)
	spawn.Anchored = true
	spawn.Color = Color3.fromRGB(240, 240, 250)
	spawn.Neutral = true
	spawn.Transparency = 0.4
	spawn.Parent = plaza

	local function guide(x, zz, txt, rgb)
		block(plaza, "SignPost", Vector3.new(0.5, 5, 0.5), Vector3.new(x, 2.5, zz), { 90, 90, 100 })
		local s = block(plaza, "Sign", Vector3.new(21, 4, 0.6), Vector3.new(x, 5.6, zz), rgb)
		text(s, txt, Enum.NormalId.Front)
	end
	guide(-34, 64, "🏃 RUN THE STREETS = +⚡", { 40, 140, 90 })
	guide(34, 64, "🔌 CHARGERS ▼ SOUTH", { 50, 100, 200 })
	guide(0, 108, "🗼 TOWERS ▲ NORTH", { 170, 70, 170 })

	-- لوحتا الصدارة
	block(plaza, "BoardPostL", Vector3.new(0.6, 6, 0.6), Vector3.new(-27, 3, 88), { 70, 70, 85 })
	block(plaza, "BoardPostR", Vector3.new(0.6, 6, 0.6), Vector3.new(27, 3, 88), { 70, 70, 85 })
	local bl = block(plaza, "BoardTopLevel", Vector3.new(19, 12, 1), Vector3.new(-27, 9, 88), { 40, 30, 70 })
	local levelLabels = boardText(bl, "🏆 TOP LEVEL 🏆")
	local bw = block(plaza, "BoardTopWins", Vector3.new(19, 12, 1), Vector3.new(27, 9, 88), { 40, 30, 70 })
	local winsLabels = boardText(bw, "🏆 TOP WINS 🏆")

	-- كشك الأدوات
	block(plaza, "StallBase", Vector3.new(24, 1, 20), Vector3.new(-56, 0.9, 96), { 60, 44, 92 })
	local stall = block(plaza, "Stall", Vector3.new(18, 8, 12), Vector3.new(-56, 5.4, 98), { 120, 90, 180 })
	block(plaza, "StallRoof", Vector3.new(21, 1, 15), Vector3.new(-56, 9.8, 98), { 44, 32, 80 })
	text(stall, "🛍️ ITEMS", Enum.NormalId.Front)

	-- مباني المدينة (رامات وشرائح ومكثفات)
	local buildings = Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = world
	local angles = { 0, 35, 55, 145, 180, 215, 260, 325 }
	for bi, deg in angles do
		local a = math.rad(deg)
		local r = deg == 55 and 90 or 118
		local bx, bz = math.cos(a) * r, 40 + math.sin(a) * r
		local kind = (bi - 1) % 3
		if kind == 0 then -- رامة
			block(buildings, "Ram", Vector3.new(12, 26, 4), Vector3.new(bx, 13, bz), { 28, 88, 48 })
			block(buildings, "RamTeeth", Vector3.new(12.4, 2.5, 4.4), Vector3.new(bx, 1.2, bz), { 255, 200, 60 }, Enum.Material.Neon)
			block(buildings, "RamTop", Vector3.new(12.2, 0.8, 4.2), Vector3.new(bx, 25.5, bz), { 60, 230, 160 }, Enum.Material.Neon)
		elseif kind == 1 then -- برج شريحة
			block(buildings, "ChipTower", Vector3.new(18, 30, 18), Vector3.new(bx, 15, bz), { 26, 28, 40 })
			for w = 1, 3 do
				block(buildings, "WinStrip", Vector3.new(14, 1, 0.4), Vector3.new(bx, 6 + w * 7, bz + 9.2), { 90, 200, 255 }, Enum.Material.Neon)
			end
			block(buildings, "ChipTop", Vector3.new(8, 1, 8), Vector3.new(bx, 30.5, bz), { 255, 110, 220 }, Enum.Material.Neon)
		else -- مكثف
			local body = block(buildings, "Capacitor", Vector3.new(15, 8.5, 8.5), Vector3.new(bx, 7.5, bz), { 120, 140, 170 })
			body.Shape = Enum.PartType.Cylinder
			body.Orientation = Vector3.new(0, 0, 90)
			local band = block(buildings, "CapBand", Vector3.new(2, 8.7, 8.7), Vector3.new(bx, 11, bz), { 40, 44, 60 })
			band.Shape = Enum.PartType.Cylinder
			band.Orientation = Vector3.new(0, 0, 90)
			local cap = block(buildings, "CapTop", Vector3.new(1, 9.5, 9.5), Vector3.new(bx, 15.4, bz), { 90, 200, 255 }, Enum.Material.Neon)
			cap.Shape = Enum.PartType.Cylinder
			cap.Orientation = Vector3.new(0, 0, 90)
		end
	end

	-- جزيرة المنطقة الاجتماعية (قريبًا)
	block(world, "IslandBase", Vector3.new(38, 2, 38), Vector3.new(170, 55, -60), { 30, 30, 46 })
	local ring = block(world, "PortalRing", Vector3.new(1.2, 17, 17), Vector3.new(170, 59, -60), { 255, 110, 220 }, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.Orientation = Vector3.new(90, 0, 0)
	local orb = block(world, "Orb", Vector3.new(4, 4, 4), Vector3.new(170, 59, -60), { 255, 200, 250 }, Enum.Material.Neon)
	orb.Shape = Enum.PartType.Ball
	local islandSign = block(world, "IslandSign", Vector3.new(26, 5, 1), Vector3.new(170, 63, -42), { 30, 30, 46 })
	text(islandSign, "🌐 SOCIAL DISTRICT — SOON", Enum.NormalId.Front)

	-- ================= حيّ الشحن (جنوب) =================
	local district = Instance.new("Folder")
	district.Name = "ChargingDistrict"
	district.Parent = world
	block(district, "Slab", Vector3.new(176, 0.5, 46), Vector3.new(0, 0.05, 152), { 52, 36, 78 })
	block(district, "ArchPostL", Vector3.new(1, 11, 1), Vector3.new(-30, 5.5, 132), { 70, 60, 95 })
	block(district, "ArchPostR", Vector3.new(1, 11, 1), Vector3.new(30, 5.5, 132), { 70, 60, 95 })
	local arch = block(district, "Arch", Vector3.new(64, 5, 1.5), Vector3.new(0, 11.5, 132), { 70, 50, 110 })
	text(arch, "🔌 CHARGING DISTRICT", Enum.NormalId.Front)
	for i = 1, 8 do
		node(-80 + i * 20 - 10, 138, true)
	end
	local stations = Instance.new("Folder")
	stations.Name = "Stations"
	stations.Parent = district
	for i, chg in Config.CHARGERS do
		local x = -70 + (i - 1) * 20
		local pad = block(stations, "Station_" .. i, Vector3.new(13, 0.25, 13), Vector3.new(x, 0.42, 152),
			i == #Config.CHARGERS and { 255, 200, 40 } or { 90, 230, 255 }, Enum.Material.Neon)
		pad:SetAttribute("Station", i)
		block(stations, "Pylon_" .. i, Vector3.new(3, 15, 3), Vector3.new(x, 7.5, 161), { 38, 40, 56 })
		local capBall = block(stations, "PylonCap_" .. i, Vector3.new(2.6, 2.6, 2.6), Vector3.new(x, 15.8, 161), { 90, 230, 255 }, Enum.Material.Neon)
		capBall.Shape = Enum.PartType.Ball
		local price = chg.cost == 0 and "FREE" or "🏆 " .. Format.num(chg.cost)
		local pylonFace = block(stations, "PylonFace_" .. i, Vector3.new(6, 9, 0.4), Vector3.new(x, 8, 159.2), { 24, 26, 38 })
		text(pylonFace, "🔌 " .. chg.name .. "\n+" .. Format.num(chg.rate) .. "⚡/s\n" .. price, Enum.NormalId.Front)
	end

	-- ================= أبراج المراحل (شمال) =================
	local stages = Instance.new("Folder")
	stages.Name = "Stages"
	stages.Parent = world
	local built = 0
	for i, def in Config.STAGES do
		built += 1
		local theme = Config.THEMES[(i - 1) % #Config.THEMES + 1]
		local cx = (i - 8) * 36
		local sf = Instance.new("Folder")
		sf.Name = "Stage_" .. i
		sf.Parent = stages
		if def.boss then
			sf:SetAttribute("Boss", true)
		end
		local shellRgb = def.boss and { 255, 200, 40 } or theme.accent

		block(sf, "Floor", Vector3.new(30, 2, 110), Vector3.new(cx, 0, -157), { 30, 32, 44 })
		local wallL = block(sf, "WallL", Vector3.new(1, 32, 110), Vector3.new(cx - 15, 17, -157), { 140, 180, 220 }, Enum.Material.Glass)
		wallL.Transparency = 0.55
		local wallR = block(sf, "WallR", Vector3.new(1, 32, 110), Vector3.new(cx + 15, 17, -157), { 140, 180, 220 }, Enum.Material.Glass)
		wallR.Transparency = 0.55
		block(sf, "WallBack", Vector3.new(30, 32, 1), Vector3.new(cx, 17, -212), { 26, 28, 40 })
		block(sf, "FrontL", Vector3.new(11, 32, 1), Vector3.new(cx - 9.5, 17, -102), { 26, 28, 40 })
		block(sf, "FrontR", Vector3.new(11, 32, 1), Vector3.new(cx + 9.5, 17, -102), { 26, 28, 40 })
		block(sf, "Lintel", Vector3.new(30, 5, 1), Vector3.new(cx, 29.5, -102), { 26, 28, 40 })
		block(sf, "Roof", Vector3.new(30, 1, 110), Vector3.new(cx, 33.8, -157), { 22, 24, 34 })
		block(sf, "LightStripL", Vector3.new(0.8, 0.3, 98), Vector3.new(cx - 8, 33.2, -157), { 190, 230, 255 }, Enum.Material.Neon)
		block(sf, "LightStripR", Vector3.new(0.8, 0.3, 98), Vector3.new(cx + 8, 33.2, -157), { 190, 230, 255 }, Enum.Material.Neon)
		for _, px in { -15, 15 } do
			for _, pz in { -102, -212 } do
				block(sf, "PillarPost", Vector3.new(2, 34, 2), Vector3.new(cx + px, 17, pz), { 40, 42, 56 })
			end
			block(sf, "Trim", Vector3.new(0.7, 32, 0.7), Vector3.new(cx + px, 17, -101.4), shellRgb, Enum.Material.Neon)
		end
		block(sf, "TrimTop", Vector3.new(30.5, 0.7, 0.7), Vector3.new(cx, 33.2, -101.4), shellRgb, Enum.Material.Neon)
		local header = block(sf, "Header", Vector3.new(30, 5, 2), Vector3.new(cx, 26, -101), shellRgb)
		text(header, "🗼 " .. def.name, Enum.NormalId.Front)

		local kill = block(sf, "KillFloor", Vector3.new(28, 0.5, 106), Vector3.new(cx, 1.25, -157), { 255, 70, 40 }, Enum.Material.Neon)
		kill:SetAttribute("Kill", true)

		-- منصة البداية + وسادة الدخول + لافتة البوابة
		block(sf, "Dais", Vector3.new(16, 3, 10), Vector3.new(cx, 1.5, -109), theme.floor)
		local begin = block(sf, "Begin", Vector3.new(16, 0.6, 6), Vector3.new(cx, 3.3, -109), { 120, 255, 140 }, Enum.Material.Neon)
		begin:SetAttribute("Begin", i)
		local enter = block(sf, "EnterPad", Vector3.new(12, 0.5, 8), Vector3.new(cx, 0.3, -95), { 120, 255, 140 }, Enum.Material.Neon)
		enter:SetAttribute("Enter", i)
		text(enter, "▶ ENTER", Enum.NormalId.Top, Color3.fromRGB(15, 60, 20))
		block(sf, "GatePostL", Vector3.new(0.5, 9, 0.5), Vector3.new(cx - 7, 4.5, -99), { 70, 70, 85 })
		block(sf, "GatePostR", Vector3.new(0.5, 9, 0.5), Vector3.new(cx + 7, 4.5, -99), { 70, 70, 85 })
		local gate = block(sf, "Gate", Vector3.new(17, 7, 0.8), Vector3.new(cx, 6, -99), shellRgb)
		gate:SetAttribute("Need", def.req)
		text(gate, "🔋 LEVEL " .. def.req .. "\n" .. def.name, Enum.NormalId.Front)

		local topY, endZ = towerCourse(sf, i, def.plan, cx, theme, def.boss)
		block(sf, "FinishDeck", Vector3.new(20, 1, 10), Vector3.new(cx, topY - 0.5, endZ - 5), theme.floor)
		local finish = block(sf, "Finish", Vector3.new(16, 0.8, 8), Vector3.new(cx, topY + 0.4, endZ - 5), { 255, 214, 40 }, Enum.Material.Neon)
		finish:SetAttribute("Finish", i)
		text(finish, "🏆 +" .. Format.num(def.wins) .. " WINS", Enum.NormalId.Top, Color3.fromRGB(80, 60, 0))
		local finSign = block(sf, "FinishSign", Vector3.new(14, 3.5, 0.6), Vector3.new(cx, topY + 4.2, endZ - 9.5), { 30, 32, 44 })
		text(finSign, "🏁 TOP!", Enum.NormalId.Front, Color3.fromRGB(255, 230, 120))
	end

	local voidKill = block(world, "VoidKill", Vector3.new(620, 1, 600), Vector3.new(0, -10, -20), { 255, 70, 40 }, Enum.Material.Neon)
	voidKill.Transparency = 0.6
	voidKill:SetAttribute("Kill", true)

	-- استبدال آمن
	local old = workspace:FindFirstChild("PhoneWorld")
	if old then
		old:Destroy()
	end
	world.Name = "PhoneWorld"
	world.Parent = workspace

	print(("[Phone] world ready: %d nodes, %d towers"):format(nodes, built))
	return { levelLabels = levelLabels, winsLabels = winsLabels }
end

return Builder
