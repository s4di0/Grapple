print("grapple server live")

local tool = script.Parent
local remote = tool:WaitForChild("GrappleRemote")

local players = game:GetService("Players")
local runService = game:GetService("RunService")
local debris = game:GetService("Debris")

-- tuned during testing, not final
local MAX_RANGE = 10000
local MIN_RANGE = 6
local STOP_DIST = 10
local COOLDOWN_TIME = 1

local BASE_FORCE = 1000
local UPWARD_KICK = 60

local MODE = "Balanced" -- swapped a lot while testing

local cooldown = {}
local active = {}

local function getRoot(plr)
	local char = plr.Character
	if not char then return end
	return char:FindFirstChild("HumanoidRootPart")
end

local function clear(plr)
	local data = active[plr]
	if not data then return end

	if data.force then data.force:Destroy() end
	if data.att then data.att:Destroy() end
	if data.beam then data.beam:Destroy() end
	if data.rope then data.rope:Destroy() end
	if data.anchor then data.anchor:Destroy() end

	active[plr] = nil
end

local function applyCooldown(plr)
	cooldown[plr] = true
	task.delay(COOLDOWN_TIME, function()
		cooldown[plr] = nil
	end)
end

local function makeForce(root)
	local att = Instance.new("Attachment")
	att.Parent = root

	local vf = Instance.new("VectorForce")
	vf.Attachment0 = att
	vf.RelativeTo = Enum.ActuatorRelativeTo.World
	vf.ApplyAtCenterOfMass = true
	vf.Parent = root

	return vf, att
end

local function makeBeam(root, pos)
	local a0 = Instance.new("Attachment")
	a0.Parent = root

	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1,1,1)
	anchor.Position = pos
	anchor.Parent = workspace

	debris:AddItem(anchor, 6)

	local a1 = Instance.new("Attachment")
	a1.Parent = anchor

	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.2
	beam.Width1 = 0.2
	beam.FaceCamera = true
	beam.Parent = root

	return beam, a0, anchor
end

local function fire(plr, targetPos)
	if cooldown[plr] then return end

	local root = getRoot(plr)
	if not root then return end

	local dir = (targetPos - root.Position).Unit * MAX_RANGE
	local dist = dir.Magnitude

	if dist < MIN_RANGE then return end

	applyCooldown(plr)
	clear(plr)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {plr.Character}
	params.IgnoreWater = true

	local result = workspace:Raycast(root.Position, dir, params)
	if not result then return end

	local hit = result.Position

	-- quick pop upward so it doesn't feel flat
	local vel = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(vel.X, UPWARD_KICK, vel.Z)

	remote:FireClient(plr, "shake")
	remote:FireClient(plr, "wind")

	if MODE == "Swing" then
		local rope = Instance.new("RopeConstraint")

		local a0 = Instance.new("Attachment")
		a0.Parent = root

		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.Size = Vector3.new(1,1,1)
		anchor.Position = hit
		anchor.Parent = workspace

		debris:AddItem(anchor, 6)

		local a1 = Instance.new("Attachment")
		a1.Parent = anchor

		rope.Attachment0 = a0
		rope.Attachment1 = a1
		rope.Length = dist * 1.02
		rope.Visible = true
		rope.Parent = root

		active[plr] = {rope = rope, anchor = anchor}
		return
	end

	local force, att = makeForce(root)
	local beam, _, anchor = makeBeam(root, hit)

	active[plr] = {
		force = force,
		att = att,
		beam = beam,
		anchor = anchor
	}

	local conn
	conn = runService.Heartbeat:Connect(function()
		if not root.Parent then
			conn:Disconnect()
			clear(plr)
			return
		end

		local delta = hit - root.Position
		local d = delta.Magnitude

		if d <= STOP_DIST then
			conn:Disconnect()
			clear(plr)
			return
		end

		local accel = BASE_FORCE

		if MODE == "Arcade" then
			accel *= 1.35
		elseif MODE == "Competitive" then
			accel *= 0.85
		end

		force.Force = delta.Unit * accel * root.AssemblyMass
	end)
end

remote.OnServerEvent:Connect(function(plr, action, data)
	if action == "grapple" then
		fire(plr, data)
	elseif action == "cancel" then
		clear(plr)
	end
end)

players.PlayerRemoving:Connect(function(plr)
	clear(plr)
	cooldown[plr] = nil
end)

tool.Unequipped:Connect(function()
	for plr in pairs(active) do
		clear(plr)
	end
end)

runService.Heartbeat:Connect(function()
	for plr in pairs(active) do
		if not plr.Character then
			clear(plr)
		end
	end
end)
