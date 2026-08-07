-- ====================================================================
-- MM2 GUN & C4 SCRIPT FOR DELTA EXECUTOR
-- ====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-----------------------------------------------------------------------
-- CONFIGURATION
-----------------------------------------------------------------------
local CONFIG = {
	GunName = "Matrixscope",                  
	LaserColor = Color3.fromRGB(0, 180, 60),  
	LaserDuration = 0.2,                       
	Cooldown = 0.2,                           
	ShootSound = "rbxassetid://8561500387",    
	ReloadSound = "rbxassetid://8561502124",    
	ClickSound = "rbxassetid://124247245989090",
	
	MeshId = "rbxassetid://6224425",
	ButtonImageId = "rbxassetid://124720308473109",
	ToolTextureId = "rbxassetid://124720308473109",
	GunMeshId = "rbxassetid://124720308473109",
	
	-- C4 Config
	C4Cooldown = 2,
	C4CanUse = true
}

local CurrentDroppedBomb = nil

-- Hàm tạo Part C4 duy nhất
local function BuildC4()
	local Main = Instance.new("Part")
	Main.Name = "Handle"
	Main.Size = Vector3.new(1.8, 0.7, 1.2)
	Main.Color = Color3.fromRGB(255, 180, 50)
	Main.Material = Enum.Material.Metal
	Main.CanCollide = true
	return Main
end

-----------------------------------------------------------------------
-- REMOTE EVENT INITIALIZATION
-----------------------------------------------------------------------
local RemoteName = "MM2_SharedGunRemote"
local remoteEvent = ReplicatedStorage:FindFirstChild(RemoteName)

if not remoteEvent then
	remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = RemoteName
	remoteEvent.Parent = ReplicatedStorage
end

-----------------------------------------------------------------------
-- SHIFTLOCK & CAMERA SYSTEM
-----------------------------------------------------------------------
local isShiftLockEnabled = false
local shiftLockConnection = nil

local function toggleShiftLock(enable)
	isShiftLockEnabled = enable
	
	if shiftLockConnection then
		shiftLockConnection:Disconnect()
		shiftLockConnection = nil
	end

	if isShiftLockEnabled then
		shiftLockConnection = RunService.RenderStepped:Connect(function()
			local character = LocalPlayer.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				local rootPart = character.HumanoidRootPart
				
				local cameraCFrame = Camera.CFrame
				local lookVector = Vector3.new(cameraCFrame.LookVector.X, 0, cameraCFrame.LookVector.Z).Unit
				
				rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + lookVector)
				Camera.CFrame = cameraCFrame + (cameraCFrame.RightVector * 1.75)
			end
		end)
	end
end

-----------------------------------------------------------------------
-- MULTI-DUMMY SYSTEM (BACON HAIR DUMMIES)
-----------------------------------------------------------------------
local activeDummies = {}
local dummyMovementThreads = {}
local isDummyMovementEnabled = true
local isDummyJumpEnabled = false
local currentDummySpeed = 16 
local currentSpawnCount = 5 

local function stopAllDummyThreads()
	for _, thread in ipairs(dummyMovementThreads) do
		task.cancel(thread)
	end
	dummyMovementThreads = {}
end

local function clearAllDummies()
	stopAllDummyThreads()
	for _, dummy in ipairs(activeDummies) do
		if dummy and dummy.Parent then
			dummy:Destroy()
		end
	end
	activeDummies = {}
end

local function killAllDummies()
	for _, dummy in ipairs(activeDummies) do
		if dummy and dummy.Parent then
			local humanoid = dummy:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = 0
			end
			local head = dummy:FindFirstChild("Head")
			if head then 
				head.Color = Color3.fromRGB(255, 50, 50) 
			end
		end
	end
	
	task.delay(0.3, function()
		clearAllDummies()
	end)
end

