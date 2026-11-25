--DISCORD:squipo_| ROBLOX:squipo_0
local replicated_storage = game:GetService("ReplicatedStorage")
local player_service = game:GetService("Players")

local events = replicated_storage.Events
local player_enter_queue_event = events.Player_manager
local vote_event = events.Voteupd
local map_show_event = events.Showmaps
local game_values = game.Workspace:WaitForChild("Baseplate")



local maps_folder = replicated_storage.Maps

local players_needed_to_start = 2

local maps = {
	["Cave"] = 0,
	["Desert"] = 0,
	["Ocean"] = 0 ,
	["Forest"] = 0
}


local function check_humanoid_dead(player:Player)
	local character = player.Character -- store the character in a variable so it can be nil checked 
	if not character then return end -- nil check the variable above to avoid runtime error
	local humanoid = character:FindFirstChild("Humanoid") -- store the humanoid in a variable so it can be nil checked
	if not humanoid then return end -- nil check the humanoid to avoid runtime error
	if humanoid:GetState() == Enum.HumanoidStateType.Dead then -- confirm that the humanoid is dead by checking its state
		return true -- as this function is used to confirm the player's character is dead, return true if its dead 
	else
		return false  -- as this function is used to confirm the player's character is dead, return false if its not dead 
	end
end




local function update_player_vote_data(player:Player,map_name:string)
	player:SetAttribute("voted",true) -- set the player's "voted" attribute to true so the player cant vote again
	player:SetAttribute("voted_map",map_name) -- save the player's voted map in an attribute of the player so it can be used to remove the vote from the map later
end
local function reset_player_vote_data(player:Player)
	player:SetAttribute("voted",false) -- as this function is called whenever the game is ready to enter its voting stage, set the player's voted attribute to false so they can vote again
end
local function increase_vote(map_name:string)
	maps[map_name] += 1 -- increase the vote of the map in the maps table so it can be used by the mapchoose function later
	maps_folder:FindFirstChild(map_name):SetAttribute("votes",maps[map_name]) -- increase the votes attribute of the map in the maps folder so that the ui can be updated
end
local function decrease_vote(player:Player)
	if player:GetAttribute("voted")  == false then return end -- check if the user has voted or not before decreasing the vote. so the vote count wont decrease everytime the player removes their queue leading to a game break
	local player_voted_map = player:GetAttribute("voted_map") -- store the player's voted map in a variable so it can be easily accessed and increase readaibilty
	maps[player_voted_map] -= 1 -- decrease the vote of the map in the maps table so it can be used bt rhe mapchoose function later
	maps_folder:FindFirstChild(player_voted_map):SetAttribute("votes",maps[player_voted_map]) -- decrease the map's "votes" attribute in the maps folder to update ui
end
local function register_vote(player:Player,map_name:string)
	if player:GetAttribute("queued") ~= true then return end -- as the player gets remove from queue after dying, quit the function if the player isnt queued so votes cant go past the amount of players in the queue
	if player:GetAttribute("voted") then return end -- if the player has already voted then quit the function to accurately show how many people voted for a map
	update_player_vote_data(player,map_name) -- update the player's atttribute so they can't vote unfairly
	increase_vote(map_name) -- increase the map's vote so the mapchooser function can properly choose the map with the highest votes
end
vote_event.OnServerEvent:Connect(register_vote) -- each time the player presses the vote button run the above funtion to register the vote properly





local players_table ={} -- used a players table to keep track of queued plaeyrs for efficiently  iterating through queued players
local function player_adding(player:Player)
	if player:GetAttribute("queued") then return end -- as the player has their queued attribute to true when being added, quit the function if the player is already queued to avoid the same player being queued and telported multiple times
	players_table[player] = true -- put the player in the players table so they can be safely teleported in and out of the map
	game_values:SetAttribute("Players",game_values:GetAttribute("Players")+1) -- increase the players attribute so the ui can be updated
	player:SetAttribute("queued",true) -- set the player's queued attribute to true so the mapvoting ui can be showed to them once the countdown start
