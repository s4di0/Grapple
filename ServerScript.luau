print("ServerScript Grapple Test")

local Grapple = script.Parent
local Remote = Grapple:WaitForChild("GrappleRemote")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

-- SETTINGS
local Config = {
	MaxDistance = 10000, -- MAX RANGE
	MinDistance = 6,     -- MIN RANGE
	StopDistance = 10,   -- PULL DISTANCE
	Cooldown = 1.0,      -- PREVENT SPAM
	PullAcceleration = 1000, -- PULL FORCE
	ArcBoost = 60,       -- UPWARD BOOST
	Mode = "Balanced"    -- BALANCE MODE
}

local Cooldowns = {} -- COOLDOWN PER PLAYER
local Active = {} -- GRAPPLE STORAGE 

-- GETTERS

local function GetCharacter(Plr)
	return Plr.Character
end

local function GetRoot(Character)
	if not Character then return nil end
	return Character:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid(Character)
	if not Character then return nil end
	return Character:FindFirstChildOfClass("Humanoid")
end

-- CHECK FOR COOLDOWN
local function IsReady(Plr)
	return not Cooldowns[Plr]
end

-- COOLDOWN TIMER
local function StartCooldown(Plr)
	Cooldowns[Plr] = true
	task.delay(Config.Cooldown, function()
		Cooldowns[Plr] = nil
	end)
end

-- REMOVAL OF GRAPPLE
local function RemoveGrapple(Plr)

	local Data = Active[Plr]
	if not Data then return end

	if Data.force then Data.force:Destroy() end
	if Data.attach then Data.attach:Destroy() end
	if Data.beam then Data.beam:Destroy() end
	if Data.rope then Data.rope:Destroy() end
	if Data.anchor then Data.anchor:Destroy() end
	Active[Plr] = nil
end

-- pulling force using VectorForce
local function createForce(Root)

	local attachment = Instance.new("Attachment")
	attachment.Parent = Root

	local force = Instance.new("VectorForce")
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Parent = Root
	return force, attachment
end

-- visible beam effect between player and target
local function BeamCreation(Root, TargetPosition)

	local StartAttachment = Instance.new("Attachment")
	StartAttachment.Parent = Root

	-- invisible anchor part placed at hit position
	local anchor = Instance.new("Part")
	anchor.Size = Vector3.new(1,1,1)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Position = TargetPosition
	anchor.Parent = Workspace

	Debris:AddItem(anchor, 6) --  cleanup

	local endAttachment = Instance.new("Attachment")
	endAttachment.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Attachment0 = StartAttachment
	beam.Attachment1 = endAttachment
	beam.Width0 = 0.2
	beam.Width1 = 0.2
	beam.FaceCamera = true
	beam.Parent = Root
	return beam, StartAttachment, anchor
end

-- main grapple function
local function launch(Plr, TargetPosition)

	-- prevent spam
	if not IsReady(Plr) then return end

	local Character = GetCharacter(Plr)
	if not Character then return end

	local Root = GetRoot(Character)
	if not Root then return end

	local humanoid = GetHumanoid(Character)
	if not humanoid then return end

	-- calculate direction toward click
	local direction = (TargetPosition - Root.Position).Unit * Config.MaxDistance
	local distance = direction.Magnitude

	-- ignore if too close
	if distance < Config.MinDistance then return end

	StartCooldown(Plr)
	RemoveGrapple(Plr)

	-- raycast to ensure we only hit real surfaces
	local RParams = RaycastParams.new()
	RParams.FilterType = Enum.RaycastFilterType.Exclude
	RParams.FilterDescendantsInstances = {Character}
	RParams.IgnoreWater = true

	local Result = Workspace:Raycast(Root.Position, direction, RParams)

	-- stop if nothing was hit (no air grappling)
	if not Result then
		return
	end

	local HitPosition = Result.Position

	-- small upward boost for movement feel
	local velocity = Root.AssemblyLinearVelocity
	Root.AssemblyLinearVelocity = Vector3.new(
		velocity.X,
		Config.ArcBoost,
		velocity.Z
	)

	-- effects
	Remote:FireClient(Plr, "shake")
	Remote:FireClient(Plr, "wind")

	-- swing mode uses rope physics
	if Config.Mode == "Swing" then

		local rope = Instance.new("RopeConstraint")
		local attachA = Instance.new("Attachment")
		attachA.Parent = Root

		local anchor = Instance.new("Part")
		anchor.Size = Vector3.new(1,1,1)
		anchor.Anchored = true
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.Position = HitPosition
		anchor.Parent = Workspace

		Debris:AddItem(anchor,6)

		local attachB = Instance.new("Attachment")
		attachB.Parent = anchor

		rope.Attachment0 = attachA
		rope.Attachment1 = attachB
		rope.Length = distance * 1.02
		rope.Visible = true
		rope.Parent = Root

		Active[Plr] = { rope = rope, anchor = anchor }

		return
	end

	-- normal pull mode
	local force, attach = createForce(Root)
	local beam, beamAttach, anchor = BeamCreation(Root, HitPosition)

	Active[Plr] = {
		force = force,
		attach = attach,
		beam = beam,
		anchor = anchor
	}

	-- smooth pulling loop
	local connection
	connection = RunService.Heartbeat:Connect(function()

		if not Root.Parent then
			connection:Disconnect()
			RemoveGrapple(Plr)
			return
		end

		local toTarget = HitPosition - Root.Position
		local dist = toTarget.Magnitude

		-- stop when close enough
		if dist <= Config.StopDistance then
			connection:Disconnect()
			RemoveGrapple(Plr)
			return
		end

		local acceleration = Config.PullAcceleration

		-- mode adjustments
		if Config.Mode == "Arcade" then
			acceleration *= 1.35
		elseif Config.Mode == "Competitive" then
			acceleration *= 0.85
		end

		-- apply force toward hit position
		local desired = toTarget.Unit * acceleration * Root.AssemblyMass
		force.Force = desired

	end)
end

-- remote communication from client
Remote.OnServerEvent:Connect(function(Plr, action, Data)
	if action == "grapple" then
		launch(Plr, Data)
	elseif action == "cancel" then
		RemoveGrapple(Plr)
	end
end)

-- cleanup when player leaves
Players.PlayerRemoving:Connect(function(Plr)
	RemoveGrapple(Plr)
	Cooldowns[Plr] = nil
end)

-- cleanup when Grapple unequips
Grapple.Unequipped:Connect(function()
	for Plr in pairs(Active) do
		RemoveGrapple(Plr)
	end
end)

-- safety check loop to prevent leftover grapples
RunService.Heartbeat:Connect(function()
	for Plr in pairs(Active) do
		local char = GetCharacter(Plr)
		if not char then
			RemoveGrapple(Plr)
		end
	end
end)
