--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("AngryBirds"):WaitForChild("Config"))
local TrajectoryMath = require(ReplicatedStorage:WaitForChild("AngryBirds"):WaitForChild("TrajectoryMath"))

export type SlingshotCallbacks = {
	onLaunched: (bird: BasePart, velocity: Vector3) -> (),
}

local SlingshotController = {}
SlingshotController.__index = SlingshotController

function SlingshotController.screenToPlane(screenPos: Vector2): Vector3?
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local ray = cam:ScreenPointToRay(screenPos.X, screenPos.Y)
	if math.abs(ray.Direction.Z) < 1e-5 then
		return nil
	end
	local t = -ray.Origin.Z / ray.Direction.Z
	if t <= 0 then
		return nil
	end
	local hit = ray.Origin + ray.Direction * t
	return Vector3.new(hit.X, hit.Y, 0)
end

local function updateBandPart(band: BasePart, fromPos: Vector3, toPos: Vector3)
	local delta = toPos - fromPos
	local len = delta.Magnitude
	if len < 0.05 then
		band.Transparency = 1
		return
	end
	local mid = (fromPos + toPos) * 0.5
	band.Size = Vector3.new(0.32, 0.32, len)
	band.CFrame = CFrame.lookAt(mid, toPos)
	band.Transparency = 0
end

function SlingshotController.new(callbacks: SlingshotCallbacks)
	local self = setmetatable({
		_callbacks = callbacks,
		_stageRefs = nil :: any,
		_activeBird = nil :: BasePart?,
		_enabled = false,
		_dragging = false,
		_dots = {} :: { Part },
		_conns = {} :: { RBXScriptConnection },
	}, SlingshotController)

	table.insert(self._conns, UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if self._dragging and (input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape) then
			self:cancelDrag()
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if gameProcessed then
				return
			end
			local worldPos = SlingshotController.screenToPlane(Vector2.new(input.Position.X, input.Position.Y))
			if worldPos then
				self:simulateDragStart(worldPos, gameProcessed)
			end
		end
	end))

	table.insert(self._conns, UserInputService.InputChanged:Connect(function(input: InputObject, _gameProcessed: boolean)
		if not self._dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local worldPos = SlingshotController.screenToPlane(Vector2.new(input.Position.X, input.Position.Y))
			if worldPos then
				self:simulateDragMove(worldPos)
			end
		end
	end))

	table.insert(self._conns, UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
		if not self._dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:simulateDragRelease()
		end
	end))

	return self
end

function SlingshotController:_clearDots()
	for _, dot in ipairs(self._dots) do
		if dot.Parent then
			dot:Destroy()
		end
	end
	table.clear(self._dots)
end

function SlingshotController:_hideVisuals()
	if self._stageRefs then
		if self._stageRefs.bandLeft and self._stageRefs.bandLeft.Parent then
			self._stageRefs.bandLeft.Transparency = 1
		end
		if self._stageRefs.bandRight and self._stageRefs.bandRight.Parent then
			self._stageRefs.bandRight.Transparency = 1
		end
	end
	for _, dot in ipairs(self._dots) do
		if dot.Parent then
			dot.Transparency = 1
		end
	end
end

function SlingshotController:bindStage(stageRefs: any)
	self:cancelDrag()
	self:_clearDots()
	self._stageRefs = stageRefs

	if stageRefs and stageRefs.stageFolder and stageRefs.stageFolder.Parent then
		for i = 1, Config.DOT_COUNT do
			local dot = Instance.new("Part")
			dot.Name = "TrajectoryDot"
			dot.Shape = Enum.PartType.Ball
			local frac = (i - 1) / math.max(1, Config.DOT_COUNT - 1)
			local diameter = 0.85 * (1 - frac * 0.45)
			dot.Size = Vector3.new(diameter, diameter, diameter)
			dot.Anchored = true
			dot.CanCollide = false
			dot.CanTouch = false
			dot.CanQuery = false
			dot.CollisionGroup = Config.CollisionGroups.NoCollide
			dot.Color = Color3.fromRGB(255, 255, 255)
			dot.Material = Enum.Material.SmoothPlastic
			dot.Transparency = 1
			dot.Parent = stageRefs.stageFolder
			table.insert(self._dots, dot)
		end
	end
end

function SlingshotController:setActiveBird(bird: BasePart?)
	self:cancelDrag()
	self._activeBird = bird
end

