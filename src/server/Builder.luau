-- Builder.luau — يبني عالم اللعبة كاملًا من الكود عند بدء السيرفر.
-- التصميم v4 «مدينة الأزرار»: عالم نهاري مشرق مريح للعين (مثل خرائط
-- الكيبورد) — الأرض سجادة أزرار ملوّنة بأيقونات: كل خطوة على زر = +1.
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
		tl.TextColor3 = Color3.fromRGB(255, 236, 170)
		tl.Text = title
		tl.Parent = gui
		table.insert(labels, tl)
	end
	return labels
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
			block(parent, "Pillar", Vector3.new(5, h, 5), Vector3.new(cx, 1 + h / 2, midZ), { 150, 158, 175 })
		end
	end
	local function starAt(x, topY, zz)
		starN += 1
		local s = block(parent, "Star" .. starN, Vector3.new(1.7, 1.7, 1.7), Vector3.new(x, topY + 1.6, zz), { 255, 200, 60 }, Enum.Material.Neon)
		s.Shape = Enum.PartType.Ball
		s:SetAttribute("Star", true)
		s:SetAttribute("StarOf", stageIdx)
	end
	for _, token in plan do
		local kind, arg = string.match(token, "^(%a+):?(%d*)$")
		local len = math.floor((tonumber(arg) or 0) * 0.85)
		if kind == "mid" then
			block(parent, "MidBase", Vector3.new(14, 1, 8), Vector3.new(cx, y - 0.5, z - 4), theme.floor)
			local p = block(parent, "MidPad", Vector3.new(12, 0.6, 6), Vector3.new(cx, y + 0.3, z - 4), { 110, 235, 130 })
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
					local p = block(parent, "Blink", Vector3.new(16, 0.8, seg - 1.5), Vector3.new(cx, y - 0.4, z - (k - 0.5) * seg), { 250, 235, 160 })
					p:SetAttribute("Vanish", (k + stageIdx) % 3)
				end
			elseif kind == "convF" or kind == "convB" then
				local p = block(parent, "Belt", Vector3.new(16, 1, len), Vector3.new(cx, y - 0.5, mid), kind == "convF" and { 120, 195, 245 } or { 250, 165, 105 })
				p:SetAttribute("Belt", kind == "convF" and -26 or 18)
				pillar(y, mid)
			elseif kind == "bounce" then
				for _, f in { 0.3, 0.7 } do
					local iz = z - len * f
					block(parent, "Isle", Vector3.new(9, 1, 9), Vector3.new(cx, y - 0.5, iz), theme.floor)
					local p = block(parent, "Pad", Vector3.new(6, 0.6, 6), Vector3.new(cx, y + 0.3, iz), { 250, 120, 195 })
					p:SetAttribute("Bounce", 68)
				end
			elseif kind == "sweep" then
				block(parent, "SweepFloor", Vector3.new(16, 1, len), Vector3.new(cx, y - 0.5, mid), theme.floor)
				block(parent, "SweepPost", Vector3.new(1.2, 3, 1.2), Vector3.new(cx, y + 1.5, mid), { 130, 138, 155 })
				local arm = block(parent, "Spinner", Vector3.new(13, 1.1, 1.1), Vector3.new(cx, y + 1.35, mid), { 240, 90, 80 })
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
				local cell = block(parent, "Cell_" .. nCell, Vector3.new(2.2, 3, 1.2), Vector3.new(cx + (si % 2 == 0 and -6 or 6), seg.topY + 1.8, seg.midZ), { 110, 230, 130 })
				cell.CanCollide = false
				cell:SetAttribute("Cell", true)
				text(cell, "🔋", Enum.NormalId.Front, Color3.fromRGB(20, 80, 20))
			end
		end
	end
	return y, z
end

