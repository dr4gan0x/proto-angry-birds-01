--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local sharedFolder = ReplicatedStorage:WaitForChild("AngryBirds")
local Config = require(sharedFolder:WaitForChild("Config"))
local LevelData = require(sharedFolder:WaitForChild("LevelData"))
local ProgressionState = require(sharedFolder:WaitForChild("ProgressionState"))

local clientModules = script.Parent:WaitForChild("AngryBirds")
local CameraController = require(clientModules:WaitForChild("CameraController"))
local LevelBuilder = require(clientModules:WaitForChild("LevelBuilder"))
local Physics2D = require(clientModules:WaitForChild("Physics2D"))
local SlingshotController = require(clientModules:WaitForChild("SlingshotController"))
local UIController = require(clientModules:WaitForChild("UIController"))

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

type GameState = "MainMenu" | "Aiming" | "InFlight" | "Settling" | "LevelWon" | "LevelLost"

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local progression = ProgressionState.new(LevelData.getCount())
local cameraController = CameraController.new()

local state: GameState = "MainMenu"
local currentLevelIndex = 1
local currentScore = 0
local birdsRemaining = 0
local sessionToken = 0

local physics: any = nil
local levelBuilder: any = LevelBuilder.new(nil)
local activeFlyingBird: BasePart? = nil
local activeBirdTouchConn: RBXScriptConnection? = nil

local flightStartTime = 0
local settleStartTime = 0
local settledElapsed = 0
local winDetectTime: number? = nil

local slingshot: any = nil
local ui: any = nil

local function disconnectFlyingBirdTouch()
	if activeBirdTouchConn then
		activeBirdTouchConn:Disconnect()
		activeBirdTouchConn = nil
	end
end

local function enterSettling()
	if state == "Settling" or state == "LevelWon" or state == "LevelLost" or state == "MainMenu" then
		return
	end
	disconnectFlyingBirdTouch()
	if slingshot then
		slingshot:setEnabled(false)
	end
	state = "Settling"
	settleStartTime = os.clock()
	settledElapsed = 0
end

local function cleanupActiveLevel()
	sessionToken += 1
	disconnectFlyingBirdTouch()
	activeFlyingBird = nil
	winDetectTime = nil
	settledElapsed = 0

	if slingshot then
		slingshot:setEnabled(false)
		slingshot:setActiveBird(nil)
	end
	if physics then
		physics:destroy()
		physics = nil
	end
	if levelBuilder then
		levelBuilder:clear()
	end
end

local startLevel: (number) -> ()
local returnToMenu: () -> ()

returnToMenu = function()
	cleanupActiveLevel()
	state = "MainMenu"
	levelBuilder = LevelBuilder.new(nil)
	levelBuilder:buildScenicBackdrop()
	cameraController:enable()
	ui:showMainMenu(progression)
end

startLevel = function(levelIndex: number)
	local levelDef = LevelData.getLevel(levelIndex)
	if not levelDef then
		return
	end

	cleanupActiveLevel()

	local myToken = sessionToken
	currentLevelIndex = levelIndex
	currentScore = 0
	birdsRemaining = levelDef.birds

	local stageFolder = Instance.new("Folder")
	stageFolder.Name = "AngryBirdsStage"
	stageFolder.Parent = workspace

	physics = Physics2D.new(stageFolder, {
		onScore = function(points: number)
			if myToken ~= sessionToken or state == "LevelWon" or state == "LevelLost" or state == "MainMenu" then
				return
			end
			currentScore += points
			ui:updateHud(birdsRemaining, currentScore)
		end,
		onTargetCountChanged = function(remaining: number)
			if myToken ~= sessionToken then
				return
			end
			if remaining == 0 and (state == "Aiming" or state == "InFlight" or state == "Settling") then
				if winDetectTime == nil then
					winDetectTime = os.clock()
				end
				enterSettling()
			end
		end,
	})

	levelBuilder = LevelBuilder.new(physics)
	local refs = levelBuilder:buildLevel(levelDef)
	physics:startGracePeriod(Config.SPAWN_GRACE_SEC)

	cameraController:enable()
	slingshot:bindStage(refs)
	slingshot:setActiveBird(refs.activeBird)

	ui:showGameplayHud(levelIndex, LevelData.getCount(), levelDef.name, birdsRemaining, currentScore)
	state = "Aiming"
	slingshot:setEnabled(true)
end