function SlingshotController:setEnabled(enabled: boolean)
	self._enabled = enabled
	if not enabled then
		self:cancelDrag()
	end
end

function SlingshotController:isDragging(): boolean
	return self._dragging
end

function SlingshotController:cancelDrag()
	self._dragging = false
	self:_hideVisuals()
	if self._activeBird and self._activeBird.Parent and self._activeBird.Anchored and self._stageRefs then
		local a = self._stageRefs.slingshotAnchor
		self._activeBird.CFrame = CFrame.new(a.X, a.Y, 0)
	end
end

function SlingshotController:simulateDragStart(worldPosOnPlane: Vector3, gameProcessed: boolean?): boolean
	if gameProcessed == true then
		return false
	end
	if not self._enabled or not self._activeBird or not self._activeBird.Parent or not self._stageRefs then
		return false
	end

	local planar = Vector3.new(worldPosOnPlane.X, worldPosOnPlane.Y, 0)
	local anchor = self._stageRefs.slingshotAnchor
	local birdPos = Vector3.new(self._activeBird.Position.X, self._activeBird.Position.Y, 0)
	local distAnchor = (planar - anchor).Magnitude
	local distBird = (planar - birdPos).Magnitude
	if distAnchor > Config.GRAB_RADIUS and distBird > Config.GRAB_RADIUS then
		return false
	end

	self._dragging = true
	self:simulateDragMove(planar)
	return true
end

function SlingshotController:simulateDragMove(worldPosOnPlane: Vector3)
	if not self._dragging or not self._activeBird or not self._activeBird.Parent or not self._stageRefs then
		return
	end

	local anchor = self._stageRefs.slingshotAnchor
	local minY = Config.GROUND_Y + Config.BIRD_RADIUS + 0.05
	local safeCursor = Vector3.new(worldPosOnPlane.X, math.max(minY, worldPosOnPlane.Y), 0)
	local pulled = TrajectoryMath.clampPullPosition(anchor, safeCursor, Config.PULL_MAX)
	self._activeBird.CFrame = CFrame.new(pulled.X, pulled.Y, 0)

	updateBandPart(self._stageRefs.bandLeft, self._stageRefs.forkLeft, pulled)
	updateBandPart(self._stageRefs.bandRight, self._stageRefs.forkRight, pulled)

	local vel = TrajectoryMath.computeLaunchVelocity(anchor, pulled, Config.PULL_MIN, Config.LAUNCH_SPEED_PER_STUD)
	if vel then
		local pts = TrajectoryMath.sampleTrajectory(pulled, vel, Config.GRAVITY, #self._dots, Config.DOT_DT, Config.GROUND_Y)
		for i, dot in ipairs(self._dots) do
			local pt = pts[i]
			if pt and dot.Parent then
				dot.CFrame = CFrame.new(pt.X, pt.Y, 0.2)
				local frac = (i - 1) / math.max(1, #self._dots - 1)
				dot.Transparency = 0.08 + frac * 0.55
			elseif dot.Parent then
				dot.Transparency = 1
			end
		end
	else
		for _, dot in ipairs(self._dots) do
			if dot.Parent then
				dot.Transparency = 1
			end
		end
	end
end

function SlingshotController:simulateDragRelease(): boolean
	if not self._dragging or not self._activeBird or not self._activeBird.Parent or not self._stageRefs then
		self:cancelDrag()
		return false
	end

	local bird = self._activeBird
	local anchor = self._stageRefs.slingshotAnchor
	local pulled = Vector3.new(bird.Position.X, bird.Position.Y, 0)
	local vel = TrajectoryMath.computeLaunchVelocity(anchor, pulled, Config.PULL_MIN, Config.LAUNCH_SPEED_PER_STUD)
	if not vel then
		self:cancelDrag()
		return false
	end

	self._dragging = false
	self:_hideVisuals()
	self._activeBird = nil

	bird.Anchored = false
	bird.AssemblyLinearVelocity = vel
	bird.AssemblyAngularVelocity = Vector3.zero

	if self._callbacks.onLaunched then
		self._callbacks.onLaunched(bird, vel)
	end
	return true
end

function SlingshotController:destroy()
	self:cancelDrag()
	self:_clearDots()
	for _, conn in ipairs(self._conns) do
		conn:Disconnect()
	end
	table.clear(self._conns)
	self._activeBird = nil
	self._stageRefs = nil
end

return SlingshotController
