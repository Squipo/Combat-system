--DISCORD:squipo_| ROBLOX:squipo_0
local player = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local block  = rs.Events:WaitForChild("Block")
local debris = game:GetService("Debris")
local animations = rs.Anims

local states = {}
local abilities = {}
local players={}
local playercontroller = {}
-- The three tables below are used as class-like prototypes. Assigning each table to
-- its own __index field makes missing instance members fall back to the prototype
-- when an object is created with setmetatable(), which is the basis of the OOP
-- pattern used by the controller, state, and ability objects in this script.
states.__index = states
abilities.__index = abilities
playercontroller.__index = playercontroller

-- RemoteEvents are collected into one lookup table so the networking layer only
-- has to resolve the ReplicatedStorage hierarchy once. The ability methods below
-- are deliberately kept separate from the event callbacks, so the same combat
-- logic can be called by both players and the test NPCs at the bottom of the script.
local events = {
	-- WaitForChild yields until the named RemoteEvent exists; this avoids indexing
	-- a missing instance during server startup while rs.Events is being created.
	M1 = rs.Events:WaitForChild("M1"),
	Dash = rs.Events:WaitForChild("Dash"),
	Dashhit = rs.Events:WaitForChild("Dashhit"),
	Uppercut = rs.Events:WaitForChild("Uppercut")
}

-- AnimationTracks are cached per character so attacks do not repeatedly call
-- Animator:LoadAnimation(). The returned table is later stored by abilities.new()
-- and accessed by animation name, allowing each controller to use its own tracks.
local function loadanimation(character)
	-- WaitForChild is chained because the animation system depends on both a
	-- Humanoid and its Animator existing before LoadAnimation can be called.
	local animator = character:WaitForChild("Humanoid"):WaitForChild("Animator")

	-- A new cache is created for every character so AnimationTracks are not shared
	-- between characters; each Animator therefore owns the tracks it plays.
	local cache = {}

	-- ipairs iterates through the Animation instances returned by GetChildren(),
	-- allowing every animation to be converted into an AnimationTrack for this
	-- character's Animator.
	for i, anim in ipairs(animations:GetChildren()) do
		-- The animation's Name becomes the lookup key, while LoadAnimation creates
		-- the character-specific AnimationTrack used by the ability controller.
		cache[anim.Name] = animator:LoadAnimation(anim)
	end

	-- Returning the cache connects animation loading with playercontroller.new(),
	-- which passes these tracks into abilities.new() for later combat actions.
	return cache
end

-- The stun helper accepts either a Player or an NPC-like character reference.
-- Both are resolved into the same controller structure so the rest of the function
-- can operate identically regardless of whether the target is a player or NPC.
local function stun(plr:Player, humanoid:Humanoid)

	-- Player characters are stored using the Player as their key, while NPCs are
	-- stored using their Model. This fallback allows one function to support both.
	local stat = plr and players[plr] or players[humanoid.Parent]

	-- A character without a registered controller cannot safely access the state
	-- or ability objects, so the function exits before attempting those accesses.
	if not stat then return end

	-- Store the current movement properties so the character can be returned to
	-- its previous configuration instead of assuming every Humanoid uses defaults.
	local oldws = humanoid.WalkSpeed
	local oldjp = humanoid.JumpPower

	-- If movement was already zero, use the normal defaults so the stun does not
	-- accidentally preserve zero movement after the stun finishes.
	if oldws == 0 then oldws = 16 end
	if oldjp == 0 then oldjp = 50 end

	-- task.spawn allows the stun timer to run independently without making the
	-- hitbox function wait for the entire stun duration.
	task.spawn(function()

		-- The AnimationTrack belongs to this character's cached animation table,
		-- so the stun animation is played through the same animation system used
		-- by the other abilities.
		stat.abilities.anims["Stun"]:Play()

		-- Prevent another stun coroutine from replacing the current stun while
		-- the character is already locked in the stunned state.
		if stat.state:getstate("stun") then return end

		-- The state system records the stun so canuseability() and other systems
		-- can recognize that this character is temporarily unable to act.
		stat.state:setstate("stun", true)

		-- Setting these Humanoid properties to zero prevents normal movement while
		-- the state system handles the logical side of the stun.
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0

		-- Only this spawned task yields, leaving the rest of the server free to
		-- process other players and combat actions.
		task.wait(1)

		-- Remove the logical stun state before restoring movement so subsequent
		-- ability checks immediately see the character as available.
		stat.state:setstate("stun", false)

		-- Restore the values captured before the stun rather than forcing every
		-- character back to a single movement configuration.
		humanoid.WalkSpeed = oldws
		humanoid.JumpPower = oldjp

		return
	end)
