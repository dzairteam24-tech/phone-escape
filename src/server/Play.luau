-- Play.luau — حلقة اللعب: الخطو على الأيقونات، محطات الشحن، بوابات
-- المستوى، جولات المراحل (نجوم/سقوط/ميداليات)، وميكانيكية البطارية.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Format = require(Shared.Format)

local Store = require(script.Parent.Store)

local Play = {}
Play.passGain = {} -- [Player] = مضاعف الباسات (يملؤه Shop)
Play.passWins = {} -- [Player] = مضاعف Wins من الباسات
Play.hooks = {} -- { icons=fn(player), stages=fn(player), charge=fn(player, seconds) }

local ctx -- { remotes, toast }
local frac = {} -- كسور الشحن المتراكمة
local lastPad = {} -- [Player] = آخر زر داسه (خطوة على زر جديد = +1 فقط)
local lockToastAt = {} -- [Player] = clock (تنبيه محطة مقفلة)
local gateToastAt = {} -- [Player] = { [stage] = clock }
local beginAt = {} -- [stage] = CFrame (بدايات الأبراج، يملؤها init)
local checkpoints = {} -- [Player] = CFrame
local armed = {} -- [Player] = { [stage] = true }
local runs = {} -- [Player] = { stage, t0, falls, stars=set, battery?, warned50, warned25 }
local cellCd = {} -- [Player] = { [part] = clock }
local bossStages = {} -- [stage] = true
local LOBBY_SPAWN = nil -- يُضبط في init من SpawnLocation

local function toast(player, text)
	if ctx and ctx.toast then
		ctx.toast(player, text)
	end
end

-- ===== المضاعفات =====
local function ownsPass(data, key)
	return data.pass and data.pass[key] == true
end

function Play.caseMult(player)
	local data = Store.profiles[player]
	if not data then
		return 1
	end
	return Rules.bestMult(data.cases, Config.CASES, function(key)
		return ownsPass(data, key)
	end)
end

function Play.signalMult(player)
	local data = Store.profiles[player]
	if not data then
		return 1
	end
	return Rules.bestMult(data.signals, Config.SIGNALS, function(key)
		return ownsPass(data, key)
	end)
end

function Play.cableMult(player)
	local data = Store.profiles[player]
	if not data then
		return 1
	end
	local best = 1
	for _, cable in Config.CABLES do
		if ownsPass(data, cable.pass) and cable.mult > best then
			best = cable.mult
		end
	end
	return best
end

function Play.stack(player)
	local data = Store.profiles[player]
	if not data then
		return 1
	end
	local m = Rules.gainStack(Play.caseMult(player), Play.signalMult(player), Rules.itemsMult(data.items), data.phones, data.ascends, Play.passGain[player] or 1)
	if data.boostUntil and data.boostUntil > os.time() then
		m *= data.boostMult or 1
	end
	return m
end

-- كسب شحن عبر الحلقة (يمر بكل المضاعفات)
function Play.gain(player, base)
	local data = Store.profiles[player]
	if not data then
		return
	end
	frac[player] = (frac[player] or 0) + base * Play.stack(player)
	local whole = math.floor(frac[player])
	if whole > 0 then
		frac[player] -= whole
		data.charge += whole
		data.lifetime += whole
		Store.sync(player)
	end
end

-- منح مباشر (أكواد/هدايا/منتجات): يعدّ في التراكمي أيضًا
function Play.grant(player, amount)
	local data = Store.profiles[player]
	if not data then
		return
	end
	data.charge += amount
	data.lifetime += amount
	Store.sync(player)
end

function Play.batteryOf(player)
	local run = runs[player]
	if run and run.battery then
		return math.max(0, math.floor(run.battery))
	end
	return nil
end

function Play.resetRun(player)
	runs[player] = nil
	armed[player] = {}
	checkpoints[player] = nil
end

