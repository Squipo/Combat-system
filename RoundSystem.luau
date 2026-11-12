--DISCORD:squipo_| ROBLOX:squipo_0
local run_service = game:GetService("RunService")
local player_service = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")

local player_count_updater = replicated_storage:WaitForChild("Playercountupdater")
local count_down_updater = replicated_storage:WaitForChild("Countdownupdater")
local game_end_ui_updater = replicated_storage:WaitForChild("Gameendupdater") 
local game_start_ui_updater = replicated_storage:WaitForChild("Gamestartupdater") 
local voting_menu_visibility_updater = replicated_storage:WaitForChild("MapMenuUpdater")
local available_maps_shower = replicated_storage:WaitForChild("MapShower")
local vote_count_ui_updater = replicated_storage:WaitForChild("Voteupd")
local game_enter_button_toggler = replicated_storage:WaitForChild("EnterGameBtnUpdater")

local map_folder = replicated_storage:FindFirstChild("Maps")


local players_needed_to_start = 2


local is_countdown_started = false
local maps = { -- save a table with the maps and their votes
	["Cave"] = 0,
	["Forest"] = 0,
	["Ocean"] = 0,
	["Desert"] = 0
}
local queued_players = {} -- declare a variable with a table that store the players that are queued for next round
local players_in_map_table = {} -- declare a variaable with a table that stores the players in the map during the game
local player_data = {} --declare a variable with a table that store the player's data
player_service.PlayerAdded:Connect(function(player:Player) --when a player joins run this function
	player_data[player] = { -- create a table with the player's object inside it
		["debounce"]=false, -- attach this item and value to the player's object in the player_data table
		["voted"] = false, -- attach this item and value to the player's object in the player_data table
		["voted_map"] = nil -- attach this iteam and value to the player's object in the player_data table
	}
end)

local function fire_queued_player_clients(event:RemoteEvent,value:boolean,value2:boolean) -- function for only firing the players that are queued for next round
	for player in queued_players do -- for every item in the queued_players table run this code and save the item in "l"
		event:FireClient(player,value,value2) -- send the value gotten from the function to every player client in the queued_players table
	end
end
local function update_vote(player:Player,map_name:string)
	maps[map_name] += 1 -- increase the value of the item with the same name as the recieved value from event in the maps table by 1
	player_data[player]["voted"] = true -- get the player's data from the player_data table and set the "voted" value to true
	player_data[player]["voted_map"] = map_name -- get the player's data from the player_data table and set the voted_map value to the recieved value from event
	vote_count_ui_updater:FireAllClients(maps[map_name],map_name) -- update the ui that shows each map's vote count on all clients by sending the name of the map that just got voted and the number of votes the map has after it got voted								 
end
local function vote_updater(player:Player,map_name:string)-- sets the value recieved from the event as a parameter of the function							
	if player_data[player]["voted"] then return end --get the player's data from the player_data table and check the voted value. if it is true then return	
	update_vote(player,map_name) -- update the vote
end
vote_count_ui_updater.OnServerEvent:Connect(vote_updater) -- the event is fired from the client with the sent value as the name of the map they voted for

