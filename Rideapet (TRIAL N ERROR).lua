local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

-- Clean up old UI if re-executed
local parentGui = (gethui and gethui()) or CoreGui:FindFirstChild("RobloxGui") or player:WaitForChild("PlayerGui")
local oldGui = parentGui:FindFirstChild("HalloweenCandyHub")
if oldGui then
    oldGui:Destroy()
end

local settings = {
    autoFarmLoop = false,
    bypassAFK = false,
    moveMode = "Walk", -- "Walk", "Tween", or "TP"
    speed = 250
}

local currentTween = nil
local collectedInstances = {}
local spawnPadCooldowns = {}

-- Enforce speed on Heartbeat
RunService.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")

    if settings.autoFarmLoop and hum and hrp then
        if settings.moveMode == "Walk" then
            hum.WalkSpeed = settings.speed
            if hum.MoveDirection.Magnitude > 0 then
                hrp.AssemblyLinearVelocity = Vector3.new(
                    hum.MoveDirection.X * settings.speed,
                    hrp.AssemblyLinearVelocity.Y,
                    hum.MoveDirection.Z * settings.speed
                )
            end
        elseif settings.moveMode == "Tween" then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end)

-- Collect Remote
local gameFolder = ReplicatedStorage:FindFirstChild("Game", true)
local collectRemote = gameFolder and gameFolder:FindFirstChild("CollectCandy")

-- Extract position from any Part or Model
local function getObjectPos(obj)
    if not obj or not obj.Parent then return nil end
    if obj:IsA("BasePart") then
        return obj.Position
    elseif obj:IsA("Model") then
        local ok, cf = pcall(function() return obj:GetPivot() end)
        if ok and cf then return cf.Position end
    end
    local part = obj:FindFirstChildWhichIsA("BasePart", true)
    if part then return part.Position end
    return nil
end

-- Check if a CandySpawn pad currently has candy
local function hasActiveCandyOnPad(pad)
    if spawnPadCooldowns[pad] and (tick() - spawnPadCooldowns[pad] < 20) then
        return false
    end

    local amountGui = pad:FindFirstChild("CandyAmount")
    if amountGui then
        if (amountGui:IsA("BillboardGui") or amountGui:IsA("SurfaceGui")) and not amountGui.Enabled then
            return false
        end
        if amountGui:IsA("ValueBase") and amountGui.Value <= 0 then
            return false
        end
        local lbl = amountGui:FindFirstChildWhichIsA("TextLabel", true)
        if lbl then
            if not lbl.Visible or lbl.Text == "" or lbl.Text == "0" then
                return false
            end
            local num = tonumber(lbl.Text:match("%d+"))
            if num and num <= 0 then return false end
        end
    end

    return true
end

-- Gather ALL uncollected candies across the world
local function getAllWorldCandies()
    local targets = {}

    -- 1. Physical candy meshes in Workspace.HalloweenCandy (e.g. Candy_01)
    local halloweenCandyFolder = Workspace:FindFirstChild("HalloweenCandy")
    if halloweenCandyFolder then
        for _, candy in ipairs(halloweenCandyFolder:GetChildren()) do
            if not collectedInstances[candy] then
                local pos = getObjectPos(candy)
                if pos then
                    table.insert(targets, {instance = candy, pos = pos, isPad = false})
                end
            end
        end
    end

    -- 2. Active spawn pads in Workspace.HalloweenArea.CandySpawns
    local hArea = Workspace:FindFirstChild("HalloweenArea")
    local spawns = hArea and hArea:FindFirstChild("CandySpawns")
    if spawns then
        for _, pad in ipairs(spawns:GetChildren()) do
            if hasActiveCandyOnPad(pad) then
                local pos = getObjectPos(pad)
                if pos then
                    table.insert(targets, {instance = pad, pos = pos, isPad = true})
                end
            end
        end
    end

    -- Sort nearest first from current position
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        table.sort(targets, function(a, b)
            return (hrp.Position - a.pos).Magnitude < (hrp.Position - b.pos).Magnitude
        end)
    end

    return targets
