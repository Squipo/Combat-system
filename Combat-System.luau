--DISCORD:squipo_| ROBLOX:squipo_0

--SERVICESS
local playerserv = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local debris = game:GetService("Debris")

--Modules

local event = rs:WaitForChild("Events").Slash
local blockevent = rs:WaitForChild("Events").Block

--ASSETS
local animations = {
	parry = Instance.new("Animation"),
	stun = Instance.new("Animation")
	
}
animations.parry.AnimationId = "rbxassetid://136840500235295"
animations.stun.AnimationId = "rbxassetid://83738392468806"

local combodata = {}
local vfx = rs:WaitForChild("VFX")
             
local vfxs = {
	block =  vfx.Block,
	parry = vfx.Parry,
	slash = vfx.Slash
}
local sfx = rs:WaitForChild("SFX")


local sfxs = {
	parry = sfx:WaitForChild("Parry_Atk"),
	block = sfx:WaitForChild("Block"),
	slash = sfx:WaitForChild("Slash"),
	crit = sfx:WaitForChild("Crit"),
}

--CONFIGS

local size = Vector3.new(4,4,4) 
local stuntime = 1
local parrystun = 2
local resettime = 2
local parrywindow = 0.5
local endcombocd = 1

--ATTRIBUTE CREATION
playerserv.PlayerAdded:Connect(function(player)
	if player == nil  then return end
	player.CharacterAdded:Connect(function(char)
	if char == nil then return end
		char:SetAttribute("Blocking",false)
		char:SetAttribute("Parrying",false)
		char:SetAttribute("CanBlock",true)
		char:SetAttribute("CanSlash",true)
		char:SetAttribute("Stunned",false)
		char:SetAttribute("Defense",1)
		char:SetAttribute("Strength",1)
		char:SetAttribute("Crit", 1)
		char:SetAttribute("Attacking",false)
	end)
end)

--FUNCTIONS

local funcs = {}
 --when parried make the attacker stunned to give the target time to recover or retaliate
 --the function sends a feedback of the successful parry by displaying vfx and playing sfx
--sfx and vfx are cloned from an asset and saved as a runtime instance before getting removed by debris
--the function also sets the character to stunned by using the attribute and the setstate function
--saved the animator to a variable to be able to use it later on in order to play animations via roblox's animation system
funcs.parry = function (hithumanoid)
	local animator = hithumanoid:FindFirstChildOfClass("Animator")
	
	local sfxclone = sfxs.parry:Clone()
					
	local track = animator:LoadAnimation(animations.parry)
	track:Play()
					
	sfxclone.Parent = hithumanoid
	sfxclone:Play()
	debris:AddItem(sfxclone, 2)
					
	local vfxclone = vfxs.parry:Clone()
	vfxclone.Parent = workspace
	vfxclone.CFrame = hithumanoid.Parent.HumanoidRootPart.CFrame
	vfxclone.Anchored = true
	debris:AddItem(vfxclone, 0.6)
end

--this function is used as a kind of switch to set the attributes of the character to the desired state 
--the parameters are passed in instead of being hardcodded as this function is used by stunfunc to simplify the code and improve readability
funcs.setstate = function (character,canParry,canBlock,canAttack,stunned)
	character:SetAttribute("CanParry", canParry)
	character:SetAttribute("CanBlock", canBlock)
	character:SetAttribute("CanSlash", canAttack)
	character:SetAttribute("Stunned", stunned)
end
--this function is used to apply linearassemblyvelocity to the humanoidrootpart to produce an immediate knockback
--first, produces the vector from the target toward the attacker then normalizes the vector that allows the strength to be independently controlled by the
--knockback force.  An additional vector is added to the direction to make the target fly up in the air
funcs.knockback = function (knockbackForce, targethrp,attackerhrp)
	local dir = (targethrp.Position - attackerhrp.Position).Unit
	targethrp.AssemblyLinearVelocity = (dir * knockbackForce) + Vector3.new(0, 5, 0)	