end
local function player_removing(player:Player)
	if player:GetAttribute("queued") == false then return end -- as the player has their queued attribute to false when being removed, quit the function if the player hasn't even queued yet to avoid causing an error 
	players_table[player] = nil -- remove the player from the players table so they wont be teleported in the map even if they dont wanna participate in the next match
	game_values:SetAttribute("Players",game_values:GetAttribute("Players")-1) -- decrease the players attribute so the ui can be updated
	player:SetAttribute("queued",false) -- set the player's queued attribute to false so the mapvoting ui will be hid from them
end
local function player_all_removing()
	for player in players_table do -- remove every player from the players table after the game ends so they can choose to or not to participate in the next round
		player_removing(player)
	end
end
local function reset_all_player_data()
	for player in players_table do
		decrease_vote(player) -- decrease the vote of every player in the table so the votes will be reset and the players can vote for another map 
		reset_player_vote_data(player) -- reset the data of every player in the table so the players can vote again in the next round
	end
end	
local function button_cooldown(player:Player)
	if player:GetAttribute("debounce") == true then return end -- if the player's button is in cooldown quit the function so the player wont be placed in multiple cooldowns simultaneously and increase their wait time
	player:SetAttribute("debounce",true) -- place the player in cooldown  for the button so they wont glitch the countdown
	task.delay(1,function() -- used task delay to avoid pausing the thread
		player:SetAttribute("debounce",false) -- after one second since the player used the button remove their cooldown so they may wish to leave queue or enter the queue again
	end)
end
local function can_player_not_use_button(player:Player)
	return check_humanoid_dead(player) or player:GetAttribute("debounce") -- check if the player is dead so they wont be added to the players table while they are dead because once they respawn their data gets reset and they can vote again. 
	-- this will prevent them from  voting twice in the same voting stage
end
local function player_management(player:Player,entering:boolean)
	if can_player_not_use_button(player) then return end -- check if the player can use the button or not for the reasons stated above
	if entering then -- as the same remote event is used for entering and exiting the queue, check if the event was sent by the enter button or not
		player_adding(player) -- add the player in the table so they cant be teleported once the game starts
		button_cooldown(player) -- put the player on cooldown for using the button so they wont glitch the countdown
	else
		decrease_vote(player) -- if the player wants to exit then decrease the vote so the total votes wont go past total queued players
		reset_player_vote_data(player) -- reset the players data so they can vote again if they choose to enter the queue
		player_removing(player) -- as they dont want to participate in the next round, rmeove the player from the table so they wont be teleported in the map
		button_cooldown(player) -- put the player on cooldown for using the button so they wont gliych the countdown
	end
end
player_enter_queue_event.OnServerEvent:Connect(player_management) -- when the enter or exit button is pressed and the remote event is fired call the player management function 





local function teleport(player:Player,cframe:CFrame)
	local character = player.Character -- store the character in a separate variable for easier debugging
	local humanoid_root_part = character:FindFirstChild("HumanoidRootPart") -- store the humanoidrootpart in a variable so that it can be nil checked
	if not humanoid_root_part then return end -- nil check the humanoid root part to avoid runtime error
	humanoid_root_part.CFrame = cframe -- move the player's hhumanoid root part's position to the passed cframe so they can be teleported properly and can participate in the game properly 
end
local function teleport_back()
	if players_table == nil then return end -- in the case of a solo match, the players table might be empty, nil check it to avoid a runtime error
	for player in players_table do
		teleport(player,CFrame.new(176, 318.881, -4)) -- teleport every player in the table out of the map and into the lobby so the map can be easily reset 
	end
end
local function teleport_in_map()
	for player in players_table do
		teleport(player,CFrame.new(0, 2, 0)) -- teleport every player in the table into the map so they can participate in the map
	end
end


