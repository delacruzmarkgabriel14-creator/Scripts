local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

local parentGui = nil
pcall(function() parentGui = gethui and gethui() end)
if not parentGui then parentGui = CoreGui:FindFirstChild("RobloxGui") or player:WaitForChild("PlayerGui") end

for _, uiName in ipairs({"HalloweenCandyHub", "EggTrialTester", "YinYangTester"}) do
	local oldGui = parentGui:FindFirstChild(uiName)
	if oldGui then oldGui:Destroy() end
end

local settings = {
	autoFarmLoop = false,
	autoBuyEgg = false,
	moveMode = "Max", 
	speed = 250,
	tpDelay = 0.15, -- Hardcoded optimal pickup delay
	nearDepositThreshold = 500, 
	eggCost = 50 
}

local currentTween = nil
local collectedInstances = {}
local spawnPadCooldowns = {}
local cachedSpawns = setmetatable({}, {__mode = "k"})
local lastFarTargetCollected = false
local isBuyingEgg = false
local canAffordEggSinceLastDeposit = true 

local collectRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Game"):WaitForChild("CollectCandy")
local buyEggRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Game"):WaitForChild("BuyHalloweenEgg")
local dialogueRemote = ReplicatedStorage:WaitForChild("Dialogue"):WaitForChild("Remotes"):WaitForChild("DialogueSelect")

local screenGui

local function requestStreamSafe(pos)
	task.spawn(function() pcall(function() player:RequestStreamAroundAsync(pos, 2) end) end)
end