end

-- Movement Method 1: Instant Upright Teleport
local function tpTo(destinationPos)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    if currentTween then currentTween:Cancel() end
    pcall(function() player:RequestStreamAroundAsync(destinationPos, 2) end)

    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero

    local _, yRot, _ = hrp.CFrame:ToOrientation()
    hrp.CFrame = CFrame.new(destinationPos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, yRot, 0)

    task.wait(0.12)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    return true
end

-- Movement Method 2: Smooth Tween Glide
local function tweenTo(destinationPos)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    if currentTween then currentTween:Cancel() end
    pcall(function() player:RequestStreamAroundAsync(destinationPos, 2) end)

    local targetPos = destinationPos + Vector3.new(0, 2, 0)
    local flatLook = Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z)
    local targetCFrame = CFrame.new(targetPos)

    if (flatLook - hrp.Position).Magnitude > 0.5 then
        local lookRot = CFrame.lookAt(hrp.Position, flatLook) - hrp.Position
        targetCFrame = CFrame.new(targetPos) * lookRot
    end

    local distance = (hrp.Position - targetPos).Magnitude
    local duration = math.clamp(distance / settings.speed, 0.05, 8)

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    currentTween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
    currentTween:Play()

    while currentTween and currentTween.PlaybackState == Enum.PlaybackState.Playing do
        if not settings.autoFarmLoop or settings.moveMode ~= "Tween" then
            currentTween:Cancel()
            break
        end
        task.wait(0.02)
    end

    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    return true
end

-- Movement Method 3: High-Speed Velocity Walk
local function walkTo(destinationPos, customStopRadius)
    local char = player.Character
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return false end

    pcall(function() player:RequestStreamAroundAsync(destinationPos, 2) end)

    -- Tight stop radius (2.5 studs) so we walk directly ON TOP of the candy
    local stopRadius = customStopRadius or 2.5
    local timeout = tick()

    while (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(destinationPos.X, 0, destinationPos.Z)).Magnitude > stopRadius do
        if not settings.autoFarmLoop or settings.moveMode ~= "Walk" or (tick() - timeout > 5) then break end

        hum.WalkSpeed = settings.speed
        hum:MoveTo(destinationPos)

        local flatTarget = Vector3.new(destinationPos.X, hrp.Position.Y, destinationPos.Z)
        local dir = (flatTarget - hrp.Position).Unit
        hrp.AssemblyLinearVelocity = Vector3.new(dir.X * settings.speed, hrp.AssemblyLinearVelocity.Y, dir.Z * settings.speed)

        if hrp.AssemblyLinearVelocity.Magnitude < 3 and (tick() - timeout > 0.3) then
            hum.Jump = true
        end
        task.wait(0.02)
    end

    -- Stop horizontal velocity right on top of the target so we don't slide past it
    hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
    return true
end

-- Unified Movement Router
local function moveToTarget(destinationPos, exactStopRadius)
    if settings.moveMode == "TP" then
        return tpTo(destinationPos)
    elseif settings.moveMode == "Tween" then
        return tweenTo(destinationPos)
    else
        return walkTo(destinationPos, exactStopRadius)
    end
end