end

-- Knockback is separated from hit detection so every attack can reuse the same
-- physics implementation while supplying its own direction and force.
local function knockback(hrp:Part, direction:Vector3, kb:number)

	-- The Attachment gives LinearVelocity a point on the target's assembly to
	-- operate from without requiring a permanent attachment on every character.
	local attachment = Instance.new("Attachment")
	attachment.Parent = hrp

	-- LinearVelocity creates a temporary physics constraint that can directly
	-- control the target's velocity during the knockback window.
	local vel = Instance.new("LinearVelocity")
	vel.Parent = attachment

	-- Connect the constraint to the attachment created specifically for this hit.
	vel.Attachment0 = attachment

	-- A very large force allows the knockback to overcome normal character forces
	-- long enough to produce a consistent combat reaction.
	vel.MaxForce = math.huge

	-- Multiplying the direction by kb converts the supplied direction into the
	-- actual velocity magnitude that LinearVelocity applies to the target.
	vel.VectorVelocity = direction * kb

	-- Both objects are temporary. Debris automatically removes them so repeated
	-- attacks do not leave unused physics instances attached to characters.
	debris:AddItem(attachment, 0.1)
	debris:AddItem(vel, 0.1)
end

-- Hit detection is centralized here so M1, dash-hit, and uppercut all share the
-- same target filtering, blocking, knockback, stun, and damage rules.
local function hitbox(
	hrp:Part,
	attacker:Humanoid,
	dmg:number,
	kb:number,
	direction:Vector3
)

	-- A single character can contribute several body parts to the overlap query.
	-- This table ensures that one Humanoid can only be processed once per hitbox.
	local hithumanoids = {}

	-- OverlapParams controls which instances the spatial query is allowed to return,
	-- avoiding unnecessary checks against unrelated objects in Workspace.
	local overlap = OverlapParams.new()

	-- Include means only descendants of the supplied filter instances are considered,
	-- which makes the combat query specifically target the Characters container.
	overlap.FilterType = Enum.RaycastFilterType.Include

	-- Restrict the spatial query to characters so map geometry and other workspace
	-- objects do not enter the combat-processing loop.
	overlap.FilterDescendantsInstances = {workspace.Characters}

	-- CFrame multiplication moves the box two studs forward from the attacker's
	-- root part. Vector3.new defines its dimensions, while OverlapParams applies
	-- the character-only filtering rules to the spatial query.
	local parts = workspace:GetPartBoundsInBox(
		hrp.CFrame * CFrame.new(0, 0, -2),
		Vector3.new(5, 5, 5),
		overlap
	)

	-- GetPartBoundsInBox returns BaseParts rather than Humanoids, so each result
	-- must first be resolved back to the character that owns the body part.
	for i, part in ipairs(parts) do

		-- Not every returned part is guaranteed to have a Humanoid as its direct
		-- parent's child, so this check prevents invalid Humanoid indexing.
		if part.Parent:FindFirstChild("Humanoid") == nil then
			continue
		end

		-- Store the Humanoid because it is the object used for health, identity,
		-- and applying the final damage.
		local hum = part.Parent.Humanoid

		-- The attacker can also be inside their own hitbox, so comparing Humanoid
		-- instances prevents the attack from affecting its creator.
		if attacker == hum then
			continue
		end

		-- Multiple body parts may belong to the same character. The table lookup
		-- prevents each of those parts from producing another hit.
		if hithumanoids[hum] then
			continue
		end

		-- Dead characters are ignored because their remaining body parts can still
		-- exist physically inside the overlap region after death.
		if hum.Health <= 0 then
			continue
		end

		-- Mark the Humanoid before applying effects so additional body parts from
		-- the same character cannot duplicate the attack.
		hithumanoids[hum] = true

		-- GetPlayerFromCharacter returns a Player for player characters and nil for
		-- NPCs. The fallback to hum.Parent therefore gives NPCs their Model key.
		local plr = player:GetPlayerFromCharacter(hum.Parent) or hum.Parent

		-- Both players and NPCs are represented by playercontroller objects inside
		-- the same table, allowing combat logic to use one controller interface.
		local target = players[plr]

		-- An unregistered character has no state/controller information, so it must
		-- be skipped before attempting to access its combat state.
		if not target then
			continue
		end

		-- Blocking is checked centrally here so every attack using this hitbox
		-- automatically follows the same defensive rule.
		if target.state:getstate("blocking") then
			continue
		end

		-- Apply the attack's configured knockback direction and magnitude to the
		-- target's root part.
		knockback(
			part.Parent.HumanoidRootPart,
			direction,
			kb
		)

		-- The same target/controller is passed into stun so the target's state and
		-- movement are updated consistently with the hitbox result.
		stun(plr, hum)

		-- Only a target that passed all previous checks reaches TakeDamage(), keeping
		-- invalid, blocked, dead, and self targets out of the damage stage.
		hum:TakeDamage(dmg)
	end