local function getAliveCharacterParts()
	local char = player.Character
	if not char or not char.Parent then return nil, nil end
	local hum = char:FindFirstChildWhichIsA("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then return nil, nil end
	return hum, hrp
end

local function getPlayerHalloweenTokens()
	-- 1. Check Player Attributes & Leaderstats
	for attrName, val in pairs(player:GetAttributes()) do
		local lower = attrName:lower()
		if type(val) == "number" and (lower:find("candy") or lower:find("token") or lower:find("halloween")) then
			return val
		end
	end
	for _, desc in ipairs(player:GetDescendants()) do
		if desc:IsA("IntValue") or desc:IsA("NumberValue") then
			local lower = desc.Name:lower()
			if lower:find("candy") or lower:find("token") or lower:find("halloween") then
				return desc.Value
			end
		end
	end
	
	-- 2. Check PlayerGui specifically for HalloweenTokens UI structure
	local pGui = player:FindFirstChild("PlayerGui")
	if pGui then
		for _, guiObj in ipairs(pGui:GetDescendants()) do
			if guiObj:IsA("TextLabel") and guiObj.Visible then
				local pName = guiObj.Name
				local parentName = guiObj.Parent and guiObj.Parent.Name or ""
				if pName == "HalloweenTokens" or parentName == "HalloweenTokens" then
					local clean = guiObj.Text:gsub(",", "")
					local num = tonumber(clean:match("%d+"))
					if num then return num end
				end
			end
		end
	end
	return nil 
end

local function hasSufficientHalloweenTokens()
	local balance = getPlayerHalloweenTokens()
	if balance ~= nil then return balance >= settings.eggCost, balance end
	return canAffordEggSinceLastDeposit, nil
end

local heartbeatConn
heartbeatConn = RunService.Heartbeat:Connect(function()
	if not screenGui or not screenGui.Parent then
		if heartbeatConn then heartbeatConn:Disconnect() end
		return
	end
	local hum, hrp = getAliveCharacterParts()
	if settings.autoFarmLoop and hum and hrp then
		if settings.moveMode == "Walk" then
			hum.WalkSpeed = settings.speed
			if hum.MoveDirection.Magnitude > 0 then
				hrp.AssemblyLinearVelocity = Vector3.new(hum.MoveDirection.X * settings.speed, hrp.AssemblyLinearVelocity.Y, hum.MoveDirection.Z * settings.speed)
			end
		elseif settings.moveMode == "Tween" or (settings.moveMode == "Max" and currentTween and currentTween.PlaybackState == Enum.PlaybackState.Playing) then
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
	end
end)

local function getObjectPos(obj)
	if not obj or not obj.Parent then return nil end
	if obj:IsA("BasePart") then
		cachedSpawns[obj] = obj.Position
		return obj.Position
	elseif obj:IsA("Model") then
		local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
		if part then
			cachedSpawns[obj] = part.Position
			return part.Position
		end
		local ok, cf = pcall(function() return obj:GetPivot() end)
		if ok and cf then
			cachedSpawns[obj] = cf.Position
			return cf.Position
		end
	end
	local part = obj:FindFirstChildWhichIsA("BasePart", true)
	if part then
		cachedSpawns[obj] = part.Position
		return part.Position
	end
	return cachedSpawns[obj]
end

local function getDepositPos()
	local dropPoint = Workspace:FindFirstChild("CandyDropOff", true)
	return dropPoint and getObjectPos(dropPoint), dropPoint
end

local function getExactCandyId(inst)
	if not inst or not inst.Parent then return nil end
	if inst.Name:match("^[A-Za-z]+%d+$") then
		local zone, numStr = inst.Name:match("^([A-Za-z]+)(%d+)$")
		if zone and numStr then
			local zoneId = 1
			local lowerZone = zone:lower()
			if lowerZone == "near" then zoneId = 1
			elseif lowerZone == "mid" then zoneId = 2
			elseif lowerZone == "far" then zoneId = 3
			end
			return "Candy" .. zoneId .. "_" .. tostring(tonumber(numStr))
		end
	end
	if inst.Name:match("^Candy%d+_%d+") then return inst.Name end
	local ok, attrs = pcall(function() return inst:GetAttributes() end)
	if ok and attrs then
		local spawnId = attrs["SpawnId"] or attrs["Id"]
		if spawnId and type(spawnId) == "string" then return spawnId end
		for _, val in pairs(attrs) do
			if type(val) == "string" and val:match("^Candy%d+_%d+") then return val end
		end
	end
	return nil
end

local function isTargetFarFromDeposit(inst, candyId, pos, dropPos)
	local combinedName = (inst.Name .. " " .. tostring(candyId or "")):lower()
	if combinedName:find("near") then return false end
	if dropPos and pos then return (pos - dropPos).Magnitude > settings.nearDepositThreshold end
	if combinedName:find("far") or combinedName:find("mid") then return true end
	return false
end

local function hasActiveCandyOnPad(pad)
	if spawnPadCooldowns[pad] and (tick() - spawnPadCooldowns[pad] < 8) then return false end
	local amountGui = pad:FindFirstChild("CandyAmount")
	if amountGui then
		if (amountGui:IsA("BillboardGui") or amountGui:IsA("SurfaceGui")) and not amountGui.Enabled then return false end
		if amountGui:IsA("ValueBase") and amountGui.Value <= 0 then return false end
		local lbl = amountGui:FindFirstChildWhichIsA("TextLabel", true)
		if lbl then
			if not lbl.Visible or lbl.Text == "" or lbl.Text == "0" then return false end
			local num = tonumber(lbl.Text:match("%d+"))
			if num and num <= 0 then return false end
		end
	end
	return true
end

local function getAllWorldCandies()
	local targets = {}
	local now = tick()
	local dropPos = getDepositPos()
	for inst, timestamp in pairs(collectedInstances) do
		if not inst or not inst.Parent or (now - timestamp > 15) then collectedInstances[inst] = nil end
	end
	local halloweenCandyFolder = Workspace:FindFirstChild("HalloweenCandy")
	if halloweenCandyFolder then
		for _, candy in ipairs(halloweenCandyFolder:GetChildren()) do
			if not collectedInstances[candy] then
				local pos = getObjectPos(candy)
				local id = getExactCandyId(candy)
				if pos and id then
					local isFar = isTargetFarFromDeposit(candy, id, pos, dropPos)
					table.insert(targets, {instance = candy, pos = pos, candyId = id, isPad = false, isFar = isFar})
				end
			end
		end
	end
	local hArea = Workspace:FindFirstChild("HalloweenArea")
	local spawns = hArea and hArea:FindFirstChild("CandySpawns")
	if spawns then
		for _, pad in ipairs(spawns:GetChildren()) do
			if hasActiveCandyOnPad(pad) then
				local pos = getObjectPos(pad)
				local id = getExactCandyId(pad)
				if pos and id then
					local isFar = isTargetFarFromDeposit(pad, id, pos, dropPos)
					table.insert(targets, {instance = pad, pos = pos, candyId = id, isPad = true, isFar = isFar})
				end
			end
		end
	end
	local _, hrp = getAliveCharacterParts()
	if hrp then
		table.sort(targets, function(a, b)
			if a.isPad ~= b.isPad then return not a.isPad end
			if settings.moveMode == "Max" and a.isFar ~= b.isFar then return not a.isFar end
			return (hrp.Position - a.pos).Magnitude < (hrp.Position - b.pos).Magnitude
		end)
	end
	return targets
end

local function tpTo(destinationPos)
	local _, hrp = getAliveCharacterParts()
	if not hrp then return false end
	if currentTween then currentTween:Cancel() end
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	local _, yRot, _ = hrp.CFrame:ToOrientation()
	hrp.CFrame = CFrame.new(destinationPos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, yRot, 0)
	requestStreamSafe(destinationPos)
	
	task.wait(settings.tpDelay) 
	
	if hrp and hrp.Parent then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
	return true
end

local function tweenTo(destinationPos)
	local hum, hrp = getAliveCharacterParts()
	if not hum or not hrp then return false end
	if currentTween then currentTween:Cancel() end
	requestStreamSafe(destinationPos)
	local targetPos = destinationPos + Vector3.new(0, 2.5, 0)
	local flatLook = Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z)
	local targetCFrame = CFrame.new(targetPos)
	if (flatLook - hrp.Position).Magnitude > 0.5 then
		local lookRot = CFrame.lookAt(hrp.Position, flatLook) - hrp.Position
		targetCFrame = CFrame.new(targetPos) * lookRot
	end
	local distance = (hrp.Position - targetPos).Magnitude
	local duration = math.clamp(distance / math.max(settings.speed, 1), 0.05, 8)
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	currentTween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
	currentTween:Play()
	local startTime = tick()
	while currentTween and currentTween.PlaybackState == Enum.PlaybackState.Playing do
		local currentHum, currentHrp = getAliveCharacterParts()
		if not settings.autoFarmLoop or (settings.moveMode ~= "Tween" and settings.moveMode ~= "Max") or not currentHum or not currentHrp or (tick() - startTime > duration + 1) then
			currentTween:Cancel()
			break
		end
		task.wait(0.02)
	end
	if hrp and hrp.Parent then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
	task.wait(0.05)
	return true