local function hrpOf(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

function Play.sendTo(player, cf)
	local hrp = hrpOf(player)
	if hrp then
		hrp.CFrame = cf
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
	checkpoints[player] = cf
end

function Play.toLobby(player)
	Play.sendTo(player, LOBBY_SPAWN or CFrame.new(0, 3, 80))
end

function Play.stageStart(i)
	return beginAt[i]
end

function Play.respawn(player)
	local run = runs[player]
	if run then
		run.falls += 1
	end
	local hrp = hrpOf(player)
	if hrp then
		hrp.CFrame = checkpoints[player] or LOBBY_SPAWN
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
end

-- ===== إتمام مرحلة =====
local function claim(player, stageIdx, withRun)
	local data = Store.profiles[player]
	local def = Config.STAGES[stageIdx]
	if not (data and def) then
		return
	end
	local reward = def.wins * (Play.passWins[player] or 1)
	local extra = ""
	local run = runs[player]
	if withRun and run and run.stage == stageIdx then
		local starCount = 0
		for _ in run.stars do
			starCount += 1
		end
		local elapsed = os.clock() - run.t0
		local pct, medal = Rules.runBonus(starCount, run.falls, elapsed, stageIdx)
		if pct > 0 then
			reward = math.floor(reward * (1 + pct / 100))
			local bits = {}
			if starCount > 0 then
				table.insert(bits, "⭐x" .. starCount)
			end
			if run.falls == 0 then
				table.insert(bits, "flawless")
			end
			if medal ~= "" then
				table.insert(bits, (medal == "gold" and "🥇" or medal == "silver" and "🥈" or "🥉") .. string.format(" %.1fs", elapsed))
			end
			extra = " (" .. table.concat(bits, " • ") .. " +" .. pct .. "%)"
		end
		local key = "s" .. stageIdx
		if not data.best[key] or elapsed < data.best[key] then
			data.best[key] = math.floor(elapsed * 10) / 10
		end
		runs[player] = nil
	end
	data.wins += reward
	if stageIdx > data.stage then
		data.stage = stageIdx
	end
	Store.sync(player)
	toast(player, "🏆 Stage " .. stageIdx .. " — " .. def.name .. " cleared! +" .. Format.num(reward) .. " Wins" .. extra)
	if ctx and ctx.remotes then
		ctx.remotes.StageCleared:FireClient(player, stageIdx)
	end
	if Play.hooks.stages then
		Play.hooks.stages(player)
	end
end

-- تخطي مدفوع: يمنح الجائزة الأساسية بلا بونص جولة
function Play.claimSkip(player, stageIdx)
	claim(player, stageIdx, false)
end

function Play.clearStageReward(stageIdx)
	local def = Config.STAGES[stageIdx]
	return def and def.wins or 0
end

-- ===== التهيئة =====
function Play.init(context)
	ctx = context
	local world = workspace:WaitForChild("PhoneWorld")
	LOBBY_SPAWN = CFrame.new(0, 3, 84)
	local plaza = world:FindFirstChild("Plaza")
	local spawnLoc = plaza and plaza:FindFirstChild("Spawn")
	if spawnLoc then
		LOBBY_SPAWN = CFrame.new(spawnLoc.Position + Vector3.new(0, 2, 0))
	end
	local stagesFolder = world:FindFirstChild("Stages")
	if stagesFolder then
		for _, sf in stagesFolder:GetChildren() do
			local idx = tonumber(string.match(sf.Name, "Stage_(%d+)"))
			if idx and sf:GetAttribute("Boss") then
				bossStages[idx] = true
			end
		end
	end

	local movers, spinners, blinks, belts, stars = {}, {}, {}, {}, {}
	local enterPads = {}
	local flashBusy = {}
	local function flash(partObj)
		if flashBusy[partObj] then
			return
		end
		flashBusy[partObj] = true
		local c = partObj.Color
		partObj.Color = Color3.fromRGB(255, 255, 235) -- وميض أبيض ناعم بلا نيون
		task.delay(0.18, function()
			if partObj.Parent then
				partObj.Color = c
			end
			flashBusy[partObj] = nil
		end)
	end

	local bounceAt = {}
	for _, d in world:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("Move") then
				table.insert(movers, { part = d, base = d.CFrame, axis = d:GetAttribute("Axis") or "X", range = d:GetAttribute("Range") or 7, speed = d:GetAttribute("Speed") or 1.1, phase = d:GetAttribute("Phase") or 0 })
			end
			if d:GetAttribute("Sweep") then
				table.insert(spinners, { part = d, y = d.Position.Y, px = d:GetAttribute("PivotX") or d.Position.X, pz = d:GetAttribute("PivotZ") or d.Position.Z, speed = d:GetAttribute("SweepSpeed") or 1.2 })
			end
			if d:GetAttribute("Vanish") ~= nil then
				table.insert(blinks, { part = d, phase = d:GetAttribute("Vanish") })
			end
			if d:GetAttribute("Belt") then
				table.insert(belts, { part = d, z = d:GetAttribute("Belt") })
			end
			if d:GetAttribute("Star") then
				local ofStage = d:GetAttribute("StarOf")
				table.insert(stars, { part = d, base = d.Position, phase = math.random() * 6 })
				d.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					local run = player and runs[player]
					if run and run.stage == ofStage and not run.stars[d] then
						run.stars[d] = true
						toast(player, "⭐ Star! (+25% stage bonus)")
					end
				end)
			end
			if d:GetAttribute("Enter") then
				table.insert(enterPads, d)
			end
			if d:GetAttribute("Cell") then
				d.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					local run = player and runs[player]
					if run and run.battery and run.battery < 100 then
						cellCd[player] = cellCd[player] or {}
						local now = os.clock()
						if now - (cellCd[player][d] or 0) > 8 then
							cellCd[player][d] = now
							run.battery = math.min(100, run.battery + Config.BATTERY_CELL)
							toast(player, "🔋 +" .. Config.BATTERY_CELL .. "% (" .. math.floor(run.battery) .. "%)")
						end
					end
				end)
			end
			if d:GetAttribute("Bounce") then
				local power = d:GetAttribute("Bounce")
				d.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					local root = hit.Parent and hit.Parent:FindFirstChild("HumanoidRootPart")
					if player and root then
						local key = player.UserId .. d:GetDebugId()
						local now = os.clock()
						if now - (bounceAt[key] or 0) > 0.35 then
							bounceAt[key] = now
							local v = root.AssemblyLinearVelocity
							root.AssemblyLinearVelocity = Vector3.new(v.X, power, v.Z)
						end
					end
				end)
			end
			if d:GetAttribute("Begin") then
				local idx = d:GetAttribute("Begin")
				beginAt[idx] = d.CFrame + Vector3.new(0, 3, 0)
				d.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if not player then
						return
					end
					checkpoints[player] = d.CFrame + Vector3.new(0, 3, 0)
					armed[player] = armed[player] or {}
					armed[player][idx] = true
					local run = runs[player]
					if not run or run.stage ~= idx then
						runs[player] = { stage = idx, t0 = os.clock(), falls = 0, stars = {} }
						if bossStages[idx] then
							runs[player].battery = 100
							toast(player, "🔋 Power-save stage! Grab 🔋 cells — 0% sends you back!")
						end
					end
				end)
			elseif d:GetAttribute("Mid") then
				local idx = d:GetAttribute("Mid")
				d.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if player then
						checkpoints[player] = d.CFrame + Vector3.new(0, 3, 0)
						armed[player] = armed[player] or {}
						armed[player][idx] = true
					end
				end)
			elseif d:GetAttribute("Finish") then
				local idx = d:GetAttribute("Finish")
				d.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if player and armed[player] and armed[player][idx] then
						armed[player][idx] = false
						claim(player, idx, true)
					end
				end)
			elseif d:GetAttribute("Kill") then
				d.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if player then
						Play.respawn(player)
					end
				end)
			end
		end
	end
	-- وسائد دخول الأبراج: بوابة المستوى تُفحص هنا (لا عبور بلا مستوى)
	for _, pad in enterPads do
		local idx = pad:GetAttribute("Enter")
		pad.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then
				return
			end
			local data = Store.profiles[player]
			local target = beginAt[idx]
			local def = Config.STAGES[idx]
			if not (data and target and def) then
				return
			end
			local level = Rules.level(data.lifetime)
			if idx <= data.stage or level >= def.req then
				checkpoints[player] = target
				local root = hit.Parent:FindFirstChild("HumanoidRootPart")
				if root then
					root.CFrame = target
					root.AssemblyLinearVelocity = Vector3.zero
				end
			else
				gateToastAt[player] = gateToastAt[player] or {}
				local now = os.clock()
				if now - (gateToastAt[player][idx] or 0) > 3 then
					gateToastAt[player][idx] = now
					toast(player, "🧱 Tower " .. idx .. " — " .. def.name .. " needs Level " .. def.req .. "!")
				end
			end
		end)
	end
	Play._flash = flash

	-- حلقة الميكانيكيات المتحركة
	local lastCycle = -1
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, m in movers do
			local off = math.sin(t * m.speed + m.phase) * m.range
			m.part.CFrame = m.axis == "Y" and (m.base * CFrame.new(0, off, 0)) or (m.base * CFrame.new(off, 0, 0))
		end
		for _, s in spinners do
			s.part.CFrame = CFrame.new(s.px, s.y, s.pz) * CFrame.Angles(0, t * s.speed, 0)
		end
		local cycle = math.floor(t / 1.1) % 3
		if cycle ~= lastCycle then
			lastCycle = cycle
			for _, b in blinks do
				local solid = b.phase == cycle
				b.part.CanCollide = solid
				b.part.Transparency = solid and 0 or 0.65
			end
		end
		for _, s in stars do
			s.part.Position = s.base + Vector3.new(0, math.sin(t * 2 + s.phase) * 0.3, 0)
		end
		if #belts > 0 then
			for _, player in Players:GetPlayers() do
				local root = hrpOf(player)
				if root then
					for _, belt in belts do
						local bp, bs = belt.part.Position, belt.part.Size
						if math.abs(root.Position.X - bp.X) < bs.X / 2 + 0.5
							and math.abs(root.Position.Z - bp.Z) < bs.Z / 2 + 0.5
							and root.Position.Y > bp.Y and root.Position.Y < bp.Y + 3.2 then
							local v = root.AssemblyLinearVelocity
							root.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, belt.z)
						end
					end
				end
			end
		end
	end)

	-- حلقة اللعب: فحص ما تحت اللاعب + البوابات + البطارية
	RunService.Heartbeat:Connect(function(dt)
		local w = workspace:FindFirstChild("PhoneWorld")
		if not w then
			return
		end
		for _, player in Players:GetPlayers() do
			local data = Store.profiles[player]
			local root = hrpOf(player)
			if not (data and root) then
				continue
			end
			-- ما تحت اللاعب
			local params = OverlapParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { w }
			local hits = workspace:GetPartBoundsInBox(CFrame.new(root.Position - Vector3.new(0, 2.6, 0)), Vector3.new(3.4, 2.2, 3.4), params)
			local now = os.clock()
			local padUnder, bestD = nil, math.huge
			for _, hit in hits do
				if hit:GetAttribute("Icon") then
					local dx = hit.Position.X - root.Position.X
					local dz = hit.Position.Z - root.Position.Z
					local d2 = dx * dx + dz * dz
					if d2 < bestD then
						bestD = d2
						padUnder = hit
					end
				elseif hit:GetAttribute("Station") then
					local idx = hit:GetAttribute("Station")
					local chg = Config.CHARGERS[idx]
					if chg then
						if table.find(data.chargers, idx) then
							Play.gain(player, Rules.chargerRate(chg, data.chargerLv[idx] or 0) * Play.cableMult(player) * dt)
							if Play.hooks.charge then
								Play.hooks.charge(player, dt)
							end
						elseif now - (lockToastAt[player] or 0) > 4 then
							lockToastAt[player] = now
							toast(player, "🔒 Buy the " .. chg.name .. " station in the Chargers panel")
						end
					end
				end
			end
			-- خطوة على زرّ جديد = +شحن (الوقوف على نفس الزر لا يمنح شيئًا)
			if padUnder then
				if padUnder ~= lastPad[player] then
					lastPad[player] = padUnder
					local link = Config.LINKS[data.linkIdx] or Config.LINKS[1]
					Play.gain(player, link.amount)
					flash(padUnder)
					-- صوت كيبورد + رقم طائر عند اللاعب نفسه
					if ctx and ctx.remotes and ctx.remotes.StepFX then
						ctx.remotes.StepFX:FireClient(player, math.max(1, math.floor(link.amount * Play.stack(player) + 0.5)))
					end
					if Play.hooks.icons then
						Play.hooks.icons(player)
					end
				end
			else
				lastPad[player] = nil
			end
			-- سرعة المشي من الشحن: نمو محسوس من أول دقيقة لعب
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				local eff = data.charge
				if data.cap and data.cap > 0 then
					eff = math.min(eff, data.cap)
				end
				hum.WalkSpeed = math.min(16 + math.sqrt(math.max(eff, 0)) / 2, 250)
			end
			-- البطارية
			local run = runs[player]
			if run and run.battery then
				run.battery -= Config.BATTERY_DRAIN * dt
				if run.battery <= 50 and not run.warned50 then
					run.warned50 = true
					toast(player, "🪫 Battery at 50%! Find a 🔋 cell!")
				end
				if run.battery <= 25 and not run.warned25 then
					run.warned25 = true
					toast(player, "🪫⚠️ Battery at 25%!")
				end
				if run.battery <= 0 then
					runs[player] = nil
					toast(player, "🔋 Battery empty! Back to the checkpoint!")
					Play.respawn(player)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		frac[player] = nil
		lastPad[player] = nil
		lockToastAt[player] = nil
		gateToastAt[player] = nil
		checkpoints[player] = nil
		armed[player] = nil
		runs[player] = nil
		cellCd[player] = nil
		Play.passGain[player] = nil
		Play.passWins[player] = nil
	end)
end

return Play
