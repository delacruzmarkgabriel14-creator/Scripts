local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local parentGui = nil
pcall(function() parentGui = gethui and gethui() end)
if not parentGui then parentGui = CoreGui:FindFirstChild("RobloxGui") or player:WaitForChild("PlayerGui") end

-- Clean up old tester
local uiName = "DomainTesterUI"
local oldGui = parentGui:FindFirstChild(uiName)
if oldGui then oldGui:Destroy() end

local fadeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Game"):WaitForChild("HalloweenFade")

-- UI Setup
local screen = Instance.new("ScreenGui")
screen.Name = uiName
screen.ResetOnSpawn = false
screen.Parent = parentGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 180, 0, 120)
frame.Position = UDim2.new(0.5, 120, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screen

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.Text = "🦇 Domain Tester"
title.TextColor3 = Color3.fromRGB(255, 170, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Parent = frame

local btnEnter = Instance.new("TextButton")
btnEnter.Size = UDim2.new(0.9, 0, 0, 30)
btnEnter.Position = UDim2.new(0.05, 0, 0, 35)
btnEnter.Text = "Enter Domain"
btnEnter.BackgroundColor3 = Color3.fromRGB(46, 125, 50)
btnEnter.TextColor3 = Color3.new(1, 1, 1)
btnEnter.Font = Enum.Font.GothamSemibold
btnEnter.Parent = frame

local cornerEnter = Instance.new("UICorner")
cornerEnter.CornerRadius = UDim.new(0, 6)
cornerEnter.Parent = btnEnter

btnEnter.MouseButton1Click:Connect(function()
	pcall(function()
		fadeRemote:FireServer("Ready", 1)
		print("[DomainTester] Fired Enter (1)")
	end)
end)

local btnLeave = Instance.new("TextButton")
btnLeave.Size = UDim2.new(0.9, 0, 0, 30)
btnLeave.Position = UDim2.new(0.05, 0, 0, 75)
btnLeave.Text = "Leave Domain"
btnLeave.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
btnLeave.TextColor3 = Color3.new(1, 1, 1)
btnLeave.Font = Enum.Font.GothamSemibold
btnLeave.Parent = frame

local cornerLeave = Instance.new("UICorner")
cornerLeave.CornerRadius = UDim.new(0, 6)
cornerLeave.Parent = btnLeave

btnLeave.MouseButton1Click:Connect(function()
	pcall(function()
		fadeRemote:FireServer("Ready", 2)
		print("[DomainTester] Fired Leave (2)")
	end)
end)
