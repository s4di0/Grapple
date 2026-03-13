local Tool = script.Parent
local Remote = Tool:WaitForChild("GrappleRemote")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local mouse
local clickConnection

local character
local humanoid
local animator

local walkTrack
local jumpTrack
local grappleTrack
local flyTrack

-- camera getter

local function getCamera()
	return workspace.CurrentCamera
end

-- screen shake while grappling

local function screenShake()

	local camera = getCamera()
	if not camera then return end

	local duration = 0.25
	local startTime = tick()

	local connection
	connection = RunService.RenderStepped:Connect(function()

		if tick() - startTime > duration then
			connection:Disconnect()
			return
		end

		local intensity = 0.35

		local shakeOffset = Vector3.new(
			(math.random() - 0.5) * intensity,
			(math.random() - 0.5) * intensity,
			0
		)

		camera.CFrame = camera.CFrame * CFrame.new(shakeOffset)

	end)

end


-- wind sound woooooooooooshhhhhhhhhhhhh

local function playWindSound()

	local camera = getCamera()
	if not camera then return end

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://107218267655793"
	sound.Volume = 1
	sound.Parent = camera
	sound:Play()

	Debris:AddItem(sound, 3)

end

-- animations WOAHHHH

local function setupAnimations()

	if not character then return end

	humanoid = character:WaitForChild("Humanoid")

	animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local walkAnim = Tool:WaitForChild("WalkAnim")
	local jumpAnim = Tool:WaitForChild("JumpAnim")
	local grappleAnim = Tool:WaitForChild("GrappleAnim")
	local flyAnim = Tool:WaitForChild("GrappleFlyAnim")

	walkTrack = animator:LoadAnimation(walkAnim)
	jumpTrack = animator:LoadAnimation(jumpAnim)
	grappleTrack = animator:LoadAnimation(grappleAnim)
	flyTrack = animator:LoadAnimation(flyAnim)

	-- set priorities (VERY important)
	walkTrack.Priority = Enum.AnimationPriority.Movement
	jumpTrack.Priority = Enum.AnimationPriority.Action
	grappleTrack.Priority = Enum.AnimationPriority.Action
	flyTrack.Priority = Enum.AnimationPriority.Action

	print("Animations loaded successfully ✨")

end

-- tool equipped

Tool.Equipped:Connect(function()

	character = player.Character or player.CharacterAdded:Wait()

	setupAnimations()

	mouse = player:GetMouse()

	clickConnection = mouse.Button1Down:Connect(function()
		if mouse and mouse.Target then
			Remote:FireServer("grapple", mouse.Hit.Position)

			if grappleTrack then
				grappleTrack:Play()
			end
		end
	end)

end)

-- tool unequipped

Tool.Unequipped:Connect(function()

	if clickConnection then
		clickConnection:Disconnect()
		clickConnection = nil
	end

end)

-- server effects

Remote.OnClientEvent:Connect(function(effect)

	if effect == "shake" then
		screenShake()

	elseif effect == "wind" then
		playWindSound()

	end

end)

-- respawn 

player.CharacterAdded:Connect(function(char)

	character = char
	task.wait(0.2)
	setupAnimations()

end)


print("Grapple client ready 🕷️")