-- Guaranteed Candy Pickup: stands directly on the candy, fires all touch/remote triggers, and waits for server registration
local function collectTarget(targetData)
    local inst = targetData.instance
    if not inst or not inst.Parent then return false end

    -- 1. Move right on top of the candy (stopRadius = 2 studs)
    moveToTarget(targetData.pos, 2)

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    if not hrp then return false end

    -- Re-fetch exact streamed position and snap onto it so we don't miss due to high speed
    local currentPos = getObjectPos(inst) or targetData.pos
    if (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(currentPos.X, 0, currentPos.Z)).Magnitude > 4 then
        hrp.CFrame = CFrame.new(currentPos + Vector3.new(0, 2.5, 0))
        hrp.AssemblyLinearVelocity = Vector3.zero
    end

    -- 2. Repeatedly trigger pickup for 0.35s so the server registers proximity + remote + touch
    for _ = 1, 3 do
        if not settings.autoFarmLoop then break end

        -- Fire Remote with all possible expected arguments (instance, name, and no-arg)
        if collectRemote then
            pcall(function() collectRemote:FireServer(inst) end)
            pcall(function() collectRemote:FireServer(inst.Name) end)
            pcall(function() collectRemote:FireServer() end)
        end

        -- Fire TouchInterest on the target AND any nearby Candy_XX in Workspace.HalloweenCandy
        if firetouchinterest then
            local exactPart = inst:IsA("BasePart") and inst or inst:FindFirstChildWhichIsA("BasePart", true)
            if exactPart then
                pcall(function()
                    firetouchinterest(hrp, exactPart, 0)
                    firetouchinterest(hrp, exactPart, 1)
                end)
            end
            local hCandy = Workspace:FindFirstChild("HalloweenCandy")
            if hCandy then
                for _, cObj in ipairs(hCandy:GetChildren()) do
                    local cPos = getObjectPos(cObj)
                    if cPos and (cPos - currentPos).Magnitude < 15 then
                        local cPart = cObj:IsA("BasePart") and cObj or cObj:FindFirstChildWhichIsA("BasePart", true)
                        if cPart then
                            pcall(function()
                                firetouchinterest(hrp, cPart, 0)
                                firetouchinterest(hrp, cPart, 1)
                            end)
                        end
                        if collectRemote then
                            pcall(function() collectRemote:FireServer(cObj) end)
                            pcall(function() collectRemote:FireServer(cObj.Name) end)
                        end
                    end
                end
            end
        end

        -- Fire ProximityPrompt if present
        local prompt = inst:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and fireproximityprompt then
            fireproximityprompt(prompt)
        end

        -- Micro-step on the pad so server .Touched / spatial listeners fire
        if hum then
            hum:MoveTo(currentPos + Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)))
        end

        task.wait(0.12)
    end

    -- 3. Mark collected AFTER lingering on the spot
    if targetData.isPad then
        spawnPadCooldowns[inst] = tick()
    else
        collectedInstances[inst] = true
    end

    return true
end

-- Reliable Deposit Handler
local function performDeposit()
    local dropPoint = Workspace:FindFirstChild("CandyDropOff", true)
    if not dropPoint then return end
    local dropPos = getObjectPos(dropPoint)
    if not dropPos then return end

    moveToTarget(dropPos, 2)

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    if not hrp then return end

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

    if hum then
        hum:MoveTo(dropPos + Vector3.new(2, 0, 0))
        task.wait(0.18)
        hum:MoveTo(dropPos)
        task.wait(0.18)
    else
        task.wait(0.35)
    end
end

-- Compact Scrollable ScreenGui Setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HalloweenCandyHub"
screenGui.ResetOnSpawn = false
screenGui.Parent = parentGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 210, 0, 215)
mainFrame.Position = UDim2.new(0.5, -105, 0.3, 0)
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
title.Text = "🎃 Candy Auto"
title.TextColor3 = Color3.fromRGB(255, 170, 0)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

local candyLabel = Instance.new("TextLabel")
candyLabel.Size = UDim2.new(0.9, 0, 0, 24)
candyLabel.Position = UDim2.new(0.05, 0, 0, 28)
candyLabel.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
candyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
candyLabel.Text = "World Candy: ..."
candyLabel.TextSize = 12
candyLabel.Font = Enum.Font.GothamSemibold
candyLabel.Parent = mainFrame

local labelCorner = Instance.new("UICorner")
labelCorner.CornerRadius = UDim.new(0, 6)
labelCorner.Parent = candyLabel

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(0.92, 0, 0, 150)
scrollFrame.Position = UDim2.new(0.04, 0, 0, 58)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 4
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 260)
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