end

-- playercontroller is the top-level object for one character. It owns that
-- character's state object and ability controller, creating a clear hierarchy:
-- Player/NPC -> Controller -> State + Abilities.
function playercontroller.new(plr:Player, anims)

	-- setmetatable connects this instance to playercontroller.__index so methods
	-- defined on the prototype can be called through this individual object.
	local self = setmetatable({}, playercontroller)

	-- Store the original Player or NPC Model so the controller retains ownership
	-- information for later lookups.
	self.player = plr

	-- pcall prevents an unexpected Character property access from terminating
	-- controller creation. The success result determines which object type was given.
	local success, character = pcall(function()
		return plr.Character
	end)

	-- Players expose Character, whereas NPC Models already represent the character.
	-- Supporting both paths lets the same controller architecture manage both.
	if success then
		self.humanoid = character:WaitForChild("Humanoid")
	else
		self.humanoid = plr:WaitForChild("Humanoid")
	end

	-- The root part is cached because movement, hitboxes, and directional attacks
	-- repeatedly require it.
	self.hrp = self.humanoid.Parent:WaitForChild("HumanoidRootPart")

	-- Each controller gets its own state object so one character's flags cannot
	-- accidentally affect another character.
	self.state = states.new()

	-- The controller is passed into the ability object, allowing abilities to access
	-- the same Humanoid, root part, state machine, and character context.
	self.abilities = abilities.new(self, anims)

	return self
end

-- The state object stores simple boolean combat conditions. Keeping state in its own
-- object prevents individual abilities from managing unrelated state variables.
function states.new()

	-- Connect the new table to the states prototype so shared methods such as
	-- setstate() and getstate() are available on every state instance.
	local self = setmetatable({}, states)

	-- Every new character begins with no active movement/combat restrictions.
	self.running = false
	self.dashing = false
	self.attacking = false
	self.stun = false
	self.blocking = false

	return self
end

-- Centralizing state writes gives the rest of the combat system one interface for
-- changing states rather than directly modifying the internal table everywhere.
function states:setstate(state, value)
	self[state] = value
end

