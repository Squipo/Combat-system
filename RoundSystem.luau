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





local players_table ={}
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
	player:SetAttribute("queued",false) -- set the player's queued attribute to false so the mapvoting ui be hid from them
end
local function player_all_removing()
	for player in players_table do -- remove every player from the players table after the game ends so they can choose to or not to participate in the next round
		player_removing(player)
	end
end
local function reset_all_player_data()
	for player in players_table do
		decrease_vote(player) -- decrease the vote of every player in the table so the votes will be reset and the players can vote for another map 
		reset_player_vote_data(player) -- reset the data of every player in the table so 
	end
end	
local function button_cooldown(player:Player)
	if player:GetAttribute("debounce") == true then return end
	player:SetAttribute("debounce",true)
	task.delay(1,function()
		player:SetAttribute("debounce",false)
	end)
end
local function player_management(player:Player,entering:boolean)
	if check_humanoid_dead(player) or player:GetAttribute("debounce") then return end
	if entering then
		player_adding(player)
		button_cooldown(player)
	else
		decrease_vote(player) 
		reset_player_vote_data(player) 
		player_removing(player)
		button_cooldown(player)
	end
end
player_enter_queue_event.OnServerEvent:Connect(player_management)





local countdown_lock = true
local function teleport(player:Player,cframe:CFrame)
	local character = player.Character
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = cframe
end
local function teleport_back(players_table)
	if players_table == nil then return end
	for player in players_table do
		teleport(player,CFrame.new(176, 318.881, -4))
	end
end
local function teleport_in_map(players_table)
	for player in players_table do
		teleport(player,CFrame.new(0, 2, 0))
	end
end


local function choose_map()
	local chosen_map = nil
	local highest_vote = -math.huge
	for map,votes in maps do
		if votes > highest_vote then
			highest_vote = votes
			chosen_map = map
		end
	end
	return chosen_map
end
local function clone_map()
	local map_name = choose_map()
	local map = maps_folder:FindFirstChild(map_name):Clone()
	map.Parent = game.Workspace
	map.Name = "Map"
end
local function destroy_map()
	local map = workspace:FindFirstChild("Map")
	map:Destroy()
end


local function countdown()
	countdown_lock = false
	for count = 10,1,-1 do
		if countdown_lock then return end
		game_values:SetAttribute("Countdown",count)
		task.wait(1)
	end
	game_values:SetAttribute("Countdown",0)
end


local function countdown_pause()
	game_values:SetAttribute("Gamestate","Ended")
	countdown_lock = true
	task.delay(2,function()
		countdown_lock = false
	end)
	game_values:SetAttribute("Countdown",0)
	reset_all_player_data()
end
local function game_start()
	map_show_event:FireAllClients()
	game_values:SetAttribute("Gamestate","Countdown")
	countdown()
	if countdown_lock == true then return end
	clone_map()
	teleport_in_map(players_table)
	game_values:SetAttribute("Gamestate","Started")
end
local function game_end()
	teleport_back(players_table)
	destroy_map()
	reset_all_player_data()
	player_all_removing()
	game_values:SetAttribute("Gamestate","Ended")

end


local function can_start()
	local is_game_ended = game_values:GetAttribute("Gamestate") == "Ended"
	local is_enough_players = game_values:GetAttribute("Players") >= players_needed_to_start
	return is_game_ended and is_enough_players
end
local function should_pause()
	local is_game_in_countdown = game_values:GetAttribute("Gamestate") == "Countdown"
	local is_not_enough_players = game_values:GetAttribute("Players") < players_needed_to_start
	return is_game_in_countdown and is_not_enough_players
end
local function can_end()
	local is_game_started = game_values:GetAttribute("Gamestate") == "Started"
	local is_not_enough_players = game_values:GetAttribute("Players") < players_needed_to_start
	return is_game_started and is_not_enough_players
end
local function round_state_management()
	if can_start() then
		game_start()
	elseif should_pause() then
		countdown_pause()
	elseif can_end() then
		game_end()
	end
end
game_values:GetAttributeChangedSignal("Players"):Connect(round_state_management)





local function reset_attributes(player:Player)
	player:SetAttribute("debounce",false)
	player:SetAttribute("voted",false)
	player:SetAttribute("queued",false)
end
local function on_dead(player:Player)
	player_removing(player)
	decrease_vote(player)
	reset_attributes(player)
end
local function on_character_added(character:Model,player:Player)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		on_dead(player)
	end)
end
local function on_player_added(player:Player)
	reset_attributes(player)
	player.CharacterAdded:Connect(function(character:Model)
		on_character_added(character,player)
	end)
end
player_service.PlayerAdded:Connect(on_player_added)
player_service.PlayerRemoving:Connect(on_dead)