local players_in_map = 0 -- declare a variable to store the number of players in the map which is changed by the latter function 
local cframe = CFrame.new(0, 52, 0) -- the center position of the spatial query
local size = Vector3.new(2048, 136, 2048) -- the size of the spatial query
local overlap = OverlapParams.new() --declare a variable to configure the rules of the spatial query
overlap.FilterType = Enum.RaycastFilterType.Exclude -- set the filter type to exclude
overlap.FilterDescendantsInstances = {workspace.Maps} --exclue all the intances under the maps folder
local function player_count_updater_function() -- function for counting the players in the map 
	local parts = workspace:GetPartBoundsInBox(cframe,size,overlap) -- declare a variable to store the parts in a certain area (use getpartsinbox for box shaped spatial query)
	players_in_map_table = {} -- reset the players table each time this function is ran so the players are added in the table freshly and the old players removed each time this function runs
	for _, part in parts do -- for every part in the said area run this code
		local character = part:FindFirstAncestorWhichIsA("Model") -- declare a variable to store every the model that is the ancestor of the part
		--(confirming that the part is a part of a model) 
		if not character then continue end -- if the variable declared above comes out nil then skip this iteration
		local humanoid = character:FindFirstChildWhichIsA("Humanoid") -- declare a variable to find and store the humanoid in the model
		--(confirming that the model is indeed a character model )
		if not humanoid then continue end -- if the variable declared above comes out nil then skip this iteration
		if humanoid:GetState() == Enum.HumanoidStateType.Dead then continue end -- if the humanoid of the character is dead then skip this iteration
		local player = player_service:GetPlayerFromCharacter(character) --get the player from the character using the player service
		if not player  then continue end -- if the character model doesnt belong to a player in the game skip this iteration
		players_in_map_table[player] = true -- put the player gotten from the character in the table declared earlier
	end
	players_in_map = 0 --set the players_in_map to 0 before running the for loop meant to increase the player count based on the items in the players_in_map_table
	--(this is to avoid the player count increasing beyond the items in the said table every time the function runs)
	for _ in players_in_map_table do -- for every item in the players_in_map_table run this code
		players_in_map += 1 -- increase the player count by one
	end
	player_count_updater:FireAllClients(players_in_map) -- send the player count to all clients to update the ui for the player count
end

local function player_can_enter_queue(player:Player)
	return not (player_data[player]["debounce"] or player.Character:FindFirstChild("Humanoid"):GetState() == Enum.HumanoidStateType.Dead) -- get the player's data from the player_data table and check the debounce value. if it is true or the player is dead then return
	
end
local function player_has_voted(player:Player)
	return player_data[player]["voted"] and player_data[player]["voted_map"]
end
local function put_player_in_queue(player:Player)
	queued_players[player] = true --if the entering value sent by the client is true then put the player in the queued_players table 
	if is_countdown_started then voting_menu_visibility_updater:FireClient(player,true) end --if the countdown started value is true then fire the voting_menu_visibility_updater event to the client and send the value true 
	--which makes the map voting menu visible
end
local function remove_player_from_queue(player:Player)
	queued_players[player] = nil -- if the entering value sent by the client is false then remove the player from the queued_players table
	voting_menu_visibility_updater:FireClient(player,false) -- fire the voting_menu_visibility_updater event of the player with "false" value to make the map voting menu invisible
end
local function remove_player_vote(player:Player)	
	maps[player_data[player]["voted_map"]] -= 1 -- check for the item in the player_data table with the player's object and check the voted value if it is true then 
	-- decrease the value of the map they voted for by 1
	vote_count_ui_updater:FireAllClients(maps[player_data[player]["voted_map"]],player_data[player]["voted_map"]) --update the ui that shows each map's vote count on all clients 
	--by sending the name of the map they voted for and the number of votes it has now
	player_data[player]["voted"] = false -- get the player's data from the item with the player's object in the player_data table and set the "voted" value to false so they will be able to vote again if they re-enter
end

local queued_player_count = 0 -- declare a variable to store the number of players in the queue which is changed by the latter function 
local function update_player_count()
	queued_player_count = 0 -- set the queued_player_count value to 0 before running the for loop
	--(this is to avoid the queued  player count increasing beyond the items in the said table every time the function runs)
	for i in queued_players do
		queued_player_count += 1 --increase the queued player count for every item in the queued_players table by 1
	end