-- The getter hides the table implementation from callers. A missing state naturally
-- returns nil, which behaves as false in the conditional checks used by the system.
function states:getstate(state)
	return self[state]
end

-- abilities is responsible for combat actions while playercontroller remains
-- responsible for character ownership and shared context.
function abilities.new(controller, anims)

	-- Link the instance to abilities.__index so shared ability methods are resolved
	-- through the prototype rather than copied into every object.
	local self = setmetatable({}, abilities)

	-- Keep the parent controller so abilities can access the character's global state
	-- without creating a second independent state system.
	self.controller = controller

	-- Cache commonly accessed character references to avoid repeated hierarchy searches.
	self.hrp = controller.hrp
	self.humanoid = controller.humanoid

	-- Store the character-specific animation cache generated by loadanimation().
	self.anims = anims

	-- time records the previous M1 timestamp and is later compared with os.clock()
	-- to determine whether the combo continuation window has expired.
	self.time = 0

	-- These fields provide per-controller storage for combat values that can be
	-- expanded later as more abilities require temporary attack data.
	self.dmg = 0
	self.kb = 0

	-- Starting at one means the first M1 selects combodata[1]. Each attack later
	-- replaces this value with the next combo index.
	self.combo = 1

	return self
end

-- canuseability() is the central validation layer for mutually exclusive actions.
-- Every ability can call this method instead of duplicating the same conditions.
function abilities:canuseability()

	-- Read the state object belonging to this ability's parent controller.
	local state = self.controller.state

	-- These states represent actions that prevent another ability from starting.
	local blocklist = {
		"attacking",
		"dashing",
		"stun",
		"blocking"
	}

	-- Iterate through the state names so one active restriction is enough to reject
	-- the requested ability without repeating four separate conditionals.
	for i, statename in blocklist do

		-- getstate() provides the current boolean value without exposing how state
		-- storage is implemented internally.
		if state:getstate(statename) then
			return false
		end
	end

	-- No mutually exclusive state is active, so the ability is allowed to begin.
	return true
end

-- Dash uses LinearVelocity for temporary forward movement and the state system to
-- prevent another ability from starting during the dash window.
function abilities:dash()

	-- Validate before creating physics objects or playing an animation so rejected
	-- actions produce no side effects.
	if not self:canuseability() then
		return
	end

	local state = self.controller.state

	-- Select the AnimationTrack that was cached specifically for this character.
	local dashanim = self.anims["Dash"]

	-- Mark the character as dashing before applying movement so another request cannot
	-- pass canuseability() while this ability is active.
	state:setstate("dashing", true)

	-- Create a temporary attachment because LinearVelocity needs an attachment
	-- reference on the character's physical assembly.
	local attachment = Instance.new("Attachment", self.hrp)

	-- LinearVelocity provides a controlled burst of movement without permanently
	-- changing the character's normal movement configuration.
	local dash = Instance.new("LinearVelocity", attachment)

	-- A large force prevents ordinary character forces from immediately cancelling
	-- the intended dash velocity.
	dash.MaxForce = math.huge

	-- LookVector represents the direction the HumanoidRootPart is facing. Multiplying
	-- it by 50 converts that unit direction into the desired dash velocity.
	dash.VectorVelocity = self.hrp.CFrame.LookVector * 50

	-- Connect the constraint to the attachment created for this dash.
	dash.Attachment0 = attachment

	-- The dash physics is temporary, so Debris cleans both instances automatically.
	debris:AddItem(dash, 0.2)
	debris:AddItem(attachment, 0.2)

	-- Play the cached animation after the movement components have been configured.
	dashanim:Play()

	-- This wait defines the logical dash duration while yielding only this thread.
	task.wait(0.5)

	-- Release the state lock so another ability can begin.
	state:setstate("dashing", false)

	-- Explicitly stop the animation so the visual state cannot continue after the dash.
	dashanim:Stop()
end

