--!strict
local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("AngryBirds"):WaitForChild("Config"))

Players.CharacterAutoLoads = false
workspace.Gravity = Config.GRAVITY

Lighting.ClockTime = 13.5
Lighting.Brightness = 2.0
Lighting.GlobalShadows = false
Lighting.Ambient = Color3.fromRGB(160, 175, 190)
Lighting.OutdoorAmbient = Color3.fromRGB(175, 195, 215)

local function hideDefaultPart(name: string)
	local inst = workspace:FindFirstChild(name)
	if inst and inst:IsA("BasePart") then
		inst.Transparency = 1
		inst.CanCollide = false
		inst.CanTouch = false
		inst.CanQuery = false
		inst.Position = Vector3.new(0, -500, 0)
	end
end

hideDefaultPart("Baseplate")
hideDefaultPart("SpawnLocation")

-- Anchor ReplicationFocus so StreamingEnabled clients never pause waiting for a character
local streamingFocus = workspace:FindFirstChild("AB_StreamingFocus")
if not streamingFocus then
	local focusPart = Instance.new("Part")
	focusPart.Name = "AB_StreamingFocus"
	focusPart.Size = Vector3.new(1, 1, 1)
	focusPart.Position = Vector3.new(0, 10, 0)
	focusPart.Anchored = true
	focusPart.Transparency = 1
	focusPart.CanCollide = false
	focusPart.CanTouch = false
	focusPart.CanQuery = false
	focusPart.Parent = workspace
	streamingFocus = focusPart
end

local function assignFocus(player: Player)
	if streamingFocus and streamingFocus:IsA("BasePart") then
		player.ReplicationFocus = streamingFocus
	end
end

Players.PlayerAdded:Connect(assignFocus)
for _, p in ipairs(Players:GetPlayers()) do
	assignFocus(p)
end

local function ensureCollisionGroup(name: string)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
end

local groups = Config.CollisionGroups
ensureCollisionGroup(groups.Bird)
ensureCollisionGroup(groups.Block)
ensureCollisionGroup(groups.Pig)
ensureCollisionGroup(groups.Ground)
ensureCollisionGroup(groups.NoCollide)

local allGroups = { groups.Bird, groups.Block, groups.Pig, groups.Ground, groups.NoCollide, "Default" }
for _, g in ipairs(allGroups) do
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(groups.NoCollide, g, false)
	end)
end
