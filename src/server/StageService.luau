-- StageService: stage gates with level requirements, checkpoints,
-- kill-floor respawns, Wins pads, and world portals.
-- v6: two worlds. World 1 stages extend from z=0; World 2 (Snow) from
-- z = Config.WORLD2_Z, gated by the documented World 2 level ladder.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local NumberFormat = require(Shared.NumberFormat)

local DataService = require(script.Parent.DataService)
local SpeedService = require(script.Parent.SpeedService)

local StageService = {}
StageService.onClaim = nil -- optional hook (player, stageIndex) — set by ServerMain for quests
StageService.checkpoints = {} -- [Player] = CFrame
StageService.armed = {} -- [Player] = {[world*1000+stageIndex] = true}
local remotes
local portalCooldown = {}
-- v8 mechanics registries + per-run tracking (stars / falls / timer)
local movers = {}
local sweepers = {}
local vanishTiles = {}
local conveyors = {}
local spinStars = {}
local runs = {} -- [Player] = {world, stage, startT, falls, stars = {[part] = true}, battery?}
local bounceCooldown = {}
local batteryStages = {} -- [world*1000+stage] = drain % per second (boss stages)
local batteryCooldown = {} -- [Player] = {[BasePart] = os.clock()}

local WORLD_OFFSETS = { [1] = 0, [2] = Config.WORLD2_Z }
local WORLD_SPAWNS = { [1] = CFrame.new(0, 3, 78), [2] = CFrame.new(0, 3, Config.WORLD2_LOBBY_Z) }

function StageService.toast(player: Player, text: string)
	if remotes then
		remotes.Toast:FireClient(player, text)
	end
end

function StageService.setSpawn(player: Player, cframe: CFrame)
	StageService.checkpoints[player] = cframe
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = cframe
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
end

function StageService.claimStage(player: Player, stageIndex: number, world: number?)
	world = world or 1
	local data = DataService.profiles[player]
	if not data then
		return
	end
	local reward = Economy.stageReward(stageIndex, world) * (SpeedService.winMult[player] or 1)
	-- v8 run bonuses: stars, no-fall, timer medal
	local bonusText = ""
	local run = runs[player]
	if run and run.world == world and run.stage == stageIndex then
		local starCount = 0
		for _ in run.stars do
			starCount += 1
		end
		local elapsed = os.clock() - run.startT
		local pct, medal = Economy.runBonus(starCount, run.falls, elapsed, Economy.parTime(stageIndex, world))
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
				table.insert(bits, (medal == "gold" and "🥇" or medal == "silver" and "🥈" or "🥉") .. " " .. string.format("%.1fs", elapsed))
			end
			bonusText = " (" .. table.concat(bits, " • ") .. " +" .. pct .. "%)"
		end
		data.BestTimes = data.BestTimes or {}
		local key = "w" .. world .. "_" .. stageIndex
		if not data.BestTimes[key] or elapsed < data.BestTimes[key] then
			data.BestTimes[key] = math.floor(elapsed * 10) / 10
		end
		runs[player] = nil
	end
	data.Wins += reward
	if world == 2 then
		if stageIndex > (data.MaxStageW2 or 0) then
			data.MaxStageW2 = stageIndex
		end
	else
		if stageIndex > data.MaxStage then
			data.MaxStage = stageIndex
		end
	end
	DataService.syncStats(player)
	local tag = world == 2 and "❄️ World 2 — " or ""
	StageService.toast(player, "🏆 " .. tag .. "Stage " .. stageIndex .. " cleared! +" .. NumberFormat.format(reward) .. " Wins" .. bonusText)
	if remotes then
		remotes.StageCleared:FireClient(player, stageIndex)
	end
	if StageService.onClaim then
		StageService.onClaim(player, stageIndex)
	end
end