-- M1 uses a data-driven combo table. The table contains attack-specific data while
-- the surrounding function contains the common combo, animation, and hitbox logic.
function abilities:m1()

	-- Use the shared validation system before modifying combo or attack state.
	if not self:canuseability() then
		return
	end

	-- os.clock() provides elapsed time used to determine whether the previous M1
	-- occurred recently enough to continue the combo.
	if os.clock() - self.time >= 1 then

		-- A gap of one second or more resets the sequence to the first punch.
		self.combo = 1
	end

	-- Save this attack's timestamp so the next M1 can measure its interval.
	self.time = os.clock()

	-- Lock the character before executing the attack so another ability cannot start
	-- while this attack is active.
	self.controller.state:setstate("attacking", true)

	-- Each combo entry stores configuration rather than executable code. This means
	-- attack values can be changed without rewriting the common M1 implementation.
	local combodata = {

		[1] = {
			anim = "Punch1",
			nextcmbo = 2,
			dmg = 10,
			kb = 10
		},

		[2] = {
			anim = "Punch2",
			nextcmbo = 3,
			dmg = 20,
			kb = 15
		},

		[3] = {
			anim = "Punch3",
			nextcmbo = 1,
			dmg = 20,
			kb = 30
		}
	}

	-- Use the current combo number as the configuration lookup key.
	local attack = combodata[self.combo]

	-- Retrieve the correct cached AnimationTrack using the configuration's name.
	self.anims[attack.anim]:Play()

	-- Advance immediately so the following M1 uses the configured next combo entry.
	-- Punch three points back to one, creating the repeating three-hit sequence.
	self.combo = combodata[self.combo].nextcmbo

	-- Pass the attack's unique damage and knockback values into the shared hitbox
	-- while LookVector makes the attack direction follow the character's facing.
	hitbox(
		self.hrp,
		self.humanoid,
		attack.dmg,
		attack.kb,
		self.hrp.CFrame.LookVector
	)

	-- Keep the attacking state active for the remainder of the attack window.
	task.wait(0.5)

	-- Once the attack window has finished, allow another ability to begin.
	self.controller.state:setstate("attacking", false)
end

-- Dash-hit combines movement and melee damage. It uses the attacking state because
-- the character is committed to an attack sequence rather than being in a normal dash.
function abilities:dashhit(humanoid:Humanoid)

	if not self:canuseability() then
		return
	end

	-- Prevent other combat actions while the dash-hit sequence is running.
	self.controller.state:setstate("attacking", true)

	-- Create a temporary physics setup for the forward dash.
	local attachment = Instance.new("Attachment", self.hrp)
	local dash = Instance.new("LinearVelocity", attachment)

	dash.MaxForce = math.huge
	dash.VectorVelocity = self.hrp.CFrame.LookVector * 50
	dash.Attachment0 = attachment

	-- The physics objects only exist for the short movement burst.
	debris:AddItem(dash, 0.2)
	debris:AddItem(attachment, 0.2)

	-- Play the character-specific dash-hit animation from the cached tracks.
	self.anims["Dashhit"]:Play()

	-- Save the caller's movement configuration because the ability temporarily
	-- overrides it and should restore the original values afterward.
	local ogw = humanoid.WalkSpeed
	local ogj = humanoid.JumpPower

	-- Disable normal movement so player/NPC locomotion does not fight the attack
	-- sequence while it is approaching its impact point.
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	-- Delay the hitbox until the intended impact moment of the ability.
	task.wait(0.5)

	-- Reuse the central hitbox implementation so dash-hit receives the same filtering,
	-- blocking, knockback, stun, and damage behavior as other attacks.
	hitbox(
		self.hrp,
		self.humanoid,
		20,
		10,
		self.hrp.CFrame.LookVector
	)

	-- Restore the exact movement configuration captured before the ability began.
	humanoid.WalkSpeed = ogw
	humanoid.JumpPower = ogj

	-- Release the attack lock after the dash-hit sequence completes.
	self.controller.state:setstate("attacking", false)
