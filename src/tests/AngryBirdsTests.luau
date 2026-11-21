--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tests = {}

local function approxEqual(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-3)
end

local function assertTrue(cond: boolean, msg: string)
	if not cond then
		error("ASSERTION FAILED: " .. msg, 2)
	end
end

function Tests.runCoreUnitTests()
	local abFolder = ReplicatedStorage:FindFirstChild("AngryBirds")
	assertTrue(abFolder ~= nil, "ReplicatedStorage.AngryBirds folder missing")

	local configMod = abFolder:FindFirstChild("Config")
	assertTrue(configMod ~= nil and configMod:IsA("ModuleScript"), "Config ModuleScript missing")
	local mathMod = abFolder:FindFirstChild("TrajectoryMath")
	assertTrue(mathMod ~= nil and mathMod:IsA("ModuleScript"), "TrajectoryMath ModuleScript missing")
	local progMod = abFolder:FindFirstChild("ProgressionState")
	assertTrue(progMod ~= nil and progMod:IsA("ModuleScript"), "ProgressionState ModuleScript missing")

	local Config = require(configMod) :: any
	local TrajectoryMath = require(mathMod) :: any
	local ProgressionState = require(progMod) :: any

	-- Verify core physics and slingshot constants
	assertTrue(Config.GROUND_Y == 0, "GROUND_Y must be 0")
	assertTrue(Config.GRAVITY == 100, "GRAVITY must be 100")
	assertTrue(Config.PULL_MIN == 1.2, "PULL_MIN must be 1.2")
	assertTrue(Config.PULL_MAX == 8.5, "PULL_MAX must be 8.5")
	assertTrue(Config.Materials.Glass ~= nil and Config.Materials.Wood ~= nil and Config.Materials.Stone ~= nil, "Materials must define Glass, Wood, Stone")

	-- Pull clamping onto the Z=0 plane within PULL_MAX
	local anchor = Config.SLINGSHOT_ANCHOR
	local farLeft = anchor + Vector3.new(-20, 0, 5)
	local clamped = TrajectoryMath.clampPullPosition(anchor, farLeft, Config.PULL_MAX)
	assertTrue(approxEqual((clamped - anchor).Magnitude, Config.PULL_MAX, 1e-3), "clamped pull distance should equal PULL_MAX")
	assertTrue(approxEqual(clamped.Z, 0, 1e-4), "clamped pull Z must be 0")

	local nearPull = anchor + Vector3.new(-4, 0, 0)
	local unclamped = TrajectoryMath.clampPullPosition(anchor, nearPull, Config.PULL_MAX)
	assertTrue(approxEqual((unclamped - nearPull).Magnitude, 0, 1e-4), "pull inside maxPull should remain unchanged")

	-- Launch velocity calculation and minimum pull deadzone
	local tinyPull = anchor + Vector3.new(-0.8, 0, 0)
	local deadzoneVel = TrajectoryMath.computeLaunchVelocity(anchor, tinyPull, Config.PULL_MIN, Config.LAUNCH_SPEED_PER_STUD)
	assertTrue(deadzoneVel == nil, "pull inside PULL_MIN deadzone must return nil")

	local validPull = anchor + Vector3.new(-5, 0, 0)
	local vel = TrajectoryMath.computeLaunchVelocity(anchor, validPull, Config.PULL_MIN, Config.LAUNCH_SPEED_PER_STUD)
	assertTrue(vel ~= nil, "valid pull must return launch velocity")
	assertTrue(approxEqual(vel.X, 57.5, 1e-3) and approxEqual(vel.Y, 0, 1e-3) and approxEqual(vel.Z, 0, 1e-4), "launch velocity mismatch")

	-- Parabolic trajectory sampling above ground
	local p0 = Vector3.new(-36, 7, 0)
	local v0 = Vector3.new(40, 30, 0)
	local pts = TrajectoryMath.sampleTrajectory(p0, v0, 100, 18, 0.08, 0)
	assertTrue(#pts > 0 and #pts <= 18, "sampleTrajectory should return points within count")
	for i, pt in ipairs(pts) do
		local t = i * 0.08
		local ex = p0.X + v0.X * t
		local ey = p0.Y + v0.Y * t - 0.5 * 100 * t * t
		assertTrue(approxEqual(pt.X, ex, 1e-3) and approxEqual(pt.Y, ey, 1e-3) and approxEqual(pt.Z, 0, 1e-4), "trajectory point mismatch at step " .. tostring(i))
		assertTrue(pt.Y >= 0, "trajectory point should not fall below groundY")
	end

	-- Impact damage threshold and scaling
	assertTrue(TrajectoryMath.computeImpactDamage(6.9, 7.0, 2.6) == 0, "speed below minSpeed must deal 0 damage")
	assertTrue(approxEqual(TrajectoryMath.computeImpactDamage(17.0, 7.0, 2.6), 26.0, 1e-3), "impact damage formula mismatch")

	-- Camera framing across aspect ratios
	local cf169 = TrajectoryMath.computeCameraCFrame(Config.CAMERA.center, Config.CAMERA.width, Config.CAMERA.height, Config.CAMERA.fov, Vector2.new(1920, 1080))
	local cf43 = TrajectoryMath.computeCameraCFrame(Config.CAMERA.center, Config.CAMERA.width, Config.CAMERA.height, Config.CAMERA.fov, Vector2.new(1024, 768))
	assertTrue(cf169.Position.Z > 0, "camera must be positioned on +Z")
	assertTrue(cf43.Position.Z > cf169.Position.Z, "narrower 4:3 viewport must move camera further back in +Z")
	assertTrue(cf169.LookVector.Z < -0.99, "camera must face toward -Z")

	-- Sequential level progression and best score tracking
	local prog = ProgressionState.new(3)
	assertTrue(prog:isUnlocked(1) == true, "Level 1 must start unlocked")
	assertTrue(prog:isUnlocked(2) == false, "Level 2 must start locked")
	assertTrue(prog:isUnlocked(3) == false, "Level 3 must start locked")
	assertTrue(prog:getHighestUnlocked() == 1, "Highest unlocked must start at 1")

	local r1 = prog:recordWin(1, 12000)
	assertTrue(r1.unlockedNext == 2 and prog:isUnlocked(2) == true and prog:isUnlocked(3) == false, "Beating Level 1 must unlock Level 2 only")
	assertTrue(prog:isCompleted(1) == true and prog:getBestScore(1) == 12000, "Level 1 completion and best score mismatch")

	prog:recordWin(1, 8000)
	assertTrue(prog:getBestScore(1) == 12000, "Lower replay score must not overwrite best score")

	local r2 = prog:recordWin(2, 15000)
	assertTrue(r2.unlockedNext == 3 and prog:isUnlocked(3) == true, "Beating Level 2 must unlock Level 3")

	local r3 = prog:recordWin(3, 20000)
	assertTrue(r3.unlockedNext == nil and prog:getHighestUnlocked() == 3, "Beating final level keeps highest at 3")
	assertTrue(prog:computeFinalScore(5000, 2, 10000) == 25000, "Final score with unused bird bonus mismatch")
end

function Tests.runLevelDataTests()
	local abFolder = ReplicatedStorage:FindFirstChild("AngryBirds")
	assertTrue(abFolder ~= nil, "ReplicatedStorage.AngryBirds missing")

	local levelDataMod = abFolder:FindFirstChild("LevelData")
	assertTrue(levelDataMod ~= nil and levelDataMod:IsA("ModuleScript"), "LevelData ModuleScript missing")

	local LevelData = require(levelDataMod) :: any
	assertTrue(LevelData.getCount() == 3, "Must define exactly 3 levels")

	local function collectMaterials(lvl: any): { [string]: boolean }
		local set = {}
		for _, b in ipairs(lvl.blocks) do
			set[b.material] = true
		end
		return set
	end

	local l1 = LevelData.getLevel(1)
	local l2 = LevelData.getLevel(2)
	local l3 = LevelData.getLevel(3)
	assertTrue(l1 ~= nil and l2 ~= nil and l3 ~= nil, "Levels 1, 2, 3 must exist")
	assertTrue(LevelData.getLevel(0) == nil and LevelData.getLevel(4) == nil, "Out-of-range level must return nil")

	local m1 = collectMaterials(l1)
	assertTrue(m1.Wood == true and m1.Glass == nil and m1.Stone == nil, "Level 1 must use only Wood blocks")
	assertTrue(l1.birds == 3 and #l1.targets == 2, "Level 1 must have 3 birds and 2 targets")

	local m2 = collectMaterials(l2)
	assertTrue(m2.Wood == true and m2.Glass == true and m2.Stone == nil, "Level 2 must use Wood and Glass blocks")
	assertTrue(l2.birds == 3 and #l2.targets == 3, "Level 2 must have 3 birds and 3 targets")

	local m3 = collectMaterials(l3)
	assertTrue(m3.Stone == true and m3.Wood == true and m3.Glass == true, "Level 3 must use Stone, Wood, and Glass blocks")
	assertTrue(l3.birds == 4 and #l3.targets == 4, "Level 3 must have 4 birds and 4 targets")

	for i = 1, 3 do
		local ok, reason = LevelData.validateLevel(LevelData.getLevel(i))
		assertTrue(ok == true, "Level " .. tostring(i) .. " failed validation: " .. tostring(reason))
	end

	-- Synthetic overlapping level must fail validation
	local badLevel = {
		id = 99,
		name = "Invalid Overlap",
		birds = 2,
		blocks = {
			{ x = 20, y = 2, w = 4, h = 4, material = "Wood" },
			{ x = 21, y = 2, w = 4, h = 4, material = "Wood" },
		},
		targets = {
			{ x = 30, y = 1.4, radius = 1.4 },
		},
	}
	local badOk = LevelData.validateLevel(badLevel)
	assertTrue(badOk == false, "Overlapping blocks must fail validateLevel")
end

local function getClientAngryBirdsFolder(): Instance
	local Players = game:GetService("Players")
	local lp = Players.LocalPlayer
	if lp then
		local ps = lp:FindFirstChild("PlayerScripts")
		if ps then
			local ab = ps:FindFirstChild("AngryBirds")
			if ab then
				return ab
			end
		end
	end
	local StarterPlayer = game:GetService("StarterPlayer")
	local sps = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	assertTrue(sps ~= nil, "StarterPlayerScripts missing")
	local ab = sps:FindFirstChild("AngryBirds")
	assertTrue(ab ~= nil, "Client AngryBirds folder missing")
	return ab
end

function Tests.runPhysics2DTests()
	local clientAb = getClientAngryBirdsFolder()
	local physicsMod = clientAb:FindFirstChild("Physics2D")
	assertTrue(physicsMod ~= nil and physicsMod:IsA("ModuleScript"), "Physics2D ModuleScript missing")
	local builderMod = clientAb:FindFirstChild("LevelBuilder")
	assertTrue(builderMod ~= nil and builderMod:IsA("ModuleScript"), "LevelBuilder ModuleScript missing")
	local cameraMod = clientAb:FindFirstChild("CameraController")
	assertTrue(cameraMod ~= nil and cameraMod:IsA("ModuleScript"), "CameraController ModuleScript missing")

	local Config = require(ReplicatedStorage.AngryBirds.Config) :: any
	local LevelData = require(ReplicatedStorage.AngryBirds.LevelData) :: any
	local Physics2D = require(physicsMod) :: any
	local LevelBuilder = require(builderMod) :: any
	local CameraController = require(cameraMod) :: any

	local cam = CameraController.new()
	cam:enable()

	-- All levels must remain stable on spawn without breaking blocks or targets
	for lvlIdx = 1, 3 do
		local lvl = LevelData.getLevel(lvlIdx)
		local score = 0
		local stageFolder = workspace:FindFirstChild("AngryBirdsStage")
		if stageFolder then
			stageFolder:Destroy()
		end

		local tempStage = Instance.new("Folder")
		tempStage.Name = "AngryBirdsStage"
		tempStage.Parent = workspace

		local physics = Physics2D.new(tempStage, {
			onScore = function(pts: number)
				score += pts
			end,
			onTargetCountChanged = function(_count: number) end,
		})
		local builder = LevelBuilder.new(physics)
		builder:buildLevel(lvl)
		physics:startGracePeriod(Config.SPAWN_GRACE_SEC)

		task.wait(3.0)

		assertTrue(
			physics:getRemainingTargets() == #lvl.targets,
			"Level " .. tostring(lvlIdx) .. " targets died on spawn: got " .. tostring(physics:getRemainingTargets())
		)
		assertTrue(
			physics:getBlockCount() == #lvl.blocks,
			"Level " .. tostring(lvlIdx) .. " blocks broke on spawn: got " .. tostring(physics:getBlockCount())
		)
		assertTrue(score == 0, "Level " .. tostring(lvlIdx) .. " awarded unintended spawn score: " .. tostring(score))

		physics:destroy()
		builder:clear()
	end

	-- 2D planar lock holds under high-speed bird impact and OOB targets are eliminated
	do
		local lvl1 = LevelData.getLevel(1)
		local score = 0
		local stage = Instance.new("Folder")
		stage.Name = "AngryBirdsStage"
		stage.Parent = workspace

		local physics = Physics2D.new(stage, {
			onScore = function(pts: number)
				score += pts
			end,
			onTargetCountChanged = function(_count: number) end,
		})
		local builder = LevelBuilder.new(physics)
		local refs = builder:buildLevel(lvl1)
		physics:startGracePeriod(Config.SPAWN_GRACE_SEC)
		task.wait(Config.SPAWN_GRACE_SEC + 0.15)

		local bird = refs.activeBird
		assertTrue(bird ~= nil, "Level 1 must spawn an activeBird")
		physics:registerDynamicBody(bird)
		bird.Anchored = false
		bird.AssemblyLinearVelocity = Vector3.new(68, 22, 0)

		task.wait(1.6)

		-- Verify impact occurred (damage or destruction)
		local damagedOrBroken = score > 0 or physics:getBlockCount() < #lvl1.blocks or physics:getRemainingTargets() < #lvl1.targets
		if not damagedOrBroken then
			for _, desc in ipairs(stage:GetDescendants()) do
				if desc:IsA("BasePart") and desc:GetAttribute("AB_HP") ~= nil and desc:GetAttribute("AB_MaxHP") ~= nil then
					if (desc:GetAttribute("AB_HP") :: number) < (desc:GetAttribute("AB_MaxHP") :: number) then
						damagedOrBroken = true
						break
					end
				end
			end
		end
		assertTrue(damagedOrBroken, "Bird impact on Level 1 tower should damage or break at least one block/target")

		-- Verify 2D planar lock on all surviving dynamic bodies
		for _, desc in ipairs(stage:GetDescendants()) do
			if desc:IsA("BasePart") and not desc.Anchored and desc:GetAttribute("AB_Dynamic") == true then
				assertTrue(
					math.abs(desc.Position.Z) < 0.15,
					"Dynamic part " .. desc.Name .. " drifted in Z: " .. tostring(desc.Position.Z)
				)
				assertTrue(
					math.abs(desc.CFrame.ZVector.Z) > 0.95,
					"Dynamic part " .. desc.Name .. " tilted out of 2D plane: ZVector.Z=" .. tostring(desc.CFrame.ZVector.Z)
				)
			end
		end

		-- Out-of-bounds target elimination
		local beforeTargets = physics:getRemainingTargets()
		local beforeScore = score
		if beforeTargets == 0 then
			physics:destroy()
			builder:clear()
			stage = Instance.new("Folder")
			stage.Name = "AngryBirdsStage"
			stage.Parent = workspace
			score = 0
			physics = Physics2D.new(stage, {
				onScore = function(pts: number)
					score += pts
				end,
				onTargetCountChanged = function(_count: number) end,
			})
			builder = LevelBuilder.new(physics)
			builder:buildLevel(lvl1)
			beforeTargets = physics:getRemainingTargets()
			beforeScore = score
		end

		local somePig: BasePart? = nil
		for _, desc in ipairs(stage:GetDescendants()) do
			if desc:IsA("BasePart") and desc:GetAttribute("AB_Kind") == "Pig" then
				somePig = desc
				break
			end
		end
		assertTrue(somePig ~= nil, "Expected a live pig to test OOB elimination")
		local pigPart = somePig :: BasePart
		pigPart.CFrame = CFrame.new(80, -20, 0)
		task.wait(0.25)

		assertTrue(physics:getRemainingTargets() == beforeTargets - 1, "OOB pig must decrement remaining targets")
		assertTrue(score >= beforeScore + Config.Pig.score, "OOB pig must award pig score")

		physics:destroy()
		builder:clear()
	end

	cam:disable()
end

function Tests.runSlingshotTests()
	local clientAb = getClientAngryBirdsFolder()
	local slingshotMod = clientAb:FindFirstChild("SlingshotController")
	assertTrue(slingshotMod ~= nil and slingshotMod:IsA("ModuleScript"), "SlingshotController ModuleScript missing")

	local Config = require(ReplicatedStorage.AngryBirds.Config) :: any
	local LevelData = require(ReplicatedStorage.AngryBirds.LevelData) :: any
	local TrajectoryMath = require(ReplicatedStorage.AngryBirds.TrajectoryMath) :: any
	local Physics2D = require(clientAb.Physics2D) :: any
	local LevelBuilder = require(clientAb.LevelBuilder) :: any
	local SlingshotController = require(slingshotMod) :: any

	local stage = Instance.new("Folder")
	stage.Name = "AngryBirdsStage"
	stage.Parent = workspace

	local physics = Physics2D.new(stage, {
		onScore = function() end,
		onTargetCountChanged = function() end,
	})
	local builder = LevelBuilder.new(physics)
	local refs = builder:buildLevel(LevelData.getLevel(1))
	local bird = refs.activeBird
	assertTrue(bird ~= nil, "Active bird missing")
	local anchor = refs.slingshotAnchor

	local launchCount = 0
	local launchedBird: BasePart? = nil
	local launchedVel: Vector3? = nil

	local sling = SlingshotController.new({
		onLaunched = function(b: BasePart, v: Vector3)
			launchCount += 1
			launchedBird = b
			launchedVel = v
		end,
	})
	sling:bindStage(refs)
	sling:setActiveBird(bird)
	sling:setEnabled(true)

	-- Must ignore input already processed by UI
	local startedProcessed = sling:simulateDragStart(anchor, true)
	assertTrue(startedProcessed == false and sling:isDragging() == false, "Slingshot must ignore gameProcessed input")

	-- Deadzone release and explicit cancel must not launch
	assertTrue(sling:simulateDragStart(anchor, false) == true, "Should start drag near anchor")
	sling:simulateDragMove(anchor + Vector3.new(-0.6, 0, 0))
	local launchedDeadzone = sling:simulateDragRelease()
	assertTrue(launchedDeadzone == false and launchCount == 0, "Deadzone release must not launch")
	assertTrue(approxEqual((bird.Position - anchor).Magnitude, 0, 1e-2), "Bird must snap back to anchor after deadzone cancel")
	assertTrue(refs.bandLeft.Transparency == 1 and refs.bandRight.Transparency == 1, "Bands must hide after deadzone cancel")

	assertTrue(sling:simulateDragStart(anchor, false) == true, "Should start second drag")
	sling:simulateDragMove(anchor + Vector3.new(-6, -2, 0))
	assertTrue(sling:isDragging() == true, "Should be dragging")
	sling:cancelDrag()
	assertTrue(sling:isDragging() == false and launchCount == 0, "cancelDrag must abort without launching")
	assertTrue(approxEqual((bird.Position - anchor).Magnitude, 0, 1e-2), "Bird must snap back on cancelDrag")
	assertTrue(refs.bandLeft.Transparency == 1 and refs.bandRight.Transparency == 1, "Bands must hide on cancelDrag")

	-- Valid pull updates bands & preview dots and launches cleanly on release
	assertTrue(sling:simulateDragStart(anchor, false) == true, "Should start valid launch drag")
	local rawTarget = anchor + Vector3.new(-15, -3, 0)
	sling:simulateDragMove(rawTarget)
	local expectedClamped = TrajectoryMath.clampPullPosition(anchor, rawTarget, Config.PULL_MAX)
	assertTrue(approxEqual((bird.Position - expectedClamped).Magnitude, 0, 0.05), "Bird pull position must match clamped PULL_MAX")
	assertTrue(refs.bandLeft.Transparency == 0 and refs.bandRight.Transparency == 0, "Bands must be visible while pulling")

	local visibleDots = 0
	for _, desc in ipairs(stage:GetDescendants()) do
		if desc:IsA("BasePart") and desc.Name == "TrajectoryDot" and desc.Transparency < 1 then
			visibleDots += 1
		end
	end
	assertTrue(visibleDots > 0, "Trajectory preview dots must be visible during valid pull")

	local expectedVel = TrajectoryMath.computeLaunchVelocity(anchor, expectedClamped, Config.PULL_MIN, Config.LAUNCH_SPEED_PER_STUD)
	local didLaunch = sling:simulateDragRelease()
	assertTrue(didLaunch == true and launchCount == 1, "Valid pull release must launch exactly once")
	assertTrue(launchedBird == bird, "onLaunched must pass launched bird")
	assertTrue(launchedVel ~= nil and expectedVel ~= nil and approxEqual((launchedVel - expectedVel).Magnitude, 0, 0.05), "Launched velocity mismatch")
	assertTrue(bird.Anchored == false, "Launched bird must be unanchored")
	assertTrue(refs.bandLeft.Transparency == 1 and refs.bandRight.Transparency == 1, "Bands must hide after launch")

	sling:destroy()
	physics:destroy()
	builder:clear()
end

function Tests.runUITests()
	local clientAb = getClientAngryBirdsFolder()
	local uiMod = clientAb:FindFirstChild("UIController")
	assertTrue(uiMod ~= nil and uiMod:IsA("ModuleScript"), "UIController ModuleScript missing")

	local Players = game:GetService("Players")
	local lp = Players.LocalPlayer
	assertTrue(lp ~= nil, "LocalPlayer required for UIController tests")
	local playerGui = lp:WaitForChild("PlayerGui") :: PlayerGui

	local ProgressionState = require(ReplicatedStorage.AngryBirds.ProgressionState) :: any
	local UIController = require(uiMod) :: any

	local testContainer = Instance.new("Folder")
	testContainer.Name = "AB_UITestHost"
	testContainer.Parent = playerGui

	local ui = UIController.new(testContainer, {
		onPlay = function() end,
		onSelectLevel = function(_i: number) end,
		onRestart = function() end,
		onMainMenu = function() end,
		onNextLevel = function() end,
	})

	local gui = ui:getScreenGui()
	assertTrue(gui ~= nil and gui:IsA("ScreenGui"), "UIController must create a ScreenGui")

	local mainPanel = gui:FindFirstChild("MainMenuPanel") :: GuiObject
	local hudPanel = gui:FindFirstChild("HudPanel") :: GuiObject
	local modal = gui:FindFirstChild("ResultModal") :: GuiObject
	assertTrue(mainPanel ~= nil and hudPanel ~= nil and modal ~= nil, "MainMenuPanel, HudPanel, and ResultModal must exist")

	-- Main menu sequential lock states
	local prog = ProgressionState.new(3)
	ui:showMainMenu(prog)
	assertTrue(mainPanel.Visible == true and hudPanel.Visible == false and modal.Visible == false, "MainMenu visibility state mismatch")

	local titleLbl = mainPanel:FindFirstChild("TitleLabel", true) :: TextLabel
	local playBtn = mainPanel:FindFirstChild("PlayButton", true) :: TextButton
	local btn1 = mainPanel:FindFirstChild("LevelBtn1", true) :: TextButton
	local btn2 = mainPanel:FindFirstChild("LevelBtn2", true) :: TextButton
	local btn3 = mainPanel:FindFirstChild("LevelBtn3", true) :: TextButton
	assertTrue(titleLbl ~= nil and string.find(titleLbl.Text, "ANGRY BIRDS", 1, true) ~= nil, "Title must contain ANGRY BIRDS")
	assertTrue(playBtn ~= nil and playBtn.Text == "PLAY", "Play button text must be PLAY")
	assertTrue(btn1 ~= nil and btn2 ~= nil and btn3 ~= nil, "Level buttons 1..3 must exist")

	assertTrue(btn1.Interactable == true and string.find(btn1.Text, "Level 1", 1, true) ~= nil, "Level 1 must start unlocked")
	assertTrue(btn2.Interactable == false and string.find(btn2.Text, "🔒", 1, true) ~= nil, "Level 2 must start locked with lock icon")
	assertTrue(btn3.Interactable == false and string.find(btn3.Text, "🔒", 1, true) ~= nil, "Level 3 must start locked with lock icon")

	prog:recordWin(1, 14000)
	ui:showMainMenu(prog)
	assertTrue(btn2.Interactable == true and string.find(btn2.Text, "🔒", 1, true) == nil, "Level 2 must unlock after Level 1 win")
	assertTrue(string.find(btn1.Text, "14000", 1, true) ~= nil or string.find(btn1.Text, "✓", 1, true) ~= nil, "Completed Level 1 card must show completion/score")
	assertTrue(btn3.Interactable == false, "Level 3 must remain locked")

	-- Gameplay HUD and result modals
	ui:showGameplayHud(1, 3, "Wooden Tower", 3, 0)
	assertTrue(hudPanel.Visible == true and mainPanel.Visible == false and modal.Visible == false, "HUD visibility state mismatch")
	assertTrue(hudPanel.Position.Y.Offset >= 58, "HudPanel must sit below Roblox TopBar (>= 58px), got: " .. tostring(hudPanel.Position.Y.Offset))
	local lvlLbl = hudPanel:FindFirstChild("LevelLabel", true) :: TextLabel
	local birdsLbl = hudPanel:FindFirstChild("BirdsLabel", true) :: TextLabel
	local scoreLbl = hudPanel:FindFirstChild("ScoreLabel", true) :: TextLabel
	local menuBtn = hudPanel:FindFirstChild("MenuBtn", true) :: TextButton
	local restartBtn = hudPanel:FindFirstChild("RestartBtn", true) :: TextButton
	assertTrue(lvlLbl ~= nil and string.find(lvlLbl.Text, "Level 1 / 3", 1, true) ~= nil, "HUD level label mismatch")
	assertTrue(birdsLbl ~= nil and string.find(birdsLbl.Text, "3", 1, true) ~= nil, "HUD birds label mismatch")
	assertTrue(scoreLbl ~= nil and string.find(scoreLbl.Text, "Score: 0", 1, true) ~= nil, "HUD score label mismatch")
	assertTrue(menuBtn ~= nil and menuBtn.Text == "Main Menu", "HUD menu button label mismatch")
	assertTrue(restartBtn ~= nil and restartBtn.Text == "Restart", "HUD restart button label mismatch")

	ui:updateHud(2, 5750)
	assertTrue(string.find(birdsLbl.Text, "2", 1, true) ~= nil and string.find(scoreLbl.Text, "5750", 1, true) ~= nil, "updateHud did not update labels")

	ui:showWinModal(1, 3, 15750, 10000)
	assertTrue(modal.Visible == true, "Win modal must be visible")
	local modalTitle = modal:FindFirstChild("ModalTitle", true) :: TextLabel
	local primaryBtn = modal:FindFirstChild("PrimaryBtn", true) :: TextButton
	local secondaryBtn = modal:FindFirstChild("SecondaryBtn", true) :: TextButton
	local modalMenuBtn = modal:FindFirstChild("ModalMenuBtn", true) :: TextButton
	assertTrue(modalTitle.Text == "Level Complete!", "Level 1 win title mismatch")
	assertTrue(primaryBtn.Text == "Next Level", "Level 1 win primary button mismatch")
	assertTrue(secondaryBtn.Visible == true and secondaryBtn.Text == "Replay", "Win replay button mismatch")
	assertTrue(modalMenuBtn.Text == "Main Menu", "Modal menu button mismatch")

	ui:showWinModal(3, 3, 25000, 10000)
	assertTrue(modalTitle.Text == "All Levels Complete!", "Level 3 win title mismatch")
	assertTrue(primaryBtn.Text == "Play Again", "Level 3 win primary button mismatch")

	ui:showLoseModal(1, 2000)
	assertTrue(modalTitle.Text == "Level Failed", "Lose modal title mismatch")
	assertTrue(primaryBtn.Text == "Try Again", "Lose modal primary button mismatch")
	assertTrue(secondaryBtn.Visible == false, "Lose modal should hide secondary replay button")

	ui:destroy()
	testContainer:Destroy()
end

function Tests.runEndToEndTests()
	local StarterPlayer = game:GetService("StarterPlayer")
	local Players = game:GetService("Players")
	local lp = Players.LocalPlayer
	local clientScript = if lp
		then (lp:FindFirstChild("PlayerScripts") and lp.PlayerScripts:FindFirstChild("AngryBirdsClient"))
		else StarterPlayer.StarterPlayerScripts:FindFirstChild("AngryBirdsClient")
	assertTrue(clientScript ~= nil and clientScript:IsA("LocalScript"), "AngryBirdsClient LocalScript missing")

	local app = (_G :: any).AngryBirdsApp
	assertTrue(app ~= nil, "_G.AngryBirdsApp missing (client not initialized)")

	local Config = require(ReplicatedStorage.AngryBirds.Config) :: any
	local LevelData = require(ReplicatedStorage.AngryBirds.LevelData) :: any

	local function waitUntil(pred: () -> boolean, timeoutSec: number, label: string)
		local deadline = os.clock() + timeoutSec
		while os.clock() < deadline do
			if pred() then
				return
			end
			task.wait(0.05)
		end
		error("TIMEOUT waiting for: " .. label .. " (state=" .. tostring(app.getState()) .. ")", 2)
	end

	-- Boot state: main menu visible and player avatar disabled
	assertTrue(lp.Character == nil, "Player character must not auto-load")
	assertTrue(app.getState() == "MainMenu", "App must boot into MainMenu, got: " .. tostring(app.getState()))
	local prog = app.getProgression()
	assertTrue(prog:isUnlocked(1) == true and prog:isUnlocked(2) == false and prog:isUnlocked(3) == false, "Initial unlock state must be 1 only")

	local gui = app.getUI():getScreenGui()
	local mainPanel = gui:FindFirstChild("MainMenuPanel") :: GuiObject
	local modal = gui:FindFirstChild("ResultModal") :: GuiObject
	local modalTitle = modal:FindFirstChild("ModalTitle", true) :: TextLabel
	local primaryBtn = modal:FindFirstChild("PrimaryBtn", true) :: TextButton
	assertTrue(mainPanel.Visible == true, "MainMenuPanel must be visible on boot")

	local anchor = Config.SLINGSHOT_ANCHOR
	local function fireLeftOffscreen()
		local sling = app.getSlingshot()
		assertTrue(sling:simulateDragStart(anchor, false) == true, "Failed to grab slingshot")
		sling:simulateDragMove(Vector3.new(-28, 7, 0))
		assertTrue(sling:simulateDragRelease() == true, "Failed to release slingshot")
	end

	-- Mid-flight restart and return-to-menu cleanup
	app.startLevel(1)
	assertTrue(app.getState() == "Aiming", "startLevel(1) must enter Aiming")
	assertTrue(app.getBirdsRemaining() == 3, "Level 1 must start with 3 birds")
	fireLeftOffscreen()
	assertTrue(app.getState() == "InFlight", "Launching bird must enter InFlight")

	app.restartLevel()
	assertTrue(app.getState() == "Aiming", "Mid-flight restart must immediately enter Aiming")
	assertTrue(app.getBirdsRemaining() == 3, "Mid-flight restart must restore 3 birds")
	local l1 = LevelData.getLevel(1)
	assertTrue(app.getPhysics():getBlockCount() == #l1.blocks and app.getPhysics():getRemainingTargets() == #l1.targets, "Mid-flight restart must restore full blocks and targets")
	task.wait(1.0)
	assertTrue(app.getState() == "Aiming", "No stale timer may alter state after restart")

	fireLeftOffscreen()
	app.returnToMenu()
	assertTrue(app.getState() == "MainMenu", "Mid-flight returnToMenu must enter MainMenu")
	assertTrue(mainPanel.Visible == true, "MainMenuPanel must be visible after returnToMenu")
	assertTrue(app.getSlingshot():isDragging() == false, "Slingshot must not remain dragging after returnToMenu")

	-- Out-of-bounds shot cleanly advances turn
	app.startLevel(1)
	fireLeftOffscreen()
	waitUntil(function()
		return app.getState() == "Aiming"
	end, 8.0, "OOB shot turn advance to Aiming")
	assertTrue(app.getBirdsRemaining() == 2, "OOB shot should leave 2 birds remaining")

	-- Lose flow when all birds are spent
	fireLeftOffscreen()
	waitUntil(function()
		return app.getState() == "Aiming"
	end, 8.0, "2nd OOB shot turn advance")
	assertTrue(app.getBirdsRemaining() == 1, "Should have 1 bird left")
	fireLeftOffscreen()
	waitUntil(function()
		return app.getState() == "LevelLost"
	end, 10.0, "LevelLost after spending all 3 birds")
	assertTrue(modal.Visible == true and modalTitle.Text == "Level Failed" and primaryBtn.Text == "Try Again", "Lose modal label mismatch")

	app.restartLevel()
	assertTrue(app.getState() == "Aiming" and app.getBirdsRemaining() == 3 and modal.Visible == false, "Restart from LevelLost must cleanly reset")

	-- Sequential level progression from Level 1 through Level 3
	local function clearTargetsViaPhysics(levelIndex: number)
		app.startLevel(levelIndex)
		task.wait(Config.SPAWN_GRACE_SEC + 0.1)
		local stage = workspace:FindFirstChild("AngryBirdsStage")
		assertTrue(stage ~= nil, "AngryBirdsStage missing during progression test")
		for _, desc in ipairs(stage:GetDescendants()) do
			if desc:IsA("BasePart") and desc:GetAttribute("AB_Kind") == "Pig" then
				desc.CFrame = CFrame.new(80, -20, 0)
			end
		end
		waitUntil(function()
			return app.getState() == "LevelWon"
		end, 6.0, "LevelWon for level " .. tostring(levelIndex))
	end

	clearTargetsViaPhysics(1)
	assertTrue(prog:isUnlocked(2) == true and prog:isUnlocked(3) == false, "Winning Level 1 must unlock Level 2 only")
	assertTrue(modal.Visible == true and modalTitle.Text == "Level Complete!" and primaryBtn.Text == "Next Level", "Level 1 win modal mismatch")

	clearTargetsViaPhysics(2)
	assertTrue(prog:isUnlocked(3) == true, "Winning Level 2 must unlock Level 3")
	assertTrue(modal.Visible == true and modalTitle.Text == "Level Complete!", "Level 2 win modal mismatch")

	clearTargetsViaPhysics(3)
	assertTrue(modal.Visible == true and modalTitle.Text == "All Levels Complete!" and primaryBtn.Text == "Play Again", "Level 3 completion modal mismatch")

	app.returnToMenu()
	assertTrue(app.getState() == "MainMenu" and mainPanel.Visible == true, "Final returnToMenu failed")
end

function Tests.runRegressionTests()
	local clientAb = getClientAngryBirdsFolder()
	local Config = require(ReplicatedStorage.AngryBirds.Config) :: any
	local LevelData = require(ReplicatedStorage.AngryBirds.LevelData) :: any
	local Physics2D = require(clientAb.Physics2D) :: any
	local LevelBuilder = require(clientAb.LevelBuilder) :: any
	local CameraController = require(clientAb.CameraController) :: any
	local SlingshotController = require(clientAb.SlingshotController) :: any

	local app = (_G :: any).AngryBirdsApp
	assertTrue(app ~= nil, "_G.AngryBirdsApp missing")

	-- Screen-to-plane raycast must match InputObject.Position (ScreenPointToRay)
	do
		local camCtrl = CameraController.new()
		camCtrl:enable()
		local cam = workspace.CurrentCamera
		assertTrue(cam ~= nil, "CurrentCamera missing")
		assertTrue(type(SlingshotController.screenToPlane) == "function", "SlingshotController.screenToPlane must be exposed")

		local anchor = Config.SLINGSHOT_ANCHOR
		local screenPt = cam:WorldToScreenPoint(anchor)
		local rayHit = SlingshotController.screenToPlane(Vector2.new(screenPt.X, screenPt.Y))
		assertTrue(rayHit ~= nil, "screenToPlane must hit Z=0 for anchor screen coordinates")
		local errDist = (Vector3.new(rayHit.X, rayHit.Y, 0) - anchor).Magnitude
		assertTrue(errDist < 0.2, "screenToPlane offset from WorldToScreenPoint too large (TopBar inset mismatch): " .. tostring(errDist))
	end

	-- Downward slingshot pull stays above ground and waiting queue birds remain non-colliding
	do
		local stage = Instance.new("Folder")
		stage.Name = "AngryBirdsStage"
		stage.Parent = workspace
		local phys = Physics2D.new(stage, { onScore = function() end, onTargetCountChanged = function() end })
		local builder = LevelBuilder.new(phys)
		local refs = builder:buildLevel(LevelData.getLevel(1))

		assertTrue(refs.activeBird ~= nil and refs.activeBird.CanCollide == true and refs.activeBird.CollisionGroup == Config.CollisionGroups.Bird, "Active bird must be collidable in AB_Bird")
		assertTrue(#refs.waitingBirds == 2, "Level 1 should have 2 waiting birds in queue")
		for i, wb in ipairs(refs.waitingBirds) do
			assertTrue(wb.CanCollide == false and wb.CollisionGroup == Config.CollisionGroups.NoCollide, "Waiting bird #" .. tostring(i) .. " must be non-colliding in AB_NoCollide")
		end

		local sling = SlingshotController.new({ onLaunched = function() end })
		sling:bindStage(refs)
		sling:setActiveBird(refs.activeBird)
		sling:setEnabled(true)

		local anchor = refs.slingshotAnchor
		assertTrue(sling:simulateDragStart(anchor, false) == true, "Must grab slingshot for downward pull test")
		sling:simulateDragMove(anchor + Vector3.new(-2, -12, 0))
		local minY = Config.GROUND_Y + Config.BIRD_RADIUS + 0.04
		assertTrue(refs.activeBird.Position.Y >= minY, "Downward pull penetrated ground: Y=" .. tostring(refs.activeBird.Position.Y))
		assertTrue((refs.activeBird.Position - anchor).Magnitude <= Config.PULL_MAX + 0.05, "Clamped downward pull exceeded PULL_MAX")

		-- Next spawned bird from queue restores CanCollide and AB_Bird
		local nextBird = builder:spawnBirdAtSlingshot()
		assertTrue(nextBird ~= nil and nextBird.CanCollide == true and nextBird.CollisionGroup == Config.CollisionGroups.Bird, "Spawned queue bird must restore CanCollide and AB_Bird")

		sling:destroy()
		phys:destroy()
		builder:clear()
	end

	-- Same-step destruction preserves _prevVel until next Heartbeat for partner Touched callbacks
	do
		local stage = Instance.new("Folder")
		stage.Name = "AngryBirdsStage"
		stage.Parent = workspace
		local phys = Physics2D.new(stage, { onScore = function() end, onTargetCountChanged = function() end })
		local glassPart = Instance.new("Part")
		glassPart.Size = Vector3.new(2, 2, 2)
		glassPart.CFrame = CFrame.new(10, 10, 0)
		glassPart.Anchored = false
		glassPart.Parent = stage
		phys:registerDestructible(glassPart, "Block", 18, 500, nil)
		glassPart.AssemblyLinearVelocity = Vector3.new(0, -40, 0)
		task.wait(0.05)

		local entry = phys._destructibles[glassPart]
		assertTrue(entry ~= nil, "Glass entry missing")
		phys:_destroyDestructible(entry)
		local preserved = phys._prevVel[glassPart]
		assertTrue(preserved ~= nil and preserved.Magnitude > 5, "Destroyed part _prevVel must remain readable during same physics step for partner callbacks")
		task.wait(0.06)
		assertTrue(phys._prevVel[glassPart] == nil, "Deferred _prevVel entry must be cleaned up on next Heartbeat")

		phys:destroy()
		stage:Destroy()
	end

	-- Post-win destruction must not mutate score or HUD behind the Win modal
	do
		app.startLevel(1)
		task.wait(Config.SPAWN_GRACE_SEC + 0.1)
		local stage = workspace:FindFirstChild("AngryBirdsStage")
		assertTrue(stage ~= nil, "Stage missing for post-win score check")
		for _, desc in ipairs(stage:GetDescendants()) do
			if desc:IsA("BasePart") and desc:GetAttribute("AB_Kind") == "Pig" then
				desc.CFrame = CFrame.new(80, -20, 0)
			end
		end
		local deadline = os.clock() + 5.0
		while os.clock() < deadline and app.getState() ~= "LevelWon" do
			task.wait(0.05)
		end
		assertTrue(app.getState() == "LevelWon", "Expected LevelWon state for post-win score test")

		local frozenScore = app.getScore()
		local hudScoreLbl = app.getUI():getScreenGui():FindFirstChild("ScoreLabel", true) :: TextLabel
		local frozenText = hudScoreLbl.Text

		-- Trigger a late block destruction out of bounds after LevelWon
		local lateBlock: BasePart? = nil
		for _, desc in ipairs(stage:GetDescendants()) do
			if desc:IsA("BasePart") and desc:GetAttribute("AB_Kind") == "Block" then
				lateBlock = desc
				break
			end
		end
		assertTrue(lateBlock ~= nil, "Expected a remaining block on Level 1 after pig OOB")
		local lbPart = lateBlock :: BasePart
		lbPart.CFrame = CFrame.new(80, -20, 0)
		task.wait(0.25)

		assertTrue(app.getScore() == frozenScore, "Post-win block break mutated score from " .. tostring(frozenScore) .. " to " .. tostring(app.getScore()))
		assertTrue(hudScoreLbl.Text == frozenText, "Post-win block break mutated HUD ScoreLabel behind modal")
		app.returnToMenu()
	end
end

function Tests.runAll()
	Tests.runCoreUnitTests()
	Tests.runLevelDataTests()
	Tests.runPhysics2DTests()
	Tests.runSlingshotTests()
	Tests.runUITests()
	Tests.runEndToEndTests()
	Tests.runRegressionTests()
end

return Tests
