local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

if not hrp then
    warn("[Domain Prompt] Character not found!")
    return
end

local nearestPrompt = nil
local shortestDistance = 20 -- Searches within a 20-stud radius

for _, desc in ipairs(Workspace:GetDescendants()) do
    if desc:IsA("ProximityPrompt") then
        local pos = nil
        if desc.Parent:IsA("Attachment") then
            pos = desc.Parent.WorldPosition
        elseif desc.Parent:IsA("BasePart") then
            pos = desc.Parent.Position
        end
        
        if pos then
            local dist = (hrp.Position - pos).Magnitude
            if dist < shortestDistance then
                shortestDistance = dist
                nearestPrompt = desc
            end
        end
    end
end

if nearestPrompt and fireproximityprompt then
    print("[Domain Prompt] Firing prompt:", nearestPrompt:GetFullName())
    
    local oldDist = nearestPrompt.MaxActivationDistance
    local oldLos = nearestPrompt.RequiresLineOfSight
    local oldHold = nearestPrompt.HoldDuration
    
    pcall(function()
        nearestPrompt.MaxActivationDistance = 999999
        nearestPrompt.RequiresLineOfSight = false
        nearestPrompt.HoldDuration = 0
        
        fireproximityprompt(nearestPrompt)
        
        task.delay(0.25, function()
            nearestPrompt.MaxActivationDistance = oldDist
            nearestPrompt.RequiresLineOfSight = oldLos
            nearestPrompt.HoldDuration = oldHold
        end)
    end)
else
    warn("[Domain Prompt] No prompt found nearby, or your executor lacks fireproximityprompt support.")
end
