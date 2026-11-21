--!strict
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("AngryBirds"):WaitForChild("Config"))
local TrajectoryMath = require(ReplicatedStorage:WaitForChild("AngryBirds"):WaitForChild("TrajectoryMath"))

export type PhysicsCallbacks = {
	onScore: (number) -> (),
	onTargetCountChanged: (number) -> (),
}

type DestructibleEntry = {
	part: BasePart,
	kind: "Block" | "Pig",
	hp: number,
	maxHp: number,
	scoreValue: number,
	damagedColor: Color3?,
	destroyed: boolean,
	lastHitBy: { [BasePart]: number },
	touchConn: RBXScriptConnection?,
}

local Physics2D = {}
Physics2D.__index = Physics2D

function Physics2D.new(stageFolder: Folder, callbacks: PhysicsCallbacks)
	local anchorPart = Instance.new("Part")
	anchorPart.Name = "PlaneAnchor2D"
	anchorPart.Size = Vector3.new(1, 1, 1)
	anchorPart.CFrame = CFrame.new(0, 0, 0)
	anchorPart.Anchored = true
	anchorPart.CanCollide = false
	anchorPart.CanTouch = false
	anchorPart.CanQuery = false
	anchorPart.Transparency = 1
	anchorPart.CollisionGroup = Config.CollisionGroups.NoCollide
	anchorPart.Parent = stageFolder

	local planeAtt = Instance.new("Attachment")
	planeAtt.Name = "PlaneNormalAtt"
	planeAtt.Axis = Vector3.zAxis
	planeAtt.Parent = anchorPart

	local self = setmetatable({
		_stageFolder = stageFolder,
		_callbacks = callbacks,
		_planeAnchor = anchorPart,
		_planeAtt = planeAtt,
		_dynamicParts = {} :: { [BasePart]: boolean },
		_prevVel = {} :: { [BasePart]: Vector3 },
		_pendingCleanup = {} :: { BasePart },
		_pendingDeadSet = {} :: { [BasePart]: boolean },
		_destructibles = {} :: { [BasePart]: DestructibleEntry },
		_remainingTargets = 0,
		_blockCount = 0,
		_graceUntil = 0,
		_destroyed = false,
		_hbConn = nil :: RBXScriptConnection?,
	}, Physics2D)

	self._hbConn = RunService.Heartbeat:Connect(function()
		self:_onHeartbeat()
	end)

	return self
end

function Physics2D:getStageFolder(): Folder
	return self._stageFolder
end

function Physics2D:startGracePeriod(durationSec: number)
	self._graceUntil = os.clock() + durationSec
end

function Physics2D:lockPartTo2D(part: BasePart)
	part:SetAttribute("AB_Dynamic", true)

	local existingAtt = part:FindFirstChild("Lock2DAtt")
	if existingAtt then
		existingAtt:Destroy()
	end
	local existingPlane = part:FindFirstChild("PlaneLock2D")
	if existingPlane then
		existingPlane:Destroy()
	end
	local existingAlign = part:FindFirstChild("OrientLock2D")
	if existingAlign then
		existingAlign:Destroy()
	end

	local partAtt = Instance.new("Attachment")
	partAtt.Name = "Lock2DAtt"
	partAtt.Axis = Vector3.zAxis
	partAtt.Parent = part

	local planeConstraint = Instance.new("PlaneConstraint")
	planeConstraint.Name = "PlaneLock2D"
	planeConstraint.Attachment0 = self._planeAtt
	planeConstraint.Attachment1 = partAtt
	planeConstraint.Parent = part

	local alignOrient = Instance.new("AlignOrientation")
	alignOrient.Name = "OrientLock2D"
	alignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrient.Attachment0 = partAtt
	alignOrient.AlignType = Enum.AlignType.PrimaryAxisParallel
	alignOrient.CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.zAxis, Vector3.yAxis)
	alignOrient.RigidityEnabled = true
	alignOrient.Parent = part

	self._dynamicParts[part] = true
	self._prevVel[part] = Vector3.zero
end

function Physics2D:registerDynamicBody(part: BasePart)
	if not part:FindFirstChild("PlaneLock2D") then
		self:lockPartTo2D(part)
	else
		part:SetAttribute("AB_Dynamic", true)
		self._dynamicParts[part] = true
		self._prevVel[part] = part.AssemblyLinearVelocity
	end