end

local function walkTo(destinationPos, customStopRadius)
	local hum, hrp = getAliveCharacterParts()
	if not hrp then return false end
	requestStreamSafe(destinationPos)
	local stopRadius = customStopRadius or 3
	local timeout = tick()
	while true do
		hum, hrp = getAliveCharacterParts()
		if not hum or not hrp then break end
		local flatDiff = Vector3.new(destinationPos.X - hrp.Position.X, 0, destinationPos.Z - hrp.Position.Z)
		if flatDiff.Magnitude <= stopRadius then break end
		if not settings.autoFarmLoop or settings.moveMode ~= "Walk" or (tick() - timeout > 5) then break end
		hum.WalkSpeed = settings.speed
		hum:MoveTo(destinationPos)
		if flatDiff.Magnitude > 0.05 then
			local dir = flatDiff.Unit
			hrp.AssemblyLinearVelocity = Vector3.new(dir.X * settings.speed, hrp.AssemblyLinearVelocity.Y, dir.Z * settings.speed)
		end
		if hrp.AssemblyLinearVelocity.Magnitude < 3 and (tick() - timeout > 0.3) then hum.Jump = true end
		task.wait(0.02)
	end
	if hrp and hrp.Parent then hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0) end
	return true
end

local function flashBuyHalloweenEgg(ignoreTokenCheck)
	if isBuyingEgg then return end
	if not ignoreTokenCheck then
		local canAfford = hasSufficientHalloweenTokens()
		if not canAfford then return end
	end
	isBuyingEgg = true
	pcall(function()
		local _, hrp = getAliveCharacterParts()
		local eggShop = Workspace:FindFirstChild("HalloweenEggShop")
		local promptPart = eggShop and eggShop:FindFirstChild("HalloweenShopPrompt")
		local shopGuy = Workspace:FindFirstChild("ShopGuy")
		local halloweenNpc = shopGuy and shopGuy:FindFirstChild("Halloween")
		if not hrp or not promptPart then return end
		local savedCF = hrp.CFrame
		local targetPos = getObjectPos(promptPart)
		if not targetPos then return end

		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 2))
		task.wait(0.18)

		if fireproximityprompt then
			for _, desc in ipairs(promptPart:GetDescendants()) do
				if desc:IsA("ProximityPrompt") then
					pcall(function()
						local oldDist = desc.MaxActivationDistance
						local oldLos = desc.RequiresLineOfSight
						desc.MaxActivationDistance = 999999
						desc.RequiresLineOfSight = false
						fireproximityprompt(desc)
						task.delay(0.2, function()
							desc.MaxActivationDistance = oldDist
							desc.RequiresLineOfSight = oldLos
						end)
					end)
				end
			end
			if promptPart:IsA("ProximityPrompt") then pcall(function() fireproximityprompt(promptPart) end) end
		end
		if firetouchinterest then
			local touchPart = promptPart:IsA("BasePart") and promptPart or promptPart:FindFirstChildWhichIsA("BasePart", true)
			if touchPart then
				pcall(function()
					firetouchinterest(hrp, touchPart, 0)
					task.wait(0.02)
					firetouchinterest(hrp, touchPart, 1)
				end)
			end
		end
		if halloweenNpc then pcall(function() dialogueRemote:FireServer(halloweenNpc, "Show me!") end) end
		task.spawn(function()
			local ok, res1, res2 = pcall(function() return buyEggRemote:InvokeServer("Halloween Egg") end)
			if not ok or res1 == false or (type(res1) == "string" and (res1:lower():find("not enough") or res1:lower():find("insufficient") or res1:lower():find("afford"))) or (type(res2) == "string" and (res2:lower():find("not enough") or res2:lower():find("afford"))) then
				canAffordEggSinceLastDeposit = false
			end
		end)
		task.wait(0.1)
		if hrp and hrp.Parent then
			hrp.CFrame = savedCF
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
	end)
	isBuyingEgg = false
