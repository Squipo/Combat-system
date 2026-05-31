--DISCORD:squipo_| ROBLOX:squipo_0

--SERVICESS
local players = game:GetService("Players")
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
local stun = 1
local parrystun = 2
local resettime = 2
local parrywindow = 0.5
local endcombocd = 1
local maxdef = 99
local maxstr = 99

--ATTRIBUTE CREATION
players.PlayerAdded:Connect(function(player)
	if player then
		player.CharacterAdded:Connect(function(char)
			if char then
				local blocking = char:SetAttribute("Blocking",false)
				local parrying = char:SetAttribute("Parrying",false)
				local canblock = char:SetAttribute("CanBlock",true)
				local canslash = char:SetAttribute("CanSlash",true)
				local stunned = char:SetAttribute("Stunned",false)
				local defense = char:SetAttribute("Defense",1)
				local strength = char:SetAttribute("Strength",1)
				local critchance = char:SetAttribute("Crit", 1)
				local attacking = char:SetAttribute("Attacking",false)
			end
		end)
	end

end)

--FUNCTIONS

local funcs = {}
 --when parried make the attacker stunned to give the target time to recover or retaliate
funcs.parry = function (hithumanoid)
	local animator = hithumanoid:FindFirstChildOfClass("Animator")
	
	local sfx = sfxs.parry:Clone()
					
	local track = animator:LoadAnimation(animations.parry)
	track:Play()
					
	sfx.Parent = hithumanoid
	sfx:Play()
	debris:AddItem(sfx, 2)
					
	local vfxclone = vfxs.parry:Clone()
	vfxclone.Parent = workspace
	vfxclone.CFrame = hithumanoid.Parent.HumanoidRootPart.CFrame
	vfxclone.Anchored = true
	debris:AddItem(vfxclone, 0.6)
end


funcs.setstate = function (character,canParry,canBlock,canAttack,stunned)
	character:SetAttribute("CanParry", canParry)
	character:SetAttribute("CanBlock", canBlock)
	character:SetAttribute("CanSlash", canAttack)
	character:SetAttribute("Stunned", stunned)
end

funcs.knockback = function (knockbackForce, targethrp,attackerhrp)
	local dir = (targethrp.Position - attackerhrp.Position).Unit
	targethrp.AssemblyLinearVelocity = (dir * knockbackForce) + Vector3.new(0, 5, 0)	
end
--[[gets called by the hitbox function to stun the attacker or the target depending on wether the target is parrying or not,
when stunned the character is immobile and cant use attacks for a certain duration]]
funcs.stun = function (hum,duration) 
	task.spawn(function()
	if hum.Parent:GetAttribute("Stunned") == false then
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
		end
	end)
end

funcs.blockvfx = function (hitHumanoid)
	local vfxclone = vfxs.block:Clone()
	vfxclone.Parent = workspace
	vfxclone.CFrame = hitHumanoid.Parent.HumanoidRootPart.CFrame
	vfxclone.Anchored = true
	debris:AddItem(vfxclone,0.6)
end

funcs.blocksfx = function (hitHumanoid)
	local sfx = sfxs.block:Clone()
	sfx.Parent = hitHumanoid
	sfx:Play()
	debris:AddItem(sfx, 2)
end

funcs.critsfx = function (hitHumanoid)
	local sfx = sfxs.crit:Clone()
	sfx.Parent = hitHumanoid
	sfx:Play()
	debris:AddItem(sfx, 2)
end


funcs.slashvfx = function (hitHumanoid)
	local vfxclone = vfxs.slash:Clone()
	vfxclone.Parent = workspace
	vfxclone.CFrame = hitHumanoid.Parent.HumanoidRootPart.CFrame
	vfxclone.Anchored = true
	debris:AddItem(vfxclone,0.6)
end

funcs.slashsfx = function (hitHumanoid)
	local sfx = sfxs.slash:Clone()
	sfx.Parent = hitHumanoid
	sfx:Play()
	debris:AddItem(sfx, 2)
end

--gets called by the event to update the attacker's block and parry attribute
funcs.block = function(plr, strin)
	if plr.Character:GetAttribute("Attacking") == false then
		if strin == "False" then
			plr.Character:SetAttribute("Blocking", false)
		elseif strin == "True" then
			plr.Character:SetAttribute("Blocking", true)
			plr.Character:SetAttribute("Parrying", true)
			task.wait(parrywindow)
			plr.Character:SetAttribute("Parrying", false)
		end
	end
	
end

funcs.Chanced = function(plrattribute)
	local chanced = math.random(1,100) <= plrattribute.crit
	return chanced
end

funcs.isAlive = function(hum)
	return hum.Health > 0