end
--this function is used to freeze the passed humanoid's movements and block them from doing any combat actions
--as task.wait,task.spawn is used to run the function in a new thread to not block the main thread 
funcs.stun = function (hum,duration) 
	task.spawn(function()
	if hum.Parent:GetAttribute("Stunned") == true then return end
	local animator = hum:FindFirstChildOfClass("Animator") 
	funcs.setstate(hum.Parent,false,false,false,true)
	local track = animator:LoadAnimation(animations.stun)
	track:Play()
	hum.WalkSpeed = 0
	hum.JumpPower = 0 
	task.wait(duration) 
	funcs.setstate(hum.Parent,true,true,true,false)
	hum.WalkSpeed = 16
	hum.JumpPower = 50
	end)
end
--this function is used to copy the vfx asset and play it on the target humanoidrootpart
--debris is used to remove the vfx after 0.6 seconds
funcs.playvfx = function(hitHumanoid, vfxsource, duration)
	local vfxclone = vfxsource:Clone()
	vfxclone.Parent = hitHumanoid
	vfxclone.CFrame = hitHumanoid.Parent.HumanoidRootPart.CFrame
	vfxclone.Anchored = true
	debris:AddItem(vfxclone,duration)
end
--this function does the same thing as the previous one but used for copying sfx. they are separated as sfx needs to be played differently
funcs.playsfx = function(hitHumanoid,sfxsource,duration)
	local sfxclone = sfxsource:Clone()
	sfxclone.Parent = hitHumanoid
	sfxclone:Play()
	debris:AddItem(sfxclone, duration)
end
--gets called by the event to update the attacker's block and parry attribute
--block and parry are different states when blocking starts the  character create a limited parry window.
--the character continues blocking but is no longer parrying after the window ends 
funcs.block = function(plr, block)
	if plr.Character:GetAttribute("Attacking") == true then return end 
	if not block then
		plr.Character:SetAttribute("Blocking", false)
	else
		plr.Character:SetAttribute("Blocking", true)
		plr.Character:SetAttribute("Parrying", true)
		task.wait(parrywindow)
		plr.Character:SetAttribute("Parrying", false)
	end
end
--simple function to calucalte a chance 
--the higher the crit attribute is the higher the chance of the crit occurring as the selected number needs to be less than the crit attribute
funcs.chancecalc = function(plrattribute)
	local critornot = math.random(1,100) <= plrattribute.crit
	return critornot
end

funcs.isAlive = function(hum)
	return hum.Health > 0
end
--the main atack processor to calculate different damages and knockback according to the passed data
--same for daisplaying vfx and playing sfxs
--the crit calc function from earlier is used to differentiate between a normal attack and a crit using different sfx 
funcs.AttackProcessor = function(attributes,hitHumanoid,data,targethrp,attackerhrp,defformula,attackerhumanoid,crit,damage)
	--when the character is not blocking or parrying then the normal attack is used
	--the character gets stunned normally and takes damage which is calculated through the def formula
	--in this case the character recieves the normal amount of damage
	if attributes.blocking == false and attributes.parrying == false then
		if crit then
			funcs.playsfx(hitHumanoid,sfxs.crit,2)
		else 
			funcs.playsfx(hitHumanoid,sfxs.slash,2)	
		end
		funcs.stun(hitHumanoid,stuntime)
		funcs.knockback(data.kb,targethrp,attackerhrp)
		funcs.playvfx(hitHumanoid,vfxs.slash,0.6)
		hitHumanoid:TakeDamage(damage * defformula)
	--when the character is blocking but not parrying then this function is used
	--the character gets stunned but recieves half the damage and half the knockback
	--but during the final combo it break the character's block and deals the full damage
	elseif attributes.blocking == true  and attributes.parrying == false then
		if crit then
			funcs.playsfx(hitHumanoid,sfxs.crit,2)
		else
			funcs.playsfx(hitHumanoid,sfxs.block,2)		
		end
		funcs.stun(hitHumanoid,stuntime)
		funcs.knockback(data.kb/2,targethrp,attackerhrp)
		funcs.playvfx(hitHumanoid,vfxs.block,0.6)
		hitHumanoid:TakeDamage((damage* defformula)/2)
		if data.combo == 3 then
			hitHumanoid:TakeDamage(damage)
			hitHumanoid.Parent:SetAttribute("Blocking", false)
		end
	--when the character successfully parried an attack this function is used to completely negate the damage and knockback
	elseif attributes.parrying == true then
		funcs.stun(attackerhumanoid,parrystun)
		funcs.parry(hitHumanoid)
	end
