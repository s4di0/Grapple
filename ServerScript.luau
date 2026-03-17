-- GRAPPLE SCRPT

print("ServerScript run test")

local Grapple = script.Parent
local Remote = Grapple:WaitForChild("GrappleRemote")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

-- tuning values
local MAX_DISTANCE = 10000
local MIN_DISTANCE = 6
local STOP_DISTANCE = 10
local COOLDOWN = 1

local PULL_FORCE = 1000
local ARC_BOOST = 60

local MODE = "Balanced" -- change while testing if needed

local cooldowns = {}
local active = {}

-- getters
local function GetCharacter(plr)
	if not plr then return nil end
	return plr.Character
end

local function GetRoot(char)
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid(char)
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

local function IsOnCooldown(plr)
	return cooldowns[plr] == true
end

local function StartCooldown(plr)
	cooldowns[plr] = true
	task.delay(COOLDOWN, function()
		cooldowns[plr] = nil
	end)
end

local function Cleanup(plr)
	local data = active[plr]
	if not data then return end

	if data.force then data.force:Destroy() end
	if data.attach then data.attach:Destroy() end
	if data.beam then data.beam:Destroy() end
	if data.rope then data.rope:Destroy() end
	if data.anchor then data.anchor:Destroy() end

	active[plr] = nil
end

local function MakeForce(root)
	local att = Instance.new("Attachment")
	att.Name = "GrappleAttachment"
	att.Parent = root

	local vf = Instance.new("VectorForce")
	vf.Name = "GrappleForce"
	vf.Attachment0 = att
	vf.RelativeTo = Enum.ActuatorRelativeTo.World
	vf.ApplyAtCenterOfMass = true
	vf.Parent = root

	return vf, att
end

local function MakeBeam(root, pos)
	local startAtt = Instance.new("Attachment")
	startAtt.Name = "BeamStart"
	startAtt.Parent = root

	local anchor = Instance.new("Part")
	anchor.Size = Vector3.new(1,1,1)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Position = pos
	anchor.Parent = workspace

	Debris:AddItem(anchor, 6)

	local endAtt = Instance.new("Attachment")
	endAtt.Name = "BeamEnd"
	endAtt.Parent = anchor

	local beam = Instance.new("Beam")
	beam.Attachment0 = startAtt
	beam.Attachment1 = endAtt
	beam.Width0 = 0.2
	beam.Width1 = 0.2
	beam.FaceCamera = true
	beam.Parent = root

	return beam, startAtt, anchor
end

local function Launch(plr, targetPos)
	if IsOnCooldown(plr) then return end

	local char = GetCharacter(plr)
	if not char then return end

	local root = GetRoot(char)
	if not root then return end

	local humanoid = GetHumanoid(char)
	if not humanoid then return end

	local direction = targetPos - root.Position
	if direction.Magnitude <= 0 then return end

	local distance = direction.Magnitude
	if distance < MIN_DISTANCE then return end

	StartCooldown(plr)
	Cleanup(plr)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char}
	params.IgnoreWater = true

	local result = workspace:Raycast(root.Position, direction.Unit * MAX_DISTANCE, params)
	if not result then return end

	local hitPos = result.Position

	-- small upward boost so it feels less stiff
	local vel = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(vel.X, ARC_BOOST, vel.Z)

	Remote:FireClient(plr, "shake")
	Remote:FireClient(plr, "wind")

	if MODE == "Swing" then
		local rope = Instance.new("RopeConstraint")

		local a0 = Instance.new("Attachment")
		a0.Parent = root

		local anchor = Instance.new("Part")
		anchor.Size = Vector3.new(1,1,1)
		anchor.Anchored = true
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.Position = hitPos
		anchor.Parent = workspace

		Debris:AddItem(anchor, 6)

		local a1 = Instance.new("Attachment")
		a1.Parent = anchor

		rope.Attachment0 = a0
		rope.Attachment1 = a1
		rope.Length = distance * 1.02
		rope.Visible = true
		rope.Parent = root

		active[plr] = { rope = rope, anchor = anchor }
		return
	end

	local force, attach = MakeForce(root)
	local beam, _, anchor = MakeBeam(root, hitPos)

	active[plr] = { force = force, attach = attach, beam = beam, anchor = anchor }

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not root or not root.Parent then
			connection:Disconnect()
			Cleanup(plr)
			return
		end

		local offset = hitPos - root.Position
		local dist = offset.Magnitude

		if dist <= STOP_DISTANCE then
			connection:Disconnect()
			Cleanup(plr)
			return
		end

		local accel = PULL_FORCE

		if MODE == "Arcade" then
			accel *= 1.35
		elseif MODE == "Competitive" then
			accel *= 0.85
		end

		force.Force = offset.Unit * accel * root.AssemblyMass
	end)
end

Remote.OnServerEvent:Connect(function(plr, action, data)
	if action == "grapple" then
		Launch(plr, data)
	elseif action == "cancel" then
		Cleanup(plr)
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	Cleanup(plr)
	cooldowns[plr] = nil
end)

Grapple.Unequipped:Connect(function()
	for plr in pairs(active) do
		Cleanup(plr)
	end
end)