end

local function performDeposit(forceTweenBack)
	local dropPos, dropPoint = getDepositPos()
	if not dropPos or not dropPoint then return end
	if settings.moveMode == "Max" then
		if forceTweenBack or lastFarTargetCollected then tweenTo(dropPos) else tpTo(dropPos) end
	elseif settings.moveMode == "Tween" then tweenTo(dropPos)
	else walkTo(dropPos, 3) end

	local hum, hrp = getAliveCharacterParts()
	if not hrp then return end
	
	for i = 1, 3 do
		if firetouchinterest then
			for _, part in ipairs(dropPoint:GetDescendants()) do
				if part:IsA("BasePart") then
					pcall(function()
						firetouchinterest(hrp, part, 0)
						task.wait(0.02)
						firetouchinterest(hrp, part, 1)
					end)
				end
			end
		end
		task.wait(0.05)
	end
	
	if hum then
		hum:MoveTo(dropPos + Vector3.new(2, 0, 0))
		task.wait(0.05)
		hum:MoveTo(dropPos)
	end
	task.wait(0.1) 
	
	lastFarTargetCollected = false
	canAffordEggSinceLastDeposit = true 
	if settings.autoBuyEgg and hasSufficientHalloweenTokens() then flashBuyHalloweenEgg(false) end
end

local function collectTarget(targetData)
	local inst = targetData.instance
	if not inst or not inst.Parent then return false end
	local moved = false
	if settings.moveMode == "Max" then moved = tpTo(targetData.pos)
	elseif settings.moveMode == "Tween" then moved = tweenTo(targetData.pos)
	else moved = walkTo(targetData.pos, 3) end
	if not moved then return false end

	local _, hrp = getAliveCharacterParts()
	if not hrp then return false end
	if targetData.candyId then pcall(function() collectRemote:FireServer(targetData.candyId) end) end

	local pickupTime = tick()
	if targetData.isPad then
		while hasActiveCandyOnPad(inst) and (tick() - pickupTime < 0.6) do task.wait(0.02) end
	else
		while inst and inst.Parent and (tick() - pickupTime < 0.6) do task.wait(0.02) end
	end
	
	if targetData.isPad then spawnPadCooldowns[inst] = tick()
	else collectedInstances[inst] = tick() end

	if targetData.isFar then lastFarTargetCollected = true end
	performDeposit(lastFarTargetCollected)

	return true
end

