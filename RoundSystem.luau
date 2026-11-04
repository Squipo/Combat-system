
local runservice = game:GetService("RunService")
local playerservice = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")

local playercountupd = rs:WaitForChild("Playercountupdater") -- store the remoteevent meant to update the player count ui in the declared variable
local countdownupd = rs:WaitForChild("Countdownupdater") -- store the remoteevent meant to update the countdown ui in the declare variabel
local gamend = rs:WaitForChild("Gameendupdater") -- store the remoteevent meant to change the gamestate ui to "game ended" in the declared variable
local gamestart = rs:WaitForChild("Gamestartupdater") -- store the remoteevent meant to change the gamestate ui to "game started" in the declared variable
local mapupdt = rs:WaitForChild("MapMenuUpdater") -- store the remote event meant to update the map voting menu's visibility in the declared variable 
local mapshow = rs:WaitForChild("MapShower") -- store the remote event meant to show all the available maps in the map voting menu in the declared variable
local voteupd = rs:WaitForChild("Voteupd") -- store the remote event meant to update the ui that shows mapvotes in the declared variable 
local entergamebtnupd = rs:WaitForChild("EnterGameBtnUpdater") -- store the remoteevent meant to toggle between the exit or enter button in the declared variable
local template = rs:WaitForChild("Template") -- store the template ui in the declared variable
local mapfolder = rs:FindFirstChild("Maps") -- store the folder containing all the maps in the declared variable


local playerstostart = 2


local countdownstarted = false
local maps = { -- save a table with the maps and their votes
	["Cave"] = 0,
	["Forest"] = 0,
	["Ocean"] = 0,
	["Desert"] = 0
}
local queuedplayers = {} -- declare a variable with a table that store the players that are queued for next round
local playersinmap = {} -- declare a variaable with a table that stores the players in the map during the game
local playerdata = {} --declare a variable with a table that store the player's data
playerservice.PlayerAdded:Connect(function(pl) --when a player joins run this function
	playerdata[pl] = { -- create a table with the player's object inside it
		["db"]=false, -- attach this item and value to the player's object in the playerdata table
		["voted"] = false, -- attach this item and value to the player's object in the playerdata table
		["votedmap"] = nil -- attach this iteam and value to the player's object in the playerdata table
	}
end)

local function firequeuedplayerclients(event:RemoteEvent,value:boolean,value2:boolean) -- function for only firing the players that are queued for next round
	for l in queuedplayers do -- for every item in the queuedplayers table run this code and save the item in "l"
		event:FireClient(l,value,value2) -- send the value gotten from the function to every player client in the queuedplayers table
	end
end


local function voteupdater(plr,mapname)-- sets the value recieved from the event as a parameter of the function							
	if playerdata[plr]["voted"] then return end --get the player's data from the playerdata table and check the voted value. if it is true then return	
	maps[mapname] += 1 -- increase the value of the item with the same name as the recieved value from event in the maps table by 1
	playerdata[plr]["voted"] = true -- get the player's data from the playerdata table and set the "voted" value to true
	playerdata[plr]["votedmap"] = mapname -- get the player's data from the playerdata table and set the votedmap value to the recieved value from event
	voteupd:FireAllClients(maps[mapname],mapname) -- update the ui that shows each map's vote count on all clients by sending the name of the map that just got voted and the number of votes the map has after it got voted								 
end
voteupd.OnServerEvent:Connect(voteupdater) -- the event is fired from the client with the sent value as the name of the map they voted for