slingshot = SlingshotController.new({
	onLaunched = function(bird: BasePart, _velocity: Vector3)
		if state ~= "Aiming" or not physics then
			return
		end
		local myToken = sessionToken
		birdsRemaining = math.max(0, birdsRemaining - 1)
		ui:updateHud(birdsRemaining, currentScore)
		slingshot:setEnabled(false)

		activeFlyingBird = bird
		physics:registerDynamicBody(bird)
		state = "InFlight"
		flightStartTime = os.clock()

		disconnectFlyingBirdTouch()
		activeBirdTouchConn = bird.Touched:Connect(function(other: BasePart)
			if myToken ~= sessionToken or state ~= "InFlight" then
				return
			end
			if not other or not other:IsA("BasePart") or not other.CanCollide then
				return
			end
			if other.CollisionGroup == Config.CollisionGroups.NoCollide then
				return
			end
			enterSettling()
		end)
	end,
})

ui = UIController.new(playerGui, {
	onPlay = function()
		startLevel(progression:getHighestUnlocked())
	end,
	onSelectLevel = function(index: number)
		if progression:isUnlocked(index) then
			startLevel(index)
		end
	end,
	onRestart = function()
		startLevel(currentLevelIndex)
	end,
	onMainMenu = function()
		returnToMenu()
	end,
	onNextLevel = function()
		if currentLevelIndex < LevelData.getCount() then
			startLevel(currentLevelIndex + 1)
		else
			startLevel(1)
		end
	end,
})

RunService.Heartbeat:Connect(function(dt: number)
	if not physics then
		return
	end

	local now = os.clock()
	local remainingTargets = physics:getRemainingTargets()

	if remainingTargets == 0 and (state == "Aiming" or state == "InFlight" or state == "Settling") then
		if winDetectTime == nil then
			winDetectTime = now
		end
		if state ~= "Settling" then
			enterSettling()
		end
	end

	if state == "InFlight" then
		local bird = activeFlyingBird
		local oob = bird == nil or physics:isBodyOutOfBounds(bird)
		if oob then
			if bird and bird.Parent then
				bird:Destroy()
			end
			activeFlyingBird = nil
			enterSettling()
		elseif (now - flightStartTime) >= Config.MAX_FLIGHT_SEC then
			enterSettling()
		end
	elseif state == "Settling" then
		if activeFlyingBird and physics:isBodyOutOfBounds(activeFlyingBird) then
			if activeFlyingBird.Parent then
				activeFlyingBird:Destroy()
			end
			activeFlyingBird = nil
		end

		if remainingTargets == 0 then
			local wStart = winDetectTime or settleStartTime
			if (now - wStart) >= Config.WIN_DELAY_SEC then
				state = "LevelWon"
				local bonus = birdsRemaining * Config.UNUSED_BIRD_BONUS
				local finalScore = progression:computeFinalScore(currentScore, birdsRemaining, Config.UNUSED_BIRD_BONUS)
				currentScore = finalScore
				progression:recordWin(currentLevelIndex, finalScore)
				ui:updateHud(birdsRemaining, currentScore)
				ui:showWinModal(currentLevelIndex, LevelData.getCount(), finalScore, bonus)
			end
			return
		end

		if physics:areBodiesSettled(Config.SETTLE_SPEED_THRESHOLD) then
			settledElapsed += dt
		else
			settledElapsed = 0
		end

		local settleTimedOut = (now - settleStartTime) >= Config.MAX_SETTLE_SEC
		if settledElapsed >= Config.SETTLE_HOLD_SEC or settleTimedOut then
			activeFlyingBird = nil
			if birdsRemaining > 0 then
				local nextBird = levelBuilder:spawnBirdAtSlingshot()
				if nextBird then
					slingshot:setActiveBird(nextBird)
					state = "Aiming"
					slingshot:setEnabled(true)
					return
				end
			end
			state = "LevelLost"
			ui:showLoseModal(currentLevelIndex, currentScore)
		end
	end
end)

local globalEnv: any = _G
globalEnv.AngryBirdsApp = {
	getState = function(): GameState
		return state
	end,
	getCurrentLevel = function(): number
		return currentLevelIndex
	end,
	getBirdsRemaining = function(): number
		return birdsRemaining
	end,
	getScore = function(): number
		return currentScore
	end,
	getProgression = function()
		return progression
	end,
	getSlingshot = function()
		return slingshot
	end,
	getPhysics = function()
		return physics
	end,
	getUI = function()
		return ui
	end,
	startLevel = startLevel,
	returnToMenu = returnToMenu,
	restartLevel = function()
		startLevel(currentLevelIndex)
	end,
}

returnToMenu()
