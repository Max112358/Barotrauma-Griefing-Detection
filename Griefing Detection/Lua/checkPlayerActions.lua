--print("your local mod is running")

if SERVER then return end --prevents it from running on the server
--this script runs client side only. clients cannot see the serverLog, so cannot detect wiring issues or the reactor

local susPoints = {} --every time someone does something suspicious, add points. Ring alarm beyond threshold.

-- Use the constructed path. path is a global stored in init
local sound = Game.SoundManager.LoadSound(path .. "/alert.ogg")

local configPath = path .. "/config.json"

-- Function to update player scores
local function increaseSusPoints(playerName, amountToIncrease)
    -- Check if the player is already in the table
    if susPoints[playerName] then
        -- Player is already in the table, increment their score
        susPoints[playerName] = susPoints[playerName] + amountToIncrease
    else
        -- Player is not in the table, add them with a score of 1
        susPoints[playerName] = amountToIncrease
    end
end

-- Function to reduce points for all players
local function reducePointsForAll()

    for playerName, score in pairs(susPoints) do
        -- Decrement the score by 1
		if susPoints[playerName] > 0 then
			susPoints[playerName] = score - 1
		end
    end
	
	Timer.Wait(reducePointsForAll, config.decayTime) --recursively run again every X seconds, where X is decayTime
end

-- Start the timer initially
reducePointsForAll()


-- Function to activate the alarm
local function activateAlarm(printStatement)
	print(printStatement)
	local myPos = Character.Controlled --center on the controlled character
	sound.Play(10, 100000, myPos)
end

-- Function to find the AccountId id from a given character
local function getClientID(passedCharacter)
	local clientID = ""
	for key, client in pairs(Client.ClientList) do
		if client.Character == passedCharacter then
			clientID = client.AccountId
		end
	end
	return clientID
end


--equipped an item
Hook.Add("item.equip", "equippedAnItem", function(item, paramCharacter)
   
	if paramCharacter == nil then return end

	config = json.parse(File.Read(configPath)) -- I have no idea why this is needed. Somehow its not recognizing changes to the global config without it. Reference error somehow?

	local isSuspicious = false
   
	local isYou = false
	--if client ~= nil then
	if Character.Controlled ~= nil then
		isYou = (Character.Controlled.name == paramCharacter.name)
	end
	
	if (isYou and not config.selfAlarmEnabled) then return end --if its your character and self alarm not active, abort
   
	--check against the sus table to see if the item is bad
	for itemName, suspicionLevel in pairs(config.susTable) do
		if itemName == item.Prefab.Identifier and paramCharacter ~= nil then
			increaseSusPoints(paramCharacter.Name, suspicionLevel)
			if susPoints[paramCharacter.Name] > config.susThreshold then 
				isSuspicious = true
			end
			break -- Exit the loop if a match is found
		end
	end

	local clientID = getClientID(paramCharacter)
	if isSuspicious then activateAlarm(paramCharacter.name .. " has equipped " .. item.name .. "!!!!" .. " Client ID: " .. tostring(clientID)) end
end)

--applied an item
Hook.Add("item.applyTreatment", "appliedTreatment", function(item, usingCharacter, targetCharacter, limb)
   
	if usingCharacter == nil then return end
   
	config = json.parse(File.Read(configPath)) -- I have no idea why this is needed. Somehow its not recognizing changes to the global config without it. Reference error somehow?

	local isSuspicious = false
	
	local isYou = false
	if Character.Controlled ~= nil then
		isYou = (Character.Controlled.name == usingCharacter.name)
	end
	if (isYou and not config.selfAlarmEnabled) then return end --if its your character and self alarm not active, abort
   


	--logging items that are suspicious to use in large amounts. No immediate alarm on this, just keep an eye on it.
	for itemName, suspicionLevel in pairs(config.susTable) do
		if itemName == item.Prefab.Identifier and usingCharacter ~= nil then
			increaseSusPoints(usingCharacter.Name, suspicionLevel)
			if susPoints[usingCharacter.Name] > config.susThreshold then 
				isSuspicious = true
			end
			break -- Exit the loop if a match is found
		end
	end
   
	local clientID = getClientID(usingCharacter)
	if isSuspicious then activateAlarm(usingCharacter.name .. " has applied " .. item.Name .. " to " .. targetCharacter.name .. "!!!!" .. " Client ID: " .. tostring(clientID)) end

   
end)