local playercount = 0 -- declare a variable to store the number of players in the map which is changed by the latter function 
local cframe = CFrame.new(0, 52, 0) -- the center position of the spatial query
local size = Vector3.new(2048, 136, 2048) -- the size of the spatial query
local overlap = OverlapParams.new() --declare a variable to configure the rules of the spatial query
overlap.FilterType = Enum.RaycastFilterType.Exclude -- set the filter type to exclude
overlap.FilterDescendantsInstances = {workspace.Maps} --exclue all the intances under the maps folder
local function playercountupdater() -- function for counting the players in the map 
	local parts = workspace:GetPartBoundsInBox(cframe,size,overlap) -- declare a variable to store the parts in a certain area (use getpartsinbox for box shaped spatial query)
	playersinmap = {} -- reset the players table each time this function is ran so the players are added in the table freshly and the old players removed each time this function runs
	for _, part in parts do -- for every part in the said area run this code
		local character = part:FindFirstAncestorWhichIsA("Model") -- declare a variable to store every the model that is the ancestor of the part
		--(confirming that the part is a part of a model) 
		if not character then continue end -- if the variable declared above comes out nil then skip this iteration
		local humanoid = character:FindFirstChildWhichIsA("Humanoid") -- declare a variable to find and store the humanoid in the model
		--(confirming that the model is indeed a character model )
		if not humanoid then continue end -- if the variable declared above comes out nil then skip this iteration
		if humanoid:GetState() == Enum.HumanoidStateType.Dead then continue end -- if the humanoid of the character is dead then skip this iteration
		local player = playerservice:GetPlayerFromCharacter(character) --get the player from the character using the player service
		if not player  then continue end -- if the character model doesnt belong to a player in the game skip this iteration
		playersinmap[player] = true -- put the player gotten from the character in the table declared earlier
	end
	playercount = 0 --set the playercount to 0 before running the for loop meant to increase the player count based on the items in the playersinmap table
	--(this is to avoid the player count increasing beyond the items in the said table every time the function runs)
	for _ in playersinmap do -- for every item in the playersinmap table run this code
		playercount += 1 -- increase the player count by one
	end
	playercountupd:FireAllClients(playercount) -- send the player count to all clients to update the ui for the player count
end

local queuedplayercount = 0 -- declare a variable to store the number of players in the queue which is changed by the latter function 
local function queuedplayercountupdater(plr,entering)
	if playerdata[plr]["db"] or plr.Character:FindFirstChild("Humanoid"):GetState() == Enum.HumanoidStateType.Dead then return end -- get the player's data from the playerdata table and check the db value. if it is true or the player is dead then return
																																   -- this is to avoid the player getting added before they die and respawn causing a glitch
	playerdata[plr]["db"] = true -- in the playerdata table find the item with the player's object and set its db value to true so the button wont be spammed thus glitching the countdown
	if entering then -- if the player has entered the queue then put them in the table and if the voting has begun show them the map voting menu
		queuedplayers[plr] = true --if the entering value sent by the client is true then put the player in the queuedplayers table 
		if countdownstarted then mapupdt:FireClient(plr,true) end --if the countdown started value is true then fire the mapupdt event to the client and send the value true 
		--which makes the map voting menu visible
	elseif entering == false then 
		queuedplayers[plr] = nil -- if the entering value sent by the client is false then remove the player from the queuedplayers table
		if playerdata[plr]["voted"] and playerdata[plr]["votedmap"] then -- if the player had voted before leaving prior to the game starting then their votes get removed and the ui becomes invisible to them
			maps[playerdata[plr]["votedmap"]] -= 1 -- check for the item in the playerdata table with the player's object and check the voted value if it is true then 
			-- decrease the value of the map they voted for by 1
			voteupd:FireAllClients(maps[playerdata[plr]["votedmap"]],playerdata[plr]["votedmap"]) --update the ui that shows each map's vote count on all clients 
			--by sending the name of the map they voted for and the number of votes it has now
			playerdata[plr]["voted"] = false -- get the player's data from the item with the player's object in the playerdata table and set the "voted" value to false so they will be able to vote again if they re-enter
		end
		mapupdt:FireClient(plr,false) -- fire the mapupdt event of the player with "false" value to make the map voting menu invisible
	end
	task.delay(2,function() -- used task.delay to prevent pausing the whole thread
		playerdata[plr]["db"] = false -- find the player's object in the playerdata table and set the db value of the player to false
	end)
	queuedplayercount = 0 -- set the queuedplayercount value to 0 before running the for loop
	--(this is to avoid the queued  player count increasing beyond the items in the said table every time the function runs)
	for i in queuedplayers do
		queuedplayercount += 1 --increase the queued player count for every item in the queuedplayers table by 1
	end
end
playercountupd.OnServerEvent:Connect(queuedplayercountupdater) -- connect the function to the playercountupd event

local function countdown()
	for  i = 10 ,0, -1  do -- for every number between 10 and 0 in descending order run this code and save the number in "i"
		if not countdownstarted then countdownupd:FireAllClients(0,false) return end -- check if the countdownstarted has been set to false 
		--if it has then break out of the loop and fire the countdownupd event to all clients to reset the countdown and hide its ui from all clients
		
		countdownupd:FireAllClients(i,true) -- change the countdown ui of all players to the current number and make it visible
		task.wait(1) -- wait 1 second before the next iteration
	end
	countdownupd:FireAllClients(0,false) -- after the for loop ends reset countdown ui and hide it from all clients