-- 1. Auto Farm Toggle
createItemButton("Collect All Candy: OFF", 1, function(btn)
    settings.autoFarmLoop = not settings.autoFarmLoop
    btn.Text = "Collect All Candy: " .. (settings.autoFarmLoop and "ON" or "OFF")
    btn.BackgroundColor3 = settings.autoFarmLoop and Color3.fromRGB(46, 125, 50) or Color3.fromRGB(45, 45, 55)
    if not settings.autoFarmLoop and currentTween then
        currentTween:Cancel()
    end
end)

-- 2. Compact Scrollable Method Dropdown
local methodDropdownOpen = false
local methodHeaderBtn
local methodScroll = Instance.new("ScrollingFrame")
methodScroll.Size = UDim2.new(0.96, 0, 0, 58)
methodScroll.LayoutOrder = 3
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

methodHeaderBtn = createItemButton("Method: Walk ▼", 2, function(btn)
    methodDropdownOpen = not methodDropdownOpen
    methodScroll.Visible = methodDropdownOpen
    btn.Text = "Method: " .. settings.moveMode .. (methodDropdownOpen and " ▲" or " ▼")
end)

for _, mName in ipairs({"Walk", "Tween", "TP"}) do
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

-- 3. Speed Switcher
local speeds = {80, 150, 250, 400, 600, 800}
local speedIdx = 3
createItemButton("Speed: " .. settings.speed, 4, function(btn)
    speedIdx = (speedIdx % #speeds) + 1
    settings.speed = speeds[speedIdx]
    btn.Text = "Speed: " .. settings.speed
end)

-- 4. Reset Visited Memory Button
createItemButton("Reset Visited Memory", 5, function()
    table.clear(collectedInstances)
    table.clear(spawnPadCooldowns)
end)

-- 5. Bypass AFK Toggle
createItemButton("Bypass AFK Area: OFF", 6, function(btn)
    settings.bypassAFK = not settings.bypassAFK
    btn.Text = "Bypass AFK Area: " .. (settings.bypassAFK and "ON" or "OFF")
    btn.BackgroundColor3 = settings.bypassAFK and Color3.fromRGB(46, 125, 50) or Color3.fromRGB(45, 45, 55)
end)

-- 6. Manual Deposit Button
createItemButton("Go to Deposit", 7, function()
    performDeposit()
end)

-- Live Display Updater
task.spawn(function()
    while screenGui.Parent do
        local list = getAllWorldCandies()
        candyLabel.Text = "World Candy: " .. tostring(#list)
        task.wait(0.5)
    end
end)

-- Background AFK Area Presence Spoofing
task.spawn(function()
    while screenGui.Parent do
        if settings.bypassAFK then
            pcall(function()
                local pScripts = player:FindFirstChild("PlayerScripts")
                local reusable = pScripts and pScripts:FindFirstChild("Reusable")
                local afkScript = reusable and reusable:FindFirstChild("TeleportBackOnAFK")
                if afkScript and afkScript.Enabled then
                    afkScript.Enabled = false
                end

                local afkZone = Workspace:FindFirstChild("HalloweenAFK", true)
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if afkZone and hrp and firetouchinterest then
                    local zonePart = afkZone:IsA("BasePart") and afkZone or afkZone:FindFirstChildWhichIsA("BasePart")
                    if zonePart then
                        firetouchinterest(hrp, zonePart, 0)
                        task.wait(0.05)
                        firetouchinterest(hrp, zonePart, 1)
                    end
                end
            end)
        end
        task.wait(1)
    end
end)

-- Main Loop: Re-evaluates nearest uncollected candy every cycle
task.spawn(function()
    while screenGui.Parent do
        if settings.autoFarmLoop then
            local allTargets = getAllWorldCandies()

            if #allTargets > 0 then
                -- Always grab the closest available candy first
                local bestTarget = allTargets[1]
                collectTarget(bestTarget)

                if settings.autoFarmLoop then
                    performDeposit()
                end
            else
                task.wait(0.3)
            end
        end
        task.wait(0.05)
    end
end)