--used an item
Hook.Add("item.use", "usedItem", function(item, itemUser, targetLimb)
   
	if itemUser == nil then return end
   
   	config = json.parse(File.Read(configPath)) -- I have no idea why this is needed. Somehow its not recognizing changes to the global config without it. Reference error somehow?

	local isSuspicious = false

	local isYou = false
	if Character.Controlled ~= nil then
		isYou = (Character.Controlled.name == itemUser.name)
	end
	if (isYou and not config.selfAlarmEnabled) then return end --if its your character and self alarm not active, abort

	--logging items that are suspicious to use in large amounts. No immediate alarm on this, just keep an eye on it.
	for itemName, suspicionLevel in pairs(config.susTable) do
		if itemName == item.Prefab.Identifier and itemUser ~= nil then
			increaseSusPoints(itemUser.Name, suspicionLevel)
			if susPoints[itemUser.Name] > config.susThreshold then 
				isSuspicious = true
			end
			break -- Exit the loop if a match is found
		end
	end
   
	local clientID = getClientID(itemUser)
	if isSuspicious then activateAlarm(itemUser.name .. " has used " .. item.Name .. "!!!!"  .. " Client ID: " .. tostring(clientID)) end
   
end)

--moved item to inventory 
Hook.Add("inventoryPutItem", "transferredAnItem", function(inventory, item, characterUser)
   
	if characterUser == nil then return end
   
	config = json.parse(File.Read(configPath)) -- I have no idea why this is needed. Somehow its not recognizing changes to the global config without it. Reference error somehow?

	-- Check if item.Name matches any entry in config.susTable
	local isSuspicious = false
   
	local isYou = false
	if Character.Controlled ~= nil then
		isYou = (Character.Controlled.name == characterUser.name)
	end
	if (isYou and not config.selfAlarmEnabled) then return end --if its your character and self alarm not active, abort
   
	--if they put welding fuel in a suit or mask
	for _, itemName in ipairs(config.breathingDevices) do
	  if item.Name == "Welding Fuel Tank" and inventory.owner.name == itemName then
		 isSuspicious = true
		 break
	  end
	end
	
	--if they put incendium fuel in a suit or mask
	for _, itemName in ipairs(config.breathingDevices) do
	  if item.Name == "Incendium Fuel Tank" and inventory.owner.name == itemName then
		 isSuspicious = true
		 break
	  end
	end
   
	--if they made a welder bomb
	if item.Name == "Oxygen Tank" and inventory.owner.name == "Welding Tool" then
		isSuspicious = true
	end
	
	--more ways to welder bomb
	if item.Name == "Oxygenite Tank" and inventory.owner.name == "Welding Tool" then
		isSuspicious = true
	end
	
	--logging items that are suspicious to use in large amounts. No immediate alarm on this, just keep an eye on it.
	for itemName, suspicionLevel in pairs(config.susTable) do
		if itemName == item.Prefab.Identifier and characterUser ~= nil then
			print(characterUser.Name .. " has transferred " .. item.name .. " to " .. inventory.owner.name .. ".")
			
			if suspicionLevel > config.susThreshold then
				increaseSusPoints(characterUser.Name, suspicionLevel) --for items that are immediately suspicious
			else
				increaseSusPoints(characterUser.Name, 1) --for normal items like fuel rods
			end
			
			if susPoints[characterUser.Name] > config.susThreshold then 
				isSuspicious = true
			end
			break -- Exit the loop if a match is found
		end
	end

	local clientID = getClientID(characterUser)
	if isSuspicious then activateAlarm(characterUser.Name .. " has transferred " .. item.name .. " to " .. inventory.owner.name .. "!!!!" .. " Client ID: " .. tostring(clientID)) end
end)