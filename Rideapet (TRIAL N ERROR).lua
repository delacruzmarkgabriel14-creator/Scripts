local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local parentGui = nil
pcall(function() parentGui = gethui and gethui() end)
if not parentGui then parentGui = CoreGui:FindFirstChild("RobloxGui") or player:WaitForChild("PlayerGui") end

local uiName = "DomainTesterUI"
local oldGui = parentGui:FindFirstChild(uiName)
if oldGui then oldGui:Destroy() end

local fadeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Game"):WaitForChild("HalloweenFade")

local screen = Instance.new("ScreenGui")
screen.Name = uiName
screen.ResetOnSpawn = false
screen.Parent = parentGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 150)
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
title.Text = "🦇 Domain & Token Tester"
title.TextColor3 = Color3.fromRGB(255, 170, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Parent = frame

local tokenDisplay = Instance.new("TextLabel")
tokenDisplay.Size = UDim2.new(0.9, 0, 0, 25)
tokenDisplay.Position = UDim2.new(0.05, 0, 0, 35)
tokenDisplay.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
tokenDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
tokenDisplay.Text = "Tokens: ..."
tokenDisplay.Font = Enum.Font.GothamSemibold
tokenDisplay.Parent = frame

local tokenCorner = Instance.new("UICorner")
tokenCorner.CornerRadius = UDim.new(0, 6)
tokenCorner.Parent = tokenDisplay

local btnEnter = Instance.new("TextButton")
btnEnter.Size = UDim2.new(0.9, 0, 0, 30)
btnEnter.Position = UDim2.new(0.05, 0, 0, 70)
btnEnter.Text = "Enter Domain (1)"
btnEnter.BackgroundColor3 = Color3.fromRGB(46, 125, 50)
btnEnter.TextColor3 = Color3.new(1, 1, 1)
btnEnter.Font = Enum.Font.GothamSemibold
btnEnter.Parent = frame

local cornerEnter = Instance.new("UICorner")
cornerEnter.CornerRadius = UDim.new(0, 6)
cornerEnter.Parent = btnEnter

btnEnter.MouseButton1Click:Connect(function()
	pcall(function()
		local args = { [1] = "Ready", [2] = 1 }
		fadeRemote:FireServer(unpack(args))
	end)
end)

local btnLeave = Instance.new("TextButton")
btnLeave.Size = UDim2.new(0.9, 0, 0, 30)
btnLeave.Position = UDim2.new(0.05, 0, 0, 110)
btnLeave.Text = "Leave Domain (2)"
btnLeave.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
btnLeave.TextColor3 = Color3.new(1, 1, 1)
btnLeave.Font = Enum.Font.GothamSemibold
btnLeave.Parent = frame

local cornerLeave = Instance.new("UICorner")
cornerLeave.CornerRadius = UDim.new(0, 6)
cornerLeave.Parent = btnLeave

btnLeave.MouseButton1Click:Connect(function()
	pcall(function()
		local args = { [1] = "Ready", [2] = 2 }
		fadeRemote:FireServer(unpack(args))
	end)
end)

task.spawn(function()
	while screen and screen.Parent do
		local pGui = player:FindFirstChild("PlayerGui")
		local exactTokens = nil
		local rawText = ""
		
		if pGui then
			local main = pGui:FindFirstChild("Main")
			if main then
				local currency = main:FindFirstChild("Currency")
				if currency then
					local hTokens = currency:FindFirstChild("HalloweenTokens")
					if hTokens and hTokens:IsA("TextLabel") then
						rawText = hTokens.Text
						-- Extract only digits, ignoring commas, symbols, or letters
						local numStr = rawText:gsub("%D", "")
						exactTokens = tonumber(numStr)
					end
				end
			end
		end
		
		if exactTokens then
			tokenDisplay.Text = "Tokens: " .. tostring(exactTokens)
		else
			tokenDisplay.Text = "Tokens: Not Found (" .. tostring(rawText) .. ")"
		end
		
		task.wait(0.5)
	end
end)