end

local highestvote = 0 --set the highest vote to 0 by default which will be changed according to the highest value a item posseses in the map value by the function below
local chosenmap -- declare a variable earlier to later store the chosen map through the function below
local function chosenmapfinder()
	for i,vote in maps do -- for every item in the maps table run this code and save the value attached to the item in "vote"
		if vote > highestvote then
			highestvote = vote -- if the attached value is higher than the previous iterated item's value then set the highest vote to the current iterated item's value so that it eventually stops on the highest value
			chosenmap = i -- set the chosen map to the current iterated item
		end
	end
	highestvote = 0  -- reset highest vote to 0 for the next round
	-- (to avoid choosing the same map every round)
end

local function teleport()
	for v in queuedplayers do -- for every item in the queuedplayers table run this code and save the item in "v"
		local character = v.Character -- declare a variable to store the character of the item
		if not character then continue end -- if the character doesnt exist then skip this iteration because that means the item isnt a player
		local hrp = character:FindFirstChild("HumanoidRootPart") -- declare a variable to store the player's humanoidrootpart
		hrp.CFrame = CFrame.new(48, 0.5, -444) --move the character's humanoidrootpart to the created cframe which is in the round map
	end
end

local function teleportback()
	for player in playersinmap do -- for every item in the playersinmap table run this code and save the item in "player"
		local character = player.Character -- declare a variable to store the character of the item
		if not character then continue end -- if the character doesnt exist then skip this iteration because that means the item isnt a player
		local hrp  = character:FindFirstChild("HumanoidRootPart") --declare a variable to store the player's humanoidrootpart
		hrp.CFrame = CFrame.new(23.694, 288.649, -1045.418) --move the humanoid root part to the created cframe which is on the spawnpoint
	end
end

local function resettables()
	for _,v in playerservice:GetPlayers() do --for every player in the game run this code and save the player in "v"
		playerdata[v]["voted"] = false -- find the item in the playerdata table that's the player's object and set it's voted value to false
		playerdata[v]["votedmap"] = nil -- get the player's data from the playerdata table. specifically, the votedmap value and set it to nil
	end
	for i,v in maps do -- for every item in the maps table run this code and save the item in "i"
		maps[i] = 0 -- set the value of the item in the maps table to 0
	end
end
local function enterbutton() -- function for changiong the enter button to leave button and vice versa depending on whether the player is in the queue or not
	for _,v in playerservice:GetPlayers() do -- for every player in the game run this code and save the player in "v"
		if queuedplayers[v] then
			firequeuedplayerclients(entergamebtnupd,true,false) -- if the player is in the queuedplayers table then change the enter button to exit button through the local script
		else 
			entergamebtnupd:FireClient(v,false,false) -- if the player isnt in the queuedplayers table then change the exit button to enter button through the local script
		end
	end
end