local function spawnSingleDummy(spawnCFrame)
	local character = LocalPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	local dummy = Instance.new("Model")
	dummy.Name = "Bacon Dummy"

	local tag = Instance.new("BoolValue")
	tag.Name = "IsClientDummy"
	tag.Parent = dummy

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.WalkSpeed = currentDummySpeed
	humanoid.JumpPower = 50
	humanoid.Parent = dummy

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.CFrame = spawnCFrame
	rootPart.Transparency = 1
	rootPart.CanCollide = false
	rootPart.Parent = dummy
	dummy.PrimaryPart = rootPart

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.CFrame = spawnCFrame
	torso.Color = Color3.fromRGB(45, 45, 45)
	torso.Material = Enum.Material.SmoothPlastic
	torso.Parent = dummy

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.CFrame = spawnCFrame * CFrame.new(0, 1.5, 0)
	head.Color = Color3.fromRGB(248, 217, 153)
	head.Material = Enum.Material.SmoothPlastic
	head.Parent = dummy

	local meshHead = Instance.new("SpecialMesh")
	meshHead.MeshType = Enum.MeshType.Head
	meshHead.Scale = Vector3.new(1.25, 1.25, 1.25)
	meshHead.Parent = head

	local hair = Instance.new("Part")
	hair.Name = "BaconHair"
	hair.Size = Vector3.new(1, 1, 1)
	hair.CFrame = head.CFrame * CFrame.new(0, 0.3, 0)
	hair.Color = Color3.fromRGB(115, 82, 49)
	hair.Material = Enum.Material.SmoothPlastic
	hair.CanCollide = false
	hair.Parent = dummy

	local hairMesh = Instance.new("SpecialMesh")
	hairMesh.MeshId = CONFIG.MeshId
	hairMesh.Scale = Vector3.new(1.05, 1.05, 1.05)
	hairMesh.Parent = hair

	local hairWeld = Instance.new("WeldConstraint")
	hairWeld.Part0 = head
	hairWeld.Part1 = hair
	hairWeld.Parent = head

	local leftArm = Instance.new("Part")
	leftArm.Name = "Left Arm"
	leftArm.Size = Vector3.new(1, 2, 1)
	leftArm.CFrame = spawnCFrame * CFrame.new(-1.5, 0, 0)
	leftArm.Color = Color3.fromRGB(248, 217, 153)
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.Parent = dummy

	local rightArm = Instance.new("Part")
	rightArm.Name = "Right Arm"
	rightArm.Size = Vector3.new(1, 2, 1)
	rightArm.CFrame = spawnCFrame * CFrame.new(1.5, 0, 0)
	rightArm.Color = Color3.fromRGB(248, 217, 153)
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.Parent = dummy

	local leftLeg = Instance.new("Part")
	leftLeg.Name = "Left Leg"
	leftLeg.Size = Vector3.new(1, 2, 1)
	leftLeg.CFrame = spawnCFrame * CFrame.new(-0.5, -2, 0)
	leftLeg.Color = Color3.fromRGB(29, 71, 123)
	leftLeg.Material = Enum.Material.SmoothPlastic
	leftLeg.Parent = dummy

	local rightLeg = Instance.new("Part")
	rightLeg.Name = "Right Leg"
	rightLeg.Size = Vector3.new(1, 2, 1)
	rightLeg.CFrame = spawnCFrame * CFrame.new(0.5, -2, 0)
	rightLeg.Color = Color3.fromRGB(29, 71, 123)
	rightLeg.Material = Enum.Material.SmoothPlastic
	rightLeg.Parent = dummy

	local function weldParts(p0, p1)
		local w = Instance.new("WeldConstraint")
		w.Part0 = p0
		w.Part1 = p1
		w.Parent = p0
	end

	weldParts(rootPart, torso)
	weldParts(torso, head)
	weldParts(torso, leftArm)
	weldParts(torso, rightArm)
	weldParts(torso, leftLeg)
	weldParts(torso, rightLeg)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DummyTag"
	billboard.Size = UDim2.new(0, 200, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = head

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "[ BACON DUMMY ]"
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.TextSize = 15
	textLabel.Parent = billboard

	dummy.Parent = workspace
	table.insert(activeDummies, dummy)

	local thread = task.spawn(function()
		while dummy and dummy.Parent and humanoid.Health > 0 do
			humanoid.WalkSpeed = currentDummySpeed
			if isDummyMovementEnabled and rootPart then
				local randomOffset = Vector3.new(math.random(-35, 35), 0, math.random(-35, 35))
				local targetPos = rootPart.Position + randomOffset
				humanoid:MoveTo(targetPos)

				if isDummyJumpEnabled and math.random(1, 3) == 1 then
					task.wait(math.random(3, 8) / 10)
					if humanoid.Health > 0 then
						humanoid.Jump = true
					end
				end
			end
			task.wait(math.random(2, 4))
		end
	end)
	table.insert(dummyMovementThreads, thread)
end

local function spawnCustomDummies()
	clearAllDummies()
	local character = LocalPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	local hrp = character.HumanoidRootPart
	local count = currentSpawnCount

	for i = 1, count do
		local angle = (i / count) * (2 * math.pi)
		local radius = 10 + (math.floor(i / 10) * 4) 
		local offsetX = math.cos(angle) * radius
		local offsetZ = math.sin(angle) * radius
		local spawnCFrame = hrp.CFrame * CFrame.new(offsetX, 2, offsetZ)
		spawnSingleDummy(spawnCFrame)
	end
end

-----------------------------------------------------------------------
-- LASER EFFECT FUNCTION
-----------------------------------------------------------------------
local function drawLaser(origin, endPos)
	local distance = (endPos - origin).Magnitude
	local laser = Instance.new("Part")
	laser.Name = "LaserEffect"
	laser.Anchored = true
	laser.CanCollide = false
	laser.Material = Enum.Material.Neon
	laser.Color = CONFIG.LaserColor
	laser.Size = Vector3.new(0.2, 0.2, distance)
	laser.CFrame = CFrame.lookAt(origin, endPos) * CFrame.new(0, 0, -distance / 2)
	laser.Parent = workspace

	local tweenInfo = TweenInfo.new(CONFIG.LaserDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(laser, tweenInfo, {Transparency = 1, Size = Vector3.new(0, 0, distance)})
	tween:Play()

	tween.Completed:Connect(function()
		laser:Destroy()
	end)
end

-----------------------------------------------------------------------
-- EXTERNAL EVENT LISTENER
-----------------------------------------------------------------------
remoteEvent.OnClientEvent:Connect(function(action, data)
	if action == "RenderLaser" then
		drawLaser(data.Origin, data.EndPos)
	elseif action == "KillTarget" then
		if data.TargetPlayer == LocalPlayer and LocalPlayer.Character then
			local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = 0
			end
		end
	end
end)

-----------------------------------------------------------------------
-- CREATE GUN (MATRIXSCOPE MESH MODEL)
-----------------------------------------------------------------------
local isReloading = false

local function createMM2Gun()
	local tool = Instance.new("Tool")
	tool.Name = CONFIG.GunName
	tool.RequiresHandle = true
	tool.TextureId = CONFIG.ToolTextureId 
	
	tool.GripPos = Vector3.new(0, 0, 0)
	tool.GripForward = Vector3.new(0, 0, -1)
	tool.GripRight = Vector3.new(1, 0, 0)
	tool.GripUp = Vector3.new(0, 1, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Transparency = 0
	handle.CanCollide = false
	handle.Parent = tool

	local gunMesh = Instance.new("SpecialMesh")
	gunMesh.MeshType = Enum.MeshType.FileMesh
	gunMesh.MeshId = CONFIG.GunMeshId
	gunMesh.TextureId = CONFIG.GunMeshId
	gunMesh.Scale = Vector3.new(1, 1, 1)
	gunMesh.Parent = handle

	local shootSound = Instance.new("Sound")
	shootSound.Name = "ShootSound"
	shootSound.SoundId = CONFIG.ShootSound
	shootSound.Parent = handle

	local reloadSound = Instance.new("Sound")
	reloadSound.Name = "ReloadSound"
	reloadSound.SoundId = CONFIG.ReloadSound
	reloadSound.Parent = handle

	tool.Activated:Connect(function()
		if isReloading then return end
		isReloading = true

		shootSound:Play()

		local character = LocalPlayer.Character
		if not character or not character:FindFirstChild("Head") then 
			isReloading = false
			return 
		end

		local origin = handle.Position + (handle.CFrame.LookVector * 2.0)
		local direction

		if isShiftLockEnabled then
			direction = Camera.CFrame.LookVector * 500
		else
			local targetPos = Mouse.Hit.p
			direction = (targetPos - origin).Unit * 500
		end

		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {character}
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude

		local result = workspace:Raycast(origin, direction, raycastParams)
		local endPos = result and result.Position or (origin + direction)

		drawLaser(origin, endPos)
		remoteEvent:FireServer("RenderLaser", {Origin = origin, EndPos = endPos})

		if result and result.Instance then
			local hitChar = result.Instance.Parent
			
			if not hitChar:FindFirstChildOfClass("Humanoid") and hitChar.Parent:FindFirstChildOfClass("Humanoid") then
				hitChar = hitChar.Parent
			end

			local targetPlayer = Players:GetPlayerFromCharacter(hitChar)
			local targetHumanoid = hitChar:FindFirstChildOfClass("Humanoid")

			if targetPlayer and targetPlayer ~= LocalPlayer then
				remoteEvent:FireServer("KillTarget", {TargetPlayer = targetPlayer})
			elseif targetHumanoid and hitChar:FindFirstChild("IsClientDummy") then
				targetHumanoid.Health = 0

				local headPart = hitChar:FindFirstChild("Head")
				if headPart then headPart.Color = Color3.fromRGB(255, 50, 50) end

				task.delay(1.5, function()
					if hitChar and hitChar.Parent then
						hitChar:Destroy()
					end
				end)
			end
		end

		task.delay(CONFIG.Cooldown - 0.3, function()
			reloadSound:Play()
		end)

		task.delay(CONFIG.Cooldown, function()
			isReloading = false
		end)
	end)

	return tool
end

-----------------------------------------------------------------------
-- CREATE C4 TOOL
-----------------------------------------------------------------------
local function GiveC4Tool()
	local Tool = Instance.new("Tool")
	Tool.Name = "Đọc làm chó đĩ dở"
	Tool.RequiresHandle = true
	Tool.CanBeDropped = false
	Tool.Grip = CFrame.new(0, -0.2, 0.2) * CFrame.Angles(0, math.rad(180), 0)
	
	local C4Part = BuildC4()
	C4Part.Parent = Tool
	
	Tool.Activated:Connect(function()
		if not CONFIG.C4CanUse then return end
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		
		CONFIG.C4CanUse = false
		
		if CurrentDroppedBomb then CurrentDroppedBomb:Destroy() end
		
		local d_handle = BuildC4()
		d_handle.CFrame = hrp.CFrame * CFrame.new(0, -3.2, 0)
		d_handle.Parent = game.Workspace
		
		CurrentDroppedBomb = d_handle

		local bv = Instance.new("BodyVelocity", d_handle)
		bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		bv.Velocity = ((Mouse.Hit.p - hrp.Position).Unit * 25) + Vector3.new(0, 10, 0)
		
		game.Debris:AddItem(bv, 0.1)
		
		local parts = {}
		for _, p in pairs(Tool:GetChildren()) do
			if p:IsA("BasePart") then parts[p] = p.Transparency p.Transparency = 1 end
		end
		
		task.wait(CONFIG.C4Cooldown)
		
		if CurrentDroppedBomb then 
			CurrentDroppedBomb:Destroy() 
			CurrentDroppedBomb = nil
		end
		
		for p, trans in pairs(parts) do if p then p.Transparency = trans end end
		CONFIG.C4CanUse = true
	end)
	
	Tool.Parent = LocalPlayer.Backpack
end

-----------------------------------------------------------------------
-- FUNCTION: EQUIP / UNEQUIP
-----------------------------------------------------------------------
local function toggleEquipMatrixscope()
	local character = LocalPlayer.Character
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if not character or not backpack then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local gunInCharacter = character:FindFirstChild(CONFIG.GunName)
	local gunInBackpack = backpack:FindFirstChild(CONFIG.GunName)

	if gunInCharacter then
		humanoid:UnequipTools()
		return
	end

	if gunInBackpack then
		humanoid:EquipTool(gunInBackpack)
		return
	end

	local newGun = createMM2Gun()
	newGun.Parent = backpack
	humanoid:EquipTool(newGun)
end

-----------------------------------------------------------------------
-- GUI SYSTEM
-----------------------------------------------------------------------
local function setupGUI()
	local existingGui = CoreGui:FindFirstChild("WillizardGunGui") or PlayerGui:FindFirstChild("WillizardGunGui")
	if existingGui then existingGui:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WillizardGunGui"
	screenGui.ResetOnSpawn = false

	pcall(function() screenGui.Parent = CoreGui end)
	if not screenGui.Parent then screenGui.Parent = PlayerGui end

	-- MAIN PANEL (Đã tăng chiều cao một chút để chứa nút C4 mới)
	local mainPanel = Instance.new("Frame")
	mainPanel.Name = "MainPanel"
	mainPanel.Size = UDim2.new(0, 210, 0, 420)
	mainPanel.Position = UDim2.new(0.02, 0, 0.22, 0)
	mainPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	mainPanel.Active = true
	mainPanel.Draggable = true
	mainPanel.Parent = screenGui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 8)
	mainCorner.Parent = mainPanel

	-- TITLE BAR
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 35)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Made By Willizard"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.TextSize = 16
	titleLabel.Parent = mainPanel

	local titleLine = Instance.new("Frame")
	titleLine.Size = UDim2.new(0.9, 0, 0, 1)
	titleLine.Position = UDim2.new(0.05, 0, 0, 35)
	titleLine.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	titleLine.BorderSizePixel = 0
	titleLine.Parent = mainPanel

	-- BUTTON CONTAINER
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 1, -40)
	container.Position = UDim2.new(0, 0, 0, 40)
	container.BackgroundTransparency = 1
	container.Parent = mainPanel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	local function createMenuButton(name, text, order, customColor)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0.88, 0, 0, 30)
		btn.BackgroundColor3 = customColor or Color3.fromRGB(35, 35, 35)
		btn.Text = text
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Font = Enum.Font.SourceSansBold
		btn.TextSize = 12
		btn.LayoutOrder = order
		btn.Parent = container

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = btn

		return btn
	end

	local spawnBtn = createMenuButton("SpawnBtn", "Spawn Matrixscope", 1)
	
	-- NÚT SPAWN C4 MỚI TRONG MENU
	local spawnC4Btn = createMenuButton("SpawnC4Btn", "Spawn C4 Tool", 2, Color3.fromRGB(200, 140, 20))

	local shiftBtn = createMenuButton("ShiftBtn", "Shiftlock: OFF", 3)
	
	-- Ô NHẬP SỐ LƯỢNG DUMMY
	local countBox = Instance.new("TextBox")
	countBox.Name = "CountBox"
	countBox.Size = UDim2.new(0.88, 0, 0, 30)
	countBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	countBox.Text = tostring(currentSpawnCount)
	countBox.TextColor3 = Color3.fromRGB(0, 180, 60)
	countBox.Font = Enum.Font.SourceSansBold
	countBox.TextSize = 13
	countBox.PlaceholderText = "Nhập số lượng (1-100)"
	countBox.ClearTextOnFocus = false
	countBox.LayoutOrder = 4
	countBox.Parent = container

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 6)
	boxCorner.Parent = countBox

	local boxStroke = Instance.new("UIStroke")
	boxStroke.Color = Color3.fromRGB(0, 180, 60)
	boxStroke.Thickness = 1.5
	boxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	boxStroke.Parent = countBox

	countBox.FocusLost:Connect(function()
		local num = tonumber(countBox.Text)
		if num then
			num = math.floor(num)
			if num < 1 then num = 1 end
			if num > 100 then num = 100 end 
			currentSpawnCount = num
			countBox.Text = tostring(currentSpawnCount)
		else
			countBox.Text = tostring(currentSpawnCount)
		end
	end)

	local dummyBtn = createMenuButton("DummyBtn", "Spawn Bacon Dummies", 5)
	local killAllBtn = createMenuButton("KillAllBtn", "Kill All Bacons", 6, Color3.fromRGB(150, 40, 40))
	
	local speedBtn = createMenuButton("SpeedBtn", "Dummy Speed: 16", 7)
	local moveBtn = createMenuButton("MoveBtn", "Dummy Move: ON", 8)
	local jumpBtn = createMenuButton("JumpBtn", "Dummy Jump: OFF", 9)

	-- CENTER CROSSHAIR
	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.Size = UDim2.new(0, 6, 0, 6)
	crosshair.Position = UDim2.new(0.5, -3, 0.5, -3)
	crosshair.BackgroundColor3 = Color3.fromRGB(0, 180, 60)
	crosshair.Visible = false
	crosshair.Parent = screenGui

	local crossCorner = Instance.new("UICorner")
	crossCorner.CornerRadius = UDim.new(1, 0)
	crossCorner.Parent = crosshair

	-- MINIMIZE / TOGGLE MENU BUTTON
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "ToggleMenuBtn"
	toggleBtn.Size = UDim2.new(0, 110, 0, 30)
	toggleBtn.Position = UDim2.new(0.02, 0, 0.16, 0)
	toggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	toggleBtn.Text = "Willizard Menu"
	toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleBtn.Font = Enum.Font.SourceSansBold
	toggleBtn.TextSize = 12
	toggleBtn.Active = true
	toggleBtn.Draggable = true
	toggleBtn.Parent = screenGui

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 6)
	toggleCorner.Parent = toggleBtn

	toggleBtn.MouseButton1Click:Connect(function()
		mainPanel.Visible = not mainPanel.Visible
	end)

	-------------------------------------------------------------------
	-- NÚT TRÒN SHIFTLOCK
	-------------------------------------------------------------------
	local shiftLockToggleBtn = Instance.new("TextButton")
	shiftLockToggleBtn.Name = "ShiftLockCircleBtn"
	shiftLockToggleBtn.Size = UDim2.new(0, 65, 0, 65)
	shiftLockToggleBtn.Position = UDim2.new(0.12, 10, 0.13, 0)
	shiftLockToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	shiftLockToggleBtn.BackgroundTransparency = 0.25
	shiftLockToggleBtn.Text = "SHIFT"
	shiftLockToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	shiftLockToggleBtn.Font = Enum.Font.SourceSansBold
	shiftLockToggleBtn.TextSize = 12
	shiftLockToggleBtn.Active = true
	shiftLockToggleBtn.Draggable = true
	shiftLockToggleBtn.Parent = screenGui

	local shiftCircleCorner = Instance.new("UICorner")
	shiftCircleCorner.CornerRadius = UDim.new(1, 0)
	shiftCircleCorner.Parent = shiftLockToggleBtn

	local shiftCircleStroke = Instance.new("UIStroke")
	shiftCircleStroke.Color = Color3.fromRGB(0, 180, 60)
	shiftCircleStroke.Thickness = 2.5
	shiftCircleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	shiftCircleStroke.Parent = shiftLockToggleBtn

	local function updateShiftlockState(newState)
		toggleShiftLock(newState)
		if newState then
			shiftLockToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 50, 20)
			shiftBtn.Text = "Shiftlock: ON"
			crosshair.Visible = true
		else
			shiftLockToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
			shiftBtn.Text = "Shiftlock: OFF"
			crosshair.Visible = false
		end
	end

	shiftLockToggleBtn.MouseButton1Click:Connect(function()
		updateShiftlockState(not isShiftLockEnabled)
	end)

	-------------------------------------------------------------------
	-- NÚT TRÒN TRANG BỊ SÚNG NHANH
	-------------------------------------------------------------------
	local quickBtn = Instance.new("ImageButton")
	quickBtn.Name = "QuickEquipMatrixscope"
	quickBtn.Size = UDim2.new(0, 65, 0, 65)
	quickBtn.Position = UDim2.new(0.83, -10, 0.58, -10) 
	quickBtn.BackgroundColor3 = Color3.fromRGB(15, 25, 20)
	quickBtn.BackgroundTransparency = 0.25
	quickBtn.Image = CONFIG.ButtonImageId
	quickBtn.ScaleType = Enum.ScaleType.Fit
	quickBtn.Active = true
	quickBtn.Draggable = true 
	quickBtn.Parent = screenGui

	local quickCorner = Instance.new("UICorner")
	quickCorner.CornerRadius = UDim.new(1, 0)
	quickCorner.Parent = quickBtn

	local quickStroke = Instance.new("UIStroke")
	quickStroke.Color = Color3.fromRGB(0, 180, 60)
	quickStroke.Thickness = 2.5
	quickStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	quickStroke.Parent = quickBtn

	local buttonSound = Instance.new("Sound")
	buttonSound.Name = "QuickButtonSound"
	buttonSound.SoundId = CONFIG.ClickSound
	buttonSound.Volume = 0.3
	buttonSound.Parent = quickBtn

	quickBtn.MouseButton1Click:Connect(function()
		buttonSound:Play()

		local originalSize = UDim2.new(0, 65, 0, 65)
		quickBtn.Size = UDim2.new(0, 58, 0, 58)
		task.delay(0.1, function()
			quickBtn.Size = originalSize
		end)

		toggleEquipMatrixscope()
	end)

	-- EVENT LOGIC LISTENERS
	spawnBtn.MouseButton1Click:Connect(function()
		toggleEquipMatrixscope()
	end)

	spawnC4Btn.MouseButton1Click:Connect(function()
		GiveC4Tool()
	end)

	shiftBtn.MouseButton1Click:Connect(function()
		updateShiftlockState(not isShiftLockEnabled)
	end)

	dummyBtn.MouseButton1Click:Connect(function()
		spawnCustomDummies()
	end)

	killAllBtn.MouseButton1Click:Connect(function()
		killAllDummies()
	end)

	speedBtn.MouseButton1Click:Connect(function()
		if currentDummySpeed == 16 then
			currentDummySpeed = 24
		elseif currentDummySpeed == 24 then
			currentDummySpeed = 32
		elseif currentDummySpeed == 32 then
			currentDummySpeed = 8
		else
			currentDummySpeed = 16
		end
		speedBtn.Text = "Dummy Speed: " .. currentDummySpeed
	end)

	moveBtn.MouseButton1Click:Connect(function()
		isDummyMovementEnabled = not isDummyMovementEnabled
		if isDummyMovementEnabled then
			moveBtn.Text = "Dummy Move: ON"
		else
			moveBtn.Text = "Dummy Move: OFF"
		end
	end)

	jumpBtn.MouseButton1Click:Connect(function()
		isDummyJumpEnabled = not isDummyJumpEnabled
		if isDummyJumpEnabled then
			jumpBtn.Text = "Dummy Jump: ON"
		else
			jumpBtn.Text = "Dummy Jump: OFF"
		end
	end)
end

setupGUI()
GiveC4Tool()
