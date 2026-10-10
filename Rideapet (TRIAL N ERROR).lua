local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
if not req then warn("HTTP requests not supported by this executor.") end

local MaxPlayers = 5

local guiName = "InstantHopRAPGui"
local function removeOldGui(parentFolder)
    local old = parentFolder:FindFirstChild(guiName)
    if old then old:Destroy() end
end
pcall(function() removeOldGui(gethui and gethui() or CoreGui) end)
pcall(function() removeOldGui(CoreGui) end)
if player:FindFirstChild("PlayerGui") then removeOldGui(player.PlayerGui) end

-- =========================================
-- RAP CORE DATA & HELPERS
-- =========================================
local AutoMagmaEnabled = false
local AutoReturnEnabled = true
local isProcessingEgg = false 
local isEnteringVolcano = false -- Prevents false triggers while entering the volcano

local DROP_OFFSET = 85
local VOLCANO_TOP_POS = Vector3.new(-5102.843, 41405.629, -3489.114)
local VOLCANO_ENTRANCE_POS = Vector3.new(-4942.78, 41283.9, -3676.58)
local VOLCANO_VALIDATE_POS = Vector3.new(-4966.71, 41282.8, -3656.44)
local VOLCANIC_POS = Vector3.new(-5329.45, 40910.2, -3580.87)

local eggRarityScores = {
    volcanic = 5,
    blackhole = 2, cherub = 4, solaris = 3,
    aurora = 1, galaxy = 1,
    soul = 1, tidal = 1, sinister = 1,
    default = 0
}
local blacklistedEggs = {}
local savedCustomLocation = nil 

local function isValidEgg(item)
    if not item:IsA("Model") and not item:IsA("BasePart") then return false end
    local name = string.lower(item.Name)
    
    if not string.find(name, "egg") and not string.find(name, "blackhole") and not string.find(name, "solaris") then return false end
    if string.find(name, "eggo") or string.find(name, "tracker") or string.find(name, "box") then return false end
    if item.Parent and item.Parent.Name == "Stalls" then return false end
    if item:FindFirstAncestor("Plots") then return false end
    if blacklistedEggs[item] then return false end
    
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character and item:IsDescendantOf(p.Character) then return false end
    end
    return true
end

local function getEggScore(eggName)
    local lowerName = string.lower(eggName)
    for name, score in pairs(eggRarityScores) do
        if string.find(lowerName, name) then return score end
    end
    return eggRarityScores.default
end

local function teleportOnly(targetModel)
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(targetModel:GetPivot().Position + Vector3.new(0, 4, 0))
    end
end

local function getPlotCFrame()
    local plotsFolder = Workspace:FindFirstChild("Plots")
    if plotsFolder then
        local pName = string.lower(player.Name)
        local dName = string.lower(player.DisplayName)
        for _, plot in ipairs(plotsFolder:GetChildren()) do
            if string.find(string.lower(plot.Name), pName) or string.find(string.lower(plot.Name), dName) then
                return plot:GetPivot()
            end
            local ownerVal = plot:FindFirstChild("Owner", true) or plot:FindFirstChild("Player", true)
            if ownerVal and (ownerVal.Value == player or (typeof(ownerVal.Value) == "string" and (string.lower(ownerVal.Value) == pName or string.lower(ownerVal.Value) == dName))) then
                return plot:GetPivot()
            end
        end
    end
    return nil
end

-- =========================================
-- VOLCANO HELPERS & MUTATION LOGIC
-- =========================================
local function findPart(partName)
    for _, v in pairs(Workspace:GetDescendants()) do
        if string.lower(v.Name) == string.lower(partName) and (v:IsA("BasePart") or v:IsA("MeshPart")) then return v end
    end
    return nil
end

local function strikeTrigger(char, hrp, targetPos)
    local humanoid = char:FindFirstChild("Humanoid")
    for i = 1, 3 do
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.Anchored = false
        char:PivotTo(CFrame.new(targetPos + Vector3.new(0, 6, 0)))
        
        local timeout = tick() + 1.5
        local landed = false
        
        while tick() < timeout do
            if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
                landed = true
                break
            end
            if hrp.Position.Y < (targetPos.Y - 15) then break end
            task.wait(0.05)
        end
        
        if landed then
            task.wait(0.2)
            return true 
        end
    end
    return false
end