end

-- Blocking is represented as a state rather than a separate hit-detection system.
-- hitbox() reads this state, allowing every attack to automatically respect blocking.
function abilities:blocking(start)

	local state = self.controller.state

	-- These actions cannot be entered while another mutually exclusive action is active.
	local blocklist2 = {
		"attacking",
		"dashing",
		"stun"
	}

	for i, statename in blocklist2 do

		-- Abort the blocking request if the character is currently performing one
		-- of the incompatible actions.
		if state:getstate(statename) then
			return
		end
	end

	-- The boolean argument determines whether blocking should start or stop.
	if start then

		-- Start the cached blocking animation for this specific character.
		self.anims["Block"]:Play()

		-- Once enabled, hitbox() can detect this state and ignore incoming damage.
		self.controller.state:setstate("blocking", true)

	else

		-- Stop the visual representation when blocking ends.
		self.anims["Block"]:Stop()

		-- Clear the state so future hitboxes can affect this character normally.
		self.controller.state:setstate("blocking", false)
	end
end

-- Uppercut reuses the standard hitbox and knockback system. Its only special behavior
-- is supplying an upward component to the knockback direction.
function abilities:uppercut()

	if not self:canuseability() then
		return
	end

	-- Lock the character so another ability cannot interrupt the uppercut.
	self.controller.state:setstate("attacking", true)

	-- Play the character-specific cached uppercut animation.
	self.anims["UpperCut"]:Play()

	-- LookVector supplies forward movement while Vector3.new adds an upward component.
	-- hitbox() passes this combined vector into knockback(), allowing the same physics
	-- function to create an upward launch without needing a separate uppercut system.
	hitbox(
		self.hrp,
		self.humanoid,
		20,
		10,
		self.hrp.CFrame.LookVector + Vector3.new(0, 5, 0)
	)

	task.wait(0.5)

	-- Release the attack state after the uppercut's active window.
	self.controller.state:setstate("attacking", false)
end

-- CharacterAdded is used because PlayerAdded only guarantees that the Player exists;
-- its Character may be created later or recreated after death.
player.PlayerAdded:Connect(function(plr)

	-- A new controller is required after respawning because the old Humanoid,
	-- root part, and AnimationTracks belong to the previous character.
	plr.CharacterAdded:Connect(function(char)

		-- Load the new character's animation tracks first, then pass the cache into
		-- the controller so all abilities reference tracks owned by this character.
		players[plr] = playercontroller.new(
			plr,
			loadanimation(char)
		)

		-- Moving the character into Characters makes it eligible for the Include
		-- filter used by hitbox(), connecting character registration with detection.
		char.Parent = workspace.Characters
	end)
end)

-- RemoteEvent callbacks stay intentionally small. Networking only resolves the
-- sender's controller while the ability object owns validation and gameplay logic.
events.Uppercut.OnServerEvent:Connect(function(plr)

	-- Call the server-side ability rather than trusting the client to implement
	-- damage, hit detection, or state changes.
	players[plr].abilities:uppercut()
end)

events.Dash.OnServerEvent:Connect(function(plr)

	-- The server resolves the sender's controller and performs the actual dash.
	players[plr].abilities:dash()
end)

events.M1.OnServerEvent:Connect(function(plr)

	-- The client only requests an M1; the server-side controller determines whether
	-- it is allowed and performs the resulting hit detection.
	players[plr].abilities:m1()
end)

events.Dashhit.OnServerEvent:Connect(function(plr)

	-- The current server-side Humanoid is supplied because dashhit temporarily changes
	-- movement properties before performing its impact check.
	players[plr].abilities:dashhit(plr.Character.Humanoid)
end)

-- The client supplies whether blocking should begin or end, while the server-side
-- controller performs the actual state transition and animation changes.
block.OnServerEvent:Connect(function(plr, start)

	players[plr].abilities:blocking(start)
end) 
