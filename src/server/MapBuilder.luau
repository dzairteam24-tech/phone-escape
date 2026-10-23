-- MapBuilder v3: clones the screenshot layout of +1 Speed Keyboard Escape.
-- The lobby floor IS a giant keyboard (chocolate keys, pink gradient runway)
-- that runs straight into Stage 1. TOP LEVEL / TOP WINS boards flank the gate.
-- Items Shop stall, event portal, candy decor, charger platform on the side.
-- Then 27 stages (15 in World 1, 12 in Snow World): level gates, courses,
-- kill floors, yellow Wins pads.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NumberFormat = require(Shared.NumberFormat)

local MapBuilder = {}
MapBuilder.boardLevelLabels = {}
MapBuilder.boardWinsLabels = {}

local function part(parent, name, size, pos, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = pos
	p.Anchored = true
	p.Color = Color3.fromRGB(color[1], color[2], color[3])
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function label(partObj, text, face, color)
	local faces = { face or Enum.NormalId.Front }
	if faces[1] ~= Enum.NormalId.Top and faces[1] ~= Enum.NormalId.Bottom then
		table.insert(faces, faces[1] == Enum.NormalId.Front and Enum.NormalId.Back or Enum.NormalId.Front)
	end
	local first
	for _, f in faces do
		local gui = Instance.new("SurfaceGui")
		gui.Face = f
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = partObj
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Text = text
		tl.Font = Enum.Font.FredokaOne
		tl.TextScaled = true
		tl.TextColor3 = color or Color3.new(1, 1, 1)
		tl.TextStrokeTransparency = 0.35
		tl.Parent = gui
		first = first or gui
	end
	return first
end

local function board(partObj, title)
	local labels = {}
	for _, f in { Enum.NormalId.Back, Enum.NormalId.Front } do
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

local function lerpColor(a, b, t)
	return {
		math.floor(a[1] + (b[1] - a[1]) * t + 0.5),
		math.floor(a[2] + (b[2] - a[2]) * t + 0.5),
		math.floor(a[3] + (b[3] - a[3]) * t + 0.5),
	}
end

function MapBuilder.build()
	-- Beauty pass (v4): bloom, warm color grade, soft atmosphere.
	local Lighting = game:GetService("Lighting")
	if not Lighting:FindFirstChild("KB_Bloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "KB_Bloom"
		bloom.Intensity = 0.35
		bloom.Size = 24
		bloom.Threshold = 0.85
		bloom.Parent = Lighting
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "KB_Grade"
		cc.Saturation = 0.14
		cc.Contrast = 0.05
		cc.Brightness = 0.02
		cc.Parent = Lighting
		local rays = Instance.new("SunRaysEffect")
		rays.Name = "KB_Rays"
		rays.Intensity = 0.06
		rays.Parent = Lighting
		local atm = Instance.new("Atmosphere")
		atm.Name = "KB_Atmosphere"
		atm.Density = 0.16
		atm.Color = Color3.fromRGB(215, 230, 255)
		atm.Decay = Color3.fromRGB(255, 200, 220)
		atm.Parent = Lighting
		Lighting.ClockTime = 14.2
	end

	-- Build the fresh map off to the side and swap it in only once it is
	-- complete: if anything below errors, the baked map already in the
	-- place survives instead of being destroyed first.
	local map = Instance.new("Folder")
	map.Name = "PhoneMap_Building"
	local keysBuilt, stagesBuilt = 0, 0

	-- ================= LOBBY =================
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = map
	part(lobby, "UnderSlab", Vector3.new(150, 1, 130), Vector3.new(0, -0.7, 34), { 22, 22, 34 })

	-- The giant home screen: app-icon tiles on dark glass. Every icon
	-- stepped on = +1 Charge and flashes.
	local kb = Instance.new("Folder")
	kb.Name = "HomeScreen"
	kb.Parent = lobby
	local pitch = Config.APP_SIZE + Config.APP_GAP
	local appColors = {
		{ 255, 90, 90 }, { 255, 160, 60 }, { 255, 215, 80 }, { 120, 220, 110 },
		{ 70, 200, 190 }, { 80, 160, 255 }, { 150, 110, 255 }, { 255, 110, 190 },
	}
	for r = 1, Config.APP_ROWS do
		local z = 84 - (r - 1) * pitch
		for c = 1, Config.APP_COLS do
			local x = (c - (Config.APP_COLS + 1) / 2) * pitch
			local gi = ((r - 1) * Config.APP_COLS + (c - 1)) % #Config.APP_GLYPHS + 1
			local color = appColors[((r * 3 + c) % #appColors) + 1]
			local key = part(kb, "App_" .. r .. "_" .. c, Vector3.new(Config.APP_SIZE, 0.8, Config.APP_SIZE), Vector3.new(x, 0.4, z), color)
			key:SetAttribute("IsApp", true)
			keysBuilt += 1
			label(key, Config.APP_GLYPHS[gi], Enum.NormalId.Top, Color3.new(1, 1, 1))
			local plateColor = lerpColor(color, { 255, 255, 255 }, 0.25)
			part(kb, "Plate_" .. r .. "_" .. c, Vector3.new(Config.APP_SIZE - 1.3, 0.22, Config.APP_SIZE - 1.3), Vector3.new(x, 0.91, z), plateColor)
		end
	end

	-- Perimeter walls (the phone's bezel) + title
	part(lobby, "WallBack", Vector3.new(150, 10, 1), Vector3.new(0, 5, 93), { 30, 30, 45 })
	part(lobby, "WallL", Vector3.new(1, 10, 118), Vector3.new(-71, 5, 34), { 30, 30, 45 })
	part(lobby, "WallR", Vector3.new(1, 10, 118), Vector3.new(71, 5, 34), { 30, 30, 45 })
	local trim = part(lobby, "TrimBack", Vector3.new(150, 1, 1.4), Vector3.new(0, 10.4, 93), { 90, 230, 255 }, Enum.Material.Neon)
	local title = part(lobby, "TitleSign", Vector3.new(52, 8, 1), Vector3.new(0, 5.5, 92.4), { 40, 40, 55 })
	label(title, "📱 PHONE ESCAPE 📱", Enum.NormalId.Back)

	-- Spawn deck (the home bar)
	part(lobby, "SpawnDeck", Vector3.new(17, 0.3, 17), Vector3.new(0, 0.95, 80), { 210, 210, 220 })
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 1.4, 80)
	spawn.Anchored = true
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Neutral = true
	spawn.Transparency = 0.4
	spawn.Parent = lobby

	-- Guide signs for new players (v4 comfort): the first 3 things to do
	part(lobby, "Guide1Post", Vector3.new(0.5, 5, 0.5), Vector3.new(0, 2.5, 30), { 90, 90, 100 })
	local g1 = part(lobby, "Guide1", Vector3.new(20, 4, 0.6), Vector3.new(0, 5.6, 30), { 50, 160, 90 })
	label(g1, "1️⃣ STEP ON APPS = +1 ⚡", Enum.NormalId.Back)
	local g2 = part(lobby, "Guide2", Vector3.new(15, 4, 0.6), Vector3.new(49, 4.5, 82), { 60, 120, 220 })
	label(g2, "🔌 CHARGE HERE ➡", Enum.NormalId.Back)
	local g3 = part(lobby, "Guide3", Vector3.new(20, 4, 0.6), Vector3.new(0, 5.6, -8), { 220, 90, 160 })
	label(g3, "🚪 STAGE 1 — LEVEL 1", Enum.NormalId.Back)

	-- TOP LEVEL / TOP WINS boards flanking the Stage 1 gate
	local bLevel = part(lobby, "BoardLevel", Vector3.new(19, 12, 1), Vector3.new(-24, 6.5, -15), { 160, 50, 140 })
	MapBuilder.boardLevelLabels = board(bLevel, "🏆 TOP LEVEL 🏆")
	local bWins = part(lobby, "BoardWins", Vector3.new(19, 12, 1), Vector3.new(24, 6.5, -15), { 160, 50, 140 })
	MapBuilder.boardWinsLabels = board(bWins, "🏆 TOP WINS 🏆")

	-- Items Shop stall (left, on a platform over the keys)
	part(lobby, "ShopPlatform", Vector3.new(24, 1, 20), Vector3.new(-56, 0.9, 58), { 200, 120, 170 })
	local stall = part(lobby, "ItemsShop", Vector3.new(18, 8, 12), Vector3.new(-56, 5.4, 60), { 255, 170, 215 })
	part(lobby, "ShopRoof", Vector3.new(21, 1, 15), Vector3.new(-56, 9.8, 60), { 200, 60, 130 })
	label(stall, "🛍️ ITEMS SHOP", Enum.NormalId.Front)

	-- Event portal arch (right) — decorative, like the screenshot's countdown portal
	part(lobby, "PortalL", Vector3.new(3, 13, 3), Vector3.new(50, 6.5, 62), { 90, 90, 100 })
	part(lobby, "PortalR", Vector3.new(3, 13, 3), Vector3.new(62, 6.5, 62), { 90, 90, 100 })
	local beam = part(lobby, "PortalTop", Vector3.new(15, 3, 3), Vector3.new(56, 13.5, 62), { 90, 90, 100 })
	label(beam, "🌍 WORLD 2 — SOON", Enum.NormalId.Front)

	-- Neon bubble decor (app bubbles rising off the screen)
	local lolColors = { { 255, 110, 180 }, { 110, 220, 255 }, { 170, 255, 110 }, { 255, 190, 90 } }
	for i, pos in { { -66, 26 }, { 66, 26 }, { -66, 84 }, { 66, 84 } } do
		part(lobby, "BubbleStick" .. i, Vector3.new(0.6, 10, 0.6), Vector3.new(pos[1], 5, pos[2]), { 245, 245, 245 })
		local head = part(lobby, "Bubble" .. i, Vector3.new(5.4, 1.4, 5.4), Vector3.new(pos[1], 10.6, pos[2]), lolColors[i], Enum.Material.Neon)
		head.Shape = Enum.PartType.Cylinder
		head.Orientation = Vector3.new(0, 0, 90)
	end
	for i, pos in { { -64, 44 }, { 64, 44 }, { -64, 6 }, { 64, 6 } } do
		local gum = part(lobby, "Puff" .. i, Vector3.new(4, 3, 4), Vector3.new(pos[1], 1.2, pos[2]), lolColors[(i % 4) + 1])
		gum.Shape = Enum.PartType.Ball
	end

	-- Charging-station platform (right side), pads along it
	part(lobby, "ChargePlatform", Vector3.new(17, 1, 118), Vector3.new(58, 0.25, 26), { 45, 45, 60 })
	local tmFolder = Instance.new("Folder")
	tmFolder.Name = "Chargers"
	tmFolder.Parent = lobby
	for i, tm in Config.CHARGERS do
		local z = 74 - (i - 1) * 16
		local pad = part(tmFolder, "Charger_" .. i, Vector3.new(13, 0.25, 13), Vector3.new(58, 0.9, z),
			i == #Config.CHARGERS and { 255, 200, 40 } or { 80, 80, 100 }, Enum.Material.Neon)
		pad:SetAttribute("ChargerIndex", i)
		local costText = tm.cost == 0 and "FREE" or "🏆 " .. NumberFormat.format(tm.cost)
		label(pad, "🔌 " .. tm.name .. "\n+" .. NumberFormat.format(tm.rate) .. "⚡/s\n" .. costText, Enum.NormalId.Top)
	end

	-- ================= COURSE BUILDER (v8) =================
	-- Lays a stage's planned elements over its 84-stud run. Mechanics are
	-- attribute-driven; StageService animates/drives them at runtime.
	local function buildCourse(stageFolder, world, stageIdx, plan, zStart, zEnd, theme)
		local speedScale = world == 2 and 1.35 or 1
		local z = zStart
		local elIdx = 0
		local function star(x, y, zz)
			local st = part(stageFolder, "Star_" .. stageIdx .. "_" .. elIdx, Vector3.new(1.7, 1.7, 1.7), Vector3.new(x, y, zz), { 255, 215, 0 }, Enum.Material.Neon)
			st.Shape = Enum.PartType.Ball
			st:SetAttribute("IsStar", true)
			st:SetAttribute("StarKey", world * 1000 + stageIdx)
			elIdx += 1
		end
		for _, token in plan.elements do
			elIdx += 1
			local name, arg = string.match(token, "^(%a+):?(%d*)$")
			local len = tonumber(arg) or 0
			local zc = z - len / 2
			if name == "run" then
				part(stageFolder, "Run_" .. elIdx, Vector3.new(16, 1, len), Vector3.new(0, 0, zc), theme.floor)
			elseif name == "gap" then
				-- open air over the kill floor
			elseif name == "moving" or name == "movingy" then
				local plat = part(stageFolder, "Moving_" .. elIdx, Vector3.new(11, 1, 10), Vector3.new(0, 0, zc), theme.accent)
				plat:SetAttribute("Moving", true)
				plat:SetAttribute("MoveAxis", name == "movingy" and "Y" or "X")
				plat:SetAttribute("MoveRange", name == "movingy" and 3.2 or 7)
				plat:SetAttribute("MoveSpeed", 1.1 * speedScale)
				plat:SetAttribute("MovePhase", stageIdx * 1.7 + elIdx)
			elseif name == "vanish" then
				local tileLen = len / 3
				for k = 1, 3 do
					local tile = part(stageFolder, "Vanish_" .. elIdx .. "_" .. k, Vector3.new(16, 0.8, tileLen - 1.5), Vector3.new(0, 0, z - (k - 0.5) * tileLen), { 255, 240, 170 }, Enum.Material.Neon)
					tile:SetAttribute("VanishPhase", (k + stageIdx) % 3)
				end
			elseif name == "convF" or name == "convB" then
				local belt = part(stageFolder, "Belt_" .. elIdx, Vector3.new(16, 1, len), Vector3.new(0, 0, zc), name == "convF" and { 90, 200, 255 } or { 255, 150, 90 })
				belt:SetAttribute("ConvZ", name == "convF" and -26 or 18)
			elseif name == "bounce" then
				for _, frac in { 0.3, 0.7 } do
					local islandZ = z - len * frac
					part(stageFolder, "BounceIsle_" .. elIdx, Vector3.new(9, 1, 9), Vector3.new(0, 0, islandZ), theme.floor)
					local padB = part(stageFolder, "BouncePad_" .. elIdx, Vector3.new(6, 0.6, 6), Vector3.new(0, 0.8, islandZ), { 255, 90, 200 }, Enum.Material.Neon)
					padB:SetAttribute("Bounce", 68)
				end
			elseif name == "sweep" then
				part(stageFolder, "SweepFloor_" .. elIdx, Vector3.new(16, 1, len), Vector3.new(0, 0, zc), theme.floor)
				part(stageFolder, "SweepPost_" .. elIdx, Vector3.new(1.2, 3, 1.2), Vector3.new(0, 1.5, zc), { 60, 60, 70 })
				local arm = part(stageFolder, "SweepArm_" .. elIdx, Vector3.new(13, 1.1, 1.1), Vector3.new(0, 1.35, zc), { 235, 70, 60 }, Enum.Material.Neon)
				arm:SetAttribute("Sweeper", true)
				arm:SetAttribute("SweepSpeed", (1.1 + stageIdx * 0.04) * speedScale)
				arm:SetAttribute("PivotX", 0)
				arm:SetAttribute("PivotZ", zc)
			elseif name == "narrow" then
				part(stageFolder, "Narrow_" .. elIdx .. "a", Vector3.new(4.5, 1, len / 2), Vector3.new(-3.5, 0, z - len / 4), theme.floor)
				part(stageFolder, "Narrow_" .. elIdx .. "b", Vector3.new(4.5, 1, len / 2), Vector3.new(3.5, 0, z - 3 * len / 4), theme.floor)
			elseif name == "tower" then
				for k = 1, 5 do
					part(stageFolder, "Tower_" .. elIdx .. "_" .. k, Vector3.new(9, 1, 9), Vector3.new(0, k * 2.1 - 1, z - (k - 0.5) * (len / 5)), theme.floor)
				end
			elseif name == "split" then
				part(stageFolder, "SplitSafe_" .. elIdx, Vector3.new(10, 1, len), Vector3.new(-12.5, 0, zc), theme.floor)
				part(stageFolder, "SplitRisk_" .. elIdx, Vector3.new(5, 1, len), Vector3.new(13.5, 0, zc), theme.accent)
				for _, frac in { 0.25, 0.5, 0.75 } do
					star(13.5, 1.6, z - len * frac)
				end
			elseif name == "mid" then
				local midPad = part(stageFolder, "MidPad_" .. elIdx, Vector3.new(12, 0.6, 6), Vector3.new(0, 0.3, z - 3), { 120, 255, 140 }, Enum.Material.Neon)
				midPad:SetAttribute("MidStart", stageIdx)
				midPad:SetAttribute("World", world)
			end
			z -= len
		end
		if z > zEnd then
			part(stageFolder, "Run_fill", Vector3.new(16, 1, z - zEnd), Vector3.new(0, 0, (z + zEnd) / 2), theme.floor)
		end
	end

	-- ================= STAGES (parameterized per world, v6) =================
	local function buildStages(stagesFolder, world, zOffset, themes)
		local reqTable = world == 2 and Config.STAGE_LEVEL_REQS_W2 or Config.STAGE_LEVEL_REQS
		local winsTable = world == 2 and Config.STAGE_WINS_W2 or Config.STAGE_WINS
		for i = 1, #reqTable do
			local theme = themes[(i - 1) % #themes + 1]
			local zGate = zOffset - Config.STAGE_SPACING * (i - 1) - 20
			local zStart = zGate - 6
			local zEnd = zStart - 84
			local stageFolder = Instance.new("Folder")
			stageFolder.Name = "Stage_" .. i
			stageFolder.Parent = stagesFolder
			stagesBuilt += 1

			local req = reqTable[i]
			local plan = world == 2 and Config.STAGE_PLANS[((i + 2) % #Config.STAGE_PLANS) + 1] or Config.STAGE_PLANS[i]
			local gateColor = plan.boss and { 255, 200, 40 } or theme.accent
			local gate = part(stageFolder, "Gate", Vector3.new(26, 15, 2), Vector3.new(0, 7.5, zGate), gateColor)
			gate:SetAttribute("StageIndex", i)
			gate:SetAttribute("World", world)
			gate:SetAttribute("Requirement", req)
			label(gate, "🔋 LEVEL " .. req .. "\n" .. plan.name, Enum.NormalId.Back)
			part(stageFolder, "GatePostL", Vector3.new(3, 19, 3), Vector3.new(-14.5, 9.5, zGate), gateColor)
			part(stageFolder, "GatePostR", Vector3.new(3, 19, 3), Vector3.new(14.5, 9.5, zGate), gateColor)

			buildCourse(stageFolder, world, i, plan, zStart, zEnd, theme)

			-- Battery stages (bosses): draining battery + pickup cells
			if plan.boss then
				stageFolder:SetAttribute("BatteryDrain", Config.BATTERY_DRAIN_PCT)
				local spots = { { -6, 22 }, { 6, 47 }, { 0, 70 } }
				for n, spot in spots do
					local cell = part(stageFolder, "BatteryPickup_" .. n, Vector3.new(2.2, 3, 1.2), Vector3.new(spot[1], 1.8, zStart - spot[2]), { 90, 255, 120 }, Enum.Material.Neon)
					cell.CanCollide = false
					cell:SetAttribute("IsBattery", true)
					label(cell, "🔋", Enum.NormalId.Front, Color3.fromRGB(20, 80, 20))
				end
			end

			local startPad = part(stageFolder, "StartPad", Vector3.new(16, 0.6, 6), Vector3.new(0, 0.3, zStart - 3), { 120, 255, 140 }, Enum.Material.Neon)
			startPad:SetAttribute("StageStart", i)
			startPad:SetAttribute("World", world)

			local reward = winsTable[i]
			local pad = part(stageFolder, "WinsPad", Vector3.new(16, 0.8, 10), Vector3.new(0, 0.4, zEnd - 5), { 255, 214, 40 }, Enum.Material.Neon)
			pad:SetAttribute("StageWin", i)
			pad:SetAttribute("World", world)
			label(pad, "🏆 +" .. NumberFormat.format(reward) .. " WINS", Enum.NormalId.Top, Color3.fromRGB(80, 60, 0))

			local kill = part(stageFolder, "KillFloor", Vector3.new(60, 1, 100), Vector3.new(0, -8, (zStart + zEnd) / 2), world == 2 and { 90, 180, 255 } or { 255, 70, 40 }, Enum.Material.Neon)
			kill:SetAttribute("IsKill", true)

			local nextGateZ = zOffset - Config.STAGE_SPACING * i - 20
			local bridgeLen = (zEnd - 10) - nextGateZ
			if i < #reqTable then
				part(stageFolder, "Bridge", Vector3.new(16, 1, bridgeLen), Vector3.new(0, 0, (zEnd - 10 + nextGateZ) / 2), theme.floor)
			else
				local fin = part(stageFolder, "Finish", Vector3.new(30, 1, 24), Vector3.new(0, 0, zEnd - 22), { 255, 215, 0 }, Enum.Material.Neon)
				label(fin, "🏆 YOU ESCAPED THE PHONE! 🏆", Enum.NormalId.Top, Color3.fromRGB(80, 60, 0))
			end
		end
	end

	local stages = Instance.new("Folder")
	stages.Name = "Stages"
	stages.Parent = map
	buildStages(stages, 1, 0, Config.STAGE_THEMES)

	-- World 2 teaser (by the arch): Social Apps world ships in Update 1.
	-- Decorative pad only — no portal wiring in v1.
	local teaser = part(lobby, "W2Teaser", Vector3.new(10, 0.5, 10), Vector3.new(40, 1.0, 62), { 120, 120, 140 }, Enum.Material.Neon)
	label(teaser, "🔒 WORLD 2\nSOCIAL APPS — SOON", Enum.NormalId.Top)

	local lobbyKill = part(map, "LobbyKill", Vector3.new(500, 1, 500), Vector3.new(0, -12, -Config.STAGE_SPACING * Config.STAGE_COUNT / 2), { 255, 70, 40 }, Enum.Material.Neon)
	lobbyKill.Transparency = 0.6
	lobbyKill:SetAttribute("IsKill", true)

	-- World 2 (Social Apps) ships in Update 1 — its numbers already live
	-- in Config; v1 builds World 1 only, plus the lobby teaser above.

	-- Seasonal decor (disabled until the first event: Config.SEASONAL)
	if Config.SEASONAL then
		for i, pos in { { -30, 96 }, { 30, 96 }, { -70, 58 }, { 70, 58 }, { -30, -2 }, { 34, -2 } } do
			local pumpkin = part(lobby, "Pumpkin" .. i, Vector3.new(3.4, 2.8, 3.4), Vector3.new(pos[1], 1.4, pos[2]), { 255, 130, 30 })
			pumpkin.Shape = Enum.PartType.Ball
			part(lobby, "PumpkinStem" .. i, Vector3.new(0.5, 0.8, 0.5), Vector3.new(pos[1], 3.1, pos[2]), { 70, 140, 60 })
		end
		for i, pos in { { -52, 20 }, { 52, 20 }, { 0, 108 } } do
			local ghost = part(lobby, "Ghost" .. i, Vector3.new(2.6, 3.4, 2.6), Vector3.new(pos[1], 4.5, pos[2]), { 245, 245, 255 })
			ghost.Shape = Enum.PartType.Ball
			ghost.Transparency = 0.25
		end
	end

	local old = workspace:FindFirstChild("PhoneMap")
	if old then
		old:Destroy()
	end
	map.Name = "PhoneMap"
	map.Parent = workspace

	print(("[Phone] Map built: %d app icons, %d stages"):format(keysBuilt, stagesBuilt))
end

return MapBuilder