end

function Physics2D:_spawnBreakPuff(pos: Vector3, color: Color3, isPig: boolean)
	if self._destroyed or not self._stageFolder.Parent then
		return
	end
	local count = if isPig then 5 else 4
	for i = 1, count do
		local shard = Instance.new("Part")
		shard.Name = "DebrisPuff"
		local sz = if isPig then 0.7 else 0.55
		shard.Size = Vector3.new(sz, sz, sz)
		shard.Shape = if isPig then Enum.PartType.Ball else Enum.PartType.Block
		shard.Color = color
		shard.Material = Enum.Material.SmoothPlastic
		shard.CanCollide = false
		shard.CanTouch = false
		shard.CanQuery = false
		shard.CollisionGroup = Config.CollisionGroups.NoCollide
		local angle = (i / count) * math.pi * 2 + math.random() * 0.5
		shard.CFrame = CFrame.new(pos.X, pos.Y, 0)
		shard.Parent = self._stageFolder
		shard.AssemblyLinearVelocity = Vector3.new(math.cos(angle) * 14, math.sin(angle) * 14 + 8, 0)
		Debris:AddItem(shard, 0.45)
	end
end

function Physics2D:_destroyDestructible(entry: DestructibleEntry)
	if entry.destroyed or self._destroyed then
		return
	end
	entry.destroyed = true

	if entry.touchConn then
		entry.touchConn:Disconnect()
		entry.touchConn = nil
	end

	local part = entry.part
	local pos = part.Position
	local color = part.Color

	self._destructibles[part] = nil
	self._dynamicParts[part] = nil

	if entry.kind == "Pig" then
		self._remainingTargets = math.max(0, self._remainingTargets - 1)
	else
		self._blockCount = math.max(0, self._blockCount - 1)
	end

	self:_spawnBreakPuff(pos, color, entry.kind == "Pig")

	-- Hide & disable immediately, deferring _prevVel removal and Destroy until next Heartbeat
	-- so partner Touched callbacks in the same physics step still read pre-impact velocity.
	if part.Parent then
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Transparency = 1
		part.CollisionGroup = Config.CollisionGroups.NoCollide
		for _, d in ipairs(part:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 1
			end
		end
		table.insert(self._pendingCleanup, part)
		self._pendingDeadSet[part] = true
	else
		self._prevVel[part] = nil
	end

	if self._callbacks.onScore then
		self._callbacks.onScore(entry.scoreValue)
	end
	if entry.kind == "Pig" and self._callbacks.onTargetCountChanged then
		self._callbacks.onTargetCountChanged(self._remainingTargets)
	end
end

function Physics2D:registerDestructible(
	part: BasePart,
	kind: "Block" | "Pig",
	maxHp: number,
	scoreValue: number,
	damagedColor: Color3?
)
	self:lockPartTo2D(part)

	part:SetAttribute("AB_Kind", kind)
	part:SetAttribute("AB_HP", maxHp)
	part:SetAttribute("AB_MaxHP", maxHp)

	local entry: DestructibleEntry = {
		part = part,
		kind = kind,
		hp = maxHp,
		maxHp = maxHp,
		scoreValue = scoreValue,
		damagedColor = damagedColor,
		destroyed = false,
		lastHitBy = {},
		touchConn = nil,
	}

	self._destructibles[part] = entry
	if kind == "Pig" then
		self._remainingTargets += 1
	else
		self._blockCount += 1
	end

	entry.touchConn = part.Touched:Connect(function(other: BasePart)
		if entry.destroyed or self._destroyed then
			return
		end
		if os.clock() < self._graceUntil then
			return
		end
		if not other or not other:IsA("BasePart") then
			return
		end
		local isJustDestroyed = self._pendingDeadSet[other] == true
		if not isJustDestroyed then
			if not other.CanCollide or other.CollisionGroup == Config.CollisionGroups.NoCollide then
				return
			end
		end

		local now = os.clock()
		local lastHit = entry.lastHitBy[other]
		if lastHit and (now - lastHit) < Config.PAIR_COOLDOWN_SEC then
			return
		end

		local vA = part.AssemblyLinearVelocity
		local vB = other.AssemblyLinearVelocity
		local curRel = (vA - vB).Magnitude

		local prevA = self._prevVel[part] or vA
		local prevB = self._prevVel[other] or vB
		local prevRel = (prevA - prevB).Magnitude

		local impactSpeed = math.max(curRel, prevRel)
		local dmg = TrajectoryMath.computeImpactDamage(impactSpeed, Config.MIN_IMPACT_SPEED, Config.DAMAGE_PER_SPEED)
		if dmg <= 0 then
			return
		end

		entry.lastHitBy[other] = now
		entry.hp = math.max(0, entry.hp - dmg)
		part:SetAttribute("AB_HP", entry.hp)

		if entry.hp <= 0 then
			self:_destroyDestructible(entry)
		elseif entry.hp <= entry.maxHp * 0.5 and entry.damagedColor then
			part.Color = entry.damagedColor
		end
	end)
end

function Physics2D:isBodyOutOfBounds(part: BasePart): boolean
	if not part or not part.Parent then
		return true
	end
	local p = part.Position
	local b = Config.STAGE_BOUNDS
	return p.X < b.minX or p.X > b.maxX or p.Y < b.minY or p.Y > b.maxY
end

function Physics2D:_onHeartbeat()
	if self._destroyed then
		return
	end

	if #self._pendingCleanup > 0 then
		for _, deadPart in ipairs(self._pendingCleanup) do
			self._prevVel[deadPart] = nil
			self._pendingDeadSet[deadPart] = nil
			if deadPart.Parent then
				deadPart:Destroy()
			end
		end
		table.clear(self._pendingCleanup)
	end

	local toRemove = {}
	for part in pairs(self._dynamicParts) do
		if not part.Parent then
			table.insert(toRemove, part)
		elseif not part.Anchored then
			local v = part.AssemblyLinearVelocity
			self._prevVel[part] = v

			if math.abs(v.Z) > 0.01 then
				part.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, 0)
			end

			local av = part.AssemblyAngularVelocity
			if math.abs(av.X) > 0.01 or math.abs(av.Y) > 0.01 then
				part.AssemblyAngularVelocity = Vector3.new(0, 0, av.Z)
			end

			local pos = part.Position
			if math.abs(pos.Z) > 0.04 or math.abs(part.CFrame.ZVector.Z) < 0.995 then
				local right = part.CFrame.RightVector
				local angle = math.atan2(right.Y, right.X)
				part.CFrame = CFrame.new(pos.X, pos.Y, 0) * CFrame.Angles(0, 0, angle)
			end

			if self:isBodyOutOfBounds(part) then
				local entry = self._destructibles[part]
				if entry then
					self:_destroyDestructible(entry)
				else
					table.insert(toRemove, part)
				end
			end
		end
	end

	for _, part in ipairs(toRemove) do
		self._dynamicParts[part] = nil
		self._prevVel[part] = nil
	end
end

function Physics2D:getRemainingTargets(): number
	return self._remainingTargets
end

function Physics2D:getBlockCount(): number
	return self._blockCount
end

function Physics2D:areBodiesSettled(speedThreshold: number): boolean
	local angThreshold = speedThreshold * 1.5
	for part in pairs(self._dynamicParts) do
		if part.Parent and not part.Anchored then
			if part.AssemblyLinearVelocity.Magnitude > speedThreshold then
				return false
			end
			if part.AssemblyAngularVelocity.Magnitude > angThreshold then
				return false
			end
		end
	end
	return true
end

function Physics2D:destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true

	if self._hbConn then
		self._hbConn:Disconnect()
		self._hbConn = nil
	end

	for _, entry in pairs(self._destructibles) do
		if entry.touchConn then
			entry.touchConn:Disconnect()
			entry.touchConn = nil
		end
	end

	for _, deadPart in ipairs(self._pendingCleanup) do
		if deadPart.Parent then
			deadPart:Destroy()
		end
	end
	table.clear(self._pendingCleanup)
	table.clear(self._pendingDeadSet)
	table.clear(self._destructibles)
	table.clear(self._dynamicParts)
	table.clear(self._prevVel)
end

return Physics2D