-- Reusable safe drop and pickup base delivery!
local function executeDropAndPickup(hrp, baseCFrame)
    hrp.CFrame = CFrame.new(baseCFrame.Position + Vector3.new(DROP_OFFSET, 5, DROP_OFFSET))
    task.wait(0.4)
    
    local remoteFolder = ReplicatedStorage:FindFirstChild("Remotes")
    local gameFolder = remoteFolder and remoteFolder:FindFirstChild("Game")
    local basketDrop = gameFolder and gameFolder:FindFirstChild("BasketDrop")
    
    if basketDrop then basketDrop:FireServer() end

    for i = 1, 40 do 
        local closestPrompt = nil
        local minDist = 15
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.Parent and desc.Parent:IsA("BasePart") then
                local dist = (desc.Parent.Position - hrp.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    closestPrompt = desc
                end
            end
        end
        
        if closestPrompt then
            hrp.CFrame = CFrame.new(closestPrompt.Parent.Position)
            task.wait(0.05) 
            pcall(function()
                if fireproximityprompt then fireproximityprompt(closestPrompt, 1)
                else closestPrompt:InputHoldBegin(); task.wait(0.05); closestPrompt:InputHoldEnd() end
            end)
            task.wait(0.1) 
            if not closestPrompt:IsDescendantOf(Workspace) then break end
        else
            task.wait(0.1) 
        end
    end
    
    task.wait(0.2) 
    hrp.CFrame = CFrame.new(baseCFrame.Position + Vector3.new(0, 5, 0))
end

local function performMagmaMutation(item, isVolcanoEgg)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if not isVolcanoEgg then
        hrp.CFrame = CFrame.new(VOLCANO_TOP_POS + Vector3.new(0, 50, 0))
        task.wait(2)
        hrp.CFrame = CFrame.new(VOLCANO_TOP_POS + Vector3.new(0, 4, 0))
    else
        -- Since processEggPickup already ran the strikeTrigger escape out of the volcano,
        -- we can go straight to the top of the volcano!
        hrp.CFrame = CFrame.new(VOLCANO_TOP_POS + Vector3.new(0, 4, 0))
    end

    task.wait(0.5)
    local netFolder = ReplicatedStorage:FindFirstChild("packages") and ReplicatedStorage.packages:FindFirstChild("Net")
    local dipRemote = netFolder and netFolder:FindFirstChild("RE/VolcanoDip")
    if dipRemote then
        dipRemote:FireServer()
        task.wait(10)
    end
    
    -- Auto Magma Update: Use safe delivery routine instead of direct teleport
    local baseCFrame = getPlotCFrame()
    if baseCFrame then
        executeDropAndPickup(hrp, baseCFrame)
    else
        local spawnLocation = Workspace:FindFirstChild("SpawnLocation", true) 
        if spawnLocation then hrp.CFrame = CFrame.new(spawnLocation.Position + Vector3.new(0, 5, 0)) end
    end
end

local function processEggPickup(item, isVolcanoEgg)
    if isProcessingEgg then return end
    isProcessingEgg = true

    -- Wait if still in the middle of entering the volcano
    while isEnteringVolcano do task.wait(0.05) end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    -- Immediately escape the guard pet and exit the volcano upon manual pickup
    if isVolcanoEgg and char and hrp then
        statusLabel.Text = "Escaping Volcano..."
        strikeTrigger(char, hrp, VOLCANO_VALIDATE_POS)
        strikeTrigger(char, hrp, VOLCANO_ENTRANCE_POS)
    end

    if AutoMagmaEnabled then
        performMagmaMutation(item, isVolcanoEgg)
    elseif AutoReturnEnabled then
        if char and hrp then
            local baseCFrame = getPlotCFrame()
            if baseCFrame then
                executeDropAndPickup(hrp, baseCFrame)
            end
        end
    end
    
    task.wait(2)
    isProcessingEgg = false
end

-- =========================================
-- UI CREATION
-- =========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = guiName
screenGui.Parent = player:WaitForChild("PlayerGui")
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 200, 0, 260) 
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 6)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 20, 0, 20); closeButton.Position = UDim2.new(1, -25, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50); closeButton.Text = "X"; closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Parent = mainFrame; Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 4)

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 20, 0, 20); minimizeButton.Position = UDim2.new(1, -50, 0, 5)
minimizeButton.BackgroundColor3 = Color3.fromRGB(255, 255, 0); minimizeButton.Text = "-"; minimizeButton.TextColor3 = Color3.new(0, 0, 0)
minimizeButton.Parent = mainFrame; Instance.new("UICorner", minimizeButton).CornerRadius = UDim.new(0, 4)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 100, 0, 20); titleLabel.Position = UDim2.new(0, 10, 0, 5)
titleLabel.BackgroundTransparency = 1; titleLabel.Text = "RAP Quick Menu"; titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.Font = Enum.Font.SourceSansBold; titleLabel.TextSize = 16; titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

