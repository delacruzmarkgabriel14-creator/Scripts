local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

-- Clean up old UIs if re-executed
local parentGui = (gethui and gethui()) or CoreGui:FindFirstChild("RobloxGui") or player:WaitForChild("PlayerGui")
for _, uiName in ipairs({"HalloweenEggHub", "EggFarmHubMobile", "DeltaEggHub"}) do
	local oldGui = parentGui:FindFirstChild(uiName)
	if oldGui then oldGui:Destroy() end
end

-- ============================================================================
-- SETTINGS
-- ============================================================================
local settings = {
	autoFarmEggs = false,
	targetEggName = "",
	batchSize = 10,
	hatchDelay = 2,
    placeDelay = 0.5
}

-- ============================================================================
-- GUI SETUP
-- ============================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HalloweenEggHub"
screenGui.ResetOnSpawn = false
screenGui.Parent = parentGui

-- Draggable Icon (Minimized State)
local iconFrame = Instance.new("TextButton")
iconFrame.Size = UDim2.new(0, 50, 0, 50)
iconFrame.Position = UDim2.new(0.5, -25, 0.1, 0)
iconFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
iconFrame.Text = "🎃"
iconFrame.TextSize = 24
iconFrame.Visible = false -- Hidden by default
iconFrame.Active = true
iconFrame.Draggable = true
iconFrame.Parent = screenGui

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(1, 0) -- Perfect circle
iconCorner.Parent = iconFrame

local iconStroke = Instance.new("UIStroke")
iconStroke.Color = Color3.fromRGB(255, 170, 0)
iconStroke.Thickness = 2
iconStroke.Parent = iconFrame

-- Main Menu (Maximized State)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 240, 0, 300)
mainFrame.Position = UDim2.new(0.5, -120, 0.3, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.8, 0, 0, 30)
title.Position = UDim2.new(0.05, 0, 0, 5)
title.BackgroundTransparency = 1
title.Text = "🎃 Egg Place & Hatch"
title.TextColor3 = Color3.fromRGB(255, 170, 0)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

-- Minimize Button
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
minimizeBtn.Position = UDim2.new(0.85, 0, 0, 5)
minimizeBtn.BackgroundTransparency = 1
minimizeBtn.Text = "—"
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.TextSize = 18
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.Parent = mainFrame

-- Delay Input
local delayInput = Instance.new("TextBox")
delayInput.Size = UDim2.new(0.9, 0, 0, 30)
delayInput.Position = UDim2.new(0.05, 0, 0.13, 0)
delayInput.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
delayInput.TextColor3 = Color3.fromRGB(255, 255, 255)
delayInput.Font = Enum.Font.Gotham
delayInput.TextSize = 14
delayInput.Text = tostring(settings.placeDelay)
delayInput.PlaceholderText = "Place Delay (Secs)"
delayInput.Parent = mainFrame
Instance.new("UICorner", delayInput).CornerRadius = UDim.new(0, 6)

-- Refresh Button
local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0.9, 0, 0, 25)
refreshBtn.Position = UDim2.new(0.05, 0, 0.25, 0)
refreshBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 150)
refreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.TextSize = 12
refreshBtn.Text = "↻ Refresh Backpack Eggs"
refreshBtn.Parent = mainFrame
Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 6)

-- Scrolling Frame for Eggs
local eggScroll = Instance.new("ScrollingFrame")
eggScroll.Size = UDim2.new(0.9, 0, 0, 80)
eggScroll.Position = UDim2.new(0.05, 0, 0.35, 0)
eggScroll.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
eggScroll.BorderSizePixel = 0
eggScroll.ScrollBarThickness = 4
eggScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
eggScroll.Parent = mainFrame
Instance.new("UICorner", eggScroll).CornerRadius = UDim.new(0, 6)

local scrollLayout = Instance.new("UIListLayout")
scrollLayout.Parent = eggScroll
scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
scrollLayout.Padding = UDim.new(0, 4)

local scrollPadding = Instance.new("UIPadding")
scrollPadding.Parent = eggScroll
scrollPadding.PaddingTop = UDim.new(0, 4)
scrollPadding.PaddingLeft = UDim.new(0, 4)
scrollPadding.PaddingRight = UDim.new(0, 4)

-- Live Egg Counter Label
local countLabel = Instance.new("TextLabel")
countLabel.Size = UDim2.new(0.9, 0, 0, 20)
countLabel.Position = UDim2.new(0.05, 0, 0.65, 0)
countLabel.BackgroundTransparency = 1
countLabel.Text = "Available: 0"
countLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
countLabel.TextSize = 13
countLabel.Font = Enum.Font.GothamMedium
countLabel.Parent = mainFrame

-- Toggle Farm Button
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0.9, 0, 0, 45)
toggleBtn.Position = UDim2.new(0.05, 0, 0.75, 0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 16
toggleBtn.Text = "START FARMING"
toggleBtn.Parent = mainFrame
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

-- ============================================================================
-- UI LOGIC
-- ============================================================================
-- Minimize/Maximize Logic
minimizeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    iconFrame.Visible = true
    -- Move icon to where the menu was
    iconFrame.Position = UDim2.new(0, mainFrame.AbsolutePosition.X + (mainFrame.AbsoluteSize.X/2) - 25, 0, mainFrame.AbsolutePosition.Y)
end)

iconFrame.MouseButton1Click:Connect(function()
    iconFrame.Visible = false
    mainFrame.Visible = true
end)

delayInput.FocusLost:Connect(function()
    local num = tonumber(delayInput.Text)
    if num then
        settings.placeDelay = num
    else
        delayInput.Text = tostring(settings.placeDelay)
    end
end)

