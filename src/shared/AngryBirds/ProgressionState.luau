--!strict
export type ProgressionState = {
	totalLevels: number,
	highestUnlocked: number,
	completed: { [number]: boolean },
	bestScores: { [number]: number },
	isUnlocked: (self: ProgressionState, levelIndex: number) -> boolean,
	getHighestUnlocked: (self: ProgressionState) -> number,
	recordWin: (self: ProgressionState, levelIndex: number, score: number) -> { unlockedNext: number?, bestScore: number },
	getBestScore: (self: ProgressionState, levelIndex: number) -> number?,
	isCompleted: (self: ProgressionState, levelIndex: number) -> boolean,
	computeFinalScore: (self: ProgressionState, baseScore: number, remainingBirds: number, bonusPerBird: number) -> number,
}

local ProgressionStateModule = {}
ProgressionStateModule.__index = ProgressionStateModule

function ProgressionStateModule.new(totalLevels: number): ProgressionState
	local self = setmetatable({
		totalLevels = math.max(1, totalLevels),
		highestUnlocked = 1,
		completed = {},
		bestScores = {},
	}, ProgressionStateModule)
	return (self :: any) :: ProgressionState
end

function ProgressionStateModule:isUnlocked(levelIndex: number): boolean
	return levelIndex >= 1 and levelIndex <= self.totalLevels and levelIndex <= self.highestUnlocked
end

function ProgressionStateModule:getHighestUnlocked(): number
	return self.highestUnlocked
end

function ProgressionStateModule:recordWin(levelIndex: number, score: number): { unlockedNext: number?, bestScore: number }
	self.completed[levelIndex] = true
	local prevBest = self.bestScores[levelIndex]
	local best = if prevBest == nil or score > prevBest then score else prevBest
	self.bestScores[levelIndex] = best

	local unlockedNext: number? = nil
	if levelIndex + 1 <= self.totalLevels and self.highestUnlocked < levelIndex + 1 then
		self.highestUnlocked = levelIndex + 1
		unlockedNext = levelIndex + 1
	end

	return {
		unlockedNext = unlockedNext,
		bestScore = best,
	}
end

function ProgressionStateModule:getBestScore(levelIndex: number): number?
	return self.bestScores[levelIndex]
end

function ProgressionStateModule:isCompleted(levelIndex: number): boolean
	return self.completed[levelIndex] == true
end

function ProgressionStateModule:computeFinalScore(baseScore: number, remainingBirds: number, bonusPerBird: number): number
	return baseScore + math.max(0, remainingBirds) * bonusPerBird
end

return ProgressionStateModule