end
local function queued_player_count_updater(player:Player,entering:boolean)
	if not player_can_enter_queue(player) then return end -- this is to avoid the player getting added before they die and respawn causing a glitch
	player_data[player]["debounce"] = true -- in the player_data table find the item with the player's object and set its debounce value to true so the button wont be spammed thus glitching the countdown
	if entering then -- if the player has entered the queue then put them in the table and if the voting has begun show them the map voting menu
		put_player_in_queue(player) -- put the player in the queue table
	elseif entering == false then 
		remove_player_from_queue(player) -- remove the player from the queue table
		if player_has_voted(player) then -- if the player had voted before leaving prior to the game starting then their votes get removed and the ui becomes invisible to them
			remove_player_vote(player) -- remove the player's vote
		end
	end
	task.delay(2,function() -- used task.delay to prevent pausing the whole thread
		player_data[player]["debounce"] = false -- find the player's object in the player_data table and set the debounce value of the player to false
	end)
	update_player_count() -- update the player count
end
player_count_updater.OnServerEvent:Connect(queued_player_count_updater) -- connect the function to the player_count_updater event
local function countdown()
	for  i = 10 ,0, -1  do -- for every number between 10 and 0 in descending order run this code and save the number in "i"
		if not is_countdown_started then count_down_updater:FireAllClients(0,false) return end -- check if the is_countdown_started has been set to false 
		--if it has then break out of the loop and fire the count_down_updater event to all clients to reset the countdown and hide its ui from all clients
		count_down_updater:FireAllClients(i,true) -- change the countdown ui of all players to the current number and make it visible
		task.wait(1) -- wait 1 second before the next iteration
	end
	count_down_updater:FireAllClients(0,false) -- after the for loop ends reset countdown ui and hide it from all clients
end

local highest_vote = 0 --set the highest vote to 0 by default which will be changed according to the highest value a item posseses in the map value by the function below
local chosen_map -- declare a variable earlier to later store the chosen map through the function below
local function chosen_map_finder()
	for i,vote in maps do -- for every item in the maps table run this code and save the value attached to the item in "vote"
		if vote > highest_vote then
			highest_vote = vote -- if the attached value is higher than the previous iterated item's value then set the highest vote to the current iterated item's value so that it eventually stops on the highest value
			chosen_map = i -- set the chosen map to the current iterated item
		end
	end
	highest_vote = 0  -- reset highest vote to 0 for the next round
	-- (to avoid choosing the same map every round)
end
local function reset_player_counts()
	players_in_map = 0 -- reset the players_in_map value to 0 to avoid wrongly counting players
	queued_player_count = 0 -- reset the queued_player_count value to 0 to avoid wrongly counting queued players
end
local function move_players_cframe_to_map(player:Player)	
	local character = player.Character -- declare a variable to store the character of the item
	if not character then return end -- if the character doesnt exist then skip this iteration because that means the item isnt a player
	local humanoid_root_part = character:FindFirstChild("HumanoidRootPart") -- declare a variable to store the player's humanoidrootpart
	humanoid_root_part.CFrame = CFrame.new(48, 0.5, -444) --move the character's humanoidrootpart to the created cframe which is in the round map
end
local function teleport()
	for player in queued_players do -- for every item in the queued_players table run this code and save the item in "player"
	move_players_cframe_to_map(player)	
	end
end

local function move_players_cframe_to_spawn(player:Player)
	local character = player.Character -- declare a variable to store the character of the item
	if not character then return end -- if the character doesnt exist then skip this iteration because that means the item isnt a player
	local humanoid_root_part  = character:FindFirstChild("HumanoidRootPart") --declare a variable to store the player's humanoidrootpart
	humanoid_root_part.CFrame = CFrame.new(23.694, 288.649, -1045.418) --move the humanoid root part to the created cframe which is on the spawnpoint
end
local function teleport_players_to_spawn()
	for player in players_in_map_table do -- for every item in the players_in_map_table run this code and save the item in "player"
	move_players_cframe_to_spawn(player)
	end
end

local function reset_player_data(player:Player)
	player_data[player]["voted"] = false -- find the item in the player_data table that's the player's object and set it's voted value to false
	player_data[player]["voted_map"] = nil -- get the player's data from the player_data table. specifically, the voted_map value and set it to nil
	