-- Buttons
local hopNowButton = Instance.new("TextButton")
hopNowButton.Size = UDim2.new(0, 180, 0, 35); hopNowButton.Position = UDim2.new(0, 10, 0, 35)
hopNowButton.BackgroundColor3 = Color3.fromRGB(85, 255, 0); hopNowButton.TextColor3 = Color3.fromRGB(0, 0, 0)
hopNowButton.Text = "HOP NOW"; hopNowButton.Font = Enum.Font.SourceSansBold; hopNowButton.TextSize = 18
hopNowButton.Parent = mainFrame; Instance.new("UICorner", hopNowButton).CornerRadius = UDim.new(0, 4)

local tpBestButton = Instance.new("TextButton")
tpBestButton.Size = UDim2.new(0, 180, 0, 30); tpBestButton.Position = UDim2.new(0, 10, 0, 75)
tpBestButton.BackgroundColor3 = Color3.fromRGB(0, 100, 255); tpBestButton.TextColor3 = Color3.fromRGB(255, 255, 255)
tpBestButton.Text = "TP to Best World Egg"; tpBestButton.Font = Enum.Font.SourceSansBold; tpBestButton.TextSize = 14
tpBestButton.Parent = mainFrame; Instance.new("UICorner", tpBestButton).CornerRadius = UDim.new(0, 4)

local setLocationBtn = Instance.new("TextButton")
setLocationBtn.Size = UDim2.new(0, 180, 0, 25); setLocationBtn.Position = UDim2.new(0, 10, 0, 110)
setLocationBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 150); setLocationBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
setLocationBtn.Text = "Set Custom Location"; setLocationBtn.Font = Enum.Font.SourceSansBold; setLocationBtn.TextSize = 14
setLocationBtn.Parent = mainFrame; Instance.new("UICorner", setLocationBtn).CornerRadius = UDim.new(0, 4)

local tpCustomBtn = Instance.new("TextButton")
tpCustomBtn.Size = UDim2.new(0, 180, 0, 25); tpCustomBtn.Position = UDim2.new(0, 10, 0, 140)
tpCustomBtn.BackgroundColor3 = Color3.fromRGB(100, 30, 100); tpCustomBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
tpCustomBtn.Text = "TP to Custom Location"; tpCustomBtn.Font = Enum.Font.SourceSansBold; tpCustomBtn.TextSize = 14
tpCustomBtn.Parent = mainFrame; Instance.new("UICorner", tpCustomBtn).CornerRadius = UDim.new(0, 4)

local magmaToggleButton = Instance.new("TextButton")
magmaToggleButton.Size = UDim2.new(0, 180, 0, 25); magmaToggleButton.Position = UDim2.new(0, 10, 0, 170)
magmaToggleButton.BackgroundColor3 = Color3.fromRGB(255, 100, 0); magmaToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
magmaToggleButton.Text = "Auto Magma: OFF"; magmaToggleButton.Font = Enum.Font.SourceSansBold; magmaToggleButton.TextSize = 14
magmaToggleButton.Parent = mainFrame; Instance.new("UICorner", magmaToggleButton).CornerRadius = UDim.new(0, 4)

local autoReturnBtn = Instance.new("TextButton")
autoReturnBtn.Size = UDim2.new(0, 180, 0, 25); autoReturnBtn.Position = UDim2.new(0, 10, 0, 200)
autoReturnBtn.BackgroundColor3 = Color3.fromRGB(85, 255, 0); autoReturnBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
autoReturnBtn.Text = "Auto Return: ON"; autoReturnBtn.Font = Enum.Font.SourceSansBold; autoReturnBtn.TextSize = 14
autoReturnBtn.Parent = mainFrame; Instance.new("UICorner", autoReturnBtn).CornerRadius = UDim.new(0, 4)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 180, 0, 20); statusLabel.Position = UDim2.new(0, 10, 0, 230)
statusLabel.BackgroundTransparency = 1; statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.Text = ""; statusLabel.Font = Enum.Font.SourceSansBold; statusLabel.TextScaled = true; statusLabel.Parent = mainFrame