screenGui = Instance.new("ScreenGui")
screenGui.Name = "HalloweenCandyHub"
screenGui.ResetOnSpawn = false
screenGui.Parent = parentGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 220, 0, 225)
mainFrame.Position = UDim2.new(0.5, -110, 0.3, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundTransparency = 1
title.Text = "🎃 Candy & Egg Auto"
title.TextColor3 = Color3.fromRGB(255, 170, 0)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

local candyLabel = Instance.new("TextLabel")
candyLabel.Size = UDim2.new(0.9, 0, 0, 24)
candyLabel.Position = UDim2.new(0.05, 0, 0, 28)
candyLabel.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
candyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
candyLabel.Text = "Candy: ... | Tokens: ..."
candyLabel.TextSize = 11
candyLabel.Font = Enum.Font.GothamSemibold
candyLabel.Parent = mainFrame
local labelCorner = Instance.new("UICorner")
labelCorner.CornerRadius = UDim.new(0, 6)
labelCorner.Parent = candyLabel

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(0.92, 0, 0, 158)
scrollFrame.Position = UDim2.new(0.04, 0, 0, 58)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 4
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 290)
scrollFrame.Parent = mainFrame
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
end)

local function createItemButton(text, order, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.96, 0, 0, 28)
	btn.LayoutOrder = order
	btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = text
	btn.TextSize = 12
	btn.Font = Enum.Font.Gotham
	btn.Parent = scrollFrame
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn
	btn.MouseButton1Click:Connect(function() callback(btn) end)
	return btn
end

