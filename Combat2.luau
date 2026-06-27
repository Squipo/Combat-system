--DISCORD:squipo_| ROBLOX:squipo_0
--//SERVICES AND REFRENCES
local player = game:GetService("Players")
local dashevent = game:GetService("ReplicatedStorage").Events:WaitForChild("Dash")
local m1event = game:WaitForChild("ReplicatedStorage").Events:WaitForChild("M1")
local dashhitevent = game:GetService("ReplicatedStorage").Events:WaitForChild("Dashhit")
local uppercutevent = game:GetService("ReplicatedStorage").Events:WaitForChild("Uppercut")
local block  = game:GetService("ReplicatedStorage").Events:WaitForChild("Block")
local debris = game:GetService("Debris")
local animations = game:GetService("ReplicatedStorage").Anims
--//TABLES
local states = {}
local abilities = {}
local players={}
local playercontroller = {}
local animobj = {}
--//CREATING CLASSES
--[[Assigns each table as its own __index metamethod.
This allows instances created with setmetatable() to inherit methods
from their respective tables]]
states.__index = states
abilities.__index = abilities
playercontroller.__index = playercontroller

--FUNCTIONS--
--//LOADING ANIMATIONS
--[[ Loads and caches all animations for a character into a lookup table.
 Uses the Humanoid's Animator to ensure proper Roblox animation pipeline handling.
 Returns a table where keys are animation names and values are AnimationTracks.]]
local function loadanimation(character)
	local animator = character:WaitForChild("Humanoid"):WaitForChild("Animator")
	local cache = {}
	for i, anim in ipairs(animations:GetChildren()) do
	cache[anim.Name] = animator:LoadAnimation(anim)
	end
	return cache
end
--//STUN FUNCTION
--[[ Temporarily disables movement by setting WalkSpeed/JumpPower to 0.
 Uses state flag to prevent overlapping stun instances]]
local function stun(plr:Player,humanoid: Humanoid)
	local stat = plr and players[plr] or players[humanoid.Parent]
	if not stat then return end
	local oldws = humanoid.WalkSpeed
	local oldjp = humanoid.JumpPower
	if oldws == 0 then oldws = 16 end
	if oldjp == 0 then oldjp = 50 end
	
	task.spawn(function()
	stat.abilities.anims["Stun"]:Play()
	if stat.state:getstate("stun") then return end
	stat.state:setstate("stun",true)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	task.wait(1)
	stat.state:setstate("stun",false)
	humanoid.WalkSpeed = oldws
	humanoid.JumpPower = oldjp
	return
	end)
end
--// KNOCKBACK FUNCTION
--[[ Applies a short-lived force to push a character away from an impact point.
Uses LinearVelocity for immediate and controllable knockback.]]
local function knockback(hrp: Part, direction: Vector3,kb: number)
	local attachment = Instance.new("Attachment")
	attachment.Parent = hrp
	local vel = Instance.new("LinearVelocity")
	vel.Parent = attachment
	vel.Attachment0 = attachment
	vel.MaxForce = math.huge
	vel.VectorVelocity = direction * kb
	debris:AddItem(attachment,0.1)
	debris:AddItem(vel,0.1)
end
--// HITBOX FUNCTION
--[[ Performs hit detection using a box overlap region in front of the attacker.
Filters only characters inside workspace.Characters to reduce unnecessary checks.
Prevents multi-hit on the same humanoid using a local debounce table.
Ignores self-hit and dead characters.
Respects blocking state and cancels damage if target is blocking.
Applies knockback, stun, and damage to valid targets.]]
local function hitbox(hrp:Part,attacker:Humanoid,dmg:number, kb:number,direction: Vector3)
	local plr = nil
	local hithumanoids = {}
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = {workspace.Characters}
	local parts = workspace:GetPartBoundsInBox(hrp.CFrame*CFrame.new(0,0,-2),Vector3.new(5,5,5),overlap)
	for i, part in ipairs(parts) do
		if part.Parent:FindFirstChild("Humanoid") == nil then continue end
		local hum = part.Parent.Humanoid
		if attacker == hum then continue end
		if hithumanoids[hum] == true then continue end
		if hum.Health <= 0 then continue end
		hithumanoids[hum] = true
		plr = player:GetPlayerFromCharacter(hum.Parent)
		if plr == nil then
			plr = hum.Parent
		else
			plr = game.Players:GetPlayerFromCharacter(hum.Parent)
		end
		local target = players[plr]
		if not target then continue end
		if target.state:getstate("blocking") then continue end
		knockback(part.Parent.HumanoidRootPart,direction,kb)
		stun(plr,hum)
		hum:TakeDamage(dmg)
	end
