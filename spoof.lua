-- ====================================================================
-- HEADLESS IDENTITY & AVATAR SPOOFER (EXECUTION CODE)
-- Upload this entire block to your GitHub raw link!
-- ====================================================================

print("[Daemon] Pulling settings and initializing spoofer...")

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local localPlayer = Players.LocalPlayer

local realUsername = localPlayer.Name
local realDisplayName = localPlayer.DisplayName

local function escapePattern(str)
	return str:gsub("([^%w])", "%%%1")
end

-- Resolve dynamic environment settings set by the user's loadstring
local function getSetting(name, default)
	local env = (type(getgenv) == "function" and getgenv()) or {}
	if env[name] ~= nil then
		return env[name]
	end
	return default
end

local function getTargetId() return tonumber(getSetting("SpoofTargetId", 2611776)) end
local function getSpoofUsername() return tostring(getSetting("SpoofUsername", "Roblox")) end
local function getSpoofDisplayName() return tostring(getSetting("SpoofDisplayName", "OfficialRoblox")) end

-- ==========================================
-- 1. CLIENT-SIDE AVATAR MORPH
-- ==========================================
local function swapAvatarLocally()
	local character = localPlayer.Character
	if not character then return end
	
	local targetId = getTargetId()
	local success, targetModel = pcall(function()
		return Players:CreateHumanoidModelFromUserId(targetId)
	end)
	
	if not success or not targetModel then 
		warn("[Daemon] Failed to fetch assets for Target ID: " .. tostring(targetId))
		return 
	end
	
	-- Strip current accessories and clothes
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") or child:IsA("Clothing") or child:IsA("ShirtGraphic") or child:IsA("BodyColors") then
			child:Destroy()
		end
	end
	
	-- Apply clothes and skin textures
	for _, child in ipairs(targetModel:GetChildren()) do
		if child:IsA("Clothing") or child:IsA("ShirtGraphic") or child:IsA("BodyColors") then
			child:Clone().Parent = character
		end
	end
	
	-- Attach accessories manually using rigid welds
	local function weldAccessory(accessory)
		local handle = accessory:FindFirstChild("Handle")
		if not handle or not handle:IsA("BasePart") then return end
		local accAttachment = handle:FindFirstChildOfClass("Attachment")
		if not accAttachment then return end
		
		local charAttachment = nil
		for _, part in ipairs(character:GetChildren()) do
			if part:IsA("BasePart") then
				local found = part:FindFirstChild(accAttachment.Name)
				if found and found:IsA("Attachment") then
					charAttachment = found
					break
				end
			end
		end
		
		if charAttachment then
			handle.CanCollide = false
			handle.Anchored = false
			handle.CFrame = charAttachment.WorldCFrame * accAttachment.CFrame:Inverse()
			
			local weld = Instance.new("Weld")
			weld.Name = "AccessoryWeld"
			weld.Part0 = handle
			weld.Part1 = charAttachment.Parent
			weld.C0 = accAttachment.CFrame
			weld.C1 = charAttachment.CFrame
			weld.Parent = handle
		end
	end

	for _, child in ipairs(targetModel:GetChildren()) do
		if child:IsA("Accessory") then
			local clone = child:Clone()
			clone.Parent = character
			weldAccessory(clone)
		end
	end
	
	targetModel:Destroy()
	print("[Daemon] Local character morphed successfully.")
end

-- ==========================================
-- 2. LEADERBOARD, ESC MENU, & UI SPOOFER
-- ==========================================
local function replaceCoreElements()
	local coreSuccess, CoreGui = pcall(function() return game:GetService("CoreGui") end)
	if not coreSuccess or not CoreGui then 
		warn("[Daemon] CoreGui access blocked. UI renaming disabled.")
		return 
	end

	local function handleImageLabel(imageLabel)
		local function updateImage()
			local imageStr = imageLabel.Image
			local realUserIdStr = tostring(localPlayer.UserId)
			local targetUserIdStr = tostring(getTargetId())
			
			local targetHeadshot = "rbxthumb://type=AvatarHeadShot&id=" .. targetUserIdStr .. "&w=150&h=150"
			local targetBust = "rbxthumb://type=AvatarBust&id=" .. targetUserIdStr .. "&w=150&h=150"
			local targetFull = "rbxthumb://type=Avatar&id=" .. targetUserIdStr .. "&w=352&h=352"

			if imageStr ~= "" and string.find(imageStr, "id=" .. realUserIdStr) then
				if string.find(imageStr, "type=Avatar") and not string.find(imageStr, "type=AvatarBust") and not string.find(imageStr, "type=AvatarHeadShot") then
					imageLabel.Image = targetFull
				elseif string.find(imageStr, "type=AvatarBust") then
					imageLabel.Image = targetBust
				elseif string.find(imageStr, "type=AvatarHeadShot") then
					imageLabel.Image = targetHeadshot
				end
			end
		end
		pcall(updateImage)
		imageLabel:GetPropertyChangedSignal("Image"):Connect(function() pcall(updateImage) end)
	end

	local function handleTextLabel(textLabel)
		local function updateText()
			local currentText = textLabel.Text
			if currentText == "" then return end
			
			local spoofUser = getSpoofUsername()
			local spoofDisplay = getSpoofDisplayName()
			
			local updatedText = currentText
			updatedText = string.gsub(updatedText, "@" .. realUsername, "@" .. spoofUser)
			updatedText = string.gsub(updatedText, escapePattern(realDisplayName), spoofDisplay)
			updatedText = string.gsub(updatedText, realUsername, spoofUser)
			
			if updatedText ~= currentText then
				textLabel.Text = updatedText
			end
		end
		pcall(updateText)
		textLabel:GetPropertyChangedSignal("Text"):Connect(function() pcall(updateText) end)
	end

	local function processDescendant(desc)
		if desc:IsA("ImageLabel") then
			handleImageLabel(desc)
		elseif desc:IsA("TextLabel") then
			handleTextLabel(desc)
		end
	end

	pcall(function()
		for _, desc in ipairs(CoreGui:GetDescendants()) do
			processDescendant(desc)
		end
	end)

	CoreGui.DescendantAdded:Connect(function(desc)
		pcall(processDescendant, desc)
	end)
	
	print("[Daemon] Core UI listeners mounted.")
end

-- ==========================================
-- 3. METATABLE HOOKING (INSPECT SPOOFER)
-- ==========================================
local rawMetatable = getrawmetatable and getrawmetatable(game)
if rawMetatable and makewriteable then
	makewriteable(rawMetatable)
	local oldNamecall = rawMetatable.__namecall
	
	rawMetatable.__namecall = newcclosure(function(self, ...)
		local method = getnamecallmethod()
		if self == GuiService and (method == "InspectPlayerFromUserId" or method == "InspectPlayerFromHumanoidDescription") then
			local args = {...}
			local targetId = getTargetId()
			
			if args[1] == localPlayer.UserId then
				return oldNamecall(self, targetId, unpack(args, 2))
			end
		end
		return oldNamecall(self, ...)
	end)
	print("[Daemon] Engine metatable hooked.")
else
	warn("[Daemon] Metatable hooking unsupported on this executor.")
end

-- ==========================================
-- 4. INITIALIZATION & SPAWN BINDINGS
-- ==========================================
task.spawn(swapAvatarLocally)
task.spawn(replaceCoreElements)

localPlayer.CharacterAdded:Connect(function()
	task.wait(0.5)
	task.spawn(swapAvatarLocally)
end)

print("[Daemon] Identity Spoofer fully operational in the background!")