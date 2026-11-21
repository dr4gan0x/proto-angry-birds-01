--!strict
local Config = require(script.Parent:WaitForChild("Config"))

export type BlockDef = {
	x: number,
	y: number,
	w: number,
	h: number,
	material: "Glass" | "Wood" | "Stone",
}

export type TargetDef = {
	x: number,
	y: number,
	radius: number?,
}

export type LevelDef = {
	id: number,
	name: string,
	birds: number,
	blocks: { BlockDef },
	targets: { TargetDef },
}

local LevelData = {}

LevelData.Levels = {
	{
		id = 1,
		name = "Wooden Tower",
		birds = 3,
		blocks = {
			{ x = 18.0, y = 3.5, w = 1.5, h = 7.0, material = "Wood" },
			{ x = 28.0, y = 3.5, w = 1.5, h = 7.0, material = "Wood" },
			{ x = 23.0, y = 7.6, w = 13.0, h = 1.2, material = "Wood" },
			{ x = 19.5, y = 10.7, w = 1.4, h = 5.0, material = "Wood" },
			{ x = 26.5, y = 10.7, w = 1.4, h = 5.0, material = "Wood" },
			{ x = 23.0, y = 13.8, w = 10.0, h = 1.2, material = "Wood" },
		},
		targets = {
			{ x = 23.0, y = 1.4, radius = 1.4 },
			{ x = 23.0, y = 9.6, radius = 1.4 },
		},
	},
	{
		id = 2,
		name = "Glass & Wood Outpost",
		birds = 3,
		blocks = {
			-- Front glass & wood shield
			{ x = 11.0, y = 3.0, w = 1.2, h = 6.0, material = "Glass" },
			{ x = 15.8, y = 3.0, w = 1.2, h = 6.0, material = "Glass" },
			{ x = 13.4, y = 6.55, w = 6.8, h = 1.1, material = "Wood" },
			-- Rear two-bay tower
			{ x = 22.5, y = 3.5, w = 1.5, h = 7.0, material = "Wood" },
			{ x = 28.5, y = 3.5, w = 1.4, h = 7.0, material = "Glass" },
			{ x = 34.5, y = 3.5, w = 1.5, h = 7.0, material = "Wood" },
			{ x = 28.5, y = 7.6, w = 14.0, h = 1.2, material = "Wood" },
			{ x = 25.0, y = 10.95, w = 1.2, h = 5.5, material = "Glass" },
			{ x = 32.0, y = 10.95, w = 1.2, h = 5.5, material = "Glass" },
			{ x = 28.5, y = 14.3, w = 9.5, h = 1.2, material = "Wood" },
		},
		targets = {
			{ x = 13.4, y = 1.4, radius = 1.4 },
			{ x = 25.5, y = 1.4, radius = 1.4 },
			{ x = 28.5, y = 9.6, radius = 1.4 },
		},
	},
	{
		id = 3,
		name = "Stone Castle",
		birds = 4,
		blocks = {
			-- Left stone/glass bay
			{ x = 14.5, y = 3.5, w = 1.8, h = 7.0, material = "Stone" },
			{ x = 20.5, y = 3.5, w = 1.8, h = 7.0, material = "Stone" },
			{ x = 17.5, y = 7.6, w = 8.2, h = 1.2, material = "Wood" },
			{ x = 15.3, y = 10.7, w = 1.2, h = 5.0, material = "Glass" },
			{ x = 19.7, y = 10.7, w = 1.2, h = 5.0, material = "Glass" },
			{ x = 17.5, y = 13.75, w = 6.6, h = 1.1, material = "Wood" },
			-- Center stone/wood/glass keep
			{ x = 24.0, y = 3.5, w = 1.8, h = 7.0, material = "Stone" },
			{ x = 30.0, y = 3.5, w = 1.8, h = 7.0, material = "Stone" },
			{ x = 27.0, y = 7.6, w = 8.4, h = 1.2, material = "Stone" },
			{ x = 24.5, y = 11.2, w = 1.5, h = 6.0, material = "Wood" },
			{ x = 29.5, y = 11.2, w = 1.5, h = 6.0, material = "Wood" },
			{ x = 27.0, y = 14.8, w = 7.6, h = 1.2, material = "Wood" },
			{ x = 25.2, y = 17.4, w = 1.1, h = 4.0, material = "Glass" },
			{ x = 28.8, y = 17.4, w = 1.1, h = 4.0, material = "Glass" },
			{ x = 27.0, y = 19.95, w = 5.6, h = 1.1, material = "Wood" },
			-- Right stone/glass bay
			{ x = 33.5, y = 3.5, w = 1.8, h = 7.0, material = "Stone" },
			{ x = 39.5, y = 3.5, w = 1.8, h = 7.0, material = "Stone" },
			{ x = 36.5, y = 7.6, w = 8.2, h = 1.2, material = "Wood" },
			{ x = 34.3, y = 10.7, w = 1.2, h = 5.0, material = "Glass" },
			{ x = 38.7, y = 10.7, w = 1.2, h = 5.0, material = "Glass" },
			{ x = 36.5, y = 13.75, w = 6.6, h = 1.1, material = "Wood" },
		},
		targets = {
			{ x = 17.5, y = 1.4, radius = 1.4 },
			{ x = 27.0, y = 1.4, radius = 1.4 },
			{ x = 27.0, y = 9.6, radius = 1.4 },
			{ x = 36.5, y = 1.4, radius = 1.4 },
		},
	},
} :: { LevelDef }

