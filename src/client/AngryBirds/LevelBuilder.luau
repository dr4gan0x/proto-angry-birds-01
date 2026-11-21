--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("AngryBirds"):WaitForChild("Config"))

local LevelBuilder = {}
LevelBuilder.__index = LevelBuilder

local function setNoCollide(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CollisionGroup = Config.CollisionGroups.NoCollide
end

local function weldAccessory(parent: BasePart, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?, name: string): Part
	local acc = Instance.new("Part")
	acc.Name = name
	acc.Size = size
	acc.Shape = shape or Enum.PartType.Block
	acc.Color = color
	acc.Material = Enum.Material.SmoothPlastic
	acc.TopSurface = Enum.SurfaceType.Smooth
	acc.BottomSurface = Enum.SurfaceType.Smooth
	acc.Massless = true
	acc.Anchored = false
	setNoCollide(acc)
	acc.CFrame = parent.CFrame * offset
	acc.Parent = parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = acc
	weld.Parent = acc
	return acc
end

function LevelBuilder.new(physics2D: any?)
	local self = setmetatable({
		_physics = physics2D,
		_stageFolder = nil :: Folder?,
		_waitingBirds = {} :: { BasePart },
		_activeBird = nil :: BasePart?,
		_slingshotRefs = nil :: any,
	}, LevelBuilder)
	return self
end

function LevelBuilder:_getOrCreateStageFolder(): Folder
	if self._physics and self._physics.getStageFolder then
		local f = self._physics:getStageFolder()
		if f and f.Parent then
			self._stageFolder = f
			return f
		end
	end

	local existing = workspace:FindFirstChild("AngryBirdsStage")
	if existing and existing:IsA("Folder") then
		self._stageFolder = existing
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = "AngryBirdsStage"
	folder.Parent = workspace
	self._stageFolder = folder
	return folder
end

function LevelBuilder:_buildSceneryAndSlingshot(stage: Folder)
	-- Ground grass strip (top surface strictly at Y = Config.GROUND_Y = 0)
	local grass = Instance.new("Part")
	grass.Name = "GroundGrass"
	grass.Size = Vector3.new(170, 1.5, 10)
	grass.CFrame = CFrame.new(0, Config.GROUND_Y - 0.75, 0)
	grass.Anchored = true
	grass.Color = Color3.fromRGB(98, 178, 64)
	grass.Material = Enum.Material.SmoothPlastic
	grass.TopSurface = Enum.SurfaceType.Smooth
	grass.BottomSurface = Enum.SurfaceType.Smooth
	grass.CustomPhysicalProperties = PhysicalProperties.new(1.0, 0.85, 0.08, 1.0, 1.0)
	grass.CollisionGroup = Config.CollisionGroups.Ground
	grass.Parent = stage

	-- Sub-soil earth strip
	local dirt = Instance.new("Part")
	dirt.Name = "GroundDirt"
	dirt.Size = Vector3.new(170, 16, 10)
	dirt.CFrame = CFrame.new(0, Config.GROUND_Y - 9.5, 0)
	dirt.Anchored = true
	dirt.Color = Color3.fromRGB(122, 82, 48)
	dirt.Material = Enum.Material.SmoothPlastic
	setNoCollide(dirt)
	dirt.Parent = stage

	-- 2D Sky backdrop
	local sky = Instance.new("Part")
	sky.Name = "SkyBackdrop"
	sky.Size = Vector3.new(260, 140, 1)
	sky.CFrame = CFrame.new(2, 24, -24)
	sky.Anchored = true
	sky.Color = Color3.fromRGB(132, 206, 250)
	sky.Material = Enum.Material.SmoothPlastic
	setNoCollide(sky)
	sky.Parent = stage

	-- Rolling distant hills (stylized 2D layers)
	local hillSpecs = {
		{ x = -32, y = -3, r = 24, z = -21, color = Color3.fromRGB(110, 192, 92) },
		{ x = 8, y = -5, r = 30, z = -20.5, color = Color3.fromRGB(96, 178, 82) },
		{ x = 44, y = -2, r = 26, z = -21, color = Color3.fromRGB(110, 192, 92) },
		{ x = -12, y = -7, r = 20, z = -17, color = Color3.fromRGB(82, 162, 68) },
		{ x = 28, y = -6, r = 22, z = -17, color = Color3.fromRGB(82, 162, 68) },
	}
	for i, h in ipairs(hillSpecs) do
		local hill = Instance.new("Part")
		hill.Name = "BgHill_" .. tostring(i)
		hill.Shape = Enum.PartType.Cylinder
		hill.Size = Vector3.new(1.2, h.r * 2, h.r * 2)
		hill.CFrame = CFrame.new(h.x, h.y, h.z) * CFrame.Angles(0, math.pi * 0.5, 0)
		hill.Anchored = true
		hill.Color = h.color
		hill.Material = Enum.Material.SmoothPlastic
		setNoCollide(hill)
		hill.Parent = stage
	end

	-- Flat stylized white clouds
	local cloudClusters = {
		{ x = -28, y = 24, s = 1.0 },
		{ x = 4, y = 28, s = 1.25 },
		{ x = 34, y = 25, s = 0.95 },
	}
	for i, cl in ipairs(cloudClusters) do
		local offsets = {
			{ dx = -2.6, dy = 0, r = 2.4 },
			{ dx = 0, dy = 0.9, r = 3.2 },
			{ dx = 2.8, dy = 0, r = 2.5 },
		}
		for j, o in ipairs(offsets) do
			local puff = Instance.new("Part")
			puff.Name = string.format("BgCloud_%d_%d", i, j)
			puff.Shape = Enum.PartType.Cylinder
			puff.Size = Vector3.new(0.8, o.r * 2 * cl.s, o.r * 2 * cl.s)
			puff.CFrame = CFrame.new(cl.x + o.dx * cl.s, cl.y + o.dy * cl.s, -19.5) * CFrame.Angles(0, math.pi * 0.5, 0)
			puff.Anchored = true
			puff.Color = Color3.fromRGB(246, 250, 255)
			puff.Material = Enum.Material.SmoothPlastic
			setNoCollide(puff)
			puff.Parent = stage
		end
	end

	-- Slingshot Y-fork (non-colliding visual anchored around SLINGSHOT_ANCHOR)
	local anchor = Config.SLINGSHOT_ANCHOR
	local woodColor = Color3.fromRGB(110, 68, 34)
	local darkWood = Color3.fromRGB(82, 48, 22)

	local trunk = Instance.new("Part")
	trunk.Name = "SlingshotTrunk"
	trunk.Size = Vector3.new(1.1, 4.4, 1.1)
	trunk.CFrame = CFrame.new(anchor.X, 2.2, 0)
	trunk.Anchored = true
	trunk.Color = woodColor
	trunk.Material = Enum.Material.Wood
	setNoCollide(trunk)
	trunk.Parent = stage

	local forkBack = Instance.new("Part")
	forkBack.Name = "SlingshotForkBack"
	forkBack.Size = Vector3.new(0.85, 3.6, 0.85)
	forkBack.CFrame = CFrame.new(anchor.X, 5.9, -0.75) * CFrame.Angles(math.rad(-14), 0, 0)
	forkBack.Anchored = true
	forkBack.Color = darkWood
	forkBack.Material = Enum.Material.Wood
	setNoCollide(forkBack)
	forkBack.Parent = stage

	local forkFront = Instance.new("Part")
	forkFront.Name = "SlingshotForkFront"
	forkFront.Size = Vector3.new(0.85, 3.6, 0.85)
	forkFront.CFrame = CFrame.new(anchor.X, 5.9, 0.75) * CFrame.Angles(math.rad(14), 0, 0)
	forkFront.Anchored = true
	forkFront.Color = woodColor
	forkFront.Material = Enum.Material.Wood
	setNoCollide(forkFront)
	forkFront.Parent = stage

	local forkLeftPos = Vector3.new(anchor.X, anchor.Y + 0.5, -1.1)
	local forkRightPos = Vector3.new(anchor.X, anchor.Y + 0.5, 1.1)

	local function makeBand(name: string): Part
		local band = Instance.new("Part")
		band.Name = name
		band.Size = Vector3.new(0.32, 0.32, 1)
		band.Anchored = true
		band.Color = Color3.fromRGB(58, 32, 18)
		band.Material = Enum.Material.SmoothPlastic
		band.Transparency = 1
		setNoCollide(band)
		band.Parent = stage
		return band
	end

	local bandLeft = makeBand("SlingshotBandBack")
	local bandRight = makeBand("SlingshotBandFront")

	self._slingshotRefs = {
		stageFolder = stage,
		slingshotAnchor = anchor,
		forkLeft = forkLeftPos,
		forkRight = forkRightPos,
		bandLeft = bandLeft,
		bandRight = bandRight,
	}
end

function LevelBuilder:_createBirdPart(stage: Folder, pos: Vector3, index: number): Part
	local r = Config.BIRD_RADIUS
	local bird = Instance.new("Part")
	bird.Name = "Bird_" .. tostring(index)
	bird.Shape = Enum.PartType.Ball
	bird.Size = Vector3.new(r * 2, r * 2, r * 2)
	bird.CFrame = CFrame.new(pos.X, pos.Y, 0)
	bird.Anchored = true
	bird.Color = Config.Bird.color
	bird.Material = Enum.Material.SmoothPlastic
	bird.TopSurface = Enum.SurfaceType.Smooth
	bird.BottomSurface = Enum.SurfaceType.Smooth
	bird.CustomPhysicalProperties = PhysicalProperties.new(
		Config.Bird.density,
		Config.Bird.friction,
		Config.Bird.elasticity,
		1.0,
		1.0
	)
	-- Waiting queue birds stay non-colliding so downward slingshot pulls never snag on them
	bird.CanCollide = false
	bird.CanTouch = false
	bird.CanQuery = false
	bird.CollisionGroup = Config.CollisionGroups.NoCollide
	bird.Parent = stage

	-- Belly patch + face details facing camera (+Z) and slightly right (+X)
	weldAccessory(bird, Vector3.new(0.62, 0.62, 0.25), CFrame.new(0.55, 0.22, r * 0.82), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball, "EyeR")
	weldAccessory(bird, Vector3.new(0.62, 0.62, 0.25), CFrame.new(0.05, 0.22, r * 0.88), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball, "EyeL")
	weldAccessory(bird, Vector3.new(0.26, 0.26, 0.22), CFrame.new(0.66, 0.22, r * 0.94), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball, "PupilR")
	weldAccessory(bird, Vector3.new(0.26, 0.26, 0.22), CFrame.new(0.16, 0.22, r * 0.98), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball, "PupilL")
	weldAccessory(bird, Vector3.new(0.95, 0.22, 0.22), CFrame.new(0.32, 0.56, r * 0.95) * CFrame.Angles(0, 0, math.rad(-16)), Color3.fromRGB(22, 22, 22), Enum.PartType.Block, "Brow")
	weldAccessory(bird, Vector3.new(0.9, 0.55, 0.55), CFrame.new(r * 0.85, -0.15, r * 0.45) * CFrame.Angles(0, 0, math.rad(-10)), Color3.fromRGB(248, 194, 34), Enum.PartType.Block, "Beak")
	weldAccessory(bird, Vector3.new(0.55, 0.55, 0.4), CFrame.new(-0.2, r * 0.95, 0) * CFrame.Angles(0, 0, math.rad(25)), Config.Bird.color, Enum.PartType.Block, "Crest")

	return bird
end

function LevelBuilder:_createPigPart(stage: Folder, t: any, index: number): Part
	local r = t.radius or Config.PIG_RADIUS
	local pig = Instance.new("Part")
	pig.Name = "Pig_" .. tostring(index)
	pig.Shape = Enum.PartType.Ball
	pig.Size = Vector3.new(r * 2, r * 2, r * 2)
	pig.CFrame = CFrame.new(t.x, t.y, 0)
	pig.Anchored = false
	pig.Color = Config.Pig.color
	pig.Material = Enum.Material.SmoothPlastic
	pig.TopSurface = Enum.SurfaceType.Smooth
	pig.BottomSurface = Enum.SurfaceType.Smooth
	pig.CustomPhysicalProperties = PhysicalProperties.new(
		Config.Pig.density,
		0.85,
		0.05,
		1.0,
		1.0
	)
	pig.CollisionGroup = Config.CollisionGroups.Pig
	pig.Parent = stage

	-- Stylized snout, eyes, ears facing camera (+Z)
	weldAccessory(pig, Vector3.new(1.1, 0.78, 0.5), CFrame.new(0, -0.08, r * 0.96), Color3.fromRGB(168, 240, 108), Enum.PartType.Ball, "Snout")
	weldAccessory(pig, Vector3.new(0.24, 0.32, 0.2), CFrame.new(-0.22, -0.08, r * 1.15), Color3.fromRGB(32, 68, 18), Enum.PartType.Ball, "NostrilL")
	weldAccessory(pig, Vector3.new(0.24, 0.32, 0.2), CFrame.new(0.22, -0.08, r * 1.15), Color3.fromRGB(32, 68, 18), Enum.PartType.Ball, "NostrilR")
	weldAccessory(pig, Vector3.new(0.62, 0.62, 0.28), CFrame.new(-0.56, 0.3, r * 0.9), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball, "EyeL")
	weldAccessory(pig, Vector3.new(0.62, 0.62, 0.28), CFrame.new(0.56, 0.3, r * 0.9), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball, "EyeR")
	weldAccessory(pig, Vector3.new(0.28, 0.28, 0.22), CFrame.new(-0.56, 0.3, r * 1.04), Color3.fromRGB(18, 18, 18), Enum.PartType.Ball, "PupilL")
	weldAccessory(pig, Vector3.new(0.28, 0.28, 0.22), CFrame.new(0.56, 0.3, r * 1.04), Color3.fromRGB(18, 18, 18), Enum.PartType.Ball, "PupilR")
	weldAccessory(pig, Vector3.new(0.45, 0.45, 0.3), CFrame.new(-0.82, 0.95, 0), Config.Pig.color, Enum.PartType.Ball, "EarL")
	weldAccessory(pig, Vector3.new(0.45, 0.45, 0.3), CFrame.new(0.82, 0.95, 0), Config.Pig.color, Enum.PartType.Ball, "EarR")

	return pig
end

function LevelBuilder:buildScenicBackdrop()
	self:clear()
	local stage = self:_getOrCreateStageFolder()
	self:_buildSceneryAndSlingshot(stage)
	return self._slingshotRefs
end

function LevelBuilder:buildLevel(levelDef: any)
	-- Clear existing children inside stageFolder without destroying PlaneAnchor2D if shared with Physics2D
	local stage = self:_getOrCreateStageFolder()
	for _, child in ipairs(stage:GetChildren()) do
		if child.Name ~= "PlaneAnchor2D" then
			child:Destroy()
		end
	end
	self._waitingBirds = {}
	self._activeBird = nil

	self:_buildSceneryAndSlingshot(stage)

	-- Spawn blocks
	for i, b in ipairs(levelDef.blocks) do
		local matSpec = Config.Materials[b.material]
		local part = Instance.new("Part")
		part.Name = string.format("Block_%s_%d", b.material, i)
		part.Size = Vector3.new(b.w, b.h, Config.BLOCK_DEPTH)
		part.CFrame = CFrame.new(b.x, b.y, 0)
		part.Anchored = false
		part.Color = matSpec.color
		part.Transparency = matSpec.transparency
		part.Material = matSpec.robloxMaterial
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CustomPhysicalProperties = PhysicalProperties.new(
			matSpec.density,
			matSpec.friction,
			matSpec.elasticity,
			1.0,
			1.0
		)
		part.CollisionGroup = Config.CollisionGroups.Block
		part.Parent = stage

		if self._physics then
			self._physics:registerDestructible(part, "Block", matSpec.hp, matSpec.score, matSpec.damagedColor)
		end
	end

	-- Spawn targets (pigs)
	for i, t in ipairs(levelDef.targets) do
		local pig = self:_createPigPart(stage, t, i)
		if self._physics then
			self._physics:registerDestructible(pig, "Pig", Config.Pig.hp, Config.Pig.score, Config.Pig.damagedColor)
		end
	end

	-- Spawn waiting bird queue on the ground behind slingshot
	local anchor = Config.SLINGSHOT_ANCHOR
	for i = 1, levelDef.birds do
		local waitPos = Vector3.new(anchor.X - 4.5 - (i - 1) * 3.4, Config.GROUND_Y + Config.BIRD_RADIUS, 0)
		local bird = self:_createBirdPart(stage, waitPos, i)
		table.insert(self._waitingBirds, bird)
	end

	-- Load first bird onto slingshot
	local active = self:spawnBirdAtSlingshot()

	local refs = {
		stageFolder = stage,
		slingshotAnchor = self._slingshotRefs.slingshotAnchor,
		forkLeft = self._slingshotRefs.forkLeft,
		forkRight = self._slingshotRefs.forkRight,
		bandLeft = self._slingshotRefs.bandLeft,
		bandRight = self._slingshotRefs.bandRight,
		waitingBirds = self._waitingBirds,
		activeBird = active,
	}
	return refs
end

function LevelBuilder:spawnBirdAtSlingshot(): BasePart?
	if #self._waitingBirds == 0 then
		self._activeBird = nil
		return nil
	end
	local nextBird = table.remove(self._waitingBirds, 1) :: BasePart
	local anchor = Config.SLINGSHOT_ANCHOR
	nextBird.Anchored = true
	nextBird.CanCollide = true
	nextBird.CanTouch = true
	nextBird.CanQuery = true
	nextBird.CollisionGroup = Config.CollisionGroups.Bird
	nextBird.AssemblyLinearVelocity = Vector3.zero
	nextBird.AssemblyAngularVelocity = Vector3.zero
	nextBird.CFrame = CFrame.new(anchor.X, anchor.Y, 0)

	if self._physics then
		self._physics:lockPartTo2D(nextBird)
	end

	-- Shift remaining queue birds slightly forward
	for i, wb in ipairs(self._waitingBirds) do
		if wb.Parent then
			wb.CFrame = CFrame.new(anchor.X - 4.5 - (i - 1) * 3.4, Config.GROUND_Y + Config.BIRD_RADIUS, 0)
		end
	end

	self._activeBird = nextBird
	return nextBird
end

function LevelBuilder:clear()
	self._waitingBirds = {}
	self._activeBird = nil
	self._slingshotRefs = nil
	if self._stageFolder and self._stageFolder.Parent then
		self._stageFolder:Destroy()
	end
	self._stageFolder = nil
	local leftover = workspace:FindFirstChild("AngryBirdsStage")
	if leftover then
		leftover:Destroy()
	end
end

return LevelBuilder