local function populateEggs()
    for _, child in ipairs(eggScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    
    local foundEggs = {}
    
    -- Filter to ONLY show tools containing "egg" in their name
    for _, tool in ipairs(player.Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:lower():find("egg") then
            if not foundEggs[tool.Name] then
                foundEggs[tool.Name] = true
            end
        end
    end
    
    local ySize = 0
    for eggName, _ in pairs(foundEggs) do
        local eggBtn = Instance.new("TextButton")
        eggBtn.Size = UDim2.new(1, 0, 0, 25)
        eggBtn.BackgroundColor3 = (settings.targetEggName == eggName) and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 55)
        eggBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        eggBtn.Font = Enum.Font.Gotham
        eggBtn.TextSize = 12
        eggBtn.Text = eggName
        eggBtn.Parent = eggScroll
        Instance.new("UICorner", eggBtn).CornerRadius = UDim.new(0, 4)
        
        ySize = ySize + 29
        
        eggBtn.MouseButton1Click:Connect(function()
            settings.targetEggName = eggName
            populateEggs() 
        end)
    end
    
    -- Auto-select first egg if none selected
    if settings.targetEggName == "" and eggScroll:FindFirstChildWhichIsA("TextButton") then
        settings.targetEggName = eggScroll:FindFirstChildWhichIsA("TextButton").Text
        populateEggs()
    end
    
    eggScroll.CanvasSize = UDim2.new(0, 0, 0, ySize)
end

refreshBtn.MouseButton1Click:Connect(populateEggs)
populateEggs() 

toggleBtn.MouseButton1Click:Connect(function()
    if settings.targetEggName == "" then
        toggleBtn.Text = "SELECT AN EGG FIRST"
        task.wait(1)
        toggleBtn.Text = settings.autoFarmEggs and "STOP FARMING" or "START FARMING"
        return
    end

    settings.autoFarmEggs = not settings.autoFarmEggs
    if settings.autoFarmEggs then
        toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        toggleBtn.Text = "STOP FARMING"
    else
        toggleBtn.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
        toggleBtn.Text = "START FARMING"
    end
end)

-- Live Update Loop for the Egg Counter
task.spawn(function()
    while task.wait(0.5) do
        if settings.targetEggName ~= "" then
            local count = 0
            -- Check Backpack
            for _, tool in ipairs(player.Backpack:GetChildren()) do
                if tool.Name == settings.targetEggName then count = count + 1 end
            end
            -- Check Character (if equipped)
            if player.Character then
                for _, tool in ipairs(player.Character:GetChildren()) do
                    if tool:IsA("Tool") and tool.Name == settings.targetEggName then count = count + 1 end
                end
            end
            countLabel.Text = "Available: " .. tostring(count)
        else
            countLabel.Text = "Available: 0"
        end
    end
end)

-- ============================================================================
-- AUTOMATION LOGIC
-- ============================================================================
local function getMyPlacedEggs(rootPos)
    local activeEggs = {}
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return activeEggs end

    for _, plot in ipairs(plots:GetChildren()) do
        local eggsFolder = plot:FindFirstChild("Eggs")
        if eggsFolder then
            for _, egg in ipairs(eggsFolder:GetChildren()) do
                local eggPos = egg:GetPivot().Position
                if (eggPos - rootPos).Magnitude <= 100 then
                    table.insert(activeEggs, egg)
                end
            end
        end
    end
    return activeEggs
end

task.spawn(function()
    while task.wait(0.2) do
        if not settings.autoFarmEggs then continue end
        
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        
        if not root or not hum then continue end

        local placedEggs = getMyPlacedEggs(root.Position)

        -- STATE 1: HATCH EXISTING EGGS
        if #placedEggs > 0 then
            for _, egg in ipairs(placedEggs) do
                if not settings.autoFarmEggs then break end
                
                pcall(function()
                    local key = egg.Name:match("-") and egg.Name or egg:GetAttribute("EggKey") or (egg:FindFirstChild("EggKey") and egg.EggKey.Value)
                    if key then
                        ReplicatedStorage.Remotes.Game.Hatch:FireServer({ ["EggKey"] = key })
                    end

                    local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if prompt then
                        local eggPos = egg:GetPivot().Position
                        root.CFrame = CFrame.new(eggPos + Vector3.new(0, 3, 0))
                        root.AssemblyLinearVelocity = Vector3.zero
                        task.wait(0.1)

                        if fireproximityprompt then
                            local oldDist = prompt.MaxActivationDistance
                            local oldLos = prompt.RequiresLineOfSight
                            prompt.MaxActivationDistance = 999999
                            prompt.RequiresLineOfSight = false
                            
                            fireproximityprompt(prompt)
                            
                            task.wait(0.1)
                            prompt.MaxActivationDistance = oldDist
                            prompt.RequiresLineOfSight = oldLos
                        else
                            prompt:InputHoldBegin()
                            task.wait(prompt.HoldDuration + 0.1)
                            prompt:InputHoldEnd()
                        end
                    end
                end)
                task.wait(0.3)
            end
            
        -- STATE 2: PLACE NEW EGGS
        else
            for i = 1, settings.batchSize do
                if not settings.autoFarmEggs then break end
                
                if #getMyPlacedEggs(root.Position) >= settings.batchSize then break end
                
                local tool = player.Backpack:FindFirstChild(settings.targetEggName)
                if not tool then break end 
                
                pcall(function()
                    hum:EquipTool(tool)
                    local plantPos = root.Position + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
                    ReplicatedStorage.Remotes.Game.EggPlaced:FireServer({ ["PlantPosition"] = plantPos })
                end)
                
                task.wait(settings.placeDelay) 
            end
            
            task.wait(settings.hatchDelay)
        end
    end
end)