function Builder.build()
	-- إضاءة نهارية مشرقة مريحة (بلا نيون يعمي العين)
	local Lighting = game:GetService("Lighting")
	local function getOr(class, name)
		local f = Lighting:FindFirstChild(name)
		if not f then
			f = Instance.new(class)
			f.Name = name
			f.Parent = Lighting
		end
		return f
	end
	local bloom = getOr("BloomEffect", "PhoneBloom")
	bloom.Intensity = 0.22
	bloom.Size = 24
	bloom.Threshold = 0.92
	local cc = getOr("ColorCorrectionEffect", "PhoneGrade")
	cc.Saturation = 0.06
	cc.Contrast = 0.02
	cc.Brightness = 0.02
	local atm = getOr("Atmosphere", "PhoneAir")
	atm.Density = 0.12
	atm.Color = Color3.fromRGB(205, 226, 255)
	atm.Decay = Color3.fromRGB(150, 180, 225)
	atm.Haze = 1
	Lighting.ClockTime = 14
	Lighting.Ambient = Color3.fromRGB(150, 156, 172)
	Lighting.OutdoorAmbient = Color3.fromRGB(178, 188, 205)

	local world = Instance.new("Folder")
	world.Name = "PhoneWorld_Building"
	local nodes = 0

	-- ================= الأرض + سجادة الأزرار =================
	local city = Instance.new("Folder")
	city.Name = "City"
	city.Parent = world
	block(city, "Board", Vector3.new(560, 1, 420), Vector3.new(0, -0.7, -20), { 198, 212, 228 })

	-- زر دائري باستيل + غطاء أبيض كأزرار الكيبورد + أيقونة فوقه.
	-- كل زر يحمل Icon: الدوس على زر جديد = +1 (منطق الخطو في Play).
	local palette = {
		{ 168, 230, 190 }, { 165, 205, 245 }, { 250, 205, 160 }, { 245, 180, 205 },
		{ 205, 190, 240 }, { 245, 230, 160 }, { 160, 225, 225 }, { 245, 175, 165 },
	}
	local glyphs = { "⚡", "🔋", "📶", "⭐", "➕" }
	local function button(parent, x, zz, baseY)
		nodes += 1
		local rgb = palette[((nodes * 7) % #palette) + 1]
		local pad = block(parent, "Btn_" .. nodes, Vector3.new(0.9, 5.2, 5.2), Vector3.new(x, baseY + 0.45, zz), rgb)
		pad.Shape = Enum.PartType.Cylinder
		pad.Orientation = Vector3.new(0, 0, 90)
		pad:SetAttribute("Icon", true)
		local cap = block(parent, "Cap_" .. nodes, Vector3.new(3.6, 0.18, 3.6), Vector3.new(x, baseY + 0.99, zz), { 246, 249, 252 })
		text(cap, glyphs[(nodes % #glyphs) + 1], Enum.NormalId.Top, Color3.fromRGB(52, 62, 84))
		return pad
	end

	local function inRect(x, z, x1, z1, x2, z2)
		return x >= x1 and x <= x2 and z >= z1 and z <= z2
	end
	for gx = -19, 19 do
		for gz = 0, 36 do
			local x = gx * 6
			local z = -92 + gz * 6
			if inRect(x, z, -22, 18, 22, 62) then
				-- ساحة المعالج
			elseif inRect(x, z, -11, 73, 11, 95) then
				-- منصة البداية
			elseif inRect(x, z, -69, 85, -43, 109) then
				-- كشك الأدوات
			else
				local blocked = false
				if z == -92 then
					for i = 1, 15 do
						if math.abs(x - (i - 8) * 36) <= 9 then
							blocked = true -- وسادات دخول الأبراج
							break
						end
					end
				end
				if not blocked then
					button(city, x, z, -0.2)
				end
			end
		end
	end

	-- ================= ساحة المعالج =================
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = world
	block(plaza, "CpuBase", Vector3.new(36, 3, 36), Vector3.new(0, 1.3, 40), { 200, 208, 220 })
	block(plaza, "CpuTop", Vector3.new(30, 0.5, 30), Vector3.new(0, 3.05, 40), { 228, 234, 244 })
	local cpuCore = block(plaza, "CpuCore", Vector3.new(18, 0.7, 18), Vector3.new(0, 3.6, 40), { 120, 190, 240 })
	text(cpuCore, "⚡ CPU ⚡", Enum.NormalId.Top, Color3.fromRGB(15, 50, 70))
	block(plaza, "PinN", Vector3.new(36.5, 0.7, 2), Vector3.new(0, 2.6, 57.2), { 245, 205, 95 })
	block(plaza, "PinS", Vector3.new(36.5, 0.7, 2), Vector3.new(0, 2.6, 22.8), { 245, 205, 95 })
	block(plaza, "PinW", Vector3.new(2, 0.7, 36.5), Vector3.new(-17.2, 2.6, 40), { 245, 205, 95 })
	block(plaza, "PinE", Vector3.new(2, 0.7, 36.5), Vector3.new(17.2, 2.6, 40), { 245, 205, 95 })

	block(plaza, "BannerPostL", Vector3.new(1, 12, 1), Vector3.new(-16, 6, 66), { 150, 155, 170 })
	block(plaza, "BannerPostR", Vector3.new(1, 12, 1), Vector3.new(16, 6, 66), { 150, 155, 170 })
	local banner = block(plaza, "Banner", Vector3.new(36, 7, 1), Vector3.new(0, 10.5, 66), { 240, 244, 250 })
	text(banner, "⚡ CHARGE CITY ⚡", Enum.NormalId.Front, Color3.fromRGB(28, 118, 108))

	block(plaza, "SpawnDeck", Vector3.new(18, 0.3, 18), Vector3.new(0, 0.05, 84), { 215, 222, 235 })
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.7, 84)
	spawn.Anchored = true
	spawn.Color = Color3.fromRGB(245, 246, 250)
	spawn.Neutral = true
	spawn.Transparency = 0.4
	spawn.Parent = plaza

	-- لافتة رقم النسخة عند نقطة البداية (تشخيص فوري لأي ملف قديم)
	block(plaza, "VersionPostL", Vector3.new(0.5, 5, 0.5), Vector3.new(-6, 2.5, 93), { 150, 155, 170 })
	block(plaza, "VersionPostR", Vector3.new(0.5, 5, 0.5), Vector3.new(6, 2.5, 93), { 150, 155, 170 })
	local vsign = block(plaza, "VersionSign", Vector3.new(15, 3.5, 0.6), Vector3.new(0, 5.4, 93), { 46, 160, 90 })
	text(vsign, "✅ BUILD v" .. Config.VERSION, Enum.NormalId.Front, Color3.fromRGB(240, 255, 240))

	local function guide(x, zz, txt, rgb)
		block(plaza, "SignPost", Vector3.new(0.5, 5, 0.5), Vector3.new(x, 2.5, zz), { 150, 155, 170 })
		local s = block(plaza, "Sign", Vector3.new(21, 4, 0.6), Vector3.new(x, 5.6, zz), rgb)
		text(s, txt, Enum.NormalId.Front)
	end
	guide(-34, 64, "🏃 EVERY STEP = +⚡", { 86, 184, 128 })
	guide(34, 64, "🔌 CHARGERS ▼ SOUTH", { 96, 150, 222 })
	guide(0, 108, "🗼 TOWERS ▲ NORTH", { 186, 120, 196 })

	-- لوحتا الصدارة
	block(plaza, "BoardPostL", Vector3.new(0.6, 6, 0.6), Vector3.new(-27, 3, 88), { 120, 124, 140 })
	block(plaza, "BoardPostR", Vector3.new(0.6, 6, 0.6), Vector3.new(27, 3, 88), { 120, 124, 140 })
	local bl = block(plaza, "BoardTopLevel", Vector3.new(19, 12, 1), Vector3.new(-27, 9, 88), { 58, 50, 96 })
	local levelLabels = boardText(bl, "🏆 TOP LEVEL 🏆")
	local bw = block(plaza, "BoardTopWins", Vector3.new(19, 12, 1), Vector3.new(27, 9, 88), { 58, 50, 96 })
	local winsLabels = boardText(bw, "🏆 TOP WINS 🏆")

	-- كشك الأدوات
	block(plaza, "StallBase", Vector3.new(24, 1, 20), Vector3.new(-56, 0.9, 96), { 196, 186, 222 })
	local stall = block(plaza, "Stall", Vector3.new(18, 8, 12), Vector3.new(-56, 5.4, 98), { 168, 148, 216 })
	block(plaza, "StallRoof", Vector3.new(21, 1, 15), Vector3.new(-56, 9.8, 98), { 120, 100, 178 })
	text(stall, "🛍️ ITEMS", Enum.NormalId.Front)

	-- مباني المدينة (رامات وشرائح ومكثفات) — ألوان فاتحة
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
			block(buildings, "Ram", Vector3.new(12, 26, 4), Vector3.new(bx, 13, bz), { 146, 204, 158 })
			block(buildings, "RamTeeth", Vector3.new(12.4, 2.5, 4.4), Vector3.new(bx, 1.2, bz), { 246, 205, 95 })
			block(buildings, "RamTop", Vector3.new(12.2, 0.8, 4.2), Vector3.new(bx, 25.5, bz), { 110, 214, 170 })
		elseif kind == 1 then -- برج شريحة
			block(buildings, "ChipTower", Vector3.new(18, 30, 18), Vector3.new(bx, 15, bz), { 172, 188, 208 })
			for w = 1, 3 do
				block(buildings, "WinStrip", Vector3.new(14, 1, 0.4), Vector3.new(bx, 6 + w * 7, bz + 9.2), { 150, 205, 245 })
			end
			block(buildings, "ChipTop", Vector3.new(8, 1, 8), Vector3.new(bx, 30.5, bz), { 246, 170, 205 })
		else -- مكثف
			local body = block(buildings, "Capacitor", Vector3.new(15, 8.5, 8.5), Vector3.new(bx, 7.5, bz), { 186, 198, 214 })
			body.Shape = Enum.PartType.Cylinder
			body.Orientation = Vector3.new(0, 0, 90)
			local band = block(buildings, "CapBand", Vector3.new(2, 8.7, 8.7), Vector3.new(bx, 11, bz), { 110, 122, 142 })
			band.Shape = Enum.PartType.Cylinder
			band.Orientation = Vector3.new(0, 0, 90)
			local cap = block(buildings, "CapTop", Vector3.new(1, 9.5, 9.5), Vector3.new(bx, 15.4, bz), { 150, 205, 245 })
			cap.Shape = Enum.PartType.Cylinder
			cap.Orientation = Vector3.new(0, 0, 90)
		end
	end

	-- جزيرة المنطقة الاجتماعية (قريبًا)
	block(world, "IslandBase", Vector3.new(38, 2, 38), Vector3.new(170, 55, -60), { 196, 204, 220 })
	local ring = block(world, "PortalRing", Vector3.new(1.2, 17, 17), Vector3.new(170, 59, -60), { 246, 170, 205 })
	ring.Shape = Enum.PartType.Cylinder
	ring.Orientation = Vector3.new(90, 0, 0)
	local orb = block(world, "Orb", Vector3.new(4, 4, 4), Vector3.new(170, 59, -60), { 250, 215, 245 })
	orb.Shape = Enum.PartType.Ball
	local islandSign = block(world, "IslandSign", Vector3.new(26, 5, 1), Vector3.new(170, 63, -42), { 58, 60, 84 })
	text(islandSign, "🌐 SOCIAL DISTRICT — SOON", Enum.NormalId.Front)

	-- ================= حيّ الشحن (جنوب) =================
	local district = Instance.new("Folder")
	district.Name = "ChargingDistrict"
	district.Parent = world
	block(district, "Slab", Vector3.new(176, 0.5, 46), Vector3.new(0, 0.05, 152), { 198, 190, 218 })
	block(district, "ArchPostL", Vector3.new(1, 11, 1), Vector3.new(-30, 5.5, 132), { 140, 128, 175 })
	block(district, "ArchPostR", Vector3.new(1, 11, 1), Vector3.new(30, 5.5, 132), { 140, 128, 175 })
	local arch = block(district, "Arch", Vector3.new(64, 5, 1.5), Vector3.new(0, 11.5, 132), { 128, 108, 178 })
	text(arch, "🔌 CHARGING DISTRICT", Enum.NormalId.Front)
	for i = 1, 8 do
		button(district, -80 + i * 20 - 10, 138, 0.3)
	end
	local stations = Instance.new("Folder")
	stations.Name = "Stations"
	stations.Parent = district
	for i, chg in Config.CHARGERS do
		local x = -70 + (i - 1) * 20
		local pad = block(stations, "Station_" .. i, Vector3.new(13, 0.25, 13), Vector3.new(x, 0.42, 152),
			i == #Config.CHARGERS and { 250, 205, 80 } or { 140, 205, 245 })
		pad:SetAttribute("Station", i)
		block(stations, "Pylon_" .. i, Vector3.new(3, 15, 3), Vector3.new(x, 7.5, 161), { 198, 206, 218 })
		local capBall = block(stations, "PylonCap_" .. i, Vector3.new(2.6, 2.6, 2.6), Vector3.new(x, 15.8, 161), { 140, 205, 245 })
		capBall.Shape = Enum.PartType.Ball
		local price = chg.cost == 0 and "FREE" or "🏆 " .. Format.num(chg.cost)
		local pylonFace = block(stations, "PylonFace_" .. i, Vector3.new(6, 9, 0.4), Vector3.new(x, 8, 159.2), { 44, 48, 64 })
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
		local shellRgb = def.boss and { 250, 205, 80 } or theme.accent

		block(sf, "Floor", Vector3.new(30, 2, 110), Vector3.new(cx, 0, -157), { 208, 202, 192 })
		local wallL = block(sf, "WallL", Vector3.new(1, 32, 110), Vector3.new(cx - 15, 17, -157), { 160, 195, 225 }, Enum.Material.Glass)
		wallL.Transparency = 0.55
		local wallR = block(sf, "WallR", Vector3.new(1, 32, 110), Vector3.new(cx + 15, 17, -157), { 160, 195, 225 }, Enum.Material.Glass)
		wallR.Transparency = 0.55
		block(sf, "WallBack", Vector3.new(30, 32, 1), Vector3.new(cx, 17, -212), { 122, 134, 154 })
		block(sf, "FrontL", Vector3.new(11, 32, 1), Vector3.new(cx - 9.5, 17, -102), { 122, 134, 154 })
		block(sf, "FrontR", Vector3.new(11, 32, 1), Vector3.new(cx + 9.5, 17, -102), { 122, 134, 154 })
		block(sf, "Lintel", Vector3.new(30, 5, 1), Vector3.new(cx, 29.5, -102), { 122, 134, 154 })
		block(sf, "Roof", Vector3.new(30, 1, 110), Vector3.new(cx, 33.8, -157), { 100, 112, 132 })
		block(sf, "LightStripL", Vector3.new(0.8, 0.3, 98), Vector3.new(cx - 8, 33.2, -157), { 170, 215, 250 })
		block(sf, "LightStripR", Vector3.new(0.8, 0.3, 98), Vector3.new(cx + 8, 33.2, -157), { 170, 215, 250 })
		for _, px in { -15, 15 } do
			for _, pz in { -102, -212 } do
				block(sf, "PillarPost", Vector3.new(2, 34, 2), Vector3.new(cx + px, 17, pz), { 140, 150, 168 })
			end
			block(sf, "Trim", Vector3.new(0.7, 32, 0.7), Vector3.new(cx + px, 17, -101.4), shellRgb)
		end
		block(sf, "TrimTop", Vector3.new(30.5, 0.7, 0.7), Vector3.new(cx, 33.2, -101.4), shellRgb)
		local header = block(sf, "Header", Vector3.new(30, 5, 2), Vector3.new(cx, 26, -101), shellRgb)
		text(header, "🗼 " .. def.name, Enum.NormalId.Front)

		-- أرضية القتل مدفونة داخل أرضية البرج: السقوط من المسار لا يقتل
		-- بحد ذاته (تعود مشيًا للبداية)، ولا تلمس من يمشي على الأرضية
		local kill = block(sf, "KillFloor", Vector3.new(28, 0.5, 106), Vector3.new(cx, 0.55, -157), { 240, 90, 70 })
		kill:SetAttribute("Kill", true)

		-- منصة البداية + عتبة دخول مشيًا + وسادة الدخول + لافتة البوابة
		block(sf, "StepIn", Vector3.new(16, 2, 4), Vector3.new(cx, 1, -102), theme.floor)
		block(sf, "Dais", Vector3.new(16, 3, 10), Vector3.new(cx, 1.5, -109), theme.floor)
		local begin = block(sf, "Begin", Vector3.new(16, 0.6, 6), Vector3.new(cx, 3.3, -109), { 110, 235, 130 })
		begin:SetAttribute("Begin", i)
		local enter = block(sf, "EnterPad", Vector3.new(12, 0.5, 8), Vector3.new(cx, 0.3, -95), { 110, 235, 130 })
		enter:SetAttribute("Enter", i)
		text(enter, "▶ ENTER", Enum.NormalId.Top, Color3.fromRGB(15, 60, 20))
		block(sf, "GatePostL", Vector3.new(0.5, 9, 0.5), Vector3.new(cx - 7, 4.5, -99), { 140, 148, 165 })
		block(sf, "GatePostR", Vector3.new(0.5, 9, 0.5), Vector3.new(cx + 7, 4.5, -99), { 140, 148, 165 })
		local gate = block(sf, "Gate", Vector3.new(17, 7, 0.8), Vector3.new(cx, 6, -99), shellRgb)
		gate:SetAttribute("Need", def.req)
		text(gate, "🔋 LEVEL " .. def.req .. "\n" .. def.name, Enum.NormalId.Front)

		local topY, endZ = towerCourse(sf, i, def.plan, cx, theme, def.boss)
		block(sf, "FinishDeck", Vector3.new(20, 1, 10), Vector3.new(cx, topY - 0.5, endZ - 5), theme.floor)
		local finish = block(sf, "Finish", Vector3.new(16, 0.8, 8), Vector3.new(cx, topY + 0.4, endZ - 5), { 250, 210, 70 })
		finish:SetAttribute("Finish", i)
		text(finish, "🏆 +" .. Format.num(def.wins) .. " WINS", Enum.NormalId.Top, Color3.fromRGB(80, 60, 0))
		local finSign = block(sf, "FinishSign", Vector3.new(14, 3.5, 0.6), Vector3.new(cx, topY + 4.2, endZ - 9.5), { 122, 134, 154 })
		text(finSign, "🏁 TOP!", Enum.NormalId.Front, Color3.fromRGB(255, 240, 170))
	end

	local voidKill = block(world, "VoidKill", Vector3.new(620, 1, 600), Vector3.new(0, -10, -20), { 240, 90, 70 })
	voidKill.Transparency = 0.6
	voidKill:SetAttribute("Kill", true)

	-- استبدال آمن
	local old = workspace:FindFirstChild("PhoneWorld")
	if old then
		old:Destroy()
	end
	world.Name = "PhoneWorld"
	world.Parent = workspace

	print(("[Phone] world ready: %d buttons, %d towers"):format(nodes, built))
	return { levelLabels = levelLabels, winsLabels = winsLabels }
end

return Builder