end

--//STATES OBJECT CREATION
--[[Implements a lightweight state machine using a table with metatable behavior.
Each instance represents a character state container (running, dashing, attacking, stun, blocking).
States are stored as key-value pairs, allowing flexible expansion without rewriting the structure.
Provides simple getter/setter methods to control state changes safely.]]
function states.new()
	local self = setmetatable({},states)
	self.running = false
	self.dashing = false
	self.attacking = false
	self.stun = false
	self.blocking = false
	return self
end

function states:setstate(state,value)
	self[state] = value
end

function states:getstate(state)
	return self[state] 
	
end

--// ABILITY CONTROLLER
--[[ Creates an ability controller instance for a player or NPC character.
This object manages combat actions (m1, dash, block, stun interactions)
and stores runtime combat data such as animations, damage values, and combo state.
Uses a shared controller reference to access state machine and character context.]]
function abilities.new(controller,anims)
	local self = setmetatable({},abilities)
	self.player = controller.player
	self.controller = controller
	self.anims = anims
	self.time = 0
	if controller.player:IsA("Player") then
		self.humanoid = controller.player.Character:WaitForChild("Humanoid")
	else
		self.humanoid = controller.player:WaitForChild("Humanoid")
	end
	self.hrp = self.humanoid.Parent:WaitForChild("HumanoidRootPart")
	self.dmg = 0
	self.kb = 0
	self.combo = 1
	return self
end
--// DASH ABILITY
--[[ Performs a short forward dash using the LinearVelocity physics system.
The ability first validates that the character is able to act, then
temporarily enters the "dashing" state to prevent other abilities from
being used simultaneously. A LinearVelocity object is applied to move
the character before being cleaned up automatically.]]
function abilities:dash()
	if not self:canuseability() then return end
	
	self.controller.state:setstate("dashing",true)
		
	local attachment = Instance.new("Attachment",self.hrp)
	local dash = Instance.new("LinearVelocity",attachment)
	dash.MaxForce = math.huge
	dash.VectorVelocity = self.hrp.CFrame.LookVector * 50
	dash.Attachment0 = attachment
	debris:AddItem(dash,0.2)
	debris:AddItem(attachment,0.2)
	self.anims["Dash"]:Play()
		
	task.wait(0.5)
	self.controller.state:setstate("dashing",false)
	self.anims["Dash"]:Stop()
	
end
--// M1 ABILITY
--[[ Executes the melee attack for the character.
Implements a three-hit combo system that progresses with consecutive attacks.
If the player waits longer than one second between attacks, the combo
sequence is reset back to the first punch.]]

function abilities:m1()
	if not self:canuseability() then return end
	if os.clock() - self.time >= 1 then
		self.combo = 1
	end
	self.time = os.clock()
	self.controller.state:setstate("attacking",true)
	if self.combo == 1 then
		self.anims["Punch1"]:Play()
		self.combo = 2
		self.dmg = 10
		self.kb = 10
	elseif self.combo == 2 then
		self.anims["Punch2"]:Play()
		self.dmg = 20
		self.kb = 15
		self.combo = 3
	elseif self.combo == 3 then
		self.anims["Punch3"]:Play()
		self.dmg = 20
		self.kb = 30
		self.combo = 1
	end
