--!strict
local TrajectoryMath = {}

function TrajectoryMath.clampPullPosition(anchor: Vector3, cursorOnPlane: Vector3, maxPull: number): Vector3
	local planarCursor = Vector3.new(cursorOnPlane.X, cursorOnPlane.Y, anchor.Z)
	local delta = planarCursor - anchor
	local dist = delta.Magnitude
	if dist <= maxPull or dist == 0 then
		return planarCursor
	end
	return anchor + delta.Unit * maxPull
end

function TrajectoryMath.computeLaunchVelocity(
	anchor: Vector3,
	pulledPos: Vector3,
	minPull: number,
	speedPerStud: number
): Vector3?
	local displacement = Vector3.new(anchor.X - pulledPos.X, anchor.Y - pulledPos.Y, 0)
	local dist = displacement.Magnitude
	if dist < minPull then
		return nil
	end
	return displacement * speedPerStud
end

function TrajectoryMath.sampleTrajectory(
	startPos: Vector3,
	velocity: Vector3,
	gravity: number,
	count: number,
	dt: number,
	groundY: number
): { Vector3 }
	local points = {}
	for i = 1, count do
		local t = i * dt
		local x = startPos.X + velocity.X * t
		local y = startPos.Y + velocity.Y * t - 0.5 * gravity * t * t
		if y < groundY then
			break
		end
		table.insert(points, Vector3.new(x, y, 0))
	end
	return points
end

function TrajectoryMath.computeImpactDamage(relativeSpeed: number, minSpeed: number, damagePerSpeed: number): number
	if relativeSpeed <= minSpeed then
		return 0
	end
	return (relativeSpeed - minSpeed) * damagePerSpeed
end

function TrajectoryMath.computeCameraCFrame(
	center: Vector3,
	stageWidth: number,
	stageHeight: number,
	fovDeg: number,
	viewportSize: Vector2
): CFrame
	local halfV = math.rad(fovDeg) * 0.5
	local tanHalfV = math.tan(halfV)
	local safeY = math.max(1, viewportSize.Y)
	local aspect = math.max(0.5, viewportSize.X / safeY)

	local distY = (stageHeight * 0.5) / tanHalfV
	local distX = (stageWidth * 0.5) / (tanHalfV * aspect)
	local zDist = math.max(distX, distY) * 1.06

	local camPos = Vector3.new(center.X, center.Y, center.Z + zDist)
	return CFrame.lookAt(camPos, center, Vector3.yAxis)
end

return TrajectoryMath