local gamestateconnection -- declare a variable which will stay empty before it is used to continuously show the game status after the game has begun
local playercountconnection = runservice.Heartbeat:Connect(function()playercountupd:FireAllClients(queuedplayercount)end) -- declare a variable with a connection which continuously shows the amount of players in the queue by default 
local enterbtnconnection  = runservice.Heartbeat:Connect(enterbutton) -- continuosly show the enter button or exit button depending on whether the player is in the queued table or not 
local intermission = false --declare a variable that serves as a lock for the round cycle
local started = false -- declare a varibale which stop or lets certain codes run during the game
local function roundmanager()
	if intermission then return end -- lock this function if the intermission bool value is true
	if queuedplayercount  >= playerstostart and not started and not countdownstarted then -- check if the queuedplayercount meets the criteria 
																											 -- check the started countdownstarted and intermission values to make sure:
																											 -- the count down doesnt start when one countdown is running
																											 --this function doesnt run when the game is already running
		mapshow:FireAllClients(chosenmap) -- fire the client with the previously chosen map to show all the available maps except the previously chosen one
		firequeuedplayerclients(mapupdt,true) -- show the map menu only to the players in the queuedplayers table
		countdownstarted = true -- set the countdownstarted value to true so this function doesnt run during a running countdown and to allow the for loop for the countdown function to run
		countdown() -- start the countdown
		if not countdownstarted then return end --make sure tge countdown didnt stop in the middle of the countdown(because if it did it means the game musnt be started )
		gamestateconnection = runservice.Heartbeat:Connect(function() gamestart:FireAllClients(true) end) -- make the ui visible and change the text to "Game started" for all clients 
		chosenmapfinder()																							  -- heartbeat connection is used here to avoid the ui being invisible to newly joined players or players who just died
		local clonemap = mapfolder:FindFirstChild(tostring(chosenmap)):Clone() --find the object with the same name as the chosen map in the maps folder in replicated storage and clone it and save it in the declared varibale
		clonemap.Parent = workspace.Maps --put the clonedmap under the maps folder in workspace so that it will be excluded from the spatial query
		clonemap.Name = "Map" -- rename the cloned map to "Map" to make it easier to remove it later
		clonemap.CFrame = CFrame.new(0, -8, 0) -- move the cloned map to the center of the map
		teleport() --teleport the players on the map
		mapupdt:FireAllClients(false) --make the map voting menu invisible
		countdownstarted = false -- set the countdownstarted to false so that this code can be ran again on the next round
		playercountconnection:Disconnect() --disconnect the connection that update the ui using queued player count(the players in the queue)
		playercountconnection = nil -- clear the connection from memory
		playercountconnection = runservice.Heartbeat:Connect(playercountupdater)-- connect the connection againt to update the ui using playercount(the players in the map)
		enterbtnconnection:Disconnect() -- disconnect the connection that continuosly shows the enter game button
		enterbtnconnection = nil -- clear the connection from memory
		enterbtnconnection = runservice.Heartbeat:Connect(function() entergamebtnupd:FireAllClients(false,true) end) -- reconnect the connection so that it continuously makes both the enter button and leave button invisible
		started = true -- set the started value to true to avoid running certail codes at the middle of the game
	elseif queuedplayercount  < playerstostart and not started and countdownstarted then -- this code runs to stop the countdown abdruptly when oe of the players suddenly leave and the
																												--  playercount goes below the needed criteria
		resettables() -- change all the player's data back to default and reset all the map's votes to 0 (so the players will be able to vote again and the same map wont be chosen )
		countdownstarted = false -- stop the countdown abruptly
		mapupdt:FireAllClients(false) -- make the map vote menu invisble to everyone
	elseif started and playercount < playerstostart then -- this code runs when not enough players are left in the game to continue it any longer so its time to end the game. reset everything and get everything ready for next round
		intermission = true -- set the intemission value to true to lock all codes in round manager
		teleportback() -- teleport all players back to spawn
		queuedplayers = {} -- reset the tables containing queued players
		playersinmap = {} -- reset the table containing players in the map
		resettables() --change all the player's data back to default and reset all the map's votes to 0 (so the players will be able to vote again and the same map wont be chosen )
		started = false -- set the started value to false so that this code wont run when the game hasnt been started 
		playercount = 0 -- reset the playercount value to 0 to avoid wrongly counting players
		queuedplayercount = 0 -- reset the queuedplayercount value to 0 to avoid wrongly counting queued players
		playercountconnection:Disconnect() -- disconnect the connection thats updating the ui using the players in the map
		playercountconnection = nil -- remove the connection from memory
		playercountconnection = runservice.Heartbeat:Connect(function()playercountupd:FireAllClients(queuedplayercount)end) -- reconnect the connection to update ui using queued player count
		enterbtnconnection:Disconnect() -- disconnect the connection thats making both the enter and exit button invisible 
		enterbtnconnection = nil -- remove the connection from memory
		gamestateconnection:Disconnect()  -- disconnect the connection that shows the "game started" ui continuously
		gamestateconnection = nil -- remove the connection from memory
		gamestateconnection = runservice.Heartbeat:Connect(function()gamend:FireAllClients(true) end) -- reconnect the connection to change the ui to "game ended" and show it to all the players continuosly
		task.wait(3)-- wait 3 seconds before running the next code
		workspace.Maps:FindFirstChild("Map"):Destroy() -- destroy the map in the workspace maps folder
		gamestateconnection:Disconnect() -- disconnect the connection thats showing the "game ended" ui to all players
		gamestateconnection = nil -- remove the connection from memory
		gamend:FireAllClients(false) -- make the ui showing the game state (game starting/ending) invisible for all players
		enterbtnconnection = runservice.Heartbeat:Connect(enterbutton) -- reconnect the connection to make the enter/exit button visible
		intermission = false -- unlock all the codes in this function by setting this value to false
	end
end
runservice.Heartbeat:Connect(roundmanager) -- continuously look for changes and run the round cycle accordingly