hitbox(self.hrp,self.humanoid,self.dmg,self.kb,self.hrp.CFrame.LookVector)
task.wait(0.5)
self.controller.state:setstate("attacking",false)
end
--// DASH HIT ABILITY
--[[Performs a forward dash that transitions into a close-range attack.
The user is moved using LinearVelocity while their movement is temporarily
disabled to prevent input conflicts during the attack animation.
After a short wind-up, a hitbox is created to damage and knock back
any valid targets before restoring the user's movement.]]
function abilities:dashhit(humanoid:Humanoid)
	if not self:canuseability() then return end
	self.controller.state:setstate("attacking",true)
	local attachment = Instance.new("Attachment",self.hrp)
	local dash = Instance.new("LinearVelocity",attachment)
	dash.MaxForce = math.huge
	dash.VectorVelocity = self.hrp.CFrame.LookVector * 50
	dash.Attachment0 = attachment
	debris:AddItem(dash,0.2)
	debris:AddItem(attachment,0.2)
	self.anims["Dashhit"]:Play()
	local ogw = humanoid.WalkSpeed
	local ogj = humanoid.JumpPower
	humanoid.WalkSpeed = 0 
	humanoid.JumpPower = 0
	task.wait(0.5)
	hitbox(self.hrp,self.humanoid,20,10,self.hrp.CFrame.LookVector)
	humanoid.WalkSpeed = ogw
	humanoid.JumpPower = ogj
	self.controller.state:setstate("attacking",false)
end
--// BLOCKING ABILITY
--[[ Toggles the blocking state for the character.
While blocking is active, the controller marks the player as blocking so
incoming hitboxes can ignore damage. The blocking animation is
also started or stopped to match the player's current defensive state.]]
function abilities:blocking(start)
	if self.controller.state:getstate("attacking") then return end
	if self.controller.state:getstate("dashing") then return end
	if self.controller.state:getstate("stun") then return end
	if start then
		self.anims["Block"]:Play()
		self.controller.state:setstate("blocking",true)
	else 
		self.anims["Block"]:Stop()
		self.controller.state:setstate("blocking",false)
	end
end
--// UPPERCUT ABILITY
--[[Executes an upward melee attack that launches the target upwards.
The attack is locked using the controller's state system to prevent
overlapping abilities. The hitbox direction includes an upward vector,
causing knockback to lift targets instead of pushing them only forward to replicate an uppercut.]]
function abilities:uppercut()
	if not self:canuseability() then return end
	self.controller.state:setstate("attacking",true)
	self.anims["UpperCut"]:Play()
	hitbox(self.hrp,self.humanoid,20,10,self.hrp.CFrame.LookVector+ Vector3.new(0,5,0))
	task.wait(0.5)
	self.controller.state:setstate("attacking",false)
end
--// PLAYER OBJECT CREATION
--[[Creates a controller that manages a single character's gameplay logic.
The controller acts as the central object for that character, storing
references to the player/NPC, their current state, and their abilities.
Each character receives its own independent controller instance.]]
function playercontroller.new(plr:Player,anims)
	local self = setmetatable({},playercontroller)
	self.player = plr
	self.state = states.new()
	self.abilities = abilities.new(self,anims)
	return self
end
--// ATTACK VIERFIER
function abilities:canuseability()
	if self.controller.state:getstate("attacking") then return false end
	if self.controller.state:getstate("dashing") then return false end
	if self.controller.state:getstate("stun") then return false end
	if self.controller.state:getstate("blocking") then return false end
	return true
end
player.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
	players[plr] = playercontroller.new(plr,loadanimation(char))
	char.Parent = workspace.Characters
	end)
end)

uppercutevent.OnServerEvent:Connect(function(plr)
	players[plr].abilities:uppercut()
end)
dashevent.OnServerEvent:Connect(function(plr)
	players[plr].abilities:dash()
end)
m1event.OnServerEvent:Connect(function(plr)
	players[plr].abilities:m1()
end)
dashhitevent.OnServerEvent:Connect(function(plr)
	players[plr].abilities:dashhit(plr.Character.Humanoid)
end)
block.OnServerEvent:Connect(function(plr,start)
	players[plr].abilities:blocking(start)
end)