local function choose_map()
	local chosen_map -- put a nil variable on the very top of the function so it can be changed by the below code
	local highest_vote = -1 -- set the initial highest vote to a negative value so if none of the map are voted a random map can be selected 
	for map,votes in maps do
		if votes > highest_vote then 
			highest_vote = votes -- if the map's vote is higher than the previous map's vote then change the value to the current maps vote so if the next iterated map has more votes it will be set as the chosen map 
			chosen_map = map -- if the maps vote is higher than the previous map's vote or the currently recorded highest vote then select that map as the chosen map ensuring that the map with the highest vote will remain in the variable
		end
	end
	return chosen_map -- after the loop ends and all the maps are iterated only the map with the highest vote will remain in the variable, so return it
end
local function clone_map()
	local map_name = choose_map() -- use the choose map function to get the map with the highest vote and store it in a separate variable for easier debugging
	local map = maps_folder:FindFirstChild(map_name):Clone() -- run the choosemap functio to find the map with highest votes in the maps folder, clone and store it in a variable so the clone can be parented, named and positioned
	map.CFrame = CFrame.new(0,-8,0) -- change the cloned maps position to have a consisten spawn postition
	map.Parent = game.Workspace.Activemap -- parent the map in the workplace so it can appear in the actual game and players can play the game in the map put the map in the folder as well in the case of a player having the same name as the map
	map.Name = "Map" -- change the map's name to a simple "map" so it can be easily deleted later
end
local function destroy_map()
	local map = workspace.Activemap:FindFirstChild("Map") -- store the map instance in a variable so it can be nil checked
	if not map then return end -- nil check the map to avoid runtime error
	map:Destroy() -- destroy the map so it can be reset
end


local countdown_lock -- keep a variable at top that will be controlled by the latter functions
local function countdown()
	countdown_lock = false -- as the only purpose of this variable is to stop the countdown abruptly and know the countdown was abruptly stopped, unlock the countdown whenever the countdown needs to be started
	for count = 10,1,-1 do
		if countdown_lock then return end -- if the countdown lock is true quit countdown abdruptly so the ui wont be updated
		game_values:SetAttribute("Countdown",count) -- change the countdown attribute to the current count so the ui can be updated
		task.wait(1) -- wait one second between each iteration 
	end
end


local function countdown_pause()
	game_values:SetAttribute("Gamestate","Ended") -- set the gamestate to ended so the necessary UIs can be shown 
	countdown_lock = true -- set the variable to true to stop the countdown and prevent the game to get past the countdown stage
	reset_all_player_data() -- since the countdown/voting stage was stopped abruptly remove the votes made by them and reset their voting states so they can vote again if the sufficient players are there
end
local function game_start()
	game_values:SetAttribute("Gamestate","Countdown") -- set the gamestate attribute to countdown so the neccessary UIs can be shown
	map_show_event:FireAllClients() -- fire the remote event to show the available maps, this is only done once each countdown event because the players must strictly be shown the same voting options
	countdown() -- start the count down to let players know how long is the voting period
	if countdown_lock == true then return end -- if the countdown was stopepd abruptly dont go past the countdown/voting stage since there isnt enough players for the game
	clone_map() -- find the map with the highest votes and clone it into workspace under a folder so the players can play in it
	teleport_in_map() -- teleport the players in map 
	game_values:SetAttribute("Gamestate","Started") -- set the gamestate attribute to started so the neccessary UIs can be shown
end
local function game_end()
	teleport_back() -- teleport the players back to lobby so the map can be reset
	destroy_map() -- destroy the map and reset it
	reset_all_player_data() -- reset the player's data so they can vote and participate in the next round
	player_all_removing() -- remove all players from the table so the player can decide whether to participate in the next round or not
	game_values:SetAttribute("Gamestate","Ended") -- set the gamestate to ended so the necessary UIs can be shown 

end