end
--recieves the block signal from the client and sets the character to block or not
blockevent.OnServerEvent:Connect(funcs.block)



--recieves the attack signal from the client and sets the character to attack
event.OnServerEvent:Connect(function(player)
	--save the attacker's character and the pos for the hitbox infront of the attacker for better readabily and t avoid repeated access
	local pos = player.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-5)
	local attacker = player.Character
	--save attacker's attributes in a table for easier access
	local attackeratt ={
		str = attacker:GetAttribute("Strength"),
		crit = attacker:GetAttribute("Crit"),
		attacking = attacker:GetAttribute("Attacking")
	}
	--if the character is already attacking then return to avoid attack overlaps
	if attackeratt.attacking == true then return end
	attacker:SetAttribute("Attacking",true)
	
	local attackerhumanoid = attacker.Humanoid
	
	--orginally set the crit to false before changing it according to the chance calc
	local crit = false
	--use the chanceccalc funtion to decide whether the crit will happen or not
	--increase the final damage by 1.5 times if the crit happens
	if funcs.chancecalc(attackeratt) then
		crit = true
		
	else
		crit = false
	end
	--save combo and damage,knockback according to the combo in a table thats unique for each player to prevent all the player having the same combo data
	--this table mainly stores knockback force and damage according to the stage of combo the attacker is in
	if not combodata[player] then
		combodata[player] = {
			combo = 0,
			timewhencombo = 0,
			kb = 0,
			damage = 0
		}
	end
	local data = combodata[player]
	--compares the current time with the time when combo started, if its more than the given resettimee , reset the combo
	if os.clock() - data.timewhencombo > resettime then
		data.combo = 0
	end
	data.combo = data.combo + 1
	data.timewhencombo = os.clock()
	if data.combo > 3 then
		data.combo = 1
	end
	--increase the combo and damage according to the combo to emphasize that the attack gets stronger each hit 
	if data.combo == 1 then
		data.kb = 20 
		data.damage = 10 
	elseif data.combo == 2 then
		data.kb = 35
		data.damage = 15 
	elseif data.combo == 3 then
		data.kb = 60
		data.damage = 20 
	end
	
	--used overlap params to avoid hitting the attacker
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {attacker}
	local parts = workspace:GetPartBoundsInBox(pos,size,params)
	local hitHumanoids = {}
	--[[send the combo for animation and the cooldown for each animation stage and an end combo cd to avoid infinite combo and give the player
	time to counter attack]]
	event:FireClient(player,data.combo,endcombocd)
	task.wait(0.4)
	for i,v in pairs(parts) do
		--gets the target's humanoidrootpart through the "GetPartBoundsInBox" and stores it
		--also stores the attacker's humanoidrootpart for easier access
		--if it doesnt find any humanoidrootpart it will skip it as the found part cannot be processed for an attack
		local target = v.Parent
		local targethrp = target:FindFirstChild("HumanoidRootPart")
		local attackerhrp = attacker.HumanoidRootPart
		local humanoid = target:FindFirstChild("Humanoid")
		if not targethrp then continue end
		--get attributes of the humanoid that has been hit that will later be used to detect if the humanoid is blocking or parrying or
		--calculate the damage reduction according to the defense
		local targetatt = {
			blocking = target:GetAttribute("Blocking"),
			parrying = target:GetAttribute("Parrying"),
			defense = target:GetAttribute("Defense") or 0
		}
		
		--formula for damage reduction that will be used during the dealing damage part to decrease the damage
		--the damage reduction is calculated by the difference between the attacker's strength and the target's defense
		local defformula = 1 + ((attackeratt.str-targetatt.defense)/100)
		if hitHumanoids[humanoid] or not funcs.isAlive(humanoid)  then
			continue
		end
		hitHumanoids[humanoid] = true
		local hitHumanoid = humanoid
		funcs.AttackProcessor(targetatt,hitHumanoid,data,targethrp,attackerhrp,defformula,attackerhumanoid,crit,data.damage)
	end
	--after the entire attack is over set the attacking attribute to false to allow the player to attack again
	attacker:SetAttribute("Attacking",false)
end)
--clear the combo data when player leaves to avoid memory leaks
playerserv.PlayerRemoving:Connect(function(removedplayer)
	combodata[removedplayer] = nil
end)