end
local function reset_tables()
	queued_players = {} -- reset the tables containing queued players
	players_in_map_table = {} -- reset the table containing players in the map
	
	for _,player in player_service:GetPlayers() do --for every player in the game run this code and save the player in "player"
		reset_player_data(player)
	end
	
	for map in maps do -- for every item in the maps table run this code and save the item in "map"
		maps[map] = 0 -- set the value of the item in the maps table to 0
	end
end

local function enter_button_toggle_function() -- function for changiong the enter button to leave button and vice versa depending on whether the player is in the queue or not
	for _,v in player_service:GetPlayers() do -- for every player in the game run this code and save the player in "v"
		if queued_players[v] then
			fire_queued_player_clients(game_enter_button_toggler,true,false) -- if the player is in the queued_players table then change the enter button to exit button through the local script
		else 
			game_enter_button_toggler:FireClient(v,false,false) -- if the player isnt in the queued_players table then change the exit button to enter button through the local script
		end
	end
end
local game_state_connection -- declare a variable which will stay empty before it is used to continuously show the game status after the game has begun
local player_count_connection = run_service.Heartbeat:Connect(function()player_count_updater:FireAllClients(queued_player_count)end) -- declare a variable with a connection which continuously shows the amount of players in the queue by default 
local enter_button_connection  = run_service.Heartbeat:Connect(enter_button_toggle_function) -- continuosly show the enter button or exit button depending on whether the player is in the queued table or not 
local intermission = false --declare a variable that serves as a lock for the round cycle
local has_game_started = false -- declare a varibale which stop or lets certain codes run during the game
 
local function switch_player_counter_to_player_in_map()
	player_count_connection:Disconnect() --disconnect the connection that update the ui using queued player count(the players in the queue)
	player_count_connection = nil -- clear the connection from memory
	player_count_connection = run_service.Heartbeat:Connect(player_count_updater_function)-- connect the connection again to update the ui using players_in_map
	
end
local function switch_enter_button_to_exit_button()
	enter_button_connection:Disconnect() -- disconnect the connection that continuosly shows the enter game button
	enter_button_connection = nil -- clear the connection from memory
	enter_button_connection = run_service.Heartbeat:Connect(function() game_enter_button_toggler:FireAllClients(false,true) end) -- reconnect the connection so that it continuously makes both the enter button and leave button invisible
end

local function disconnect_enter_button_connection()
	enter_button_connection:Disconnect() -- disconnect the connection thats making both the enter and exit button invisible 
	enter_button_connection = nil -- remove the connection from memory
end
local function switch_game_state_to_game_ended()
	game_state_connection:Disconnect()  -- disconnect the connection that shows the "game started" ui continuously
	game_state_connection = nil -- remove the connection from memory
	game_state_connection = run_service.Heartbeat:Connect(function()game_end_ui_updater:FireAllClients(true) end) -- reconnect the connection to change the ui to "game ended" and show it to all the players continuosly
end

local function switch_player_counter_to_queued_player_count()
	player_count_connection:Disconnect() -- disconnect the connection thats updating the ui using the players in the map
	player_count_connection = nil -- remove the connection from memory
	player_count_connection = run_service.Heartbeat:Connect(function()player_count_updater:FireAllClients(queued_player_count)end) -- reconnect the connection to update ui using queued player count
end
local function clone_map()
	local cloned_map = map_folder:FindFirstChild(tostring(chosen_map)):Clone() --find the object with the same name as the chosen map in the maps folder in replicated storage and clone it and save it in the declared varibale
	cloned_map.Parent = workspace.Maps --put the clonedmap under the maps folder in workspace so that it will be excluded from the spatial query
	cloned_map.Name = "Map" -- rename the cloned map to "Map" to make it easier to remove it later
	cloned_map.CFrame = CFrame.new(0, -8, 0) -- move the cloned map to the center of the map
end
local function disconnect_game_state_connection()
	game_state_connection:Disconnect() -- disconnect the connection thats showing the "game ended" ui to all players
	game_state_connection = nil -- remove the connection from memory