local minimizedIcon = Instance.new("Frame")
minimizedIcon.Size = UDim2.new(0, 40, 0, 40); minimizedIcon.Position = UDim2.new(0, 10, 0, 10)
minimizedIcon.BackgroundColor3 = Color3.fromRGB(0, 0, 0); minimizedIcon.Visible = false
minimizedIcon.Active = true; minimizedIcon.Draggable = true; minimizedIcon.Parent = screenGui
Instance.new("UICorner", minimizedIcon).CornerRadius = UDim.new(1, 0)

local miniStatusLabel = Instance.new("TextLabel")
miniStatusLabel.Size = UDim2.new(1, 0, 1, 0); miniStatusLabel.BackgroundTransparency = 1
miniStatusLabel.TextColor3 = Color3.new(1, 1, 1); miniStatusLabel.Font = Enum.Font.SourceSansBold
miniStatusLabel.TextScaled = true; miniStatusLabel.Text = "RAP"; miniStatusLabel.Parent = minimizedIcon

local iconButton = Instance.new("TextButton")
iconButton.Size = UDim2.new(1, 0, 1, 0); iconButton.BackgroundTransparency = 1; iconButton.Text = ""; iconButton.Parent = minimizedIcon

-- =========================================
-- IMPROVED AUTO RETURN MONITOR
-- =========================================
local trackedEggs = {}
local function monitorEggPickup(item)
    if trackedEggs[item] then return end
    trackedEggs[item] = true
    
    local initialPos = item:GetPivot().Position
    local isVolcanoEgg = string.find(string.lower(item.Name), "volcanic egg") ~= nil
    
    for _, desc in ipairs(item:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            desc.Triggered:Connect(function(plr)
                if plr == player then
                    statusLabel.Text = "Egg Collected! Processing..."
                    -- Zero delay for Volcanic Egg so we immediately escape the guard pet
                    if not isVolcanoEgg then
                        task.wait(0.5)
                    end
                    processEggPickup(item, isVolcanoEgg)
                end
            end)
        end
    end
    
    item.AncestryChanged:Connect(function(_, parent)
        if parent == nil or not item:IsDescendantOf(Workspace) then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                if (char.HumanoidRootPart.Position - initialPos).Magnitude < 15 then
                    statusLabel.Text = "Egg Collected! Processing..."
                    -- Zero delay for Volcanic Egg so we immediately escape the guard pet
                    if not isVolcanoEgg then
                        task.wait(0.5)
                    end
                    processEggPickup(item, isVolcanoEgg)
                    task.delay(1.5, function() if statusLabel.Text == "Egg Collected! Processing..." then statusLabel.Text = "" end end)
                end
            end
        end
    end)
end

for _, item in pairs(Workspace:GetDescendants()) do if isValidEgg(item) then monitorEggPickup(item) end end
Workspace.DescendantAdded:Connect(function(item) task.wait(0.1); if isValidEgg(item) then monitorEggPickup(item) end end)

-- =========================================
-- LOGIC BINDS
-- =========================================
magmaToggleButton.MouseButton1Click:Connect(function()
    AutoMagmaEnabled = not AutoMagmaEnabled
    if AutoMagmaEnabled then
        magmaToggleButton.Text = "Auto Magma: ON"
        magmaToggleButton.BackgroundColor3 = Color3.fromRGB(85, 255, 0)
        magmaToggleButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    else
        magmaToggleButton.Text = "Auto Magma: OFF"
        magmaToggleButton.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
        magmaToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end)

autoReturnBtn.MouseButton1Click:Connect(function()
    AutoReturnEnabled = not AutoReturnEnabled
    if AutoReturnEnabled then
        autoReturnBtn.Text = "Auto Return: ON"
        autoReturnBtn.BackgroundColor3 = Color3.fromRGB(85, 255, 0)
        autoReturnBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
    else
        autoReturnBtn.Text = "Auto Return: OFF"
        autoReturnBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
        autoReturnBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end)

tpBestButton.MouseButton1Click:Connect(function()
    statusLabel.Text = "Scanning..."
    local bestEgg, highestScore = nil, -999
    
    for _, item in pairs(Workspace:GetDescendants()) do
        if isValidEgg(item) then
            local score = getEggScore(item.Name)
            if score > highestScore then 
                highestScore = score
                bestEgg = item 
            end
        end
    end
    
    if bestEgg then 
        statusLabel.Text = "Target: " .. bestEgg.Name
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            local isVolcanoEgg = string.find(string.lower(bestEgg.Name), "volcanic egg") ~= nil
            
            if isVolcanoEgg then
                isEnteringVolcano = true
                
                strikeTrigger(char, hrp, VOLCANO_ENTRANCE_POS)
                strikeTrigger(char, hrp, VOLCANO_VALIDATE_POS)
                strikeTrigger(char, hrp, VOLCANIC_POS)
                strikeTrigger(char, hrp, VOLCANIC_POS)
                task.wait(1.5)
                
                hrp.AssemblyLinearVelocity = Vector3.zero
                char:PivotTo(CFrame.new(bestEgg:GetPivot().Position + Vector3.new(0, 4, 0)))
                
                isEnteringVolcano = false
                statusLabel.Text = "Ready! Pick up egg."
            else
                teleportOnly(bestEgg)
            end
        end
    else
        statusLabel.Text = "No valid eggs found."
        task.delay(2, function() statusLabel.Text = "" end)
    end
end)

setLocationBtn.MouseButton1Click:Connect(function()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        savedCustomLocation = char.HumanoidRootPart.CFrame
        statusLabel.Text = "Location Saved!"
        task.delay(2, function() statusLabel.Text = "" end)
    end
end)

tpCustomBtn.MouseButton1Click:Connect(function()
    if savedCustomLocation then
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = savedCustomLocation
            statusLabel.Text = "Teleported!"
            task.delay(1, function() statusLabel.Text = "" end)
        end
    else
        statusLabel.Text = "No location set."
        task.delay(2, function() statusLabel.Text = "" end)
    end
end)

closeButton.MouseButton1Click:Connect(function() screenGui:Destroy() end)
minimizeButton.MouseButton1Click:Connect(function() mainFrame.Visible = false; minimizedIcon.Visible = true end)
iconButton.MouseButton1Click:Connect(function() mainFrame.Visible = true; minimizedIcon.Visible = false end)

-- =========================================
-- INSTANT HOPPER LOGIC
-- =========================================
local isHopping = false

local function fetchWaterfallServer()
    local cursor = ""
    local placeId = game.PlaceId
    
    while cursor ~= nil do
        local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor ~= "" then url = url .. "&cursor=" .. cursor end
        
        local success, response = pcall(function() return req({Url = url, Method = "GET"}) end)
        
        if success and response and response.StatusCode == 200 then
            local body = HttpService:JSONDecode(response.Body)
            if body and body.data then
                for _, v in pairs(body.data) do
                    if type(v) == "table" and v.playing ~= nil and v.id ~= game.JobId then
                        if v.playing >= 1 and v.playing <= MaxPlayers then return v.id end
                    end
                end
                cursor = body.nextPageCursor
            else
                break
            end
        else
            task.wait(1)
        end
    end
    return nil
end

local function executeHop()
    if isHopping then return end
    isHopping = true
    
    hopNowButton.Text = "SEARCHING..."
    hopNowButton.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
    statusLabel.Text = "Finding low player server..."
    
    task.spawn(function()
        local targetServerId = fetchWaterfallServer()
        
        if targetServerId then
            hopNowButton.Text = "TELEPORTING..."
            hopNowButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
            statusLabel.Text = "Joining server!"
            TeleportService:TeleportToPlaceInstance(game.PlaceId, targetServerId, player)
        else
            statusLabel.Text = "Failed to find 1-5 player server."
            hopNowButton.Text = "HOP NOW"
            hopNowButton.BackgroundColor3 = Color3.fromRGB(85, 255, 0)
            isHopping = false
        end
    end)
end

hopNowButton.MouseButton1Click:Connect(executeHop)

TeleportService.TeleportInitFailed:Connect(function()
    isHopping = false
    hopNowButton.Text = "HOP NOW"
    hopNowButton.BackgroundColor3 = Color3.fromRGB(85, 255, 0)
    statusLabel.Text = "Teleport failed. Try again."
end)