end

--BLOCK FUNCTION FOR WHEN THE PLAYER IS BLOCKING
blockevent.OnServerEvent:Connect(funcs.block)



--HITBOX FUNCTION	FOR WHEN THE PLAYER ATTACKS
event.OnServerEvent:Connect(function(player)
	local pos = player.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-5)
	local attacker = player.Character
	attacker:SetAttribute("Attacking",true)
	
	local attackerhumanoid = attacker.Humanoid
	
	---GET player ATTRIBUTES
	local plrattribute ={
		str = attacker:GetAttribute("Strength"),
		crit = attacker:GetAttribute("Crit")
	}
	
	
	if plrattribute.str > maxstr then
		attacker:SetAttribute("Strength", maxstr)
	end
	--formulas for the damage
	local attformuula = 1 + (attacker:GetAttribute("Strength") * 0.01)
	local crit = false
	--if the crit will happen then increase the damage and call the chanced function to decide if its a crit
		if funcs.Chanced(plrattribute) then
		crit = true
		attformuula *= 1.5
		else crit = false
	end
	--[[save combo and damage,knockback according to the combo in a table thats unique for each player to prevent all the player having the
	same combo data]]
	if not combodata[player] then
		combodata[player] = {
			combo = 0,
			timewhencombo = 0,
			kb = 0,
			damage = 0
		}
		
	end
	local data = combodata[player]
	--compares the current time with the time when combo started, if its more than 2 seconds, reset the combo
	if os.clock() - data.timewhencombo > resettime then
		
		data.combo = 0
	end
	data.combo = data.combo + 1
	data.timewhencombo = os.clock()
	if data.combo > 3 then
		data.combo = 1
	end
	--[[increase the combo and damage according to the combo to emphasize that the attack gets stronger each hit multiply the attformula with it
	to increase the damage according to it being a crit or not and the attacker's strength]]
	if data.combo == 1 then
		data.kb = 20 
		data.damage = 10 * (attformuula)
	elseif data.combo == 2 then
		data.kb = 35
		data.damage = 15 * (attformuula)
	elseif data.combo == 3 then
		data.kb = 60
		data.damage = 20 * (attformuula)
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
	local target = v.Parent
	local targethrp = target:FindFirstChild("HumanoidRootPart")
	local attackerhrp = attacker.HumanoidRootPart
	local humanoid = target:FindFirstChild("Humanoid")
	if humanoid then
		--[[get attributes of the humanoid that has been hit that will later be used to detect if the humanoid is blocking or parrying or
		calculate the damage reduction according to the defense]]
			local attributes = {
				blocking = target:GetAttribute("Blocking"),
				parrying = target:GetAttribute("Parrying"),
				defense = target:GetAttribute("Defense") or 0
			}
		if attributes.defense > maxdef then
			target:SetAttribute("Defense",maxdef)
		end
		--formula for damage reduction that will be used during the dealing damage part to decrease the damage
		local defformula = 1 - (target:GetAttribute("Defense") * 0.01)
			if hitHumanoids[humanoid] == nil and funcs.isAlive(humanoid)  then
				hitHumanoids[humanoid] = true
				local hitHumanoid = humanoid
				task.spawn(function()
					
				if attributes.blocking == false and attributes.parrying == false then
					if crit then
						funcs.critsfx(hitHumanoid)
					else 
						funcs.slashsfx(hitHumanoid)
						
					end
					funcs.stun(hitHumanoid,stun)
					funcs.knockback(data.kb,targethrp,attackerhrp)
					funcs.slashvfx(hitHumanoid)
					hitHumanoid:TakeDamage(data.damage * defformula)
				elseif attributes.blocking == true  and attributes.parrying == false then
					if crit then
						funcs.critsfx(hitHumanoid)
					else
						funcs.blocksfx(hitHumanoid)
						
					end
					funcs.stun(hitHumanoid,stun)
					funcs.knockback(data.kb/2,targethrp,attackerhrp)
					funcs.blockvfx(hitHumanoid)
					hitHumanoid:TakeDamage((data.damage* defformula)/2)
					if data.combo == 3 then
						hitHumanoid:TakeDamage(data.damage)
						hitHumanoid.Parent:SetAttribute("Blocking", false)
					end
				elseif attributes.parrying == true then
					funcs.stun(attackerhumanoid,parrystun)
					funcs.parry(hitHumanoid)
				end
				end)
			end
		end
	end
		attacker:SetAttribute("Attacking",false)
end)
--clear the combo data when player leaves to avoid memory leaks
players.PlayerRemoving:Connect(function(removedplayer)
	combodata[removedplayer] = nil
end)