local function createSlider(name, minVal, maxVal, currentVal, isFloat, order, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.96, 0, 0, 38)
	container.LayoutOrder = order
	container.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	container.Parent = scrollFrame
	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 6)
	cCorner.Parent = container
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 18)
	label.BackgroundTransparency = 1
	label.Text = name .. ": " .. tostring(currentVal)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 11
	label.Font = Enum.Font.Gotham
	label.Parent = container
	local track = Instance.new("Frame")
	track.Size = UDim2.new(0.9, 0, 0, 8)
	track.Position = UDim2.new(0.05, 0, 0, 22)
	track.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	track.Parent = container
	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(1, 0)
	tCorner.Parent = track
	local fill = Instance.new("Frame")
	local startRatio = math.clamp((currentVal - minVal) / (maxVal - minVal), 0, 1)
	fill.Size = UDim2.new(startRatio, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
	fill.Parent = track
	local fCorner = Instance.new("UICorner")
	fCorner.CornerRadius = UDim.new(1, 0)
	fCorner.Parent = fill
	local dragging = false
	local function update(input)
		local xPos = input.Position.X - track.AbsolutePosition.X
		local ratio = math.clamp(xPos / track.AbsoluteSize.X, 0, 1)
		fill.Size = UDim2.new(ratio, 0, 1, 0)
		local val = minVal + (maxVal - minVal) * ratio
		if not isFloat then val = math.floor(val) else val = math.floor(val * 100) / 100 end
		label.Text = name .. ": " .. tostring(val)
		callback(val)
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			update(input)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			update(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	return container
end

createItemButton("Collect All Candy: OFF", 1, function(btn)
	settings.autoFarmLoop = not settings.autoFarmLoop
	btn.Text = "Collect All Candy: " .. (settings.autoFarmLoop and "ON" or "OFF")
	btn.BackgroundColor3 = settings.autoFarmLoop and Color3.fromRGB(46, 125, 50) or Color3.fromRGB(45, 45, 55)
	if not settings.autoFarmLoop and currentTween then currentTween:Cancel() end
end)

createItemButton("Auto Buy Egg: OFF", 2, function(btn)
	settings.autoBuyEgg = not settings.autoBuyEgg
	canAffordEggSinceLastDeposit = true
	btn.Text = "Auto Buy Egg: " .. (settings.autoBuyEgg and "ON" or "OFF")
	btn.BackgroundColor3 = settings.autoBuyEgg and Color3.fromRGB(46, 125, 50) or Color3.fromRGB(45, 45, 55)
end)

local methodDropdownOpen = false
local methodHeaderBtn
local methodScroll = Instance.new("ScrollingFrame")
methodScroll.Size = UDim2.new(0.96, 0, 0, 58)
methodScroll.LayoutOrder = 4
methodScroll.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
methodScroll.BorderSizePixel = 0
methodScroll.ScrollBarThickness = 3
methodScroll.CanvasSize = UDim2.new(0, 0, 0, 80)
methodScroll.Visible = false
methodScroll.Parent = scrollFrame
local methodCorner = Instance.new("UICorner")
methodCorner.CornerRadius = UDim.new(0, 6)
methodCorner.Parent = methodScroll
local methodLayout = Instance.new("UIListLayout")
methodLayout.Padding = UDim.new(0, 3)
methodLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
methodLayout.Parent = methodScroll

methodHeaderBtn = createItemButton("Method: Max ▼", 3, function(btn)
	methodDropdownOpen = not methodDropdownOpen
	methodScroll.Visible = methodDropdownOpen
	btn.Text = "Method: " .. settings.moveMode .. (methodDropdownOpen and " ▲" or " ▼")
end)

for _, mName in ipairs({"Max", "Walk", "Tween"}) do
	local opt = Instance.new("TextButton")
	opt.Size = UDim2.new(0.94, 0, 0, 22)
	opt.BackgroundColor3 = Color3.fromRGB(55, 55, 68)
	opt.TextColor3 = Color3.fromRGB(255, 255, 255)
	opt.Text = mName
	opt.TextSize = 11
	opt.Font = Enum.Font.GothamSemibold
	opt.Parent = methodScroll
	local optCorner = Instance.new("UICorner")
	optCorner.CornerRadius = UDim.new(0, 4)
	optCorner.Parent = opt
	opt.MouseButton1Click:Connect(function()
		settings.moveMode = mName
		if currentTween then currentTween:Cancel() end
		methodDropdownOpen = false
		methodScroll.Visible = false
		methodHeaderBtn.Text = "Method: " .. mName .. " ▼"
	end)
end

createSlider("Walk/Tween Speed", 50, 3000, settings.speed, false, 4, function(val)
	settings.speed = val
end)

local nearRanges = {500, 1000, 1500, 2000, 3000}
local rangeIdx = 1
createItemButton("Near TP Range: " .. settings.nearDepositThreshold, 5, function(btn)
	rangeIdx = (rangeIdx % #nearRanges) + 1
	settings.nearDepositThreshold = nearRanges[rangeIdx]
	btn.Text = "Near TP Range: " .. settings.nearDepositThreshold
end)

local eggCosts = {25, 50, 75, 100, 150, 200}
local costIdx = 2
createItemButton("Min Egg Tokens: " .. settings.eggCost, 6, function(btn)
	costIdx = (costIdx % #eggCosts) + 1
	settings.eggCost = eggCosts[costIdx]
	canAffordEggSinceLastDeposit = true
	btn.Text = "Min Egg Tokens: " .. settings.eggCost
end)

createItemButton("Buy Egg Once (Flash)", 7, function()
	task.spawn(function() flashBuyHalloweenEgg(true) end)
end)

createItemButton("Reset Visited Memory", 8, function()
	table.clear(collectedInstances)
	table.clear(spawnPadCooldowns)
end)

createItemButton("Go to Deposit", 9, function()
	task.spawn(function() pcall(function() performDeposit(false) end) end)
end)

player.CharacterAdded:Connect(function()
	if currentTween then pcall(function() currentTween:Cancel() end) end
	table.clear(collectedInstances)
	table.clear(spawnPadCooldowns)
end)

task.spawn(function()
	while screenGui and screenGui.Parent do
		local ok, list = pcall(getAllWorldCandies)
		local tokens = getPlayerHalloweenTokens()
		if ok and list then
			candyLabel.Text = string.format("Candy: %d | Tokens: %s", #list, tokens and tostring(tokens) or "Auto")
		end
		task.wait(0.5)
	end
end)

task.spawn(function()
	while screenGui and screenGui.Parent do
		if settings.autoBuyEgg and not settings.autoFarmLoop and not isBuyingEgg then
			if hasSufficientHalloweenTokens() then flashBuyHalloweenEgg(false) end
			task.wait(1.5)
		end
		task.wait(0.3)
	end
end)

task.spawn(function()
	while screenGui and screenGui.Parent do
		if settings.autoFarmLoop then
			local ok, err = pcall(function()
				local hum, hrp = getAliveCharacterParts()
				if not hum or not hrp then
					task.wait(0.5)
					return
				end
				local allTargets = getAllWorldCandies()
				if #allTargets > 0 then
					local bestTarget = allTargets[1]
					collectTarget(bestTarget)
				else
					if settings.autoBuyEgg and hasSufficientHalloweenTokens() then
						flashBuyHalloweenEgg(false)
					end
					task.wait(0.1)
				end
			end)
			if not ok then
				warn("[CandyHub] Main loop recovered from error:", err)
				task.wait(0.5)
			end
		end
		task.wait(0.02)
	end
end)