function LevelData.getCount(): number
	return #LevelData.Levels
end

function LevelData.getLevel(index: number): LevelDef?
	if index < 1 or index > #LevelData.Levels then
		return nil
	end
	return LevelData.Levels[index]
end

type Box = {
	label: string,
	minX: number,
	maxX: number,
	minY: number,
	maxY: number,
}

function LevelData.validateLevel(levelDef: any): (boolean, string?)
	if type(levelDef) ~= "table" then
		return false, "levelDef must be a table"
	end
	if type(levelDef.birds) ~= "number" or levelDef.birds < 1 then
		return false, "birds must be >= 1"
	end
	if type(levelDef.blocks) ~= "table" or #levelDef.blocks == 0 then
		return false, "blocks must be a non-empty array"
	end
	if type(levelDef.targets) ~= "table" or #levelDef.targets == 0 then
		return false, "targets must be a non-empty array"
	end

	local boxes: { Box } = {}
	local eps = 0.02

	for i, b in ipairs(levelDef.blocks) do
		if Config.Materials[b.material] == nil then
			return false, "invalid material on block " .. tostring(i) .. ": " .. tostring(b.material)
		end
		if b.w <= 0 or b.h <= 0 then
			return false, "non-positive block size on block " .. tostring(i)
		end
		local minY = b.y - b.h * 0.5
		if minY < Config.GROUND_Y - 1e-4 then
			return false, "block " .. tostring(i) .. " penetrates ground"
		end
		table.insert(boxes, {
			label = "block#" .. tostring(i),
			minX = b.x - b.w * 0.5,
			maxX = b.x + b.w * 0.5,
			minY = minY,
			maxY = b.y + b.h * 0.5,
		})
	end

	for i, t in ipairs(levelDef.targets) do
		local r = t.radius or Config.PIG_RADIUS
		if r <= 0 then
			return false, "non-positive radius on target " .. tostring(i)
		end
		local minY = t.y - r
		if minY < Config.GROUND_Y - 1e-4 then
			return false, "target " .. tostring(i) .. " penetrates ground"
		end
		table.insert(boxes, {
			label = "target#" .. tostring(i),
			minX = t.x - r,
			maxX = t.x + r,
			minY = minY,
			maxY = t.y + r,
		})
	end

	for i = 1, #boxes do
		local a = boxes[i]
		for j = i + 1, #boxes do
			local b = boxes[j]
			local overlapX = math.min(a.maxX, b.maxX) - math.max(a.minX, b.minX)
			local overlapY = math.min(a.maxY, b.maxY) - math.max(a.minY, b.minY)
			if overlapX > eps and overlapY > eps then
				return false, string.format("overlap between %s and %s (dx=%.3f, dy=%.3f)", a.label, b.label, overlapX, overlapY)
			end
		end
	end

	return true, nil
end

return LevelData
