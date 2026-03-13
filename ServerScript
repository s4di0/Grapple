print("Grapple (SERVER) Engine Online")

local Tool = script.Parent
local Remote = Tool:WaitForChild("GrappleRemote")

-- core services we need for physics + cleanup
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Workspace = workspace

-- configuration table so values are easy to tweak
local Config = {
	MaxDistance = 10000, -- how far the grapple can reach
	MinDistance = 6,     -- prevents weird self-grappling
	StopDistance = 10,   -- how close before we stop pulling
	Cooldown = 1.0,      -- prevents spam
	PullAcceleration = 1000, -- strength of pull force
	ArcBoost = 60,       -- small upward boost for movement feel
	Mode = "Balanced"    -- balancing mode
}

-- stores cooldown state per player
local Cooldowns = {}

-- stores active grapple objects so we can clean them properly
local Active = {}

-- GETTER functions (just keeping things organized)

local function getCharacter(player)
	return player.Character
end

local function getRoot(character)
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart") -- R6 root part
end

local function getHumanoid(character)
	if not character then return nil end
	return character:FindFirstChildOfClass("Humanoid")
end

-- checks if player can grapple again
local function isReady(player)
	return not Cooldowns[player]
end

-- starts cooldown timer
local function startCooldown(player)
	Cooldowns[player] = true
	task.delay(Config.Cooldown, function()
		Cooldowns[player] = nil
	end)
end

-- removes all grapple-related objects safely
local function removeGrapple(player)

	local data = Active[player]
	if not data then return end

	-- destroy any created physics objects
	if data.force then data.force:Destroy() end
	if data.attach then data.attach:Destroy() end
	if data.beam then data.beam:Destroy() end
	if data.rope then data.rope:Destroy() end
	if data.anchor then data.anchor:Destroy() end

	Active[player] = nil
end

-- creates pulling force using VectorForce
local function createForce(root)

	local attachment = Instance.new("Attachment")
	attachment.Parent = root

	local force = Instance.new("VectorForce")
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Parent = root

	return force, attachment
end

-- creates visible beam effect between player and target
local function createBeam(root, targetPosition)

	local startAttachment = Instance.new("Attachment")
	startAttachment.Parent = root

	-- invisible anchor part placed at hit position
	local anchor = Instance.new("Part")
	anchor.Size = Vector3.new(1,1,1)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Position = targetPosition
	anchor.Parent = Workspace

	Debris:AddItem(anchor, 6) -- auto cleanup

	local endAttachment = Instance.new("Attachment")
	endAttachment.Parent = anchor

	local beam = Instance.new("Beam")
	beam.Attachment0 = startAttachment
	beam.Attachment1 = endAttachment
	beam.Width0 = 0.2
	beam.Width1 = 0.2
	beam.FaceCamera = true
	beam.Parent = root

	return beam, startAttachment, anchor
end

-- main grapple function
local function launch(player, targetPosition)

	-- prevent spam
	if not isReady(player) then return end

	local character = getCharacter(player)
	if not character then return end

	local root = getRoot(character)
	if not root then return end

	local humanoid = getHumanoid(character)
	if not humanoid then return end

	-- calculate direction toward click
	local direction = (targetPosition - root.Position).Unit * Config.MaxDistance
	local distance = direction.Magnitude

	-- ignore if too close
	if distance < Config.MinDistance then return end

	startCooldown(player)
	removeGrapple(player)

	-- raycast to ensure we only hit real surfaces
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character}
	rayParams.IgnoreWater = true

	local rayResult = Workspace:Raycast(root.Position, direction, rayParams)

	-- stop if nothing was hit (no air grappling)
	if not rayResult then
		return
	end

	local hitPosition = rayResult.Position

	-- small upward boost for movement feel
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(
		velocity.X,
		Config.ArcBoost,
		velocity.Z
	)

	-- client effects
	Remote:FireClient(player, "shake")
	Remote:FireClient(player, "wind")

	-- swing mode uses rope physics
	if Config.Mode == "Swing" then

		local rope = Instance.new("RopeConstraint")
		local attachA = Instance.new("Attachment")
		attachA.Parent = root

		local anchor = Instance.new("Part")
		anchor.Size = Vector3.new(1,1,1)
		anchor.Anchored = true
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.Position = hitPosition
		anchor.Parent = Workspace

		Debris:AddItem(anchor,6)

		local attachB = Instance.new("Attachment")
		attachB.Parent = anchor

		rope.Attachment0 = attachA
		rope.Attachment1 = attachB
		rope.Length = distance * 1.02
		rope.Visible = true
		rope.Parent = root

		Active[player] = { rope = rope, anchor = anchor }

		return
	end

	-- normal pull mode
	local force, attach = createForce(root)
	local beam, beamAttach, anchor = createBeam(root, hitPosition)

	Active[player] = {
		force = force,
		attach = attach,
		beam = beam,
		anchor = anchor
	}

	-- smooth pulling loop
	local connection
	connection = RunService.Heartbeat:Connect(function()

		if not root.Parent then
			connection:Disconnect()
			removeGrapple(player)
			return
		end

		local toTarget = hitPosition - root.Position
		local dist = toTarget.Magnitude

		-- stop when close enough
		if dist <= Config.StopDistance then
			connection:Disconnect()
			removeGrapple(player)
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
		local desired = toTarget.Unit * acceleration * root.AssemblyMass
		force.Force = desired

	end)
end

-- remote communication from client
Remote.OnServerEvent:Connect(function(player, action, data)
	if action == "grapple" then
		launch(player, data)
	elseif action == "cancel" then
		removeGrapple(player)
	end
end)

-- cleanup when player leaves
Players.PlayerRemoving:Connect(function(player)
	removeGrapple(player)
	Cooldowns[player] = nil
end)

-- cleanup when tool unequips
Tool.Unequipped:Connect(function()
	for player in pairs(Active) do
		removeGrapple(player)
	end
end)

-- safety check loop to prevent leftover grapples
RunService.Heartbeat:Connect(function()
	for player in pairs(Active) do
		local char = getCharacter(player)
		if not char then
			removeGrapple(player)
		end
	end
end)