local function can_start()
	local is_game_ended = game_values:GetAttribute("Gamestate") == "Ended" -- check if gamestate is ended and store it in a variable for easier debugging
	local is_enough_players = game_values:GetAttribute("Players") >= players_needed_to_start -- check if there is enough players and store it in a variable for easier debugging
	return is_game_ended and is_enough_players -- return the two variables because if both are true then there is sufficient players and the game has ended so the voting for the next match can begun 
end
local function should_pause()
	local is_game_in_countdown = game_values:GetAttribute("Gamestate") == "Countdown" -- check if gamestate is countdown and store it in a variable for easier debugging
	local is_not_enough_players = game_values:GetAttribute("Players") < players_needed_to_start --  check if there is not enough players and store it in a variable for easier debugging
	return is_game_in_countdown and is_not_enough_players --  return the two variables because if both are true then there isnt sufficient players but the game has ended so the voting for the next match needs to be paused 
end
local function can_end()
	local is_game_started = game_values:GetAttribute("Gamestate") == "Started" -- check if gamestate is started and store it in a variable for easier debugging
	local is_not_enough_players = game_values:GetAttribute("Players") < players_needed_to_start --  check if there is not enough players and store it in a variable for easier debugging
	return is_game_started and is_not_enough_players --return the two variables because if both are true then there isnt sufficient players but the game has started so the game can be ended
end
local function round_state_management()
	if can_start() then -- as only one map can exist at a time the can start function checks if the game has ended to avoid cloning maps that overlap and for having a proper round system 
		game_start() -- if the sufficient criteras are met then this function is ran which starts the countdown, clones the map and teleports the players
	elseif should_pause() then -- as the function below is for pausing the cooldown and resetting player data, whether the countdown is happening or not is checked first
		countdown_pause() -- if the sufficient criteras are met then this function is ran which stops the countdown
	elseif can_end() then -- as the function below ends the game and resets everything, whether the game has begun or not is checked first before calling it
		game_end() -- if the sufficient criterias are met then this function is ran which resets the player datas, resets the map and remove the players from the table
	end
end
game_values:GetAttributeChangedSignal("Players"):Connect(round_state_management) --whenever the amount of player changes the function above gets ran to change the gamestate according to the player count and manage the overall rounds





local function reset_attributes(player:Player)
	player:SetAttribute("debounce",false) -- as this function gets called whenever the player dies or newly joins the debounce needs to be set to false (or be created) so they can use the buttons (because they are kicked out of queue when they die)
	player:SetAttribute("voted",false) -- as this function gets called whenever the player dies or newly joins the voted attribute for the player needs to be set to false(or be created) so they can vote again (because their vote gets removed once they die)
	player:SetAttribute("queued",false) -- as this function gets called whenever the player dies or newly join the queued needs to be set to false (or be created)so they can join the queue ( because they are kicked out of queue after dying)
end
local function on_dead(player:Player)
	player_removing(player) --when a player dies remove them from the player table so a dead player won't be teleporting thus causing the players to be miscounted once they respawn
	decrease_vote(player) -- as they are removed from the players table, decrease their vote to avoid the total votes going past the total players
	reset_attributes(player)-- as they have  their vote removed and they are removed from the players table, reset the attributes so they will be able to vote or participate in the next match again 
end
local function on_character_added(character:Model,player:Player)
	local humanoid = character:WaitForChild("Humanoid") -- store the player's humanoid in a variable for easier debugging 
	humanoid.Died:Connect(function()
		on_dead(player) -- connect the function to a player's death, so whenever a player dies they get removed from the table, their vote gets removed and their attributes get removed for reasons stated above
	end)
end
local function on_player_added(player:Player)
	reset_attributes(player) -- when a new player joins, set all the attributes used in the script so they will be able to use all the ui functions again(map_name isn't set there as the map_name is never checked except when decreasing vote, but in that case the existence of the map_name is confirmed through the voted attribute
	player.CharacterAdded:Connect(function(character:Model)
		on_character_added(character,player)-- used character added to get the character of the newly joined player
	end)
end
player_service.PlayerAdded:Connect(on_player_added)