function StageService.teleportToCheckpoint(player: Player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		if runs[player] then
			runs[player].falls += 1
		end
		hrp.CFrame = StageService.checkpoints[player] or WORLD_SPAWNS[1]
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
end

local function usePortal(player: Player, targetWorld: number)
	local now = os.clock()
	if portalCooldown[player] and now - portalCooldown[player] < 2 then
		return
	end
	portalCooldown[player] = now
	local data = DataService.profiles[player]
	if not data then
		return
	end
	if targetWorld == 2 and Economy.levelFor(data.TotalEarned) < Config.WORLD2_UNLOCK_LEVEL and (data.MaxStageW2 or 0) == 0 then
		StageService.toast(player, "🔒 World 2 unlocks at Level " .. Config.WORLD2_UNLOCK_LEVEL .. "!")
		return
	end
	StageService.setSpawn(player, WORLD_SPAWNS[targetWorld] + Vector3.new(0, 1, 0))
	StageService.toast(player, targetWorld == 2 and "❄️ Welcome to SNOW WORLD! Gates need Level 140+, Wins up to 40M" or "🏠 Back to World 1")
end

function StageService.resetRun(player: Player)
	runs[player] = nil
end

-- Current battery % for the HUD (nil when not in a battery stage run).
function StageService.runBattery(player: Player): number?
	local run = runs[player]
	if run and run.battery then
		return math.max(0, math.floor(run.battery))
	end
	return nil
end

function StageService.init(remotesFolder)
	remotes = remotesFolder
	local map = workspace:WaitForChild("PhoneMap")

	-- Battery stages registry (boss folders carry a BatteryDrain attribute)
	local stagesFolder = map:FindFirstChild("Stages")
	if stagesFolder then
		for _, folder in stagesFolder:GetChildren() do
			local drain = folder:GetAttribute("BatteryDrain")
			local idx = tonumber(string.match(folder.Name, "Stage_(%d+)"))
			if drain and idx then
				batteryStages[1000 + idx] = drain
			end
		end
	end

	-- Touch wiring: checkpoints, wins pads, kill floors, portals + v8 mechanics
	for _, desc in map:GetDescendants() do
		if desc:IsA("BasePart") then
			if desc:GetAttribute("Moving") then
				table.insert(movers, {
					part = desc, base = desc.CFrame,
					axis = desc:GetAttribute("MoveAxis") or "X",
					range = desc:GetAttribute("MoveRange") or 7,
					speed = desc:GetAttribute("MoveSpeed") or 1.1,
					phase = desc:GetAttribute("MovePhase") or 0,
				})
			end
			if desc:GetAttribute("Sweeper") then
				table.insert(sweepers, {
					part = desc, pos = desc.Position,
					pivotX = desc:GetAttribute("PivotX") or desc.Position.X,
					pivotZ = desc:GetAttribute("PivotZ") or desc.Position.Z,
					speed = desc:GetAttribute("SweepSpeed") or 1.2,
				})
			end
			if desc:GetAttribute("VanishPhase") ~= nil then
				table.insert(vanishTiles, { part = desc, phase = desc:GetAttribute("VanishPhase") })
			end
			if desc:GetAttribute("ConvZ") then
				table.insert(conveyors, { part = desc, z = desc:GetAttribute("ConvZ") })
			end
			if desc:GetAttribute("Bounce") then
				local power = desc:GetAttribute("Bounce")
				desc.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					local hrp = hit.Parent and hit.Parent:FindFirstChild("HumanoidRootPart")
					if player and hrp then
						local key = player.UserId .. "_" .. desc:GetDebugId()
						local now = os.clock()
						if not bounceCooldown[key] or now - bounceCooldown[key] > 0.35 then
							bounceCooldown[key] = now
							local v = hrp.AssemblyLinearVelocity
							hrp.AssemblyLinearVelocity = Vector3.new(v.X, power, v.Z)
						end
					end
				end)
			end
			if desc:GetAttribute("IsBattery") then
				desc.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					local run = player and runs[player]
					if run and run.battery and run.battery < 100 then
						batteryCooldown[player] = batteryCooldown[player] or {}
						local now = os.clock()
						if now - (batteryCooldown[player][desc] or 0) > 8 then
							batteryCooldown[player][desc] = now
							run.battery = math.min(100, run.battery + Config.BATTERY_PICKUP_PCT)
							StageService.toast(player, "🔋 +" .. Config.BATTERY_PICKUP_PCT .. "% battery! (" .. math.floor(run.battery) .. "%)")
						end
					end
				end)
			end
			if desc:GetAttribute("IsStar") then
				table.insert(spinStars, { part = desc, base = desc.Position, phase = math.random() * 6 })
				local starKey = desc:GetAttribute("StarKey")
				desc.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					local run = player and runs[player]
					if run and run.world * 1000 + run.stage == starKey and not run.stars[desc] then
						run.stars[desc] = true
						StageService.toast(player, "⭐ Star! (+25% stage bonus)")
					end
				end)
			end
			if desc:GetAttribute("StageStart") then
				local idx = desc:GetAttribute("StageStart")
				local world = desc:GetAttribute("World") or 1
				desc.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if player then
						StageService.checkpoints[player] = desc.CFrame + Vector3.new(0, 3, 0)
						StageService.armed[player] = StageService.armed[player] or {}
						StageService.armed[player][world * 1000 + idx] = true
						-- start a fresh timed run (re-touching mid-run keeps it)
						local run = runs[player]
						if not run or run.world ~= world or run.stage ~= idx then
							runs[player] = { world = world, stage = idx, startT = os.clock(), falls = 0, stars = {} }
							local drain = batteryStages[world * 1000 + idx]
							if drain then
								runs[player].battery = 100
								runs[player].drain = drain
								StageService.toast(player, "🔋 Power-save stage! Watch your battery — grab 🔋 cells!")
							end
						end
					end
				end)
			elseif desc:GetAttribute("MidStart") then
				local idx = desc:GetAttribute("MidStart")
				local world = desc:GetAttribute("World") or 1
				desc.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if player then
						StageService.checkpoints[player] = desc.CFrame + Vector3.new(0, 3, 0)
						StageService.armed[player] = StageService.armed[player] or {}
						StageService.armed[player][world * 1000 + idx] = true
					end
				end)
			elseif desc:GetAttribute("StageWin") then
				local idx = desc:GetAttribute("StageWin")
				local world = desc:GetAttribute("World") or 1
				desc.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					local key = world * 1000 + idx
					if player and StageService.armed[player] and StageService.armed[player][key] then
						StageService.armed[player][key] = false
						StageService.claimStage(player, idx, world)
					end
				end)
			elseif desc:GetAttribute("IsKill") then
				desc.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if player then
						StageService.teleportToCheckpoint(player)
					end
				end)
			elseif desc:GetAttribute("IsPortal") then
				local targetWorld = desc:GetAttribute("IsPortal")
				desc.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if player then
						usePortal(player, targetWorld)
					end
				end)
			end
		end
	end

	-- v8 mechanics animation: movers, sweepers, vanish cycle, conveyors, stars
	local lastVanishCycle = -1
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, m in movers do
			local off = math.sin(t * m.speed + m.phase) * m.range
			if m.axis == "Y" then
				m.part.CFrame = m.base * CFrame.new(0, off, 0)
			else
				m.part.CFrame = m.base * CFrame.new(off, 0, 0)
			end
		end
		for _, sw in sweepers do
			sw.part.CFrame = CFrame.new(sw.pivotX, sw.pos.Y, sw.pivotZ) * CFrame.Angles(0, t * sw.speed, 0)
		end
		local cycle = math.floor(t / 1.1) % 3
		if cycle ~= lastVanishCycle then
			lastVanishCycle = cycle
			for _, tile in vanishTiles do
				local solid = tile.phase == cycle
				tile.part.CanCollide = solid
				tile.part.Transparency = solid and 0 or 0.65
			end
		end
		for _, st in spinStars do
			st.part.Position = st.base + Vector3.new(0, math.sin(t * 2 + st.phase) * 0.3, 0)
		end
		if #conveyors > 0 then
			for _, player in Players:GetPlayers() do
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then
					for _, belt in conveyors do
						local bp = belt.part.Position
						local bs = belt.part.Size
						if math.abs(hrp.Position.X - bp.X) < bs.X / 2 + 0.5
							and math.abs(hrp.Position.Z - bp.Z) < bs.Z / 2 + 0.5
							and hrp.Position.Y > bp.Y and hrp.Position.Y < bp.Y + 3.2 then
							local v = hrp.AssemblyLinearVelocity
							hrp.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, belt.z)
						end
					end
				end
			end
		end
	end)

	-- Battery drain (boss stages): hits 0% -> run fails to the checkpoint.
	RunService.Heartbeat:Connect(function(dt)
		for _, player in Players:GetPlayers() do
			local run = runs[player]
			if run and run.battery then
				run.battery -= (run.drain or Config.BATTERY_DRAIN_PCT) * dt
				if run.battery <= 50 and not run.warn50 then
					run.warn50 = true
					StageService.toast(player, "🪫 Battery at 50%! Find a 🔋 cell!")
				end
				if run.battery <= 25 and not run.warn25 then
					run.warn25 = true
					StageService.toast(player, "🪫⚠️ Battery at 25%!")
				end
				if run.battery <= 0 then
					runs[player] = nil
					StageService.toast(player, "🔋 Battery empty! Back to the checkpoint — try again!")
					StageService.teleportToCheckpoint(player)
				end
			end
		end
	end)

	-- Gate enforcement per world: crossing a gate plane without the speed
	-- bounces you back. Stages you already cleared stay open to you.
	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			local data = DataService.profiles[player]
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if data and hrp then
				local level = Economy.levelFor(data.TotalEarned)
				for world = 1, 2 do
					local offset = WORLD_OFFSETS[world]
					local maxStage = world == 2 and (data.MaxStageW2 or 0) or data.MaxStage
					for i = 1, Economy.stageCount(world) do
						local gateZ = offset - Config.STAGE_SPACING * (i - 1) - 20
						if hrp.Position.Z < gateZ - 1.5 and hrp.Position.Z > gateZ - 30 then
							local req = Economy.stageLevelReq(i, world)
							if i > maxStage and level < req then
								hrp.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y, gateZ + 4)
								hrp.AssemblyLinearVelocity = Vector3.zero
								StageService.toast(player, "🧱 Stage " .. i .. " needs Level " .. req .. "!")
							end
							break
						end
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		StageService.checkpoints[player] = nil
		StageService.armed[player] = nil
		portalCooldown[player] = nil
		runs[player] = nil
		batteryCooldown[player] = nil
	end)
end

return StageService