end

local function reconnnect_enter_button_connection()
	enter_button_connection = run_service.Heartbeat:Connect(enter_button_toggle_function) -- reconnect the connection to make the enter/exit button visible
end

local function remove_map()
	workspace.Maps:FindFirstChild("Map"):Destroy() -- destroy the map in the workspace maps folder
end
local function can_start_game()
	return queued_player_count  >= players_needed_to_start and not has_game_started and not is_countdown_started
end

local function should_countdown_stop()
	return queued_player_count  < players_needed_to_start and not has_game_started and is_countdown_started
end
local function can_stop_gane()
	return has_game_started and players_in_map < players_needed_to_start
end
local function round_manager()
	if intermission then return end -- lock this function if the intermission bool value is true
	if can_start_game() then -- check if the queued_player_count meets the criteria 
		-- check the has_game_started is_countdown_started and intermission values to make sure:
		-- the count down doesnt start when one countdown is running
		--this function doesnt run when the game is already running
		available_maps_shower:FireAllClients(chosen_map) -- fire the client with the previously chosen map to show all the available maps except the previously chosen one
		fire_queued_player_clients(voting_menu_visibility_updater,true) -- show the map menu only to the players in the queued_players table
		is_countdown_started = true -- set the is_countdown_started value to true so this function doesnt run during a running countdown and to allow the for loop for the countdown function to run
		countdown() -- start the countdown
		if not is_countdown_started then return end --make sure tge countdown didnt stop in the middle of the countdown(because if it did it means the game musnt be started )
		game_state_connection = run_service.Heartbeat:Connect(function() game_start_ui_updater:FireAllClients(true) end) -- make the ui visible and change the text to "Game started" for all clients 
		-- heartbeat connection is used here to avoid the ui being invisible to newly joined players or players who just died
		chosen_map_finder() -- find the map with the highest votes
		clone_map() -- clone the map
		teleport() --teleport the players on the map
		voting_menu_visibility_updater:FireAllClients(false) --make the map voting menu invisible
		is_countdown_started = false -- set the is_countdown_started to false so that this code can be ran again on the next round
		switch_player_counter_to_player_in_map()
		switch_enter_button_to_exit_button()
		has_game_started = true -- set the has_game_started value to true to avoid running certail codes at the middle of the game
	elseif should_countdown_stop() then -- this code runs to stop the countdown abdruptly when oe of the players suddenly leave and the
		--  players_in_map goes below the needed criteria
		reset_tables() -- change all the player's data back to default and reset all the map's votes to 0 (so the players will be able to vote again and the same map wont be chosen )
		is_countdown_started = false -- stop the countdown abruptly
		voting_menu_visibility_updater:FireAllClients(false) -- make the map vote menu invisble to everyone
	elseif can_stop_gane() then -- this code runs when not enough players are left in the game to continue it any longer so its time to end the game. reset everything and get everything ready for next round
		intermission = true -- set the intemission value to true to lock all codes in round manager
		teleport_players_to_spawn() -- teleport all players back to spawn
		reset_tables() --change all the player's data back to default and reset all the map's votes to 0 (so the players will be able to vote again and the same map wont be chosen )
		has_game_started = false -- set the has_game_started value to false so that this code wont run when the game hasnt been started 
		reset_player_counts()
		disconnect_enter_button_connection()
		switch_game_state_to_game_ended()
		switch_player_counter_to_queued_player_count()
		task.wait(3)-- wait 3 seconds before running the next code
		remove_map()
		disconnect_game_state_connection()
		game_end_ui_updater:FireAllClients(false) -- make the ui showing the game state (game starting/ending) invisible for all players
		reconnnect_enter_button_connection()
		intermission = false -- unlock all the codes in this function by setting this value to false
	end
end
run_service.Heartbeat:Connect(round_manager) -- continuously look for changes and run the round cycle accordingly

--[[to do list:
continue optimizing from round manager]]
