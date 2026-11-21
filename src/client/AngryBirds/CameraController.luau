--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("AngryBirds"):WaitForChild("Config"))
local TrajectoryMath = require(ReplicatedStorage:WaitForChild("AngryBirds"):WaitForChild("TrajectoryMath"))

local CameraController = {}
CameraController.__index = CameraController

function CameraController.new()
	local self = setmetatable({
		_enabled = false,
		_vpConn = nil :: RBXScriptConnection?,
		_camChangedConn = nil :: RBXScriptConnection?,
	}, CameraController)
	return self
end

function CameraController:updateFraming()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = Config.CAMERA.fov
	cam.CFrame = TrajectoryMath.computeCameraCFrame(
		Config.CAMERA.center,
		Config.CAMERA.width,
		Config.CAMERA.height,
		Config.CAMERA.fov,
		cam.ViewportSize
	)
end

function CameraController:_bindCamera(cam: Camera)
	if self._vpConn then
		self._vpConn:Disconnect()
		self._vpConn = nil
	end
	self:updateFraming()
	self._vpConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if self._enabled then
			self:updateFraming()
		end
	end)
end

function CameraController:enable()
	if self._enabled then
		self:updateFraming()
		return
	end
	self._enabled = true

	local cam = workspace.CurrentCamera
	if cam then
		self:_bindCamera(cam)
	end

	self._camChangedConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if self._enabled and workspace.CurrentCamera then
			self:_bindCamera(workspace.CurrentCamera)
		end
	end)
end

function CameraController:disable()
	self._enabled = false
	if self._vpConn then
		self._vpConn:Disconnect()
		self._vpConn = nil
	end
	if self._camChangedConn then
		self._camChangedConn:Disconnect()
		self._camChangedConn = nil
	end
end

return CameraController
