local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local parentGui = nil
pcall(function() parentGui = gethui and gethui() end)
if not parentGui then parentGui = player:FindFirstChild("PlayerGui") end

local uiName = "PivotTesterUI"
local oldGui = parentGui:FindFirstChild(uiName)
if oldGui then oldGui:Destroy() end

local screen = Instance.new("ScreenGui")
screen.Name = uiName
screen.ResetOnSpawn = false
screen.Parent = parentGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 130)
frame.Position = UDim2.new(0.5, 120, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
frame.Active = true
frame.Draggable = true
frame.Parent = screen

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.Text = "📍 Pivot Teleporter"
title.TextColor3 = Color3.fromRGB(255, 170, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Parent = frame

local btn1 = Instance.new("TextButton")
btn1.Size = UDim2.new(0.9, 0, 0, 35)
btn1.Position = UDim2.new(0.05, 0, 0, 35)
btn1.Text = "TP to Pivot 1"
btn1.BackgroundColor3 = Color3.fromRGB(46, 125, 50)
btn1.TextColor3 = Color3.new(1, 1, 1)
btn1.Font = Enum.Font.GothamSemibold
btn1.Parent = frame
Instance.new("UICorner", btn1).CornerRadius = UDim.new(0, 6)

local btn2 = Instance.new("TextButton")
btn2.Size = UDim2.new(0.9, 0, 0, 35)
btn2.Position = UDim2.new(0.05, 0, 0, 80)
btn2.Text = "TP to Pivot 2"
btn2.BackgroundColor3 = Color3.fromRGB(150, 50, 150)
btn2.TextColor3 = Color3.new(1, 1, 1)
btn2.Font = Enum.Font.GothamSemibold
btn2.Parent = frame
Instance.new("UICorner", btn2).CornerRadius = UDim.new(0, 6)

local function teleportTo(cframeValues)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		-- Suspend velocity before teleporting to prevent flinging
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		pcall(function() player:RequestStreamAroundAsync(Vector3.new(cframeValues[1], cframeValues[2], cframeValues[3]), 2) end)
		
		hrp.CFrame = CFrame.new(unpack(cframeValues))
		task.wait(0.1)
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
end

btn1.MouseButton1Click:Connect(function()
	teleportTo({209.21286, 40336.4922, 695.937744, -0.594695568, 0, -0.803951442, 0, 1, 0, 0.803951442, 0, -0.594695568})
end)

btn2.MouseButton1Click:Connect(function()
	teleportTo({-46034.7383, 40393.8828, -20358.2891, 0.623091042, 0.000573370373, -0.782149076, -4.87407669e-05, 0.999999762, 0.000694241375, 0.782149315, -0.000394453062, 0.623090923})
end)
